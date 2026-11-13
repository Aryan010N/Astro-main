import {
  Controller,
  Post,
  Get,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { AuthService } from './auth.service.js';
import { RequestOtpDto } from './dto/request-otp.dto.js';
import { VerifyOtpDto } from './dto/verify-otp.dto.js';
import { VerifyFirebaseTokenDto } from './dto/verify-firebase-token.dto.js';
import { RefreshTokenDto } from './dto/refresh-token.dto.js';
import { AdminLoginDto } from './dto/admin-login.dto.js';
import { JwtAuthGuard } from './guards/jwt-auth.guard.js';
import { CurrentUser } from './decorators/current-user.decorator.js';

@ApiTags('Authentication')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('otp/request')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Request OTP for phone verification' })
  @ApiResponse({ status: 200, description: 'OTP sent successfully, returns requestId' })
  async requestOtp(@Body() dto: RequestOtpDto) {
    return this.authService.requestOtp(dto);
  }

  @Post('otp/verify')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify OTP code and issue JWT tokens' })
  @ApiResponse({ status: 200, description: 'OTP verified successfully, returns JWT and user profile' })
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtp(dto);
  }

  @Post('firebase-login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Exchange Firebase client ID token for backend JWT tokens' })
  @ApiResponse({ status: 200, description: 'Firebase token verified, returns backend JWT and user profile' })
  async firebaseLogin(@Body() dto: VerifyFirebaseTokenDto) {
    return this.authService.verifyFirebaseToken(dto);
  }

  @Post('admin/login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Admin email/password login, returns JWT with role admin' })
  @ApiResponse({ status: 200, description: 'Admin authenticated successfully' })
  async adminLogin(@Body() dto: AdminLoginDto) {
    return this.authService.adminLogin(dto);
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Refresh expired access token using refresh token' })
  @ApiResponse({ status: 200, description: 'New access token issued' })
  async refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refreshToken(dto.refreshToken);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get current logged-in user profile and wallet' })
  @ApiResponse({ status: 200, description: 'Returns authenticated user info' })
  async getMe(@CurrentUser('userId') userId: string) {
    return this.authService.getProfile(userId);
  }
}

