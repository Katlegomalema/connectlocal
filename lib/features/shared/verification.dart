import 'dart:math';

/// Free, offline checks that really work (no paid services needed).
/// Each one is a stand-in for a paid lookup that can be added later:
///  * South African ID number  -> Home Affairs / Smile ID
///  * Company registration no. -> CIPC lookup
///  * Phone code              -> an SMS provider

// ---------------------------------------------------------------------------
// South African ID number: 13 digits YYMMDD SSSS C A Z
//   YYMMDD valid birth date, SSSS gender (0000-4999 female, 5000-9999 male),
//   C citizenship (0 citizen, 1 resident), Z Luhn check digit.
// ---------------------------------------------------------------------------
class SaIdInfo {
  final DateTime birthDate;
  final bool male;
  final bool citizen;
  const SaIdInfo(this.birthDate, this.male, this.citizen);

  int get age {
    final now = DateTime.now();
    var a = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      a--;
    }
    return a;
  }
}

/// Returns the details if [id] is a valid SA ID number, otherwise null.
SaIdInfo? parseSaId(String id) {
  final s = id.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^\d{13}$').hasMatch(s)) return null;

  // Luhn check
  var sum = 0;
  for (var i = 0; i < 13; i++) {
    var d = int.parse(s[12 - i]);
    if (i.isOdd) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  if (sum % 10 != 0) return null;

  // Birth date (two-digit year: assume 19xx unless that would be in the future)
  final yy = int.parse(s.substring(0, 2));
  final mm = int.parse(s.substring(2, 4));
  final dd = int.parse(s.substring(4, 6));
  final year = (2000 + yy <= DateTime.now().year) ? 2000 + yy : 1900 + yy;
  final birth = DateTime(year, mm, dd);
  if (birth.month != mm || birth.day != dd) return null; // e.g. 31 February
  if (birth.isAfter(DateTime.now())) return null;

  final gender = int.parse(s.substring(6, 10));
  final citizenDigit = int.parse(s[10]);
  if (citizenDigit > 1) return null;
  return SaIdInfo(birth, gender >= 5000, citizenDigit == 0);
}

/// "9001015009087" -> "900101 •••• ••7"
String maskSaId(String id) {
  final s = id.replaceAll(RegExp(r'\s'), '');
  if (s.length != 13) return id;
  return '${s.substring(0, 6)} •••• •••${s.substring(12)}';
}

// ---------------------------------------------------------------------------
// Company registration number: YYYY/NNNNNN/TT  (e.g. 2019/123456/07)
// TT is the enterprise type: 06 public company, 07 private company,
// 08 non-profit company, 09 personal liability company, 10 external company,
// 21 close corporation, 23 close corporation (converted).
// ---------------------------------------------------------------------------
const _enterpriseTypes = {'06', '07', '08', '09', '10', '21', '23'};

/// Returns null if the number looks valid, otherwise a message for the user.
String? checkRegistrationNumber(String value) {
  final s = value.trim();
  final m = RegExp(r'^(\d{4})/(\d{6})/(\d{2})$').firstMatch(s);
  if (m == null) return 'Use the format 2019/123456/07';
  final year = int.parse(m.group(1)!);
  if (year < 1900 || year > DateTime.now().year) {
    return 'The registration year ${m.group(1)} is not valid';
  }
  if (!_enterpriseTypes.contains(m.group(3))) {
    return 'The last two digits (${m.group(3)}) are not a valid company type';
  }
  return null;
}

// ---------------------------------------------------------------------------
// One-time codes (phone verification). The code is created and checked here,
// so a wrong code is really rejected. With no SMS provider, the "SMS" is shown
// inside the app (see DemoSms). A backend replaces [OtpService].
// ---------------------------------------------------------------------------
enum OtpCheck { ok, wrong, expired, tooManyTries, noCode }

class OtpService {
  OtpService._();
  static final OtpService instance = OtpService._();

  static const _validFor = Duration(minutes: 5);
  static const _maxTries = 5;

  String? _phone;
  String? _code;
  DateTime? _expires;
  int _tries = 0;

  /// Creates a new 6-digit code for [phone] and returns it (to be "sent").
  String send(String phone) {
    final r = Random.secure();
    _code = (100000 + r.nextInt(900000)).toString();
    _phone = phone;
    _expires = DateTime.now().add(_validFor);
    _tries = 0;
    return _code!;
  }

  OtpCheck check(String phone, String entered) {
    if (_code == null || _phone != phone) return OtpCheck.noCode;
    if (_tries >= _maxTries) return OtpCheck.tooManyTries;
    if (DateTime.now().isAfter(_expires!)) return OtpCheck.expired;
    if (entered.trim() != _code) {
      _tries++;
      return _tries >= _maxTries ? OtpCheck.tooManyTries : OtpCheck.wrong;
    }
    _code = null; // single use
    return OtpCheck.ok;
  }

  int get triesLeft => _maxTries - _tries;
}


// ---------------------------------------------------------------------------
// Bank details for payouts (free, offline checks).
// ---------------------------------------------------------------------------
/// South African banks with their universal branch codes.
const Map<String, String> kBanks = {
  'ABSA': '632005',
  'African Bank': '430000',
  'Capitec': '470010',
  'Discovery Bank': '679000',
  'FNB': '250655',
  'Nedbank': '198765',
  'Standard Bank': '051001',
  'TymeBank': '678910',
  'Other bank': '',
};

const List<String> kAccountTypes = ['Cheque / Current', 'Savings', 'Transmission'];

/// Returns null if OK, otherwise a message. SA account numbers have 9-11 digits.
String? checkBankAccountNumber(String value) {
  final s = value.replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^\d+$').hasMatch(s)) return 'Use digits only';
  if (s.length < 9 || s.length > 11) return 'Account numbers have 9 to 11 digits';
  return null;
}

String? checkBranchCode(String value) =>
    RegExp(r'^\d{6}$').hasMatch(value.trim()) ? null : 'Branch codes have 6 digits';

List<String> _nameTokens(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z\s]'), ' ')
    .split(RegExp(r'\s+'))
    .where((t) => t.isNotEmpty && !const {'pty', 'ltd', 'cc', 'mr', 'mrs', 'ms', 'miss', 'dr'}.contains(t))
    .toList();

/// The account must belong to the provider: the holder name has to match the
/// person's name (surname + first name or initial, any order) or the business
/// name. This stops earnings being redirected to somebody else's account.
bool bankNameMatches(String holder, {required String personName, String businessName = ''}) {
  final h = _nameTokens(holder);
  if (h.isEmpty) return false;
  final person = _nameTokens(personName);
  if (person.length >= 2) {
    final surname = person.last;
    final first = person.first;
    final hasSurname = h.contains(surname);
    final hasFirst = h.any((t) => t == first || (t.length == 1 && t == first[0]));
    if (hasSurname && hasFirst) return true;
  }
  final biz = _nameTokens(businessName);
  if (biz.isNotEmpty && biz.every(h.contains)) return true;
  return false;
}
