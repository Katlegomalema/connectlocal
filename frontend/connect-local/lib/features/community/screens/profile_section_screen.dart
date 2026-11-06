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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = AppScope.read(context);
      if (widget.section == 'Notifications') app.refreshNotifications();
      if (widget.section == 'Payment History') app.refreshMyPayments();
    });
  }

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
        final items = app.notifications;
        final anyUnread = app.unreadNotifications > 0;
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => app.refreshNotifications(),
            child: ListView(children: const [
              SizedBox(height: 80),
              EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'You\u2019re all caught up',
                message: 'New activity will show up here.',
              ),
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: () => app.refreshNotifications(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              for (final item in items) ...[
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: item.isRead ? AppColors.inputBg : AppColors.avatarBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.isRead ? Icons.done_all_rounded : Icons.notifications_none_rounded,
                          size: 20,
                          color: item.isRead ? AppColors.muted : AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.35,
                                color: item.isRead ? AppColors.muted : AppColors.text,
                                fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                              ),
                            ),
                            if (item.body.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(item.body,
                                  style: const TextStyle(fontSize: 14, height: 1.35, color: AppColors.text)),
                            ],
                            const SizedBox(height: 4),
                            Text(whenLabel(item.createdAt),
                                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (anyUnread) ...[
                const SizedBox(height: 4),
                PrimaryButton(
                  'Mark all as read',
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final error = await app.markNotificationsRead();
                    if (error != null) {
                      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(error)));
                    }
                  },
                ),
              ],
            ],
          ),
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
                          'Booking fees are always paid online. You enter your payment details on PayFast’s secure page; ConnectLocal never stores them.',
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
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final p = payments[index];
            final booking = app.bookingById(p.bookingId);
            final statusColor = switch (p.status) {
              PaymentStatus.paid => AppColors.green,
              PaymentStatus.refunded => AppColors.muted,
              PaymentStatus.failed => AppColors.red,
              PaymentStatus.pending => AppColors.orange,
            };
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
                          '${p.kind == PaymentKind.bookingFee ? 'Booking fee' : 'Service'}'
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
                        switch (p.status) {
                          PaymentStatus.paid => p.method == PayMethod.cash ? 'Paid in cash' : 'Paid · Verified',
                          PaymentStatus.refunded => 'Refunded',
                          PaymentStatus.failed => 'Failed',
                          PaymentStatus.pending => 'Pending',
                        },
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
