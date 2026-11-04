import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_menu_item.dart';
import 'messages_screen.dart';
import 'no_bookings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showMessage(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(duration: const Duration(seconds: 3), content: Text('$title selected')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 12,
          ),
          children: [
            const SizedBox(height: 22),

            const CircleAvatar(
              radius: 38,
              backgroundColor: Color(0xFFDDF3F2),
              child: Icon(
                Icons.person,
                size: 52,
                color: AppTheme.teal,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Lucas Doe',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.text,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'lucas.doe@email.com',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.muted,
              ),
            ),

            const SizedBox(height: 12),

            Center(
              child: TextButton(
                onPressed: () =>
                    _showMessage(context, 'Edit Profile'),
                child: const Text('Edit Profile'),
              ),
            ),

            const SizedBox(height: 12),

            // My Bookings
            ProfileMenuItem(
              icon: Icons.description_outlined,
              title: 'My Bookings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NoBookingsScreen(),
                  ),
                );
              },
              showArrow: false,
            ),

            // Messages
            ProfileMenuItem(
              icon: Icons.chat_bubble_outline,
              title: 'Messages',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MessagesScreen(),
                  ),
                );
              },
              showArrow: false,
            ),

            ProfileMenuItem(
              icon: Icons.notifications_none,
              title: 'Notifications',
              onTap: () =>
                  _showMessage(context, 'Notifications'),
              showArrow: false,
            ),

            ProfileMenuItem(
              icon: Icons.credit_card,
              title: 'Payment Methods',
              onTap: () =>
                  _showMessage(context, 'Payment Methods'),
            ),

            ProfileMenuItem(
              icon: Icons.bar_chart,
              title: 'Payment History',
              onTap: () =>
                  _showMessage(context, 'Payment History'),
            ),

            ProfileMenuItem(
              icon: Icons.phone_outlined,
              title: 'Verify Phone',
              onTap: () =>
                  _showMessage(context, 'Verify Phone'),
            ),

            ProfileMenuItem(
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () => _showMessage(context, 'Settings'),
            ),

            const SizedBox(height: 28),

            Center(
              child: TextButton.icon(
                onPressed: () =>
                    _showMessage(context, 'Logout'),
                icon: const Icon(
                  Icons.logout,
                  size: 15,
                  color: Colors.redAccent,
                ),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}