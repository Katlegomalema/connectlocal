import 'package:flutter/material.dart';

import '../../community/models/models.dart';
import '../../community/state/app_state.dart';
import '../../community/theme/app_theme.dart';
import '../../community/utils/format.dart';
import '../../community/widgets/stat_card.dart';
import '../../community/widgets/ui_kit.dart';

/// Every booking on the platform with where it is right now (stage), what has
/// been paid, whether the provider was verified with the PIN, and the payout.
class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  int _tab = 0;
  static const _labels = ['All', 'Pending', 'Active', 'Unpaid', 'Closed'];

  bool _matches(Booking b) => switch (_tab) {
        1 => b.stage == BookingStage.awaitingProvider,
        2 => b.stage == BookingStage.secured || b.stage == BookingStage.inProgress,
        3 => b.stage == BookingStage.paymentDue || b.stage == BookingStage.cashPending,
        4 => b.stage == BookingStage.completed ||
            b.stage == BookingStage.declined ||
            b.stage == BookingStage.cancelled,
        _ => true,
      };

  Widget _line(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color ?? AppColors.text)),
            ),
          ],
        ),
      );

  Widget _details(AppState app, Booking b) {
    final service = app.payments
        .where((p) => p.bookingId == b.id && p.kind == PaymentKind.service)
        .toList();
    final payout = app.payouts.where((p) => p.bookingId == b.id).toList();
    final String serviceText;
    Color? serviceColor;
    if (b.status == BookingStatus.declined || b.status == BookingStatus.cancelled) {
      serviceText = 'Not charged';
    } else if (b.balancePaid) {
      serviceText = 'R${b.balance} paid${b.serviceMethod == null ? '' : ' (${b.serviceMethod!.label})'}';
      serviceColor = AppColors.green;
    } else if (service.isNotEmpty && b.serviceMethod == PayMethod.cash) {
      serviceText = 'R${b.balance} cash \u2013 waiting for the provider to confirm';
      serviceColor = AppColors.orange;
    } else if (b.status == BookingStatus.completed) {
      serviceText = 'R${b.balance} DUE \u2013 job done, customer has not paid';
      serviceColor = AppColors.red;
    } else {
      serviceText = 'R${b.balance} to be paid after the service';
    }
    final String payoutText;
    if (payout.isNotEmpty) {
      final po = payout.first;
      payoutText = po.status == PayoutStatus.paid
          ? 'R${po.amount} paid (ref ${po.reference ?? '-'})'
          : 'R${po.amount} due to provider';
    } else if (b.balancePaid && b.serviceMethod == PayMethod.cash) {
      payoutText = 'None (provider took the cash)';
    } else {
      payoutText = '\u2013';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line('Deposit',
            'R${b.bookingFee} ${b.feeRefunded ? 'refunded' : 'paid'}'),
        _line('Service cost', serviceText, color: serviceColor),
        _line(
            'Provider PIN',
            b.pinVerified
                ? 'Verified \u2013 provider arrived'
                : b.pinAttempts > 0
                    ? '${b.pinAttempts} wrong attempt(s)'
                    : 'Not entered yet'),
        _line('Payout', payoutText),
        if (b.rating != null) _line('Review', '${b.rating}/5${(b.review ?? '').isEmpty ? '' : ' \u2013 ${b.review}'}'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final all = app.allBookings;
    final shown = all.where(_matches).toList();
    final active = all
        .where((b) => b.stage == BookingStage.secured || b.stage == BookingStage.inProgress)
        .length;
    final unpaid = all.where((b) => b.awaitingPayment);
    final unpaidTotal = unpaid.fold<int>(0, (t, b) => t + b.balance);
    final done = all.where((b) => b.stage == BookingStage.completed).length;
    return Scaffold(
      appBar: AppBar(title: const Text('All bookings')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(children: [
                Expanded(
                    child: StatCard(
                        icon: Icons.handyman_outlined, label: 'Active', value: '$active')),
                const SizedBox(width: 10),
                Expanded(
                    child: StatCard(
                        icon: Icons.hourglass_bottom_rounded,
                        label: 'Unpaid',
                        value: money(unpaidTotal))),
                const SizedBox(width: 10),
                Expanded(
                    child: StatCard(
                        icon: Icons.check_circle_outline, label: 'Completed', value: '$done')),
              ]),
            ),
            FilterTabs(
              labels: _labels,
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const EmptyState(
                      icon: Icons.event_busy_outlined,
                      title: 'No bookings here',
                      message: 'Bookings at this stage will show up here.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final b = shown[i];
                        return BookingCard(
                          title: '${b.clientName} \u2192 ${app.providerById(b.providerId).name}',
                          service: '${b.serviceName} \u00b7 ${b.quantityLabel}',
                          dateText: '${formatDate(b.dateTime)} \u00b7 ${formatTime(b.dateTime)}',
                          priceText: money(b.price),
                          status: b.status,
                          stage: b.stage,
                          footer: _details(app, b),
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
