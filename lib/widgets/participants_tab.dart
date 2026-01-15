import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/participant.dart';

class ParticipantsTab extends ConsumerWidget {
  final String tripId;

  const ParticipantsTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync = ref.watch(tripParticipantsProvider(tripId));

    return participantsAsync.when(
      data: (participants) {
        return Column(
          children: [
            Expanded(
              child: participants.isEmpty
                  ? const Center(
                      child: Text('No participants yet'),
                    )
                  : ListView.builder(
                      itemCount: participants.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final participant = participants[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: participant.photoUrl != null
                                  ? NetworkImage(participant.photoUrl!)
                                  : null,
                              child: participant.photoUrl == null
                                  ? Text(participant.displayName[0].toUpperCase())
                                  : null,
                            ),
                            title: Text(participant.displayName),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditParticipantDialog(context, ref, participant, participants);
                                } else if (value == 'delete') {
                                  _deleteParticipant(context, ref, participant);
                                }
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit Name')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => _showAddParticipantDialog(context, ref),
                icon: const Icon(Icons.person_add),
                label: const Text('Add Participant'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  void _showEditParticipantDialog(
    BuildContext context,
    WidgetRef ref,
    Participant participant,
    List<Participant> allParticipants,
  ) {
    final nameController = TextEditingController(text: participant.displayName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Participant'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter participant name',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 25,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              
              if (name.isEmpty) {
                return;
              }

              // Check for duplicate names (excluding current participant)
              final isDuplicate = allParticipants.any(
                (p) => p.id != participant.id && 
                       p.displayName.toLowerCase() == name.toLowerCase(),
              );

              if (isDuplicate) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('A participant with this name already exists'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                return;
              }

              try {
                final repo = ref.read(participantRepoProvider);
                
                final updatedParticipant = participant.copyWith(displayName: name);
                repo.updateParticipant(tripId, updatedParticipant);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Participant updated')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update participant: $e')),
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

  void _showAddParticipantDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Participant'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter participant name',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 25,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              
              if (name.isEmpty) {
                return;
              }

              // Check for duplicate names
              final participantsAsync = ref.read(tripParticipantsProvider(tripId));
              final participants = participantsAsync.value ?? [];
              
              // Check if limit reached
              if (participants.length >= 40) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('A trip can have up to 40 participants for clarity and performance.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                return;
              }
              
              final isDuplicate = participants.any(
                (p) => p.displayName.toLowerCase() == name.toLowerCase(),
              );

              if (isDuplicate) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('A participant with this name already exists'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                return;
              }

              try {
                final repo = ref.read(participantRepoProvider);
                final tripRepo = ref.read(tripRepoProvider);
                
                // Generate a unique ID for the participant
                final participantId = DateTime.now().millisecondsSinceEpoch.toString();
                
                final participant = Participant(
                  id: participantId,
                  displayName: name,
                );

                await repo.addParticipant(tripId, participant);
                tripRepo.addParticipant(tripId, participantId);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Participant added')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add participant: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteParticipant(
    BuildContext context,
    WidgetRef ref,
    Participant participant,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Participant'),
        content: Text(
          'Are you sure you want to remove ${participant.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final repo = ref.read(participantRepoProvider);
                final tripRepo = ref.read(tripRepoProvider);
                
                await repo.deleteParticipant(tripId, participant.id);
                await tripRepo.removeParticipant(tripId, participant.id);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Participant removed')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to remove participant: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
