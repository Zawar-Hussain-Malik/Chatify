const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.syncPresence = functions.database
  .ref('/status/{userId}')
  .onUpdate((change, context) => {
    const after = change.after.val();
    const userId = context.params.userId;

    if (after === null) return null;

    return admin.firestore().collection('users').doc(userId).update({
      isOnline: after,
      lastSeen: admin.firestore.FieldValue.serverTimestamp(),
    });
  });