import React from 'react';
import { 
  LayoutDashboard, 
  Inbox, 
  Wheat, 
  Megaphone, 
  Settings, 
  LogOut, 
  ShieldCheck,
  Building2,
  X
} from 'lucide-react';

export default function Sidebar({ 
  currentTab, 
  setCurrentTab, 
  pendingCount = 0, 
  isOpen, 
  onClose,
  onLogout 
}) {
  const menuItems = [
    { id: 'dashboard', label: 'الرئيسية والمؤشرات', icon: LayoutDashboard },
    { 
      id: 'requests', 
      label: 'طلبات المساعدة', 
      icon: Inbox,
      badge: pendingCount > 0 ? pendingCount : null 
    },
    { id: 'prices', label: 'أسعار الفطرة والنصاب', icon: Wheat },
    { id: 'announcements', label: 'الإعلانات والتعميمات', icon: Megaphone },
    { id: 'settings', label: 'الحسابات وإعدادات النظام', icon: Settings },
  ];

  return (
    <>
      {isOpen && (
        <div 
          onClick={onClose}
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0,0,0,0.6)',
            backdropFilter: 'blur(4px)',
            zIndex: 95
          }}
        />
      )}

      <aside className={`admin-sidebar ${isOpen ? 'open' : ''}`}>
        {/* Brand Header */}
        <div style={{
          padding: '24px 20px',
          borderBottom: '1px solid var(--border-color)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{
              width: '42px',
              height: '42px',
              borderRadius: '12px',
              background: 'linear-gradient(135deg, var(--primary), var(--gold-dark))',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#fff',
              boxShadow: '0 4px 12px rgba(0, 105, 92, 0.4)'
            }}>
              <Building2 size={24} />
            </div>
            <div>
              <h2 style={{ fontSize: '15px', fontWeight: '800', margin: 0, color: '#fff' }}>
                الهيئة العامة للزكاة
              </h2>
              <span style={{ fontSize: '11px', color: 'var(--gold)', fontWeight: '600' }}>
                بوابة الإدارة المركزية
              </span>
            </div>
          </div>
          {onClose && (
            <button 
              onClick={onClose} 
              className="btn btn-outline btn-sm"
              style={{ padding: '6px', border: 'none', display: 'none' }}
            >
              <X size={18} />
            </button>
          )}
        </div>

        {/* Navigation List */}
        <nav style={{ padding: '16px 12px', flex: 1, display: 'flex', flexDirection: 'column', gap: '6px' }}>
          {menuItems.map(item => {
            const Icon = item.icon;
            const isActive = currentTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => {
                  setCurrentTab(item.id);
                  if (onClose) onClose();
                }}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '12px 16px',
                  borderRadius: '12px',
                  border: 'none',
                  background: isActive 
                    ? 'linear-gradient(135deg, rgba(0, 105, 92, 0.35), rgba(212, 175, 55, 0.15))' 
                    : 'transparent',
                  color: isActive ? '#fff' : 'var(--text-muted)',
                  fontWeight: isActive ? '700' : '600',
                  fontSize: '13.5px',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease',
                  borderRight: isActive ? '4px solid var(--gold)' : '4px solid transparent'
                }}
                onMouseEnter={e => {
                  if (!isActive) e.currentTarget.style.background = 'rgba(255, 255, 255, 0.04)';
                }}
                onMouseLeave={e => {
                  if (!isActive) e.currentTarget.style.background = 'transparent';
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <Icon size={19} color={isActive ? 'var(--gold)' : 'var(--text-muted)'} />
                  <span>{item.label}</span>
                </div>
                {item.badge && (
                  <span style={{
                    background: 'var(--warning)',
                    color: '#000',
                    fontSize: '11px',
                    fontWeight: '800',
                    padding: '2px 8px',
                    borderRadius: '12px'
                  }}>
                    {item.badge}
                  </span>
                )}
              </button>
            );
          })}
        </nav>

        {/* Footer info & Logout */}
        <div style={{
          padding: '16px',
          borderTop: '1px solid var(--border-color)',
          display: 'flex',
          flexDirection: 'column',
          gap: '12px'
        }}>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
            padding: '10px 12px',
            background: 'rgba(255, 255, 255, 0.03)',
            borderRadius: '10px'
          }}>
            <ShieldCheck size={20} color="var(--success)" />
            <div>
              <div style={{ fontSize: '12px', fontWeight: '700', color: '#fff' }}>
                المشرف العام (Admin)
              </div>
              <div style={{ fontSize: '10.5px', color: 'var(--text-dim)' }}>
                متصل بالنظام السحابي
              </div>
            </div>
          </div>

          <button 
            onClick={onLogout}
            className="btn btn-outline btn-sm"
            style={{ width: '100%', justifyContent: 'center', gap: '8px', color: '#fca5a5' }}
          >
            <LogOut size={16} />
            <span>تسجيل الخروج</span>
          </button>
        </div>
      </aside>
    </>
  );
}
