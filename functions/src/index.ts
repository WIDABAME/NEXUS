import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

exports.sendNotificationOnNewNote = functions.firestore
  .document("notes/{noteId}")
  .onCreate(async (snapshot) => {
    const note = snapshot.data();

    if (!note) {
      console.log("No data associated with the event");
      return;
    }

    const payload = {
      notification: {
        title: "New Note Added!",
        body: `A new note titled '${note.title}' was added.`,
      },
      topic: "allUsers",
    };

    try {
      await admin.messaging().send(payload);
      console.log("Notification sent successfully");
    } catch (error) {
      console.error("Error sending notification:", error);
    }
  });
