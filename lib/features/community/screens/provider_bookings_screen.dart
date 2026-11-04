import 'package:flutter/material.dart';

import '../../shared/location_map.dart';

import '../../admin/screens/provider_booking_detail_screen.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common_widgets.dart';
import '../widgets/payout_gate.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/ui_kit.dart';
import 'chat_screen.dart';

/// Screen 28: Provider Bookings
class ProviderBookingsScreen extends StatefulWidget {
  const ProviderBookingsScreen({super.key});

  @override
  State<ProviderBookingsScreen> createState() => _ProviderBookingsScreenState();
}

class _ProviderBookingsScreenState extends State<ProviderBookingsScreen> {
  int _selectedTab = 0;
  static const _tabs = ['Upcoming', 'Past', 'Pending'];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final now = DateTime.now();
    final bookings = app.providerBookings.where((booking) {
      final stale = booking.status == BookingStatus.pending && booking.dateTime.isBefore(now);
      switch (_selectedTab) {
        case 0:
          // Anything not finished yet, including a finished job awaiting payment.
          return booking.isActive && !stale;
        case 1:
          return !booking.isActive || stale;
        default:
          return booking.status == BookingStatus.pending;
      }
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: SafeArea(
        child: Column(
          children: [
            FilterTabs(
              labels: _tabs,
              selected: _selectedTab,
              onChanged: (i) => setState(() => _selectedTab = i),
            ),
            Expanded(
              child: bookings.isEmpty
                  ? EmptyState(
                      icon: Icons.event_note_outlined,
                      title: _selectedTab == 2
                          ? 'No pending bookings'
                          : _selectedTab == 1
                              ? 'No past bookings'
                              : 'No upcoming bookings',
                      message: 'New booking requests will appear here.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: bookings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) =>
                          _bookingCard(context, app, bookings[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(BuildContext context, Booking booking) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(booking: booking, viewerIsProvider: true),
        ),
      );

  void _openDetail(BuildContext context, AppState app, Booking booking) {
    final pending = booking.status == BookingStatus.pending;
    final confirmed = booking.status == BookingStatus.confirmed;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderBookingDetailScreen(
          status: pending ? 'Pending Confirmation' : booking.stage.label,
          statusColor: pending
              ? const Color(0xFFF5C518)
              : confirmed
                  ? AppColors.green
                  : booking.status == BookingStatus.completed
                      ? AppColors.muted
                      : AppColors.red,
          customerName: booking.clientName,
          phone: booking.phone.isEmpty ? 'Not provided' : booking.phone,
          service:
              '${booking.serviceName} · ${booking.quantityLabel}',
          date: formatDate(booking.dateTime),
          time: formatTime(booking.dateTime),
          location: booking.address.isEmpty
              ? '${booking.distanceKm.toStringAsFixed(0)} km away'
              : booking.address,
          total: money(booking.price),
          notes: booking.notes,
          showActions: pending,
          onConfirm: pending ? () => confirmBooking(context, app, booking) : null,
          onDecline: pending ? () => app.setStatus(booking, BookingStatus.declined) : null,
          completeLabel: confirmed && !booking.pinVerified
              ? 'Enter PIN to Verify & Start'
              : confirmed
                  ? 'Mark job as complete'
                  : 'Cash received',
          onComplete: confirmed && !booking.pinVerified
              ? () async {
                  await showStartJobPinDialog(context, app, booking);
                  // Close the detail page once the PIN started the job.
                  if (booking.pinVerified && context.mounted) Navigator.pop(context);
                }
              : confirmed
                  ? () {
                      app.completeJob(booking);
                      Navigator.pop(context);
                    }
                  : (booking.status == BookingStatus.completed &&
                          !booking.balancePaid &&
                          booking.serviceMethod == PayMethod.cash)
                      ? () {
                          app.confirmCashReceived(booking);
                          Navigator.pop(context);
                        }
                      : null,
          onChat: () => _openChat(context, booking),
          onDirections: () => openDirectionsTo(context,
              lat: booking.latitude, lng: booking.longitude, address: booking.address),
        ),
      ),
    );
  }

  Widget _bookingCard(BuildContext context, AppState app, Booking booking) {
    final isPending = booking.status == BookingStatus.pending;
    final isConfirmed = booking.status == BookingStatus.confirmed;
    final awaitingPayment =
        booking.status == BookingStatus.completed && !booking.balancePaid;
    return BookingCard(
      title: booking.clientName,
      service:
          '${booking.serviceName} · ${booking.quantityLabel}',
      dateText: '${formatDate(booking.dateTime)} · ${formatTime(booking.dateTime)}',
      priceText: money(booking.price),
      status: booking.status,
      stage: booking.stage,
      onTap: () => _openDetail(context, app, booking),
      trailing: RoundIconButton(
        icon: Icons.chat_bubble_outline_rounded,
        tooltip: 'Open chat',
            label: 'Chat',
        onPressed: () => _openChat(context, booking),
      ),
      footer: (isPending || isConfirmed || awaitingPayment)
          ? Row(
              children: [
                if (isPending) ...[
                  Expanded(
                    child: PillButton(
                      label: 'Confirm',
                      onPressed: () => confirmBooking(context, app, booking),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PillButton(
                      label: 'Decline',
                      color: AppColors.red,
                      outlined: true,
                      onPressed: () => app.setStatus(booking, BookingStatus.declined),
                    ),
                  ),
                ],
                if (isConfirmed && !booking.pinVerified)
                  Expanded(
                    child: PillButton(
                      label: 'Enter PIN to Verify & Start',
                      color: AppColors.green,
                      onPressed: () => showStartJobPinDialog(context, app, booking),
                    ),
                  ),
                if (isConfirmed && booking.pinVerified)
                  Expanded(
                    child: PillButton(
                      label: 'Complete job',
                      color: AppColors.green,
                      onPressed: () => app.completeJob(booking),
                    ),
                  ),
                if (awaitingPayment && booking.serviceMethod == PayMethod.cash)
                  Expanded(
                    child: PillButton(
                      label: 'Cash received',
                      color: AppColors.green,
                      onPressed: () => app.confirmCashReceived(booking),
                    ),
                  ),
                if (awaitingPayment && booking.serviceMethod != PayMethod.cash)
                  const Expanded(
                    child: Text('Waiting for the customer to pay',
                        style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  ),
              ],
            )
          : null,
    );
  }
}
