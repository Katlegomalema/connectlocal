import 'package:flutter/material.dart';

import '../../community/models/models.dart';
import '../../community/state/app_state.dart';
import '../../community/theme/app_theme.dart';
import '../../community/utils/format.dart';
import '../../community/widgets/stat_card.dart';
import '../../community/widgets/ui_kit.dart';

/// Every payout to a provider (from the server). Payouts are automatic (sent to the provider's saved bank
/// account once the balance is paid), so there is nothing for the admin to do here. Bank details are masked.
class AdminPayoutsScreen extends StatelessWidget {
  const AdminPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final all = List<Payout>.from(app.payouts)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final due = all.where((p) => p.status == PayoutStatus.due).toList();
    final paid = all.where((p) => p.status == PayoutStatus.paid).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Payouts')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(children: [
              Expanded(
                  child: StatCard(
                      icon: Icons.hourglass_bottom_rounded,
                      label: 'Processing',
                      value: money(app.payoutTotal(all, PayoutStatus.due)))),
              const SizedBox(width: 12),
              Expanded(
                  child: StatCard(
                      icon: Icons.check_circle_outline,
                      label: 'Paid out',
                      value: money(app.payoutTotal(all, PayoutStatus.paid)))),
            ]),
            const SizedBox(height: 24),
            if (due.isNotEmpty) ...[
              SectionTitle('Processing (${due.length})'),
              const SizedBox(height: 12),
              for (final p in due) ...[
                _PayoutTile(p, app),
                const SizedBox(height: 12),
              ],
            ],
            if (all.isEmpty)
              const EmptyState(icon: Icons.task_alt_outlined, title: 'No payouts yet'),
            if (paid.isNotEmpty) ...[
              const SizedBox(height: 12),
              SectionTitle('Paid (${paid.length})'),
              const SizedBox(height: 12),
              for (final p in paid) ...[
                _PayoutTile(p, app),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  final Payout p;
  final AppState app;
  const _PayoutTile(this.p, this.app);

  @override
  Widget build(BuildContext context) {
    final isDue = p.status == PayoutStatus.due;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.businessName ?? app.providerById(p.providerId).name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const SizedBox(height: 2),
                    Text('${p.serviceName} · ${p.clientName} · ${whenLabel(p.createdAt)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    Text('Job ${money(p.jobTotal)} · commission ${money(p.commission)}',
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
                  StatusChip(isDue ? 'Processing' : 'Paid', color: isDue ? AppColors.orange : AppColors.green),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: p.bankLabel == null
                ? const Text('No bank details yet – the provider has not added them.',
                    style: TextStyle(fontSize: 13, color: AppColors.red))
                : Text(p.bankLabel!, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.text)),
          ),
          if (isDue && p.note != null) ...[
            const SizedBox(height: 8),
            Text(p.note!, style: const TextStyle(fontSize: 12, color: AppColors.orange)),
          ],
          if (!isDue && p.reference != null) ...[
            const SizedBox(height: 8),
            Text('Paid ${p.paidAt == null ? '' : whenLabel(p.paidAt!)} · Ref ${p.reference}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}
