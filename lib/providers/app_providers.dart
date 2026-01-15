import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/trip.dart';
import '../models/participant.dart';
import '../models/expense.dart';
import '../repositories/trip_repo.dart';
import '../repositories/participant_repo.dart';
import '../repositories/expense_repo.dart';
import '../services/currency_service.dart';
import 'auth_providers.dart';

/// Firestore instance provider
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Firebase Storage instance provider
final storageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

/// HTTP client provider
final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

/// Currency service provider
final currencyServiceProvider = Provider<CurrencyService>((ref) {
  final client = ref.watch(httpClientProvider);
  return CurrencyService(client);
});

/// Trip repository provider
final tripRepoProvider = Provider<TripRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return TripRepository(firestore);
});

/// Participant repository provider
final participantRepoProvider = Provider<ParticipantRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ParticipantRepository(firestore);
});

/// Expense repository provider
final expenseRepoProvider = Provider<ExpenseRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final storage = ref.watch(storageProvider);
  return ExpenseRepository(firestore, storage);
});

/// Stream of user's trips
final userTripsProvider = StreamProvider<List<Trip>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final repo = ref.watch(tripRepoProvider);
  return repo.watchTrips(user.uid);
});

/// Single trip provider
final tripProvider = StreamProvider.family<Trip?, String>((ref, tripId) {
  final repo = ref.watch(tripRepoProvider);
  return repo.getTrip(tripId).asStream();
});

/// Participants for a trip
final tripParticipantsProvider = 
    StreamProvider.family<List<Participant>, String>((ref, tripId) {
  final repo = ref.watch(participantRepoProvider);
  return repo.watchParticipants(tripId);
});

/// Expenses for a trip
final tripExpensesProvider = 
    StreamProvider.family<List<Expense>, String>((ref, tripId) {
  final repo = ref.watch(expenseRepoProvider);
  return repo.watchExpenses(tripId);
});
