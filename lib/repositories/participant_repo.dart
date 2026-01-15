import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/participant.dart';

class ParticipantRepository {
  final FirebaseFirestore _firestore;

  ParticipantRepository(this._firestore);

  /// Watch participants for a trip
  Stream<List<Participant>> watchParticipants(String tripId) {
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('participants')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Participant.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  /// Get a single participant
  Future<Participant?> getParticipant(String tripId, String participantId) async {
    final doc = await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('participants')
        .doc(participantId)
        .get();
    
    if (!doc.exists) return null;
    return Participant.fromMap(doc.id, doc.data()!);
  }

  /// Add participant
  Future<void> addParticipant(
    String tripId,
    Participant participant,
  ) async {
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('participants')
        .doc(participant.id)
        .set(participant.toMap());
  }

  /// Update participant
  Future<void> updateParticipant(
    String tripId,
    Participant participant,
  ) async {
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('participants')
        .doc(participant.id)
        .update(participant.toMap());
  }

  /// Delete participant and update all related expenses with current name snapshot
  Future<void> deleteParticipant(String tripId, String participantId) async {
    // First, fetch the participant to get their current displayName
    final participantDoc = await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('participants')
        .doc(participantId)
        .get();
    
    if (participantDoc.exists) {
      final currentDisplayName = participantDoc.data()?['displayName'] as String? ?? 'Unknown';
      
      // Update all expenses where this participant was the payer
      final payerExpenses = await _firestore
          .collection('trips')
          .doc(tripId)
          .collection('expenses')
          .where('payerId', isEqualTo: participantId)
          .get();
      
      for (var doc in payerExpenses.docs) {
        await doc.reference.update({
          'payerDisplayName': currentDisplayName,
        });
      }
      
      // Update all expenses where this participant is in shares
      final shareExpenses = await _firestore
          .collection('trips')
          .doc(tripId)
          .collection('expenses')
          .get();
      
      for (var doc in shareExpenses.docs) {
        final shareParticipantNames = 
            doc.data()['shareParticipantNames'] as Map<String, dynamic>?;
        
        if (shareParticipantNames != null && 
            shareParticipantNames.containsKey(participantId)) {
          shareParticipantNames[participantId] = currentDisplayName;
          await doc.reference.update({
            'shareParticipantNames': shareParticipantNames,
          });
        }
      }
    }
    
    // Now delete the participant
    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('participants')
        .doc(participantId)
        .delete();
  }
}
