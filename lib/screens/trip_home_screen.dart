import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../widgets/expenses_tab.dart';
import '../widgets/participants_tab.dart';
import '../widgets/reports_tab.dart';

class TripHomeScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripHomeScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripHomeScreen> createState() => _TripHomeScreenState();
}

class _TripHomeScreenState extends ConsumerState<TripHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripProvider(widget.tripId));

    return tripAsync.when(
      data: (trip) {
        if (trip == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Trip Not Found')),
            body: const Center(child: Text('This trip does not exist')),
          );
        }

        final tabs = [
          ExpensesTab(tripId: widget.tripId),
          ParticipantsTab(tripId: widget.tripId),
          ReportsTab(tripId: widget.tripId),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(trip.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download),
                tooltip: 'Export',
                onPressed: () => context.push('/trip/${widget.tripId}/export'),
              ),
            ],
          ),
          body: tabs[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt),
                label: 'Expenses',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Participants',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart),
                label: 'Reports',
              ),
            ],
          ),
          floatingActionButton: _currentIndex == 0
              ? FloatingActionButton(
                  onPressed: () => context.push('/trip/${widget.tripId}/add-expense'),
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}
