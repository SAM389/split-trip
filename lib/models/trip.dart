import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a group trip for expense tracking and splitting.
///
/// A trip is the main container for expenses and participants. Each trip has an owner,
/// a base currency for calculations, and a list of participant IDs who share expenses.
///
/// All expense calculations within a trip are normalized to the [baseCurrency] for
/// accurate settlement calculations across multiple currencies.
class Trip {
  /// Unique identifier for the trip
  final String id;
  
  /// User ID of the trip creator/owner
  final String ownerId;
  
  /// Display name of the trip (e.g., "Bangkok Weekend")
  final String name;
  
  /// Base currency code for expense calculations (e.g., "INR", "USD")
  final String baseCurrency;
  
  /// Timestamp when the trip was created
  final DateTime createdAt;
  
  /// List of participant user IDs who share expenses in this trip
  final List<String> participantIds;

  const Trip({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.baseCurrency,
    required this.createdAt,
    required this.participantIds,
  });

  /// Converts the trip object to a Firestore-compatible map.
  ///
  /// Excludes the [id] field as it's stored as the document ID in Firestore.
  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'baseCurrency': baseCurrency,
      'createdAt': Timestamp.fromDate(createdAt),
      'participantIds': participantIds,
    };
  }

  /// Creates a trip instance from a Firestore document.
  ///
  /// [id] is the Firestore document ID.
  /// [map] contains the document data.
  factory Trip.fromMap(String id, Map<String, dynamic> map) {
    return Trip(
      id: id,
      ownerId: map['ownerId'] as String,
      name: map['name'] as String,
      baseCurrency: map['baseCurrency'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
  /// Creates a copy of this trip with the given fields replaced with new values.
  ///
  /// Used for immutable updates in state management.
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
