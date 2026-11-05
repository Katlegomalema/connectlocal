import 'package:flutter/material.dart';

import '../../../screens/no_bookings_screen.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/ui_kit.dart';
import 'chat_screen.dart';
import 'customer_booking_detail_screen.dart';

/// Customer-side "My Bookings" (reached from the Home bottom nav).
class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({super.key});

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.customerBookings.isEmpty) {
      return NoBookingsScreen(
        onBrowseServices: () => Navigator.popUntil(context, (route) => route.isFirst),
      );
    }
    final now = DateTime.now();
    // "Upcoming" = anything not finished yet, including a finished job that
    // still has to be paid. "Past" = finished and paid, declined or cancelled
    // (or a request nobody answered before its date).
    final bookings = app.customerBookings.where((booking) {
      final stale = booking.status == BookingStatus.pending && booking.dateTime.isBefore(now);
      final isPast = !booking.isActive || stale;
      return _selectedTab == 0 ? !isPast : isPast;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: SafeArea(
        child: Column(
          children: [
            FilterTabs(
              labels: const ['Upcoming', 'Past'],
              selected: _selectedTab,
              onChanged: (i) => setState(() => _selectedTab = i),
            ),
            Expanded(
              child: bookings.isEmpty
                  ? EmptyState(
                      icon: Icons.event_available_outlined,
                      title: _selectedTab == 0
                          ? 'No upcoming bookings'
                          : 'No past bookings',
                      message: _selectedTab == 0
                          ? 'When you book a service it will show up here.'
                          : 'Completed bookings will be listed here.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: bookings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        final provider = app.providerById(booking.providerId);
                        return BookingCard(
                          title: provider.name,
                          service:
                              '${booking.serviceName} · ${booking.quantityLabel}',
                          onTap: () => CustomerBookingDetailScreen.open(context, booking),
                          dateText:
                              '${formatDate(booking.dateTime)} · ${formatTime(booking.dateTime)}',
                          priceText: money(booking.price),
                          status: booking.status,
                          stage: booking.stage,
                          footer: (booking.status == BookingStatus.completed &&
                                  !booking.balancePaid &&
                                  booking.serviceMethod == null)
                              ? SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () => CustomerBookingDetailScreen.open(context, booking),
                                    icon: const Icon(Icons.lock_outline_rounded, size: 20),
                                    label: Text('Pay R${booking.balance}'),
                                  ),
                                )
                              : (booking.status == BookingStatus.completed &&
                                      booking.balancePaid &&
                                      booking.rating == null)
                                  ? SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => CustomerBookingDetailScreen.showReview(
                                            context, app, booking),
                                        icon: const Icon(Icons.star_outline_rounded, size: 20),
                                        label: const Text('Leave a review'),
                                      ),
                                    )
                                  : null,
                          trailing: RoundIconButton(
                            icon: Icons.chat_bubble_outline_rounded,
                            tooltip: 'Message provider',
                            label: 'Chat',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  booking: booking,
                                  viewerIsProvider: false,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
