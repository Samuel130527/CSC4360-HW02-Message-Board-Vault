
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BoardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int currentSchemaVersion = 2;

  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection('messages');

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in.');
    }
    return user.uid;
  }

  String newSubmissionId() {
    return _messages.doc().id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages() {
    return _messages
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Create a version 2 message.
  // Reusing the submission ID prevents duplicate creation.
  Future<void> createMessage(
    String text, {
    required String submissionId,
  }) async {
    final content = text.trim();

    if (content.isEmpty || content.length > 1000) {
      throw ArgumentError(
        'Message must contain 1 to 1000 characters.',
      );
    }

    final uid = _uid;
    final ref = _messages.doc(submissionId);

    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);

      if (existing.exists) {
        final data = existing.data();

        if (data?['authorUid'] != uid ||
            data?['text'] != content) {
          throw StateError(
            'Submission ID already belongs to another message.',
          );
        }

        return;
      }

      transaction.set(ref, {
        'schemaVersion': currentSchemaVersion,
        'authorUid': uid,
        'text': content,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateMessage(
    String messageId,
    String text,
  ) async {
    final content = text.trim();

    if (content.isEmpty || content.length > 1000) {
      throw ArgumentError(
        'Message must contain 1 to 1000 characters.',
      );
    }

    await _messages.doc(messageId).update({
      'text': content,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String messageId) async {
    await _messages.doc(messageId).delete();
  }

  // Convert one existing v1 message to v2.
  // Only the original author may migrate it.
  Future<void> migrateMessageToV2(String messageId) async {
    final uid = _uid;
    final ref = _messages.doc(messageId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);

      if (!snapshot.exists) {
        throw StateError('Message does not exist.');
      }

      final data = snapshot.data()!;

      if (data['authorUid'] != uid) {
        throw StateError(
          'Only the author can migrate this message.',
        );
      }

      final version = data['schemaVersion'];

      if (version == currentSchemaVersion) {
        return;
      }

      if (version != 1) {
        throw StateError(
          'Unsupported schema version: $version',
        );
      }

      transaction.update(ref, {
        'schemaVersion': currentSchemaVersion,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
