import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import 'app_colors.dart';
import 'common.dart';

/// Provider: the days and hours they work, and how long one booking slot is.
/// Customers can only book free slots inside these hours. Reached from the Business Profile screen.
class WorkingHoursScreen extends StatefulWidget {
  const WorkingHoursScreen({super.key});

  @override
  State<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  late int _slotMinutes;

  /// Index 0 = Monday ... 6 = Sunday. Null = closed that day.
  late final List<DayHours?> _days;

  /// Hours shown when a closed day is switched on.
  static const _defaultDay = DayHours(480, 1020); // 8:00 - 17:00

  @override
  void initState() {
    super.initState();
    final hours = AppScope.read(context).activeProvider.workingHours;
    _slotMinutes = hours.slotMinutes;
    _days = [for (var d = DateTime.monday; d <= DateTime.sunday; d++) hours.days[d]];
  }

  Future<int?> _pickTime(int minutesOfDay) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutesOfDay ~/ 60, minute: minutesOfDay % 60),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.teal),
        ),
        child: child!,
      ),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  Future<void> _editTime(int index, {required bool opening}) async {
    final day = _days[index]!;
    final picked = await _pickTime(opening ? day.open : day.close);
    if (picked == null || !mounted) return;
    final open = opening ? picked : day.open;
    final close = opening ? day.close : picked;
    if (close <= open) {
      _message('Closing time must be after opening time.');
      return;
    }
    setState(() => _days[index] = DayHours(open, close));
  }

  void _message(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(duration: const Duration(seconds: 3), content: Text(text)));

  void _save() {
    if (_days.every((d) => d == null)) {
      _message('Switch on at least one working day.');
      return;
    }
    for (var i = 0; i < 7; i++) {
      final d = _days[i];
      if (d != null && d.close - d.open < _slotMinutes) {
        _message('${kWeekdayNames[i]} is shorter than one ${slotLengthLabel(_slotMinutes).toLowerCase()} slot. '
            'Choose shorter slots or longer hours.');
        return;
      }
    }
    AppScope.read(context).setWorkingHours(WorkingHours(
      days: {
        for (var i = 0; i < 7; i++)
          if (_days[i] != null) i + 1: _days[i]!,
      },
      slotMinutes: _slotMinutes,
    ));
    Navigator.maybePop(context);
    _message('Working hours saved');
  }

  Widget _timeButton(String text, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(text, style: const TextStyle(fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final preview = WorkingHours(
      days: {
        for (var i = 0; i < 7; i++)
          if (_days[i] != null) i + 1: _days[i]!,
      },
      slotMinutes: _slotMinutes,
    );
    // Example: the slots of the first open day, so the provider sees what customers will see.
    final firstOpen = _days.indexWhere((d) => d != null);
    final now = DateTime.now();
    final exampleDay = firstOpen < 0 ? null : now.add(Duration(days: (firstOpen + 1 - now.weekday) % 7));
    final exampleSlots = exampleDay == null ? const <DateTime>[] : preview.slotStarts(exampleDay);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeader('Working hours & time slots'),
              const SizedBox(height: 14),
              const Text(
                'Customers book a time slot inside these hours. Once a slot is booked, no one else can book '
                'you at that time. You always get a 30-minute break after each booking, in case a job runs '
                'a little long.',
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textGrey),
              ),
              const SizedBox(height: 18),
              const Text('How long is one slot?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in kSlotLengths)
                    ChoiceChip(
                      label: Text(slotLengthLabel(m)),
                      selected: _slotMinutes == m,
                      selectedColor: AppColors.teal.withValues(alpha: 0.15),
                      onSelected: (_) => setState(() => _slotMinutes = m),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'E.g. a barber uses 30 minutes, a plumber 2 hours, a painter a full day. '
                'Per-hour services can take several slots in a row.',
                style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textGrey),
              ),
              const SizedBox(height: 20),
              const Text('Working days',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              for (var i = 0; i < 7; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Switch(
                        value: _days[i] != null,
                        activeTrackColor: AppColors.teal,
                        onChanged: (on) => setState(() => _days[i] = on ? _defaultDay : null),
                      ),
                      SizedBox(
                        width: 92,
                        child: Text(kWeekdayNames[i],
                            style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
                      ),
                      if (_days[i] == null)
                        const Text('Closed', style: TextStyle(fontSize: 13, color: AppColors.textGrey))
                      else
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              _timeButton(clockLabel(_days[i]!.open), () => _editTime(i, opening: true)),
                              const Text('to', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                              _timeButton(clockLabel(_days[i]!.close), () => _editTime(i, opening: false)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (exampleDay != null) ...[
                const SizedBox(height: 20),
                Text('Customers will see these slots on ${kWeekdayNames[firstOpen]}s:',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in exampleSlots)
                      Chip(
                        label: Text(clockLabel(s.hour * 60 + s.minute), style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (exampleSlots.isEmpty)
                      const Text('No slots fit in these hours.',
                          style: TextStyle(fontSize: 12, color: AppColors.cancelRed)),
                  ],
                ),
              ],
              const SizedBox(height: 28),
              TealButton('Save working hours', height: 46, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
