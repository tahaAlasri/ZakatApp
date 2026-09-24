

const { initializeApp, cert } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const fs = require('fs');
const path = require('path');

// محاولة البحث عن ملف مفتاح الخدمة serviceAccountKey.json إذا وُجد
const keyPath = path.join(__dirname, 'serviceAccountKey.json');
if (fs.existsSync(keyPath)) {
  const serviceAccount = require(keyPath);
  initializeApp({
    credential: cert(serviceAccount)
  });
} else {
  // تهيئة افتراضية
  initializeApp();
}

const args = process.argv.slice(2);
const title = args[0] || 'إعلان هام من الهيئة العامة للزكاة';
const body = args[1] || 'تم إطلاق حملة جديدة لصرف المساعدات ومتابعة الحول الشرعي.';

const message = {
  notification: {
    title: `📢 الهيئة العامة للزكاة: ${title}`,
    body: body,
  },
  data: {
    type: 'announcement',
    title: `📢 الهيئة العامة للزكاة: ${title}`,
    body: body,
    id: `test_${Date.now()}`,
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
  },
  android: {
    priority: 'high',
    notification: {
      channelId: 'zakat_alerts_channel',
      sound: 'default',
      priority: 'max',
      defaultVibrateTimings: true,
      visibility: 'public',
      icon: '@mipmap/launcher_icon',
    },
  },
  apns: {
    payload: {
      aps: {
        alert: {
          title: `📢 الهيئة العامة للزكاة: ${title}`,
          body: body,
        },
        sound: 'default',
        badge: 1,
      },
    },
  },
  topic: 'announcements',
};

async function send() {
  try {
    console.log(`📡 جاري إرسال الإشعار الفوري إلى موضوع 'announcements'...`);
    const response = await getMessaging().send(message);
    console.log(`✅ تم إرسال الإشعار الفوري بنجاح لجميع الهواتف! المعرف: ${response}`);
  } catch (error) {
    console.error(`❌ تعذر إرسال الإشعار:`, error.message);
  }
}

send();
