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

// ==========================================
// Phase 3 — Wallet & Payment Contracts
// ==========================================

export interface CreateRechargeOrderDto {
  amountInPaise: number; // e.g. 50000 paise = ₹500
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
