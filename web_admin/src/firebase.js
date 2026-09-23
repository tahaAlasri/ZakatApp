import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY || "AIzaSyBGzRGMUgU1j7GUmo50Dae1M2aIDvJNYwE",
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || "zakat-app-6bf78.firebaseapp.com",
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || "zakat-app-6bf78",
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET || "zakat-app-6bf78.firebasestorage.app",
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || "46552772030",
  appId: import.meta.env.VITE_FIREBASE_APP_ID || "1:46552772030:web:89405dab7d63fb93115def"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const auth = getAuth(app);
export default app;
