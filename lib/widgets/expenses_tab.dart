import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../providers/app_providers.dart';
import '../utils/constants.dart';
import '../screens/add_expense_screen.dart';

class ExpensesTab extends ConsumerWidget {
  final String tripId;

  const ExpensesTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(tripExpensesProvider(tripId));
    final participantsAsync = ref.watch(tripParticipantsProvider(tripId));

    return expensesAsync.when(
      data: (expenses) {
        if (expenses.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No expenses yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap + to add your first expense',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return participantsAsync.when(
          data: (participants) {
            final participantMap = {
              for (var p in participants) p.id: p.displayName,
            };

            return ListView.builder(
              itemCount: expenses.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final expense = expenses[index];
                final payerName = getParticipantDisplayName(
                  expense.payerId,
                  participantMap,
                  expense.shareParticipantNames,
                );
                final dateStr = DateFormat.yMMMd().format(expense.date);

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(_getCategoryIcon(expense.category)),
                    ),
                    title: Text(expense.description),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          payerName,
                          style: const TextStyle(fontSize: 14, color: Colors.black),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 14, color: Colors.black),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          expense.category,
                          style: const TextStyle(fontSize: 14, color: Colors.black),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatCurrency(
                                expense.totalInBase,
                                expense.expenseCurrency,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              final payerExists = participantMap.containsKey(
                                expense.payerId,
                              );

                              if (!payerExists) {
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Cannot edit expense'),
                                      content: const Text(
                                        'This expense was paid by a participant who has been removed from the trip.\n\n'
                                        'To protect expense history, this expense cannot be edited.',
                                      ),
                                      actions: [
                                        FilledButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return;
                              }

                              // Navigate to edit expense screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => AddExpenseScreen(
                                    tripId: tripId,
                                    expenseToEdit: expense,
                                  ),
                                ),
                              );
                            } else if (value == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete expense?'),
                                  content: Text(
                                    'Delete "${expense.description}" (${formatCurrency(expense.totalInBase, expense.expenseCurrency)})?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  await ref
                                      .read(expenseRepoProvider)
                                      .deleteExpense(tripId, expense.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Expense deleted'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to delete: $e'),
                                      ),
                                    );
                                  }
                                }
                              }
                            }
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () {
                      // TODO: Show expense detail
                      _showExpenseDetail(context, expense, participantMap);
                    },
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              Center(child: Text('Error loading participants')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;
      case 'Stay':
        return Icons.hotel;
      case 'Transport':
        return Icons.directions_car;
      case 'Entertainment':
        return Icons.movie;
      case 'Shopping':
        return Icons.shopping_bag;
      default:
        return Icons.attach_money;
    }
  }

  // Consistent text style for all monetary values in expense details
  static const expenseAmountTextStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: Colors.black,
  );

  void _showExpenseDetail(
    BuildContext context,
    expense,
    Map<String, String> participantMap,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom:
                24 +
                MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                expense.description,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                'Amount',
                formatCurrency(expense.amount, expense.expenseCurrency),
              ),
              _buildDetailRow(
                'Paid by',
                getParticipantDisplayName(
                  expense.payerId,
                  participantMap,
                  expense.shareParticipantNames,
                ),
              ),
              _buildDetailRow('Date', DateFormat.yMMMMd().format(expense.date)),
              _buildDetailRow('Category', expense.category),
              _buildDetailRow('Split', _formatSplitType(expense.splitType)),
              const SizedBox(height: 16),
              const Text(
                'Split between:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              ...expense.shares.map(
                (share) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        getParticipantDisplayName(
                          share.participantId,
                          participantMap,
                          expense.shareParticipantNames,
                        ),
                        style: expenseAmountTextStyle,
                      ),
                      Text(
                        formatCurrency(
                          share.amountInBase,
                          expense.expenseCurrency,
                        ),
                        style: expenseAmountTextStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSplitType(SplitType splitType) {
    switch (splitType) {
      case SplitType.equal:
        return 'Equal';
      case SplitType.percentage:
        return 'Percentage';
      case SplitType.exact:
        return 'Exact';
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: expenseAmountTextStyle),
          Text(value, style: expenseAmountTextStyle),
        ],
      ),
    );
  }
}
