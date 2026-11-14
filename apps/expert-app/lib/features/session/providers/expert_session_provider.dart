import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/constants/api_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/expert_session_model.dart';

class ExpertSessionState {
  final bool isConnected;
  final IncomingSessionRequest? incomingRequest;
  final ExpertActiveSession? activeSession;
  final List<ExpertChatMessage> messages;
  final Map<String, dynamic>? lastSummary;
  final String? errorMessage;

  const ExpertSessionState({
    this.isConnected = false,
    this.incomingRequest,
    this.activeSession,
    this.messages = const [],
    this.lastSummary,
    this.errorMessage,
  });

  ExpertSessionState copyWith({
    bool? isConnected,
    IncomingSessionRequest? incomingRequest,
    bool clearIncomingRequest = false,
    ExpertActiveSession? activeSession,
    bool clearActiveSession = false,
    List<ExpertChatMessage>? messages,
    Map<String, dynamic>? lastSummary,
    bool clearLastSummary = false,
    String? errorMessage,
  }) {
    return ExpertSessionState(
      isConnected: isConnected ?? this.isConnected,
      incomingRequest: clearIncomingRequest ? null : (incomingRequest ?? this.incomingRequest),
      activeSession: clearActiveSession ? null : (activeSession ?? this.activeSession),
      messages: messages ?? this.messages,
      lastSummary: clearLastSummary ? null : (lastSummary ?? this.lastSummary),
      errorMessage: errorMessage,
    );
  }
}

class ExpertSessionNotifier extends Notifier<ExpertSessionState> {
  io.Socket? _socket;
  Timer? _localTickTimer;

  @override
  ExpertSessionState build() {
    ref.onDispose(() {
      _stopLocalTimer();
      _socket?.dispose();
    });

    Future.microtask(() => initSocket());

    return const ExpertSessionState();
  }

  Future<void> initSocket() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final token = await storage.getAccessToken();

      if (token == null || token.isEmpty) return;

      _socket?.dispose();

      _socket = io.io(
        ApiConstants.baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableReconnection()
            .setAuth({'token': token})
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('[ExpertSocket] Connected to backend');
        state = state.copyWith(isConnected: true);
        // Automatically set presence to ONLINE on dashboard connect
        _socket!.emit('presence:set', {'status': 'ONLINE'});
      });

      _socket!.onDisconnect((_) {
        debugPrint('[ExpertSocket] Disconnected from backend');
        state = state.copyWith(isConnected: false);
      });

      _socket!.on('session:incoming_request', (data) {
        debugPrint('[ExpertSocket] Incoming request: $data');
        if (data is Map<String, dynamic>) {
          final req = IncomingSessionRequest.fromJson(data);
          state = state.copyWith(incomingRequest: req);
        }
      });

      _socket!.on('session:started', (data) {
        debugPrint('[ExpertSocket] Session started: $data');
        if (state.activeSession != null) {
          state = state.copyWith(
            activeSession: state.activeSession!.copyWith(
              status: 'ACTIVE',
              isPaused: false,
            ),
          );
          _startLocalTimer();
        }
      });

      _socket!.on('session:billing_tick', (data) {
        if (state.activeSession != null && data is Map<String, dynamic>) {
          final totalBilledRupees = (data['totalBilledRupees'] as num?)?.toDouble() ?? 0.0;
          state = state.copyWith(
            activeSession: state.activeSession!.copyWith(
              totalBilledRupees: totalBilledRupees,
            ),
          );
        }
      });

      _socket!.on('session:billing_paused', (data) {
        final reason = (data is Map) ? data['reason']?.toString() : 'Idle';
        if (state.activeSession != null) {
          state = state.copyWith(
            activeSession: state.activeSession!.copyWith(
              isPaused: true,
              pauseReason: reason,
            ),
          );
        }
      });

      _socket!.on('session:billing_resumed', (_) {
        if (state.activeSession != null) {
          state = state.copyWith(
            activeSession: state.activeSession!.copyWith(
              isPaused: false,
              pauseReason: null,
            ),
          );
        }
      });

      _socket!.on('chat:message', (data) {
        if (data is Map<String, dynamic>) {
          final msg = ExpertChatMessage.fromJson(data);
          state = state.copyWith(messages: [...state.messages, msg]);
        }
      });

      _socket!.on('session:summary', (data) {
        debugPrint('[ExpertSocket] Session summary: $data');
        _stopLocalTimer();
        if (data is Map<String, dynamic>) {
          state = state.copyWith(
            lastSummary: data,
            activeSession: state.activeSession?.copyWith(status: 'ENDED'),
          );
        }
      });

      _socket!.on('session:cancelled', (data) {
        _stopLocalTimer();
        state = state.copyWith(
          clearIncomingRequest: true,
          clearActiveSession: true,
        );
      });
    } catch (e) {
      debugPrint('[ExpertSocket] Error initializing socket: $e');
    }
  }

  void _startLocalTimer() {
    _localTickTimer?.cancel();
    _localTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.activeSession != null &&
          state.activeSession!.status == 'ACTIVE' &&
          !state.activeSession!.isPaused) {
        state = state.copyWith(
          activeSession: state.activeSession!.copyWith(
            durationSeconds: state.activeSession!.durationSeconds + 1,
          ),
        );
      }
    });
  }

  void _stopLocalTimer() {
    _localTickTimer?.cancel();
    _localTickTimer = null;
  }

  void acceptRequest() {
    final req = state.incomingRequest;
    if (req == null) return;

    _socket?.emit('session:accept', {'sessionId': req.sessionId});
    _socket?.emit('session:join', {'sessionId': req.sessionId});

    state = state.copyWith(
      clearIncomingRequest: true,
      messages: [],
      activeSession: ExpertActiveSession(
        id: req.sessionId,
        userId: req.userId,
        userName: req.userName,
        sessionType: req.sessionType,
        status: 'CONNECTING',
        rateInRupees: req.rateInRupees,
      ),
    );
  }

  void rejectRequest([String reason = 'Expert declined']) {
    final req = state.incomingRequest;
    if (req == null) return;

    _socket?.emit('session:reject', {
      'sessionId': req.sessionId,
      'reason': reason,
    });

    state = state.copyWith(clearIncomingRequest: true);
  }

  void sendMessage(String text) {
    final session = state.activeSession;
    if (session == null || text.trim().isEmpty) return;

    _socket?.emit('chat:message', {
      'sessionId': session.id,
      'text': text.trim(),
    });
  }

  Future<void> endSession() async {
    final session = state.activeSession;
    if (session == null) return;

    _stopLocalTimer();
    _socket?.emit('session:end', {
      'sessionId': session.id,
      'reason': 'EXPERT_ENDED',
    });

    try {
      final client = ref.read(apiClientProvider);
      final res = await client.dio.post('/sessions/${session.id}/end', data: {
        'reason': 'EXPERT_ENDED',
      });
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        state = state.copyWith(
          lastSummary: res.data as Map<String, dynamic>,
          activeSession: state.activeSession?.copyWith(status: 'ENDED'),
        );
      }
    } catch (e) {
      debugPrint('[ExpertSession] Error ending session: $e');
    }
  }

  void dismissSummary() {
    state = state.copyWith(clearLastSummary: true, clearActiveSession: true);
  }

  void setPresence(String status) {
    _socket?.emit('presence:set', {'status': status});
  }
}

final expertSessionProvider =
    NotifierProvider<ExpertSessionNotifier, ExpertSessionState>(() {
  return ExpertSessionNotifier();
});
