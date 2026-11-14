import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/session_provider.dart';
import '../widgets/session_summary_dialog.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String expertName;

  const ChatScreen({
    super.key,
    required this.expertName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
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

  void _showConfirmEndDialog() {
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
          'Billing will stop immediately at the current second and any unused balance will remain in your wallet.',
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
              ref.read(sessionProvider.notifier).endSession();
            },
            child: const Text('End Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    final session = sessionState.currentSession;
    final summary = sessionState.lastSummary;

    // Show summary popup when session reaches ENDED and summary is available
    if (summary != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => SessionSummaryDialog(
            summary: summary,
            onDismiss: () {
              ref.read(sessionProvider.notifier).clearSummary();
              Navigator.of(context).pop();
            },
          ),
        );
      });
    }

    _scrollToBottom();

    final status = session?.status ?? 'CONNECTING';
    final isPaused = session?.isPaused ?? false;
    final pauseReason = session?.pauseReason ?? '';

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
              _showConfirmEndDialog();
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
              child: const Icon(Icons.auto_awesome, color: AppTheme.goldAccent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.expertName,
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
                              : (status == 'RECONNECTING' ? AppTheme.warning : AppTheme.goldAccent),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        status == 'ACTIVE'
                            ? (isPaused ? 'PAUSED ($pauseReason)' : 'ACTIVE')
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
          // Live Timer & Billed Amount
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
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            tooltip: 'End Session',
            icon: const Icon(Icons.call_end, color: AppTheme.error),
            onPressed: _showConfirmEndDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status banners
            if (status == 'REQUESTED')
              _buildBanner(
                text: 'Waiting for expert to accept request (expires in ~30s)...',
                color: AppTheme.goldAccent,
                icon: Icons.hourglass_top,
              )
            else if (status == 'CONNECTING')
              _buildBanner(
                text: 'Connecting to room... Waiting for both parties to confirm.',
                color: AppTheme.goldAccent,
                icon: Icons.sync,
              )
            else if (status == 'RECONNECTING')
              _buildBanner(
                text: 'Connection interrupted. Reconnecting grace window active (20s)...',
                color: AppTheme.warning,
                icon: Icons.wifi_off,
              )
            else if (isPaused)
              _buildBanner(
                text: 'Billing paused due to $pauseReason. Send a message to resume.',
                color: AppTheme.warning,
                icon: Icons.pause_circle_outline,
              ),

            // Messages list
            Expanded(
              child: sessionState.messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            'Session is active. Say hello to begin!',
                            style: GoogleFonts.inter(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: sessionState.messages.length,
                      itemBuilder: (context, index) {
                        final msg = sessionState.messages[index];
                        final isMe = msg.isUser;
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

            // Chat input bar
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
                        hintText: 'Type your message...',
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
                          ref.read(sessionProvider.notifier).sendMessage(val);
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
                          ref.read(sessionProvider.notifier).sendMessage(text);
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

  Widget _buildBanner({
    required String text,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: color.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
