
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'board_service.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final BoardService _board = BoardService();
  final TextEditingController _controller = TextEditingController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;

  bool _sending = false;

  String? _pendingSubmissionId;
  String? _pendingSubmissionText;

  @override
  void initState() {
    super.initState();
    _messagesStream = _board.watchMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Operation failed: $error'),
      ),
    );
  }

  // CREATE MESSAGE WITH DUPLICATE-SUBMISSION PROTECTION
  Future<void> _sendMessage() async {
    if (_sending) return;

    final content = _controller.text.trim();

    if (content.isEmpty || content.length > 1000) {
      _showError('Message must contain 1 to 1000 characters.');
      return;
    }

    // Reuse the same document ID when retrying
    // the same pending message.
    if (_pendingSubmissionId == null ||
        _pendingSubmissionText != content) {
      _pendingSubmissionId = _board.newSubmissionId();
      _pendingSubmissionText = content;
    }

    final submissionId = _pendingSubmissionId!;

    setState(() => _sending = true);

    try {
      await _board.createMessage(
        content,
        submissionId: submissionId,
      );

      if (!mounted) return;

      _controller.clear();

      _pendingSubmissionId = null;
      _pendingSubmissionText = null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message sent successfully.'),
        ),
      );
    } catch (e) {
      // Retain the ID for a retry.
      _showError(e);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  // EDIT MESSAGE
  Future<void> _editMessage(
    String messageId,
    String originalText,
  ) async {
    final editController = TextEditingController(
      text: originalText,
    );

    try {
      final updated = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Edit Message'),
            content: TextField(
              controller: editController,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    editController.text.trim(),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (updated == null || !mounted) {
        return;
      }

      if (updated.isEmpty || updated.length > 1000) {
        _showError('Message must contain 1 to 1000 characters.');
        return;
      }

      try {
        await _board.updateMessage(messageId, updated);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message updated successfully.'),
          ),
        );
      } catch (e) {
        _showError(e);
      }
    } finally {
      editController.dispose();
    }
  }

  // DELETE MESSAGE
  Future<void> _deleteMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Message?'),
          content: const Text(
            'This message will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _board.deleteMessage(messageId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message deleted successfully.'),
        ),
      );
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Board Vault'),
        actions: [
          // LOGOUT BUTTON
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
              } catch (e) {
                _showError(e);
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          // REAL-TIME MESSAGE FEED
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading messages: ${snapshot.error}',
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Post the first one!',
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data();

                    final text =
                        data['text'] as String? ?? '';

                    final authorUid =
                        data['authorUid'] as String? ?? '';

                    final isOwner = authorUid == uid;

                    return Card(
                      child: ListTile(
                        title: Text(text),
                        subtitle: Text(
                          isOwner
                              ? 'You'
                              : 'User ${authorUid.length > 8 ? authorUid.substring(0, 8) : authorUid}',
                        ),
                        trailing: isOwner
                            ? PopupMenuButton<String>(
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _editMessage(
                                      doc.id,
                                      text,
                                    );
                                  } else if (action ==
                                      'delete') {
                                    _deleteMessage(
                                      doc.id,
                                    );
                                  }
                                },
                                itemBuilder:
                                    (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // MESSAGE INPUT
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 1000,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Write a message...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _sendMessage,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
