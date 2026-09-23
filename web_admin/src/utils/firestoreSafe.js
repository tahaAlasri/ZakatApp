/**
 * firestoreSafe.js
 * يوفر حماية كاملة ضد تعليق العمليات على "جاري..."
 * عبر تغليف استدعاءات Firestore بمهلة زمنية (Timeout)
 * مع دعم نمط التخزين المحلي التلقائي (Local Fallback) في حال تعطل أو عدم تفعيل السحاب.
 */

const DEFAULT_TIMEOUT_MS = 6000; // 6 ثوانٍ كحد أقصى للانتظار

// حالة الاتصال بالسحاب
export const CloudStatus = {
  isAvailable: false, // لا نفترض الاتصال إلا بعد التحقق الحقيقي من السيرفر
  isChecking: true,
  lastError: null,
  dbNotCreated: false,
  listeners: new Set(),
  
  setStatus(available, error = null, dbNotCreated = false) {
    this.isAvailable = available;
    this.isChecking = false;
    this.lastError = error;
    this.dbNotCreated = dbNotCreated;
    this.listeners.forEach(fn => {
      try { fn({ isAvailable: available, isChecking: false, error, dbNotCreated }); } catch (_) {}
    });
  },
  
  subscribe(fn) {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }
};

/**
 * فحص حقيقي للاتصال بسيرفر Cloud Firestore عبر REST API المباشر
 * لتجنب الوقوع في فخ الـ Offline Cache لـ Firebase JS SDK
 */
export async function verifyCloudConnection() {
  try {
    const res = await fetch(
      'https://firestore.googleapis.com/v1/projects/zakat-app-6bf78/databases/(default)/documents/app_config/zakat_prices?key=AIzaSyBGzRGMUgU1j7GUmo50Dae1M2aIDvJNYwE',
      { signal: AbortSignal.timeout(4000) }
    );
    
    if (res.status === 200) {
      CloudStatus.setStatus(true, null, false);
      return true;
    } else {
      const is404 = res.status === 404;
      const msg = is404 
        ? 'قاعدة بيانات Firestore لم يتم إنشاؤها في كونسول Firebase بعد (خطأ 404)' 
        : `تعذر الاتصال بخادم Firestore (كود: ${res.status})`;
      CloudStatus.setStatus(false, msg, is404);
      return false;
    }
  } catch (err) {
    CloudStatus.setStatus(false, 'انقطاع الاتصال بالسحاب: ' + (err.message || 'فشل الاتصال'), false);
    return false;
  }
}

/**
 * دالة تغليف بمهلة زمنية لأي Promise
 */
export function withTimeout(promise, ms = DEFAULT_TIMEOUT_MS, errorMsg = 'انتهت مهلة الاتصال بالخادم السحابي') {
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      setTimeout(() => {
        const err = new Error(errorMsg);
        err.code = 'timeout';
        reject(err);
      }, ms);
    })
  ]);
}

/**
 * حفظ آمن لمستند مع مهلة وتخزين محلي احتياطي
 */
export async function safeSetDoc(firestoreSetDocPromise, collectionKey, docId, data) {
  const storageKey = `zakat_fallback_${collectionKey}_${docId}`;
  
  try {
    // محاولة الحفظ في السحاب مع مهلة 6 ثوانٍ
    await withTimeout(firestoreSetDocPromise, DEFAULT_TIMEOUT_MS, 'السحاب لا يستجيب (خدمة Cloud Firestore قد تكون معطلة في كونسول Firebase)');
    CloudStatus.setStatus(true, null);
    
    // حفظ نسخة احتياطية محلية متزامنة
    localStorage.setItem(storageKey, JSON.stringify({ ...data, _savedAt: new Date().toISOString() }));
    return { success: true, isLocal: false };
  } catch (err) {
    console.warn(`[safeSetDoc] Cloud write failed or timed out: ${err.message}. Falling back to localStorage.`);
    CloudStatus.setStatus(false, err.message);
    
    // حفظ محلي فوراً حتى لا يتعطل العمل
    localStorage.setItem(storageKey, JSON.stringify({ ...data, _savedAt: new Date().toISOString(), _needsSync: true }));
    return { success: true, isLocal: true, error: err.message };
  }
}

/**
 * إضافة مستند جديد مع مهلة وتخزين محلي احتياطي
 */
export async function safeAddDoc(firestoreAddDocPromise, collectionKey, data) {
  const localId = 'loc_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7);
  const storageKey = `zakat_fallback_${collectionKey}`;
  
  try {
    const docRef = await withTimeout(firestoreAddDocPromise, DEFAULT_TIMEOUT_MS, 'السحاب لا يستجيب (خدمة Cloud Firestore قد تكون معطلة)');
    CloudStatus.setStatus(true, null);
    
    // تحديث القائمة المحلية
    try {
      const existing = JSON.parse(localStorage.getItem(storageKey) || '[]');
      existing.unshift({ id: docRef.id, ...data, createdAt: new Date() });
      localStorage.setItem(storageKey, JSON.stringify(existing));
    } catch (_) {}
    
    return { id: docRef.id, success: true, isLocal: false };
  } catch (err) {
    console.warn(`[safeAddDoc] Cloud write failed or timed out: ${err.message}. Saved locally.`);
    CloudStatus.setStatus(false, err.message);
    
    // حفظ المستند في القائمة المحلية
    try {
      const existing = JSON.parse(localStorage.getItem(storageKey) || '[]');
      existing.unshift({ id: localId, ...data, createdAt: new Date(), _needsSync: true });
      localStorage.setItem(storageKey, JSON.stringify(existing));
    } catch (_) {}
    
    return { id: localId, success: true, isLocal: true, error: err.message };
  }
}

/**
 * تحديث آمن لمستند
 */
export async function safeUpdateDoc(firestoreUpdateDocPromise, collectionKey, docId, updates) {
  try {
    await withTimeout(firestoreUpdateDocPromise, DEFAULT_TIMEOUT_MS, 'السحاب لا يستجيب');
    CloudStatus.setStatus(true, null);
    return { success: true, isLocal: false };
  } catch (err) {
    console.warn(`[safeUpdateDoc] Cloud update failed or timed out: ${err.message}. Updating locally.`);
    CloudStatus.setStatus(false, err.message);
    
    const storageKey = `zakat_fallback_${collectionKey}`;
    try {
      const existing = JSON.parse(localStorage.getItem(storageKey) || '[]');
      const updated = existing.map(item => item.id === docId ? { ...item, ...updates } : item);
      localStorage.setItem(storageKey, JSON.stringify(updated));
    } catch (_) {}
    
    return { success: true, isLocal: true, error: err.message };
  }
}

/**
 * حذف آمن لمستند
 */
export async function safeDeleteDoc(firestoreDeleteDocPromise, collectionKey, docId) {
  try {
    await withTimeout(firestoreDeleteDocPromise, DEFAULT_TIMEOUT_MS, 'السحاب لا يستجيب');
    CloudStatus.setStatus(true, null);
  } catch (err) {
    console.warn(`[safeDeleteDoc] Cloud delete failed or timed out: ${err.message}. Deleting locally.`);
    CloudStatus.setStatus(false, err.message);
  }
  
  // حذف من التخزين المحلي دائماً
  const storageKey = `zakat_fallback_${collectionKey}`;
  try {
    const existing = JSON.parse(localStorage.getItem(storageKey) || '[]');
    const filtered = existing.filter(item => item.id !== docId);
    localStorage.setItem(storageKey, JSON.stringify(filtered));
  } catch (_) {}
  
  return { success: true };
}

/**
 * قراءة البيانات المحلية الاحتياطية لمجموعة
 */
export function getLocalCollection(collectionKey) {
  try {
    const storageKey = `zakat_fallback_${collectionKey}`;
    return JSON.parse(localStorage.getItem(storageKey) || '[]');
  } catch (_) {
    return [];
  }
}

/**
 * قراءة مستند محلي احتياطي
 */
export function getLocalDoc(collectionKey, docId) {
  try {
    const storageKey = `zakat_fallback_${collectionKey}_${docId}`;
    const raw = localStorage.getItem(storageKey);
    return raw ? JSON.parse(raw) : null;
  } catch (_) {
    return null;
  }
}
