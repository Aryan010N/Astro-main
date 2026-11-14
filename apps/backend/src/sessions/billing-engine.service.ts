import { Injectable, Logger } from '@nestjs/common';
import { TransactionType } from '@prisma/client';
import { WalletService } from '../wallet/wallet.service.js';

export interface ActiveSessionContext {
  sessionId: string;
  userId: string;
  expertId: string;
  rateInPaisePerMinute: number;
  status: 'ACTIVE' | 'RECONNECTING';
  startedAt: number; // ms timestamp
  lastTickAt: number; // ms timestamp
  lastMessageAt: number; // ms timestamp
  totalBilledPaise: number;
  totalDurationSeconds: number;
  isBillingPaused: boolean;
  pauseReason?: string;
  graceTimer?: NodeJS.Timeout;
}

@Injectable()
export class BillingEngineService {
  private readonly logger = new Logger(BillingEngineService.name);
  private readonly activeSessions = new Map<string, ActiveSessionContext>();
  private tickerInterval?: NodeJS.Timeout;

  // Configurable defaults (Section 7A spec: 5-10s ticks, 3m idle timeout, 15-20s grace window)
  public tickIntervalSeconds = Number(process.env.SESSION_TICK_SECONDS || 5);
  public idleTimeoutSeconds = Number(process.env.SESSION_IDLE_TIMEOUT_SECONDS || 180);
  public graceWindowSeconds = Number(process.env.SESSION_GRACE_WINDOW_SECONDS || 20);

  private onBillingTickCallback?: (data: {
    sessionId: string;
    elapsedSeconds: number;
    tickBilledPaise: number;
    totalBilledPaise: number;
    remainingBalancePaise: string;
  }) => void;

  private onSessionEndCallback?: (sessionId: string, reason: string) => void;
  private onBillingStateChangeCallback?: (sessionId: string, state: 'paused' | 'resumed', reason: string) => void;

  constructor(private readonly walletService: WalletService) {
    this.startTicker();
  }

  registerCallbacks(
    onTick: (data: any) => void,
    onEnd: (sessionId: string, reason: string) => void,
    onStateChange: (sessionId: string, state: 'paused' | 'resumed', reason: string) => void,
  ) {
    this.onBillingTickCallback = onTick;
    this.onSessionEndCallback = onEnd;
    this.onBillingStateChangeCallback = onStateChange;
  }

  private startTicker() {
    this.tickerInterval = setInterval(() => {
      this.executeTick();
    }, 1000); // 1-second interval checks all active sessions
  }

  /**
   * Start billing when session transitions to ACTIVE
   * (Media/Chat confirmed present on both sides per Section 7A.1 & 7A.3)
   */
  startBilling(sessionId: string, userId: string, expertId: string, rateInPaisePerMinute: number) {
    const now = Date.now();
    const ctx: ActiveSessionContext = {
      sessionId,
      userId,
      expertId,
      rateInPaisePerMinute,
      status: 'ACTIVE',
      startedAt: now,
      lastTickAt: now,
      lastMessageAt: now,
      totalBilledPaise: 0,
      totalDurationSeconds: 0,
      isBillingPaused: false,
    };

    this.activeSessions.set(sessionId, ctx);
    this.logger.log(`Billing started for session ${sessionId} at ₹${rateInPaisePerMinute / 100}/min`);
  }

  /**
   * Stop billing when session terminates
   */
  stopBilling(sessionId: string): { durationSeconds: number; totalBilledPaise: number } {
    const ctx = this.activeSessions.get(sessionId);
    if (!ctx) {
      return { durationSeconds: 0, totalBilledPaise: 0 };
    }

    if (ctx.graceTimer) {
      clearTimeout(ctx.graceTimer);
    }

    this.activeSessions.delete(sessionId);
    this.logger.log(`Billing stopped for session ${sessionId}. Total duration: ${ctx.totalDurationSeconds}s, Billed: ₹${ctx.totalBilledPaise / 100}`);

    return {
      durationSeconds: ctx.totalDurationSeconds,
      totalBilledPaise: ctx.totalBilledPaise,
    };
  }

  /**
   * Client disconnect detected mid-session -> enter RECONNECTING and pause billing
   * Section 7A.4 Reconnection Grace Window
   */
  handleDisconnect(sessionId: string) {
    const ctx = this.activeSessions.get(sessionId);
    if (!ctx || ctx.status !== 'ACTIVE') return;

    ctx.status = 'RECONNECTING';
    ctx.isBillingPaused = true;
    ctx.pauseReason = 'RECONNECTING';
    this.logger.log(`Session ${sessionId} entered RECONNECTING. Billing paused for grace window (${this.graceWindowSeconds}s).`);

    if (this.onBillingStateChangeCallback) {
      this.onBillingStateChangeCallback(sessionId, 'paused', 'RECONNECTING');
    }

    // Set grace countdown
    ctx.graceTimer = setTimeout(() => {
      this.logger.warn(`Grace window expired for session ${sessionId}. Force-ending.`);
      if (this.onSessionEndCallback) {
        this.onSessionEndCallback(sessionId, 'FORCE_ENDED');
      }
    }, this.graceWindowSeconds * 1000);
  }

  /**
   * Client reconnected within grace window -> resume ACTIVE billing
   */
  handleReconnect(sessionId: string): boolean {
    const ctx = this.activeSessions.get(sessionId);
    if (!ctx || ctx.status !== 'RECONNECTING') return false;

    if (ctx.graceTimer) {
      clearTimeout(ctx.graceTimer);
      ctx.graceTimer = undefined;
    }

    ctx.status = 'ACTIVE';
    ctx.isBillingPaused = false;
    ctx.pauseReason = undefined;
    ctx.lastTickAt = Date.now(); // reset tick baseline so no back-billing for disconnect duration

    this.logger.log(`Session ${sessionId} reconnected! Resumed ACTIVE billing.`);

    if (this.onBillingStateChangeCallback) {
      this.onBillingStateChangeCallback(sessionId, 'resumed', 'RECONNECTED');
    }

    return true;
  }

  /**
   * Record new chat message for idle detection
   */
  recordMessageActivity(sessionId: string) {
    const ctx = this.activeSessions.get(sessionId);
    if (!ctx) return;

    ctx.lastMessageAt = Date.now();

    // If session was paused due to chat idle timeout, resume it now!
    if (ctx.isBillingPaused && ctx.pauseReason === 'IDLE_TIMEOUT' && ctx.status === 'ACTIVE') {
      ctx.isBillingPaused = false;
      ctx.pauseReason = undefined;
      ctx.lastTickAt = Date.now();
      this.logger.log(`Message activity resumed billing for idle session ${sessionId}`);

      if (this.onBillingStateChangeCallback) {
        this.onBillingStateChangeCallback(sessionId, 'resumed', 'MESSAGE_ACTIVITY');
      }
    }
  }

  /**
   * Process periodic billing ticks across all active sessions
   */
  private async executeTick() {
    const now = Date.now();

    for (const [sessionId, ctx] of this.activeSessions.entries()) {
      if (ctx.status !== 'ACTIVE') continue;

      // Check Idle Timeout (Chat only: Section 7A.3)
      const idleElapsedSec = (now - ctx.lastMessageAt) / 1000;
      if (idleElapsedSec >= this.idleTimeoutSeconds && !ctx.isBillingPaused) {
        ctx.isBillingPaused = true;
        ctx.pauseReason = 'IDLE_TIMEOUT';
        this.logger.log(`Session ${sessionId} has been idle for ${Math.round(idleElapsedSec)}s. Billing paused.`);

        if (this.onBillingStateChangeCallback) {
          this.onBillingStateChangeCallback(sessionId, 'paused', 'IDLE_TIMEOUT');
        }
        continue;
      }

      if (ctx.isBillingPaused) continue;

      // Check if tick interval elapsed
      const elapsedSinceLastTick = (now - ctx.lastTickAt) / 1000;
      if (elapsedSinceLastTick < this.tickIntervalSeconds) continue;

      // Execute deduction
      const elapsedSeconds = Math.round(elapsedSinceLastTick);
      ctx.lastTickAt = now;
      ctx.totalDurationSeconds += elapsedSeconds;

      // Calculate charge: per-second granularity
      const paisePerSecond = ctx.rateInPaisePerMinute / 60;
      const tickBilledPaise = Math.ceil(paisePerSecond * elapsedSeconds);

      try {
        const deductResult = await this.walletService.deductBalance(
          ctx.userId,
          tickBilledPaise,
          TransactionType.SESSION_CHARGE,
          sessionId,
          `Consultation billing tick (${elapsedSeconds}s @ ₹${ctx.rateInPaisePerMinute / 100}/min)`,
        );

        ctx.totalBilledPaise += tickBilledPaise;

        if (this.onBillingTickCallback) {
          this.onBillingTickCallback({
            sessionId,
            elapsedSeconds,
            tickBilledPaise,
            totalBilledPaise: ctx.totalBilledPaise,
            remainingBalancePaise: deductResult.balanceInPaise,
          });
        }
      } catch (err: any) {
        this.logger.warn(`Wallet deduction failed for session ${sessionId}: ${err.message}`);
        // Wallet exhausted: auto-end session per Section 7A.4
        if (this.onSessionEndCallback) {
          this.onSessionEndCallback(sessionId, 'WALLET_EXHAUSTED');
        }
      }
    }
  }

  getActiveContext(sessionId: string): ActiveSessionContext | undefined {
    return this.activeSessions.get(sessionId);
  }

  destroy() {
    if (this.tickerInterval) {
      clearInterval(this.tickerInterval);
    }
    for (const ctx of this.activeSessions.values()) {
      if (ctx.graceTimer) clearTimeout(ctx.graceTimer);
    }
    this.activeSessions.clear();
  }
}
