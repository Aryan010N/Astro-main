import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class VerifyFirebaseTokenDto {
  @ApiProperty({
    description: 'Firebase ID token issued after client-side Phone Auth verification',
  })
  @IsNotEmpty()
  @IsString()
  idToken: string;
}

