import '../models/expense.dart';
import '../models/transfer.dart';

/// Compute net balances from a list of expenses
/// Positive balance = person is owed money
/// Negative balance = person owes money
Map<String, double> computeNetBalances(List<Expense> expenses) {
  final net = <String, double>{};

  for (final expense in expenses) {
    final paidBase = expense.amount * expense.rateToBase;
    
    // Person who paid gets credited
    net[expense.payerId] = (net[expense.payerId] ?? 0) + paidBase;

    // People who owe get debited
    for (final share in expense.shares) {
      net[share.participantId] = 
          (net[share.participantId] ?? 0) - share.amountInBase;
    }
  }

  return net;
}

/// Generate minimal cash flow transfers to settle all balances
/// Uses greedy algorithm to minimize number of transactions
List<Transfer> minimizeCashFlow(Map<String, double> net) {
  final debtors = <MapEntry<String, double>>[];
  final creditors = <MapEntry<String, double>>[];

  // Separate into debtors (owe money) and creditors (are owed)
  net.forEach((id, balance) {
    if (balance < -0.001) {
      debtors.add(MapEntry(id, -balance)); // Convert to positive
    } else if (balance > 0.001) {
      creditors.add(MapEntry(id, balance));
    }
  });

  // Sort by amount (largest first) for greedy matching
  debtors.sort((a, b) => b.value.compareTo(a.value));
  creditors.sort((a, b) => b.value.compareTo(a.value));

  final transfers = <Transfer>[];
  int i = 0, j = 0;

  while (i < debtors.length && j < creditors.length) {
    final debtAmount = debtors[i].value;
    final creditAmount = creditors[j].value;
    
    // Transfer the minimum of what debtor owes and creditor is owed
    final transferAmount = debtAmount < creditAmount ? debtAmount : creditAmount;
    
    transfers.add(Transfer(
      debtors[i].key,
      creditors[j].key,
      double.parse(transferAmount.toStringAsFixed(2)),
    ));

    // Update remaining amounts
    debtors[i] = MapEntry(debtors[i].key, debtAmount - transferAmount);
    creditors[j] = MapEntry(creditors[j].key, creditAmount - transferAmount);

    // Move to next debtor/creditor if current one is settled
    if (debtors[i].value <= 0.001) i++;
    if (creditors[j].value <= 0.001) j++;
  }

  return transfers;
}

/// Calculate total expenses in base currency
double calculateTotalExpenses(List<Expense> expenses) {
  return expenses.fold(
    0.0,
    (sum, expense) => sum + (expense.amount * expense.rateToBase),
  );
}

/// Calculate expenses by category
Map<String, double> expensesByCategory(List<Expense> expenses) {
  final categoryTotals = <String, double>{};

  for (final expense in expenses) {
    final total = expense.amount * expense.rateToBase;
    categoryTotals[expense.category] = 
        (categoryTotals[expense.category] ?? 0) + total;
  }

  return categoryTotals;
}

/// Calculate amount paid vs owed per participant
Map<String, Map<String, double>> paidVsOwed(List<Expense> expenses) {
  final result = <String, Map<String, double>>{};

  for (final expense in expenses) {
    final payerId = expense.payerId;
    final paidAmount = expense.amount * expense.rateToBase;

    // Initialize if needed
    result[payerId] ??= {'paid': 0.0, 'owed': 0.0};
    result[payerId]!['paid'] = result[payerId]!['paid']! + paidAmount;

    // Track what each participant owes
    for (final share in expense.shares) {
      result[share.participantId] ??= {'paid': 0.0, 'owed': 0.0};
      result[share.participantId]!['owed'] = 
          result[share.participantId]!['owed']! + share.amountInBase;
    }
  }

  return result;
}
