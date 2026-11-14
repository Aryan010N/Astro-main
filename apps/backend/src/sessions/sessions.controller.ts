import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { SessionsService } from './sessions.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { SessionType } from '@prisma/client';

export class RequestSessionBodyDto {
  @IsNotEmpty()
  @IsString()
  expertId!: string;

  @IsOptional()
  @IsEnum(SessionType)
  sessionType?: SessionType;
}

export class EndSessionBodyDto {
  @IsOptional()
  @IsString()
  reason?: string;
}

@ApiTags('Sessions')
@Controller('sessions')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class SessionsController {
  constructor(private readonly sessionsService: SessionsService) {}

  @Get('experts')
  @ApiOperation({ summary: 'Get list of approved live experts with real-time presence' })
  @ApiResponse({ status: 200, description: 'List of experts with ONLINE/BUSY/OFFLINE status' })
  async getExperts() {
    return this.sessionsService.getApprovedExpertsWithPresence();
  }

  @Get('active')
  @ApiOperation({ summary: 'Get currently active consultation session for the logged-in user or expert' })
  @ApiResponse({ status: 200, description: 'Active session details or null' })
  async getActiveSession(@CurrentUser('userId') userId: string) {
    return this.sessionsService.getActiveSessionForUser(userId);
  }

  @Post('request')
  @ApiOperation({ summary: 'Request a consultation session with an expert' })
  @ApiResponse({ status: 201, description: 'Session created in REQUESTED state' })
  async requestSession(
    @CurrentUser('userId') userId: string,
    @Body() body: RequestSessionBodyDto,
  ) {
    return this.sessionsService.requestSession(
      userId,
      body.expertId,
      body.sessionType || SessionType.CHAT,
    );
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get consultation session details' })
  @ApiResponse({ status: 200, description: 'Session details' })
  async getSession(@Param('id') id: string) {
    return this.sessionsService.getSessionDetails(id);
  }

  @Get(':id/messages')
  @ApiOperation({ summary: 'Get chat messages for a session' })
  @ApiResponse({ status: 200, description: 'List of chat messages' })
  async getMessages(@Param('id') id: string) {
    return this.sessionsService.getSessionMessages(id);
  }

  @Get(':id/summary')
  @ApiOperation({ summary: 'Get final billing summary for an ended session' })
  @ApiResponse({ status: 200, description: 'Final duration, billed paise/rupees, and reason' })
  async getSummary(@Param('id') id: string) {
    return this.sessionsService.getSessionSummary(id);
  }

  @Post(':id/end')
  @ApiOperation({ summary: 'End an active consultation session' })
  @ApiResponse({ status: 200, description: 'Finalized session summary' })
  async endSession(
    @Param('id') id: string,
    @CurrentUser('userId') userId: string,
    @Body() body: EndSessionBodyDto,
  ) {
    return this.sessionsService.endSession(id, userId, body.reason || 'USER_ENDED');
  }
}
