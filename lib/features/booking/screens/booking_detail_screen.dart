import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'booking_screen.dart';

// Screen 17 - Booking Detail
class BookingDetailScreen extends StatelessWidget {
  // TODO (DB): load the full booking + provider (rating, photo) by id
  final Booking booking;

  const BookingDetailScreen({
    super.key,
    this.booking = const Booking(
      id: '#BK-2025-001',
      provider: 'Bobs Plumbing',
      service: 'Pipe repair',
      date: '15 July 2026',
      time: '10:00 AM',
      total: 'R350',
      status: 'Confirmed',
    ),
  });

  Future<void> _confirmCancel(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      // TODO (DB): mark the booking as cancelled
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(duration: const Duration(seconds: 3), content: Text('Booking cancelled')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
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
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(b.status,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCEBFA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.image_outlined, color: Color(0xFF7FB2E5)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.provider,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy)),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(Icons.star, size: 14, color: AppColors.teal),
                          SizedBox(width: 4),
                          Text('4.8',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navy)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              InfoLine('Booking ID: ${b.id}', top: 16),
              InfoLine('Service: ${b.service}', top: 14),
              // Figma repeats "Service: Pipe repair" here; using Date instead (confirm with designer)
              InfoLine('Date: ${b.date}', top: 14),
              InfoLine('Time: ${b.time}', top: 14),
              InfoLine('Total: ${b.total}', top: 14),
              const SizedBox(height: 48),
              TealButton(
                'Contact Button',
                // TODO: open call / chat with the provider
                onPressed: () => ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(duration: const Duration(seconds: 3), content: Text('Contacting provider...'))),
              ),
              const SizedBox(height: 12),
              TealButton(
                'Reschedule Booking',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookingScreen()),
                ),
              ),
              const SizedBox(height: 80),
              Center(
                child: InkWell(
                  onTap: () => _confirmCancel(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Cancel Booking',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.cancelRed,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.cancelRed,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}