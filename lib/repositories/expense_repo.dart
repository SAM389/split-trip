import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/expense.dart';

class ExpenseRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  ExpenseRepository(this._firestore, this._storage);

  /// Watch expenses for a trip
  Stream<List<Expense>> watchExpenses(String tripId) {
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Expense.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  /// Get a single expense
  Future<Expense?> getExpense(String tripId, String expenseId) async {
    final doc = await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .doc(expenseId)
        .get();
    
    if (!doc.exists) return null;
    return Expense.fromMap(doc.id, doc.data()!);
  }

  /// Add expense (with optional receipt upload)
  Future<String> addExpense(
    Expense expense, {
    File? receiptFile,
  }) async {
    String? receiptUrl;

    // Upload receipt if provided
    if (receiptFile != null) {
      receiptUrl = await _uploadReceipt(expense.tripId, receiptFile);
    }

    // Create expense with receipt URL
    final expenseWithReceipt = expense.copyWith(receiptUrl: receiptUrl);

    final docRef = await _firestore
        .collection('trips')
        .doc(expense.tripId)
        .collection('expenses')
        .add(expenseWithReceipt.toMap());

    return docRef.id;
  }

  /// Update expense
  Future<void> updateExpense(
    Expense expense, {
    File? receiptFile,
  }) async {
    String? receiptUrl = expense.receiptUrl;

    // Upload new receipt if provided
    if (receiptFile != null) {
      receiptUrl = await _uploadReceipt(expense.tripId, receiptFile);
    }

    final expenseWithReceipt = expense.copyWith(receiptUrl: receiptUrl);

    await _firestore
        .collection('trips')
        .doc(expense.tripId)
        .collection('expenses')
        .doc(expense.id)
        .update(expenseWithReceipt.toMap());
  }

  /// Delete expense
  Future<void> deleteExpense(String tripId, String expenseId) async {
    // Get expense to delete receipt if exists
    final expense = await getExpense(tripId, expenseId);
    if (expense?.receiptUrl != null) {
      try {
        final ref = _storage.refFromURL(expense!.receiptUrl!);
        await ref.delete();
      } catch (e) {
        print('Failed to delete receipt: $e');
      }
    }

    await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }

  /// Upload receipt to Firebase Storage
  Future<String> _uploadReceipt(String tripId, File file) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'receipt_$timestamp${_getFileExtension(file.path)}';
    final ref = _storage.ref().child('receipts/$tripId/$fileName');

    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    return downloadUrl;
  }

  String _getFileExtension(String path) {
    final parts = path.split('.');
    return parts.length > 1 ? '.${parts.last}' : '';
  }
}
