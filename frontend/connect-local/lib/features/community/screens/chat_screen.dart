import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/validators.dart';
import '../../shared/brand.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui_kit.dart';

/// Chat thread attached to a booking (customer <-> provider), stored on the server. While open it checks
/// for new messages every few seconds.
class ChatScreen extends StatefulWidget {
  final Booking booking;
  final bool viewerIsProvider;
  const ChatScreen(
      {super.key, required this.booking, required this.viewerIsProvider});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final error = await AppScope.read(context).loadChat(widget.booking.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final problem = Validators.text(text, max: 2000, label: 'Your message');
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(problem)));
      return;
    }
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final error = await AppScope.read(context).sendMessage(widget.booking.id, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      // Keep the text so nothing typed is lost.
      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(error)));
      return;
    }
    _ctrl.clear();
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final b = widget.booking;
    final other = widget.viewerIsProvider
        ? b.clientName
        : app.providerById(b.providerId).name;
    final messages = app.chatFor(b.id);
    if (messages.length != _shown) {
      _shown = messages.length;
      _scrollToEnd();
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(other,
                style: headingStyle(
                    size: 16, weight: FontWeight.w600, color: AppColors.text)),
            Text('${b.serviceName} · ${formatDate(b.dateTime)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.muted)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? (_loading
                      ? const Center(child: CircularProgressIndicator())
                      : EmptyState(
                          icon: _error == null ? Icons.chat_bubble_outline_rounded : Icons.cloud_off_rounded,
                          title: _error == null ? 'No messages yet' : 'Messages could not be loaded',
                          message: _error ?? 'Say hello!',
                        ))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final m = messages[i];
                        final mine = m.mine;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.7),
                            decoration: BoxDecoration(
                              color: mine ? AppColors.teal : AppColors.inputBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(m.text,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: mine
                                            ? Colors.white
                                            : AppColors.text)),
                                const SizedBox(height: 2),
                                Text(formatTime(m.sentAt),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: mine
                                            ? Colors.white70
                                            : AppColors.muted)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      maxLength: 2000,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        hintStyle: const TextStyle(
                            fontSize: 14, color: AppColors.muted),
                        filled: true,
                        fillColor: AppColors.inputBg,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send, color: AppColors.teal),
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
