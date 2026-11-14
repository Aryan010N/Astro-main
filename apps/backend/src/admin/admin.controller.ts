import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { AdminService } from './admin.service.js';
import { ReviewKycDto } from './dto/review-kyc.dto.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { RolesGuard } from '../auth/guards/roles.guard.js';
import { Roles } from '../auth/decorators/roles.decorator.js';

@ApiTags('Admin')
@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@ApiBearerAuth()
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('experts/pending')
  @ApiOperation({ summary: 'Get all expert KYC applications awaiting review' })
  @ApiResponse({ status: 200, description: 'List of pending expert profiles' })
  async getPendingExperts() {
    return this.adminService.getPendingExperts();
  }

  @Get('experts')
  @ApiOperation({ summary: 'Get all expert profiles (pending, approved, rejected)' })
  @ApiResponse({ status: 200, description: 'List of all expert profiles' })
  async getAllExperts() {
    return this.adminService.getAllExperts();
  }

  @Post('experts/:id/approve')
  @ApiOperation({ summary: 'Approve an expert KYC application and set status to APPROVED' })
  @ApiResponse({ status: 200, description: 'Expert approved successfully and promoted to EXPERT role' })
  async approveExpert(@Param('id') id: string) {
    return this.adminService.approveExpert(id);
  }

  @Post('experts/:id/reject')
  @ApiOperation({ summary: 'Reject an expert KYC application with an optional reason' })
  @ApiResponse({ status: 200, description: 'Expert KYC rejected' })
  async rejectExpert(@Param('id') id: string, @Body() dto: ReviewKycDto) {
    return this.adminService.rejectExpert(id, dto.rejectionReason);
  }
}

