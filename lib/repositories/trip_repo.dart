import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/trip.dart';

class TripRepository {
  final FirebaseFirestore _firestore;

  TripRepository(this._firestore);

  /// Watch trips where user is a participant
  Stream<List<Trip>> watchTrips(String userId) {
    return _firestore
        .collection('trips')
        .where('participantIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Trip.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  /// Get a single trip
  Future<Trip?> getTrip(String tripId) async {
    final doc = await _firestore.collection('trips').doc(tripId).get();
    if (!doc.exists) return null;
    return Trip.fromMap(doc.id, doc.data()!);
  }

  /// Create a new trip
  Future<String> createTrip({
    required String ownerId,
    required String name,
    required String baseCurrency,
  }) async {
    final now = DateTime.now();
    final trip = Trip(
      id: '', // Will be set by Firestore
      ownerId: ownerId,
      name: name,
      baseCurrency: baseCurrency,
      createdAt: now,
      participantIds: [ownerId],
    );

    final docRef = await _firestore.collection('trips').add(trip.toMap());
    return docRef.id;
  }

  /// Update trip
  Future<void> updateTrip(Trip trip) async {
    await _firestore.collection('trips').doc(trip.id).update(trip.toMap());
  }

  /// Delete trip (owner only)
  Future<void> deleteTrip(String tripId) async {
    await _firestore.collection('trips').doc(tripId).delete();
  }

  /// Deep delete an entire trip: removes subcollections and receipts in storage.
  /// Caller MUST verify ownership before calling this method.
  Future<void> deleteEntireTrip(String tripId) async {
    final tripRef = _firestore.collection('trips').doc(tripId);

    // 1. Delete storage receipts from expenses
    try {
      final expensesSnap = await tripRef.collection('expenses').get();
      final storage = FirebaseStorage.instance;
      for (final doc in expensesSnap.docs) {
        final data = doc.data();
        final receiptUrl = data['receiptUrl'];
        if (receiptUrl is String && receiptUrl.isNotEmpty) {
          try {
            final ref = storage.refFromURL(receiptUrl);
            await ref.delete();
          } catch (_) {
            // Ignore storage errors; receipt may already be deleted
          }
        }
      }
    } on FirebaseException catch (e) {
      throw FirebaseException(
        plugin: e.plugin,
        code: e.code,
        message: 'Failed to read expenses for receipt cleanup: ${e.code} - ${e.message}',
      );
    }

    // Delete subcollections in batches to avoid exceeding limits.
    Future<void> deleteCollection(String label, Query collectionQuery) async {
      const batchSize = 400; // Firestore limit per batch is 500; keep margin
      while (true) {
        final snap = await collectionQuery.limit(batchSize).get();
        if (snap.size == 0) break;
        final batch = _firestore.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        try {
          await batch.commit();
        } on FirebaseException catch (e) {
          throw FirebaseException(
            plugin: e.plugin,
            code: e.code,
            message: 'Failed to delete $label: ${e.code} - ${e.message}',
          );
        }
      }
    }

    // 2. Delete subcollections
    await deleteCollection('participants', tripRef.collection('participants'));
    await deleteCollection('expenses', tripRef.collection('expenses'));
    await deleteCollection('settlements', tripRef.collection('settlements'));

    // Finally delete trip document itself
    try {
      await tripRef.delete();
    } on FirebaseException catch (e) {
      // Surface Firestore permission or other errors to the caller
      throw FirebaseException(
        plugin: e.plugin,
        code: e.code,
        message: 'Failed to delete trip document: ${e.code} - ${e.message}',
      );
    }
    // Deletion successful; no verification needed (would cause permission-denied on non-existent doc)
  }

  /// Add participant to trip
  Future<void> addParticipant(String tripId, String userId) async {
    await _firestore.collection('trips').doc(tripId).update({
      'participantIds': FieldValue.arrayUnion([userId]),
    });
  }

  /// Remove participant from trip
  Future<void> removeParticipant(String tripId, String userId) async {
    await _firestore.collection('trips').doc(tripId).update({
      'participantIds': FieldValue.arrayRemove([userId]),
    });
  }

  /// Leave trip convenience wrapper (removes participant document as well)
  Future<void> leaveTrip(String tripId, String userId) async {
    final tripRef = _firestore.collection('trips').doc(tripId);
    final tripSnap = await tripRef.get();
    if (!tripSnap.exists) return;
    final data = tripSnap.data() as Map<String, dynamic>;
    if (data['ownerId'] == userId) {
      throw StateError('Owner cannot leave their own trip; delete instead.');
    }
    // Remove from participantIds
    await removeParticipant(tripId, userId);
    // Remove participant document if present
    final partDoc = await tripRef.collection('participants').doc(userId).get();
    if (partDoc.exists) {
      await partDoc.reference.delete();
    }
  }
}
