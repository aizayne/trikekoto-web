/// Philippine mobile numbers, normalised to the E.164 form Firebase needs.
///
/// People write the same number three ways — `09171234567`, `9171234567`,
/// `+639171234567` — and all three are correct. Rejecting two of them would be
/// a barrier over formatting rather than identity, and the error Firebase
/// returns for a badly-formed number reads as though the number itself is
/// wrong.
///
/// Returns null when the input cannot be a PH mobile number, which is what the
/// form validator reports.
String? toE164Ph(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');

  // Already E.164: +63 then a 10-digit subscriber number.
  if (digits.startsWith('+63') && digits.length == 13) return digits;

  // The way it is printed on a jeepney: 0917 123 4567.
  if (digits.startsWith('09') && digits.length == 11) {
    return '+63${digits.substring(1)}';
  }

  // Without the trunk zero, as a form sometimes stores it.
  if (digits.startsWith('9') && digits.length == 10) return '+63$digits';

  return null;
}
