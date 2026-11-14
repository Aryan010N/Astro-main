import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/constants/api_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chat_message_model.dart';
import '../models/expert_presence_model.dart';
import '../models/session_model.dart';

class SessionState {
  final bool isLoading;
  final List<ExpertWithPresence> experts;
  final ConsultationSession? currentSession;
  final List<ChatMessage> messages;
  final SessionSummary? lastSummary;
  final double? remainingBalanceRupees;
  final String? errorMessage;
  final bool isConnected;

  const SessionState({
    this.isLoading = false,
    this.experts = const [],
    this.currentSession,
    this.messages = const [],
    this.lastSummary,
    this.remainingBalanceRupees,
    this.errorMessage,
    this.isConnected = false,
  });

  SessionState copyWith({
    bool? isLoading,
    List<ExpertWithPresence>? experts,
    ConsultationSession? currentSession,
    bool clearCurrentSession = false,
    List<ChatMessage>? messages,
    SessionSummary? lastSummary,
    bool clearLastSummary = false,
    double? remainingBalanceRupees,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isConnected,
  }) {
    return SessionState(
      isLoading: isLoading ?? this.isLoading,
      experts: experts ?? this.experts,
      currentSession: clearCurrentSession ? null : (currentSession ?? this.currentSession),
      messages: messages ?? this.messages,
      lastSummary: clearLastSummary ? null : (lastSummary ?? this.lastSummary),
      remainingBalanceRupees: remainingBalanceRupees ?? this.remainingBalanceRupees,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

class SessionNotifier extends Notifier<SessionState> {
  io.Socket? _socket;
  Timer? _localTickTimer;

  @override
  SessionState build() {
    ref.onDispose(() {
      _stopLocalTimer();
      _socket?.dispose();
    });

    Future.microtask(() {
      initSocket();
      fetchExperts();
    });

    return const SessionState();
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
        debugPrint('[Socket] Connected to backend');
        state = state.copyWith(isConnected: true);
      });

      _socket!.onDisconnect((_) {
        debugPrint('[Socket] Disconnected from backend');
        state = state.copyWith(isConnected: false);
      });

      _socket!.on('presence:update', (data) {
        if (data is Map<String, dynamic>) {
          final expertId = data['expertId'] as String?;
          final status = data['status'] as String?;
          if (expertId != null && status != null) {
            _updateExpertPresence(expertId, status);
          }
        }
      });

      _socket!.on('session:accepted', (data) {
        debugPrint('[Socket] Session accepted: $data');
        if (state.currentSession != null) {
          state = state.copyWith(
            currentSession: state.currentSession!.copyWith(status: 'CONNECTING'),
          );
          // Confirm join to transition to ACTIVE per state machine
          _socket!.emit('session:join', {'sessionId': state.currentSession!.id});
        }
      });

      _socket!.on('session:started', (data) {
        debugPrint('[Socket] Session started: $data');
        if (state.currentSession != null) {
          state = state.copyWith(
            currentSession: state.currentSession!.copyWith(
              status: 'ACTIVE',
              isPaused: false,
            ),
          );
          _startLocalTimer();
        }
      });

      _socket!.on('session:billing_tick', (data) {
        if (state.currentSession != null && data is Map<String, dynamic>) {
          final totalBilledRupees = (data['totalBilledRupees'] as num?)?.toDouble() ?? 0.0;
          final totalBilledPaise = data['totalBilledPaise']?.toString() ?? '0';
          final remainingBalance = (data['remainingBalanceRupees'] as num?)?.toDouble();

          state = state.copyWith(
            currentSession: state.currentSession!.copyWith(
              totalBilledRupees: totalBilledRupees,
              totalBilledPaise: totalBilledPaise,
            ),
            remainingBalanceRupees: remainingBalance,
          );
        }
      });

      _socket!.on('session:billing_paused', (data) {
        final reason = (data is Map) ? data['reason']?.toString() : 'Idle';
        if (state.currentSession != null) {
          state = state.copyWith(
            currentSession: state.currentSession!.copyWith(
              isPaused: true,
              pauseReason: reason,
            ),
          );
        }
      });

      _socket!.on('session:billing_resumed', (_) {
        if (state.currentSession != null) {
          state = state.copyWith(
            currentSession: state.currentSession!.copyWith(
              isPaused: false,
              pauseReason: null,
            ),
          );
        }
      });

      _socket!.on('session:reconnecting', (data) {
        if (state.currentSession != null) {
          state = state.copyWith(
            currentSession: state.currentSession!.copyWith(status: 'RECONNECTING'),
          );
        }
      });

      _socket!.on('session:reconnected', (data) {
        if (state.currentSession != null) {
          state = state.copyWith(
            currentSession: state.currentSession!.copyWith(status: 'ACTIVE'),
          );
        }
      });

      _socket!.on('chat:message', (data) {
        if (data is Map<String, dynamic>) {
          final msg = ChatMessage.fromJson(data);
          state = state.copyWith(messages: [...state.messages, msg]);
        }
      });

      _socket!.on('session:summary', (data) {
        debugPrint('[Socket] Received session summary: $data');
        _stopLocalTimer();
        if (data is Map<String, dynamic>) {
          final summary = SessionSummary.fromJson(data);
          state = state.copyWith(
            lastSummary: summary,
            currentSession: state.currentSession?.copyWith(
              status: 'ENDED',
              durationSeconds: summary.durationSeconds,
              totalBilledRupees: summary.totalBilledRupees,
            ),
          );
        }
      });

      _socket!.on('session:cancelled', (data) {
        _stopLocalTimer();
        final reason = (data is Map) ? data['reason']?.toString() : 'Request cancelled';
        state = state.copyWith(
          errorMessage: reason,
          clearCurrentSession: true,
        );
      });

      _socket!.on('session:timeout', (data) {
        _stopLocalTimer();
        final msg = (data is Map) ? data['message']?.toString() : 'Expert did not respond in time';
        state = state.copyWith(
          errorMessage: msg,
          clearCurrentSession: true,
        );
      });
    } catch (e) {
      debugPrint('[Socket] Error initializing socket: $e');
    }
  }

  void _startLocalTimer() {
    _localTickTimer?.cancel();
    _localTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.currentSession != null &&
          state.currentSession!.status == 'ACTIVE' &&
          !state.currentSession!.isPaused) {
        state = state.copyWith(
          currentSession: state.currentSession!.copyWith(
            durationSeconds: state.currentSession!.durationSeconds + 1,
          ),
        );
      }
    });
  }

  void _stopLocalTimer() {
    _localTickTimer?.cancel();
    _localTickTimer = null;
  }

  void _updateExpertPresence(String expertId, String status) {
    final updatedList = state.experts.map((exp) {
      if (exp.id == expertId) {
        return exp.copyWith(presenceStatus: status);
      }
      return exp;
    }).toList();
    state = state.copyWith(experts: updatedList);
  }

  Future<void> fetchExperts() async {
    try {
      state = state.copyWith(isLoading: true, clearErrorMessage: true);
      final client = ref.read(apiClientProvider);
      final res = await client.dio.get('/sessions/experts');

      if (res.statusCode == 200 && res.data is List) {
        final list = (res.data as List)
            .map((item) => ExpertWithPresence.fromJson(item as Map<String, dynamic>))
            .toList();
        state = state.copyWith(experts: list, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to fetch astrologers: ${e.toString()}',
      );
    }
  }

  Future<bool> requestSession(ExpertWithPresence expert) async {
    try {
      state = state.copyWith(isLoading: true, clearErrorMessage: true, messages: []);
      final client = ref.read(apiClientProvider);

      final res = await client.dio.post('/sessions/request', data: {
        'expertId': expert.id,
        'sessionType': 'CHAT',
      });

      if (res.statusCode == 201 || res.statusCode == 200) {
        final session = ConsultationSession.fromJson(res.data);
        state = state.copyWith(
          isLoading: false,
          currentSession: session,
          clearLastSummary: true,
        );

        // Tell socket we are listening for this session
        _socket?.emit('session:join', {'sessionId': session.id});
        return true;
      }
      return false;
    } catch (e) {
      String msg = 'Failed to initiate session';
      try {
        final err = e as dynamic;
        if (err.response?.data?['message'] != null) {
          msg = err.response.data['message'].toString();
        }
      } catch (_) {}
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  void sendMessage(String text) {
    if (state.currentSession == null || text.trim().isEmpty) return;

    _socket?.emit('chat:message', {
      'sessionId': state.currentSession!.id,
      'text': text.trim(),
    });
  }

  Future<void> endSession() async {
    if (state.currentSession == null) return;
    try {
      _stopLocalTimer();
      _socket?.emit('session:end', {
        'sessionId': state.currentSession!.id,
        'reason': 'USER_ENDED',
      });

      final client = ref.read(apiClientProvider);
      final res = await client.dio.post('/sessions/${state.currentSession!.id}/end', data: {
        'reason': 'USER_ENDED',
      });

      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final summary = SessionSummary.fromJson(res.data);
        state = state.copyWith(
          lastSummary: summary,
          currentSession: state.currentSession?.copyWith(status: 'ENDED'),
        );
      }
    } catch (e) {
      debugPrint('[Session] Error ending session: $e');
    }
  }

  void clearSummary() {
    state = state.copyWith(clearLastSummary: true, clearCurrentSession: true);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(() {
  return SessionNotifier();
});
