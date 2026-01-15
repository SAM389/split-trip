import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String ownerId;
  final String name;
  final String baseCurrency; // e.g., "INR"
  final DateTime createdAt;
  final List<String> participantIds;

  const Trip({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.baseCurrency,
    required this.createdAt,
    required this.participantIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'baseCurrency': baseCurrency,
      'createdAt': Timestamp.fromDate(createdAt),
      'participantIds': participantIds,
    };
  }

  factory Trip.fromMap(String id, Map<String, dynamic> map) {
    return Trip(
      id: id,
      ownerId: map['ownerId'] as String,
      name: map['name'] as String,
      baseCurrency: map['baseCurrency'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      participantIds: List<String>.from(map['participantIds'] as List),
    );
  }

  Trip copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? baseCurrency,
    DateTime? createdAt,
    List<String>? participantIds,
  }) {
    return Trip(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      createdAt: createdAt ?? this.createdAt,
      participantIds: participantIds ?? this.participantIds,
    );
  }
}
