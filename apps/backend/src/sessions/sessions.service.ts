import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import {
  KycStatus,
  SessionStatus,
  SessionType,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';
import { PresenceService } from './presence.service.js';
import { SessionLockService } from './session-lock.service.js';
import { BillingEngineService } from './billing-engine.service.js';

@Injectable()
export class SessionsService {
  private readonly logger = new Logger(SessionsService.name);
  private readonly requestTimeouts = new Map<string, NodeJS.Timeout>();
  private readonly readyParties = new Map<string, Set<string>>(); // sessionId -> set of userIds joined

  // Gateway notification hooks
  private emitToUserCallback?: (userId: string, event: string, payload: any) => void;
  private emitToExpertCallback?: (expertId: string, event: string, payload: any) => void;
  private emitToSessionCallback?: (sessionId: string, event: string, payload: any) => void;

  public requestTimeoutSeconds = Number(process.env.SESSION_REQUEST_TIMEOUT_SECONDS || 30); // 30-45 second hard timeout (Section 7A.4)

  constructor(
    private readonly prisma: PrismaService,
    private readonly presenceService: PresenceService,
    private readonly lockService: SessionLockService,
    private readonly billingEngine: BillingEngineService,
  ) {
    // Wire billing engine callbacks
    this.billingEngine.registerCallbacks(
      (tickData) => this.handleBillingTick(tickData),
      (sessionId, reason) => this.endSession(sessionId, 'SYSTEM', reason),
      (sessionId, state, reason) => this.handleBillingStateChange(sessionId, state, reason),
    );
  }

  setGatewayCallbacks(
    toUser: (userId: string, event: string, payload: any) => void,
    toExpert: (expertId: string, event: string, payload: any) => void,
    toSession: (sessionId: string, event: string, payload: any) => void,
  ) {
    this.emitToUserCallback = toUser;
    this.emitToExpertCallback = toExpert;
    this.emitToSessionCallback = toSession;
  }

  /**
   * User requests a 1:1 session with an expert (Section 7A.4)
   */
  async requestSession(userId: string, expertId: string, sessionType: SessionType = SessionType.CHAT) {
    // 1. Fetch expert profile
    const expert = await this.prisma.expertProfile.findUnique({
      where: { id: expertId },
      include: { user: true },
    });

    if (!expert || expert.kycStatus !== KycStatus.APPROVED || !expert.isLive) {
      throw new BadRequestException('Expert is not currently available for consultation');
    }

    // 2. Fetch user & check wallet balance
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { wallet: true },
    });

    if (!user || !user.wallet) {
      throw new BadRequestException('User wallet not initialized');
    }

    const rateInPaise =
      sessionType === SessionType.CHAT
        ? expert.chatRateInPaise
        : sessionType === SessionType.AUDIO
        ? expert.callRateInPaise
        : expert.videoRateInPaise;

    // Check minimum 1-minute balance requirement
    if (user.wallet.balanceInPaise < rateInPaise) {
      throw new BadRequestException(
        `Insufficient wallet balance. Minimum ₹${Number(rateInPaise) / 100} required to initiate consultation.`,
      );
    }

    // 3. Check presence & concurrency lock (Section 7A.4)
    const presence = await this.presenceService.getPresence(expertId);
    if (presence === 'BUSY') {
      throw new BadRequestException('Expert is currently busy in another consultation');
    }

    // Generate provisional session ID for lock acquisition
    const sessionId = (await this.prisma.consultationSession.create({
      data: {
        userId,
        expertId,
        sessionType,
        status: SessionStatus.REQUESTED,
        rateInPaise,
      },
    })).id;

    // Atomic distributed lock acquisition in Redis
    const lockAcquired = await this.lockService.acquireLock(expertId, sessionId);
    if (!lockAcquired) {
      await this.prisma.consultationSession.update({
        where: { id: sessionId },
        data: { status: SessionStatus.CANCELLED, endReason: 'EXPERT_BUSY' },
      });
      throw new BadRequestException('Expert is currently in an active consultation. Please try again shortly.');
    }

    // Set expert status to BUSY
    await this.presenceService.setPresence(expertId, 'BUSY');

    // 4. Start 30-45 second silent non-response timeout (Section 7A.4)
    const timer = setTimeout(() => {
      this.handleSilentTimeout(sessionId);
    }, this.requestTimeoutSeconds * 1000);
    this.requestTimeouts.set(sessionId, timer);

    // 5. Notify expert socket
    if (this.emitToExpertCallback) {
      this.emitToExpertCallback(expertId, 'session:incoming_request', {
        sessionId,
        userId: user.id,
        userName: user.name || 'Seeker',
        sessionType,
        rateInPaise: rateInPaise.toString(),
        rateInRupees: Number(rateInPaise) / 100,
        timeoutSeconds: this.requestTimeoutSeconds,
      });
    }

    this.logger.log(`Session requested: ${sessionId} by user ${userId} to expert ${expertId}`);
    return this.getSessionDetails(sessionId);
  }

  /**
   * Expert accepts session -> transitions to ACCEPTED -> CONNECTING
   */
  async acceptSession(expertUserId: string, sessionId: string) {
    const session = await this.prisma.consultationSession.findUnique({
      where: { id: sessionId },
      include: { expert: true },
    });

    if (!session || session.status !== SessionStatus.REQUESTED) {
      throw new BadRequestException('Session request is no longer valid or was cancelled');
    }

    if (session.expert.userId !== expertUserId && session.expertId !== expertUserId) {
      throw new UnauthorizedException('Not authorized to accept this consultation');
    }

    // Cancel timeout timer
    const timer = this.requestTimeouts.get(sessionId);
    if (timer) {
      clearTimeout(timer);
      this.requestTimeouts.delete(sessionId);
    }

    const updated = await this.prisma.consultationSession.update({
      where: { id: sessionId },
      data: {
        status: SessionStatus.CONNECTING,
        acceptedAt: new Date(),
      },
    });

    this.readyParties.set(sessionId, new Set<string>());

    // Notify both user and expert
    if (this.emitToUserCallback) {
      this.emitToUserCallback(session.userId, 'session:accepted', {
        sessionId,
        status: 'CONNECTING',
      });
    }
    if (this.emitToExpertCallback) {
      this.emitToExpertCallback(session.expertId, 'session:accepted', {
        sessionId,
        status: 'CONNECTING',
      });
    }

    this.logger.log(`Session accepted: ${sessionId}, transitioning to CONNECTING`);
    return this.serializeSession(updated);
  }

  /**
   * Expert rejects session -> transitions to CANCELLED
   */
  async rejectSession(expertUserId: string, sessionId: string, reason?: string) {
    const session = await this.prisma.consultationSession.findUnique({
      where: { id: sessionId },
      include: { expert: true },
    });

    if (!session) throw new NotFoundException('Session not found');

    const timer = this.requestTimeouts.get(sessionId);
    if (timer) {
      clearTimeout(timer);
      this.requestTimeouts.delete(sessionId);
    }

    await this.lockService.releaseLock(session.expertId, sessionId);
    await this.presenceService.setPresence(session.expertId, 'ONLINE');

    const updated = await this.prisma.consultationSession.update({
      where: { id: sessionId },
      data: {
        status: SessionStatus.CANCELLED,
        rejectionReason: reason || 'Expert declined the request',
        endReason: 'EXPERT_REJECTED',
        endedAt: new Date(),
      },
    });

    if (this.emitToUserCallback) {
      this.emitToUserCallback(session.userId, 'session:cancelled', {
        sessionId,
        reason: reason || 'Expert is currently unavailable to accept new sessions',
      });
    }

    return this.serializeSession(updated);
  }

  /**
   * Silent timeout: expert never responds within 30-45 sec (Section 7A.4)
   * Auto-cancels, zero wallet impact, and logs against expert's response-time metric!
   */
  private async handleSilentTimeout(sessionId: string) {
    const session = await this.prisma.consultationSession.findUnique({
      where: { id: sessionId },
    });

    if (!session || session.status !== SessionStatus.REQUESTED) return;

    this.requestTimeouts.delete(sessionId);

    // Release locks and reset presence
    await this.lockService.releaseLock(session.expertId, sessionId);
    await this.presenceService.setPresence(session.expertId, 'ONLINE');

    // Update expert metric: increment missedRequests
    await this.prisma.expertProfile.update({
      where: { id: session.expertId },
      data: {
        missedRequests: { increment: 1 },
      },
    });

    await this.prisma.consultationSession.update({
      where: { id: sessionId },
      data: {
        status: SessionStatus.CANCELLED,
        endReason: 'SILENT_TIMEOUT',
        endedAt: new Date(),
      },
    });

    this.logger.warn(`Session ${sessionId} timed out silently. Zero wallet impact. Logged against expert response metric.`);

    if (this.emitToUserCallback) {
      this.emitToUserCallback(session.userId, 'session:timeout', {
        sessionId,
        message: 'Expert did not respond in time. No charges incurred.',
      });
    }
  }

  /**
   * Client joins session room. When BOTH parties confirm join -> transition to ACTIVE
   * (Billing starts ONLY at ACTIVE per Section 7A.1 & 7A.3)
   */
  async confirmJoin(participantId: string, sessionId: string) {
    const session = await this.prisma.consultationSession.findUnique({
      where: { id: sessionId },
      include: { expert: true },
    });

    if (!session) return;

    let parties = this.readyParties.get(sessionId);
    if (!parties) {
      parties = new Set<string>();
      this.readyParties.set(sessionId, parties);
    }

    parties.add(participantId);

    // Check if both user and expert have joined
    const userJoined = parties.has(session.userId);
    const expertJoined = parties.has(session.expertId) || parties.has(session.expert.userId);

    if (userJoined && expertJoined && session.status === SessionStatus.CONNECTING) {
      const now = new Date();
      const activeSession = await this.prisma.consultationSession.update({
        where: { id: sessionId },
        data: {
          status: SessionStatus.ACTIVE,
          startedAt: now,
        },
      });

      // Start the per-second billing engine NOW
      this.billingEngine.startBilling(
        sessionId,
        session.userId,
        session.expertId,
        Number(session.rateInPaise),
      );

      if (this.emitToSessionCallback) {
        this.emitToSessionCallback(sessionId, 'session:started', {
          sessionId,
          status: 'ACTIVE',
          startedAt: now.toISOString(),
          rateInRupees: Number(session.rateInPaise) / 100,
        });
      }

      this.logger.log(`Both parties confirmed present. Session ${sessionId} is now ACTIVE! Billing engine started.`);
      return this.serializeSession(activeSession);
    }
  }

  /**
   * Handle socket disconnect during ACTIVE session -> transition to RECONNECTING
   */
  async handleDisconnect(participantId: string, sessionId: string) {
    const session = this.billingEngine.getActiveContext(sessionId);
    if (session && session.status === 'ACTIVE') {
      this.billingEngine.handleDisconnect(sessionId);

      await this.prisma.consultationSession.update({
        where: { id: sessionId },
        data: { status: SessionStatus.RECONNECTING },
      }).catch((err) => {
        this.logger.error(`Error updating session status to RECONNECTING: ${err.message}`);
      });

      if (this.emitToSessionCallback) {
        this.emitToSessionCallback(sessionId, 'session:reconnecting', {
          sessionId,
          graceWindowSeconds: this.billingEngine.graceWindowSeconds,
        });
      }
    }
  }

  /**
   * Handle socket reconnect during grace window
   */
  async handleReconnect(participantId: string, sessionId: string): Promise<boolean> {
    const reconnected = this.billingEngine.handleReconnect(sessionId);
    if (reconnected) {
      await this.prisma.consultationSession.update({
        where: { id: sessionId },
        data: { status: SessionStatus.ACTIVE },
      }).catch((err) => {
        this.logger.error(`Error updating session status to ACTIVE upon reconnect: ${err.message}`);
      });

      if (this.emitToSessionCallback) {
        this.emitToSessionCallback(sessionId, 'session:reconnected', {
          sessionId,
          status: 'ACTIVE',
        });
      }
      return true;
    }
    return false;
  }

  /**
   * End session -> BILLED -> SUMMARY_SHOWN
   */
  async endSession(sessionId: string, endedBy: string, reason = 'USER_ENDED') {
    const session = await this.prisma.consultationSession.findUnique({
      where: { id: sessionId },
      include: { expert: true },
    });

    if (!session) return;
    if (session.status === SessionStatus.ENDED || session.status === SessionStatus.BILLED) {
      return this.getSessionSummary(sessionId);
    }

    const { durationSeconds, totalBilledPaise } = this.billingEngine.stopBilling(sessionId);
    this.readyParties.delete(sessionId);

    // Release locks & restore presence
    await this.lockService.releaseLock(session.expertId, sessionId);
    await this.presenceService.setPresence(session.expertId, 'ONLINE');

    const now = new Date();
    const finalStatus = reason === 'FORCE_ENDED' ? SessionStatus.FORCE_ENDED : SessionStatus.ENDED;

    const updated = await this.prisma.consultationSession.update({
      where: { id: sessionId },
      data: {
        status: finalStatus,
        durationSeconds,
        totalBilledPaise: BigInt(totalBilledPaise),
        endedAt: now,
        endReason: reason,
      },
    });

    // Increment expert total consultations
    await this.prisma.expertProfile.update({
      where: { id: session.expertId },
      data: { totalConsultations: { increment: 1 } },
    });

    const summary = {
      sessionId,
      durationSeconds,
      totalBilledPaise: totalBilledPaise.toString(),
      totalBilledRupees: totalBilledPaise / 100,
      ratePerMinuteRupees: Number(session.rateInPaise) / 100,
      startedAt: session.startedAt?.toISOString() || null,
      endedAt: now.toISOString(),
      endReason: reason,
    };

    if (this.emitToSessionCallback) {
      this.emitToSessionCallback(sessionId, 'session:summary', summary);
    }

    this.logger.log(`Session ${sessionId} finalized. Duration: ${durationSeconds}s, Total Billed: ₹${totalBilledPaise / 100}`);
    return summary;
  }

  /**
   * Chat message handling
   */
  async sendMessage(sessionId: string, senderId: string, senderRole: string, text: string) {
    const msg = await this.prisma.sessionMessage.create({
      data: {
        sessionId,
        senderId,
        senderRole,
        text,
      },
    });

    // Update lastMessageAt to prevent or resume idle timeout
    this.billingEngine.recordMessageActivity(sessionId);

    if (this.emitToSessionCallback) {
      this.emitToSessionCallback(sessionId, 'chat:message', {
        id: msg.id,
        sessionId,
        senderId,
        senderRole,
        text,
        createdAt: msg.createdAt.toISOString(),
      });
    }

    return msg;
  }

  private handleBillingTick(tickData: any) {
    // Update running duration & total billed in database periodically
    this.prisma.consultationSession.update({
      where: { id: tickData.sessionId },
      data: {
        totalBilledPaise: BigInt(tickData.totalBilledPaise),
        durationSeconds: { increment: tickData.elapsedSeconds },
      },
    }).catch(() => {});

    if (this.emitToSessionCallback) {
      this.emitToSessionCallback(tickData.sessionId, 'session:billing_tick', {
        sessionId: tickData.sessionId,
        elapsedSeconds: tickData.elapsedSeconds,
        tickBilledPaise: tickData.tickBilledPaise,
        totalBilledPaise: tickData.totalBilledPaise,
        totalBilledRupees: tickData.totalBilledPaise / 100,
        remainingBalancePaise: tickData.remainingBalancePaise,
        remainingBalanceRupees: Number(tickData.remainingBalancePaise) / 100,
      });
    }
  }

  private handleBillingStateChange(sessionId: string, state: 'paused' | 'resumed', reason: string) {
    if (this.emitToSessionCallback) {
      this.emitToSessionCallback(sessionId, `session:billing_${state}`, {
        sessionId,
        reason,
        timestamp: new Date().toISOString(),
      });
    }
  }

  async getSessionDetails(sessionId: string) {
    const session = await this.prisma.consultationSession.findUnique({
      where: { id: sessionId },
      include: {
        user: { select: { id: true, name: true, phoneNumber: true } },
        expert: true,
      },
    });

    if (!session) throw new NotFoundException('Session not found');
    return this.serializeSession(session);
  }

  async getSessionMessages(sessionId: string) {
    return this.prisma.sessionMessage.findMany({
      where: { sessionId },
      orderBy: { createdAt: 'asc' },
    });
  }

  async getSessionSummary(sessionId: string) {
    const session = await this.prisma.consultationSession.findUnique({
      where: { id: sessionId },
    });

    if (!session) throw new NotFoundException('Session not found');

    return {
      sessionId: session.id,
      durationSeconds: session.durationSeconds,
      totalBilledPaise: session.totalBilledPaise.toString(),
      totalBilledRupees: Number(session.totalBilledPaise) / 100,
      ratePerMinuteRupees: Number(session.rateInPaise) / 100,
      startedAt: session.startedAt?.toISOString() || null,
      endedAt: session.endedAt?.toISOString() || new Date().toISOString(),
      endReason: session.endReason || 'ENDED',
    };
  }

  async getActiveSessionForUser(userId: string) {
    const session = await this.prisma.consultationSession.findFirst({
      where: {
        OR: [
          { userId, status: { in: [SessionStatus.REQUESTED, SessionStatus.ACCEPTED, SessionStatus.CONNECTING, SessionStatus.ACTIVE, SessionStatus.RECONNECTING] } },
          { expert: { userId }, status: { in: [SessionStatus.REQUESTED, SessionStatus.ACCEPTED, SessionStatus.CONNECTING, SessionStatus.ACTIVE, SessionStatus.RECONNECTING] } },
        ],
      },
      include: {
        user: { select: { id: true, name: true, phoneNumber: true } },
        expert: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    return session ? this.serializeSession(session) : null;
  }

  async getApprovedExpertsWithPresence() {
    const experts = await this.prisma.expertProfile.findMany({
      where: { kycStatus: KycStatus.APPROVED, isLive: true },
      include: { user: { select: { id: true, phoneNumber: true, name: true } } },
      orderBy: { rating: 'desc' },
    });

    const presences = await this.presenceService.getAllOnlineExperts();

    return experts.map((e) => ({
      id: e.id,
      userId: e.userId,
      name: e.name,
      bio: e.bio,
      experienceYears: e.experienceYears,
      languages: e.languages,
      expertise: e.expertise,
      chatRateInPaise: e.chatRateInPaise.toString(),
      chatRateInRupees: Number(e.chatRateInPaise) / 100,
      callRateInPaise: e.callRateInPaise.toString(),
      videoRateInPaise: e.videoRateInPaise.toString(),
      rating: e.rating,
      totalConsultations: e.totalConsultations,
      missedRequests: e.missedRequests,
      presenceStatus: presences[e.id] || 'OFFLINE',
      user: e.user,
    }));
  }

  private serializeSession(session: any) {
    return {
      ...session,
      rateInPaise: session.rateInPaise.toString(),
      rateInRupees: Number(session.rateInPaise) / 100,
      totalBilledPaise: session.totalBilledPaise.toString(),
      totalBilledRupees: Number(session.totalBilledPaise) / 100,
    };
  }
}
