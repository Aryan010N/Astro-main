import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { WalletService } from './wallet.service.js';
import { CreateRechargeOrderDto } from './dto/create-recharge-order.dto.js';
import { SimulatePaymentDto } from './dto/simulate-payment.dto.js';
import { DeductBalanceDto } from './dto/deduct-balance.dto.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';

@ApiTags('Wallet')
@Controller('wallet')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class WalletController {
  constructor(private readonly walletService: WalletService) {}

  @Post('recharge/create-order')
  @ApiOperation({ summary: 'Create a Razorpay order for wallet recharge' })
  @ApiResponse({ status: 200, description: 'Order created with Razorpay orderId and receipt' })
  async createRechargeOrder(
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateRechargeOrderDto,
  ) {
    return this.walletService.createRechargeOrder(userId, dto.amountInPaise);
  }

  @Get('balance')
  @ApiOperation({ summary: 'Get current user wallet balance' })
  @ApiResponse({ status: 200, description: 'Current balance in paise and rupees' })
  async getBalance(@CurrentUser('userId') userId: string) {
    return this.walletService.getBalance(userId);
  }

  @Get('transactions')
  @ApiOperation({ summary: 'Get append-only wallet transaction history' })
  @ApiResponse({ status: 200, description: 'List of ledger transaction logs' })
  async getTransactions(
    @CurrentUser('userId') userId: string,
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
  ) {
    return this.walletService.getTransactions(
      userId,
      limit ? Number(limit) : 50,
      offset ? Number(offset) : 0,
    );
  }

  @Post('deduct')
  @ApiOperation({ summary: 'Atomic balance deduction (for sessions and testing)' })
  @ApiResponse({ status: 200, description: 'Atomic balance deducted and ledger updated' })
  async deductBalance(
    @CurrentUser('userId') userId: string,
    @Body() dto: DeductBalanceDto,
  ) {
    return this.walletService.deductBalance(
      userId,
      dto.amountInPaise,
      undefined,
      dto.referenceId,
      dto.description,
    );
  }

  @Post('simulate-payment')
  @ApiOperation({ summary: 'Simulate mock Razorpay payment for local UI/testing' })
  @ApiResponse({ status: 200, description: 'Simulated payment processed' })
  async simulatePayment(
    @CurrentUser('userId') userId: string,
    @Body() dto: SimulatePaymentDto,
  ) {
    return this.walletService.simulatePayment(dto, userId);
  }
}
