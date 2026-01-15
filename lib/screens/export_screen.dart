import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../providers/app_providers.dart';
import '../utils/settlement_utils.dart';
import '../utils/constants.dart';

class ExportScreen extends ConsumerWidget {
  final String tripId;

  const ExportScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripProvider(tripId));
    final expensesAsync = ref.watch(tripExpensesProvider(tripId));
    final participantsAsync = ref.watch(tripParticipantsProvider(tripId));

    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Export Options',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf, size: 40),
                title: const Text('Export as PDF'),
                subtitle: const Text('Detailed report with charts'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final trip = tripAsync.value;
                  final expenses = expensesAsync.value;
                  final participants = participantsAsync.value;

                  if (trip != null &&
                      expenses != null &&
                      participants != null) {
                    await _exportPdf(context, trip, expenses, participants);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    dynamic trip,
    List<dynamic> expenses,
    List<dynamic> participants,
  ) async {
    try {
      final pdf = pw.Document();

      // Load a font that supports Unicode characters (currency symbols)
      final font = await PdfGoogleFonts.notoSansRegular();
      final fontBold = await PdfGoogleFonts.notoSansBold();

      // Cast to proper types
      final expensesList = expenses.cast<Expense>();

      final participantMap = {
        for (var p in participants) p.id: p.displayName,
      }.cast<String, String>();

      // Build consolidated snapshot of all participant names from all expenses
      final allParticipantSnapshots = <String, String>{};
      for (var expense in expensesList) {
        // Add payer name snapshot
        if (expense.payerDisplayName != null) {
          allParticipantSnapshots[expense.payerId] = expense.payerDisplayName!;
        }
        // Add share participant names
        if (expense.shareParticipantNames != null) {
          allParticipantSnapshots.addAll(expense.shareParticipantNames!);
        }
      }

      final netBalances = computeNetBalances(expensesList);
      final transfers = minimizeCashFlow(netBalances);
      final total = calculateTotalExpenses(expensesList);
      final byCategory = expensesByCategory(expensesList);

      // Build union of participant IDs (current + snapshots) for listing
      // Use a set literal for uniqueness, then convert to list
      final allParticipantIds = <String>{
        ...participantMap.keys,
        ...allParticipantSnapshots.keys,
      }.toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            // Header
            pw.Header(
              level: 0,
              child: pw.Text(
                trip.name,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  font: fontBold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Summary
            pw.Text(
              'Summary',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: fontBold),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Base Currency: ${trip.baseCurrency}', style: pw.TextStyle(font: font)),
            pw.Text(
              'Total Expenses: ${formatCurrency(total, trip.baseCurrency)}',
              style: pw.TextStyle(font: font),
            ),
            pw.Text('Participants: ${allParticipantIds.length}', style: pw.TextStyle(font: font)),
            pw.Text('Expenses: ${expenses.length}', style: pw.TextStyle(font: font)),
            pw.SizedBox(height: 20),

            // Participants
            pw.Text(
              'Participants',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: fontBold),
            ),
            pw.SizedBox(height: 10),
            ...allParticipantIds.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final id = entry.value;
              return pw.Text(
                '$index. ${getParticipantDisplayName(id, participantMap, allParticipantSnapshots)}',
                style: pw.TextStyle(font: font),
              );
            }),
            pw.SizedBox(height: 20),

            // Settlement Transfers
            pw.Text(
              'Settlement Plan',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: fontBold),
            ),
            pw.SizedBox(height: 10),
            if (transfers.isEmpty)
              pw.Text('All settled!', style: pw.TextStyle(font: font))
            else
              pw.Table.fromTextArray(
                cellStyle: pw.TextStyle(font: font),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fontBold),
                headers: ['From', 'To', 'Amount'],
                data: transfers.map((t) {
                  final fromName = getParticipantDisplayName(
                    t.from,
                    participantMap,
                    allParticipantSnapshots,
                  );
                  final toName = getParticipantDisplayName(
                    t.to,
                    participantMap,
                    allParticipantSnapshots,
                  );
                  return [
                    fromName,
                    toName,
                    formatCurrency(t.amount, trip.baseCurrency),
                  ];
                }).toList(),
              ),
            pw.SizedBox(height: 20),

            // Expenses by Category
            pw.Text(
              'By Category',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: fontBold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Category', 'Amount'],
              cellStyle: pw.TextStyle(font: font),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fontBold),
              data: byCategory.entries
                  .map(
                    (e) => [e.key, formatCurrency(e.value, trip.baseCurrency)],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 20),

            // All Expenses
            pw.Text(
              'All Expenses',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: fontBold),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Date', 'Description', 'Paid By', 'Amount', 'Category'],
              data: expensesList.map((e) {
                return [
                  DateFormat.yMd().format(e.date),
                  e.description,
                  getParticipantDisplayName(
                    e.payerId,
                    participantMap,
                    allParticipantSnapshots,
                  ),
                  formatCurrency(e.amount, e.expenseCurrency),
                  e.category,
                ];
              }).toList(),
              cellStyle: pw.TextStyle(fontSize: 10, font: font),
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                font: fontBold,
              ),
              // Center align all column headers
              headerAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
              },
              // Keep the layout stable with sized columns
              columnWidths: {
                0: const pw.FixedColumnWidth(62), // Date
                1: const pw.FlexColumnWidth(3), // Description
                2: const pw.FlexColumnWidth(2), // Paid By
                3: const pw.FixedColumnWidth(
                  92,
                ), // Amount (wider to fit large numbers)
                4: const pw.FlexColumnWidth(
                  1.6,
                ), // Category (slightly narrower)
              },
              // Align numeric values to the right for readability
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
              },
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }


}
