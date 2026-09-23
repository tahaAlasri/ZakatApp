import React, { useMemo } from 'react';
import { 
  Inbox, 
  CheckCircle2, 
  Clock, 
  Wheat, 
  TrendingUp, 
  Megaphone,
  ArrowRight,
  ShieldAlert,
  Calendar,
  PieChart,
  MapPin,
  FileCheck
} from 'lucide-react';

export default function DashboardHome({ 
  requests = [], 
  wheatPrice = 24000, 
  announcements = [], 
  onNavigate 
}) {
  const pendingRequests = requests.filter(r => r.status === 'قيد المراجعة' || r.status === 'pending');
  const reviewRequests = requests.filter(r => r.status === 'قيد الدراسة' || r.status === 'under_review');
  const approvedRequests = requests.filter(r => r.status === 'تمت الموافقة' || r.status === 'approved');
  const completedRequests = requests.filter(r => r.status === 'جاهز للصرف' || r.status === 'completed');
  const rejectedRequests = requests.filter(r => r.status === 'مرفوض' || r.status === 'rejected');

  const totalProcessed = approvedRequests.length + completedRequests.length + rejectedRequests.length;
  const resolutionRate = requests.length > 0 ? Math.round((totalProcessed / requests.length) * 100) : 100;

  // Group requests by governorate / province
  const topGovernorates = useMemo(() => {
    const map = {};
    requests.forEach(r => {
      const addr = (r.address || 'أخرى').trim();
      const gov = addr.split(' ')[0] || 'غير محدد';
      map[gov] = (map[gov] || 0) + 1;
    });
    return Object.entries(map)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5);
  }, [requests]);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      {/* Welcome Banner */}
      <div style={{
        background: 'linear-gradient(135deg, rgba(0, 105, 92, 0.4), rgba(212, 175, 55, 0.2))',
        border: '1px solid var(--border-active)',
        borderRadius: 'var(--radius-lg)',
        padding: '28px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: '20px'
      }}>
        <div>
          <span style={{ 
            background: 'rgba(212, 175, 55, 0.2)', 
            color: 'var(--gold)', 
            padding: '4px 12px', 
            borderRadius: '20px', 
            fontSize: '12px', 
            fontWeight: '700' 
          }}>
            نظام الربط الإلكتروني المباشر
          </span>
          <h1 style={{ fontSize: '24px', fontWeight: '800', marginTop: '10px', marginBottom: '6px' }}>
            مرحباً بك في لوحة تحكم الهيئة العامة للزكاة
          </h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '13.5px', maxWidth: '600px', lineHeight: '1.6' }}>
            يمكنك متابعة طلبات المساعدة الواردة من تطبيق الجوال لحظياً، وتحديث أسعار زكاة الفطرة والنصاب، وتصدير كشوفات الإكسل ونشر التعميمات للمواطنين.
          </p>
        </div>

        <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
          <button 
            onClick={() => onNavigate('requests')}
            className="btn btn-primary"
          >
            <Inbox size={18} />
            <span>صندوق الطلبات ({pendingRequests.length})</span>
          </button>
          <button 
            onClick={() => onNavigate('prices')}
            className="btn btn-gold"
          >
            <Wheat size={18} />
            <span>تسعيرة الفطرة ({wheatPrice.toLocaleString()} ر.ي)</span>
          </button>
        </div>
      </div>

      {/* KPI Stats Cards */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
        gap: '16px'
      }}>
        {/* Total Requests */}
        <div className="zakat-card stat-widget">
          <div className="stat-icon" style={{ background: 'rgba(0, 105, 92, 0.2)', color: 'var(--primary-light)' }}>
            <Inbox size={26} />
          </div>
          <div>
            <div className="stat-value">{requests.length}</div>
            <div className="stat-label">إجمالي الطلبات الواردة</div>
          </div>
        </div>

        {/* Pending Requests */}
        <div className="zakat-card stat-widget" style={{ borderRight: '4px solid var(--warning)' }}>
          <div className="stat-icon" style={{ background: 'rgba(245, 158, 11, 0.2)', color: 'var(--warning)' }}>
            <Clock size={26} />
          </div>
          <div>
            <div className="stat-value">{pendingRequests.length}</div>
            <div className="stat-label">طلبات قيد المراجعة</div>
          </div>
        </div>

        {/* Approved Requests */}
        <div className="zakat-card stat-widget" style={{ borderRight: '4px solid var(--success)' }}>
          <div className="stat-icon" style={{ background: 'rgba(16, 185, 129, 0.2)', color: 'var(--success)' }}>
            <CheckCircle2 size={26} />
          </div>
          <div>
            <div className="stat-value">{approvedRequests.length + completedRequests.length}</div>
            <div className="stat-label">طلبات معتمدة ومكتملة</div>
          </div>
        </div>

        {/* Resolution Rate */}
        <div className="zakat-card stat-widget" style={{ borderRight: '4px solid var(--gold)' }}>
          <div className="stat-icon" style={{ background: 'rgba(212, 175, 55, 0.2)', color: 'var(--gold)' }}>
            <TrendingUp size={26} />
          </div>
          <div>
            <div className="stat-value" style={{ fontSize: '22px' }}>
              {resolutionRate}%
            </div>
            <div className="stat-label">نسبة إنجاز ومعالجة الطلبات</div>
          </div>
        </div>
      </div>

      {/* Analytics Breakdown Card */}
      <div className="zakat-card" style={{ padding: '20px' }}>
        <h3 style={{ fontSize: '16px', fontWeight: 'bold', marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
          <PieChart size={18} color="var(--primary-light)" />
          <span>التوزيع الإحصائي لحالات الطلبات</span>
        </h3>
        
        <div style={{ display: 'flex', height: '14px', borderRadius: '7px', overflow: 'hidden', background: 'rgba(255,255,255,0.06)', marginBottom: '16px' }}>
          {requests.length > 0 ? (
            <>
              <div title={`معتمد: ${approvedRequests.length + completedRequests.length}`} style={{ width: `${((approvedRequests.length + completedRequests.length) / requests.length) * 100}%`, background: '#10b981' }} />
              <div title={`قيد الدراسة: ${reviewRequests.length}`} style={{ width: `${(reviewRequests.length / requests.length) * 100}%`, background: '#3b82f6' }} />
              <div title={`قيد المراجعة: ${pendingRequests.length}`} style={{ width: `${(pendingRequests.length / requests.length) * 100}%`, background: '#f59e0b' }} />
              <div title={`مرفوض: ${rejectedRequests.length}`} style={{ width: `${(rejectedRequests.length / requests.length) * 100}%`, background: '#ef4444' }} />
            </>
          ) : (
            <div style={{ width: '100%', background: 'rgba(255,255,255,0.1)' }} />
          )}
        </div>

        <div style={{ display: 'flex', gap: '20px', flexWrap: 'wrap', fontSize: '12px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <span style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#10b981' }} />
            <span>معتمد وجاهز للصرف: {approvedRequests.length + completedRequests.length}</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <span style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#3b82f6' }} />
            <span>قيد الدراسة الميدانية: {reviewRequests.length}</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <span style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#f59e0b' }} />
            <span>قيد المراجعة الأولية: {pendingRequests.length}</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <span style={{ width: '10px', height: '10px', borderRadius: '50%', background: '#ef4444' }} />
            <span>اعتذار / مرفوض: {rejectedRequests.length}</span>
          </div>
        </div>
      </div>

      {/* Grid: Recent Requests & Announcements */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))',
        gap: '20px'
      }}>
        {/* Recent Assistance Requests */}
        <div className="zakat-card">
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: '18px',
            borderBottom: '1px solid var(--border-color)',
            paddingBottom: '12px'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Inbox size={20} color="var(--gold)" />
              <h3 style={{ fontSize: '16px', fontWeight: '700', margin: 0 }}>
                أحدث طلبات المساعدة الواردة
              </h3>
            </div>
            <button 
              onClick={() => onNavigate('requests')}
              className="btn btn-outline btn-sm"
              style={{ fontSize: '11.5px' }}
            >
              عرض الكل
              <ArrowRight size={14} />
            </button>
          </div>

          {requests.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '36px 12px', color: 'var(--text-muted)' }}>
              لا توجد طلبات مساعدة واردة حتى الآن.
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {requests.slice(0, 5).map(req => {
                let badgeClass = 'badge-pending';
                if (req.status === 'تمت الموافقة' || req.status === 'approved') badgeClass = 'badge-approved';
                if (req.status === 'مرفوض' || req.status === 'rejected') badgeClass = 'badge-rejected';
                if (req.status === 'جاهز للصرف' || req.status === 'completed') badgeClass = 'badge-completed';
                if (req.status === 'قيد الدراسة' || req.status === 'under_review') badgeClass = 'badge-review';

                return (
                  <div 
                    key={req.id}
                    onClick={() => onNavigate('requests')}
                    style={{
                      padding: '12px 14px',
                      background: 'rgba(255, 255, 255, 0.02)',
                      borderRadius: '10px',
                      border: '1px solid var(--border-color)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      cursor: 'pointer',
                      transition: 'all 0.2s ease'
                    }}
                    onMouseEnter={e => e.currentTarget.style.background = 'var(--bg-card-hover)'}
                    onMouseLeave={e => e.currentTarget.style.background = 'rgba(255, 255, 255, 0.02)'}
                  >
                    <div>
                      <div style={{ fontWeight: '700', fontSize: '13.5px', marginBottom: '3px' }}>
                        {req.fullName}
                      </div>
                      <div style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>
                        {req.subject} • {req.referenceCode || req.id}
                      </div>
                    </div>

                    <span className={`badge ${badgeClass}`}>
                      {req.status}
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Live Active Announcements */}
        <div className="zakat-card">
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: '18px',
            borderBottom: '1px solid var(--border-color)',
            paddingBottom: '12px'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Megaphone size={20} color="var(--primary-light)" />
              <h3 style={{ fontSize: '16px', fontWeight: '700', margin: 0 }}>
                الإعلانات المنشورة حالياً في التطبيق
              </h3>
            </div>
            <button 
              onClick={() => onNavigate('announcements')}
              className="btn btn-outline btn-sm"
              style={{ fontSize: '11.5px' }}
            >
              إدارة الإعلانات
              <ArrowRight size={14} />
            </button>
          </div>

          {announcements.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '36px 12px', color: 'var(--text-muted)' }}>
              لا توجد إعلانات منشورة حالياً. يمكنك إضافة إعلان جديد ليظهر في الصفحة الرئيسية للتطبيق.
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              {announcements.slice(0, 4).map(ann => (
                <div 
                  key={ann.id}
                  style={{
                    padding: '14px',
                    background: ann.priority === 'urgent' 
                      ? 'rgba(239, 68, 68, 0.08)' 
                      : 'rgba(255, 255, 255, 0.02)',
                    borderRadius: '12px',
                    border: ann.priority === 'urgent' 
                      ? '1px solid rgba(239, 68, 68, 0.3)' 
                      : '1px solid var(--border-color)'
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                    <span style={{ 
                      fontSize: '11px', 
                      fontWeight: '700', 
                      color: ann.priority === 'urgent' ? 'var(--error)' : 'var(--gold)' 
                    }}>
                      {ann.priority === 'urgent' ? '🚨 [عاجل]' : '📢 [تعميم عام]'}
                    </span>
                    <span style={{ fontSize: '11px', color: 'var(--text-dim)' }}>
                      منشور ونشط
                    </span>
                  </div>
                  <div style={{ fontWeight: '700', fontSize: '13.5px', marginBottom: '4px' }}>
                    {ann.title}
                  </div>
                  <div style={{ fontSize: '12px', color: 'var(--text-muted)', lineHeight: '1.4' }}>
                    {ann.content}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
