import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class DeductBalanceDto {
  @ApiProperty({ example: 2500, description: 'Amount to deduct in paise (e.g. ₹25 = 2500 paise)' })
  @IsInt()
  @Min(1)
  amountInPaise: number;

  @ApiProperty({ example: 'sess_12345', required: false, description: 'Consultation session or reference ID' })
  @IsOptional()
  @IsString()
  referenceId?: string;

  @ApiProperty({ example: '1 min chat consultation with Acharya Sharma', required: false })
  @IsOptional()
  @IsString()
  description?: string;
}
