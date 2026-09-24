const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

/**
 * دالة سحابية تعمل تلقائياً في سيرفرات Firebase بمجرد إضافة أي إعلان جديد
 * تقوم بإرسال إشعار فوري (FCM Push Notification) ذو أولوية قصوى لجميع الهواتف
 * حتى لو كان التطبيق مغلقاً تماماً وغير موجود في الذاكرة (RAM) أو شاشة الهاتف مقفلة.
 */
exports.onAnnouncementCreated = onDocumentCreated(
  {
    document: "announcements/{announcementId}",
    region: "us-central1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log("No data associated with the event");
      return;
    }

    const data = snap.data();
    if (!data || data.isActive === false) {
      console.log("Announcement is either null or inactive, skipping notification.");
      return;
    }

    const announcementId = event.params.announcementId;
    const title = data.title || "إعلان جديد";
    const content = data.content || "";
    const priority = data.priority || "general";

    let prefix = "📢 ";
    if (priority === "urgent") {
      prefix = "🚨 [عاجل] ";
    } else if (priority === "warning") {
      prefix = "⚠️ [تنبيه] ";
    }

    const message = {
      notification: {
        title: `${prefix}الهيئة العامة للزكاة: ${title}`,
        body: content,
      },
      data: {
        type: "announcement",
        id: announcementId,
        priority: priority,
        title: `${prefix}الهيئة العامة للزكاة: ${title}`,
        body: content,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "zakat_alerts_channel",
          sound: "default",
          priority: "max",
          defaultVibrateTimings: true,
          visibility: "public",
          icon: "@mipmap/launcher_icon",
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: `${prefix}الهيئة العامة للزكاة: ${title}`,
              body: content,
            },
            sound: "default",
            badge: 1,
          },
        },
      },
      topic: "announcements",
    };

    try {
      const response = await getMessaging().send(message);
      console.log(`✅ Successfully sent announcement push notification to topic 'announcements': ${response}`);
    } catch (error) {
      console.error("❌ Error sending announcement notification:", error);
    }
  }
);

/**
 * دالة سحابية لتنبيه المواطن فوراً عند تحديث حالة طلب المساعدة الخاص به أو وصول رد من الهيئة
 * وتعمل حتى والتطبيق مغلق تماماً عبر إرسال الإشعار لموضوع المستخدم الخاص user_{userId}
 */
exports.onRequestStatusUpdated = onDocumentWritten(
  {
    document: "assistance_requests/{requestId}",
    region: "us-central1",
  },
  async (event) => {
    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();

    // إذا تم حذف الطلب أو لا توجد بيانات
    if (!afterData) return;

    const userId = afterData.userId;
    if (!userId) return;

    const prevStatus = beforeData?.status;
    const currentStatus = afterData.status;
    const prevReply = beforeData?.adminResponse;
    const currentReply = afterData.adminResponse;

    // التحقق هل تغيرت الحالة أو تم إضافة رد رسمي جديد
    const statusChanged = prevStatus && prevStatus !== currentStatus;
    const replyChanged = currentReply && currentReply !== prevReply;

    if (!statusChanged && !replyChanged) return;

    const subject = afterData.subject || "طلب مساعدة";
    let statusLabel = currentStatus;
    if (currentStatus === "approved" || currentStatus === "تمت الموافقة") {
      statusLabel = "تمت الموافقة على طلبكم ✅";
    } else if (currentStatus === "rejected" || currentStatus === "مرفوض") {
      statusLabel = "تمت مراجعة الطلب مع الاعتذار ❌";
    } else if (currentStatus === "under_review" || currentStatus === "قيد الدراسة") {
      statusLabel = "طلبكم قيد الدراسة الميدانية 📋";
    } else if (currentStatus === "completed" || currentStatus === "جاهز للصرف") {
      statusLabel = "طلبكم جاهز للصرف والإنجاز 💵";
    }

    const bodyText = currentReply
      ? `${statusLabel} بخصوص "${subject}". رد الهيئة: ${currentReply}`
      : `${statusLabel} بخصوص "${subject}". اضغط للاطلاع على التفاصيل.`;

    const message = {
      notification: {
        title: "🔔 الهيئة العامة للزكاة - تحديث الطلب",
        body: bodyText,
      },
      data: {
        type: "request",
        id: event.params.requestId,
        targetId: event.params.requestId,
        title: "🔔 الهيئة العامة للزكاة - تحديث الطلب",
        body: bodyText,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "zakat_alerts_channel",
          sound: "default",
          priority: "max",
          defaultVibrateTimings: true,
          visibility: "public",
          icon: "@mipmap/launcher_icon",
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: "🔔 الهيئة العامة للزكاة - تحديث الطلب",
              body: bodyText,
            },
            sound: "default",
            badge: 1,
          },
        },
      },
      topic: `user_${userId}`,
    };

    try {
      const response = await getMessaging().send(message);
      console.log(`✅ Successfully sent request status update push to topic user_${userId}: ${response}`);
    } catch (error) {
      console.error("❌ Error sending request push notification:", error);
    }
  }
);
