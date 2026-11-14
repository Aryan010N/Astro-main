export type UserRole = 'user' | 'expert' | 'admin' | 'support_agent';

export type KycStatus = 'PENDING' | 'APPROVED' | 'REJECTED';

export type TransactionType =
  | 'RECHARGE'
  | 'SESSION_CHARGE'
  | 'SESSION_REFUND'
  | 'COMMISSION_EARNING'
  | 'PAYOUT'
  | 'MANUAL_ADJUSTMENT';

export type TransactionStatus = 'PENDING' | 'SUCCESS' | 'FAILED' | 'REVERSED';

export type PaymentOrderStatus = 'CREATED' | 'ATTEMPTED' | 'PAID' | 'FAILED';

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
  totalConsultations?: number;
  rating?: number;
  missedRequests?: number;
  presenceStatus?: 'ONLINE' | 'OFFLINE' | 'BUSY';
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

// Phase 3 — Wallet & Payment Contracts
export interface CreateRechargeOrderDto {
  amountInPaise: number;
}

export interface RechargeOrderResponseDto {
  orderId: string;
  amountInPaise: number;
  amountInRupees: number;
  currency: string;
  keyId: string;
  receipt: string;
}

export interface WalletTransactionDto {
  id: string;
  walletId: string;
  amountInPaise: string;
  amountInRupees: number;
  type: TransactionType;
  status: TransactionStatus;
  runningBalanceSnapshot: string;
  runningBalanceInRupees: number;
  referenceId?: string | null;
  description?: string | null;
  createdAt: string;
}

export interface WalletTransactionsResponseDto {
  balanceInPaise: string;
  balanceInRupees: number;
  currency: string;
  transactions: WalletTransactionDto[];
}

export interface SimulatePaymentDto {
  orderId: string;
  status: 'captured' | 'failed';
  paymentId?: string;
}

// ==========================================
// Phase 4 — Session & Presence Contracts
// ==========================================

export type ExpertPresenceStatus = 'ONLINE' | 'OFFLINE' | 'BUSY';

export type SessionStatus =
  | 'REQUESTED'
  | 'ACCEPTED'
  | 'CANCELLED'
  | 'CONNECTING'
  | 'ACTIVE'
  | 'RECONNECTING'
  | 'ENDED'
  | 'FORCE_ENDED'
  | 'BILLED'
  | 'SUMMARY_SHOWN';

export type SessionType = 'CHAT' | 'AUDIO' | 'VIDEO';

export interface RequestSessionDto {
  expertId: string;
  sessionType?: SessionType;
}

export interface SessionResponseDto {
  id: string;
  userId: string;
  expertId: string;
  sessionType: SessionType;
  status: SessionStatus;
  rateInPaise: string;
  rateInRupees: number;
  durationSeconds: number;
  totalBilledPaise: string;
  totalBilledRupees: number;
  requestedAt: string;
  acceptedAt?: string | null;
  startedAt?: string | null;
  endedAt?: string | null;
  endReason?: string | null;
  user?: UserDto;
  expert?: ExpertProfileDto;
}

export interface SessionSummaryDto {
  sessionId: string;
  durationSeconds: number;
  totalBilledPaise: string;
  totalBilledRupees: number;
  ratePerMinuteRupees: number;
  startedAt?: string | null;
  endedAt: string;
  endReason: string;
}

export interface ChatMessageDto {
  id: string;
  sessionId: string;
  senderId: string;
  senderRole: string;
  text: string;
  createdAt: string;
}

export interface PresenceUpdateEventDto {
  expertId: string;
  status: ExpertPresenceStatus;
}
