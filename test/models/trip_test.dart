
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_trip/models/trip.dart';

void main() {
  group('Trip Model Tests', () {
    final testDate = DateTime(2024, 1, 15);
    final testTrip = Trip(
      id: 'trip123',
      ownerId: 'user456',
      name: 'Bangkok Trip',
      baseCurrency: 'THB',
      createdAt: testDate,
      participantIds: ['user456', 'user789'],
    );

    test('Trip constructor creates valid instance', () {
      expect(testTrip.id, 'trip123');
      expect(testTrip.ownerId, 'user456');
      expect(testTrip.name, 'Bangkok Trip');
      expect(testTrip.baseCurrency, 'THB');
      expect(testTrip.createdAt, testDate);
      expect(testTrip.participantIds, ['user456', 'user789']);
    });

    test('toMap converts Trip to Firestore-compatible map', () {
      final map = testTrip.toMap();

      expect(map['ownerId'], 'user456');
      expect(map['name'], 'Bangkok Trip');
      expect(map['baseCurrency'], 'THB');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['participantIds'], ['user456', 'user789']);
      expect(map.containsKey('id'), false); // ID not included in map
    });

    test('fromMap creates Trip from Firestore document', () {
      final map = {
        'ownerId': 'user456',
        'name': 'Bangkok Trip',
        'baseCurrency': 'THB',
        'createdAt': Timestamp.fromDate(testDate),
        'participantIds': ['user456', 'user789'],
      };

      final trip = Trip.fromMap('trip123', map);

      expect(trip.id, 'trip123');
      expect(trip.ownerId, 'user456');
      expect(trip.name, 'Bangkok Trip');
      expect(trip.baseCurrency, 'THB');
      expect(trip.createdAt, testDate);
      expect(trip.participantIds, ['user456', 'user789']);
    });

    test('copyWith creates modified copy with specified fields', () {
      final updatedTrip = testTrip.copyWith(
        name: 'Updated Bangkok Trip',
        participantIds: ['user456', 'user789', 'user101'],
      );

      expect(updatedTrip.id, testTrip.id);
      expect(updatedTrip.ownerId, testTrip.ownerId);
      expect(updatedTrip.name, 'Updated Bangkok Trip');
      expect(updatedTrip.baseCurrency, testTrip.baseCurrency);
      expect(updatedTrip.createdAt, testTrip.createdAt);
      expect(updatedTrip.participantIds, ['user456', 'user789', 'user101']);
    });

    test('copyWith with no parameters returns identical trip', () {
      final copiedTrip = testTrip.copyWith();

      expect(copiedTrip.id, testTrip.id);
      expect(copiedTrip.ownerId, testTrip.ownerId);
      expect(copiedTrip.name, testTrip.name);
      expect(copiedTrip.baseCurrency, testTrip.baseCurrency);
      expect(copiedTrip.createdAt, testTrip.createdAt);
      expect(copiedTrip.participantIds, testTrip.participantIds);
    });

    test('toMap and fromMap roundtrip preserves data', () {
      final map = testTrip.toMap();
      final reconstructedTrip = Trip.fromMap(testTrip.id, map);

      expect(reconstructedTrip.id, testTrip.id);
      expect(reconstructedTrip.ownerId, testTrip.ownerId);
      expect(reconstructedTrip.name, testTrip.name);
      expect(reconstructedTrip.baseCurrency, testTrip.baseCurrency);
      expect(reconstructedTrip.createdAt, testTrip.createdAt);
      expect(reconstructedTrip.participantIds, testTrip.participantIds);
    });

    test('Trip supports multiple currencies', () {
      final trips = [
        testTrip.copyWith(baseCurrency: 'USD'),
        testTrip.copyWith(baseCurrency: 'EUR'),
        testTrip.copyWith(baseCurrency: 'INR'),
        testTrip.copyWith(baseCurrency: 'JPY'),
      ];

      expect(trips[0].baseCurrency, 'USD');
      expect(trips[1].baseCurrency, 'EUR');
      expect(trips[2].baseCurrency, 'INR');
      expect(trips[3].baseCurrency, 'JPY');
    });

    test('Trip can have empty participant list', () {
      final emptyTrip = testTrip.copyWith(participantIds: []);
      expect(emptyTrip.participantIds, isEmpty);
    });

    test('Trip can have single participant', () {
      final soloTrip = testTrip.copyWith(participantIds: ['user123']);
      expect(soloTrip.participantIds, ['user123']);
      expect(soloTrip.participantIds.length, 1);
    });

    test('Trip can have many participants', () {
      final largeGroupTrip = testTrip.copyWith(
        participantIds: List.generate(20, (i) => 'user$i'),
      );
      expect(largeGroupTrip.participantIds.length, 20);
    });
  });
}
