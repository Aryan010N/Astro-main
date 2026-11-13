import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString, MinLength } from 'class-validator';

export class AdminLoginDto {
  @ApiProperty({ example: 'admin@astro.com', description: 'Admin email address' })
  @IsNotEmpty()
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'admin123', description: 'Admin account password' })
  @IsNotEmpty()
  @IsString()
  @MinLength(6)
  password: string;
}
