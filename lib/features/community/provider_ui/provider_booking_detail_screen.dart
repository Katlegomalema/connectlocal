import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'avatar_box.dart';
import 'common.dart';

// Screen 29 - Provider Booking Detail
//
// Opened from the provider's bookings list with real data and working buttons.
// Opened without callbacks (admin "Bookings" tile) it shows sample data and the
// buttons only show a message.
class ProviderBookingDetailScreen extends StatelessWidget {
  // TODO (DB): load the booking and the customer's details by id
  final String status;
  final Color statusColor;
  final String customerName;
  final String phone;
  final String service;
  final String date;
  final String time;
  final String location;
  final String total;
  final String notes;

  /// Show the Confirm / Decline buttons.
  final bool showActions;
  final VoidCallback? onConfirm;
  final VoidCallback? onDecline;

  /// When set, a single action button (see [completeLabel]) is shown instead.
  final VoidCallback? onComplete;

  /// Label of the single action button when [onComplete] is set.
  final String completeLabel;
  final VoidCallback? onChat;

  /// Opens directions to the customer (provider's view).
  final VoidCallback? onDirections;

  const ProviderBookingDetailScreen({
    super.key,
    this.status = 'Pending Confirmation',
    this.statusColor = const Color(0xFFF5C518),
    this.customerName = 'Lucas Doe',
    this.phone = '082 123 4567',
    this.service = 'Pipe repair',
    this.date = '15 June 2025',
    this.time = '10:00 AM',
    this.location = '123 Main St, Cape Town',
    this.total = 'R350',
    this.notes = 'Please bring all necessary tools.',
    this.showActions = true,
    this.onConfirm,
    this.onDecline,
    this.onComplete,
    this.completeLabel = 'Enter PIN to Verify & Start',
    this.onChat,
    this.onDirections,
  });

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(text)));
  }

  /// Runs the real action and closes this screen, or shows a sample message.
  void _act(BuildContext context, VoidCallback? action, String sampleMessage) {
    if (action == null) {
      _message(context, sampleMessage);
      return;
    }
    action();
    Navigator.maybePop(context);
  }

  Widget _line(String text) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeader('Booking Details'),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderGrey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(status,
                        style: const TextStyle(fontSize: 14, color: AppColors.textGrey)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const AvatarBox(size: 48),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customerName,
                          style: const TextStyle(fontSize: 13, color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      Text(phone,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _line('Service: $service'),
              _line('Date: $date'),
              _line('Time: $time'),
              _line('Location: $location'),
              if (onDirections != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: OutlinedButton.icon(
                    onPressed: onDirections,
                    icon: const Icon(Icons.directions_outlined, size: 20),
                    label: const Text('Get directions to the customer'),
                  ),
                ),
              _line('Total: $total'),
              const SizedBox(height: 22),
              const Text('Customer Notes:',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(notes.trim().isEmpty ? 'No notes added.' : '"$notes"',
                  style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
              const SizedBox(height: 28),
              if (onComplete != null)
                TealButton(
                  completeLabel,
                  height: 44,
                  // The PIN dialog opens on top of this screen; it stays open.
                  onPressed: () => onComplete!(),
                )
              else if (showActions)
                Row(
                  children: [
                    Expanded(
                      child: TealButton(
                        'Confirm',
                        height: 44,
                        // TODO (DB): mark the booking as confirmed
                        onPressed: () => _act(context, onConfirm, 'Booking confirmed'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TealButton(
                        'Decline',
                        height: 44,
                        // TODO (DB): mark the booking as declined
                        onPressed: () => _act(context, onDecline, 'Booking declined'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              TealButton(
                'Chat with Customer',
                height: 44,
                onPressed: () {
                  final chat = onChat;
                  if (chat == null) {
                    _message(context, 'Open the chat');
                  } else {
                    chat();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
