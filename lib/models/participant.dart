/// Represents a participant in a trip.
///
/// A participant can be a registered user or a guest added to a specific trip.
/// The [id] typically corresponds to a Firebase user ID, but can also be a
/// locally generated ID for anonymous or guest participants.
class Participant {
  /// Unique identifier (usually Firebase user ID or local ID)
  final String id;
  
  /// Display name of the participant
  final String displayName;
  
  /// Optional profile photo URL from authentication provider
  final String? photoUrl;

  const Participant({
    required this.id,
    required this.displayName,
    this.photoUrl,
  });

  /// Converts the participant to a Firestore-compatible map.
  ///
  /// Excludes the [id] field as it's stored as the document ID in Firestore.
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
    };
  }

  /// Creates a participant instance from a Firestore document.
  ///
  /// [id] is the Firestore document ID.
  /// [map] contains the document data.
  factory Participant.fromMap(String id, Map<String, dynamic> map) {
    return Participant(
      id: id,
      displayName: map['displayName'] as String,
  /// Creates a copy of this participant with the given fields replaced with new values.
  ///
  /// Used for immutable updates in state management.
      photoUrl: map['photoUrl'] as String?,
    );
  }

  Participant copyWith({
    String? id,
    String? displayName,
    String? photoUrl,
  }) {
    return Participant(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
