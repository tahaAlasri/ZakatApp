/**
 * خدمة البث السحابي اللحظي للإشعارات (FCM Realtime Push Dispatcher)
 * تعمل بشكل دائم لمراقبة قاعدة بيانات Firestore وإرسال إشعارات FCM فورية لجميع الهواتف
 * حتى لو كان التطبيق مغلقاً تماماً في هواتف المستخدمين.
 * 
 * الميزات:
 * 1. ترسل إشعار فوري لجميع الهواتف عند نشر أو تفعيل أي إعلان جديد (موضوع announcements).
 * 2. ترسل إشعار فوري مخصص للمواطن عند تغيير حالة طلبه أو الرد عليه من الإدارة (موضوع user_{userId}).
 * 3. تعمل على أي خطة (سواء مجانية Spark أو مدفوعة Blaze) باستخدام serviceAccountKey.json.
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const path = require('path');
const fs = require('fs');

const keyPath = path.join(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  console.error('❌ لم يتم العثور على ملف serviceAccountKey.json في مجلد functions');
  process.exit(1);
}

const serviceAccount = require(keyPath);
initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();
const messaging = getMessaging();

console.log('🚀 تم تشغيل خدمة مراقبة وبث الإشعارات الفورية (FCM Dispatcher)...');
console.log('📡 في انتظار أي إعلان جديد أو تحديث لطلبات المساعدة...');

// ذاكرة مؤقتة لتجنب إرسال إشعارات مكررة عند بدء التشغيل
const processedAnnouncements = new Set();
const processedRequests = new Map();
let isInitialAnnouncementsLoad = true;
let isInitialRequestsLoad = true;

// 1. مراقبة الإعلانات والتعميمات اللحظية
db.collection('announcements')
  .where('isActive', '==', true)
  .onSnapshot((snapshot) => {
    if (isInitialAnnouncementsLoad) {
      snapshot.docs.forEach((doc) => processedAnnouncements.add(doc.id));
      isInitialAnnouncementsLoad = false;
      console.log(`✅ تم تحميل ${processedAnnouncements.size} إعلانات سابقة بنجاح. المراقبة نشطة الآن...`);
      return;
    }

    snapshot.docChanges().forEach(async (change) => {
      if (change.type === 'added' || change.type === 'modified') {
        const docId = change.doc.id;
        const data = change.doc.data();

        // تجنب التكرار إذا تم إرساله من قبل في نفس الجلسة
        if (processedAnnouncements.has(docId) && change.type === 'added') return;
        processedAnnouncements.add(docId);

        const title = data.title || 'إعلان رسمي جديد';
        const content = data.content || '';
        const priority = data.priority || 'general';

        let prefix = '📢 ';
        if (priority === 'urgent') prefix = '🚨 [عاجل] ';
        else if (priority === 'warning') prefix = '⚠️ [تنبيه] ';

        const fullTitle = `${prefix}الهيئة العامة للزكاة: ${title}`;

        const message = {
          notification: {
            title: fullTitle,
            body: content,
          },
          data: {
            type: 'announcement',
            id: docId,
            title: fullTitle,
            body: content,
            priority: priority,
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
                  title: fullTitle,
                  body: content,
                },
                sound: 'default',
                badge: 1,
              },
            },
          },
          topic: 'announcements',
        };

        try {
          const resp = await messaging.send(message);
          console.log(`📢 [FCM إعلان] تم إرسال إشعار الإعلان "${title}" لجميع الهواتف بنجاح! المعرف: ${resp}`);
        } catch (err) {
          console.error(`❌ خطأ أثناء إرسال إشعار الإعلان:`, err.message);
        }
      }
    });
  }, (err) => {
    console.error('❌ خطأ في مستمع الإعلانات:', err.message);
  });

// 2. مراقبة طلبات المساعدة وإرسال إشعار للمواطن عند تغيير الحالة أو الرد
db.collection('assistance_requests')
  .onSnapshot((snapshot) => {
    if (isInitialRequestsLoad) {
      snapshot.docs.forEach((doc) => {
        const data = doc.data();
        processedRequests.set(doc.id, {
          status: data.status,
          adminResponse: data.adminResponse,
        });
      });
      isInitialRequestsLoad = false;
      return;
    }

    snapshot.docChanges().forEach(async (change) => {
      const docId = change.doc.id;
      const data = change.doc.data();
      const prev = processedRequests.get(docId);

      const statusChanged = prev && prev.status !== data.status;
      const replyChanged = prev && data.adminResponse && data.adminResponse !== prev.adminResponse;

      processedRequests.set(docId, {
        status: data.status,
        adminResponse: data.adminResponse,
      });

      if ((statusChanged || replyChanged) && data.userId) {
        let statusLabel = data.status;
        if (data.status === 'approved' || data.status === 'تمت الموافقة') statusLabel = 'تمت الموافقة على طلبكم ✅';
        else if (data.status === 'rejected' || data.status === 'مرفوض') statusLabel = 'تمت مراجعة الطلب مع الاعتذار ❌';
        else if (data.status === 'under_review' || data.status === 'قيد الدراسة') statusLabel = 'طلبكم قيد الدراسة الميدانية 📋';
        else if (data.status === 'completed' || data.status === 'جاهز للصرف') statusLabel = 'طلبكم جاهز للصرف والإنجاز 💵';

        const subject = data.subject || 'طلب مساعدة';
        const replyMsg = data.adminResponse ? ` رد الهيئة: ${data.adminResponse}` : '';
        const bodyText = `${statusLabel} بخصوص "${subject}".${replyMsg}`;

        const message = {
          notification: {
            title: '🔔 الهيئة العامة للزكاة - تحديث الطلب',
            body: bodyText,
          },
          data: {
            type: 'request',
            id: docId,
            targetId: docId,
            title: '🔔 الهيئة العامة للزكاة - تحديث الطلب',
            body: bodyText,
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
          topic: `user_${data.userId}`,
        };

        try {
          const resp = await messaging.send(message);
          console.log(`🔔 [FCM طلب] تم إشعار المواطن (#${docId}) بتحديث الحالة بنجاح! المعرف: ${resp}`);
        } catch (err) {
          console.error(`❌ خطأ أثناء إشعار المواطن:`, err.message);
        }
      }
    });
  }, (err) => {
    console.error('❌ خطأ في مستمع طلبات المساعدة:', err.message);
  });
