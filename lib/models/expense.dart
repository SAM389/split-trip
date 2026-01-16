import 'package:cloud_firestore/cloud_firestore.dart';

/// Defines how an expense should be split among participants.
///
/// - [equal]: Split the expense equally among all participants
/// - [percentage]: Split based on custom percentage for each participant
/// - [exact]: Split with exact amounts specified for each participant
enum SplitType { equal, percentage, exact }

/// Represents an individual participant's share of an expense.
///
/// Stores both the normalized amount in the trip's base currency and optionally
/// the original amount if it was in a different currency.
class ExpenseShare {
  /// ID of the participant who owes this share
  final String participantId;
  
  /// Amount owed in the trip's base currency
  final double amountInBase;
  
  /// Original amount if expense was in a different currency
  final double? originalAmount;
  
  /// Original currency code if different from base (e.g., "USD")
  final String? originalCurrency;

  const ExpenseShare({
    required this.participantId,
    required this.amountInBase,
    this.originalAmount,
    this.originalCurrency,
  });

  Map<String, dynamic> toMap() {
    return {
      'participantId': participantId,
      'amountInBase': amountInBase,
      'originalAmount': originalAmount,
      'originalCurrency': originalCurrency,
    };
  }

  /// Creates an expense share from a Firestore document map.
  factory ExpenseShare.fromMap(Map<String, dynamic> map) {
    return ExpenseShare(
      participantId: map['participantId'] as String,
      amountInBase: (map['amountInBase'] as num).toDouble(),
      originalAmount: map['originalAmount'] != null
          ? (map['originalAmount'] as num).toDouble()
          : null,
      originalCurrency: map['originalCurrency'] as String?,
    );
  }
}

/// Represents a single expense within a trip.
///
/// An expense records a payment made by one participant ([payerId]) that is
/// split among multiple participants according to the [splitType] strategy.
///
/// The expense stores both the original amount in [expenseCurrency] and a
/// snapshot of the exchange [rateToBase] at creation time. This ensures
/// consistent settlement calculations even if exchange rates change later.
///
/// Each expense maintains a [shares] list that breaks down how much each
/// participant owes, normalized to the trip's base currency.
class Expense {
  /// Unique identifier for the expense
  final String id;
  
  /// ID of the trip this expense belongs to
  final String tripId;
  
  /// ID of the participant who paid for this expense
  final String payerId;
  
  /// Description of the expense (e.g., "Dinner at restaurant")
  final String description;
  
  /// Original expense amount in [expenseCurrency]
  final double amount;
  
  /// Currency code of the original expense (e.g., "USD", "EUR")
  final String expenseCurrency;
  
  /// Exchange rate to base currency at time of creation (snapshot)
  final double rateToBase;
  
  /// Date when the expense occurred
  final DateTime date;
  
  /// Converts the expense to a Firestore-compatible map.
  ///
  /// Excludes the [id] field as it's stored as the document ID in Firestore.
  /// Strategy used to split this expense among participants
  final SplitType splitType;
  
  /// Split distribution metadata (shares/percentages/exact amounts per participant)
  final Map<String, double> splitMeta;
  
  /// Computed expense shares for each participant in base currency
  final List<ExpenseShare> shares;
  
  /// Category of the expense (e.g., "Food", "Transport", "Stay")
  final String category;
  
  /// URL to uploaded receipt image in Firebase Storage
  final String? receiptUrl;
  
  /// Snapshot of payer's display name at creation time
  final String? payerDisplayName;
  
  /// Snapshot map of participant names for shares at creation time
  final Map<String, String>?
  shareParticipantNames; // snapshot of participant names for shares

  const Expense({
    required this.id,
    required this.tripId,
    required this.payerId,
    required this.description,
    required this.amount,
    required this.expenseCurrency,
    required this.rateToBase,
    required this.date,
    required this.splitType,
    required this.splitMeta,
    required this.shares,
    required this.category,
    this.receiptUrl,
    this.payerDisplayName,
    this.shareParticipantNames,
  });

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'payerId': payerId,
      'description': description,
      'amount': amount,
      'expenseCurrency': expenseCurrency,
      'rateToBase': rateToBase,
      'date': Timestamp.fromDate(date),
      'splitType': splitType.toString().split('.').last,
      'splitMeta': splitMeta,
      'shares': shares.map((s) => s.toMap()).toList(),
      'category': category,
      'receiptUrl': receiptUrl,
      'payerDisplayName': payerDisplayName,
      'shareParticipantNames': shareParticipantNames,
  /// Creates an expense instance from a Firestore document.
  ///
  /// [id] is the Firestore document ID.
  /// [map] contains the document data.
    };
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      tripId: map['tripId'] as String,
      payerId: map['payerId'] as String,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      expenseCurrency: map['expenseCurrency'] as String,
      rateToBase: (map['rateToBase'] as num).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      splitType: SplitType.values.firstWhere(
        (e) => e.name == map['splitType'],
        orElse: () => SplitType.equal,
      ),
      splitMeta: Map<String, double>.from(
        (map['splitMeta'] as Map).map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ),
      ),
      shares: (map['shares'] as List)
          .map((s) => ExpenseShare.fromMap(s as Map<String, dynamic>))
          .toList(),
      category: map['category'] as String,
      receiptUrl: map['receiptUrl'] as String?,
      payerDisplayName: map['payerDisplayName'] as String?,
      shareParticipantNames: map['shareParticipantNames'] != null
          ? Map<String, String>.from(map['shareParticipantNames'] as Map)
          : null,
    );
  }

  /// Returns the total expense amount converted to the trip's base currency.
  ///
  /// Uses the snapshot [rateToBase] exchange rate from expense creation time.
  double get totalInBase => amount * rateToBase;

  /// Creates a copy of this expense with the given fields replaced with new values.
  ///
  /// Used for immutable updates in state management.
  Expense copyWith({
    String? id,
    String? tripId,
    String? payerId,
    String? description,
    double? amount,
    String? expenseCurrency,
    double? rateToBase,
    DateTime? date,
    SplitType? splitType,
    Map<String, double>? splitMeta,
    List<ExpenseShare>? shares,
    String? category,
    String? receiptUrl,
    String? payerDisplayName,
    Map<String, String>? shareParticipantNames,
  }) {
    return Expense(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      payerId: payerId ?? this.payerId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      expenseCurrency: expenseCurrency ?? this.expenseCurrency,
      rateToBase: rateToBase ?? this.rateToBase,
      date: date ?? this.date,
      splitType: splitType ?? this.splitType,
      splitMeta: splitMeta ?? this.splitMeta,
      shares: shares ?? this.shares,
      category: category ?? this.category,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      payerDisplayName: payerDisplayName ?? this.payerDisplayName,
      shareParticipantNames:
          shareParticipantNames ?? this.shareParticipantNames,
    );
  }
}
