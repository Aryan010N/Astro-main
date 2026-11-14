import {
  BadRequestException,
  Body,
  Controller,
  Headers,
  HttpCode,
  HttpStatus,
  Post,
  Req,
} from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { Request } from 'express';
import { WalletService } from './wallet.service.js';

@ApiTags('Webhooks')
@Controller('webhooks')
export class WebhooksController {
  constructor(private readonly walletService: WalletService) {}

  @Post('payment')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Razorpay payment webhook callback' })
  @ApiResponse({ status: 200, description: 'Webhook received and processed idempotently' })
  async handlePaymentWebhook(
    @Req() req: Request & { rawBody?: Buffer },
    @Body() payload: any,
    @Headers('x-razorpay-signature') signature: string,
    @Headers('x-razorpay-event-id') eventId?: string,
  ) {
    if (!signature) {
      throw new BadRequestException('Missing x-razorpay-signature header');
    }

    const rawBody = req.rawBody || JSON.stringify(payload);

    return this.walletService.handleWebhook(payload, signature, rawBody, eventId);
  }
}
