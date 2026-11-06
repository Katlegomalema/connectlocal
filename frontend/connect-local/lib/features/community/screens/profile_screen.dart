import 'package:flutter/material.dart';

import '../../shared/validators.dart';

import '../widgets/logout.dart';

import '../../shared/photo_picker.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../../shared/brand.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'customer_bookings_screen.dart';
import 'home_feed_screen.dart';
import 'messages_screen.dart';
import 'profile_section_screen.dart';
import 'verify_phone_screen.dart';
import 'provider_application_screens.dart';
import 'provider_dashboard_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editProfile(BuildContext context, AppState app) async {
    final result = await showDialog<({String name, String email})>(
      context: context,
      builder: (_) => _EditProfileDialog(
        initialName: app.customerName,
        initialEmail: app.customerEmail,
      ),
    );
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final error = await app.updateCustomerProfile(name: result.name, email: result.email);
    messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(error ?? 'Profile saved')));
  }

  void _openSection(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => title == 'Verify Phone'
            ? const VerifyPhoneScreen()
            : ProfileSectionScreen(section: title),
      ),
    );
  }

  Widget _menuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
  }) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 22),
        minVerticalPadding: 7,
        leading: Icon(icon, color: AppColors.teal, size: 24),
        title: Text(title, style: const TextStyle(fontSize: 16, color: AppColors.text)),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: AppColors.muted, size: 24),
        onTap: onTap,
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.canPop(context)
              ? Navigator.pop(context)
              : Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const HomeFeedScreen())),
        ),
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 18),
          children: [
            const SizedBox(height: 18),
            Center(
              child: EditableAvatar(
                size: 112,
                photo: app.customerPhoto,
                onTap: () async {
                  final picked = await PhotoPicker.pick(context, title: 'Profile picture');
                  if (picked.isNotEmpty) app.setCustomerPhoto(picked.first);
                },
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(app.customerName,
                  style: headingStyle(size: 22, color: AppColors.text)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(app.customerEmail,
                  style: const TextStyle(fontSize: 15, color: AppColors.muted)),
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: () => _editProfile(context, app),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  backgroundColor: AppColors.avatarBg,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Edit Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 28),
            _menuItem(
              context: context,
              icon: Icons.description_outlined,
              title: 'My Bookings',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerBookingsScreen())),
            ),
            _menuItem(
              context: context,
              icon: Icons.forum_outlined,
              title: 'Messages',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen(viewerIsProvider: false))),
            ),
            _menuItem(context: context, icon: Icons.notifications_none, title: 'Notifications', onTap: () => _openSection(context, 'Notifications')),
            _menuItem(context: context, icon: Icons.credit_card_outlined, title: 'Payment Methods', onTap: () => _openSection(context, 'Payment Methods')),
            _menuItem(context: context, icon: Icons.bar_chart_outlined, title: 'Payment History', onTap: () => _openSection(context, 'Payment History')),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 22),
              leading: Icon(
                app.isClientVerified ? Icons.verified_user_outlined : Icons.shield_outlined,
                color: app.isClientVerified ? AppColors.green : AppColors.orange,
              ),
              title: Text(
                app.isClientVerified ? 'Account verified' : 'Account not fully verified',
                style: const TextStyle(fontSize: 15, color: AppColors.text),
              ),
              subtitle: Text(
                'Email ${app.emailVerified ? '✓' : '✗'}  ·  Phone ${app.verifiedPhone != null ? '✓' : '✗'}',
              ),
            ),
            _menuItem(context: context, icon: Icons.phone_outlined, title: 'Verify Phone', onTap: () => _openSection(context, 'Verify Phone')),
            _menuItem(context: context, icon: Icons.settings_outlined, title: 'Settings', onTap: () => _openSection(context, 'Settings')),
            if (!app.isProvider)
              _menuItem(
                context: context,
                icon: Icons.handyman_outlined,
                title: app.myApplication?.status == ApplicationStatus.pending
                    ? 'Provider application'
                    : 'Become a Provider',
                subtitle: switch (app.myApplication?.status) {
                  ApplicationStatus.pending => 'Under review by the admin',
                  ApplicationStatus.rejected => 'Not approved. Tap to apply again',
                  _ => 'Offer your services and earn',
                },
                onTap: () => app.myApplication?.status == ApplicationStatus.pending
                    ? ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(seconds: 3), 
                        content: Text('Your application is being reviewed. You will be notified.')))
                    : openBecomeProvider(context),
              ),
            if (app.isProvider)
              _menuItem(
                context: context,
                icon: Icons.storefront_outlined,
                title: 'Switch to Provider mode',
                onTap: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const ProviderDashboardScreen()),
                  (route) => false,
                ),
              ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => logoutAndGoToLogin(context),
                icon: const Icon(Icons.logout, color: AppColors.red),
                label: const Text('Logout', style: TextStyle(color: AppColors.red, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns its text controllers, so they are disposed only after the dialog's
/// close animation has finished (disposing them right after showDialog
/// returns can throw "used after being disposed").
class _EditProfileDialog extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  const _EditProfileDialog({required this.initialName, required this.initialEmail});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _save() {
    if (!validateAndReveal(_formKey)) return;
    Navigator.pop(context, (name: Validators.oneLine(_name.text), email: _email.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValidatedField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: Validators.personName,
              ),
              const SizedBox(height: 12),
              // Your sign-in email cannot be changed here (it is your account's ID with Supabase Auth).
              TextField(
                controller: _email,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  helperText: 'Your sign-in email cannot be changed here.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      );
}
