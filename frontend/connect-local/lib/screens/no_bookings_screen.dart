import 'package:flutter/material.dart';

import '../features/community/widgets/ui_kit.dart';

/// Shown on My Bookings when the customer has never made a booking.
class NoBookingsScreen extends StatelessWidget {
  const NoBookingsScreen({super.key, this.onBrowseServices});

  final VoidCallback? onBrowseServices;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              child: EmptyState(
                icon: Icons.event_busy_outlined,
                title: 'No bookings yet',
                message: 'Start exploring services in your area.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: PrimaryButton(
                'Browse Services',
                onPressed: onBrowseServices ??
                    () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(duration: const Duration(seconds: 3), 
                            content: Text('Connect this button to your services screen.'),
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
