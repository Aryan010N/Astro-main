import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, Matches } from 'class-validator';

export class RequestOtpDto {
  @ApiProperty({
    example: '+919999999999',
    description: 'Phone number in E.164 international format (with country code)',
  })
  @IsNotEmpty()
  @IsString()
  @Matches(/^\+[1-9]\d{6,14}$/, {
    message: 'Phone number must be a valid international number in E.164 format (e.g. +919999999999)',
  })
  phoneNumber: string;
}

