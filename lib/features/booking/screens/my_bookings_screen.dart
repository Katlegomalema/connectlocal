import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../theme/app_colors.dart';
import 'booking_detail_screen.dart';

// Screen 16 - My Bookings
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  bool _upcoming = true;

  // TODO (DB): load upcoming / past bookings for the logged-in user
  static const _upcomingList = [
    Booking(
        id: '#BK-2026-001', provider: 'Bobs Plumbing', service: 'Pipe repair',
        date: '15 July 2026', time: '10:00 AM', total: 'R350', status: 'Pending'),
    Booking(
        id: '#BK-2026-002', provider: "John's Tutoring", service: 'Pipe repair',
        date: '16 July 2026', time: '14:00 PM', total: 'R200', status: 'Confirmed'),
  ];
  static const _pastList = [
    Booking(
        id: '#BK-2026-003', provider: 'Sparkle Cleaners', service: 'Home cleaning',
        date: '2 June 2026', time: '09:00 AM', total: 'R280', status: 'Completed'),
    Booking(
        id: '#BK-2026-004', provider: 'Bobs Plumbing', service: 'Tap repair',
        date: '20 May 2026', time: '11:00 AM', total: 'R150', status: 'Completed'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = _upcoming ? _upcomingList : _pastList;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('My Bookings',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 20),
              Row(
                children: [
                  _tab('Upcoming', _upcoming, () => setState(() => _upcoming = true)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('|', style: TextStyle(fontSize: 14, color: AppColors.textDark)),
                  ),
                  _tab('Past', !_upcoming, () => setState(() => _upcoming = false)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) => _BookingTile(booking: items[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(String text, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: active ? AppColors.textDark : AppColors.textGrey,
      ),
    ),
  );
}

class _BookingTile extends StatelessWidget {
  final Booking booking;
  const _BookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: b)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.provider,
                      style: const TextStyle(fontSize: 11, color: AppColors.textDark)),
                  const SizedBox(height: 6),
                  Text(b.service,
                      style: const TextStyle(fontSize: 12, color: AppColors.navy)),
                  const SizedBox(height: 6),
                  Text('Total:${b.total}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textDark)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.date,
                      style: const TextStyle(fontSize: 12, color: AppColors.textDark)),
                  const SizedBox(height: 6),
                  Text(b.time,
                      style: const TextStyle(fontSize: 12, color: AppColors.textDark)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: b.status == 'Pending'
                          ? AppColors.badgeOrange
                          : AppColors.badgeGreen,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(b.status,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}