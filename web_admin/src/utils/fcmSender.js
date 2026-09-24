/**
 * وحدة إرسال إشعارات الدفع الفورية (FCM Push Notifications) من لوحة التحكم مباشرة
 * تتيح إرسال التنبيهات لجميع الهواتف المشتركة في موضوع معين (مثل announcements)
 * حتى لو كان التطبيق مغلقاً تماماً أو غير موجود في الـ RAM.
 */

// جلب مفتاح الخادم من متغيرات البيئة أو التخزين المحلي للوحة
export function getStoredServerKey() {
  return localStorage.getItem('fcm_server_key') || import.meta.env.VITE_FIREBASE_SERVER_KEY || '';
}

export function setStoredServerKey(key) {
  if (key) {
    localStorage.setItem('fcm_server_key', key.trim());
  } else {
    localStorage.removeItem('fcm_server_key');
  }
}

/**
 * إرسال إشعار فوري لموضوع معين (مثل announcements أو user_123)
 * @param {Object} params
 * @param {string} params.topic - موضوع البث (مثل 'announcements')
 * @param {string} params.title - عنوان الإشعار
 * @param {string} params.body - نص الإشعار
 * @param {Object} [params.data] - بيانات إضافية مرافقة
 * @param {string} [params.priority] - أولوية التنبيه (urgent / normal)
 */
export async function sendDirectFcmNotification({
  topic = 'announcements',
  title,
  body,
  data = {},
  priority = 'general',
}) {
  const serverKey = getStoredServerKey();
  if (!serverKey) {
    console.info('ℹ️ لم يتم العثور على FCM Server Key في اللوحة. إذا كانت دوال Cloud Functions منشورة فسيتم الإرسال عبر السيرفر تلقائياً.');
    return { success: false, reason: 'no_server_key' };
  }

  let prefix = '📢 ';
  if (priority === 'urgent') {
    prefix = '🚨 [عاجل] ';
  } else if (priority === 'warning') {
    prefix = '⚠️ [تنبيه] ';
  }

  const fullTitle = title.startsWith('📢') || title.startsWith('🚨') || title.startsWith('⚠️') || title.startsWith('🔔')
    ? title
    : `${prefix}الهيئة العامة للزكاة: ${title}`;

  const payload = {
    to: `/topics/${topic}`,
    priority: 'high',
    notification: {
      title: fullTitle,
      body: body,
      sound: 'default',
      android_channel_id: 'zakat_alerts_channel',
      icon: '@mipmap/launcher_icon',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    data: {
      type: data.type || 'announcement',
      id: data.id || `ann_${Date.now()}`,
      priority: priority,
      title: fullTitle,
      body: body,
      targetId: data.targetId || data.id || '',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      ...data,
    },
  };

  try {
    const response = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${serverKey}`,
      },
      body: JSON.stringify(payload),
    });

    const result = await response.json();
    if (response.ok && (result.message_id || result.success === 1)) {
      console.log('✅ تم إرسال الإشعار الفوري للهواتف بنجاح عبر FCM Direct API:', result);
      return { success: true, result };
    } else {
      console.warn('⚠️ رد خدمة FCM:', result);
      return { success: false, result };
    }
  } catch (err) {
    console.error('❌ خطأ أثناء إرسال إشعار FCM المباشر:', err);
    return { success: false, error: err.message };
  }
}
