# إعداد خدمة الإشعارات السحابية الفورية (Push Notifications)

هذا المجلد يحتوي على دوال **Firebase Cloud Functions** الخاصة بتطبيق الهيئة العامة للزكاة لإرسال الإشعارات التلقائية للمستخدمين في كافة الحالات (حتى لو كان التطبيق مغلقاً كلياً أو غير موجود في الـ RAM).

---

## 📌 كيف تعمل المنظومة؟

1. **في تطبيق الهاتف (Flutter):**
   - عند فتح التطبيق لأول مرة، يقوم التطبيق تلقائياً بالاشتراك في قناة الإعلانات `announcements` وموضوع التنبيهات `zakat_alerts` عبر Firebase Cloud Messaging.
   - تم تسجيل معالج الخلفية `firebaseMessagingBackgroundHandler` لاستقبال الإشعارات وعرضها حتى لو كان التطبيق مغلقاً.

2. **عند نشر إعلان جديد من لوحة الإدارة أو Firestore:**
   - الدالة السحابية `onAnnouncementCreated` تستشعر الإعلان الجديد فوراً في السحاب.
   - تقوم بإرسال رسالة FCM ذات أولوية قصوى (`priority: high`) وقناة إشعارات مخصصة بنغمة واهتزاز إلى موضوع `announcements`.
   - تستقبل خدمة `Google Play Services` في نظام أندرويد الإشعار وتعرضه فوراً في شريط الإشعارات العلوي للهاتف.

---

## 🚀 طريقة نشر الدوال السحابية (Deploy)

1. افتح موجه الأوامر (Terminal) في مجلد المشروع الرئيسي.
2. تأكد من تثبيت أدوات Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```
3. تسجيل الدخول إلى حساب Firebase:
   ```bash
   firebase login
   ```
4. الانتقال إلى مجلد functions وتثبيت الحزم:
   ```bash
   cd functions
   npm install
   ```
5. نشر الدوال إلى Firebase:
   ```bash
   firebase deploy --only functions
   ```

---

## 🧪 طريقة اختبار الإشعارات الفورية من Firebase Console مباشرة دون كتابة كود

يمكنك أيضاً اختبار إرسال إشعار فوري للتطبيق وهو مغلق بالكامل عبر الخطوات التالية:
1. اذهب إلى [Firebase Console](https://console.firebase.google.com/).
2. اختر مشروعك (`zakat-app-6bf78`).
3. من القائمة الجانبية، اذهب إلى **Engage** > **Messaging** (أو **Cloud Messaging**).
4. اضغط على **Create your first campaign** ثم اختر **Firebase Notification messages**.
5. اكتب عنوان الإشعار ونصه.
6. في خطوة **Target** (الهدف):
   - اختر **Topic** (موضوع).
   - اكتب: `announcements`
7. اضغط **Review** ثم **Publish**.
8. سيصل الإشعار فوراً إلى الهاتف حتى لو كان التطبيق مغلقاً كلياً ومحذوفاً من الـ RAM!
