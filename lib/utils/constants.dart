import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

/// Generate a UPI deep link for payment
String buildUpiDeepLink({
  required String vpa,
  required String name,
  required double amount,
  String note = 'Trip settlement',
}) {
  final amountStr = amount.toStringAsFixed(2);
  final encodedNote = Uri.encodeComponent(note);
  final encodedName = Uri.encodeComponent(name);

  return 'upi://pay?pa=$vpa&pn=$encodedName&am=$amountStr&cu=INR&tn=$encodedNote';
}

/// Format currency with locale-aware grouping and fixed 2 decimals
/// - INR uses Indian numbering system (en_IN)
/// - Others use Western grouping (en_US)
/// - Middle Eastern currencies display code (AED, SAR, QAR, OMR)
String formatCurrency(double amount, String currencyCode) {
  // Locale selection
  final locale = currencyCode == 'INR' ? 'en_IN' : 'en_US';

  // Symbol mapping (codes where required)
  const symbols = {
    'USD': '\$',
    'CAD': 'CA\$',
    'AUD': 'A\$',
    'SGD': 'S\$',
    'HKD': 'HK\$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
    'JPY': 'JP¥',
    'CNY': 'CN¥',
    'AED': 'AED',
    'SAR': 'SAR',
    'QAR': 'QAR',
    'THB': '฿',
    'CHF': 'CHF',
    'OMR': 'OMR',
    'NOK': 'NOK',
    'SEK': 'SEK',
    'DKK': 'DKK',
    'KRW': '₩',
    'IDR': 'Rp',
    'MYR': 'RM',
    'VND': '₫',
  };

  final symbol = symbols[currencyCode] ?? currencyCode;

  // Use decimal pattern for grouping; force 2 fraction digits
  final formatter = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = 2
    ..maximumFractionDigits = 2;

  return '$symbol ${formatter.format(amount)}';
}

/// Common currency codes
const List<String> commonCurrencies = [
  'USD',
  'CAD',
  'EUR',
  'INR',
  'GBP',
  'AUD',
  'JPY',
  'CNY',
  'SGD',
  'HKD',
  'AED',
  'CHF',
  'THB',
  'OMR',
  'SAR',
  'QAR',
  'NOK',
  'SEK',
  'DKK',
  'KRW',
  'IDR',
  'MYR',
  'VND',
];

/// Expense categories
const List<String> expenseCategories = [
  'Food',
  'Stay',
  'Transport',
  'Entertainment',
  'Shopping',
  'Other',
];

/// TextInputFormatter for Trip Name (letters, numbers, spaces, basic punctuation only)
class TripNameFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Block emojis first
    final emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}]|'
      r'[\u{1F300}-\u{1F5FF}]|'
      r'[\u{1F680}-\u{1F6FF}]|'
      r'[\u{2600}-\u{26FF}]|'
      r'[\u{2700}-\u{27BF}]|'
      r'[\u{1F900}-\u{1F9FF}]|'
      r'[\u{1F1E0}-\u{1F1FF}]',
      unicode: true,
    );

    final text = newValue.text;

    // Block newlines
    if (text.contains('\n')) {
      return oldValue;
    }

    // Block emoji
    if (emojiRegex.hasMatch(text)) {
      return oldValue;
    }

    // Allow only: letters, numbers, spaces, and basic punctuation (- _ & () ,)
    if (!RegExp(r'^[a-zA-Z0-9 _\-&(),]*$').hasMatch(text)) {
      return oldValue;
    }

    return newValue;
  }
}

/// TextInputFormatter to block emojis and newlines (for description)
class NoEmojiFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Block emojis
    final emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}]|'
      r'[\u{1F300}-\u{1F5FF}]|'
      r'[\u{1F680}-\u{1F6FF}]|'
      r'[\u{2600}-\u{26FF}]|'
      r'[\u{2700}-\u{27BF}]|'
      r'[\u{1F900}-\u{1F9FF}]|'
      r'[\u{1F1E0}-\u{1F1FF}]',
      unicode: true,
    );

    final text = newValue.text;

    // Block newlines
    if (text.contains('\n')) {
      return oldValue;
    }

    // Block emoji
    if (emojiRegex.hasMatch(text)) {
      return oldValue;
    }

    return newValue;
  }
}

/// Validator for trip name: 1-40 chars, no emojis, only allowed characters
String? validateTripName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Trip name is required';
  }

  final trimmed = value.trim();

  if (trimmed.length > 40) {
    return 'Maximum 40 characters allowed';
  }

  // Check for emoji
  final emojiRegex = RegExp(
    r'[\u{1F600}-\u{1F64F}]|'
    r'[\u{1F300}-\u{1F5FF}]|'
    r'[\u{1F680}-\u{1F6FF}]|'
    r'[\u{2600}-\u{26FF}]|'
    r'[\u{2700}-\u{27BF}]|'
    r'[\u{1F900}-\u{1F9FF}]|'
    r'[\u{1F1E0}-\u{1F1FF}]',
    unicode: true,
  );

  if (emojiRegex.hasMatch(trimmed)) {
    return 'Emojis are not allowed';
  }

  // Check for allowed characters only
  if (!RegExp(r'^[a-zA-Z0-9 _\-&(),]+$').hasMatch(trimmed)) {
    return 'Only letters, numbers, spaces, and -_&(), allowed';
  }

  return null;
}

/// Validator for trip description: max 120 chars, no emojis
String? validateTripDescription(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null; // Description is optional
  }

  final trimmed = value.trim();

  if (trimmed.length > 120) {
    return 'Maximum 120 characters allowed';
  }

  // Check for emoji
  final emojiRegex = RegExp(
    r'[\u{1F600}-\u{1F64F}]|'
    r'[\u{1F300}-\u{1F5FF}]|'
    r'[\u{1F680}-\u{1F6FF}]|'
    r'[\u{2600}-\u{26FF}]|'
    r'[\u{2700}-\u{27BF}]|'
    r'[\u{1F900}-\u{1F9FF}]|'
    r'[\u{1F1E0}-\u{1F1FF}]',
    unicode: true,
  );

  if (emojiRegex.hasMatch(trimmed)) {
    return 'Emojis are not allowed';
  }

  return null;
}

/// TextInputFormatter for Expense Description (letters, numbers, spaces, and common punctuation)
class DescriptionFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Block emojis first
    final emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}]|'
      r'[\u{1F300}-\u{1F5FF}]|'
      r'[\u{1F680}-\u{1F6FF}]|'
      r'[\u{2600}-\u{26FF}]|'
      r'[\u{2700}-\u{27BF}]|'
      r'[\u{1F900}-\u{1F9FF}]|'
      r'[\u{1F1E0}-\u{1F1FF}]',
      unicode: true,
    );

    final text = newValue.text;

    // Block newlines
    if (text.contains('\n')) {
      return oldValue;
    }

    // Block emoji
    if (emojiRegex.hasMatch(text)) {
      return oldValue;
    }

    // Allow only: letters, numbers, spaces, and punctuation (. , - _ & () / :)
    if (!RegExp(r'^[a-zA-Z0-9 .,\-_&()/:]*$').hasMatch(text)) {
      return oldValue;
    }

    return newValue;
  }
}

/// Validator for expense description: 1-110 chars, no emojis
String? validateExpenseDescription(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter a description';
  }

  final trimmed = value.trim();

  if (trimmed.length > 110) {
    return 'Description must be under 110 characters';
  }

  // Check for emoji
  final emojiRegex = RegExp(
    r'[\u{1F600}-\u{1F64F}]|'
    r'[\u{1F300}-\u{1F5FF}]|'
    r'[\u{1F680}-\u{1F6FF}]|'
    r'[\u{2600}-\u{26FF}]|'
    r'[\u{2700}-\u{27BF}]|'
    r'[\u{1F900}-\u{1F9FF}]|'
    r'[\u{1F1E0}-\u{1F1FF}]',
    unicode: true,
  );

  if (emojiRegex.hasMatch(trimmed)) {
    return 'Emojis are not supported in descriptions';
  }

  // Check for allowed characters only
  if (!RegExp(r'^[a-zA-Z0-9 .,\-_&()/:]+$').hasMatch(trimmed)) {
    return 'Only letters, numbers, spaces, and .,_-&()/: allowed';
  }

  return null;
}

/// Get participant display name, showing "(Inactive)" if participant was deleted
///
/// When a participant is deleted, we use the snapshot name stored in the expense
/// to show "[Name] (Inactive)" so users know who the deleted participant was.
String getParticipantDisplayName(
  String participantId,
  Map<String, String> currentParticipantMap,
  Map<String, String>? snapshotParticipantNames,
) {
  // If participant still exists, show their current name
  if (currentParticipantMap.containsKey(participantId)) {
    return currentParticipantMap[participantId] ?? 'Unknown';
  }

  // Participant is deleted; use snapshot name if available
  if (snapshotParticipantNames != null &&
      snapshotParticipantNames.containsKey(participantId)) {
    final snapshotName = snapshotParticipantNames[participantId] ?? 'Unknown';
    return '$snapshotName (Inactive)';
  }

  // Fallback for very old expenses without snapshots
  return 'Unknown (Inactive)';
}
