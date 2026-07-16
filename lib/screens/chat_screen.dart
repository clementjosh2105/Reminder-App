import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/friendship.dart';
import '../providers/social_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Friendship friendship;

  const ChatScreen({super.key, required this.friendship});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(socialServiceProvider).markThreadRead(widget.friendship.id);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _blockOrReport(bool report) async {
    try {
      if (report) {
        await ref
            .read(socialServiceProvider)
            .reportUser(
              friendship: widget.friendship,
              reason: 'Reported from chat',
            );
      } else {
        await ref.read(socialServiceProvider).blockUser(widget.friendship);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(report ? 'Report sent.' : 'User blocked.')),
        );
        if (!report) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _hideConversation() async {
    try {
      await ref
          .read(socialServiceProvider)
          .hideConversation(widget.friendship.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await ref
          .read(socialServiceProvider)
          .sendMessage(friendshipId: widget.friendship.id, text: text);
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final otherName = widget.friendship.otherName(currentUid);
    final otherUid = widget.friendship.otherUid(currentUid);
    final messages = ref.watch(
      StreamProvider.autoDispose(
        (ref) => ref
            .watch(socialServiceProvider)
            .watchMessages(widget.friendship.id),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(otherName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'hide') _hideConversation();
              if (value == 'report') _blockOrReport(true);
              if (value == 'block') _blockOrReport(false);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'hide', child: Text('Hide chat')),
              PopupMenuItem(value: 'report', child: Text('Report')),
              PopupMenuItem(value: 'block', child: Text('Block')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              'Messages are private to accepted friends. They are not end-to-end encrypted.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ),
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }
                Future.microtask(() {
                  ref
                      .read(socialServiceProvider)
                      .markThreadRead(widget.friendship.id)
                      .catchError((_) {});
                });
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final message = items[index];
                    final isMine = message.senderUid == currentUid;
                    final isLatestMine =
                        isMine &&
                        index ==
                            items.lastIndexWhere(
                              (item) => item.senderUid == currentUid,
                            );
                    final isSeen = message.readBy.contains(otherUid);
                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Column(
                          crossAxisAlignment: isMine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                message.text,
                                style: TextStyle(
                                  color: isMine
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 6,
                                right: 6,
                                bottom: 8,
                              ),
                              child: Text(
                                [
                                  if (message.sentAt != null)
                                    DateFormat.jm().format(message.sentAt!),
                                  if (isLatestMine) isSeen ? 'Seen' : 'Sent',
                                ].join(' - '),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _send,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
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
