const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

initializeApp();

const db = getFirestore();

/**
 * Sends a high-priority social notification to all active devices for a user.
 * @param {string} uid Firebase Auth UID to notify.
 * @param {{title: string, body: string}} notification Notification payload.
 * @param {Object<string, string>} data Custom FCM data payload.
 * @return {Promise<void>} Resolves after all token sends complete.
 */
async function sendToUid(uid, notification, data = {}) {
  if (!uid) return;
  const tokens = await db
      .collection("device_tokens")
      .where("uid", "==", uid)
      .where("socialNotifications", "==", true)
      .limit(10)
      .get();

  if (tokens.empty) return;

  await Promise.all(tokens.docs.map(async (doc) => {
    const token = doc.data().token;
    if (!token) return;
    try {
      await getMessaging().send({
        token,
        notification,
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
            sound: "default",
            visibility: "public",
          },
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          ...data,
        },
      });
    } catch (error) {
      console.error("FCM send failed", error);
      if (String(error.code || "").includes("registration-token")) {
        await doc.ref.delete();
      }
    }
  }));
}

exports.sendWelcomeNotification = onDocumentCreated(
    "device_tokens/{tokenId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const data = snapshot.data();
      if (!data.token) return;

      await getMessaging().send({
        token: data.token,
        notification: {
          title: "StreakMind Connected",
          body: "Social notifications are ready.",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
            sound: "default",
            visibility: "public",
          },
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: "welcome",
        },
      });
    },
);

exports.notifyFriendRequest = onDocumentCreated(
    "friendships/{friendshipId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;
      const data = snapshot.data();
      if (data.status !== "pending") return;
      await sendToUid(
          data.recipientUid,
          {
            title: "New friend request",
            body: `${data.requesterName || "Someone"} added you on StreakMind`,
          },
          {type: "friend_request", friendshipId: event.params.friendshipId},
      );
    },
);

exports.notifyFriendAccepted = onDocumentUpdated(
    "friendships/{friendshipId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      if (before.status === after.status || after.status !== "accepted") return;
      await sendToUid(
          after.requesterUid,
          {
            title: "Friend request accepted",
            body: `${after.recipientName || "Your friend"} accepted you`,
          },
          {type: "friend_accepted", friendshipId: event.params.friendshipId},
      );
    },
);

exports.onMessageCreated = onDocumentCreated(
    "friendships/{friendshipId}/messages/{messageId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;
      const message = snapshot.data();
      const friendshipRef = db
          .collection("friendships")
          .doc(event.params.friendshipId);
      const friendshipDoc = await friendshipRef.get();
      if (!friendshipDoc.exists) return;
      const friendship = friendshipDoc.data();
      if (friendship.status !== "accepted") return;

      const recipients = (friendship.participantUids || [])
          .filter((uid) => uid !== message.senderUid);
      await friendshipRef.update({
        lastMessageText: message.text,
        lastMessageAt: FieldValue.serverTimestamp(),
        lastMessageSenderUid: message.senderUid,
        hiddenFor: FieldValue.arrayRemove(...friendship.participantUids),
        unreadBy: FieldValue.arrayUnion(...recipients),
        updatedAt: FieldValue.serverTimestamp(),
      });

      await Promise.all(recipients.map((uid) => sendToUid(
          uid,
          {
            title: "New message",
            body: message.text.length > 80 ?
              `${message.text.substring(0, 77)}...` :
              message.text,
          },
          {
            type: "message",
            friendshipId: event.params.friendshipId,
            messageId: event.params.messageId,
          },
      )));
    },
);

exports.notifyChallengeCreated = onDocumentCreated(
    "challenges/{challengeId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;
      const data = snapshot.data();
      if (data.status !== "pending") return;
      await sendToUid(
          data.recipientUid,
          {
            title: "New challenge",
            body: data.title || "You were invited to a challenge",
          },
          {type: "challenge", challengeId: event.params.challengeId},
      );
    },
);

exports.notifyChallengeUpdated = onDocumentUpdated(
    "challenges/{challengeId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      if (before.status === after.status) return;

      if (after.status === "active") {
        await sendToUid(
            after.creatorUid,
            {
              title: "Challenge accepted",
              body: after.title || "Your challenge is now active",
            },
            {type: "challenge_accepted", challengeId: event.params.challengeId},
        );
      }

      if (after.status === "declined") {
        await sendToUid(
            after.creatorUid,
            {
              title: "Challenge declined",
              body: after.title || "Your challenge was declined",
            },
            {type: "challenge_declined", challengeId: event.params.challengeId},
        );
      }
    },
);
