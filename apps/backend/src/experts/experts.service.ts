import { Injectable, NotFoundException } from '@nestjs/common';
import { KycStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';
import { SubmitKycDto } from './dto/submit-kyc.dto.js';

@Injectable()
export class ExpertsService {
  constructor(private readonly prisma: PrismaService) {}

  async submitKyc(userId: string, dto: SubmitKycDto) {
    const profile = await this.prisma.expertProfile.upsert({
      where: { userId },
      update: {
        name: dto.name,
        email: dto.email,
        bio: dto.bio,
        experienceYears: dto.experienceYears,
        languages: dto.languages,
        expertise: dto.expertise,
        idProofType: dto.idProofType,
        idProofNumber: dto.idProofNumber,
        payoutUpiId: dto.payoutUpiId,
        chatRateInPaise: BigInt(dto.chatRateInPaise),
        callRateInPaise: BigInt(dto.callRateInPaise),
        videoRateInPaise: BigInt(dto.videoRateInPaise),
        kycStatus: KycStatus.PENDING,
        rejectionReason: null,
      },
      create: {
        userId,
        name: dto.name,
        email: dto.email,
        bio: dto.bio,
        experienceYears: dto.experienceYears,
        languages: dto.languages,
        expertise: dto.expertise,
        idProofType: dto.idProofType,
        idProofNumber: dto.idProofNumber,
        payoutUpiId: dto.payoutUpiId,
        chatRateInPaise: BigInt(dto.chatRateInPaise),
        callRateInPaise: BigInt(dto.callRateInPaise),
        videoRateInPaise: BigInt(dto.videoRateInPaise),
        kycStatus: KycStatus.PENDING,
      },
      include: {
        user: {
          select: {
            id: true,
            phoneNumber: true,
            role: true,
          },
        },
      },
    });

    return this.serializeProfile(profile);
  }

  async getMyProfile(userId: string) {
    const profile = await this.prisma.expertProfile.findUnique({
      where: { userId },
      include: {
        user: {
          select: {
            id: true,
            phoneNumber: true,
            role: true,
          },
        },
      },
    });

    if (!profile) {
      return null;
    }

    return this.serializeProfile(profile);
  }

  private serializeProfile(profile: any) {
    return {
      ...profile,
      chatRateInPaise: profile.chatRateInPaise.toString(),
      callRateInPaise: profile.callRateInPaise.toString(),
      videoRateInPaise: profile.videoRateInPaise.toString(),
    };
  }
}
