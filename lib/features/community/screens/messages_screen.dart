import 'package:flutter/material.dart';

import '../../shared/brand.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';
import 'chat_screen.dart';

/// List of conversations (one per booking).
class MessagesScreen extends StatelessWidget {
  final bool viewerIsProvider;
  const MessagesScreen({super.key, this.viewerIsProvider = true});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final bookings = (viewerIsProvider ? app.providerBookings : app.customerBookings)
        .where((b) => b.status != BookingStatus.declined)
        .toList()
      ..sort((a, b) {
        final la = app.chatFor(a.id);
        final lb = app.chatFor(b.id);
        final ta = la.isEmpty ? a.dateTime : la.last.sentAt;
        final tb = lb.isEmpty ? b.dateTime : lb.last.sentAt;
        return tb.compareTo(ta);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: SafeArea(
        child: bookings.isEmpty
            ? const EmptyState(
                icon: Icons.forum_outlined,
                title: 'No conversations yet',
                message: 'Messages about your bookings will appear here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: bookings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final b = bookings[i];
                  final msgs = app.chatFor(b.id);
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
                                msgs.isEmpty
                                    ? '${b.serviceName} · ${whenLabel(b.dateTime)}'
                                    : msgs.last.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
