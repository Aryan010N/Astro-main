import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service.js';
import { SessionsService } from './sessions.service.js';
import { PresenceService, PresenceStatus } from './presence.service.js';

@WebSocketGateway({
  cors: {
    origin: '*',
    credentials: true,
  },
})
export class SessionsGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(SessionsGateway.name);
  private readonly socketUserMap = new Map<string, { userId: string; role: string; expertId?: string }>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
    private readonly sessionsService: SessionsService,
    private readonly presenceService: PresenceService,
  ) {}

  afterInit() {
    this.logger.log('Sessions WebSocket Gateway initialized');

    // Wire service callbacks to emit via WebSocketServer
    this.sessionsService.setGatewayCallbacks(
      (userId, event, payload) => {
        this.server.to(`user:${userId}`).emit(event, payload);
      },
      (expertId, event, payload) => {
        this.server.to(`expert:${expertId}`).emit(event, payload);
      },
      (sessionId, event, payload) => {
        this.server.to(`session:${sessionId}`).emit(event, payload);
      },
    );

    // Broadcast presence updates in real time to all clients
    this.presenceService.registerChangeListener((expertId, status) => {
      this.server.emit('presence:update', { expertId, status });
    });
  }

  async handleConnection(client: Socket) {
    try {
      const token =
        client.handshake.auth?.token ||
        client.handshake.headers?.authorization?.replace('Bearer ', '');

      if (!token) {
        this.logger.debug(`Client ${client.id} connected without token (anonymous/guest)`);
        return;
      }

      const decoded = this.jwtService.verify(token);
      const userId = decoded.sub || decoded.userId;
      const role = decoded.role || 'user';

      // Immediately register in map synchronously
      this.socketUserMap.set(client.id, { userId, role });
      client.join(`user:${userId}`);

      // Asynchronously resolve expert profile if expert
      const expertProfile = await this.prisma.expertProfile.findUnique({
        where: { userId },
      });
      if (expertProfile) {
        const currentMeta = this.socketUserMap.get(client.id);
        if (currentMeta) {
          currentMeta.expertId = expertProfile.id;
        }
        client.join(`expert:${expertProfile.id}`);
        this.logger.log(`Expert socket joined room expert:${expertProfile.id}`);
      }

      this.logger.log(`User ${userId} (${role}) connected on socket ${client.id}`);
    } catch (err: any) {
      this.logger.warn(`Socket auth error: ${err.message}`);
    }
  }

  async handleDisconnect(client: Socket) {
    const userMeta = this.socketUserMap.get(client.id);
    if (userMeta) {
      this.socketUserMap.delete(client.id);
      this.logger.log(`User ${userMeta.userId} disconnected from socket ${client.id}`);

      // If expert disconnected, update presence to OFFLINE
      if (userMeta.expertId) {
        await this.presenceService.setPresence(userMeta.expertId, 'OFFLINE');
      }

      // Check if user was in an active consultation session
      const activeSession = await this.sessionsService.getActiveSessionForUser(userMeta.userId);
      if (activeSession && (activeSession.status === 'ACTIVE' || activeSession.status === 'CONNECTING')) {
        await this.sessionsService.handleDisconnect(userMeta.userId, activeSession.id);
      }
    }
  }

  @SubscribeMessage('expert:register_presence')
  async handleExpertRegister(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { expertId: string; status?: PresenceStatus },
  ) {
    const userMeta = this.socketUserMap.get(client.id);
    if (userMeta) {
      userMeta.expertId = data.expertId;
    }

    client.join(`expert:${data.expertId}`);
    const status = data.status || 'ONLINE';
    await this.presenceService.setPresence(data.expertId, status);
    return { success: true, expertId: data.expertId, status };
  }

  @SubscribeMessage('presence:set')
  async handleSetPresence(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { expertId?: string; status: PresenceStatus },
  ) {
    const userMeta = this.socketUserMap.get(client.id);
    const targetExpertId = data.expertId || userMeta?.expertId;
    if (targetExpertId) {
      await this.presenceService.setPresence(targetExpertId, data.status);
    }
    return { success: true, status: data.status };
  }

  @SubscribeMessage('session:request')
  async handleSessionRequest(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { expertId: string; sessionType?: 'CHAT' | 'AUDIO' | 'VIDEO' },
  ) {
    const userMeta = this.socketUserMap.get(client.id);
    if (!userMeta) return { error: 'UNAUTHORIZED' };

    try {
      const session = await this.sessionsService.requestSession(
        userMeta.userId,
        data.expertId,
        data.sessionType as any,
      );
      client.join(`session:${session.id}`);
      return { success: true, session };
    } catch (err: any) {
      return { error: err.message };
    }
  }

  @SubscribeMessage('session:accept')
  async handleSessionAccept(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { sessionId: string },
  ) {
    const userMeta = this.socketUserMap.get(client.id);
    if (!userMeta) return { error: 'UNAUTHORIZED' };

    try {
      const session = await this.sessionsService.acceptSession(userMeta.userId, data.sessionId);
      client.join(`session:${data.sessionId}`);
      return { success: true, session };
    } catch (err: any) {
      return { error: err.message };
    }
  }

  @SubscribeMessage('session:reject')
  async handleSessionReject(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { sessionId: string; reason?: string },
  ) {
    const userMeta = this.socketUserMap.get(client.id);
    if (!userMeta) return { error: 'UNAUTHORIZED' };

    try {
      const session = await this.sessionsService.rejectSession(
        userMeta.userId,
        data.sessionId,
        data.reason,
      );
      return { success: true, session };
    } catch (err: any) {
      return { error: err.message };
    }
  }

  @SubscribeMessage('session:join')
  async handleSessionJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { sessionId: string },
  ) {
    const userMeta = this.socketUserMap.get(client.id);
    if (!userMeta) return { error: 'UNAUTHORIZED' };

    client.join(`session:${data.sessionId}`);
    await this.sessionsService.confirmJoin(userMeta.userId, data.sessionId);
    return { success: true, joined: true };
  }

  @SubscribeMessage('session:disconnect')
  async handleSessionDisconnect(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { sessionId: string },
  ) {
    const userMeta = this.socketUserMap.get(client.id);
    if (!userMeta) return;

    this.sessionsService.handleDisconnect(userMeta.userId, data.sessionId);
  }

  private getUserIdFromSocket(client: Socket): string | undefined {
    const userMeta = this.socketUserMap.get(client.id);
    if (userMeta?.userId) return userMeta.userId;
    try {
      const token =
        client.handshake.auth?.token ||
        client.handshake.headers?.authorization?.replace('Bearer ', '');
      if (token) {
        const decoded = this.jwtService.verify(token);
        return decoded.sub || decoded.userId;
      }
    } catch (_) {}
    return undefined;
  }

  @SubscribeMessage('session:reconnect')
  async handleSessionReconnect(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { sessionId: string },
  ) {
    const userId = this.getUserIdFromSocket(client);
    this.logger.log(`Reconnect requested for session ${data?.sessionId} by socket ${client.id} (user: ${userId})`);
    if (!userId) return { error: 'UNAUTHORIZED' };

    client.join(`session:${data.sessionId}`);
    const reconnected = await this.sessionsService.handleReconnect(userId, data.sessionId);
    this.logger.log(`Session ${data.sessionId} reconnect result: ${reconnected}`);
    return { success: reconnected };
  }

  @SubscribeMessage('session:end')
  async handleSessionEnd(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { sessionId: string; reason?: string },
  ) {
    const userMeta = this.socketUserMap.get(client.id);
    if (!userMeta) return { error: 'UNAUTHORIZED' };

    const summary = await this.sessionsService.endSession(
      data.sessionId,
      userMeta.userId,
      data.reason || 'USER_ENDED',
    );
    return { success: true, summary };
  }

  @SubscribeMessage('chat:message')
  async handleChatMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { sessionId: string; text: string },
  ) {
    const userMeta = this.socketUserMap.get(client.id);
    if (!userMeta) return { error: 'UNAUTHORIZED' };

    const msg = await this.sessionsService.sendMessage(
      data.sessionId,
      userMeta.userId,
      userMeta.role,
      data.text,
    );
    return { success: true, messageId: msg.id };
  }
}
