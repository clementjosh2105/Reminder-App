import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/challenge.dart';
import '../providers/social_provider.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    Challenge challenge,
    bool accept,
  ) async {
    try {
      await ref
          .read(socialServiceProvider)
          .respondToChallenge(challengeId: challenge.id, accept: accept);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _complete(
    BuildContext context,
    WidgetRef ref,
    Challenge challenge,
  ) async {
    try {
      await ref.read(socialServiceProvider).completeChallenge(challenge.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final state = ref.watch(myChallengesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Challenges')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (challenges) {
          if (challenges.isEmpty) {
            return const Center(child: Text('No challenges yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: challenges.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final challenge = challenges[index];
              final isRecipient = challenge.recipientUid == currentUid;
              final completed = challenge.completedUids.contains(currentUid);
              return Card(
                elevation: 0,
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.flag_rounded)),
                  title: Text(challenge.title),
                  subtitle: Text(
                    '${challenge.durationDays} days - ${challenge.status}',
                  ),
                  trailing: switch (challenge.status) {
                    'pending' when isRecipient => Wrap(
                      spacing: 6,
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Decline',
                          onPressed: () =>
                              _respond(context, ref, challenge, false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                        IconButton.filled(
                          tooltip: 'Accept',
                          onPressed: () =>
                              _respond(context, ref, challenge, true),
                          icon: const Icon(Icons.check_rounded),
                        ),
                      ],
                    ),
                    'active' when !completed => IconButton.filled(
                      tooltip: 'Mark done',
                      onPressed: () => _complete(context, ref, challenge),
                      icon: const Icon(Icons.done_all_rounded),
                    ),
                    _ => const Icon(Icons.chevron_right_rounded),
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
