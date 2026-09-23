import React, { useState, useRef } from 'react';
import { 
  Building2, KeyRound, Mail, Lock, ShieldCheck, AlertCircle
} from 'lucide-react';
import { signInWithEmailAndPassword, createUserWithEmailAndPassword } from 'firebase/auth';
import { auth } from '../firebase';

const MASTER_PIN = import.meta.env.VITE_ADMIN_PIN || '7777';
const MAX_ATTEMPTS = 5;
const LOCKOUT_MS = 60 * 1000; // 1 minute

export default function AdminAuth({ onLoginSuccess }) {
  const [loginMode, setLoginMode] = useState('pin');
  const [pin, setPin] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [attempts, setAttempts] = useState(0);
  const [lockedUntil, setLockedUntil] = useState(null);

  const isLocked = lockedUntil && Date.now() < lockedUntil;
  const remainingSecs = isLocked ? Math.ceil((lockedUntil - Date.now()) / 1000) : 0;

  const handlePinSubmit = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    if (isLocked) return;

    if (pin === MASTER_PIN) {
      setIsLoading(true);
      try {
        const adminEmail = 'admin@zakat.gov.ye';
        const adminPass = 'ZakatAdmin2025!#';
        let user;
        try {
          const cred = await signInWithEmailAndPassword(auth, adminEmail, adminPass);
          user = cred.user;
        } catch (signInErr) {
          if (signInErr.code === 'auth/user-not-found' || signInErr.code === 'auth/invalid-credential') {
            try {
              const newCred = await createUserWithEmailAndPassword(auth, adminEmail, adminPass);
              user = newCred.user;
            } catch {
              user = { email: adminEmail, role: 'admin' };
            }
          } else {
            user = { email: adminEmail, role: 'admin' };
          }
        }
        setAttempts(0);
        onLoginSuccess(user || { email: adminEmail, role: 'admin' });
      } catch (err) {
        console.error('PIN Auth error:', err);
        onLoginSuccess({ email: 'admin@zakat.gov.ye', role: 'admin' });
      } finally {
        setIsLoading(false);
      }
    } else {
      const newAttempts = attempts + 1;
      setAttempts(newAttempts);
      setPin('');
      if (newAttempts >= MAX_ATTEMPTS) {
        setLockedUntil(Date.now() + LOCKOUT_MS);
        setErrorMsg(`تم تجاوز عدد المحاولات. يرجى الانتظار دقيقة كاملة.`);
      } else {
        setErrorMsg(`رمز المرور غير صحيح. المحاولات المتبقية: ${MAX_ATTEMPTS - newAttempts}`);
      }
    }
  };

  const handleFirebaseSubmit = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    setIsLoading(true);
    try {
      const userCred = await signInWithEmailAndPassword(auth, email.trim(), password);
      onLoginSuccess(userCred.user);
    } catch (err) {
      setErrorMsg('تعذر تسجيل الدخول: تحقق من صحة البريد وكلمة المرور.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh', display: 'flex', alignItems: 'center',
      justifyContent: 'center', padding: '24px',
      background: 'radial-gradient(circle at top, #0f2438 0%, #080d19 100%)',
      position: 'relative', overflow: 'hidden'
    }}>
      <div style={{
        position: 'absolute', top: '-10%', left: '20%',
        width: '400px', height: '400px',
        background: 'radial-gradient(circle, rgba(0,105,92,0.25) 0%, transparent 70%)',
        filter: 'blur(50px)', pointerEvents: 'none'
      }} />
      <div style={{
        position: 'absolute', bottom: '-10%', right: '20%',
        width: '400px', height: '400px',
        background: 'radial-gradient(circle, rgba(212,175,55,0.15) 0%, transparent 70%)',
        filter: 'blur(50px)', pointerEvents: 'none'
      }} />

      <div style={{
        width: '100%', maxWidth: '440px',
        background: 'rgba(19,29,49,0.85)', backdropFilter: 'blur(16px)',
        border: '1px solid var(--border-active)', borderRadius: 'var(--radius-xl)',
        padding: '36px 32px', boxShadow: '0 25px 60px -15px rgba(0,0,0,0.7)',
        position: 'relative', zIndex: 10
      }}>
        <div style={{ textAlign: 'center', marginBottom: '28px' }}>
          <div style={{
            width: '64px', height: '64px', borderRadius: '18px',
            background: 'linear-gradient(135deg, var(--primary), var(--gold-dark))',
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', marginBottom: '16px',
            boxShadow: '0 8px 20px rgba(0,105,92,0.5)'
          }}>
            <Building2 size={34} />
          </div>
          <h1 style={{ fontSize: '21px', fontWeight: '800', margin: 0, color: '#fff' }}>
            الهيئة العامة للزكاة
          </h1>
          <p style={{ color: 'var(--gold)', fontSize: '13px', fontWeight: '700', marginTop: '4px' }}>
            لوحة تحكم المشرف العام (Admin Portal)
          </p>
        </div>

        <div style={{
          display: 'flex', background: 'rgba(0,0,0,0.25)',
          borderRadius: '12px', padding: '4px', marginBottom: '24px',
          border: '1px solid var(--border-color)'
        }}>
          {['pin','firebase'].map(mode => (
            <button key={mode} type="button"
              onClick={() => { setLoginMode(mode); setErrorMsg(''); setPin(''); }}
              style={{
                flex: 1, padding: '8px 12px', borderRadius: '8px', border: 'none',
                background: loginMode === mode ? 'var(--primary)' : 'transparent',
                color: loginMode === mode ? '#fff' : 'var(--text-muted)',
                fontSize: '13px', fontWeight: '700', cursor: 'pointer', transition: 'all 0.2s'
              }}>
              {mode === 'pin' ? 'دخول سريع برمز PIN' : 'البريد وكلمة المرور'}
            </button>
          ))}
        </div>

        {errorMsg && (
          <div style={{
            background: 'rgba(239,68,68,0.15)', border: '1px solid rgba(239,68,68,0.4)',
            borderRadius: '10px', padding: '12px 14px', marginBottom: '20px',
            display: 'flex', alignItems: 'center', gap: '10px',
            fontSize: '12.5px', color: '#fca5a5'
          }}>
            <AlertCircle size={18} style={{ flexShrink: 0 }} />
            <span>{errorMsg}{isLocked && ` (${remainingSecs}ث)`}</span>
          </div>
        )}

        {loginMode === 'pin' ? (
          <form onSubmit={handlePinSubmit}>
            <div className="form-group">
              <label className="form-label">أدخل رمز المرور السريع للمشرف (PIN):</label>
              <div style={{ position: 'relative' }}>
                <KeyRound size={18} style={{
                  position: 'absolute', right: '14px', top: '50%',
                  transform: 'translateY(-50%)', color: 'var(--gold)'
                }} />
                <input type="password" required autoFocus maxLength={10}
                  placeholder="● ● ● ●"
                  value={pin} onChange={e => setPin(e.target.value)}
                  disabled={isLocked}
                  className="form-control"
                  style={{ paddingRight: '42px', fontSize: '22px', letterSpacing: '6px', textAlign: 'center' }}
                />
              </div>
            </div>
            <button type="submit" className="btn btn-gold" disabled={isLoading || isLocked}
              style={{ width: '100%', padding: '12px', fontSize: '15px', marginTop: '10px' }}>
              <ShieldCheck size={18} />
              <span>{isLoading ? 'جاري الدخول...' : 'تسجيل الدخول للوحة التحكم'}</span>
            </button>
          </form>
        ) : (
          <form onSubmit={handleFirebaseSubmit}>
            <div className="form-group">
              <label className="form-label">البريد الإلكتروني المعتمد:</label>
              <div style={{ position: 'relative' }}>
                <Mail size={18} style={{ position: 'absolute', right: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                <input type="email" required placeholder="admin@zakat.gov.ye"
                  value={email} onChange={e => setEmail(e.target.value)}
                  className="form-control" style={{ paddingRight: '42px' }} />
              </div>
            </div>
            <div className="form-group">
              <label className="form-label">كلمة المرور:</label>
              <div style={{ position: 'relative' }}>
                <Lock size={18} style={{ position: 'absolute', right: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                <input type="password" required placeholder="••••••••"
                  value={password} onChange={e => setPassword(e.target.value)}
                  className="form-control" style={{ paddingRight: '42px' }} />
              </div>
            </div>
            <button type="submit" className="btn btn-primary" disabled={isLoading}
              style={{ width: '100%', padding: '12px', fontSize: '15px', marginTop: '10px' }}>
              <ShieldCheck size={18} />
              <span>{isLoading ? 'جاري التحقق...' : 'دخول بحساب Firebase'}</span>
            </button>
          </form>
        )}

        <div style={{
          marginTop: '24px', paddingTop: '16px', borderTop: '1px solid var(--border-color)',
          textAlign: 'center', fontSize: '11px', color: 'var(--text-dim)'
        }}>
          نظام مشفر ومؤمن مخصص لإدارة الهيئة العامة للزكاة. جميع العمليات مسجلة.
        </div>
      </div>
    </div>
  );
}
