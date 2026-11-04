import 'package:flutter/material.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({
    super.key,
    this.transactionId = 'TXN-2026-07-27-001',
    this.service = 'Pipe Repair',
    this.provider = 'Bobs Plumbing',
    this.date = '15 July 2025',
    this.time = '10:00 AM',
    this.amount = 'R350',
    this.bookingFee = 'R25',
    this.total = 'R375',
    this.onViewBookings,
    this.onBackHome,
  });

  final String transactionId;
  final String service;
  final String provider;
  final String date;
  final String time;
  final String amount;
  final String bookingFee;
  final String total;

  final VoidCallback? onViewBookings;
  final VoidCallback? onBackHome;

  static const Color teal = Color(0xFF1F5FA8);
  static const Color darkText = Color(0xFF34405B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 26,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // Payment success illustration
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: teal.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 68,
                      color: teal,
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'Payment Successful!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Your booking has been confirmed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF66718A),
                  ),
                ),

                const SizedBox(height: 34),

                // Booking details
                _DetailRow(
                  label: 'Transaction ID',
                  value: transactionId,
                ),
                _DetailRow(
                  label: 'Service',
                  value: service,
                ),
                _DetailRow(
                  label: 'Provider',
                  value: provider,
                ),
                _DetailRow(
                  label: 'Date',
                  value: date,
                ),
                _DetailRow(
                  label: 'Time',
                  value: time,
                ),

                const SizedBox(height: 18),

                const Divider(
                  color: Color(0xFFE4E7EF),
                ),

                const SizedBox(height: 12),

                _DetailRow(
                  label: 'Amount',
                  value: amount,
                ),
                _DetailRow(
                  label: 'Deposit',
                  value: bookingFee,
                ),

                const SizedBox(height: 8),

                _DetailRow(
                  label: 'Total',
                  value: total,
                  bold: true,
                ),

                const SizedBox(height: 30),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onViewBookings ??
                            () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(duration: const Duration(seconds: 3), 
                              content: Text(
                                'Connect this button to My Bookings.',
                              ),
                            ),
                          );
                        },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'View My Bookings',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onBackHome ??
                            () {
                          Navigator.of(context).popUntil(
                                (route) => route.isFirst,
                          );
                        },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Back to Home',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 14,
      height: 1.5,
      color: const Color(0xFF34405B),
      fontWeight: bold ? FontWeight.bold : FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              '$label:',
              style: style,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.start,
              style: style,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}