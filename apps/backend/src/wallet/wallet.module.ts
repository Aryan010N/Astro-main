import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { WalletController } from './wallet.controller.js';
import { WebhooksController } from './webhooks.controller.js';
import { WalletService } from './wallet.service.js';
import { RazorpayService } from './razorpay.service.js';
import { PrismaModule } from '../prisma/prisma.module.js';

@Module({
  imports: [ConfigModule, PrismaModule],
  controllers: [WalletController, WebhooksController],
  providers: [WalletService, RazorpayService],
  exports: [WalletService, RazorpayService],
})
export class WalletModule {}
