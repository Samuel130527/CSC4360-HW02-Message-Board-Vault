
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveUserRecord({
    required User user,
    required String firstName,
    required String lastName,
  }) async {
    final ref = _db.collection('users').doc(user.uid);

    await ref.set({
      'uid': user.uid,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'role': 'member',
      'registrationDateTime': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProfile(
    String uid,
  ) {
    return _db.collection('users').doc(uid).snapshots();
  }
}
