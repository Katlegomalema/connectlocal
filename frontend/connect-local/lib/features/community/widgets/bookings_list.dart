import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../screens/chat_screen.dart';
import 'common_widgets.dart';

class BookingsList extends StatelessWidget {
  final List<Booking> bookings;
  final bool viewerIsProvider;
  const BookingsList({super.key, required this.bookings, required this.viewerIsProvider});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const Center(child: Text('No bookings yet', style: TextStyle(color: AppColors.muted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final status = booking.status.name[0].toUpperCase() + booking.status.name.substring(1);
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const AvatarPlaceholder(size: 42, circle: true, icon: Icons.handyman),
            title: Text(booking.serviceName, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${viewerIsProvider ? booking.clientName : whenLabel(booking.dateTime)}\n${money(booking.price)} · $status'),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'Open chat',
              icon: const Icon(Icons.chat_bubble_outline, color: AppColors.teal),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(booking: booking, viewerIsProvider: viewerIsProvider)),
              ),
            ),
          ),
        );
      },
    );
  }
}
