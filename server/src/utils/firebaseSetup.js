import admin from 'firebase-admin';
import '../loadEnv.js';

let isFirebaseInitialized = false;

export function initFirebase() {
  if (isFirebaseInitialized) return;
  
  try {
    const serviceAccountStr = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (serviceAccountStr) {
      const serviceAccount = JSON.parse(serviceAccountStr);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
      isFirebaseInitialized = true;
      console.log('Firebase Admin initialized successfully.');
    } else {
      console.warn('Warning: FIREBASE_SERVICE_ACCOUNT_JSON is not set in .env. Push notifications will be disabled.');
    }
  } catch (e) {
    console.error('Failed to initialize Firebase Admin:', e.message);
  }
}

export function sendPushNotification(tokens, title, body) {
  if (!isFirebaseInitialized || !tokens || tokens.length === 0) return;
  
  const message = {
    notification: { title, body },
    tokens: tokens,
  };
  
  return admin.messaging().sendEachForMulticast(message)
    .then(response => {
      console.log(response.successCount + ' messages were sent successfully');
    })
    .catch(error => {
      console.error('Error sending message:', error);
    });
}
