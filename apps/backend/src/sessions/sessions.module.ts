import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module.js';
import { RedisModule } from '../redis/redis.module.js';
import { AuthModule } from '../auth/auth.module.js';
import { WalletModule } from '../wallet/wallet.module.js';
import { SessionsController } from './sessions.controller.js';
import { SessionsService } from './sessions.service.js';
import { SessionsGateway } from './sessions.gateway.js';
import { PresenceService } from './presence.service.js';
import { SessionLockService } from './session-lock.service.js';
import { BillingEngineService } from './billing-engine.service.js';

@Module({
  imports: [
    PrismaModule,
    RedisModule,
    AuthModule,
    WalletModule,
  ],
  controllers: [SessionsController],
  providers: [
    SessionsService,
    SessionsGateway,
    PresenceService,
    SessionLockService,
    BillingEngineService,
  ],
  exports: [
    SessionsService,
    PresenceService,
    BillingEngineService,
    SessionLockService,
  ],
})
export class SessionsModule {}
