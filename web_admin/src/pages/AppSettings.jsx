import React, { useState, useEffect } from 'react';
import { 
  Building, 
  CreditCard, 
  PhoneCall, 
  Settings, 
  Save, 
  CheckCircle2, 
  AlertTriangle,
  Layers,
  Wrench,
  Smartphone,
  Plus,
  Trash2
} from 'lucide-react';
import { doc, getDoc, setDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../firebase';
import { safeSetDoc, getLocalDoc, withTimeout } from '../utils/firestoreSafe';

export default function AppSettings() {
  const [bankAccounts, setBankAccounts] = useState([
    { id: 1, bankName: 'بنك التسليف التعاوني والزراعي (CAC Bank)', accountNum: '1001-234567-001', currency: 'ريال يمني' },
    { id: 2, bankName: 'بنك الكريمي للتمويل الأصغر الإسلامي', accountNum: '300-8877665', currency: 'ريال يمني' },
    { id: 3, bankName: 'الهيئة العامة للبريد والتوفير البريدي', accountNum: 'الحساب الموحد: 1111', currency: 'ريال يمني' },
    { id: 4, bankName: 'محفظة جيب / كاش الإلكترونية', accountNum: '777000111', currency: 'ريال يمني' },
    { id: 5, bankName: 'محفظة ون كاش (OneCash)', accountNum: '777000222', currency: 'ريال يمني' },
    { id: 6, bankName: 'محفظة فلوسك (بنك اليمن والكويت)', accountNum: '50050011', currency: 'ريال يمني' },
    { id: 7, bankName: 'بنك التضامن الإسلامي', accountNum: '21008899', currency: 'ريال يمني' },
    { id: 8, bankName: 'محفظة جوالي (Jawwali)', accountNum: '770001122', currency: 'ريال يمني' },
  ]);

  const [hotline, setHotline] = useState('8000000');
  const [whatsapp, setWhatsapp] = useState('+967 777 000 111');
  const [officialEmail, setOfficialEmail] = useState('info@zakat.gov.ye');

  const [allowRequests, setAllowRequests] = useState(true);
  const [maintenanceMode, setMaintenanceMode] = useState(false);
  const [latestVersion, setLatestVersion] = useState('1.0.1');

  const [isSaving, setIsSaving] = useState(false);
  const [successToast, setSuccessToast] = useState(null);

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    // 1. Load local fallback immediately
    const local = getLocalDoc('app_config', 'general_settings');
    if (local) {
      if (local.hotline) setHotline(local.hotline);
      if (local.whatsapp) setWhatsapp(local.whatsapp);
      if (local.officialEmail) setOfficialEmail(local.officialEmail);
      if (local.allowRequests !== undefined) setAllowRequests(local.allowRequests);
      if (local.maintenanceMode !== undefined) setMaintenanceMode(local.maintenanceMode);
      if (local.latestVersion) setLatestVersion(local.latestVersion);
      if (local.bankAccounts) setBankAccounts(local.bankAccounts);
    }

    // 2. Try fetching from cloud with 3s timeout
    try {
      const snap = await withTimeout(getDoc(doc(db, 'app_config', 'general_settings')), 3000);
      if (snap && snap.exists()) {
        const data = snap.data();
        if (data.hotline) setHotline(data.hotline);
        if (data.whatsapp) setWhatsapp(data.whatsapp);
        if (data.officialEmail) setOfficialEmail(data.officialEmail);
        if (data.allowRequests !== undefined) setAllowRequests(data.allowRequests);
        if (data.maintenanceMode !== undefined) setMaintenanceMode(data.maintenanceMode);
        if (data.latestVersion) setLatestVersion(data.latestVersion);
        if (data.bankAccounts) setBankAccounts(data.bankAccounts);
      }
    } catch (e) {
      console.warn('Using local settings cache (Cloud unavailable):', e.message);
    }
  };

  const handleSaveSettings = async (e) => {
    e.preventDefault();
    setIsSaving(true);
    const payload = {
      hotline,
      whatsapp,
      officialEmail,
      allowRequests,
      maintenanceMode,
      latestVersion,
      bankAccounts,
      updatedAt: serverTimestamp()
    };

    try {
      const res = await safeSetDoc(
        setDoc(doc(db, 'app_config', 'general_settings'), payload, { merge: true }),
        'app_config',
        'general_settings',
        payload
      );

      if (res.isLocal) {
        setSuccessToast('⚠️ تم حفظ إعدادات النظام محلياً في المتصفح بنجاح! (السحاب غير مفعل حالياً)');
      } else {
        setSuccessToast('تم حفظ وتحديث إعدادات النظام والحسابات سحابياً بنجاح!');
      }
      setTimeout(() => setSuccessToast(null), 5000);
    } catch (err) {
      alert('حدث خطأ أثناء حفظ الإعدادات: ' + err.message);
    } finally {
      setIsSaving(false);
    }
  };

  const handleAddAccount = () => {
    setBankAccounts([
      ...bankAccounts,
      { id: Date.now(), bankName: 'اسم البنك / المحفظة', accountNum: 'رقم الحساب', currency: 'ريال يمني' }
    ]);
  };

  const handleRemoveAccount = (id) => {
    setBankAccounts(bankAccounts.filter(a => a.id !== id));
  };

  const handleUpdateAccount = (id, field, value) => {
    setBankAccounts(bankAccounts.map(a => a.id === id ? { ...a, [field]: value } : a));
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      {/* Toast */}
      {successToast && (
        <div style={{
          position: 'fixed',
          bottom: '24px',
          left: '24px',
          background: 'linear-gradient(135deg, #00695c, #004d40)',
          color: '#fff',
          padding: '14px 22px',
          borderRadius: '12px',
          boxShadow: '0 10px 25px rgba(0,0,0,0.5)',
          display: 'flex',
          alignItems: 'center',
          gap: '12px',
          zIndex: 300,
          border: '1px solid var(--gold)'
        }}>
          <CheckCircle2 size={20} color="var(--gold)" />
          <span style={{ fontSize: '13.5px', fontWeight: '700' }}>{successToast}</span>
        </div>
      )}

      {/* Header */}
      <div>
        <h1 style={{ fontSize: '22px', fontWeight: '800', margin: 0 }}>
          إعدادات الحسابات البنكية والنظام
        </h1>
        <p style={{ color: 'var(--text-muted)', fontSize: '13px', marginTop: '4px' }}>
          إدارة حسابات سداد الزكاة، وقنوات التواصل الرسمية، وضوابط استقبال طلبات المساعدة.
        </p>
      </div>

      <form onSubmit={handleSaveSettings} style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
        {/* Section 1: Official Bank Accounts & E-Wallets */}
        <div className="zakat-card">
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: '18px',
            borderBottom: '1px solid var(--border-color)',
            paddingBottom: '12px'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <CreditCard size={22} color="var(--gold)" />
              <div>
                <h2 style={{ fontSize: '16px', fontWeight: '800', margin: 0 }}>
                  حسابات البنوك والمحافظ لسداد الزكاة والتبرع
                </h2>
                <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>
                  تظهر هذه الأرقام للمستخدمين في التطبيق لتسهيل سداد الزكاة عبر التطبيقات البنكية والمحافظ.
                </span>
              </div>
            </div>

            <button 
              type="button" 
              onClick={handleAddAccount}
              className="btn btn-outline btn-sm"
              style={{ gap: '6px' }}
            >
              <Plus size={14} />
              <span>إضافة حساب بنكي</span>
            </button>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {bankAccounts.map((acc, idx) => (
              <div 
                key={acc.id}
                style={{
                  background: 'rgba(255, 255, 255, 0.02)',
                  border: '1px solid var(--border-color)',
                  borderRadius: '12px',
                  padding: '14px',
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr)) 40px',
                  gap: '12px',
                  alignItems: 'center'
                }}
              >
                <div>
                  <label className="form-label" style={{ fontSize: '11px' }}>جهة الحساب / البنك:</label>
                  <input 
                    type="text"
                    value={acc.bankName}
                    onChange={e => handleUpdateAccount(acc.id, 'bankName', e.target.value)}
                    className="form-control"
                    style={{ fontSize: '13px', fontWeight: '600' }}
                  />
                </div>

                <div>
                  <label className="form-label" style={{ fontSize: '11px' }}>رقم الحساب أو المحفظة:</label>
                  <input 
                    type="text"
                    value={acc.accountNum}
                    onChange={e => handleUpdateAccount(acc.id, 'accountNum', e.target.value)}
                    className="form-control"
                    style={{ fontSize: '13px', fontWeight: 'bold', fontFamily: 'Courier' }}
                  />
                </div>

                <div>
                  <label className="form-label" style={{ fontSize: '11px' }}>العملة المعتمدة:</label>
                  <select 
                    value={acc.currency}
                    onChange={e => handleUpdateAccount(acc.id, 'currency', e.target.value)}
                    className="form-control"
                    style={{ fontSize: '13px' }}
                  >
                    <option value="ريال يمني">ريال يمني (YER)</option>
                    <option value="ريال سعودي">ريال سعودي (SAR)</option>
                    <option value="دولار أمريكي">دولار أمريكي (USD)</option>
                  </select>
                </div>

                <div style={{ display: 'flex', justifyContent: 'center', marginTop: '16px' }}>
                  <button 
                    type="button" 
                    onClick={() => handleRemoveAccount(acc.id)}
                    className="btn btn-danger btn-sm"
                    style={{ padding: '8px' }}
                    title="حذف الحساب"
                  >
                    <Trash2 size={15} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Section 2: Contact Information & Hotline */}
        <div className="zakat-card">
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
            marginBottom: '18px',
            borderBottom: '1px solid var(--border-color)',
            paddingBottom: '12px'
          }}>
            <PhoneCall size={22} color="var(--primary-light)" />
            <h2 style={{ fontSize: '16px', fontWeight: '800', margin: 0 }}>
              قنوات التواصل الرسمية وخدمة الجمهور
            </h2>
          </div>

          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))',
            gap: '16px'
          }}>
            <div className="form-group">
              <label className="form-label">الرقم المجاني لخدمة الجمهور والشكاوى:</label>
              <input 
                type="text"
                value={hotline}
                onChange={e => setHotline(e.target.value)}
                className="form-control"
                style={{ fontWeight: 'bold' }}
              />
            </div>

            <div className="form-group">
              <label className="form-label">رقم الواتساب الرسمي للهيئة:</label>
              <input 
                type="text"
                value={whatsapp}
                onChange={e => setWhatsapp(e.target.value)}
                className="form-control"
                style={{ fontWeight: 'bold' }}
              />
            </div>

            <div className="form-group">
              <label className="form-label">البريد الإلكتروني المعتمد للدعم والطلبات:</label>
              <input 
                type="email"
                value={officialEmail}
                onChange={e => setOfficialEmail(e.target.value)}
                className="form-control"
              />
            </div>
          </div>
        </div>

        {/* Section 3: App Controls & Maintenance Mode */}
        <div className="zakat-card">
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
            marginBottom: '18px',
            borderBottom: '1px solid var(--border-color)',
            paddingBottom: '12px'
          }}>
            <Settings size={22} color="var(--gold)" />
            <h2 style={{ fontSize: '16px', fontWeight: '800', margin: 0 }}>
              ضوابط التطبيق ووضع الصيانة
            </h2>
          </div>

          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))',
            gap: '20px'
          }}>
            {/* Allow Requests Submission */}
            <div style={{
              background: 'rgba(255, 255, 255, 0.02)',
              border: '1px solid var(--border-color)',
              borderRadius: '12px',
              padding: '16px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between'
            }}>
              <div>
                <strong style={{ fontSize: '14px', display: 'block' }}>استقبال طلبات المساعدة</strong>
                <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>
                  إيقاف الاستقبال مؤقتاً أثناء فترات الجرد السنوي.
                </span>
              </div>
              <input 
                type="checkbox"
                checked={allowRequests}
                onChange={e => setAllowRequests(e.target.checked)}
                style={{ width: '22px', height: '22px', accentColor: 'var(--primary)' }}
              />
            </div>

            {/* Maintenance Mode */}
            <div style={{
              background: 'rgba(255, 255, 255, 0.02)',
              border: '1px solid var(--border-color)',
              borderRadius: '12px',
              padding: '16px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between'
            }}>
              <div>
                <strong style={{ fontSize: '14px', color: maintenanceMode ? 'var(--error)' : 'inherit', display: 'block' }}>
                  وضع الصيانة المؤقت
                </strong>
                <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>
                  إظهار تنبيه الصيانة الدورية عند تحديث الخوادم.
                </span>
              </div>
              <input 
                type="checkbox"
                checked={maintenanceMode}
                onChange={e => setMaintenanceMode(e.target.checked)}
                style={{ width: '22px', height: '22px', accentColor: 'var(--error)' }}
              />
            </div>

            {/* Latest App Version */}
            <div className="form-group" style={{ margin: 0 }}>
              <label className="form-label">رقم أحدث إصدار معتمد للتطبيق:</label>
              <input 
                type="text"
                value={latestVersion}
                onChange={e => setLatestVersion(e.target.value)}
                className="form-control"
                placeholder="مثال: 1.0.1"
                style={{ fontWeight: 'bold' }}
              />
            </div>
          </div>
        </div>

        {/* Save Button */}
        <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
          <button 
            type="submit"
            className="btn btn-gold"
            disabled={isSaving}
            style={{ padding: '12px 28px', fontSize: '15px' }}
          >
            <Save size={18} />
            <span>{isSaving ? 'جاري الحفظ...' : 'حفظ ونشر التعديلات'}</span>
          </button>
        </div>
      </form>
    </div>
  );
}
