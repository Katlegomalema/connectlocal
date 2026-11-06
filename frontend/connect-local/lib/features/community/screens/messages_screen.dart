import 'package:flutter/material.dart';

import '../../shared/brand.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';
import 'chat_screen.dart';

/// List of conversations (one per booking), newest message first.
class MessagesScreen extends StatefulWidget {
  final bool viewerIsProvider;
  const MessagesScreen({super.key, this.viewerIsProvider = true});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool get viewerIsProvider => widget.viewerIsProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).refreshConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    DateTime lastActivity(Booking b) => app.conversationFor(b.id)?.lastAt ?? b.dateTime;
    final bookings = (viewerIsProvider ? app.providerBookings : app.customerBookings)
        .where((b) => b.status != BookingStatus.declined)
        .toList()
      ..sort((a, b) => lastActivity(b).compareTo(lastActivity(a)));

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => app.refreshConversations(),
          child: bookings.isEmpty
            ? ListView(children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.forum_outlined,
                  title: 'No conversations yet',
                  message: 'Messages about your bookings will appear here.',
                ),
              ])
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: bookings.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final b = bookings[i];
                  final last = app.conversationFor(b.id);
                  final name = viewerIsProvider
                      ? b.clientName
                      : app.providerById(b.providerId).name;
                  return AppCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatScreen(booking: b, viewerIsProvider: viewerIsProvider),
                      ),
                    ),
                    child: Row(
                      children: [
                        const AvatarPlaceholder(size: 48, circle: true, icon: Icons.person),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: headingStyle(
                                  size: 15,
                                  weight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                last == null
                                    ? '${b.serviceName} · ${whenLabel(b.dateTime)}'
                                    : '${last.lastMine ? 'You: ' : ''}${last.lastMessage}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        if ((last?.unread ?? 0) > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.teal,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${last!.unread}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                  );
                },
              ),
        ),
      ),
    );
  }
}
