import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module.js';
import { RedisModule } from './redis/redis.module.js';
import { AuthModule } from './auth/auth.module.js';
import { ExpertsModule } from './experts/experts.module.js';
import { AdminModule } from './admin/admin.module.js';
import { WalletModule } from './wallet/wallet.module.js';
import { SessionsModule } from './sessions/sessions.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    PrismaModule,
    RedisModule,
    AuthModule,
    ExpertsModule,
    AdminModule,
    WalletModule,
    SessionsModule,
  ],
})
export class AppModule {}
