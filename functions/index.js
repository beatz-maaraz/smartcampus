const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// Triggers when a new user document is created in the 'users' collection.
exports.assignRoleOnCreate = onDocumentCreated("users/{uid}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const data = snapshot.data();
  const role = data.role; // 'admin', 'faculty', or 'student'
  const uid = event.params.uid;

  if (role) {
    try {
      await admin.auth().setCustomUserClaims(uid, { role: role });
      console.log(`Successfully assigned role ${role} to user ${uid}`);
    } catch (error) {
      console.error(`Error assigning role to user ${uid}:`, error);
    }
  }
});
