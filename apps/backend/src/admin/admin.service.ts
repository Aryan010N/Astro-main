import { Injectable, NotFoundException } from '@nestjs/common';
import { KycStatus, UserRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  async getPendingExperts() {
    const list = await this.prisma.expertProfile.findMany({
      where: { kycStatus: KycStatus.PENDING },
      include: {
        user: {
          select: {
            id: true,
            phoneNumber: true,
            role: true,
            createdAt: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return list.map((p) => this.serializeProfile(p));
  }

  async getAllExperts() {
    const list = await this.prisma.expertProfile.findMany({
      include: {
        user: {
          select: {
            id: true,
            phoneNumber: true,
            role: true,
            createdAt: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return list.map((p) => this.serializeProfile(p));
  }

  async approveExpert(id: string) {
    const profile = await this.prisma.expertProfile.findUnique({
      where: { id },
    });

    if (!profile) {
      throw new NotFoundException(`Expert profile with ID ${id} not found`);
    }

    // Elevate user role to EXPERT
    await this.prisma.user.update({
      where: { id: profile.userId },
      data: { role: UserRole.EXPERT },
    });

    // Update profile to APPROVED and live
    const updated = await this.prisma.expertProfile.update({
      where: { id },
      data: {
        kycStatus: KycStatus.APPROVED,
        isLive: true,
        rejectionReason: null,
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

    return this.serializeProfile(updated);
  }

  async rejectExpert(id: string, reason?: string) {
    const profile = await this.prisma.expertProfile.findUnique({
      where: { id },
    });

    if (!profile) {
      throw new NotFoundException(`Expert profile with ID ${id} not found`);
    }

    const updated = await this.prisma.expertProfile.update({
      where: { id },
      data: {
        kycStatus: KycStatus.REJECTED,
        isLive: false,
        rejectionReason: reason || 'Application rejected by administration',
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

    return this.serializeProfile(updated);
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
