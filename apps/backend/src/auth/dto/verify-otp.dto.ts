import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, Length, Matches } from 'class-validator';

export class VerifyOtpDto {
  @ApiProperty({
    example: '+919999999999',
    description: 'Phone number in E.164 format',
  })
  @IsNotEmpty()
  @IsString()
  @Matches(/^\+[1-9]\d{6,14}$/, {
    message: 'Phone number must be in E.164 format (e.g. +919999999999)',
  })
  phoneNumber: string;

  @ApiProperty({
    example: 'req_1234567890',
    description: 'Request identifier returned by POST /auth/otp/request',
  })
  @IsNotEmpty()
  @IsString()
  requestId: string;

  @ApiProperty({
    example: '123456',
    description: '6-digit OTP code',
  })
  @IsNotEmpty()
  @IsString()
  @Length(4, 6)
  otp: string;
}

