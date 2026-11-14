import { Injectable, Logger } from '@nestjs/common';
import { RedisService } from '../redis/redis.service.js';

@Injectable()
export class SessionLockService {
  private readonly logger = new Logger(SessionLockService.name);

  constructor(private readonly redis: RedisService) {}

  /**
   * Acquire atomic distributed lock on expert
   * Prevents two simultaneous session requests from double-accepting
   */
  async acquireLock(expertId: string, sessionId: string, ttlSeconds = 3600): Promise<boolean> {
    const key = `expert:lock:${expertId}`;
    const acquired = await this.redis.setNx(key, sessionId, ttlSeconds);
    if (acquired) {
      this.logger.log(`Lock acquired on expert ${expertId} for session ${sessionId}`);
    } else {
      this.logger.warn(`Failed to acquire lock on expert ${expertId} (already locked)`);
    }
    return acquired;
  }

  /**
   * Release lock only if held by this sessionId
   */
  async releaseLock(expertId: string, sessionId: string): Promise<boolean> {
    const key = `expert:lock:${expertId}`;
    const currentHolder = await this.redis.get(key);
    if (currentHolder === sessionId) {
      await this.redis.del(key);
      this.logger.log(`Lock released on expert ${expertId} by session ${sessionId}`);
      return true;
    }
    return false;
  }

  async isLocked(expertId: string): Promise<boolean> {
    const key = `expert:lock:${expertId}`;
    const holder = await this.redis.get(key);
    return holder !== null;
  }
}
