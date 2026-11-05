/// "R450", "R67.50" (cents only when there are any).
String money(num amount) {
  final cents = (amount * 100).round();
  return cents % 100 == 0 ? 'R${cents ~/ 100}' : 'R${(cents / 100).toStringAsFixed(2)}';
}

String formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

/// "350 m away", "3.2 km away", "14 km away"
String distanceLabel(double km) {
  if (km < 1) {
    final metres = ((km * 1000) / 10).round() * 10; // nearest 10 m
    return '${metres < 10 ? 10 : metres} m away';
  }
  if (km < 10) return '${km.toStringAsFixed(1)} km away';
  return '${km.round()} km away';
}

String whenLabel(DateTime value) {
  final today = DateTime.now();
  if (value.year == today.year && value.month == today.month && value.day == today.day) {
    return 'Today, ${formatTime(value)}';
  }
  return '${value.day}/${value.month}/${value.year} · ${formatTime(value)}';
}

String formatDate(DateTime value) {
  const months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
