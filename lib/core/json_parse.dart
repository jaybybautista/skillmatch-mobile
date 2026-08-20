/// Tolerant readers for JSON values that are *meant* to be numbers.
///
/// A backend can hand back `5` or `"5"` for the same field without meaning
/// anything different by it — PHP's `integer` validation rule, for instance,
/// checks a query parameter without converting it, so an echoed-back filter
/// arrives as a string. A bare `as num?` cast throws on that, and the throw
/// surfaces as a screen that simply refuses to work.
///
/// These accept either form and never throw on a value that isn't a number
/// at all; they return null (or the given fallback) instead.
library;

/// The value as an int, or null when it isn't a number.
int? asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt();
  return null;
}

/// The value as an int, falling back to [fallback] (0 by default).
int asInt(Object? value, [int fallback = 0]) => asIntOrNull(value) ?? fallback;

/// The value as a double, or null when it isn't a number.
double? asDoubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// The value as a double, falling back to [fallback] (0 by default).
double asDouble(Object? value, [double fallback = 0]) =>
    asDoubleOrNull(value) ?? fallback;

/// The value as a bool. Accepts real booleans, 0/1, and the strings PHP and
/// form posts produce ("1", "true", "on", "yes").
bool asBool(Object? value, [bool fallback = false]) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty) return fallback;
    return text == '1' || text == 'true' || text == 'on' || text == 'yes';
  }
  return fallback;
}
