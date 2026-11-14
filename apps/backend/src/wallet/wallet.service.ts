import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import {
  PaymentOrderStatus,
  TransactionStatus,
  TransactionType,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';
import { RazorpayService } from './razorpay.service.js';
import { SimulatePaymentDto } from './dto/simulate-payment.dto.js';

@Injectable()
export class WalletService {
  private readonly logger = new Logger(WalletService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly razorpay: RazorpayService,
  ) {}

  /**
   * Create Razorpay recharge order and register in database
   */
  async createRechargeOrder(userId: string, amountInPaise: number) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { wallet: true },
    });

    if (!user) {
      throw new NotFoundException(`User with ID ${userId} not found`);
    }

    // Ensure wallet exists
    let wallet = user.wallet;
    if (!wallet) {
      wallet = await this.prisma.wallet.create({
        data: {
          userId,
          balanceInPaise: BigInt(0),
          currency: 'INR',
        },
      });
    }

    const receipt = `rcpt_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    // Call Razorpay Orders API (or mock wrapper)
    const razorpayOrder = await this.razorpay.createOrder({
      amount: amountInPaise,
      currency: 'INR',
      receipt,
      notes: {
        userId: user.id,
        phoneNumber: user.phoneNumber,
        purpose: 'wallet_recharge',
      },
    });

    // Record order in database
    const paymentOrder = await this.prisma.paymentOrder.create({
      data: {
        userId,
        orderId: razorpayOrder.id,
        amountInPaise: BigInt(amountInPaise),
        currency: 'INR',
        receipt,
        status: PaymentOrderStatus.CREATED,
        notes: razorpayOrder.notes as any,
      },
    });

    return {
      orderId: paymentOrder.orderId,
      amountInPaise: Number(paymentOrder.amountInPaise),
      amountInRupees: Number(paymentOrder.amountInPaise) / 100,
      currency: paymentOrder.currency,
      keyId: this.razorpay.getPublicKey(),
      receipt: paymentOrder.receipt,
    };
  }

  /**
   * Process incoming Razorpay webhook with HMAC SHA256 validation and idempotency
   */
  async handleWebhook(
    payload: any,
    signature: string,
    rawBody: string | Buffer,
    headerEventId?: string,
  ) {
    // 1. Verify HMAC SHA256 signature
    const isValid = this.razorpay.verifyWebhookSignature(rawBody, signature);
    if (!isValid) {
      this.logger.warn('Rejected webhook: invalid HMAC SHA256 signature');
      throw new UnauthorizedException('Invalid Razorpay webhook signature');
    }

    // 2. Extract or construct deterministic event ID
    const eventId =
      headerEventId ||
      payload.id ||
      `${payload.payload?.payment?.entity?.id || 'event'}_${payload.event}`;

    // 3. Idempotency Check: if this exact event was already processed, ignore safely
    const existingEvent = await this.prisma.paymentWebhookEvent.findUnique({
      where: { eventId },
    });

    if (existingEvent) {
      this.logger.log(`Webhook event ${eventId} already processed. Skipping to avoid double-crediting.`);
      return { received: true, status: 'already_processed', eventId };
    }

    const eventType = payload.event;

    // 4. Handle Payment Success (payment.captured / order.paid)
    if (eventType === 'payment.captured' || eventType === 'order.paid') {
      const payment = payload.payload?.payment?.entity;
      const orderId = payment?.order_id || payload.payload?.order?.entity?.id;
      const paymentId = payment?.id;

      if (!orderId) {
        this.logger.warn(`Webhook ${eventType} missing order_id`);
        return { received: true, status: 'ignored_missing_order_id' };
      }

      const order = await this.prisma.paymentOrder.findUnique({
        where: { orderId },
      });

      if (!order) {
        this.logger.warn(`No matching order found for ${orderId}`);
        return { received: true, status: 'order_not_found' };
      }

      // Check if order already paid
      if (order.status === PaymentOrderStatus.PAID) {
        this.logger.log(`Order ${orderId} is already marked PAID.`);
        return { received: true, status: 'order_already_paid' };
      }

      // 5. ATOMIC LEDGER WRITE & WALLET CREDIT
      await this.prisma.$transaction(async (tx) => {
        // Record webhook event (prevents concurrent duplicate executions)
        await tx.paymentWebhookEvent.create({
          data: {
            eventId,
            eventType,
            payload: payload as any,
            status: 'PROCESSED',
          },
        });

        // Mark order as PAID
        await tx.paymentOrder.update({
          where: { id: order.id },
          data: {
            status: PaymentOrderStatus.PAID,
            paymentId: paymentId || null,
          },
        });

        // Lock & fetch user's wallet
        const wallet = await tx.wallet.findUnique({
          where: { userId: order.userId },
        });

        if (!wallet) {
          throw new NotFoundException(`Wallet not found for user ${order.userId}`);
        }

        const newBalance = wallet.balanceInPaise + order.amountInPaise;

        // Update wallet balance inside the ledger transaction
        await tx.wallet.update({
          where: { id: wallet.id },
          data: { balanceInPaise: newBalance },
        });

        // Write append-only transaction log entry
        await tx.walletLedgerEntry.create({
          data: {
            walletId: wallet.id,
            amountInPaise: order.amountInPaise,
            type: TransactionType.RECHARGE,
            status: TransactionStatus.SUCCESS,
            runningBalanceSnapshot: newBalance,
            referenceId: paymentId || order.orderId,
            idempotencyKey: eventId,
            description: `Recharge via Razorpay (${order.orderId})`,
          },
        });
      });

      this.logger.log(`Successfully credited wallet for user ${order.userId} with ₹${Number(order.amountInPaise) / 100}`);
      return { received: true, status: 'processed', eventId };
    }

    // 6. Handle Payment Failure (payment.failed)
    if (eventType === 'payment.failed') {
      const payment = payload.payload?.payment?.entity;
      const orderId = payment?.order_id;

      await this.prisma.$transaction(async (tx) => {
        await tx.paymentWebhookEvent.create({
          data: {
            eventId,
            eventType,
            payload: payload as any,
            status: 'FAILED',
          },
        });

        if (orderId) {
          await tx.paymentOrder.updateMany({
            where: { orderId },
            data: { status: PaymentOrderStatus.FAILED },
          });
        }
      });

      this.logger.warn(`Recorded failed payment for order: ${orderId}. Zero wallet balance credited.`);
      return { received: true, status: 'failed_payment_recorded', eventId };
    }

    // Other unhandled events
    await this.prisma.paymentWebhookEvent.create({
      data: {
        eventId,
        eventType,
        payload: payload as any,
        status: 'IGNORED',
      },
    });

    return { received: true, status: 'ignored_event_type', eventId };
  }

  /**
   * Atomic balance deduction with database-level row lock (FOR UPDATE)
   * Prevents concurrent sessions from overdrafting the wallet below zero
   */
  async deductBalance(
    userId: string,
    amountInPaise: number,
    type: TransactionType = TransactionType.SESSION_CHARGE,
    referenceId?: string,
    description?: string,
  ) {
    if (amountInPaise <= 0) {
      throw new BadRequestException('Deduction amount must be strictly greater than 0');
    }

    const deductBigInt = BigInt(amountInPaise);

    return this.prisma.$transaction(async (tx) => {
      // Row-level lock: SELECT ... FOR UPDATE
      const wallets = await tx.$queryRaw<
        Array<{ id: string; user_id: string; balance_in_paise: bigint }>
      >`SELECT id, user_id, balance_in_paise FROM wallets WHERE user_id = ${userId}::uuid FOR UPDATE`;

      if (!wallets || wallets.length === 0) {
        throw new NotFoundException(`Wallet not found for user ${userId}`);
      }

      const wallet = wallets[0];
      const currentBalance = BigInt(wallet.balance_in_paise);

      if (currentBalance < deductBigInt) {
        throw new BadRequestException(
          `Insufficient wallet balance. Current: ₹${Number(currentBalance) / 100}, required: ₹${Number(deductBigInt) / 100}`,
        );
      }

      const newBalance = currentBalance - deductBigInt;

      // Update wallet balance
      await tx.wallet.update({
        where: { id: wallet.id },
        data: { balanceInPaise: newBalance },
      });

      // Append entry to wallet_ledger
      const ledgerEntry = await tx.walletLedgerEntry.create({
        data: {
          walletId: wallet.id,
          amountInPaise: deductBigInt,
          type,
          status: TransactionStatus.SUCCESS,
          runningBalanceSnapshot: newBalance,
          referenceId,
          description: description || 'Consultation session charge',
        },
      });

      return {
        balanceInPaise: newBalance.toString(),
        balanceInRupees: Number(newBalance) / 100,
        ledgerEntry: this.serializeLedgerEntry(ledgerEntry),
      };
    });
  }

  /**
   * Get user's current wallet balance
   */
  async getBalance(userId: string) {
    let wallet = await this.prisma.wallet.findUnique({
      where: { userId },
    });

    if (!wallet) {
      wallet = await this.prisma.wallet.create({
        data: {
          userId,
          balanceInPaise: BigInt(0),
          currency: 'INR',
        },
      });
    }

    return {
      balanceInPaise: wallet.balanceInPaise.toString(),
      balanceInRupees: Number(wallet.balanceInPaise) / 100,
      currency: wallet.currency,
    };
  }

  /**
   * Get append-only transaction history
   */
  async getTransactions(userId: string, limit = 50, offset = 0) {
    const wallet = await this.prisma.wallet.findUnique({
      where: { userId },
    });

    if (!wallet) {
      return {
        balanceInPaise: '0',
        balanceInRupees: 0,
        currency: 'INR',
        transactions: [],
      };
    }

    const transactions = await this.prisma.walletLedgerEntry.findMany({
      where: { walletId: wallet.id },
      orderBy: { createdAt: 'desc' },
      take: limit,
      skip: offset,
    });

    return {
      balanceInPaise: wallet.balanceInPaise.toString(),
      balanceInRupees: Number(wallet.balanceInPaise) / 100,
      currency: wallet.currency,
      transactions: transactions.map((t) => this.serializeLedgerEntry(t)),
    };
  }

  /**
   * Simulate a mock payment for testing and development UI without live gateway
   */
  async simulatePayment(dto: SimulatePaymentDto, userId: string) {
    const order = await this.prisma.paymentOrder.findUnique({
      where: { orderId: dto.orderId },
    });

    if (!order) {
      throw new NotFoundException(`Order ${dto.orderId} not found`);
    }

    if (order.userId !== userId) {
      throw new UnauthorizedException('Order does not belong to the authenticated user');
    }

    const paymentId = dto.paymentId || `pay_mock_${Date.now()}`;
    const eventType = dto.status === 'captured' ? 'payment.captured' : 'payment.failed';

    const payload = {
      entity: 'event',
      event: eventType,
      contains: ['payment', 'order'],
      payload: {
        payment: {
          entity: {
            id: paymentId,
            entity: 'payment',
            amount: Number(order.amountInPaise),
            currency: 'INR',
            status: dto.status,
            order_id: order.orderId,
            notes: order.notes,
          },
        },
        order: {
          entity: {
            id: order.orderId,
            entity: 'order',
            amount: Number(order.amountInPaise),
            status: dto.status === 'captured' ? 'paid' : 'attempted',
            receipt: order.receipt,
          },
        },
      },
      created_at: Math.floor(Date.now() / 1000),
    };

    const rawBody = JSON.stringify(payload);
    const signature = this.razorpay.generateWebhookSignature(rawBody);

    return this.handleWebhook(payload, signature, rawBody, `sim_${Date.now()}_${paymentId}`);
  }

  private serializeLedgerEntry(entry: any) {
    return {
      id: entry.id,
      walletId: entry.walletId,
      amountInPaise: entry.amountInPaise.toString(),
      amountInRupees: Number(entry.amountInPaise) / 100,
      type: entry.type,
      status: entry.status,
      runningBalanceSnapshot: entry.runningBalanceSnapshot.toString(),
      runningBalanceInRupees: Number(entry.runningBalanceSnapshot) / 100,
      referenceId: entry.referenceId,
      description: entry.description,
      createdAt: entry.createdAt.toISOString(),
    };
  }
}
