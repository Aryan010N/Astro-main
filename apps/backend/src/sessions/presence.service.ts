import { Injectable, Logger } from '@nestjs/common';
import { RedisService } from '../redis/redis.service.js';

export type PresenceStatus = 'ONLINE' | 'OFFLINE' | 'BUSY';

@Injectable()
export class PresenceService {
  private readonly logger = new Logger(PresenceService.name);
  private onPresenceChangeCallback?: (expertId: string, status: PresenceStatus) => void;

  constructor(private readonly redis: RedisService) {}

  registerChangeListener(cb: (expertId: string, status: PresenceStatus) => void) {
    this.onPresenceChangeCallback = cb;
  }

  async setPresence(expertId: string, status: PresenceStatus, ttlSeconds = 86400): Promise<void> {
    const key = `expert:presence:${expertId}`;
    if (status === 'OFFLINE') {
      await this.redis.del(key);
    } else {
      await this.redis.set(key, status, ttlSeconds);
    }

    this.logger.log(`Expert presence updated: ${expertId} -> ${status}`);

    if (this.onPresenceChangeCallback) {
      this.onPresenceChangeCallback(expertId, status);
    }
  }

  async getPresence(expertId: string): Promise<PresenceStatus> {
    const key = `expert:presence:${expertId}`;
    const status = await this.redis.get(key);
    return (status as PresenceStatus) || 'OFFLINE';
  }

  async getAllOnlineExperts(): Promise<Record<string, PresenceStatus>> {
    const keys = await this.redis.keys('expert:presence:*');
    const result: Record<string, PresenceStatus> = {};

    for (const key of keys) {
      const expertId = key.replace('expert:presence:', '');
      const status = await this.redis.get(key);
      if (status) {
        result[expertId] = status as PresenceStatus;
      }
    }

    return result;
  }
}
