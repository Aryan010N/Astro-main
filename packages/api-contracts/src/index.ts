export type UserRole = 'user' | 'expert' | 'admin' | 'support_agent';

export type KycStatus = 'PENDING' | 'APPROVED' | 'REJECTED';

export interface UserDto {
  id: string;
  phoneNumber: string;
  role: UserRole;
  name?: string | null;
  avatarUrl?: string | null;
  createdAt?: string;
}

export interface WalletDto {
  id: string;
  userId: string;
  balanceInPaise: string;
  currency: string;
}

export interface AuthResponseDto {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  expiresIn: number;
  user: UserDto & { wallet?: WalletDto | null };
}

export interface ExpertProfileDto {
  id: string;
  userId: string;
  name: string;
  email?: string | null;
  bio?: string | null;
  experienceYears: number;
  languages: string[];
  expertise: string[];
  idProofType?: string | null;
  idProofNumber?: string | null;
  idProofUrl?: string | null;
  payoutUpiId?: string | null;
  chatRateInPaise: string;
  callRateInPaise: string;
  videoRateInPaise: string;
  kycStatus: KycStatus;
  rejectionReason?: string | null;
  isLive: boolean;
  createdAt: string;
  updatedAt: string;
  user?: UserDto;
}

export interface SubmitKycDto {
  name: string;
  email?: string;
  bio?: string;
  experienceYears: number;
  languages: string[];
  expertise: string[];
  idProofType: string;
  idProofNumber: string;
  payoutUpiId: string;
  chatRateInPaise: number;
  callRateInPaise: number;
  videoRateInPaise: number;
}

export interface ReviewKycDto {
  action: 'APPROVE' | 'REJECT';
  rejectionReason?: string;
}
