import 'package:flutter/material.dart';

import '../../shared/verification.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// The provider's bank account: where their earnings are paid.
/// Checks: account number length, branch code, and the account holder name
/// must match the provider's own name or business name.
class PayoutDetailsScreen extends StatefulWidget {
  const PayoutDetailsScreen({super.key});

  @override
  State<PayoutDetailsScreen> createState() => _PayoutDetailsScreenState();
}

class _PayoutDetailsScreenState extends State<PayoutDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _holder;
  late final TextEditingController _number;
  late final TextEditingController _branch;
  String? _bank;
  String? _type;

  @override
  void initState() {
    super.initState();
    final existing = AppScope.read(context).activePayoutAccount;
    _holder = TextEditingController(text: existing?.holderName ?? '');
    _number = TextEditingController(text: existing?.accountNumber ?? '');
    _branch = TextEditingController(text: existing?.branchCode ?? '');
    _bank = existing?.bank;
    _type = existing?.accountType;
  }

  @override
  void dispose() {
    _holder.dispose();
    _number.dispose();
    _branch.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.muted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text.rich(TextSpan(
          text: text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
          children: const [TextSpan(text: ' *', style: TextStyle(color: AppColors.red))],
        )),
      );

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    app.savePayoutAccount(PayoutAccount(
      bank: _bank!,
      accountType: _type!,
      holderName: _holder.text.trim(),
      accountNumber: _number.text.replaceAll(RegExp(r'[\s-]'), ''),
      branchCode: _branch.text.trim(),
    ));
    Navigator.pop(context, true);
    messenger.showSnackBar(const SnackBar(duration: const Duration(seconds: 3), content: Text('Payout details saved')));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Payout details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.account_balance_outlined, color: AppColors.teal, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This is where ConnectLocal pays your earnings after each job is '
                          'completed with the customer’s PIN. Use a bank account in your own '
                          'name or your business name.',
                          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.text),
                        ),
                      ),
                    ],
                  ),
                ),
                _label('Bank'),
                DropdownButtonFormField<String>(
                  initialValue: _bank,
                  isDense: true,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 22),
                  style: const TextStyle(fontSize: 14, color: AppColors.text),
                  decoration: _decoration('Select your bank'),
                  items: [
                    for (final b in kBanks.keys) DropdownMenuItem(value: b, child: Text(b)),
                  ],
                  onChanged: (v) => setState(() {
                    _bank = v;
                    // Banks have a universal branch code: fill it in.
                    final code = kBanks[v] ?? '';
                    if (code.isNotEmpty) _branch.text = code;
                  }),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                _label('Account type'),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  isDense: true,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 22),
                  style: const TextStyle(fontSize: 14, color: AppColors.text),
                  decoration: _decoration('Select account type'),
                  items: [
                    for (final t in kAccountTypes) DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setState(() => _type = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                _label('Account holder name'),
                TextFormField(
                  controller: _holder,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 14),
                  decoration: _decoration('As it appears on your bank account'),
                  validator: (v) {
                    if (_required(v) != null) return 'Required';
                    if (!bankNameMatches(v!,
                        personName: app.customerName,
                        businessName: app.activeProvider.name)) {
                      return 'Must match your name (${app.customerName}) or business name '
                          '(${app.activeProvider.name})';
                    }
                    return null;
                  },
                ),
                _label('Account number'),
                TextFormField(
                  controller: _number,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 14),
                  decoration: _decoration('e.g. 62012345678'),
                  validator: (v) => _required(v) ?? checkBankAccountNumber(v!),
                ),
                _label('Branch code'),
                TextFormField(
                  controller: _branch,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 14),
                  decoration: _decoration('6 digits (filled in for most banks)'),
                  validator: (v) => _required(v) ?? checkBranchCode(v!),
                ),
                const SizedBox(height: 28),
                PrimaryButton('Save payout details', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
