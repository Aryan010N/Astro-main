import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';

export interface RazorpayOrderOptions {
  amount: number; // in paise
  currency?: string;
  receipt: string;
  notes?: Record<string, any>;
}

export interface RazorpayOrderResponse {
  id: string;
  entity: string;
  amount: number;
  amount_paid: number;
  amount_due: number;
  currency: string;
  receipt: string;
  status: string;
  attempts: number;
  notes?: Record<string, any>;
  created_at: number;
}

@Injectable()
export class RazorpayService {
  private readonly logger = new Logger(RazorpayService.name);
  private readonly keyId: string;
  private readonly keySecret: string;
  private readonly webhookSecret: string;
  private readonly isMockMode: boolean;

  constructor(private readonly config: ConfigService) {
    this.keyId = this.config.get<string>('RAZORPAY_KEY_ID') || 'rzp_test_placeholder_key_id';
    this.keySecret = this.config.get<string>('RAZORPAY_KEY_SECRET') || 'placeholder_secret_key';
    this.webhookSecret = this.config.get<string>('RAZORPAY_WEBHOOK_SECRET') || 'placeholder_webhook_secret';

    // Mock mode active if using placeholder keys
    this.isMockMode =
      !this.keyId ||
      this.keyId.includes('placeholder') ||
      this.keyId.startsWith('mock_');

    if (this.isMockMode) {
      this.logger.log('RazorpayService running in MOCK mode with placeholder keys. Ready for live/test key swap.');
    } else {
      this.logger.log(`RazorpayService initialized in LIVE/TEST mode with Key ID: ${this.keyId.substring(0, 8)}...`);
    }
  }

  getPublicKey(): string {
    return this.keyId;
  }

  getWebhookSecret(): string {
    return this.webhookSecret;
  }

  /**
   * Create an order via Razorpay Orders API
   * (Mock implementation when placeholder keys are set; structured identically to Razorpay response)
   */
  async createOrder(options: RazorpayOrderOptions): Promise<RazorpayOrderResponse> {
    if (this.isMockMode) {
      const randomHex = crypto.randomBytes(7).toString('hex');
      const mockOrder: RazorpayOrderResponse = {
        id: `order_${randomHex}`,
        entity: 'order',
        amount: options.amount,
        amount_paid: 0,
        amount_due: options.amount,
        currency: options.currency || 'INR',
        receipt: options.receipt,
        status: 'created',
        attempts: 0,
        notes: options.notes,
        created_at: Math.floor(Date.now() / 1000),
      };
      this.logger.log(`[MOCK] Created Razorpay order: ${mockOrder.id} for ₹${options.amount / 100}`);
      return mockOrder;
    }

    // TODO: When real test keys are added, invoke Razorpay SDK / API:
    // const instance = new Razorpay({ key_id: this.keyId, key_secret: this.keySecret });
    // return await instance.orders.create(options);
    throw new Error('Razorpay SDK requires active API credentials');
  }

  /**
   * Verify Razorpay Webhook signature using HMAC SHA256
   * per Razorpay Documentation:
   * https://razorpay.com/docs/webhooks/validate-test/
   */
  verifyWebhookSignature(rawBody: string | Buffer, signature: string): boolean {
    if (!signature) {
      return false;
    }

    const bodyStr = Buffer.isBuffer(rawBody)
      ? rawBody.toString('utf8')
      : typeof rawBody === 'string'
      ? rawBody
      : JSON.stringify(rawBody);

    const expectedSignature = crypto
      .createHmac('sha256', this.webhookSecret)
      .update(bodyStr)
      .digest('hex');

    try {
      const sigBuffer = Buffer.from(signature, 'utf8');
      const expectedBuffer = Buffer.from(expectedSignature, 'utf8');

      if (sigBuffer.length !== expectedBuffer.length) {
        return false;
      }

      return crypto.timingSafeEqual(sigBuffer, expectedBuffer);
    } catch (err: any) {
      this.logger.error(`Signature verification error: ${err.message}`);
      return false;
    }
  }

  /**
   * Helper to generate a valid HMAC SHA256 signature (used in tests and simulation)
   */
  generateWebhookSignature(payload: string | object): string {
    const bodyStr = typeof payload === 'string' ? payload : JSON.stringify(payload);
    return crypto
      .createHmac('sha256', this.webhookSecret)
      .update(bodyStr)
      .digest('hex');
  }
}
