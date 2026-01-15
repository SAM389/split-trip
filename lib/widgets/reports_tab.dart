import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_providers.dart';
import '../utils/settlement_utils.dart';
import '../utils/constants.dart';

class ReportsTab extends ConsumerWidget {
  final String tripId;

  const ReportsTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripProvider(tripId));
    final expensesAsync = ref.watch(tripExpensesProvider(tripId));
    final participantsAsync = ref.watch(tripParticipantsProvider(tripId));

    return expensesAsync.when(
      data: (expenses) {
        if (expenses.isEmpty) {
          return const Center(
            child: Text('No data to show yet'),
          );
        }

        return tripAsync.when(
          data: (trip) {
            if (trip == null) {
              return const Center(child: Text('Trip not found'));
            }

            final currency = trip.baseCurrency;

            return participantsAsync.when(
              data: (participants) {
                final participantMap = {
                  for (var p in participants) p.id: p.displayName,
                };

                // Build consolidated snapshot of all participant names from all expenses
                final allParticipantSnapshots = <String, String>{};
                for (var expense in expenses) {
                  // Add payer name snapshot
                  if (expense.payerDisplayName != null) {
                    allParticipantSnapshots[expense.payerId] = expense.payerDisplayName!;
                  }
                  // Add share participant names
                  if (expense.shareParticipantNames != null) {
                    allParticipantSnapshots.addAll(expense.shareParticipantNames!);
                  }
                }

                final total = calculateTotalExpenses(expenses);
                final byCategory = expensesByCategory(expenses);
                final netBalances = computeNetBalances(expenses);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total Summary
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text(
                                'Total Expenses',
                                style: TextStyle(fontSize:17.5, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                formatCurrency(total, currency),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Category Breakdown
                      const Text(
                        'By Category',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 250,
                        child: _buildPieChart(byCategory),
                      ),
                      const SizedBox(height: 24),

                      // Net Balances
                      const Text(
                        'Net Balances',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ...netBalances.entries.map((entry) {
                        final name = getParticipantDisplayName(
                          entry.key,
                          participantMap,
                          allParticipantSnapshots,
                        );
                        final balance = entry.value;
                        final isPositive = balance > 0.01;
                        final isNegative = balance < -0.01;

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isPositive
                                  ? Colors.green
                                  : isNegative
                                      ? Colors.red
                                      : Colors.grey,
                              child: Icon(
                                isPositive
                                    ? Icons.arrow_upward
                                    : isNegative
                                        ? Icons.arrow_downward
                                        : Icons.check,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(name),
                            subtitle: Text(
                              isPositive
                                  ? 'is owed'
                                  : isNegative
                                      ? 'owes'
                                      : 'settled',
                            ),
                            trailing: Text(
                              formatCurrency(balance.abs(), currency),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isPositive
                                    ? Colors.green
                                    : isNegative
                                        ? Colors.red
                                        : Colors.grey,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error loading participants')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error loading trip')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildPieChart(Map<String, double> byCategory) {
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.teal,
    ];

    return PieChart(
      PieChartData(
        sections: byCategory.entries.toList().asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value.key;
          final amount = entry.value.value;
          
          return PieChartSectionData(
            value: amount,
            title: category,
            color: colors[index % colors.length],
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }
}



