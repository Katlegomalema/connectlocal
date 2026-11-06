import 'package:flutter/material.dart';

import '../../shared/validators.dart';

import '../widgets/action_feedback.dart';

import '../../booking/screens/payment_method_screen.dart';
import '../../booking/screens/payment_processing_screen.dart';
import '../../shared/brand.dart';
import '../../shared/booking_maps.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui_kit.dart';
import 'chat_screen.dart';

/// Customer view of one booking: what happens next, price breakdown,
/// pay / cancel / review.
class CustomerBookingDetailScreen extends StatelessWidget {
  final String bookingId;
  const CustomerBookingDetailScreen({super.key, required this.bookingId});

  /// Pushes this screen with a route name so payment can come back to it.
  static Future<void> open(BuildContext context, Booking booking) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'booking-detail'),
          builder: (_) => CustomerBookingDetailScreen(bookingId: booking.id),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final b = app.bookingById(bookingId);
    if (b == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: const EmptyState(icon: Icons.search_off_rounded, title: 'Booking not found'),
      );
    }
    final provider = app.providerById(b.providerId);
    // The service cost is paid AFTER the provider finishes the job.
    final needsPayment = b.status == BookingStatus.completed &&
        !b.balancePaid &&
        b.serviceMethod == null;
    // A request whose 15% booking fee was never confirmed (app closed or network lost during PayFast):
    // finish paying it. The server returns the same payment, so this never charges twice.
    final feeUnpaid = b.status == BookingStatus.pending && !app.feePaid(b) && !b.feeRefunded;
    // Can't cancel once the provider has been verified and the job has started.
    final canCancel = b.status == BookingStatus.pending ||
        (b.status == BookingStatus.confirmed && !b.pinVerified);
    final canReview =
        b.status == BookingStatus.completed && b.balancePaid && b.rating == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // ---- header ----
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(provider.name,
                                  style: headingStyle(
                                      size: 18, weight: FontWeight.w600, color: AppColors.text)),
                              const SizedBox(height: 2),
                              Text(
                                '${b.serviceName} · ${b.quantityLabel}',
                                style: const TextStyle(fontSize: 14, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        StatusChip(b.stage.label, color: bookingStageColor(b.stage)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ---- what happens next ----
                  _NextStep(booking: b, providerName: provider.name),
                  if (b.status == BookingStatus.confirmed && b.completionPin != null) ...[
                    const SizedBox(height: 14),
                    _PinCard(
                      pin: b.completionPin!,
                      verified: b.pinVerified,
                      locked: b.pinAttempts >= kMaxPinAttempts,
                    ),
                  ],
                  const SizedBox(height: 22),

                  // ---- details ----
                  const SectionTitle('Details'),
                  const SizedBox(height: 10),
                  AppCard(
                    child: Column(
                      children: [
                        _detail(Icons.calendar_today_outlined, 'Date', formatDate(b.dateTime)),
                        _detail(Icons.schedule_rounded, 'Time', formatTime(b.dateTime)),
                        _detail(b.atBusiness ? Icons.storefront_outlined : Icons.home_outlined, 'Type',
                            b.locationTypeLabel),
                        if (b.atBusiness)
                          _detail(Icons.location_on_outlined, 'Business address',
                              provider.address.isEmpty ? 'See the map below' : provider.address)
                        else
                          _detail(Icons.location_on_outlined, 'Your address',
                              b.address.isEmpty ? 'Not provided' : b.address),
                        if (b.notes.isNotEmpty)
                          _detail(Icons.notes_rounded, 'Notes', b.notes),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ---- payment ----
                  const SectionTitle('Payment'),
                  const SizedBox(height: 10),
                  AppCard(
                    child: Column(
                      children: [
                        _money(
                          'Booking fee (${(kBookingFeeRate * 100).round()}%, counts toward the price)',
                          money(b.bookingFee),
                          b.feeRefunded
                              ? StatusChip('Refunded', color: AppColors.muted)
                              : StatusChip('Paid', color: AppColors.green),
                        ),
                        const Divider(height: 22),
                        _money(
                          'Remaining balance',
                          money(b.balance),
                          (b.status == BookingStatus.declined ||
                                  b.status == BookingStatus.cancelled)
                              ? StatusChip('Not charged', color: AppColors.muted)
                              : b.balancePaid
                                  ? StatusChip('Paid', color: AppColors.green)
                                  : b.serviceMethod == PayMethod.cash
                                      ? StatusChip('Cash: provider to confirm',
                                          color: AppColors.orange)
                                      : b.status == BookingStatus.completed
                                          ? StatusChip('Due now', color: AppColors.orange)
                                          : StatusChip('Pay after the service',
                                              color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),

                  // ---- map: Business Location Map (visit) or Customer Location Map (house call) ----
                  if (b.atBusiness && provider.hasBusinessLocation) ...[
                    const SizedBox(height: 22),
                    BusinessLocationMap(
                      businessId: provider.id,
                      businessName: provider.name,
                      address: provider.address,
                      latitude: provider.latitude,
                      longitude: provider.longitude,
                    ),
                  ] else if (!b.atBusiness && b.latitude != null && b.longitude != null) ...[
                    const SizedBox(height: 22),
                    CustomerLocationMap(
                      latitude: b.latitude!,
                      longitude: b.longitude!,
                      title: 'Where the provider will come',
                      address: b.address,
                    ),
                  ],
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(booking: b, viewerIsProvider: false),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                    label: const Text('Message provider'),
                  ),
                  if (canCancel) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => _confirmCancel(context, app, b),
                      style: TextButton.styleFrom(foregroundColor: AppColors.red),
                      child: const Text('Cancel booking',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
            if (needsPayment || canReview || feeUnpaid)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                ),
                child: feeUnpaid
                    ? PrimaryButton(
                        'Finish paying the ${money(b.bookingFee)} booking fee',
                        icon: Icons.lock_outline_rounded,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PaymentProcessingScreen(feeFor: b)),
                        ),
                      )
                    : needsPayment
                    ? PrimaryButton(
                        'Pay ${money(b.balance)}',
                        icon: Icons.lock_outline_rounded,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentMethodScreen(balanceFor: b),
                          ),
                        ),
                      )
                    : PrimaryButton(
                        'Leave a review',
                        icon: Icons.star_outline_rounded,
                        onPressed: () => showReview(context, app, b),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.teal),
            const SizedBox(width: 12),
            SizedBox(
              width: 70,
              child: Text(label,
                  style: const TextStyle(fontSize: 14, color: AppColors.muted)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
            ),
          ],
        ),
      );

  Widget _money(String label, String amount, Widget chip) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(amount,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
              ],
            ),
          ),
          chip,
        ],
      );

  Future<void> _confirmCancel(BuildContext context, AppState app, Booking b) async {
    final pending = b.status == BookingStatus.pending;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text(pending
            ? 'Your booking fee of ${money(b.bookingFee)} will be refunded.'
            : 'The provider already accepted, so the booking fee of ${money(b.bookingFee)} '
                'is non-refundable.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep booking')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final message = await app.cancelBooking(b);
    messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 4), content: Text(message)));
  }

  /// Opens the star-rating sheet. Also used from the My Bookings list.
  static Future<void> showReview(BuildContext context, AppState app, Booking b) async {
    var stars = 5;
    final comment = TextEditingController();
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('How was your service?'),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setSheet(() => stars = i),
                      iconSize: 38,
                      icon: Icon(
                        i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: AppColors.orange,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: comment,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Add a comment (optional)'),
              ),
              const SizedBox(height: 16),
              PrimaryButton('Submit review', onPressed: () => Navigator.pop(ctx, true)),
            ],
          ),
        ),
      ),
    );
    // The controller is not disposed on purpose: the sheet is still animating
    // closed here and disposing it now can throw "used after being disposed".
    final text = comment.text;
    final problem = Validators.text(text, max: 500, label: 'Your review');
    if (sent == true && problem != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 4), content: Text(problem)));
      return;
    }
    if (sent == true && context.mounted) {
      await runAction(context, app.addReview(b, rating: stars, comment: text), success: 'Thanks for your review!');
    }
  }
}

/// A coloured box saying what happens next for this booking.
class _NextStep extends StatelessWidget {
  final Booking booking;
  final String providerName;
  const _NextStep({required this.booking, required this.providerName});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final IconData icon;
    final Color color;
    final String title;
    final String text;
    switch (b.status) {
      case BookingStatus.pending:
        icon = Icons.hourglass_bottom_rounded;
        color = AppColors.orange;
        title = 'Waiting for the provider';
        text = '$providerName will review your request. Your booking fee of ${money(b.bookingFee)} secures it; you pay the remaining ${money(b.balance)} after the service is done.';
      case BookingStatus.confirmed:
        if (b.pinVerified) {
          icon = Icons.handyman_outlined;
          color = AppColors.green;
          title = 'Service in progress';
          text = '$providerName was verified with your PIN. When the job is finished you will be asked to pay the remaining ${money(b.balance)}.';
        } else {
          icon = Icons.check_circle_outline_rounded;
          color = AppColors.green;
          title = 'Booking secured';
          text = '$providerName accepted your request and your booking fee secured it. '
              'Give them your PIN when they arrive. You pay the remaining ${money(b.balance)} after the service.';
        }
      case BookingStatus.completed:
        icon = Icons.verified_outlined;
        // Orange while the customer still has to pay, blue otherwise.
        color = (b.rating == null && !b.balancePaid) ? AppColors.orange : AppColors.teal;
        if (b.rating != null) {
          title = 'Thanks for your review';
          text = 'You rated this job ${b.rating} out of 5.';
        } else if (!b.balancePaid && b.serviceMethod == PayMethod.cash) {
          title = 'Waiting for cash confirmation';
          text = 'Pay ${money(b.balance)} in cash to $providerName. They will confirm they received it.';
        } else if (!b.balancePaid) {
          title = 'Job done: payment due';
          text = 'Please pay the remaining ${money(b.balance)} by card, Instant EFT or cash.';
        } else {
          title = 'Job completed and paid';
          text = 'How did it go? Your review helps other customers.';
        }
      case BookingStatus.declined:
        icon = Icons.info_outline_rounded;
        color = AppColors.red;
        title = 'Request declined';
        text = '$providerName couldn’t take this booking. Your booking fee of ${money(b.bookingFee)} is refunded.';
      case BookingStatus.cancelled:
        icon = Icons.cancel_outlined;
        color = AppColors.muted;
        title = 'Booking cancelled';
        text = b.feeRefunded
            ? 'Your booking fee of ${money(b.bookingFee)} is refunded.'
            : 'The booking fee is non-refundable once a provider has accepted.';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 3),
                Text(text,
                    style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The service PIN. The customer reads it to the provider when they ARRIVE: it
/// verifies the provider for this booking and starts the job.
class _PinCard extends StatelessWidget {
  final String pin;
  final bool verified;
  final bool locked;
  const _PinCard({required this.pin, required this.verified, required this.locked});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: verified ? AppColors.green : AppColors.accent, width: 1.4),
        ),
        child: Column(
          children: [
            Text(verified ? 'Provider verified' : 'Your service PIN',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: verified ? AppColors.green : AppColors.accent)),
            const SizedBox(height: 8),
            if (verified)
              const Icon(Icons.verified_rounded, size: 44, color: AppColors.green)
            else
              Text(pin.split('').join('  '),
                  style: const TextStyle(
                      fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 8),
            Text(
              verified
                  ? 'The PIN was entered by your provider. The job has started.'
                  : locked
                      ? 'Too many wrong attempts. Please contact support.'
                      : 'Give this PIN to your provider when they ARRIVE. It confirms they are the right person for this booking. Never share it in advance or with anyone else.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted),
            ),
          ],
        ),
      );
}
