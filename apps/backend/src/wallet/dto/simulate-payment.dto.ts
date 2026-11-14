import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class SimulatePaymentDto {
  @ApiProperty({ example: 'order_mock_123456', description: 'Razorpay order ID to simulate payment for' })
  @IsNotEmpty()
  @IsString()
  orderId: string;

  @ApiProperty({ example: 'captured', enum: ['captured', 'failed'], description: 'Simulated payment outcome' })
  @IsIn(['captured', 'failed'])
  status: 'captured' | 'failed';

  @ApiProperty({ example: 'pay_mock_789012', required: false, description: 'Optional simulated payment ID' })
  @IsOptional()
  @IsString()
  paymentId?: string;
}
