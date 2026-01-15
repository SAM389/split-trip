import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_providers.dart';
import '../utils/settlement_utils.dart';
import '../utils/constants.dart';

class SettleUpScreen extends ConsumerWidget {
  final String tripId;

  const SettleUpScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(tripExpensesProvider(tripId));
    final participantsAsync = ref.watch(tripParticipantsProvider(tripId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settle Up'),
      ),
      body: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return const Center(
              child: Text('No expenses to settle'),
            );
          }

          return participantsAsync.when(
            data: (participants) {
              final participantMap = {
                for (var p in participants) p.id: p.displayName,
              };

              final netBalances = computeNetBalances(expenses);
              final transfers = minimizeCashFlow(netBalances);

              if (transfers.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 80, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'All Settled!',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No pending settlements',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Colors.blue.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.info_outline, size: 48, color: Colors.blue),
                          SizedBox(height: 8),
                          Text(
                            'Minimum Transfers Required',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'These transfers will settle all balances',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...transfers.map((transfer) {
                    final fromName = participantMap[transfer.from] ?? 'Unknown';
                    final toName = participantMap[transfer.to] ?? 'Unknown';

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.arrow_forward),
                        ),
                        title: RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              TextSpan(
                                text: fromName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(text: ' pays '),
                              TextSpan(
                                text: toName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        subtitle: Text(formatCurrency(transfer.amount, 'INR')),
                        trailing: IconButton(
                          icon: const Icon(Icons.payment),
                          tooltip: 'Pay via UPI',
                          onPressed: () => _showUpiPayment(
                            context,
                            fromName,
                            toName,
                            transfer.amount,
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Net Balances',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...netBalances.entries.map((entry) {
                    final name = participantMap[entry.key] ?? 'Unknown';
                    final balance = entry.value;
                    final isPositive = balance > 0.01;
                    final isNegative = balance < -0.01;

                    return ListTile(
                      leading: Icon(
                        isPositive
                            ? Icons.arrow_upward
                            : isNegative
                                ? Icons.arrow_downward
                                : Icons.check,
                        color: isPositive
                            ? Colors.green
                            : isNegative
                                ? Colors.red
                                : Colors.grey,
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
                        formatCurrency(balance.abs(), 'INR'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPositive
                              ? Colors.green
                              : isNegative
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  void _showUpiPayment(
    BuildContext context,
    String fromName,
    String toName,
    double amount,
  ) {
    final vpaController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pay via UPI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$fromName → $toName'),
            Text(
              formatCurrency(amount, 'INR'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: vpaController,
              decoration: const InputDecoration(
                labelText: 'UPI ID',
                hintText: 'user@upi',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final vpa = vpaController.text.trim();
              if (vpa.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter UPI ID')),
                );
                return;
              }

              final upiLink = buildUpiDeepLink(
                vpa: vpa,
                name: toName,
                amount: amount,
                note: 'Trip settlement',
              );

              final uri = Uri.parse(upiLink);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not launch UPI app')),
                  );
                }
              }
            },
            child: const Text('Pay'),
          ),
        ],
      ),
    );
  }
}
