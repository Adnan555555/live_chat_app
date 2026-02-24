// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// ─── Trigger: When a notification doc is created ──────────────────────────────
exports.sendChatNotification = functions.firestore
  .document('notifications/{notifId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data || data.sent) return null;

    const { to, title, body, chatId } = data;
    if (!to) return null;

    const message = {
      token: to,
      notification: { title, body },
      data: { chatId: chatId || '', click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      android: {
        priority: 'high',
        notification: { channelId: 'wavechat_messages', priority: 'high', defaultSound: true },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    };

    try {
      await admin.messaging().send(message);
      await snap.ref.update({ sent: true, sentAt: admin.firestore.FieldValue.serverTimestamp() });
      console.log(`Notification sent to ${to}`);
    } catch (err) {
      console.error('FCM error:', err);
      await snap.ref.update({ error: err.message });
    }
    return null;
  });

// ─── Cleanup: Delete notifications older than 7 days ─────────────────────────
exports.cleanupOldNotifications = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const old = await admin.firestore()
      .collection('notifications')
      .where('timestamp', '<', cutoff)
      .get();
    const batch = admin.firestore().batch();
    old.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    console.log(`Deleted ${old.size} old notifications`);
    return null;
  });
