import React, { useState, useMemo } from 'react';
import {
  Search, Clock, CheckCircle2, XCircle, AlertCircle,
  Copy, Phone, MessageSquare, FileText, MapPin,
  Send, Printer, RefreshCw, Bell, ChevronLeft, ChevronRight,
  Download, Filter, Calendar
} from 'lucide-react';
import confetti from 'canvas-confetti';
import { doc, updateDoc, serverTimestamp, arrayUnion } from 'firebase/firestore';
import { db } from '../firebase';
import { safeUpdateDoc } from '../utils/firestoreSafe';

const PAGE_SIZE = 15;

const statusOptions = [
  { value: 'قيد المراجعة', label: 'قيد المراجعة الأولية', color: 'badge-pending' },
  { value: 'قيد الدراسة', label: 'قيد الدراسة والبحث الميداني', color: 'badge-review' },
  { value: 'تمت الموافقة', label: 'تمت الموافقة على الطلب', color: 'badge-approved' },
  { value: 'جاهز للصرف', label: 'معتمد وجاهز للصرف', color: 'badge-completed' },
  { value: 'مرفوض', label: 'اعتذار / غير مستوفٍ للشروط', color: 'badge-rejected' },
];

const governorates = [
  'الكل',
  'أمانة العاصمة',
  'صنعاء',
  'عدن',
  'تعز',
  'الحديدة',
  'إب',
  'ذمار',
  'حضرموت',
  'حجة',
  'صعدة',
  'عمران',
  'البيضاء',
  'أبين',
  'لحج',
  'شبوة',
  'مأرب',
  'الجوف',
  'المهرة',
  'سقطرى',
  'أخرى'
];

function badgeClass(status) {
  if (status === 'تمت الموافقة' || status === 'approved') return 'badge-approved';
  if (status === 'مرفوض' || status === 'rejected') return 'badge-rejected';
  if (status === 'جاهز للصرف' || status === 'completed') return 'badge-completed';
  if (status === 'قيد الدراسة' || status === 'under_review') return 'badge-review';
  return 'badge-pending';
}

function handlePrint(req) {
  const w = window.open('', '_blank');
  w.document.write(`
    <html dir="rtl"><head><meta charset="utf-8"><title>طلب ${req.referenceCode || req.id}</title>
    <style>body{font-family:Cairo,Arial,sans-serif;padding:30px;direction:rtl}
    h2{border-bottom:2px solid #00695c;padding-bottom:8px;color:#00695c}
    .row{display:flex;gap:16px;margin:10px 0;border-bottom:1px solid #eee;padding-bottom:6px}
    .label{color:#555;min-width:140px;font-weight:bold}
    .val{flex:1}
    </style></head><body>
    <h2>الهيئة العامة للزكاة - طلب مساعدة (كود التتبع: ${req.referenceCode || req.id})</h2>
    <div class="row"><span class="label">مقدم الطلب:</span><span class="val">${req.fullName || '-'}</span></div>
    <div class="row"><span class="label">رقم الهوية:</span><span class="val">${req.idNumber || '-'}</span></div>
    <div class="row"><span class="label">الهاتف:</span><span class="val">${req.phone || '-'}</span></div>
    <div class="row"><span class="label">العنوان / المحافظة:</span><span class="val">${req.address || '-'}</span></div>
    <div class="row"><span class="label">موضوع الطلب:</span><span class="val">${req.subject || '-'}</span></div>
    <div class="row"><span class="label">التفاصيل:</span><span class="val">${req.details || '-'}</span></div>
    <div class="row"><span class="label">حالة الطلب:</span><span class="val">${req.status || '-'}</span></div>
    <div class="row"><span class="label">رد الهيئة:</span><span class="val">${req.adminResponse || '-'}</span></div>
    <div class="row"><span class="label">تاريخ التقديم:</span><span class="val">${req.createdAt?.toDate ? req.createdAt.toDate().toLocaleDateString('ar-YE') : (req.createdAt || '-')}</span></div>
    <script>window.print();window.close();</script>
    </body></html>
  `);
  w.document.close();
}

export default function RequestsInbox({ requests = [] }) {
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [governorateFilter, setGovernorateFilter] = useState('الكل');
  const [selectedReq, setSelectedReq] = useState(null);
  const [newStatus, setNewStatus] = useState('');
  const [adminReply, setAdminReply] = useState('');
  const [isUpdating, setIsUpdating] = useState(false);
  const [copiedId, setCopiedId] = useState(null);
  const [successToast, setSuccessToast] = useState(null);
  const [page, setPage] = useState(1);

  const showToast = (msg) => {
    setSuccessToast(msg);
    setTimeout(() => setSuccessToast(null), 4000);
  };

  // Filtering
  const filtered = useMemo(() => requests.filter(req => {
    const matchSearch =
      (req.fullName || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (req.phone || '').includes(searchTerm) ||
      (req.referenceCode || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (req.idNumber || '').includes(searchTerm) ||
      (req.address || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (req.subject || '').toLowerCase().includes(searchTerm.toLowerCase());

    const matchStatus = statusFilter === 'all' || req.status === statusFilter;
    const matchGov = governorateFilter === 'الكل' || (req.address || '').includes(governorateFilter);

    return matchSearch && matchStatus && matchGov;
  }), [requests, searchTerm, statusFilter, governorateFilter]);

  // Export to Excel / CSV with UTF-8 BOM
  const exportToCsv = () => {
    try {
      if (!filtered || filtered.length === 0) {
        alert('لا توجد طلبات مطابقة للتصدير.');
        return;
      }

      const formatDate = (val) => {
        if (!val) return '';
        try {
          if (val instanceof Date) return val.toLocaleDateString('ar-YE');
          if (typeof val.toDate === 'function') return val.toDate().toLocaleDateString('ar-YE');
          const d = new Date(val);
          if (!isNaN(d.getTime())) return d.toLocaleDateString('ar-YE');
          return String(val);
        } catch (_) {
          return String(val);
        }
      };

      const clean = (val) => {
        if (val === null || val === undefined) return '""';
        return `"${String(val).replace(/"/g, '""')}"`;
      };

      const headers = ['كود التتبع', 'الاسم الكامل', 'رقم الهوية', 'الهاتف', 'العنوان', 'موضوع الطلب', 'الحالة', 'رد الإدارة', 'تاريخ التقديم'];
      const rows = filtered.map(req => {
        const dateStr = formatDate(req.createdAt);
        return [
          clean(req.referenceCode || req.id || ''),
          clean(req.fullName || ''),
          clean(req.idNumber || ''),
          clean(req.phone || ''),
          clean(req.address || ''),
          clean(req.subject || ''),
          clean(req.status || ''),
          clean(req.adminResponse || ''),
          clean(dateStr)
        ].join(',');
      });

      // UTF-8 BOM '\uFEFF' ensures Microsoft Excel opens Arabic text correctly
      const csvContent = '\uFEFF' + [headers.join(','), ...rows].join('\r\n');
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      const fileName = `كشف_طلبات_المساعدة_${new Date().toISOString().slice(0, 10)}.csv`;

      if (window.navigator && window.navigator.msSaveOrOpenBlob) {
        window.navigator.msSaveOrOpenBlob(blob, fileName);
      } else {
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.setAttribute('download', fileName);
        document.body.appendChild(link);
        link.click();
        setTimeout(() => {
          document.body.removeChild(link);
          URL.revokeObjectURL(url);
        }, 200);
      }
      showToast('تم تصدير كشف الطلبات بنجاح إلى ملف Excel / CSV!');
    } catch (err) {
      console.error('Export CSV Error:', err);
      alert('حدث خطأ أثناء تصدير الملف: ' + err.message);
    }
  };

  // Pagination
  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const safePage = Math.min(page, totalPages);
  const pageRows = filtered.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE);

  const handleOpenModal = (req) => {
    setSelectedReq(req);
    setNewStatus(req.status || 'قيد المراجعة');
    setAdminReply(req.adminResponse || '');
  };

  const handleCopy = (code, id) => {
    navigator.clipboard.writeText(code);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const handleSave = async () => {
    if (!selectedReq) return;
    setIsUpdating(true);
    try {
      const historyEntry = {
        status: newStatus,
        note: adminReply.trim() || 'تم تحديث حالة الطلب من قبل الإدارة',
        timestamp: new Date().toISOString()
      };

      const docRef = doc(db, 'assistance_requests', selectedReq.id);
      const updates = {
        status: newStatus,
        adminResponse: adminReply.trim(),
        updatedAt: serverTimestamp(),
        timeline: arrayUnion(historyEntry),
        statusHistory: arrayUnion(historyEntry)
      };

      const res = await safeUpdateDoc(
        updateDoc(docRef, updates),
        'assistance_requests',
        selectedReq.id,
        {
          status: newStatus,
          adminResponse: adminReply.trim(),
          updatedAt: new Date(),
        }
      );

      if (newStatus === 'تمت الموافقة' || newStatus === 'جاهز للصرف') {
        confetti({ particleCount: 80, spread: 60, origin: { y: 0.6 } });
      }

      if (res.isLocal) {
        showToast(`⚠️ تم تحديث الطلب (#${selectedReq.referenceCode || selectedReq.id}) محلياً بنجاح!`);
      } else {
        showToast(`تم تحديث الطلب (#${selectedReq.referenceCode || selectedReq.id}) سحابياً بنجاح!`);
      }
      setSelectedReq(null);
    } catch (e) {
      console.error('Error updating request:', e);
      alert('حدث خطأ أثناء حفظ التحديث: ' + e.message);
    } finally {
      setIsUpdating(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
      {/* Toast */}
      {successToast && (
        <div style={{
          position: 'fixed',
          bottom: '24px',
          left: '24px',
          background: 'var(--primary)',
          color: 'white',
          padding: '12px 20px',
          borderRadius: '12px',
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
          boxShadow: '0 8px 24px rgba(0,0,0,0.3)',
          zIndex: 9999,
          fontWeight: 'bold',
          fontSize: '14px'
        }}>
          <CheckCircle2 size={20} color="#4ade80" />
          <span>{successToast}</span>
        </div>
      )}

      {/* Control Bar: Search, Filters & Export */}
      <div className="zakat-card" style={{ padding: '18px 22px' }}>
        <div style={{ display: 'flex', gap: '14px', flexWrap: 'wrap', alignItems: 'center', justifyContent: 'space-between' }}>
          {/* Search Box */}
          <div style={{ position: 'relative', flex: '1 1 280px' }}>
            <Search size={18} style={{ position: 'absolute', right: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
            <input
              type="text"
              placeholder="البحث بالاسم، الهاتف، كود التتبع، الهوية، المحافظة..."
              value={searchTerm}
              onChange={(e) => { setSearchTerm(e.target.value); setPage(1); }}
              className="form-control"
              style={{ paddingRight: '40px', width: '100%' }}
            />
          </div>

          {/* Filters & Export Action */}
          <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', alignItems: 'center' }}>
            {/* Status Filter */}
            <select
              value={statusFilter}
              onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }}
              className="form-control"
              style={{ minWidth: '160px' }}
            >
              <option value="all">جميع الحالات ({requests.length})</option>
              {statusOptions.map(opt => (
                <option key={opt.value} value={opt.value}>
                  {opt.label} ({requests.filter(r => r.status === opt.value).length})
                </option>
              ))}
            </select>

            {/* Governorate Filter */}
            <select
              value={governorateFilter}
              onChange={(e) => { setGovernorateFilter(e.target.value); setPage(1); }}
              className="form-control"
              style={{ minWidth: '140px' }}
            >
              {governorates.map(g => (
                <option key={g} value={g}>{g === 'الكل' ? 'جميع المحافظات' : g}</option>
              ))}
            </select>

            {/* Export CSV / Excel Button */}
            <button
              onClick={exportToCsv}
              className="btn btn-primary"
              style={{ gap: '6px' }}
              title="تصدير النتائج المفلترة إلى ملف إكسل CSV"
            >
              <Download size={16} />
              <span>تصدير Excel</span>
            </button>
          </div>
        </div>
      </div>

      {/* Requests Table */}
      <div className="zakat-card" style={{ padding: '0', overflow: 'hidden' }}>
        <div style={{ overflowX: 'auto' }}>
          <table className="table" style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: 'rgba(0, 105, 92, 0.08)', borderBottom: '1px solid var(--border-color)' }}>
                <th style={{ padding: '14px 18px', textAlign: 'right' }}>كود التتبع</th>
                <th style={{ padding: '14px 18px', textAlign: 'right' }}>مقدم الطلب</th>
                <th style={{ padding: '14px 18px', textAlign: 'right' }}>الهاتف / المحافظة</th>
                <th style={{ padding: '14px 18px', textAlign: 'right' }}>الموضوع</th>
                <th style={{ padding: '14px 18px', textAlign: 'right' }}>الحالة</th>
                <th style={{ padding: '14px 18px', textAlign: 'center' }}>الإجراءات</th>
              </tr>
            </thead>
            <tbody>
              {pageRows.length === 0 ? (
                <tr>
                  <td colSpan="6" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>
                    لا توجد طلبات مطابقة للمعايير المحددة.
                  </td>
                </tr>
              ) : (
                pageRows.map((req) => (
                  <tr key={req.id} style={{ borderBottom: '1px solid var(--border-color)' }}>
                    <td style={{ padding: '12px 18px', fontWeight: 'bold' }}>
                      <span
                        onClick={() => handleCopy(req.referenceCode || req.id, req.id)}
                        style={{ cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: '6px', color: 'var(--primary-light)' }}
                        title="انقر للنسخ"
                      >
                        {req.referenceCode || req.id.substring(0, 8)}
                        <Copy size={13} />
                      </span>
                      {copiedId === req.id && <span style={{ fontSize: '10px', color: 'var(--gold)', marginRight: '4px' }}>تم النسخ!</span>}
                    </td>
                    <td style={{ padding: '12px 18px' }}>
                      <div style={{ fontWeight: '600' }}>{req.fullName || 'فاعل خير'}</div>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{req.idNumber || '-'}</div>
                    </td>
                    <td style={{ padding: '12px 18px' }}>
                      <div>{req.phone || '-'}</div>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{req.address || '-'}</div>
                    </td>
                    <td style={{ padding: '12px 18px', maxWidth: '240px' }}>
                      <div style={{ fontWeight: '500', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {req.subject || 'طلب مساعدة عام'}
                      </div>
                    </td>
                    <td style={{ padding: '12px 18px' }}>
                      <span className={`badge ${badgeClass(req.status)}`}>
                        {req.status || 'قيد المراجعة'}
                      </span>
                    </td>
                    <td style={{ padding: '12px 18px', textAlign: 'center' }}>
                      <div style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
                        <button
                          onClick={() => handleOpenModal(req)}
                          className="btn btn-sm btn-outline"
                          title="مراجعة وتحديث الطلب"
                        >
                          معالجة
                        </button>
                        <button
                          onClick={() => handlePrint(req)}
                          className="btn btn-sm btn-ghost"
                          title="طباعة الطلب"
                        >
                          <Printer size={15} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Bar */}
        {totalPages > 1 && (
          <div style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            padding: '14px 20px',
            borderTop: '1px solid var(--border-color)',
            background: 'rgba(0,0,0,0.02)'
          }}>
            <span style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>
              عرض {((safePage - 1) * PAGE_SIZE) + 1} - {Math.min(safePage * PAGE_SIZE, filtered.length)} من إجمالي {filtered.length} طلب
            </span>
            <div style={{ display: 'flex', gap: '6px' }}>
              <button
                disabled={safePage <= 1}
                onClick={() => setPage(p => Math.max(1, p - 1))}
                className="btn btn-sm btn-ghost"
              >
                <ChevronRight size={16} />
                <span>السابق</span>
              </button>
              <button
                disabled={safePage >= totalPages}
                onClick={() => setPage(p => Math.min(totalPages, p + 1))}
                className="btn btn-sm btn-ghost"
              >
                <span>التالي</span>
                <ChevronLeft size={16} />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Edit / Review Modal */}
      {selectedReq && (
        <div style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(0, 0, 0, 0.65)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
          padding: '20px'
        }}>
          <div className="zakat-card" style={{ width: '100%', maxWidth: '580px', maxHeight: '90vh', overflowY: 'auto', padding: '24px' }}>
            <h3 style={{ fontSize: '18px', fontWeight: 'bold', marginBottom: '16px', borderBottom: '1px solid var(--border-color)', paddingBottom: '10px' }}>
              معالجة طلب المساعدة (#{selectedReq.referenceCode || selectedReq.id})
            </h3>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '16px', background: 'rgba(0,0,0,0.03)', padding: '14px', borderRadius: '10px' }}>
              <div><strong>المستفيد:</strong> {selectedReq.fullName}</div>
              <div><strong>الهاتف:</strong> {selectedReq.phone}</div>
              <div><strong>رقم الهوية:</strong> {selectedReq.idNumber || '-'}</div>
              <div><strong>العنوان:</strong> {selectedReq.address || '-'}</div>
            </div>

            <div style={{ marginBottom: '16px' }}>
              <div style={{ fontWeight: 'bold', marginBottom: '4px' }}>موضوع وتفاصيل الطلب:</div>
              <div style={{ background: 'var(--bg-main)', padding: '12px', borderRadius: '8px', fontSize: '13px', lineHeight: '1.6' }}>
                <p style={{ fontWeight: 'bold', margin: '0 0 6px 0' }}>{selectedReq.subject}</p>
                <p style={{ margin: 0 }}>{selectedReq.details}</p>
              </div>
            </div>

            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', fontWeight: 'bold', marginBottom: '6px' }}>تحديث حالة الطلب:</label>
              <select
                value={newStatus}
                onChange={(e) => setNewStatus(e.target.value)}
                className="form-control"
                style={{ width: '100%' }}
              >
                {statusOptions.map(opt => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </div>

            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', fontWeight: 'bold', marginBottom: '6px' }}>رد الهيئة العامة للزكاة وملاحظات اللجنة:</label>
              <textarea
                rows="3"
                value={adminReply}
                onChange={(e) => setAdminReply(e.target.value)}
                placeholder="أدخل رسالة التوجيه للمستفيد (تظهر مباشرة في تطبيق الجوال لدى المواطن)..."
                className="form-control"
                style={{ width: '100%', resize: 'vertical' }}
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
              <button
                onClick={() => setSelectedReq(null)}
                className="btn btn-outline"
                disabled={isUpdating}
              >
                إلغاء
              </button>
              <button
                onClick={handleSave}
                className="btn btn-primary"
                disabled={isUpdating}
              >
                {isUpdating ? 'جاري الحفظ...' : 'حفظ وإرسال التحديث للمواطن'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
