import 'package:flutter/material.dart';

import '../../community/models/models.dart';
import '../../community/state/app_state.dart';
import '../../community/theme/app_theme.dart';
import '../../community/utils/format.dart';
import '../../community/widgets/stat_card.dart';
import '../../community/widgets/ui_kit.dart';

/// What ConnectLocal earns. ConnectLocal keeps a fixed commission (10%, set by the business rules and
/// applied by the server) of every job; the provider gets the rest automatically.
class AdminEarningsScreen extends StatelessWidget {
  const AdminEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final rate = (app.commissionRate * 100).roundToDouble();

    final payouts = List<Payout>.from(app.payouts)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final jobsValue = payouts.fold<double>(0, (t, p) => t + p.jobTotal);
    final toProviders = payouts.fold<double>(0, (t, p) => t + p.amount);
    // Deposits for jobs that are still going on (held by ConnectLocal).
    final deposits = app.allBookings
        .where((b) => b.isActive && !b.feeRefunded)
        .fold<double>(0, (t, b) => t + b.bookingFee);

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(children: [
              Expanded(
                  child: StatCard(
                      icon: Icons.savings_outlined,
                      label: 'Commission earned',
                      value: money(app.commissionEarned))),
              const SizedBox(width: 12),
              Expanded(
                  child: StatCard(
                      icon: Icons.lock_clock_outlined,
                      label: 'Deposits held',
                      value: money(deposits))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: StatCard(
                      icon: Icons.work_outline,
                      label: 'Jobs paid (value)',
                      value: money(jobsValue))),
              const SizedBox(width: 12),
              Expanded(
                  child: StatCard(
                      icon: Icons.account_balance_outlined,
                      label: 'Paid to providers',
                      value: money(toProviders))),
            ]),
            const SizedBox(height: 24),
            const SectionTitle('Commission rate'),
            const SizedBox(height: 8),
            Text(
              'ConnectLocal keeps ${rate.round()}% of each completed job. The provider receives the rest in '
              'their bank account automatically. The 15% deposit the customer pays when booking counts toward '
              'the price. The rate is fixed on the server.',
              style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Commission', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                      Text('${rate.round()}%',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.teal)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'Example: a R1,000 job → ConnectLocal ${money(app.commissionFor(1000))}, '
                      'provider ${money(1000 - app.commissionFor(1000))}',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionTitle('Per job (${payouts.length})'),
            const SizedBox(height: 12),
            if (payouts.isEmpty)
              const EmptyState(icon: Icons.paid_outlined, title: 'No paid jobs yet'),
            for (final p in payouts) ...[
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.serviceName,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text)),
                          const SizedBox(height: 2),
                          Text(
                              '${p.businessName ?? app.providerById(p.providerId).name} · ${whenLabel(p.createdAt)}\n'
                              'Job ${money(p.jobTotal)} · provider ${money(p.amount)}',
                              style: const TextStyle(
                                  fontSize: 13, height: 1.4, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Text('+${money(p.commission)}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.green)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
