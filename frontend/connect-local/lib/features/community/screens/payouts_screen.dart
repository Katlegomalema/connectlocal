import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/stat_card.dart';
import '../widgets/ui_kit.dart';
import 'payout_details_screen.dart';

/// Provider: bank account used for payouts, and every payout with its status.
class PayoutsScreen extends StatelessWidget {
  const PayoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final account = app.activePayoutAccount;
    final list = app.providerPayouts;
    final due = app.payoutTotal(list, PayoutStatus.due);
    final paid = app.payoutTotal(list, PayoutStatus.paid);

    return Scaffold(
      appBar: AppBar(title: const Text('Payouts')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await app.refreshPayouts();
          },
          child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.account_balance_outlined, color: AppColors.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: account == null
                        ? const Text('No bank account yet. Add one so you can be paid.',
                            style: TextStyle(fontSize: 14, color: AppColors.text))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${account.bank} · ${account.accountType}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text)),
                              const SizedBox(height: 2),
                              Text('${account.holderName} · ${account.masked}',
                                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                            ],
                          ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PayoutDetailsScreen())),
                    child: Text(account == null ? 'Add' : 'Edit'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: StatCard(
                      icon: Icons.hourglass_bottom_rounded,
                      label: 'Pending payout',
                      value: money(due))),
              const SizedBox(width: 14),
              Expanded(
                  child: StatCard(
                      icon: Icons.check_circle_outline, label: 'Paid out', value: money(paid))),
            ]),
            const SizedBox(height: 10),
            const Text(
              'When the customer has paid, the job price minus ConnectLocal’s '
              'commission is paid to your bank account automatically. For cash jobs you '
              'keep the cash and ConnectLocal pays you the booking fee minus its commission.',
              style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            SectionTitle('Payout history (${list.length})'),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No payouts yet',
              ),
            for (final p in list) ...[
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
                          Text('${p.clientName} · ${whenLabel(p.createdAt)}',
                              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                          Text('Job ${money(p.jobTotal)} − ConnectLocal ${money(p.commission)}',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          if (p.reference != null && p.reference!.isNotEmpty)
                            Text('Ref ${p.reference}',
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
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text)),
                        const SizedBox(height: 4),
                        StatusChip(p.status.label,
                            color: p.status == PayoutStatus.paid
                                ? AppColors.green
                                : AppColors.orange),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
          ),
        ),
      ),
    );
  }
}
