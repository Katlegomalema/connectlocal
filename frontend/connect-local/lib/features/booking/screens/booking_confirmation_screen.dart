import 'package:flutter/material.dart';
import '../../community/utils/format.dart';

import '../../community/screens/customer_bookings_screen.dart';
import '../models/booking_request.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

// Screen 38 - Booking Request Sent
//
// The booking is NOT confirmed yet: it is waiting for the provider to accept.
class BookingConfirmationScreen extends StatelessWidget {
  final String bookingId;
  final String transactionId;
  final BookingRequest request;

  const BookingConfirmationScreen({
    super.key,
    required this.bookingId,
    required this.transactionId,
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    final hours = request.packageName ?? (request.hours == 1 ? '1 hour' : '${request.hours} hours');
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Image.asset('assets/images/booking_confirmed.png', height: 160),
              const SizedBox(height: 20),
              const Text('Request Sent!',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 10),
              Text(
                'Your deposit is paid. ${request.providerName} will review your '
                'request. Once they accept, you’ll pay ${money(request.serviceTotal)} for the service.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textGrey),
              ),
              const SizedBox(height: 20),
              GreyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoLine('Booking ID: $bookingId', top: 0),
                    InfoLine('Transaction ID: $transactionId'),
                    InfoLine('Provider: ${request.providerName}'),
                    InfoLine('Service: ${request.serviceName}'),
                    InfoLine('Date: ${request.date}'),
                    InfoLine('Time: ${request.time}  ($hours)'),
                    InfoLine('Address: ${request.address}'),
                    InfoLine('Deposit paid: ${money(request.fee)} (counts toward the price)'),
                    InfoLine('Due after acceptance: ${money(request.serviceTotal)}'),
                    const InfoLine('Status: Awaiting provider'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              TealButton(
                'View My Bookings',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerBookingsScreen()),
                ),
              ),
              const SizedBox(height: 12),
              TealButton(
                'Back to Home',
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
