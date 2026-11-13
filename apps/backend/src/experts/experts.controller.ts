import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { ExpertsService } from './experts.service.js';
import { SubmitKycDto } from './dto/submit-kyc.dto.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';

@ApiTags('Experts')
@Controller('experts')
export class ExpertsController {
  constructor(private readonly expertsService: ExpertsService) {}

  @Post('kyc')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Submit or update expert KYC application' })
  @ApiResponse({ status: 200, description: 'KYC application submitted successfully (Status: PENDING)' })
  async submitKyc(@CurrentUser('userId') userId: string, @Body() dto: SubmitKycDto) {
    return this.expertsService.submitKyc(userId, dto);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get logged-in expert profile and KYC status' })
  @ApiResponse({ status: 200, description: 'Returns expert profile and approval status' })
  async getMyProfile(@CurrentUser('userId') userId: string) {
    return this.expertsService.getMyProfile(userId);
  }
}
