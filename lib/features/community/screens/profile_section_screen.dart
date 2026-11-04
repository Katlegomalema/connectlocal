import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui_kit.dart';

/// Simple profile sub-pages: Notifications, Payment Methods, Payment History
/// and Settings. (Verify Phone has its own screen: verify_phone_screen.dart.)
class ProfileSectionScreen extends StatefulWidget {
  final String section;
  const ProfileSectionScreen({super.key, required this.section});

  @override
  State<ProfileSectionScreen> createState() => _ProfileSectionScreenState();
}

class _ProfileSectionScreenState extends State<ProfileSectionScreen> {
  bool _pushNotifications = true;
  bool _marketingMessages = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.section)),
      body: SafeArea(child: _content(context)),
    );
  }

  Widget _content(BuildContext context) {
    final app = AppScope.of(context);
    switch (widget.section) {
      case 'Notifications':
        final unread = app.unreadCustomerNotifications > 0;
        if (app.customerNotifications.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'You’re all caught up',
            message: 'New activity will show up here.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            for (final item in app.customerNotifications) ...[
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: unread ? AppColors.avatarBg : AppColors.inputBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        unread ? Icons.notifications_none_rounded : Icons.done_all_rounded,
                        size: 20,
                        color: unread ? AppColors.teal : AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              color: unread ? AppColors.text : AppColors.muted,
                              fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            unread ? 'Recent activity' : 'Read',
                            style: const TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (unread) ...[
              const SizedBox(height: 4),
              PrimaryButton(
                'Mark all as read',
                onPressed: () {
                  app.markCustomerNotificationsRead();
                  setState(() {});
                },
              ),
            ],
          ],
        );
      case 'Payment Methods':
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: const [
            AppCard(
              child: Row(
                children: [
                  Icon(Icons.credit_card_rounded, color: AppColors.teal, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Card, Instant EFT & Apple Pay (PayFast)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text(
                          'Deposits are always paid online. You enter your payment details on PayFast’s secure page; ConnectLocal never stores them.',
                          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            AppCard(
              child: Row(
                children: [
                  Icon(Icons.payments_outlined, color: AppColors.green, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cash',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text(
                          'You can pay the service cost in cash to your provider after the job. They confirm they received it.',
                          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case 'Payment History':
        final payments = app.customerPayments;
        if (payments.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No payment history yet',
            message: 'Your payments will be listed here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: payments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final p = payments[index];
            final booking = app.bookingById(p.bookingId);
            final statusColor = (p.status == PaymentStatus.paid ||
                    p.status == PaymentStatus.released)
                ? AppColors.green
                : p.status == PaymentStatus.refunded
                    ? AppColors.muted
                    : AppColors.orange;
            return AppCard(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.avatarBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      p.method == PayMethod.cash
                          ? Icons.payments_outlined
                          : p.method == PayMethod.scanToPay
                              ? Icons.qr_code_scanner_rounded
                              : p.method == PayMethod.instantEft || p.method == PayMethod.capitecPay
                                  ? Icons.account_balance_outlined
                                  : Icons.credit_card_rounded,
                      size: 22,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p.kind == PaymentKind.bookingFee ? 'Deposit' : 'Service'}'
                          '${booking == null ? '' : ' · ${booking.serviceName}'}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p.method.label} · ${whenLabel(p.createdAt)}',
                          style: const TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
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
                      StatusChip(
                        p.status == PaymentStatus.held
                            ? 'Held until job done'
                            : p.status == PaymentStatus.released
                                ? 'Released to provider'
                            : p.status == PaymentStatus.paid && p.verified
                            ? 'Paid · Verified'
                            : p.status == PaymentStatus.paid
                                ? 'Paid'
                                : p.status == PaymentStatus.refunded
                                    ? 'Refunded'
                                    : 'Pending',
                        color: statusColor,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      case 'Settings':
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _pushNotifications,
                    onChanged: (value) => setState(() => _pushNotifications = value),
                    title: const Text('Push notifications'),
                    subtitle: const Text('Booking updates and messages'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    value: app.locationEnabled,
                    onChanged: (value) => app.setLocationEnabled(value),
                    title: const Text('Location services'),
                    subtitle: const Text('Used to show how far providers are from you'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    value: _marketingMessages,
                    onChanged: (value) => setState(() => _marketingMessages = value),
                    title: const Text('Product updates'),
                    subtitle: const Text('News and tips from ConnectLocal'),
                  ),
                ],
              ),
            ),
          ],
        );
      default:
        return const EmptyState(
          icon: Icons.construction_outlined,
          title: 'Not available yet',
          message: 'This section is coming soon.',
        );
    }
  }
}
