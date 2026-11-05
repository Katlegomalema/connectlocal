import 'package:flutter/material.dart';

import '../../community/models/models.dart';
import '../../community/state/app_state.dart';
import '../../community/theme/app_theme.dart';
import '../../community/utils/format.dart';
import '../../community/widgets/stat_card.dart';
import '../../community/widgets/ui_kit.dart';

/// Every payment the server recorded (table `payments`), with totals. Card payments are confirmed by
/// PayFast's ITN; cash balances are confirmed by the provider.
class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({super.key});

  double _sum(List<PaymentRecord> list, bool Function(PaymentRecord) test) =>
      list.where(test).fold<double>(0, (t, p) => t + p.amount);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final all = List<PaymentRecord>.from(app.payments)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final fees = _sum(all,
        (p) => p.kind == PaymentKind.bookingFee && p.status == PaymentStatus.paid);
    final balances = _sum(all,
        (p) => p.kind == PaymentKind.service && p.method != PayMethod.cash && p.status == PaymentStatus.paid);
    final refunded = _sum(all, (p) => p.status == PaymentStatus.refunded);
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
                      label: 'Balances by card', value: money(balances), icon: Icons.credit_card_rounded)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: StatCard(
                      label: 'Refunded', value: money(refunded), icon: Icons.undo_rounded)),
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
      PaymentStatus.paid => AppColors.green,
      PaymentStatus.pending => AppColors.orange,
      PaymentStatus.failed => AppColors.red,
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
                    [p.kind.label, if ((p.serviceName ?? booking?.serviceName) != null) p.serviceName ?? booking!.serviceName]
                        .join(' · '),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 2),
                Text('${p.method.label} · ${whenLabel(p.createdAt)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                if ((p.customerName ?? booking?.clientName) != null)
                  Text(
                      'Customer: ${p.customerName ?? booking!.clientName}'
                      '${p.businessName == null ? '' : ' → ${p.businessName}'}',
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
