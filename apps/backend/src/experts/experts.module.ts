import { Module } from '@nestjs/common';
import { ExpertsController } from './experts.controller.js';
import { ExpertsService } from './experts.service.js';

@Module({
  controllers: [ExpertsController],
  providers: [ExpertsService],
  exports: [ExpertsService],
})
export class ExpertsModule {}

