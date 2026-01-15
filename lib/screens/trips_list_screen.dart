import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/trip.dart';
import '../providers/auth_providers.dart';
import '../providers/app_providers.dart';
import '../utils/constants.dart';

class TripsListScreen extends ConsumerWidget {
  const TripsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final tripsAsync = ref.watch(userTripsProvider);

    // Intercept Android system back button to exit app
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // Exit the app on Android when back is pressed
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Trips'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person),
              tooltip: 'Profile',
              onPressed: () {
                context.push('/profile');
              },
            ),
          ],
        ),
        body: tripsAsync.when(
          data: (trips) {
            if (trips.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.travel_explore,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No trips yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create your first trip to get started',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: trips.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final trip = trips[index];
                return _TripCard(trip: trip, trips: trips);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateTripDialog(context, ref, user?.uid ?? ''),
          icon: const Icon(Icons.add),
          label: const Text('Create Trip'),
        ),
      ),
    );
  }

  void _showCreateTripDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) {
    final nameController = TextEditingController();
    String selectedCurrency = 'INR';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Trip'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Trip Name',
                hintText: 'e.g., Goa Trip 2024',
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              inputFormatters: [TripNameFormatter()],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCurrency,
              decoration: InputDecoration(
                labelText: 'Base Currency',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
              isExpanded: true,
              menuMaxHeight: 600,
              borderRadius: BorderRadius.circular(16),
              items: commonCurrencies.map((currency) {
                final symbols = {
                  'USD': '\$',
                  'CAD': 'CA\$',
                  'EUR': '€',
                  'INR': '₹',
                  'GBP': '£',
                  'AUD': 'A\$',
                  'JPY': 'JP¥',
                  'CNY': 'CN¥',
                  'SGD': 'S\$',
                  'HKD': 'HK\$',
                  'AED': 'AED',
                  'CHF': 'CHF',
                  'THB': '฿',
                  'OMR': 'OMR',
                  'SAR': 'SAR',
                  'QAR': 'QAR',
                  'NOK': 'NOK',
                  'SEK': 'SEK',
                  'DKK': 'DKK',
                  'KRW': '₩',
                  'IDR': 'Rp',
                  'MYR': 'RM',
                  'VND': '₫',
                };
                final symbol = symbols[currency] ?? currency;
                return DropdownMenuItem(
                  value: currency,
                  child: Text('$currency ($symbol)'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  selectedCurrency = value;
                }
              },
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
              final name = nameController.text.trim();

              final nameError = validateTripName(name);
              if (nameError != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(nameError)));
                return;
              }

              // Check for duplicate trip names
              final tripsAsync = ref.read(userTripsProvider);
              final trips = tripsAsync.value ?? [];

              // Respectful limit: max 100 trips per user
              if (trips.length >= 100) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'You’ve reached the maximum of 100 trips.\nTo keep things organized and running smoothly, you can  delete older trips before creating a new one.',
                      ),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                return;
              }

              final isDuplicate = trips.any(
                (t) => t.name.toLowerCase() == name.toLowerCase(),
              );

              if (isDuplicate) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('A trip with this name already exists'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                return;
              }

              try {
                final repo = ref.read(tripRepoProvider);
                final tripId = await repo.createTrip(
                  ownerId: userId,
                  name: name,
                  baseCurrency: selectedCurrency,
                );

                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                  context.push('/trip/$tripId');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create trip: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends ConsumerWidget {
  final Trip trip;
  final List<Trip> trips;

  const _TripCard({required this.trip, required this.trips});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync = ref.watch(tripParticipantsProvider(trip.id));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(child: Text(trip.name[0].toUpperCase())),
        title: Text(trip.name),
        subtitle: participantsAsync.when(
          data: (participants) {
            return Text(
              '${participants.length} participants · ${trip.baseCurrency}',
            );
          },
          loading: () => const Text('Loading...'),
          error: (_, __) => Text(
            '${trip.participantIds.length} participants · ${trip.baseCurrency}',
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  _showEditDialog(context, ref);
                } else if (value == 'delete') {
                  _showDeleteDialog(context, ref);
                } else if (value == 'leave') {
                  _showLeaveDialog(context, ref);
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              itemBuilder: (ctx) {
                final uid = ref.read(currentUserProvider)?.uid;
                final isOwner = uid != null && trip.ownerId == uid;
                return [
                  if (isOwner) ...[
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Name'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ] else
                    const PopupMenuItem(value: 'leave', child: Text('Leave')),
                ];
              },
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push('/trip/${trip.id}'),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: trip.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Trip Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Trip Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 40,
          inputFormatters: [TripNameFormatter()],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();

              final nameError = validateTripName(newName);
              if (nameError != null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(nameError)));
                }
                return;
              }

              if (newName == trip.name) {
                Navigator.pop(ctx);
                return;
              }

              final isDuplicate = trips.any(
                (t) =>
                    t.id != trip.id &&
                    t.name.toLowerCase() == newName.toLowerCase(),
              );

              if (isDuplicate) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('A trip with this name already exists'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                return;
              }

              try {
                final updatedTrip = trip.copyWith(name: newName);
                await ref.read(tripRepoProvider).updateTrip(updatedTrip);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Trip name updated')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update trip name: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trip?'),
        content: const Text(
          'This will permanently delete the trip and all its data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(tripRepoProvider).deleteEntireTrip(trip.id);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Trip deleted')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete trip: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showLeaveDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave trip?'),
        content: const Text('You will be removed from this trip.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final uid = ref.read(currentUserProvider)?.uid;
              if (uid != null) {
                try {
                  await ref.read(tripRepoProvider).leaveTrip(trip.id, uid);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Left trip')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to leave trip: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}
