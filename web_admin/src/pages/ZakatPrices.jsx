import React, { useState, useEffect } from 'react';
import { 
  Wheat, 
  Coins, 
  Save, 
  CheckCircle2, 
  RefreshCw, 
  TrendingUp, 
  Scale, 
  AlertTriangle,
  Sparkles,
  Info,
  Globe,
  Zap,
  Sliders,
  Check
} from 'lucide-react';
import confetti from 'canvas-confetti';
import { doc, getDoc, setDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../firebase';
import { safeSetDoc, getLocalDoc, withTimeout } from '../utils/firestoreSafe';

export default function ZakatPrices({ initialWheatPrice = 24000, onPriceSaved }) {
  // Fitr Prices State
  const [wheatBagPriceYER, setWheatBagPriceYER] = useState(initialWheatPrice);
  const [wheatBagWeightKg, setWheatBagWeightKg] = useState(50);
  const [customCashPerSa, setCustomCashPerSa] = useState('');
  const [isManualSa, setIsManualSa] = useState(false);
  
  // Gold & Silver Prices State (Sana'a & Regional)
  const [gold24Sanaa, setGold24Sanaa] = useState(62850);
  const [gold21Sanaa, setGold21Sanaa] = useState(55000);
  const [gold18Sanaa, setGold18Sanaa] = useState(47150);
  const [silverSanaa, setSilverSanaa] = useState(700);

  // Aden Parallel Market Prices
  const [gold24Aden, setGold24Aden] = useState(235000);
  const [silverAden, setSilverAden] = useState(2500);

  // Global Market Live Pricing State
  const [isFetchingGlobal, setIsFetchingGlobal] = useState(false);
  const [globalGoldOunceUSD, setGlobalGoldOunceUSD] = useState(null); // Price per oz in USD
  const [globalSilverOunceUSD, setGlobalSilverOunceUSD] = useState(null); // Price per oz in USD
  const [globalFetchTime, setGlobalFetchTime] = useState(null);
  const [globalFetchSource, setGlobalFetchSource] = useState(null);
  const [globalFetchError, setGlobalFetchError] = useState(null);

  // Exchange rates for conversion
  const [sanaaUsdRate, setSanaaUsdRate] = useState(535);
  const [adenUsdRate, setAdenUsdRate] = useState(1950);

  const [isLoading, setIsLoading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [successToast, setSuccessToast] = useState(null);
  const [lastUpdatedDate, setLastUpdatedDate] = useState(null);

  // Load existing config on mount (from local fallback first, then cloud with timeout)
  useEffect(() => {
    loadConfig();
  }, []);

  const loadConfig = async () => {
    setIsLoading(true);
    // 1. Load local fallback immediately
    const local = getLocalDoc('app_config', 'zakat_prices');
    if (local) {
      const bPrice = Number(local.wheatBagPriceYER) || initialWheatPrice;
      const bWeight = Number(local.wheatBagWeightKg) || 50;
      setWheatBagPriceYER(bPrice);
      setWheatBagWeightKg(bWeight);

      const autoSa = Math.round(bPrice / (bWeight / 2.5));
      if (local.fitrCashYER && Number(local.fitrCashYER) !== autoSa) {
        setCustomCashPerSa(local.fitrCashYER.toString());
        setIsManualSa(true);
      } else {
        setCustomCashPerSa('');
        setIsManualSa(false);
      }

      if (local.gold24PriceYER) setGold24Sanaa(local.gold24PriceYER);
      if (local.gold21PriceYER) setGold21Sanaa(local.gold21PriceYER);
      if (local.gold18PriceYER) setGold18Sanaa(local.gold18PriceYER);
      if (local.silverPriceYER) setSilverSanaa(local.silverPriceYER);
      if (local.gold24Aden) setGold24Aden(local.gold24Aden);
      if (local.silverAden) setSilverAden(local.silverAden);
      if (local.sanaaUsdRate) setSanaaUsdRate(local.sanaaUsdRate);
      if (local.adenUsdRate) setAdenUsdRate(local.adenUsdRate);
      if (local._savedAt) setLastUpdatedDate(new Date(local._savedAt));
    }

    // 2. Try fetching from cloud with 3s timeout
    try {
      const docRef = doc(db, 'app_config', 'zakat_prices');
      const snap = await withTimeout(getDoc(docRef), 3000);
      if (snap && snap.exists()) {
        const data = snap.data();
        const bPrice = data.wheatBagPriceYER ? Number(data.wheatBagPriceYER) : (local?.wheatBagPriceYER ? Number(local.wheatBagPriceYER) : initialWheatPrice);
        const bWeight = data.wheatBagWeightKg ? Number(data.wheatBagWeightKg) : (local?.wheatBagWeightKg ? Number(local.wheatBagWeightKg) : 50);
        setWheatBagPriceYER(bPrice);
        setWheatBagWeightKg(bWeight);

        const autoSa = Math.round(bPrice / (bWeight / 2.5));
        if (data.fitrCashYER && Number(data.fitrCashYER) !== autoSa) {
          setCustomCashPerSa(data.fitrCashYER.toString());
          setIsManualSa(true);
        } else {
          setCustomCashPerSa('');
          setIsManualSa(false);
        }

        if (data.gold24PriceYER) setGold24Sanaa(data.gold24PriceYER);
        if (data.gold21PriceYER) setGold21Sanaa(data.gold21PriceYER);
        if (data.gold18PriceYER) setGold18Sanaa(data.gold18PriceYER);
        if (data.silverPriceYER) setSilverSanaa(data.silverPriceYER);
        if (data.gold24Aden) setGold24Aden(data.gold24Aden);
        if (data.silverAden) setSilverAden(data.silverAden);
        if (data.sanaaUsdRate) setSanaaUsdRate(data.sanaaUsdRate);
        if (data.adenUsdRate) setAdenUsdRate(data.adenUsdRate);
        if (data.updatedAt) setLastUpdatedDate(data.updatedAt.toDate ? data.updatedAt.toDate() : new Date());
      }
    } catch (err) {
      console.warn('Using local prices cache (Cloud unavailable):', err.message);
    } finally {
      setIsLoading(false);
    }
  };

  // 1 Troy Ounce = 31.1034768 grams
  const TROY_OUNCE_TO_GRAM = 31.1034768;

  // Global Market Live Fetch Function
  const fetchGlobalPrices = async () => {
    setIsFetchingGlobal(true);
    setGlobalFetchError(null);

    try {
      // 1. Fetch Gold (XAU) spot price
      let goldPriceUSD = null;
      let silverPriceUSD = null;

      try {
        const goldRes = await fetch('https://api.gold-api.com/price/XAU');
        if (goldRes.ok) {
          const goldData = await goldRes.json();
          goldPriceUSD = Number(goldData.price);
        }
      } catch (err) {
        console.warn('Gold API fetch failed:', err);
      }

      // 2. Fetch Silver (XAG) spot price
      try {
        const silverRes = await fetch('https://api.gold-api.com/price/XAG');
        if (silverRes.ok) {
          const silverData = await silverRes.json();
          silverPriceUSD = Number(silverData.price);
        }
      } catch (err) {
        console.warn('Silver API fetch failed:', err);
      }

      // If gold fetched, calculate fallback for silver if needed (gold:silver ratio ~ 80:1)
      if (goldPriceUSD && goldPriceUSD > 0) {
        setGlobalGoldOunceUSD(goldPriceUSD);
        if (!silverPriceUSD || silverPriceUSD <= 0) {
          silverPriceUSD = goldPriceUSD / 80;
        }
        setGlobalSilverOunceUSD(silverPriceUSD);
        setGlobalFetchTime(new Date());
        setGlobalFetchSource('بورصة المعادن العالمية الحية (Gold-API Spot Live)');
      } else {
        throw new Error('تعذر جلب السعر اللحظي من البورصة العالمية، يرجى التحقق من اتصال الإنترنت أو استخدام التسعير اليدوي.');
      }
    } catch (err) {
      setGlobalFetchError(err.message || 'حدث خطأ أثناء الاتصال ببورصة الذهب العالمية');
    } finally {
      setIsFetchingGlobal(false);
    }
  };

  // Calculated per-gram USD values
  const gold24UsdGram = globalGoldOunceUSD ? (globalGoldOunceUSD / TROY_OUNCE_TO_GRAM) : 0;
  const gold21UsdGram = gold24UsdGram * (21 / 24);
  const gold18UsdGram = gold24UsdGram * (18 / 24);
  const silverUsdGram = globalSilverOunceUSD ? (globalSilverOunceUSD / TROY_OUNCE_TO_GRAM) : 0;

  // Calculated USD Nisab
  const goldNisabUSD = Math.round(gold24UsdGram * 85);
  const silverNisabUSD = Math.round(silverUsdGram * 595);

  // Calculated Sana'a Prices from Global
  const calcGold24Sanaa = Math.round((gold24UsdGram * sanaaUsdRate) / 50) * 50;
  const calcGold21Sanaa = Math.round((calcGold24Sanaa * (21 / 24)) / 50) * 50;
  const calcGold18Sanaa = Math.round((calcGold24Sanaa * (18 / 24)) / 50) * 50;
  const calcSilverSanaa = Math.round((silverUsdGram * sanaaUsdRate) / 10) * 10;
  const calcGoldNisabSanaa = Math.round(calcGold24Sanaa * 85);
  const calcSilverNisabSanaa = Math.round(calcSilverSanaa * 595);

  // Calculated Aden Prices from Global
  const calcGold24Aden = Math.round((gold24UsdGram * adenUsdRate) / 500) * 500;
  const calcSilverAden = Math.round((silverUsdGram * adenUsdRate) / 50) * 50;
  const calcGoldNisabAden = Math.round(calcGold24Aden * 85);
  const calcSilverNisabAden = Math.round(calcSilverAden * 595);

  // Apply Calculated Global to Form Inputs
  const applyToSanaa = () => {
    if (!globalGoldOunceUSD) return;
    setGold24Sanaa(calcGold24Sanaa);
    setGold21Sanaa(calcGold21Sanaa);
    setGold18Sanaa(calcGold18Sanaa);
    setSilverSanaa(calcSilverSanaa);
    setSuccessToast('تم تطبيق أسعار الذهب والفضة العالمية على سوق صنعاء بنجاح!');
    setTimeout(() => setSuccessToast(null), 4000);
  };

  const applyToAden = () => {
    if (!globalGoldOunceUSD) return;
    setGold24Aden(calcGold24Aden);
    setSilverAden(calcSilverAden);
    setSuccessToast('تم تطبيق أسعار الذهب والفضة العالمية على سوق عدن بنجاح!');
    setTimeout(() => setSuccessToast(null), 4000);
  };

  const applyToAll = () => {
    if (!globalGoldOunceUSD) return;
    applyToSanaa();
    applyToAden();
    setSuccessToast('تم تطبيق الأسعار العالمية المحسوبة على سوق صنعاء وعدن معاً بنجاح!');
    setTimeout(() => setSuccessToast(null), 4000);
  };

  // Calculations for Zakat al-Fitr
  const saWeightKg = 2.5; // الصاع النبوي بالكيلوغرام
  const saCountInBag = wheatBagWeightKg > 0 ? (wheatBagWeightKg / saWeightKg) : 20;
  const calculatedCashPerSa = saCountInBag > 0 ? Math.round(wheatBagPriceYER / saCountInBag) : 1200;
  const effectiveCashPerSa = (isManualSa && customCashPerSa !== '' && !isNaN(Number(customCashPerSa)) && Number(customCashPerSa) > 0)
    ? Number(customCashPerSa)
    : calculatedCashPerSa;

  // Active Nisab threshold calculations (current form values)
  const goldNisabSanaa = Math.round(gold24Sanaa * 85);
  const silverNisabSanaa = Math.round(silverSanaa * 595);
  const goldNisabAden = Math.round(gold24Aden * 85);
  const silverNisabAden = Math.round(silverAden * 595);

  const handleSavePrices = async (e) => {
    e.preventDefault();
    setIsSaving(true);

    try {
      const docRef = doc(db, 'app_config', 'zakat_prices');
      const payload = {
        wheatBagPriceYER: Number(wheatBagPriceYER),
        wheatBagWeightKg: Number(wheatBagWeightKg),
        fitrCashYER: Number(effectiveCashPerSa),
        gold24PriceYER: Number(gold24Sanaa),
        gold21PriceYER: Number(gold21Sanaa),
        gold18PriceYER: Number(gold18Sanaa),
        silverPriceYER: Number(silverSanaa),
        gold24Aden: Number(gold24Aden),
        silverAden: Number(silverAden),
        sanaaUsdRate: Number(sanaaUsdRate),
        adenUsdRate: Number(adenUsdRate),
        globalGoldOunceUSD: globalGoldOunceUSD ? Number(globalGoldOunceUSD) : null,
        globalSilverOunceUSD: globalSilverOunceUSD ? Number(globalSilverOunceUSD) : null,
        updatedAt: serverTimestamp(),
      };

      const res = await safeSetDoc(
        setDoc(docRef, payload, { merge: true }),
        'app_config',
        'zakat_prices',
        payload
      );

      confetti({
        particleCount: 100,
        spread: 80,
        origin: { y: 0.6 }
      });

      if (res.isLocal) {
        setSuccessToast('⚠️ تم حفظ التسعيرة محلياً بنجاح (السحاب غير مفعل في Firebase حالياً). لن تعلق اللوحة!');
      } else {
        setSuccessToast('تم اعتماد ونشر تسعيرة زكاة الفطرة والذهب والنصاب لجميع مستخدمي التطبيق سحابياً بنجاح!');
      }
      setTimeout(() => setSuccessToast(null), 6000);
      setLastUpdatedDate(new Date());

      if (onPriceSaved) onPriceSaved(Number(wheatBagPriceYER));
    } catch (err) {
      alert('حدث خطأ أثناء حفظ الأسعار: ' + err.message);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      {/* Toast Notification */}
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
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: '16px'
      }}>
        <div>
          <h1 style={{ fontSize: '22px', fontWeight: '800', margin: 0 }}>
            إدارة تسعيرة زكاة الفطرة والنصاب الشرعي
          </h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '13px', marginTop: '4px' }}>
            تحديد أسعار النصاب الشرعي (الذهب والفضة) إما يدوياً أو بجلب الأسعار الحية من البورصة العالمية بضغطة زر.
          </p>
        </div>

        {lastUpdatedDate && (
          <div style={{
            background: 'rgba(212, 175, 55, 0.1)',
            border: '1px solid rgba(212, 175, 55, 0.3)',
            borderRadius: '10px',
            padding: '8px 14px',
            fontSize: '12px',
            color: 'var(--gold)'
          }}>
            آخر تحديث معتمد: {lastUpdatedDate.toLocaleDateString('ar')} - {lastUpdatedDate.toLocaleTimeString('ar')}
          </div>
        )}
      </div>

      <form onSubmit={handleSavePrices} style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
        {/* Section 1: Zakat al-Fitr (Wheat Bag) */}
        <div className="zakat-card" style={{ borderRight: '4px solid var(--gold)' }}>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
            marginBottom: '20px',
            borderBottom: '1px solid var(--border-color)',
            paddingBottom: '12px'
          }}>
            <Wheat size={24} color="var(--gold)" />
            <div>
              <h2 style={{ fontSize: '17px', fontWeight: '800', margin: 0 }}>
                تسعيرة زكاة الفطرة المعتمدة (كيس القمح والصاع)
              </h2>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                يتم احتساب زكاة الفطرة نقداً بناءً على سعر كيس القمح السائد في الأسواق ومقدار الصاع النبوي (≈ 2.5 كجم).
              </span>
            </div>
          </div>

          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))',
            gap: '20px'
          }}>
            {/* Wheat Bag Price */}
            <div className="form-group">
              <label className="form-label">سعر كيس القمح بالسوق (ريال يمني - YER):</label>
              <div style={{ position: 'relative' }}>
                <input 
                  type="number"
                  required
                  min="1000"
                  step="500"
                  value={wheatBagPriceYER}
                  onChange={e => {
                    setWheatBagPriceYER(Number(e.target.value));
                    if (!isManualSa) {
                      setCustomCashPerSa('');
                    }
                  }}
                  className="form-control"
                  style={{ fontSize: '16px', fontWeight: '800', paddingLeft: '50px' }}
                />
                <span style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: '12px', fontWeight: 'bold' }}>
                  ر.ي
                </span>
              </div>
              <span style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px', display: 'block' }}>
                السعر السائد لكيس القمح المعتمد رسمياً لدى لجان الهيئة.
              </span>
            </div>

            {/* Bag Weight */}
            <div className="form-group">
              <label className="form-label">وزن كيس القمح المعتمد (كيلوجرام):</label>
              <select
                value={wheatBagWeightKg}
                onChange={e => {
                  setWheatBagWeightKg(Number(e.target.value));
                  if (!isManualSa) {
                    setCustomCashPerSa('');
                  }
                }}
                className="form-control"
                style={{ fontWeight: '700' }}
              >
                <option value={50}>كيس كبير (50 كجم = 20 صاعاً نبوياً)</option>
                <option value={40}>كيس متوسط (40 كجم = 16 صاعاً نبوياً)</option>
                <option value={25}>كيس صغير (25 كجم = 10 أصواع)</option>
              </select>
            </div>

            {/* Cash Per Person / Sa' */}
            <div className="form-group">
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '6px' }}>
                <label className="form-label" style={{ margin: 0 }}>القيمة النقدية المقدرة للصاع للفرد الواحد (ر.ي):</label>
                {isManualSa ? (
                  <button
                    type="button"
                    onClick={() => {
                      setIsManualSa(false);
                      setCustomCashPerSa('');
                    }}
                    className="btn btn-outline"
                    style={{ padding: '2px 8px', fontSize: '11px', color: 'var(--gold)', borderColor: 'rgba(212, 175, 55, 0.4)' }}
                    title="العودة للحساب الآلي من سعر الكيس"
                  >
                    ↺ استعادة الحساب التلقائي
                  </button>
                ) : (
                  <span style={{
                    fontSize: '11px',
                    background: 'rgba(16, 185, 129, 0.15)',
                    color: '#10b981',
                    padding: '2px 8px',
                    borderRadius: '10px',
                    fontWeight: 'bold',
                    border: '1px solid rgba(16, 185, 129, 0.3)'
                  }}>
                    محسوب آلياً من الكيس
                  </span>
                )}
              </div>
              <div style={{ position: 'relative' }}>
                <input 
                  type="number"
                  value={isManualSa ? customCashPerSa : calculatedCashPerSa}
                  onChange={e => {
                    setIsManualSa(true);
                    setCustomCashPerSa(e.target.value);
                  }}
                  className="form-control"
                  style={{ fontSize: '16px', fontWeight: '800', paddingLeft: '50px', color: 'var(--gold)' }}
                />
                <span style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: '12px', fontWeight: 'bold' }}>
                  ر.ي
                </span>
              </div>
              <span style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px', display: 'block' }}>
                {isManualSa 
                  ? `تخصيص يدوي حالي. (المعادلة التلقائية: ${wheatBagPriceYER.toLocaleString()} ÷ ${saCountInBag.toFixed(0)} صاع = ${calculatedCashPerSa.toLocaleString()} ر.ي).`
                  : `المحسوب آلياً: (${wheatBagPriceYER.toLocaleString()} ÷ ${saCountInBag.toFixed(0)} صاع = ${calculatedCashPerSa.toLocaleString()} ر.ي). يتغير تلقائياً مع سعر الكيس.`}
              </span>
            </div>
          </div>

          {/* Quick Summary Card */}
          <div style={{
            background: 'rgba(0, 105, 92, 0.12)',
            border: '1px solid rgba(0, 105, 92, 0.3)',
            borderRadius: '12px',
            padding: '16px',
            marginTop: '8px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            flexWrap: 'wrap',
            gap: '12px'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <Info size={20} color="var(--primary-light)" />
              <div style={{ fontSize: '13px' }}>
                النتيجة للمواطن: <strong>{effectiveCashPerSa.toLocaleString()} ر.ي</strong> عن الفرد الواحد (أسرة مكونة من 5 أفراد تخرج: <strong>{(effectiveCashPerSa * 5).toLocaleString()} ر.ي</strong>).
              </div>
            </div>
            <span style={{ fontSize: '11.5px', color: 'var(--gold)', fontWeight: 'bold' }}>
              تعتمد فورياً في حاسبة الفطرة
            </span>
          </div>
        </div>

        {/* Section 2: Gold & Silver Prices for Nisab Calculation */}
        <div className="zakat-card" style={{ borderRight: '4px solid var(--primary-light)' }}>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            flexWrap: 'wrap',
            gap: '12px',
            marginBottom: '20px',
            borderBottom: '1px solid var(--border-color)',
            paddingBottom: '14px'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <Coins size={24} color="var(--gold)" />
              <div>
                <h2 style={{ fontSize: '17px', fontWeight: '800', margin: 0 }}>
                  تسعيرة الذهب والفضة وحساب النصاب الشرعي
                </h2>
                <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                  تعتمد هذه الأسعار لحساب نصاب زكاة المال والنقود (85 جرام ذهب خالص عيار 24) وعروض التجارة والسبائك.
                </span>
              </div>
            </div>
          </div>

          {/* Global Market Sync Hero Box */}
          <div style={{
            background: 'linear-gradient(135deg, rgba(19, 29, 49, 0.95), rgba(11, 17, 32, 0.95))',
            border: '1px solid rgba(212, 175, 55, 0.35)',
            borderRadius: '16px',
            padding: '20px',
            marginBottom: '28px',
            position: 'relative',
            boxShadow: '0 8px 24px rgba(0,0,0,0.35)'
          }}>
            {/* Header row */}
            <div style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              flexWrap: 'wrap',
              gap: '14px',
              borderBottom: '1px solid rgba(255, 255, 255, 0.08)',
              paddingBottom: '14px',
              marginBottom: '16px'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <div style={{
                  width: '38px',
                  height: '38px',
                  borderRadius: '10px',
                  background: 'rgba(212, 175, 55, 0.15)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: 'var(--gold)'
                }}>
                  <Globe size={22} />
                </div>
                <div>
                  <h3 style={{ fontSize: '15px', fontWeight: '800', margin: 0, color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    جلب أسعار النصاب من البورصة العالمية (Live Global Market)
                    <span style={{
                      fontSize: '10.5px',
                      background: 'rgba(16, 185, 129, 0.2)',
                      color: '#10b981',
                      padding: '2px 8px',
                      borderRadius: '12px',
                      fontWeight: 'bold',
                      border: '1px solid rgba(16, 185, 129, 0.4)'
                    }}>
                      تلقائي / غير يدوي
                    </span>
                  </h3>
                  <span style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>
                    استعلام مباشر لحظي عن سعر أونصة الذهب (XAU) والفضة (XAG) واحتساب النصاب الشرعي بالدولار والريال.
                  </span>
                </div>
              </div>

              {/* Fetch button */}
              <button
                type="button"
                onClick={fetchGlobalPrices}
                disabled={isFetchingGlobal}
                className="btn btn-gold"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  padding: '10px 20px',
                  fontWeight: '800',
                  fontSize: '13.5px',
                  cursor: isFetchingGlobal ? 'not-allowed' : 'pointer'
                }}
              >
                {isFetchingGlobal ? (
                  <>
                    <RefreshCw size={16} className="spin-animation" />
                    <span>جاري الاتصال بالبورصة...</span>
                  </>
                ) : (
                  <>
                    <Zap size={16} />
                    <span>جلب وتحديث السعر العالمي الآن</span>
                  </>
                )}
              </button>
            </div>

            {/* Global Error Banner if any */}
            {globalFetchError && (
              <div style={{
                background: 'rgba(239, 68, 68, 0.15)',
                border: '1px solid rgba(239, 68, 68, 0.4)',
                borderRadius: '10px',
                padding: '10px 14px',
                marginBottom: '16px',
                display: 'flex',
                alignItems: 'center',
                gap: '10px',
                color: '#fca5a5',
                fontSize: '12.5px'
              }}>
                <AlertTriangle size={18} color="#ef4444" />
                <span>{globalFetchError}</span>
              </div>
            )}

            {/* Display fetched market stats or instructions */}
            {globalGoldOunceUSD ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {/* 1. Global Quotes Cards */}
                <div style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))',
                  gap: '14px'
                }}>
                  {/* Gold Card */}
                  <div style={{
                    background: 'rgba(212, 175, 55, 0.08)',
                    border: '1px solid rgba(212, 175, 55, 0.3)',
                    borderRadius: '12px',
                    padding: '14px'
                  }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                      <span style={{ fontSize: '12px', fontWeight: 'bold', color: 'var(--gold)' }}>
                        أونصة الذهب (XAU/USD)
                      </span>
                      <span style={{ fontSize: '10px', background: 'rgba(212, 175, 55, 0.2)', color: 'var(--gold)', padding: '2px 6px', borderRadius: '6px' }}>
                        عالمي
                      </span>
                    </div>
                    <div style={{ fontSize: '20px', fontWeight: '900', color: '#fff', marginBottom: '4px' }}>
                      ${globalGoldOunceUSD.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                    </div>
                    <div style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>
                      سعر جرام الذهب عيار 24: <strong style={{ color: 'var(--gold)' }}>${gold24UsdGram.toFixed(2)}</strong>
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>
                      نصاب الذهب (85غ): <strong style={{ color: '#fff' }}>${goldNisabUSD.toLocaleString()}</strong>
                    </div>
                  </div>

                  {/* Silver Card */}
                  <div style={{
                    background: 'rgba(147, 197, 253, 0.08)',
                    border: '1px solid rgba(147, 197, 253, 0.3)',
                    borderRadius: '12px',
                    padding: '14px'
                  }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                      <span style={{ fontSize: '12px', fontWeight: 'bold', color: '#93c5fd' }}>
                        أونصة الفضة (XAG/USD)
                      </span>
                      <span style={{ fontSize: '10px', background: 'rgba(147, 197, 253, 0.2)', color: '#93c5fd', padding: '2px 6px', borderRadius: '6px' }}>
                        عالمي
                      </span>
                    </div>
                    <div style={{ fontSize: '20px', fontWeight: '900', color: '#fff', marginBottom: '4px' }}>
                      ${globalSilverOunceUSD ? globalSilverOunceUSD.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : '--'}
                    </div>
                    <div style={{ fontSize: '11.5px', color: 'var(--text-muted)' }}>
                      سعر جرام الفضة الخالصة: <strong style={{ color: '#93c5fd' }}>${silverUsdGram.toFixed(3)}</strong>
                    </div>
                    <div style={{ fontSize: '11px', color: 'var(--text-dim)', marginTop: '4px' }}>
                      نصاب الفضة (595غ): <strong style={{ color: '#fff' }}>${silverNisabUSD.toLocaleString()}</strong>
                    </div>
                  </div>

                  {/* Currency Exchange Tuning Card */}
                  <div style={{
                    background: 'rgba(255, 255, 255, 0.03)',
                    border: '1px solid var(--border-color)',
                    borderRadius: '12px',
                    padding: '14px',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between'
                  }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '8px' }}>
                      <Sliders size={15} color="var(--primary-light)" />
                      <span style={{ fontSize: '12px', fontWeight: 'bold', color: 'var(--text-main)' }}>
                        سعر الصرف المعتمد للتحويل
                      </span>
                    </div>

                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                      <div>
                        <label style={{ fontSize: '10.5px', color: 'var(--text-muted)', display: 'block', marginBottom: '2px' }}>
                          صرف صنعاء ($/YER):
                        </label>
                        <input
                          type="number"
                          value={sanaaUsdRate}
                          onChange={e => setSanaaUsdRate(Number(e.target.value))}
                          className="form-control"
                          style={{ padding: '4px 8px', fontSize: '12px', fontWeight: 'bold' }}
                        />
                      </div>
                      <div>
                        <label style={{ fontSize: '10.5px', color: 'var(--text-muted)', display: 'block', marginBottom: '2px' }}>
                          صرف عدن ($/YER):
                        </label>
                        <input
                          type="number"
                          value={adenUsdRate}
                          onChange={e => setAdenUsdRate(Number(e.target.value))}
                          className="form-control"
                          style={{ padding: '4px 8px', fontSize: '12px', fontWeight: 'bold' }}
                        />
                      </div>
                    </div>
                    <span style={{ fontSize: '10px', color: 'var(--text-dim)', marginTop: '4px' }}>
                      يمكنك تعديل سعر الصرف لتعديل التحويل المحلي فوراً.
                    </span>
                  </div>
                </div>

                {/* 2. Calculated Preview & 1-Click Apply Buttons */}
                <div style={{
                  background: 'rgba(0, 105, 92, 0.15)',
                  border: '1px dashed rgba(0, 137, 123, 0.5)',
                  borderRadius: '12px',
                  padding: '14px 18px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  flexWrap: 'wrap',
                  gap: '14px'
                }}>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                    <div style={{ fontSize: '12.5px', fontWeight: 'bold', color: 'var(--text-main)' }}>
                      الأسعار المحسوبة من السعر العالمي وفق الصرف المحدد:
                    </div>
                    <div style={{ fontSize: '11.5px', color: 'var(--text-muted)', display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
                      <span>صنعاء: عيار24 = <strong style={{ color: 'var(--gold)' }}>{calcGold24Sanaa.toLocaleString()} ر.ي</strong> | نصاب الذهب = <strong style={{ color: 'var(--gold)' }}>{calcGoldNisabSanaa.toLocaleString()} ر.ي</strong></span>
                      <span>عدن: عيار24 = <strong style={{ color: '#93c5fd' }}>{calcGold24Aden.toLocaleString()} ر.ي</strong> | نصاب الذهب = <strong style={{ color: '#93c5fd' }}>{calcGoldNisabAden.toLocaleString()} ر.ي</strong></span>
                    </div>
                    {globalFetchTime && (
                      <div style={{ fontSize: '10.5px', color: 'var(--text-dim)', marginTop: '2px' }}>
                        مصدر البيانات: {globalFetchSource} • تم الجلب: {globalFetchTime.toLocaleTimeString('ar')}
                      </div>
                    )}
                  </div>

                  {/* Apply Actions */}
                  <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                    <button
                      type="button"
                      onClick={applyToAll}
                      className="btn btn-gold"
                      style={{ padding: '8px 16px', fontSize: '12.5px', fontWeight: 'bold' }}
                    >
                      <Sparkles size={14} />
                      <span>تطبيق على صنعاء وعدن معاً</span>
                    </button>
                    <button
                      type="button"
                      onClick={applyToSanaa}
                      className="btn btn-outline"
                      style={{ padding: '8px 12px', fontSize: '12px' }}
                    >
                      <span>تطبيق لصنعاء فقط</span>
                    </button>
                    <button
                      type="button"
                      onClick={applyToAden}
                      className="btn btn-outline"
                      style={{ padding: '8px 12px', fontSize: '12px' }}
                    >
                      <span>تطبيق لعدن فقط</span>
                    </button>
                  </div>
                </div>
              </div>
            ) : (
              <div style={{
                background: 'rgba(255, 255, 255, 0.02)',
                borderRadius: '10px',
                padding: '16px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                flexWrap: 'wrap',
                gap: '12px'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <Info size={20} color="var(--gold)" />
                  <div style={{ fontSize: '12.5px', color: 'var(--text-muted)' }}>
                    اضغط على زر <strong>"جلب وتحديث السعر العالمي الآن"</strong> أعلاه لجلب أحدث تسعيرة لأونصة الذهب والفضة من البورصة العالمية وتحويلها آلياً إلى نصاب الذهب والفضة بالريال اليمني.
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Sana'a Market */}
          <div style={{ marginBottom: '24px' }}>
            <div style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              marginBottom: '14px',
              flexWrap: 'wrap',
              gap: '10px'
            }}>
              <h3 style={{ fontSize: '14.5px', fontWeight: '800', color: 'var(--gold)', margin: 0 }}>
                سوق صنعاء (الريال اليمني المعتمد)
              </h3>
              {globalGoldOunceUSD && (
                <button
                  type="button"
                  onClick={applyToSanaa}
                  className="btn btn-outline"
                  style={{ padding: '4px 10px', fontSize: '11px', borderColor: 'rgba(212, 175, 55, 0.4)', color: 'var(--gold)' }}
                >
                  <Sparkles size={12} />
                  <span>تعبئة تلقائية من السعر العالمي</span>
                </button>
              )}
            </div>

            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
              gap: '16px'
            }}>
              <div className="form-group">
                <label className="form-label">جرام الذهب عيار 24 (الأساس الشرعي للنصاب):</label>
                <input 
                  type="number"
                  required
                  value={gold24Sanaa}
                  onChange={e => setGold24Sanaa(Number(e.target.value))}
                  className="form-control"
                  style={{ fontWeight: '700' }}
                />
              </div>

              <div className="form-group">
                <label className="form-label">جرام الذهب عيار 21 (الشائع):</label>
                <input 
                  type="number"
                  required
                  value={gold21Sanaa}
                  onChange={e => setGold21Sanaa(Number(e.target.value))}
                  className="form-control"
                  style={{ fontWeight: '700' }}
                />
              </div>

              <div className="form-group">
                <label className="form-label">جرام الذهب عيار 18:</label>
                <input 
                  type="number"
                  required
                  value={gold18Sanaa}
                  onChange={e => setGold18Sanaa(Number(e.target.value))}
                  className="form-control"
                  style={{ fontWeight: '700' }}
                />
              </div>

              <div className="form-group">
                <label className="form-label">جرام الفضة الخالصة (نصاب 595 جرام):</label>
                <input 
                  type="number"
                  required
                  value={silverSanaa}
                  onChange={e => setSilverSanaa(Number(e.target.value))}
                  className="form-control"
                  style={{ fontWeight: '700' }}
                />
              </div>
            </div>

            {/* Nisab Result preview */}
            <div style={{
              background: 'rgba(255, 255, 255, 0.03)',
              borderRadius: '10px',
              padding: '12px 16px',
              marginTop: '12px',
              display: 'flex',
              gap: '24px',
              flexWrap: 'wrap',
              fontSize: '12.5px',
              border: '1px solid var(--border-color)'
            }}>
              <div>
                نصاب الذهب الشرعي بصنعاء (85غ × {gold24Sanaa.toLocaleString()}): 
                <strong style={{ color: 'var(--gold)', marginRight: '6px', fontSize: '13.5px' }}>{goldNisabSanaa.toLocaleString()} ر.ي</strong>
              </div>
              <div>
                نصاب الفضة الشرعي بصنعاء (595غ × {silverSanaa.toLocaleString()}): 
                <strong style={{ color: '#93c5fd', marginRight: '6px', fontSize: '13.5px' }}>{silverNisabSanaa.toLocaleString()} ر.ي</strong>
              </div>
            </div>
          </div>

          {/* Aden Parallel Market */}
          <div style={{ borderTop: '1px solid var(--border-color)', paddingTop: '18px' }}>
            <div style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              marginBottom: '14px',
              flexWrap: 'wrap',
              gap: '10px'
            }}>
              <h3 style={{ fontSize: '14.5px', fontWeight: '800', color: '#93c5fd', margin: 0 }}>
                سوق عدن (الريال اليمني - السعر الإقليمي الموازي)
              </h3>
              {globalGoldOunceUSD && (
                <button
                  type="button"
                  onClick={applyToAden}
                  className="btn btn-outline"
                  style={{ padding: '4px 10px', fontSize: '11px', borderColor: 'rgba(147, 197, 253, 0.4)', color: '#93c5fd' }}
                >
                  <Sparkles size={12} />
                  <span>تعبئة تلقائية من السعر العالمي</span>
                </button>
              )}
            </div>

            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
              gap: '16px'
            }}>
              <div className="form-group">
                <label className="form-label">جرام الذهب عيار 24 (عدن):</label>
                <input 
                  type="number"
                  value={gold24Aden}
                  onChange={e => setGold24Aden(Number(e.target.value))}
                  className="form-control"
                  style={{ fontWeight: '700' }}
                />
              </div>

              <div className="form-group">
                <label className="form-label">جرام الفضة (عدن):</label>
                <input 
                  type="number"
                  value={silverAden}
                  onChange={e => setSilverAden(Number(e.target.value))}
                  className="form-control"
                  style={{ fontWeight: '700' }}
                />
              </div>
            </div>

            {/* Aden Nisab Result preview */}
            <div style={{
              background: 'rgba(255, 255, 255, 0.03)',
              borderRadius: '10px',
              padding: '12px 16px',
              marginTop: '12px',
              display: 'flex',
              gap: '24px',
              flexWrap: 'wrap',
              fontSize: '12.5px',
              border: '1px solid var(--border-color)'
            }}>
              <div>
                نصاب الذهب الشرعي بعدن (85غ × {gold24Aden.toLocaleString()}): 
                <strong style={{ color: 'var(--gold)', marginRight: '6px', fontSize: '13.5px' }}>{goldNisabAden.toLocaleString()} ر.ي</strong>
              </div>
              <div>
                نصاب الفضة الشرعي بعدن (595غ × {silverAden.toLocaleString()}): 
                <strong style={{ color: '#93c5fd', marginRight: '6px', fontSize: '13.5px' }}>{silverNisabAden.toLocaleString()} ر.ي</strong>
              </div>
            </div>
          </div>
        </div>

        {/* Action Button */}
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '14px' }}>
          <button 
            type="button"
            onClick={loadConfig}
            className="btn btn-outline"
            disabled={isSaving}
          >
            <RefreshCw size={16} />
            <span>إعادة ضبط</span>
          </button>
          <button 
            type="submit"
            className="btn btn-gold"
            disabled={isSaving}
            style={{ padding: '12px 28px', fontSize: '15px' }}
          >
            <Save size={18} />
            <span>{isSaving ? 'جاري الحفظ والنشر...' : 'حفظ ونشر التحديث لجميع الهواتف'}</span>
          </button>
        </div>
      </form>
    </div>
  );
}
