import 'package:cloud_firestore/cloud_firestore.dart';

enum SplitType { equal, percentage, exact }

class ExpenseShare {
  final String participantId;
  final double amountInBase; // converted using rateToBase snapshot
  final double? originalAmount;
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

class Expense {
  final String id;
  final String tripId;
  final String payerId;
  final String description;
  final double amount; // original amount in expenseCurrency
  final String expenseCurrency;
  final double rateToBase; // snapshot at creation
  final DateTime date;
  final SplitType splitType;
  final Map<String, double> splitMeta; // shares/percent/exact per user
  final List<ExpenseShare> shares; // computed, in base currency
  final String category; // Food/Stay/Transport/etc.
  final String? receiptUrl;
  final String? payerDisplayName; // snapshot of payer's name at creation
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

  double get totalInBase => amount * rateToBase;

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
