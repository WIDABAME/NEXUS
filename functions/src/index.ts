
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

// --- Existing Notification Functions ---

exports.sendNotificationOnNewNote = functions.firestore
  .document("notes/{noteId}")
  .onCreate(async (snapshot) => {
    // ... (code for sending notification on new note)
  });

exports.sendNotificationOnUpdateNote = functions.firestore
  .document("notes/{noteId}")
  .onUpdate(async (change) => {
    // ... (code for sending notification on note update)
  });

exports.sendNotificationOnDeleteNote = functions.firestore
  .document("notes/{noteId}")
  .onDelete(async (snapshot) => {
    // ... (code for sending notification on note delete)
  });

// --- New Connections Logic Function (with exports for testing) ---

export const stopWords = new Set([
    'a', 'al', 'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas',
    'y', 'e', 'o', 'u', 'de', 'del', 'en', 'con', 'por', 'para', 'sin',
    'sobre', 'tras', 'que', 'como', 'cuando', 'donde', 'quien', 'cual',
    'mi', 'tu', 'su', 'nuestro', 'vuestro', 'mis', 'tus', 'sus',
    'es', 'soy', 'eres', 'somos', 'son', 'ver'
]);

export const extractKeywords = (text: string): Set<string> => {
    if (!text) return new Set();
    const sanitizedText = text
        .toLowerCase()
        .normalize("NFD").replace(/[\u0300-\u036f]/g, "") // Remove accents
        .replace(/[¿?¡!.,;:]/g, ''); // Remove punctuation
    
    return new Set(
        sanitizedText
            .split(' ')
            .filter((word) => word.length > 2 && !stopWords.has(word))
    );
};

export const rebuildConnectionsLogic = (notes: any[]) => {
    const allConnections: { [noteId: string]: any[] } = {};

    for (const note of notes) {
        allConnections[note.id] = [];
    }

    for (let i = 0; i < notes.length; i++) {
        for (let j = i + 1; j < notes.length; j++) {
            const noteA = notes[i];
            const noteB = notes[j];

            const keywordsA = extractKeywords(noteA.title);
            const keywordsB = extractKeywords(noteB.title);

            const commonTopics = new Set<string>();
            for (const keywordA of keywordsA) {
                for (const keywordB of keywordsB) {
                    if (keywordA.startsWith(keywordB) || keywordB.startsWith(keywordA)) {
                        // Use the shorter word as the canonical topic
                        commonTopics.add(keywordA.length < keywordB.length ? keywordA : keywordB);
                    }
                }
            }

            if (commonTopics.size > 0) {
                const topic = Array.from(commonTopics).join(', ');
                allConnections[noteA.id].push({ noteId: noteB.id, topic: topic });
                allConnections[noteB.id].push({ noteId: noteA.id, topic: topic });
            }
        }
    }
    return allConnections;
}

exports.rebuildConnections = functions.https.onCall((data, context) => {
    const notes = data.notes as any[];

    if (!notes || !Array.isArray(notes)) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'The function must be called with an array of notes.'
        );
    }

    const connections = rebuildConnectionsLogic(notes);

    return { connections };
});
