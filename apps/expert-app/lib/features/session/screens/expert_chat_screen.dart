import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_shared/flutter_shared.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/expert_session_provider.dart';

class ExpertChatScreen extends ConsumerStatefulWidget {
  final String userName;

  const ExpertChatScreen({super.key, required this.userName});

  @override
  ConsumerState<ExpertChatScreen> createState() => _ExpertChatScreenState();
}

class _ExpertChatScreenState extends ConsumerState<ExpertChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showEndSessionConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.midnightSurface,
        title: Text(
          'End Consultation?',
          style: GoogleFonts.lora(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Consultation will terminate and earnings will be finalized.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(expertSessionProvider.notifier).endSession();
            },
            child: const Text('End Consultation', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(expertSessionProvider);
    final session = sessionState.activeSession;
    final summary = sessionState.lastSummary;

    // Show summary dialog when ended
    if (summary != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.midnightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppTheme.goldAccent, width: 1.5),
            ),
            title: Text(
              'Consultation Finalized',
              style: GoogleFonts.lora(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duration: ${_formatTimer(summary['durationSeconds'] as int? ?? 0)}',
                  style: GoogleFonts.inter(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Earned: ₹${((summary['totalBilledRupees'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reason: ${summary['endReason'] ?? 'ENDED'}',
                  style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.goldAccent),
                onPressed: () {
                  ref.read(expertSessionProvider.notifier).dismissSummary();
                  Navigator.pop(ctx); // pop dialog
                  Navigator.pop(context); // exit chat screen
                },
                child: const Text('Return to Dashboard', style: TextStyle(color: AppTheme.midnightBackground)),
              ),
            ],
          ),
        );
      });
    }

    _scrollToBottom();

    final status = session?.status ?? 'CONNECTING';
    final isPaused = session?.isPaused ?? false;

    return Scaffold(
      backgroundColor: AppTheme.midnightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.midnightSurface,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () {
            if (session != null && session.status == 'ACTIVE') {
              _showEndSessionConfirm();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.goldAccent.withValues(alpha: 0.2),
              child: const Icon(Icons.person, color: AppTheme.goldAccent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: GoogleFonts.lora(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: status == 'ACTIVE'
                              ? (isPaused ? AppTheme.warning : AppTheme.success)
                              : AppTheme.goldAccent,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        status == 'ACTIVE'
                            ? (isPaused ? 'PAUSED (Idle)' : 'ACTIVE')
                            : status,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (session != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.midnightBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPaused ? AppTheme.warning : AppTheme.goldAccent.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatTimer(session.durationSeconds),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isPaused ? AppTheme.warning : AppTheme.goldAccent,
                    ),
                  ),
                  Text(
                    '₹${session.totalBilledRupees.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            tooltip: 'End Consultation',
            icon: const Icon(Icons.call_end, color: AppTheme.error),
            onPressed: _showEndSessionConfirm,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isPaused)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: AppTheme.warning.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    const Icon(Icons.pause_circle_outline, size: 16, color: AppTheme.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chat idle detected. Billing paused. Activity will resume billing.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Messages feed
            Expanded(
              child: sessionState.messages.isEmpty
                  ? Center(
                      child: Text(
                        'Seeker is in room. Begin consultation!',
                        style: GoogleFonts.inter(color: AppTheme.textMuted),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: sessionState.messages.length,
                      itemBuilder: (context, index) {
                        final msg = sessionState.messages[index];
                        final isMe = msg.isExpert;
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: isMe ? AppTheme.goldAccent : AppTheme.midnightSurface,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 16),
                              ),
                              border: Border.all(
                                color: isMe
                                    ? AppTheme.goldAccent
                                    : AppTheme.midnightBorder,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.text,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: isMe ? AppTheme.midnightBackground : AppTheme.textPrimary,
                                    fontWeight: isMe ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: isMe
                                        ? AppTheme.midnightBackground.withValues(alpha: 0.6)
                                        : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Input bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: AppTheme.midnightSurface,
                border: Border(top: BorderSide(color: AppTheme.midnightBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: GoogleFonts.inter(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Type response to seeker...',
                        hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: AppTheme.midnightBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppTheme.midnightBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppTheme.midnightBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppTheme.goldAccent),
                        ),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          ref.read(expertSessionProvider.notifier).sendMessage(val);
                          _textController.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.goldAccent,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: AppTheme.midnightBackground, size: 20),
                      onPressed: () {
                        final text = _textController.text.trim();
                        if (text.isNotEmpty) {
                          ref.read(expertSessionProvider.notifier).sendMessage(text);
                          _textController.clear();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
