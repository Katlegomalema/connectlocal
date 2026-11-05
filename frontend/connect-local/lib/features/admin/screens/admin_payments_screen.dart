import 'package:flutter/material.dart';

import '../../community/models/models.dart';
import '../../community/state/app_state.dart';
import '../../community/theme/app_theme.dart';
import '../../community/utils/format.dart';
import '../../community/widgets/stat_card.dart';
import '../../community/widgets/ui_kit.dart';

/// Every payment recorded by the app, with totals. Card/EFT/Apple Pay payments
/// are confirmed by PayFast; cash is confirmed by the provider with the PIN.
class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({super.key});

  int _sum(List<PaymentRecord> list, bool Function(PaymentRecord) test) =>
      list.where(test).fold(0, (t, p) => t + p.amount);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final all = List<PaymentRecord>.from(app.payments)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final fees = _sum(all,
        (p) => p.kind == PaymentKind.bookingFee && p.status == PaymentStatus.paid);
    final held = _sum(all, (p) => p.status == PaymentStatus.held);
    final released = _sum(all, (p) => p.status == PaymentStatus.released);
    final cash = _sum(all, (p) => p.method == PayMethod.cash && p.status == PaymentStatus.paid);

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(children: [
              Expanded(
                  child: StatCard(
                      label: 'Booking fees', value: money(fees), icon: Icons.receipt_long_outlined)),
              const SizedBox(width: 12),
              Expanded(
                  child: StatCard(
                      label: 'Held', value: money(held), icon: Icons.lock_clock_outlined)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: StatCard(
                      label: 'Released', value: money(released), icon: Icons.send_outlined)),
              const SizedBox(width: 12),
              Expanded(
                  child: StatCard(
                      label: 'Cash received', value: money(cash), icon: Icons.payments_outlined)),
            ]),
            const SizedBox(height: 24),
            SectionTitle('Transactions (${all.length})'),
            const SizedBox(height: 12),
            if (all.isEmpty)
              const EmptyState(icon: Icons.receipt_long_outlined, title: 'No payments yet'),
            for (final p in all) ...[
              _PaymentTile(p, app.bookingById(p.bookingId)),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final PaymentRecord p;
  final Booking? booking;
  const _PaymentTile(this.p, this.booking);

  @override
  Widget build(BuildContext context) {
    final color = switch (p.status) {
      PaymentStatus.paid || PaymentStatus.released => AppColors.green,
      PaymentStatus.held || PaymentStatus.pending => AppColors.orange,
      PaymentStatus.refunded => AppColors.muted,
    };
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${p.kind.label}${booking == null ? '' : ' · ${booking!.serviceName}'}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 2),
                Text('${p.method.label} · ${whenLabel(p.createdAt)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                if (booking != null)
                  Text('Customer: ${booking!.clientName}',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                if (p.gatewayReference != null)
                  Text('Ref ${p.gatewayReference}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(money(p.amount),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 4),
              StatusChip(p.status.label, color: color),
              if (p.verified) ...[
                const SizedBox(height: 4),
                const StatusChip('Verified', color: AppColors.teal),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
