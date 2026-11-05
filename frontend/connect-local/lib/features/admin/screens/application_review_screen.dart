import 'package:flutter/material.dart';

import '../../community/models/models.dart';
import '../../community/state/app_state.dart';
import '../../community/theme/app_theme.dart';
import '../../community/widgets/ui_kit.dart';
import '../../shared/brand.dart';
import '../../shared/photo.dart';
import '../../shared/photo_viewer.dart';
import '../../shared/verification.dart';

/// The admin reviews EVERYTHING about an application here before deciding.
/// Approve stays locked until the admin has opened and ticked each check.
class ApplicationReviewScreen extends StatefulWidget {
  final String applicationId;
  const ApplicationReviewScreen({super.key, required this.applicationId});

  @override
  State<ApplicationReviewScreen> createState() => _ApplicationReviewScreenState();
}

class _ApplicationReviewScreenState extends State<ApplicationReviewScreen> {
  bool _regChecked = false;
  bool _idChecked = false;
  bool _nameChecked = false;

  ProviderApplicationRecord? _find(AppState app) {
    for (final a in app.providerApplications) {
      if (a.id == widget.applicationId) return a;
    }
    return null;
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(fontSize: 14, color: AppColors.muted)),
            ),
            Expanded(
              child: Text(value.isEmpty ? '-' : value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
            ),
          ],
        ),
      );

  Widget _check(bool ok, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 18, color: ok ? AppColors.green : AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 14, height: 1.35)),
            ),
          ],
        ),
      );

  Widget _doc(String title, PhotoRef? photo) => Expanded(
        child: GestureDetector(
          onTap: photo == null ? null : () => showPhotoViewer(context, [photo]),
          child: Column(
            children: [
              Container(
                height: 110,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: photo == null
                    ? const Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: AppColors.muted, size: 30))
                    : PhotoImage(photo, width: double.infinity, height: 110),
              ),
              const SizedBox(height: 6),
              Text(photo == null ? '$title: missing' : '$title (tap to enlarge)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: photo == null ? AppColors.accent : AppColors.muted)),
            ],
          ),
        ),
      );

  Future<void> _reject(AppState app, ProviderApplicationRecord a) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject application'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'Tell the applicant why (e.g. ID photo is unclear)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(duration: const Duration(seconds: 3), content: Text('Please give a reason')));
      return;
    }
    await _decide(app, a, ApplicationStatus.rejected, reason: reason);
  }

  bool _deciding = false;

  /// Sends the decision (server when connected). Stays on the page with the error if it fails.
  Future<void> _decide(AppState app, ProviderApplicationRecord a, ApplicationStatus status, {String? reason}) async {
    if (_deciding) return;
    setState(() => _deciding = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final error = await app.decideApplication(a, status, reason: reason);
    if (!mounted) return;
    setState(() => _deciding = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 4), content: Text(error)));
      return;
    }
    navigator.pop();
    messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(status == ApplicationStatus.approved
            ? '${a.businessName} approved and verified'
            : '${a.businessName} rejected')));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final a = _find(app);
    if (a == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const EmptyState(icon: Icons.search_off_rounded, title: 'Application not found'));
    }
    final regProblem = checkRegistrationNumber(a.registrationNumber);
    final id = a.idNumber.isEmpty ? null : parseSaId(a.idNumber);
    final duplicates = app.providerApplications
        .where((o) =>
            o.id != a.id &&
            o.registrationNumber.isNotEmpty &&
            o.registrationNumber == a.registrationNumber &&
            o.status != ApplicationStatus.rejected)
        .length;

    // With the server the ID number is not stored (privacy): the admin checks it, and the age, on the ID
    // document instead (the "ID" tick below). On the device-only demo it is still checked here.
    final idNumberOk = a.idNumber.isEmpty || (id != null && id.age >= 18);
    final autoOk = regProblem == null && idNumberOk && duplicates == 0;
    final docsOk = a.registrationDoc != null && a.idDoc != null;
    final allTicked = _regChecked && _idChecked && _nameChecked;
    final pending = a.status == ApplicationStatus.pending;
    final canApprove = pending && autoOk && docsOk && allTicked;

    return Scaffold(
      appBar: AppBar(title: const Text('Review application')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // ---- applicant ----
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(a.businessName,
                                  style: headingStyle(size: 18, color: AppColors.text)),
                            ),
                            StatusChip(
                              a.status.label,
                              color: a.status == ApplicationStatus.approved
                                  ? AppColors.green
                                  : a.status == ApplicationStatus.rejected
                                      ? AppColors.accent
                                      : AppColors.orange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _row('Email', a.email),
                        _row('Category', a.services),
                        _row('Location', a.location),
                        _row('Applied', a.appliedLabel),
                        _row('Description', a.description),
                        if (a.rejectionReason != null && a.rejectionReason!.isNotEmpty)
                          _row('Reason', a.rejectionReason!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- automatic checks ----
                  const SectionTitle('Automatic checks'),
                  const SizedBox(height: 10),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _check(regProblem == null,
                            'Registration number ${a.registrationNumber.isEmpty ? '(none)' : a.registrationNumber}: ${regProblem ?? 'format is valid'}'),
                        _check(duplicates == 0,
                            duplicates == 0
                                ? 'No other application uses this registration number'
                                : 'Another application uses this registration number'),
                        _check(
                            idNumberOk,
                            a.idNumber.isEmpty
                                ? 'ID number is not stored (privacy): check the number and that the applicant is 18+ on the ID document below'
                                : id == null
                                    ? 'ID ${maskSaId(a.idNumber)} is not a valid South African ID'
                                    : 'ID ${maskSaId(a.idNumber)} is valid (age ${id.age}, ${id.male ? 'male' : 'female'}, ${id.citizen ? 'citizen' : 'permanent resident'})'),
                        if (id != null) _check(id.age >= 18, 'Applicant is 18 or older'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- documents ----
                  const SectionTitle('Documents'),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _doc('Registration certificate', a.registrationDoc),
                      const SizedBox(width: 12),
                      _doc('ID document', a.idDoc),
                    ],
                  ),
                  if (a.photos.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const SectionTitle('Portfolio'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: a.photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => showPhotoViewer(context, a.photos, initialIndex: i),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: PhotoImage(a.photos[i], width: 84, height: 84),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ---- admin's own checks ----
                  if (pending) ...[
                    const SectionTitle('Your review'),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _regChecked,
                      onChanged: a.registrationDoc == null
                          ? null
                          : (v) => setState(() => _regChecked = v ?? false),
                      title: const Text('The registration certificate looks genuine',
                          style: TextStyle(fontSize: 14)),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _idChecked,
                      onChanged: a.idDoc == null
                          ? null
                          : (v) => setState(() => _idChecked = v ?? false),
                      title: const Text('The ID photo matches the ID number',
                          style: TextStyle(fontSize: 14)),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _nameChecked,
                      onChanged: (v) => setState(() => _nameChecked = v ?? false),
                      title: const Text('The business name matches the certificate',
                          style: TextStyle(fontSize: 14)),
                    ),
                    if (!docsOk || !autoOk)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'This application can’t be approved: a document is missing or a check failed. You can reject it with a reason.',
                          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.accent),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (pending)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _reject(app, a),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(color: AppColors.accent),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        'Verify & approve',
                        icon: Icons.verified_rounded,
                        onPressed: canApprove && !_deciding
                            ? () => _decide(app, a, ApplicationStatus.approved)
                            : null,
                      ),
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
