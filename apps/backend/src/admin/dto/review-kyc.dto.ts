import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class ReviewKycDto {
  @ApiProperty({ example: 'Documents are unclear. Please upload clear photo ID.', required: false })
  @IsOptional()
  @IsString()
  rejectionReason?: string;
}
