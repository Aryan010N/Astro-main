import { ApiProperty } from '@nestjs/swagger';
import { IsInt, Min, Max } from 'class-validator';

export class CreateRechargeOrderDto {
  @ApiProperty({
    example: 50000,
    description: 'Recharge amount in integer paise (e.g. ₹500 = 50000 paise). Min: ₹50 (5000), Max: ₹50,000 (5000000)',
  })
  @IsInt()
  @Min(5000, { message: 'Minimum recharge amount is ₹50 (5,000 paise)' })
  @Max(5000000, { message: 'Maximum recharge amount is ₹50,000 (5,000,000 paise)' })
  amountInPaise: number;
}
