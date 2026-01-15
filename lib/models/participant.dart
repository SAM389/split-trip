class Participant {
  final String id; // userId or local id
  final String displayName;
  final String? photoUrl;

  const Participant({
    required this.id,
    required this.displayName,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
    };
  }

  factory Participant.fromMap(String id, Map<String, dynamic> map) {
    return Participant(
      id: id,
      displayName: map['displayName'] as String,
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
