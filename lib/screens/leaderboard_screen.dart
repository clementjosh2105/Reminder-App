import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/leaderboard_entry.dart';
import '../providers/auth_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/leaderboard_provider.dart';
import 'auth_screen.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Users'),
        actions: [
          IconButton(
            tooltip: 'Sync score',
            icon: const Icon(Icons.sync_rounded),
            onPressed: () async {
              await ref
                  .read(leaderboardServiceProvider)
                  .syncCurrentUserScore(ref.read(habitNotifierProvider));
            },
          ),
        ],
      ),
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _AuthRequiredState(message: error.toString()),
        data: (user) {
          if (user == null) {
            return const _AuthRequiredState();
          }

          final leaderboard = ref.watch(leaderboardProvider);
          return leaderboard.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _LeaderboardError(message: error.toString()),
            data: (entries) {
              if (entries.isEmpty) {
                return const _EmptyLeaderboard();
              }
              return RefreshIndicator(
                onRefresh: () async {
                  await ref
                      .read(leaderboardServiceProvider)
                      .syncCurrentUserScore(ref.read(habitNotifierProvider));
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _LeaderboardTile(
                      rank: index + 1,
                      entry: entries[index],
                      isCurrentUser: entries[index].uid == user.uid,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool isCurrentUser;

  const _LeaderboardTile({
    required this.rank,
    required this.entry,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rankColor = switch (rank) {
      1 => Colors.amber.shade700,
      2 => Colors.blueGrey.shade400,
      3 => Colors.brown.shade400,
      _ => theme.colorScheme.primary,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCurrentUser
              ? theme.colorScheme.primary.withValues(alpha: 0.35)
              : theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rankColor.withValues(alpha: 0.12),
          foregroundColor: rankColor,
          backgroundImage: entry.photoUrl.isNotEmpty
              ? NetworkImage(entry.photoUrl)
              : null,
          child: entry.photoUrl.isEmpty
              ? Text(
                  rank.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Text(
          entry.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${entry.weeklyCompletions} completions this week - ${entry.currentStreak} streak',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              entry.score.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              'pts',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthRequiredState extends StatelessWidget {
  final String? message;

  const _AuthRequiredState({this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_rounded,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sign in to join the leaderboard',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Your weekly score syncs after you log habits.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.login_rounded),
              label: const Text('Sign in'),
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

class _LeaderboardError extends StatelessWidget {
  final String message;

  const _LeaderboardError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not load leaderboard.\n$message',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  const _EmptyLeaderboard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No scores yet this week. Log a habit, then sync your score.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
