import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/focus_group.dart';

class GroupService {
  GroupService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('groups');

  Stream<List<FocusGroup>> watchMyGroups() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _groups
        .where('memberUids', arrayContains: user.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(FocusGroup.fromDoc).toList());
  }

  Future<void> createGroup(String name) async {
    final user = _requireUser();
    final code = _createInviteCode();
    await _groups.doc(code).set({
      'name': name.trim(),
      'code': code,
      'ownerUid': user.uid,
      'ownerName': _displayName(user),
      'memberUids': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> joinGroup(String code) async {
    final user = _requireUser();
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw ArgumentError('Enter an invite code.');
    }

    await _groups.doc(normalizedCode).update({
      'memberUids': FieldValue.arrayUnion([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to use groups.');
    }
    return user;
  }

  String _displayName(User user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'StreakMind user';
  }

  String _createInviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
