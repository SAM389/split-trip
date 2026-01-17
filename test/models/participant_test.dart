import 'package:flutter_test/flutter_test.dart';
import 'package:split_trip/models/participant.dart';

void main() {
  group('Participant Model Tests', () {
    const testParticipant = Participant(
      id: 'user123',
      displayName: 'John Doe',
      photoUrl: 'https://example.com/photo.jpg',
    );

    test('Participant constructor creates valid instance', () {
      expect(testParticipant.id, 'user123');
      expect(testParticipant.displayName, 'John Doe');
      expect(testParticipant.photoUrl, 'https://example.com/photo.jpg');
    });

    test('Participant can be created without photoUrl', () {
      const participant = Participant(
        id: 'user456',
        displayName: 'Jane Smith',
      );

      expect(participant.id, 'user456');
      expect(participant.displayName, 'Jane Smith');
      expect(participant.photoUrl, isNull);
    });

    test('toMap converts Participant to Firestore-compatible map', () {
      final map = testParticipant.toMap();

      expect(map['displayName'], 'John Doe');
      expect(map['photoUrl'], 'https://example.com/photo.jpg');
      expect(map.containsKey('id'), false); // ID not included in map
    });

    test('toMap with null photoUrl', () {
      const participant = Participant(
        id: 'user789',
        displayName: 'Bob Wilson',
      );

      final map = participant.toMap();

      expect(map['displayName'], 'Bob Wilson');
      expect(map['photoUrl'], isNull);
    });

    test('fromMap creates Participant from Firestore document', () {
      final map = {
        'displayName': 'John Doe',
        'photoUrl': 'https://example.com/photo.jpg',
      };

      final participant = Participant.fromMap('user123', map);

      expect(participant.id, 'user123');
      expect(participant.displayName, 'John Doe');
      expect(participant.photoUrl, 'https://example.com/photo.jpg');
    });

    test('fromMap with null photoUrl', () {
      final map = {
        'displayName': 'Alice Brown',
        'photoUrl': null,
      };

      final participant = Participant.fromMap('user999', map);

      expect(participant.id, 'user999');
      expect(participant.displayName, 'Alice Brown');
      expect(participant.photoUrl, isNull);
    });

    test('copyWith creates modified copy with specified fields', () {
      final updatedParticipant = testParticipant.copyWith(
        displayName: 'John Smith',
        photoUrl: 'https://example.com/new-photo.jpg',
      );

      expect(updatedParticipant.id, testParticipant.id);
      expect(updatedParticipant.displayName, 'John Smith');
      expect(updatedParticipant.photoUrl, 'https://example.com/new-photo.jpg');
    });

    test('copyWith with no parameters returns identical participant', () {
      final copiedParticipant = testParticipant.copyWith();

      expect(copiedParticipant.id, testParticipant.id);
      expect(copiedParticipant.displayName, testParticipant.displayName);
      expect(copiedParticipant.photoUrl, testParticipant.photoUrl);
    });

    test('copyWith can update only displayName', () {
      final updated = testParticipant.copyWith(displayName: 'New Name');

      expect(updated.id, testParticipant.id);
      expect(updated.displayName, 'New Name');
      expect(updated.photoUrl, testParticipant.photoUrl);
    });

    test('copyWith can update only photoUrl', () {
      final updated = testParticipant.copyWith(
        photoUrl: 'https://example.com/updated.jpg',
      );

      expect(updated.id, testParticipant.id);
      expect(updated.displayName, testParticipant.displayName);
      expect(updated.photoUrl, 'https://example.com/updated.jpg');
    });

    test('copyWith can update only id', () {
      final updated = testParticipant.copyWith(id: 'newUser999');

      expect(updated.id, 'newUser999');
      expect(updated.displayName, testParticipant.displayName);
      expect(updated.photoUrl, testParticipant.photoUrl);
    });

    test('toMap and fromMap roundtrip preserves data', () {
      final map = testParticipant.toMap();
      final reconstructed = Participant.fromMap(testParticipant.id, map);

      expect(reconstructed.id, testParticipant.id);
      expect(reconstructed.displayName, testParticipant.displayName);
      expect(reconstructed.photoUrl, testParticipant.photoUrl);
    });

    test('Participant handles special characters in displayName', () {
      const participant = Participant(
        id: 'user111',
        displayName: "O'Brien-Smith (José)",
      );

      expect(participant.displayName, "O'Brien-Smith (José)");

      final map = participant.toMap();
      final reconstructed = Participant.fromMap('user111', map);
      expect(reconstructed.displayName, "O'Brien-Smith (José)");
    });

    test('Participant handles long displayName', () {
      const longName = 'This is a very long participant name that might exceed normal length expectations';
      const participant = Participant(
        id: 'user222',
        displayName: longName,
      );

      expect(participant.displayName, longName);
      expect(participant.displayName.length, greaterThan(50));
    });

    test('Participant handles empty photoUrl string differently from null', () {
      const withEmptyUrl = Participant(
        id: 'user333',
        displayName: 'Test User',
        photoUrl: '',
      );

      const withNullUrl = Participant(
        id: 'user444',
        displayName: 'Test User',
      );

      expect(withEmptyUrl.photoUrl, '');
      expect(withNullUrl.photoUrl, isNull);
      expect(withEmptyUrl.photoUrl == withNullUrl.photoUrl, false);
    });
  });
}
