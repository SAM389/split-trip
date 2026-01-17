import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_trip/models/expense.dart';

void main() {
  group('ExpenseShare Tests', () {
    const testShare = ExpenseShare(
      participantId: 'user123',
      amountInBase: 500.0,
      originalAmount: 25.0,
      originalCurrency: 'USD',
    );

    test('ExpenseShare constructor creates valid instance', () {
      expect(testShare.participantId, 'user123');
      expect(testShare.amountInBase, 500.0);
      expect(testShare.originalAmount, 25.0);
      expect(testShare.originalCurrency, 'USD');
    });

    test('ExpenseShare can be created without original amount/currency', () {
      const share = ExpenseShare(
        participantId: 'user456',
        amountInBase: 300.0,
      );

      expect(share.participantId, 'user456');
      expect(share.amountInBase, 300.0);
      expect(share.originalAmount, isNull);
      expect(share.originalCurrency, isNull);
    });

    test('ExpenseShare toMap converts to Firestore-compatible map', () {
      final map = testShare.toMap();

      expect(map['participantId'], 'user123');
      expect(map['amountInBase'], 500.0);
      expect(map['originalAmount'], 25.0);
      expect(map['originalCurrency'], 'USD');
    });

    test('ExpenseShare fromMap creates instance from map', () {
      final map = {
        'participantId': 'user789',
        'amountInBase': 750.0,
        'originalAmount': 100.0,
        'originalCurrency': 'EUR',
      };

      final share = ExpenseShare.fromMap(map);

      expect(share.participantId, 'user789');
      expect(share.amountInBase, 750.0);
      expect(share.originalAmount, 100.0);
      expect(share.originalCurrency, 'EUR');
    });

    test('ExpenseShare roundtrip preserves data', () {
      final map = testShare.toMap();
      final reconstructed = ExpenseShare.fromMap(map);

      expect(reconstructed.participantId, testShare.participantId);
      expect(reconstructed.amountInBase, testShare.amountInBase);
      expect(reconstructed.originalAmount, testShare.originalAmount);
      expect(reconstructed.originalCurrency, testShare.originalCurrency);
    });
  });

  group('SplitType Enum Tests', () {
    test('SplitType enum has correct values', () {
      expect(SplitType.equal, isNotNull);
      expect(SplitType.percentage, isNotNull);
      expect(SplitType.exact, isNotNull);
    });

    test('SplitType enum can be converted to string', () {
      expect(SplitType.equal.toString(), 'SplitType.equal');
      expect(SplitType.percentage.toString(), 'SplitType.percentage');
      expect(SplitType.exact.toString(), 'SplitType.exact');
    });

    test('SplitType enum has correct count', () {
      expect(SplitType.values.length, 3);
    });
  });

  group('Expense Model Tests', () {
    final testDate = DateTime(2024, 1, 15, 12, 30);
    // Realistic scenario: Trip with INR base currency, expense also in INR
    final testExpense = Expense(
      id: 'expense123',
      tripId: 'trip456', // Trip with base currency INR
      payerId: 'user789',
      description: 'Dinner at restaurant',
      amount: 1200.0, // 1200 INR
      expenseCurrency: 'INR', // Same as trip base currency
      rateToBase: 1.0, // Always 1.0 since expense matches trip currency
      date: testDate,
      splitType: SplitType.equal,
      splitMeta: {'user789': 600.0, 'user101': 600.0},
      shares: [
        const ExpenseShare(participantId: 'user789', amountInBase: 600.0),
        const ExpenseShare(participantId: 'user101', amountInBase: 600.0),
      ],
      category: 'Food',
      receiptUrl: 'https://storage.example.com/receipt.jpg',
      payerDisplayName: 'John Doe',
      shareParticipantNames: {'user789': 'John Doe', 'user101': 'Jane Smith'},
    );

    test('Expense constructor creates valid instance', () {
      expect(testExpense.id, 'expense123');
      expect(testExpense.tripId, 'trip456');
      expect(testExpense.payerId, 'user789');
      expect(testExpense.description, 'Dinner at restaurant');
      expect(testExpense.amount, 1200.0);
      expect(testExpense.expenseCurrency, 'INR');
      expect(testExpense.rateToBase, 1.0);
      expect(testExpense.date, testDate);
      expect(testExpense.splitType, SplitType.equal);
      expect(testExpense.category, 'Food');
    });

    test('Expense totalInBase equals amount when currency matches trip', () {
      // Since expense is in same currency as trip, no conversion needed
      expect(testExpense.totalInBase, 1200.0);
      expect(testExpense.amount, testExpense.totalInBase);
    });

    test('Expense currency always matches trip base currency', () {
      // In this app, expense currency must equal trip base currency
      // If trip is in INR, all expenses are in INR
      expect(testExpense.expenseCurrency, 'INR');
      expect(testExpense.rateToBase, 1.0);
      
      // A trip with USD base currency has expenses in USD
      final usdExpense = testExpense.copyWith(
        expenseCurrency: 'USD',
        amount: 100.0,
        rateToBase: 1.0, // Always 1.0 as no conversion happens
      );
      expect(usdExpense.expenseCurrency, 'USD');
      expect(usdExpense.totalInBase, 100.0);
      
      // A trip with EUR base currency has expenses in EUR
      final eurExpense = testExpense.copyWith(
        expenseCurrency: 'EUR',
        amount: 50.0,
        rateToBase: 1.0,
      );
      expect(eurExpense.expenseCurrency, 'EUR');
      expect(eurExpense.totalInBase, 50.0);
    });

    test('Expense toMap converts to Firestore-compatible map', () {
      final map = testExpense.toMap();

      expect(map['tripId'], 'trip456');
      expect(map['payerId'], 'user789');
      expect(map['description'], 'Dinner at restaurant');
      expect(map['amount'], 1200.0);
      expect(map['expenseCurrency'], 'INR');
      expect(map['rateToBase'], 1.0);
      expect(map['date'], isA<Timestamp>());
      expect(map['splitType'], 'equal');
      expect(map['category'], 'Food');
      expect(map['receiptUrl'], 'https://storage.example.com/receipt.jpg');
      expect(map['shares'], isA<List>());
      expect(map.containsKey('id'), false);
    });

    test('Expense fromMap creates instance from Firestore document', () {
      final map = {
        'tripId': 'trip789', // Trip with INR base
        'payerId': 'user111',
        'description': 'Hotel booking',
        'amount': 3000.0, // 3000 INR
        'expenseCurrency': 'INR', // Must match trip base currency
        'rateToBase': 1.0, // Always 1.0
        'date': Timestamp.fromDate(testDate),
        'splitType': 'percentage',
        'splitMeta': {'user111': 1500.0, 'user222': 1500.0},
        'shares': [
          {'participantId': 'user111', 'amountInBase': 1500.0},
          {'participantId': 'user222', 'amountInBase': 1500.0},
        ],
        'category': 'Stay',
        'receiptUrl': null,
        'payerDisplayName': 'Alice',
        'shareParticipantNames': {'user111': 'Alice', 'user222': 'Bob'},
      };

      final expense = Expense.fromMap('expense999', map);

      expect(expense.id, 'expense999');
      expect(expense.tripId, 'trip789');
      expect(expense.payerId, 'user111');
      expect(expense.description, 'Hotel booking');
      expect(expense.amount, 3000.0);
      expect(expense.splitType, SplitType.percentage);
      expect(expense.category, 'Stay');
      expect(expense.shares.length, 2);
    });

    test('Expense copyWith creates modified copy', () {
      final updated = testExpense.copyWith(
        description: 'Updated dinner',
        amount: 1500.0,
        category: 'Entertainment',
      );

      expect(updated.id, testExpense.id);
      expect(updated.description, 'Updated dinner');
      expect(updated.amount, 1500.0);
      expect(updated.category, 'Entertainment');
      expect(updated.payerId, testExpense.payerId);
    });

    test('Expense with different split types', () {
      final equalSplit = testExpense.copyWith(splitType: SplitType.equal);
      final percentSplit = testExpense.copyWith(splitType: SplitType.percentage);
      final exactSplit = testExpense.copyWith(splitType: SplitType.exact);

      expect(equalSplit.splitType, SplitType.equal);
      expect(percentSplit.splitType, SplitType.percentage);
      expect(exactSplit.splitType, SplitType.exact);
    });

    test('Expense roundtrip through toMap and fromMap', () {
      final map = testExpense.toMap();
      final reconstructed = Expense.fromMap(testExpense.id, map);

      expect(reconstructed.id, testExpense.id);
      expect(reconstructed.tripId, testExpense.tripId);
      expect(reconstructed.description, testExpense.description);
      expect(reconstructed.amount, testExpense.amount);
      expect(reconstructed.splitType, testExpense.splitType);
      expect(reconstructed.shares.length, testExpense.shares.length);
    });

    test('Expense handles multiple shares', () {
      final shares = [
        const ExpenseShare(participantId: 'user1', amountInBase: 100.0),
        const ExpenseShare(participantId: 'user2', amountInBase: 200.0),
        const ExpenseShare(participantId: 'user3', amountInBase: 300.0),
        const ExpenseShare(participantId: 'user4', amountInBase: 400.0),
      ];

      final multiShareExpense = testExpense.copyWith(shares: shares);
      expect(multiShareExpense.shares.length, 4);
      
      final totalShares = multiShareExpense.shares
          .fold(0.0, (sum, share) => sum + share.amountInBase);
      expect(totalShares, 1000.0);
    });

    test('Expense with null optional fields', () {
      final minimalExpense = Expense(
        id: 'min123',
        tripId: 'trip123',
        payerId: 'user123',
        description: 'Test',
        amount: 100.0,
        expenseCurrency: 'USD',
        rateToBase: 1.0,
        date: testDate,
        splitType: SplitType.equal,
        splitMeta: {},
        shares: [],
        category: 'Other',
      );

      expect(minimalExpense.receiptUrl, isNull);
      expect(minimalExpense.payerDisplayName, isNull);
      expect(minimalExpense.shareParticipantNames, isNull);
    });

    test('Expense categories are flexible', () {
      final categories = ['Food', 'Transport', 'Stay', 'Entertainment', 'Other'];
      
      for (final category in categories) {
        final expense = testExpense.copyWith(category: category);
        expect(expense.category, category);
      }
    });

    test('Expense handles decimal amounts precisely', () {
      final preciseExpense = testExpense.copyWith(amount: 123.45);
      expect(preciseExpense.amount, 123.45);
      expect(preciseExpense.totalInBase, 123.45);
    });
  });
}
