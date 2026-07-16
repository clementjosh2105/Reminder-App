import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/friendship.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/social_provider.dart';
import 'auth_screen.dart';
import 'chat_screen.dart';
import 'challenges_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  bool _didSyncProfile = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (_didSyncProfile) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      _didSyncProfile = true;
      final settings = ref.read(settingsProvider);
      await ref
          .read(socialServiceProvider)
          .syncCurrentUserPublicProfile(
            shareActivityWithFriends: settings.shareActivityWithFriends,
            socialNotifications: settings.socialNotifications,
            friendRequestMode: settings.friendRequestMode,
          );
    });
  }

  Future<void> _addFriend(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Friend'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Friend email',
            prefixIcon: Icon(Icons.email_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty) return;

    try {
      await ref.read(socialServiceProvider).sendFriendRequestByEmail(email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    Friendship friendship,
    bool accept,
  ) async {
    try {
      await ref
          .read(socialServiceProvider)
          .respondToFriendRequest(friendshipId: friendship.id, accept: accept);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _createChallenge(Friendship friendship) async {
    final titleController = TextEditingController(text: '7-day streak');
    int durationDays = 7;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Start Challenge'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Challenge name'),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 3, label: Text('3d')),
                  ButtonSegment(value: 7, label: Text('7d')),
                  ButtonSegment(value: 14, label: Text('14d')),
                ],
                selected: {durationDays},
                onSelectionChanged: (value) {
                  setDialogState(() => durationDays = value.first);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
    final title = titleController.text.trim();
    titleController.dispose();
    if (confirmed != true) return;

    try {
      await ref
          .read(socialServiceProvider)
          .createChallenge(
            friendship: friendship,
            title: title,
            durationDays: durationDays,
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Challenge sent.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _blockOrReport(Friendship friendship, bool report) async {
    try {
      if (report) {
        await ref
            .read(socialServiceProvider)
            .reportUser(
              friendship: friendship,
              reason: 'Reported from Friends screen',
            );
      } else {
        await ref.read(socialServiceProvider).blockUser(friendship);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(report ? 'Report sent.' : 'User blocked.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _removeFriend(Friendship friendship) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text(
          'This removes ${friendship.otherName(FirebaseAuth.instance.currentUser?.uid ?? '')} from your friends list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(socialServiceProvider).removeFriend(friendship);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Friend removed.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _showProfile(Friendship friendship) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final otherUid = friendship.otherUid(currentUid);
    final stats = await ref
        .read(socialServiceProvider)
        .getFriendProfileStats(otherUid)
        .catchError((_) => null);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: friendship.otherPhotoUrl(currentUid).isNotEmpty
                  ? NetworkImage(friendship.otherPhotoUrl(currentUid))
                  : null,
              child: friendship.otherPhotoUrl(currentUid).isEmpty
                  ? const Icon(Icons.person_rounded)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(friendship.otherName(currentUid))),
          ],
        ),
        content: stats == null
            ? const Text('No public streak stats for this week yet.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProfileStat(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Current streak',
                    value: '${stats.currentStreak}',
                  ),
                  _ProfileStat(
                    icon: Icons.check_circle_rounded,
                    label: 'Completed today',
                    value: '${stats.completedToday}',
                  ),
                  _ProfileStat(
                    icon: Icons.calendar_view_week_rounded,
                    label: 'Weekly completions',
                    value: '${stats.weeklyCompletions}',
                  ),
                  _ProfileStat(
                    icon: Icons.leaderboard_rounded,
                    label: 'Weekly score',
                    value: '${stats.score}',
                  ),
                  if (stats.updatedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Updated ${DateFormat.MMMd().add_jm().format(stats.updatedAt!)}',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final friendshipsState = ref.watch(myFriendshipsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            tooltip: 'Challenges',
            icon: const Icon(Icons.flag_rounded),
            onPressed: authState.value == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChallengesScreen(),
                      ),
                    );
                  },
          ),
          IconButton(
            tooltip: 'Add friend',
            icon: const Icon(Icons.person_add_rounded),
            onPressed: authState.value == null
                ? null
                : () => _addFriend(context, ref),
          ),
        ],
      ),
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (user) {
          if (user == null) return _SignInPrompt();

          return friendshipsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(error.toString())),
            data: (friendships) {
              final incoming = friendships
                  .where(
                    (item) =>
                        item.status == 'pending' &&
                        item.recipientUid == currentUid,
                  )
                  .toList();
              final sent = friendships
                  .where(
                    (item) =>
                        item.status == 'pending' &&
                        item.requesterUid == currentUid,
                  )
                  .toList();
              final friends = friendships
                  .where((item) => item.status == 'accepted')
                  .toList();

              if (friendships.isEmpty) {
                return _EmptyFriends(onAdd: () => _addFriend(context, ref));
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (incoming.isNotEmpty) ...[
                    const _SectionTitle('Requests'),
                    for (final item in incoming)
                      _FriendTile(
                        friendship: item,
                        currentUid: currentUid,
                        subtitle: 'Wants to be your friend',
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Decline',
                              onPressed: () =>
                                  _respond(context, ref, item, false),
                              icon: const Icon(Icons.close_rounded),
                            ),
                            IconButton.filled(
                              tooltip: 'Accept',
                              onPressed: () =>
                                  _respond(context, ref, item, true),
                              icon: const Icon(Icons.check_rounded),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                  ],
                  if (friends.isNotEmpty) ...[
                    const _SectionTitle('Friends'),
                    for (final item in friends)
                      _FriendTile(
                        friendship: item,
                        currentUid: currentUid,
                        subtitle: 'Tap to message',
                        trailing: const Icon(Icons.chat_bubble_rounded),
                        menu: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'profile') _showProfile(item);
                            if (value == 'challenge') _createChallenge(item);
                            if (value == 'report') _blockOrReport(item, true);
                            if (value == 'block') _blockOrReport(item, false);
                            if (value == 'remove') _removeFriend(item);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'profile',
                              child: Text('View profile'),
                            ),
                            PopupMenuItem(
                              value: 'challenge',
                              child: Text('Start challenge'),
                            ),
                            PopupMenuItem(
                              value: 'remove',
                              child: Text('Remove friend'),
                            ),
                            PopupMenuItem(
                              value: 'report',
                              child: Text('Report'),
                            ),
                            PopupMenuItem(value: 'block', child: Text('Block')),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(friendship: item),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 18),
                  ],
                  if (sent.isNotEmpty) ...[
                    const _SectionTitle('Sent'),
                    for (final item in sent)
                      _FriendTile(
                        friendship: item,
                        currentUid: currentUid,
                        subtitle: 'Request pending',
                        trailing: const Icon(Icons.hourglass_top_rounded),
                      ),
                  ],
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: authState.value == null
          ? null
          : FloatingActionButton(
              onPressed: () => _addFriend(context, ref),
              child: const Icon(Icons.person_add_rounded),
            ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Sign in to add friends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.login_rounded),
              label: const Text('Sign In'),
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFriends extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyFriends({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline_rounded, size: 56),
            const SizedBox(height: 16),
            const Text(
              'No friends yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a friend by email to send requests and messages.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Friend'),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final Friendship friendship;
  final String currentUid;
  final String subtitle;
  final Widget trailing;
  final Widget? menu;
  final VoidCallback? onTap;

  const _FriendTile({
    required this.friendship,
    required this.currentUid,
    required this.subtitle,
    required this.trailing,
    this.menu,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = friendship.otherPhotoUrl(currentUid);
    return Card(
      elevation: 0,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: photoUrl.isEmpty ? const Icon(Icons.person_rounded) : null,
        ),
        title: Text(friendship.otherName(currentUid)),
        subtitle: Text(subtitle),
        trailing: menu == null
            ? trailing
            : Row(mainAxisSize: MainAxisSize.min, children: [trailing, menu!]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}
