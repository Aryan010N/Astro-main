import { ApiProperty } from '@nestjs/swagger';
import {
  IsArray,
  IsEmail,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class SubmitKycDto {
  @ApiProperty({ example: 'Pandit Sharma', description: 'Full legal name of the expert' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiProperty({ example: 'sharma@astrology.com', description: 'Contact email', required: false })
  @IsOptional()
  @IsEmail()
  email?: string;

  @ApiProperty({ example: 'Vedic Astrologer with 12 years of experience', required: false })
  @IsOptional()
  @IsString()
  bio?: string;

  @ApiProperty({ example: 12, description: 'Years of professional experience' })
  @IsInt()
  @Min(0)
  experienceYears: number;

  @ApiProperty({ example: ['Hindi', 'English', 'Sanskrit'], type: [String] })
  @IsArray()
  @IsString({ each: true })
  languages: string[];

  @ApiProperty({ example: ['Vedic Astrology', 'Kundli Matching', 'Numerology'], type: [String] })
  @IsArray()
  @IsString({ each: true })
  expertise: string[];

  @ApiProperty({ example: 'Aadhaar Card', description: 'Type of ID document' })
  @IsNotEmpty()
  @IsString()
  idProofType: string;

  @ApiProperty({ example: 'XXXX-XXXX-1234', description: 'ID document number' })
  @IsNotEmpty()
  @IsString()
  idProofNumber: string;

  @ApiProperty({ example: 'sharma@upi', description: 'UPI ID for earnings payout' })
  @IsNotEmpty()
  @IsString()
  payoutUpiId: string;

  @ApiProperty({ example: 2500, description: 'Per-minute chat rate in paise (e.g. ₹25/min = 2500 paise)' })
  @IsInt()
  @Min(100)
  chatRateInPaise: number;

  @ApiProperty({ example: 3000, description: 'Per-minute call rate in paise (e.g. ₹30/min = 3000 paise)' })
  @IsInt()
  @Min(100)
  callRateInPaise: number;

  @ApiProperty({ example: 5000, description: 'Per-minute video rate in paise (e.g. ₹50/min = 5000 paise)' })
  @IsInt()
  @Min(100)
  videoRateInPaise: number;
}
