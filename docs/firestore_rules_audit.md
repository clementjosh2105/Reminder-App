# Firestore Rules Audit

## Collections And Queries

The app uses these Firestore paths:

- `users_private/{uid}`: owner-only private profile metadata.
- `users_public/{uid}`: authenticated-readable public display name/avatar only.
- `user_email_lookup/{emailHash}`: authenticated-readable SHA-256 email lookup to find a UID without storing raw email publicly.
- `leaderboards/{weekKey}/entries/{uid}`: public leaderboard entry for a signed-in user's weekly score.
- `groups/{inviteCode}`: invite-code focus group metadata with owner UID, owner display name, member UIDs, and timestamps.
- `friendships/{pairId}`: friend request/friendship metadata visible only to the two participants.
- `friendships/{pairId}/messages/{messageId}`: one-to-one messages visible only inside accepted friendships.
- `activities/{activityId}`: coarse friend-visible habit activity with no habit notes or private details.
- `blocks/{ownerUid_blockedUid}`: owner-only block records.
- `reports/{reportId}`: write-only abuse reports for backend/admin review.
- `challenges/{challengeId}`: two-person challenge invitations and completion state.
- `device_tokens/{fcmToken}`: owner-scoped FCM token records used by Cloud Functions.

Queries:

- `leaderboards/{weekKey}/entries.orderBy('score', descending: true).limit(50)`.
- `groups.where('memberUids', arrayContains: uid).orderBy('updatedAt', descending: true)`.
- `friendships.where('participantUids', arrayContains: uid).orderBy('updatedAt', descending: true)`.
- `friendships/{pairId}/messages.orderBy('sentAt').limit(100)`.
- `activities.where('visibleToUids', arrayContains: uid).orderBy('createdAt', descending: true).limit(40)`.
- `challenges.where('participantUids', arrayContains: uid).orderBy('updatedAt', descending: true).limit(40)`.

## Security Model

- Private user profile documents include email and are readable/writable only by the owning Firebase Auth UID.
- Leaderboard entries intentionally contain only public fields: UID, display name, photo URL, score, weekly completions, today completions, streak, week key, and update timestamp.
- Leaderboard reads require authentication.
- Users can create/update only their own leaderboard entry.
- Users cannot delete profile or leaderboard documents from the client.
- Group reads require authentication. Group documents do not store email addresses or habit history.
- Users can create groups only for themselves. Existing group updates are limited to adding the signed-in user as a member and refreshing `updatedAt`.
- Users cannot delete group documents from the client.
- Public profile docs and email lookup docs are authenticated-readable and intentionally contain no raw email addresses.
- Friendships are readable only by participants. Requests can be created by the requester and accepted/declined only by the recipient.
- Messages can be created/read only when the parent friendship exists, includes the current user, and has `status == accepted`.
- Blocks and reports can be created by signed-in users. Reports are not client-readable.
- Challenge reads are participant-only. Challenge create/respond/complete updates preserve immutable participant and title fields.
- Device token documents must be owned by the signed-in UID and are not client-readable.
- Cloud Functions send push notifications for friend requests, accepted requests, messages, and challenges.
- Rules validate field names, required fields, basic types, string lengths, numeric ranges, immutable UID/week fields, and recent timestamps.

## Devil's Advocate Checks

- Public list exploit: unauthenticated reads are denied for all collections.
- Unauthorized read/write: non-owners cannot read private profiles or write another user's leaderboard entry.
- Update bypass: both create and update call the same validators.
- Ownership hijacking: `uid` must match both path UID and `request.auth.uid`.
- Immutable field modification: `uid` and leaderboard `weekKey` cannot change on update.
- Type juggling: validators require expected field types.
- Schema pollution: rules use `keys().hasOnly(...)`.
- Resource exhaustion: strings have explicit length limits.
- Required field omission: rules require all fields used by the app.
- Mixed content leak: email exists only in `users_private`, never in leaderboard entries.
- Hashed email lookup leak: raw email is not stored in public docs, but a user who already knows an email can test whether its hash exists.
- Query mismatch: leaderboard query is allowed because signed-in users can read entries in a week subcollection ordered by score.
- Group join abuse: updates preserve immutable owner/code fields, require all previous members to remain present, cap groups at 50 members, and allow only one added UID per write.
- Message access bypass: message reads/writes check the parent friendship and require accepted status.
- Block/report abuse: block docs are owner-only; reports are write-only to clients.
- Challenge escalation: updates preserve participants, creator, recipient, title, duration, and createdAt.
- Token hijacking: token writes require `uid == request.auth.uid` and client reads are denied.

These are prototype rules for the current app shape. Client-written leaderboard scores can still be manipulated by a modified client; a production leaderboard should move score computation to trusted server code such as Firebase Functions. Production social features should continue with rate limits, admin moderation tooling, automated abuse detection, and privacy review before a large public launch.
