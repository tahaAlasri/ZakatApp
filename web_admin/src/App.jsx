import React, { useState, useEffect, useRef, useCallback } from 'react';
import { collection, onSnapshot, query, orderBy, doc } from 'firebase/firestore';
import { signOut } from 'firebase/auth';
import { auth, db } from './firebase';
import Sidebar from './components/Sidebar';
import DashboardHome from './pages/DashboardHome';
import RequestsInbox from './pages/RequestsInbox';
import ZakatPrices from './pages/ZakatPrices';
import Announcements from './pages/Announcements';
import AppSettings from './pages/AppSettings';
import AdminAuth from './pages/AdminAuth';
import { Menu, Bell, Volume2, VolumeX } from 'lucide-react';
import { getLocalCollection, getLocalDoc } from './utils/firestoreSafe';

export default function App() {
  // عند الدخول للموقع يتم دائماً طلب تسجيل الدخول أولاً في كل جلسة جديدة
  const [isAuthenticated, setIsAuthenticated] = useState(() => {
    try {
      // تنظيف أي بيانات دخول قديمة ودائمة في localStorage
      localStorage.removeItem('zakat_admin_auth');
      localStorage.removeItem('zakat_admin_user');
      return sessionStorage.getItem('zakat_admin_auth') === 'true';
    } catch {
      return false;
    }
  });

  const [adminUser, setAdminUser] = useState(() => {
    try {
      return JSON.parse(sessionStorage.getItem('zakat_admin_user')) || null;
    } catch {
      return null;
    }
  });

  const [currentTab, setCurrentTab] = useState('dashboard');
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);

  const [requests, setRequests] = useState(() => getLocalCollection('assistance_requests'));
  const [announcements, setAnnouncements] = useState(() => getLocalCollection('announcements'));
  const [wheatPrice, setWheatPrice] = useState(() => {
    const loc = getLocalDoc('app_config', 'zakat_prices');
    return loc?.wheatBagPriceYER || 24000;
  });
  const [soundEnabled, setSoundEnabled] = useState(true);

  // Use refs to avoid stale closure in onSnapshot callbacks
  const requestsRef = useRef([]);
  const soundEnabledRef = useRef(true);
  const isFirstLoadRef = useRef(true);

  useEffect(() => { soundEnabledRef.current = soundEnabled; }, [soundEnabled]);

  const playChime = useCallback(() => {
    if (!soundEnabledRef.current) return;
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain); gain.connect(ctx.destination);
      osc.type = 'sine';
      osc.frequency.setValueAtTime(587.33, ctx.currentTime);
      osc.frequency.setValueAtTime(880, ctx.currentTime + 0.15);
      gain.gain.setValueAtTime(0.3, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.5);
      osc.start(); osc.stop(ctx.currentTime + 0.5);
    } catch (e) { console.log('Audio error:', e); }
  }, []);

  useEffect(() => {
    if (!isAuthenticated) return;

    // 1. Requests
    isFirstLoadRef.current = true;
    let unsubReq = () => {};
    try {
      const reqQ = query(collection(db, 'assistance_requests'), orderBy('createdAt', 'desc'));
      unsubReq = onSnapshot(reqQ, (snap) => {
        const loaded = snap.docs.map(d => ({
          id: d.id, ...d.data(),
          createdAt: d.data().createdAt?.toDate ? d.data().createdAt.toDate() : new Date()
        }));
        if (!isFirstLoadRef.current && loaded.length > requestsRef.current.length) {
          playChime();
        }
        isFirstLoadRef.current = false;
        requestsRef.current = loaded;
        setRequests(loaded);
      }, err => {
        console.warn('Requests onSnapshot:', err.message);
        const fallback = getLocalCollection('assistance_requests');
        if (fallback.length > 0) setRequests(fallback);
      });
    } catch (err) {
      console.warn('Requests init error:', err);
    }

    // 2. Announcements
    let unsubAnn = () => {};
    try {
      const annQ = query(collection(db, 'announcements'), orderBy('createdAt', 'desc'));
      unsubAnn = onSnapshot(annQ, (snap) => {
        const loaded = snap.docs.map(d => ({
          id: d.id, ...d.data(),
          createdAt: d.data().createdAt?.toDate ? d.data().createdAt.toDate() : new Date()
        }));
        setAnnouncements(loaded);
      }, err => {
        console.warn('Announcements onSnapshot:', err.message);
        const fallback = getLocalCollection('announcements');
        if (fallback.length > 0) setAnnouncements(fallback);
      });
    } catch (err) {
      console.warn('Announcements init error:', err);
    }

    // 3. Prices
    let unsubPrices = () => {};
    try {
      unsubPrices = onSnapshot(doc(db, 'app_config', 'zakat_prices'), (snap) => {
        if (snap.exists() && snap.data().wheatBagPriceYER) {
          setWheatPrice(snap.data().wheatBagPriceYER);
        }
      }, err => {
        console.warn('Prices onSnapshot:', err.message);
      });
    } catch (err) {
      console.warn('Prices init error:', err);
    }

    return () => { unsubReq(); unsubAnn(); unsubPrices(); };
  }, [isAuthenticated, playChime]);

  const handleLoginSuccess = (user) => {
    setIsAuthenticated(true);
    setAdminUser(user);
    try {
      sessionStorage.setItem('zakat_admin_auth', 'true');
      sessionStorage.setItem('zakat_admin_user', JSON.stringify(user));
    } catch (e) {
      console.warn('Session storage error:', e);
    }
  };

  const handleLogout = async () => {
    try {
      await signOut(auth);
    } catch (e) {
      console.warn('Sign out error:', e);
    }
    setIsAuthenticated(false);
    setAdminUser(null);
    try {
      sessionStorage.removeItem('zakat_admin_auth');
      sessionStorage.removeItem('zakat_admin_user');
      localStorage.removeItem('zakat_admin_auth');
      localStorage.removeItem('zakat_admin_user');
    } catch (e) {
      console.warn('Storage clear error:', e);
    }
  };

  if (!isAuthenticated) return <AdminAuth onLoginSuccess={handleLoginSuccess} />;

  const pendingCount = requests.filter(r =>
    r.status === 'قيد المراجعة' || r.status === 'pending'
  ).length;

  return (
    <div className="admin-layout">
      <Sidebar
        currentTab={currentTab} setCurrentTab={setCurrentTab}
        pendingCount={pendingCount} isOpen={isSidebarOpen}
        onClose={() => setIsSidebarOpen(false)} onLogout={handleLogout}
      />

      <div className="admin-main">
        <header className="admin-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            <button
              onClick={() => setIsSidebarOpen(true)}
              className="btn btn-outline btn-sm mobile-menu-btn"
              style={{ padding: '8px' }}
              aria-label="القائمة"
            >
              <Menu size={20} />
            </button>

            <div style={{
              display: 'flex', alignItems: 'center', gap: '8px',
              padding: '6px 12px',
              background: 'rgba(16,185,129,0.1)',
              border: '1px solid rgba(16,185,129,0.3)',
              borderRadius: '20px', fontSize: '12px', color: '#6ee7b7'
            }}>
              <span className="pulse-dot" />
              <span style={{ fontWeight: '700' }}>متصل بالسحابة (مباشر)</span>
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <button
              onClick={() => setSoundEnabled(v => !v)}
              className="btn btn-outline btn-sm"
              title={soundEnabled ? 'صوت التنبيهات مفعل' : 'مكتوم'}
              style={{ color: soundEnabled ? 'var(--gold)' : 'var(--text-dim)' }}
            >
              {soundEnabled ? <Volume2 size={16} /> : <VolumeX size={16} />}
              <span style={{ fontSize: '11.5px' }}>{soundEnabled ? 'تنبيه صوتي' : 'مكتوم'}</span>
            </button>

            <button
              onClick={() => setCurrentTab('requests')}
              className="btn btn-outline btn-sm"
              style={{
                borderColor: pendingCount > 0 ? 'var(--warning)' : 'var(--border-color)',
                color: pendingCount > 0 ? 'var(--warning)' : 'inherit'
              }}
            >
              <Bell size={16} />
              <span>الطلبات الجديدة ({pendingCount})</span>
            </button>
          </div>
        </header>

        <main className="admin-content">
          {currentTab === 'dashboard' && (
            <DashboardHome
              requests={requests} wheatPrice={wheatPrice}
              announcements={announcements.filter(a => a.isActive)}
              onNavigate={setCurrentTab}
            />
          )}
          {currentTab === 'requests' && (
            <RequestsInbox requests={requests} />
          )}
          {currentTab === 'prices' && (
            <ZakatPrices initialWheatPrice={wheatPrice} onPriceSaved={setWheatPrice} />
          )}
          {currentTab === 'announcements' && (
            <Announcements announcements={announcements} />
          )}
          {currentTab === 'settings' && <AppSettings />}
        </main>
      </div>
    </div>
  );
}
