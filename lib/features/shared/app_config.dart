/// TESTING SWITCH. While there is no backend, the admin panel lives inside the
/// phone app so one app can show the whole flow (apply -> approve -> go live).
/// Before release set this to false (or `--dart-define=ADMIN_IN_APP=false`) and
/// use the separate admin website (`lib/main_admin.dart`) instead.
const bool kAdminInApp = bool.fromEnvironment('ADMIN_IN_APP', defaultValue: true);
