import React, { useState } from 'react';
import {
  Megaphone, Plus, Trash2, Send, CheckCircle2,
  Smartphone, ToggleLeft, ToggleRight, Key, Info, Settings
} from 'lucide-react';
import {
  collection, addDoc, deleteDoc, doc, updateDoc, serverTimestamp
} from 'firebase/firestore';
import { db } from '../firebase';
import { safeAddDoc, safeUpdateDoc, safeDeleteDoc, getLocalCollection } from '../utils/firestoreSafe';
import { sendDirectFcmNotification, getStoredServerKey, setStoredServerKey } from '../utils/fcmSender';

// ✅ Helper: format a Date object safely
function formatDate(val) {
  if (!val) return '-';
  const d = val instanceof Date ? val : new Date(val);
  if (isNaN(d)) return '-';
  return d.toLocaleDateString('ar-YE');
}

// ✅ Fixed: badge class for warning priority
function priorityBadgeClass(priority) {
  if (priority === 'urgent') return 'badge-rejected';
  if (priority === 'warning') return 'badge-pending';
  return 'badge-approved';
}

function priorityLabel(priority) {
  if (priority === 'urgent') return 'عاجل';
  if (priority === 'warning') return 'تنبيه';
  return 'عام';
}

export default function Announcements({ announcements = [] }) {
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [priority, setPriority] = useState('general');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [successToast, setSuccessToast] = useState(null);
  const [localExtraList, setLocalExtraList] = useState(() => getLocalCollection('announcements'));
  const [showFcmModal, setShowFcmModal] = useState(false);
  const [fcmKeyInput, setFcmKeyInput] = useState(() => getStoredServerKey());
  const [savedKeyToast, setSavedKeyToast] = useState(false);

  const showToast = (msg) => {
    setSuccessToast(msg);
    setTimeout(() => setSuccessToast(null), 5000);
  };

  // Combine cloud and local items without duplicates
  const allAnnouncements = (() => {
    const list = [...announcements];
    for (const item of localExtraList) {
      if (!list.some(a => a.id === item.id)) {
        list.push(item);
      }
    }
    return list;
  })();

  const handleSaveFcmKey = (e) => {
    e.preventDefault();
    setStoredServerKey(fcmKeyInput);
    setSavedKeyToast(true);
    setTimeout(() => {
      setSavedKeyToast(false);
      setShowFcmModal(false);
    }, 1500);
    showToast('تم حفظ مفتاح خادم الإشعارات FCM بنجاح في لوحة التحكم.');
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    if (!title.trim() || !content.trim()) return;
    setIsSubmitting(true);

    const payload = {
      title: title.trim(),
      content: content.trim(),
      priority,
      isActive: true,
      createdAt: new Date(),
    };

    try {
      const res = await safeAddDoc(
        addDoc(collection(db, 'announcements'), {
          ...payload,
          createdAt: serverTimestamp()
        }),
        'announcements',
        payload
      );

      // 🔔 إرسال إشعار فوري مباشر لجميع الهواتف المشتركة في موضوع announcements
      sendDirectFcmNotification({
        topic: 'announcements',
        title: payload.title,
        body: payload.content,
        priority: payload.priority,
        data: {
          id: res.id,
          type: 'announcement',
        },
      }).then(fcmRes => {
        if (fcmRes.success) {
          console.log('✅ FCM Push Sent successfully from Admin panel.');
        }
      }).catch(err => console.warn('Direct FCM notice:', err));

      // Add to local state immediately so user sees it right away
      setLocalExtraList(prev => [{ id: res.id, ...payload }, ...prev]);

      setTitle('');
      setContent('');
      setPriority('general');

      if (res.isLocal) {
        showToast('⚠️ تم نشر الإعلان محلياً في اللوحة بنجاح (السحاب غير مفعل في Firebase حالياً)!');
      } else {
        showToast('🚀 تم نشر الإعلان بنجاح وسيصل كإشعار فوري لجميع الهواتف حتى لو كان التطبيق مغلقاً!');
      }
    } catch (err) {
      alert('حدث خطأ أثناء نشر الإعلان: ' + err.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleToggle = async (id, current) => {
    try {
      // Update UI immediately
      setLocalExtraList(prev => prev.map(a => a.id === id ? { ...a, isActive: !current } : a));
      
      await safeUpdateDoc(
        updateDoc(doc(db, 'announcements', id), {
          isActive: !current,
          updatedAt: serverTimestamp()
        }),
        'announcements',
        id,
        { isActive: !current }
      );
      showToast('تم تحديث حالة الإعلان بنجاح.');
    } catch (err) {
      alert('تعذر تحديث حالة الإعلان: ' + err.message);
    }
  };

  const handleDelete = async (id, annTitle) => {
    if (!window.confirm(`هل أنت متأكد من حذف الإعلان: "${annTitle}" نهائياً؟`)) return;
    try {
      // Remove from UI immediately
      setLocalExtraList(prev => prev.filter(a => a.id !== id));
      
      await safeDeleteDoc(
        deleteDoc(doc(db, 'announcements', id)),
        'announcements',
        id
      );
      showToast('تم حذف الإعلان بنجاح.');
    } catch (err) {
      alert('تعذر حذف الإعلان: ' + err.message);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      {successToast && (
        <div style={{
          position: 'fixed', bottom: '24px', left: '24px',
          background: 'linear-gradient(135deg, #00695c, #004d40)',
          color: '#fff', padding: '14px 22px', borderRadius: '12px',
          boxShadow: '0 10px 25px rgba(0,0,0,0.5)',
          display: 'flex', alignItems: 'center', gap: '12px',
          zIndex: 300, border: '1px solid var(--gold)'
        }}>
          <CheckCircle2 size={20} color="var(--gold)" />
          <span style={{ fontSize: '13.5px', fontWeight: '700' }}>{successToast}</span>
        </div>
      )}

      {/* FCM Server Key Settings Modal */}
      {showFcmModal && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0,0,0,0.7)', backdropFilter: 'blur(4px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          zIndex: 9999, padding: '20px'
        }}>
          <div className="zakat-card" style={{ maxWidth: '540px', width: '100%', background: '#0f172a', border: '1px solid var(--gold)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <Key size={20} color="var(--gold)" />
                <h3 style={{ fontSize: '16px', fontWeight: '800', margin: 0 }}>إعدادات إرسال الإشعارات المباشرة (FCM)</h3>
              </div>
              <button onClick={() => setShowFcmModal(false)} style={{ background: 'none', border: 'none', color: '#fff', fontSize: '18px', cursor: 'pointer' }}>✕</button>
            </div>

            <p style={{ fontSize: '13px', color: 'var(--text-muted)', lineHeight: '1.6', marginBottom: '16px' }}>
              يمكنك إدخال مفتاح خادم Firebase (Server Key) هنا ليتم إرسال إشعارات الـ Push Notification مباشرة من المتصفح لجميع الهواتف حتى لو كان التطبيق مغلقاً كلياً:
            </p>

            <form onSubmit={handleSaveFcmKey}>
              <div className="form-group" style={{ marginBottom: '16px' }}>
                <label className="form-label" style={{ fontSize: '12.5px' }}>FCM Server Key (مفتاح الخادم):</label>
                <input
                  type="password"
                  value={fcmKeyInput}
                  onChange={(e) => setFcmKeyInput(e.target.value)}
                  placeholder="AAAA... (من Firebase Console > Project Settings > Cloud Messaging)"
                  className="form-control"
                  style={{ direction: 'ltr', fontFamily: 'monospace', fontSize: '12px' }}
                />
              </div>

              <div style={{ background: 'rgba(0, 105, 92, 0.15)', border: '1px solid rgba(0, 105, 92, 0.4)', borderRadius: '8px', padding: '12px', marginBottom: '18px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: 'var(--gold)', fontWeight: 'bold', fontSize: '12px', marginBottom: '4px' }}>
                  <Info size={16} />
                  <span>طريقة الحصول على المفتاح:</span>
                </div>
                <ol style={{ margin: 0, paddingRight: '20px', fontSize: '11.5px', color: '#cbd5e1', lineHeight: '1.6' }}>
                  <li>ادخل إلى <strong>Firebase Console</strong> ثم اضغط على ⚙️ (إعدادات المشروع).</li>
                  <li>اذهب إلى تبويب <strong>Cloud Messaging</strong>.</li>
                  <li>انسخ قيمة <strong>Server key</strong> وضعها هنا واضغط حفظ.</li>
                </ol>
              </div>

              <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
                <button type="button" onClick={() => setShowFcmModal(false)} className="btn btn-secondary btn-sm">إلغاء</button>
                <button type="submit" className="btn btn-gold btn-sm" style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <CheckCircle2 size={16} />
                  <span>{savedKeyToast ? 'تم الحفظ!' : 'حفظ المفتاح'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h1 style={{ fontSize: '22px', fontWeight: '800', margin: 0 }}>نظام الإعلانات والتعميمات الرسمية</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '13px', marginTop: '4px' }}>
            نشر تنبيهات فورية ومواعيد صرف الزكاة لتصل لجميع هواتف المواطنين كإشعارات دفع حتى والتطبيق مغلق.
          </p>
        </div>
        <button
          type="button"
          onClick={() => setShowFcmModal(true)}
          className="btn btn-secondary btn-sm"
          style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', border: '1px solid var(--gold)', color: 'var(--gold)' }}
        >
          <Key size={16} />
          <span>إعدادات مفتاح الإشعارات (FCM)</span>
        </button>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))', gap: '24px' }}>
        {/* Create Form */}
        <div className="zakat-card">
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '18px', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px' }}>
            <Plus size={20} color="var(--gold)" />
            <h2 style={{ fontSize: '16px', fontWeight: '800', margin: 0 }}>إنشاء ونشر إعلان جديد</h2>
          </div>
          <form onSubmit={handleCreate}>
            <div className="form-group">
              <label className="form-label">عنوان الإعلان:</label>
              <input type="text" required placeholder="مثال: بدء صرف زكاة الفطرة"
                value={title} onChange={e => setTitle(e.target.value)} className="form-control" />
            </div>
            <div className="form-group">
              <label className="form-label">درجة الأهمية:</label>
              <select value={priority} onChange={e => setPriority(e.target.value)} className="form-control" style={{ fontWeight: '700' }}>
                <option value="general">📢 إعلان عام (أخضر)</option>
                <option value="warning">⚠️ تنبيه هام (أصفر)</option>
                <option value="urgent">🚨 عاجل جداً (أحمر)</option>
              </select>
            </div>
            <div className="form-group">
              <label className="form-label">نص الإعلان:</label>
              <textarea rows="4" required placeholder="اكتب تفاصيل الإعلان..."
                value={content} onChange={e => setContent(e.target.value)}
                className="form-control" style={{ resize: 'vertical' }} />
            </div>
            <button type="submit" className="btn btn-gold" disabled={isSubmitting}
              style={{ width: '100%', padding: '12px', justifyContent: 'center' }}>
              <Send size={16} />
              <span>{isSubmitting ? 'جاري النشر...' : 'نشر الإعلان فوراً للمستخدمين'}</span>
            </button>
          </form>
        </div>

        {/* Live Preview */}
        <div className="zakat-card" style={{ background: '#0d1527', border: '1px dashed var(--gold)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px' }}>
            <Smartphone size={20} color="var(--primary-light)" />
            <h3 style={{ fontSize: '15px', fontWeight: '700', margin: 0 }}>معاينة حية: كيف سيظهر في هاتف المواطن</h3>
          </div>
          <div style={{ background: '#131e33', border: '2px solid #2d3b55', borderRadius: '20px', padding: '16px', maxWidth: '320px', margin: '0 auto' }}>
            <div style={{ textAlign: 'center', marginBottom: '14px' }}>
              <span style={{ fontSize: '11px', color: 'var(--text-dim)', fontWeight: 'bold' }}>واجهة التطبيق الرئيسية</span>
            </div>
            <div style={{
              background: priority === 'urgent' ? 'rgba(239,68,68,0.15)' : priority === 'warning' ? 'rgba(245,158,11,0.15)' : 'rgba(0,105,92,0.2)',
              border: `1.5px solid ${priority === 'urgent' ? 'var(--error)' : priority === 'warning' ? 'var(--warning)' : 'var(--gold)'}`,
              borderRadius: '12px', padding: '12px', display: 'flex', gap: '10px'
            }}>
              <Megaphone size={22}
                color={priority === 'urgent' ? 'var(--error)' : priority === 'warning' ? 'var(--warning)' : 'var(--gold)'}
                style={{ flexShrink: 0, marginTop: '2px' }} />
              <div>
                <div style={{ fontWeight: '800', fontSize: '12.5px', color: priority === 'urgent' ? '#fca5a5' : '#fef08a', marginBottom: '3px' }}>
                  {title.trim() || 'عنوان الإعلان التجريبي'}
                </div>
                <div style={{ fontSize: '11px', color: '#e2e8f0', lineHeight: '1.4' }}>
                  {content.trim() || 'هنا سيظهر نص ومحتوى الإعلان الذي تكتبه.'}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Announcements Table */}
      <div className="zakat-card">
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px', borderBottom: '1px solid var(--border-color)', paddingBottom: '12px' }}>
          <Megaphone size={20} color="var(--gold)" />
          <h2 style={{ fontSize: '16px', fontWeight: '800', margin: 0 }}>سجل الإعلانات ({allAnnouncements.length})</h2>
        </div>

        {allAnnouncements.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '36px', color: 'var(--text-muted)' }}>لا توجد إعلانات سابقة.</div>
        ) : (
          <div className="zakat-table-container">
            <table className="zakat-table">
              <thead>
                <tr>
                  <th>العنوان</th>
                  <th>المحتوى</th>
                  <th>التصنيف</th>
                  <th>الحالة</th>
                  <th>تاريخ النشر</th>
                  <th>الإجراء</th>
                </tr>
              </thead>
              <tbody>
                {allAnnouncements.map(ann => (
                  <tr key={ann.id}>
                    <td><strong style={{ fontSize: '13.5px' }}>{ann.title}</strong></td>
                    <td style={{ maxWidth: '300px', fontSize: '12.5px', color: 'var(--text-muted)' }}>{ann.content}</td>
                    <td>
                      <span className={`badge ${priorityBadgeClass(ann.priority)}`}>
                        {priorityLabel(ann.priority)}
                      </span>
                    </td>
                    <td>
                      <button onClick={() => handleToggle(ann.id, ann.isActive)}
                        style={{ background: 'transparent', border: 'none', color: ann.isActive ? 'var(--success)' : 'var(--text-dim)', cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: '6px', fontWeight: 'bold', fontSize: '12px' }}>
                        {ann.isActive ? <ToggleRight size={22} /> : <ToggleLeft size={22} />}
                        <span>{ann.isActive ? 'نشط ومعروض' : 'معطل ومخفي'}</span>
                      </button>
                    </td>
                    {/* ✅ Fixed: date already converted to Date in App.jsx */}
                    <td style={{ fontSize: '12px', color: 'var(--text-dim)' }}>{formatDate(ann.createdAt)}</td>
                    <td>
                      <button onClick={() => handleDelete(ann.id, ann.title)}
                        className="btn btn-danger btn-sm" title="حذف الإعلان">
                        <Trash2 size={14} /><span>حذف</span>
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
