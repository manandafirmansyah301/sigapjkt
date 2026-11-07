import React, { useState, useEffect, useMemo, useRef } from 'react';
import {
  MapPin, Navigation, CloudRain, Wind,
  Award, Bell, Radio, CheckCircle2,
  Volume2, VolumeX, Plus, RefreshCw,
  ChevronDown, ChevronUp, X, Globe, Activity,
  Layers, Users, FileText, ArrowUpRight, ZoomIn, ZoomOut, RotateCcw,
  Shield, Compass, TrendingDown, Search
} from 'lucide-react';
import {
  ResponsiveContainer, AreaChart, Area, XAxis, YAxis, Tooltip, CartesianGrid
} from 'recharts';

// --- TRANSLATIONS (ID / EN) ---
const TRANSLATIONS = {
  id: {
    nav: { command: 'Pusat Komando Live', cta: 'Simulasi Sistem' },
    header: { tag: 'PUSAT KENDALI OPERASIONAL LANGSUNG', title: 'Dashboard Prediksi Banjir & Penurunan Tanah Jakarta', desc: 'Mengintegrasikan sensor kota dengan 1.248 Smart Helmet pengendara sebagai mata dan telinga bergerak di 5 wilayah DKI Jakarta.' },
    sim: { normal: 'Cuaca Kondusif', actual: 'Mode Aktual (Live)', storm: 'Badai Ekstrem' },
    kpi: {
      helmets: { title: 'Helm Pintar Aktif', unit: 'Unit Online', sub: 'Distribusi armada per wilayah' },
      flood: { title: 'Risiko Banjir AI', unit: 'Akurasi 94%', sub: 'Tinggi genangan air' },
      air: { title: 'Polusi Udara (PM2.5)', unit: 'Sensor Helm', sub: 'Kualitas udara jalanan' },
      sub: { title: 'Penurunan Tanah', unit: 'Pesisir Utara', sub: 'Laju subsiden per tahun' }
    },
    map: { title: 'Peta Digital Twin 5 Wilayah DKI', sub: 'Klik titik wilayah untuk inspeksi telemetri', radar: 'Radar Cuaca' },
    layer: { all: 'Semua Layer', flood: 'Risiko Banjir', sub: 'Penurunan Tanah', air: 'Polusi PM2.5', evac: 'Rute Evakuasi' },
    legend: { high: 'Siaga Tinggi', med: 'Siaga Sedang', low: 'Terkendali' },
    zone: { rainfall: 'Curah Hujan', subsidence: 'Penurunan Tanah', water: 'Tinggi Genangan', helmets: 'Helm Aktif', evacTitle: 'Rute Evakuasi AI:' },
    action: { broadcast: 'Pancarkan Suara ke Sektor', simulateRain: 'Simulasi Hujan Lokal (+15mm/j)', verify: '✓ Verifikasi (+50 Poin)' },
    chart: { title: 'Grafik AI Real-Time:', sub: 'Proyeksi 24 jam ke depan', water: 'Tinggi Air (cm)', rain: 'Hujan (mm/j)', air: 'PM2.5 (µg/m³)' },
    fleet: { title: 'Armada Smart Helmet', sub: 'Telemetri sensor pengendara', search: 'Cari pengendara...', filterAll: 'Semua', filterAlert: 'Siaga' },
    reports: { title: 'Laporan Bencana Warga', sub: 'Gamifikasi Poin & Validasi' }
  },
  en: {
    nav: { command: 'Live Command Center', cta: 'System Simulation' },
    header: { tag: 'LIVE OPERATIONAL COMMAND CENTER', title: 'Jakarta Flood & Land Subsidence Prediction Dashboard', desc: 'Integrating urban sensors with 1,248 Smart Helmets acting as moving eyes and ears across 5 Jakarta regions.' },
    sim: { normal: 'Clear Weather', actual: 'Live Actual', storm: 'Extreme Storm' },
    kpi: {
      helmets: { title: 'Active Smart Helmets', unit: 'Units Online', sub: 'Fleet distribution by sector' },
      flood: { title: 'AI Flood Risk', unit: '94% Accuracy', sub: 'Inundation water levels' },
      air: { title: 'Air Pollution (PM2.5)', unit: 'Helmet Sensor', sub: 'Street-level air quality' },
      sub: { title: 'Land Subsidence', unit: 'North Coast', sub: 'Annual subsidence rate' }
    },
    map: { title: '5-Region Digital Twin Map', sub: 'Click sector points for telemetry inspection', radar: 'Weather Radar' },
    layer: { all: 'All Layers', flood: 'Flood Risk', sub: 'Subsidence', air: 'PM2.5 Pollution', evac: 'Evac Routes' },
    legend: { high: 'High Alert', med: 'Moderate', low: 'Controlled' },
    zone: { rainfall: 'Rainfall', subsidence: 'Subsidence', water: 'Water Level', helmets: 'Active Helmets', evacTitle: 'AI Evacuation Route:' },
    action: { broadcast: 'Broadcast Voice to Sector', simulateRain: 'Simulate Local Rain (+15mm/h)', verify: '✓ Verify (+50 Pts)' },
    chart: { title: 'Real-Time AI Chart:', sub: '24-hour projection', water: 'Water (cm)', rain: 'Rain (mm/h)', air: 'PM2.5 (µg/m³)' },
    fleet: { title: 'Smart Helmet Fleet', sub: 'Rider sensor telemetry', search: 'Search rider...', filterAll: 'All', filterAlert: 'Alerts' },
    reports: { title: 'Citizen Disaster Reports', sub: 'Gamification Points & Validation' }
  }
};

// --- INITIAL DATA ---
const INITIAL_ZONES = [
  { id: 'penjaringan', shortName: 'Jakut - Pluit', name: 'Jakarta Utara (Pluit/PIK)', coords: { x: 45, y: 20 }, evacTarget: { x: 52, y: 34 }, riskLevel: 'high', riskLabel: { id: 'Siaga Tinggi', en: 'High Risk' }, rainfall: 58, subsidence: 4.2, waterLevel: 84, pm25: 44, activeHelmets: 312, evacRoute: { id: 'Jalur Layang Pluit Timur → Koridor Aman Jl. Jembatan Tiga', en: 'Pluit East Elevated Road → Safe Corridor Jl. Jembatan Tiga' } },
  { id: 'bundaranhi', shortName: 'Jakpus - HI', name: 'Jakarta Pusat (Bundaran HI)', coords: { x: 50, y: 47 }, evacTarget: { x: 57, y: 43 }, riskLevel: 'low', riskLabel: { id: 'Aman Terkendali', en: 'Safe' }, rainfall: 18, subsidence: 1.4, waterLevel: 24, pm25: 38, activeHelmets: 428, evacRoute: { id: 'Koridor Utama M.H. Thamrin → Jalur Terlindung Stasiun MRT Bundaran HI', en: 'M.H. Thamrin Main Corridor → Elevated MRT Bundaran HI' } },
  { id: 'kemang', shortName: 'Jaksel - Kemang', name: 'Jakarta Selatan (Kemang)', coords: { x: 47, y: 78 }, evacTarget: { x: 38, y: 68 }, riskLevel: 'high', riskLabel: { id: 'Rawan Genangan', en: 'Flood Prone' }, rainfall: 52, subsidence: 1.1, waterLevel: 76, pm25: 36, activeHelmets: 196, evacRoute: { id: 'Flyover Pangeran Antasari → Koridor Tinggi Prapanca Raya', en: 'Pangeran Antasari Flyover → Upper Prapanca Raya' } },
  { id: 'cawang', shortName: 'Jaktim - Cawang', name: 'Jakarta Timur (Cawang)', coords: { x: 74, y: 63 }, evacTarget: { x: 82, y: 52 }, riskLevel: 'moderate', riskLabel: { id: 'Siaga Sedang', en: 'Moderate Watch' }, rainfall: 39, subsidence: 1.5, waterLevel: 54, pm25: 46, activeHelmets: 164, evacRoute: { id: 'Jalur Layang Kalimalang → Koridor MT Haryono Tinggi', en: 'Kalimalang Elevated Road → Upper MT Haryono' } },
  { id: 'grogol', shortName: 'Jakbar - Grogol', name: 'Jakarta Barat (Grogol)', coords: { x: 26, y: 43 }, evacTarget: { x: 35, y: 35 }, riskLevel: 'moderate', riskLabel: { id: 'Siaga Sedang', en: 'Moderate Watch' }, rainfall: 34, subsidence: 2.3, waterLevel: 48, pm25: 45, activeHelmets: 148, evacRoute: { id: 'Flyover Grogol → Jalur Aman Kyai Tapa - Tomang', en: 'Grogol Flyover → Safe Corridor Kyai Tapa - Tomang' } }
];

const INITIAL_RIDERS = [
  { id: 'SH-108', name: 'Dimas Prakoso', zoneId: 'bundaranhi', status: 'normal', location: 'Bundaran HI', battery: 94, points: 1420, rainRate: 18, pm25: 38 },
  { id: 'SH-214', name: 'Rizky Ramadhan', zoneId: 'penjaringan', status: 'alert', location: 'Pluit Raya', battery: 82, points: 2150, rainRate: 58, pm25: 44 },
  { id: 'SH-309', name: 'Nadia Kusuma', zoneId: 'kemang', status: 'alert', location: 'Kemang Raya', battery: 88, points: 1890, rainRate: 52, pm25: 36 }
];

const INITIAL_REPORTS = [
  { id: 'REP-501', zoneId: 'penjaringan', zoneName: 'Jakut - Pluit', rider: 'Rizky (SH-214)', title: { id: 'Genangan Air Pasang 30 cm', en: '30cm Tidal Flood' }, verified: false, points: 50 },
  { id: 'REP-502', zoneId: 'kemang', zoneName: 'Jaksel - Kemang', rider: 'Nadia (SH-309)', title: { id: 'Kali Krukut Meluap', en: 'Krukut River Overflow' }, verified: true, points: 50 }
];

export default function App() {
  const [lang, setLang] = useState('id');
  const t = TRANSLATIONS[lang];

  // States
  const [simMode, setSimMode] = useState('actual');
  const [activeKpi, setActiveKpi] = useState('flood'); // helmets, flood, air, sub
  const [zones, setZones] = useState(INITIAL_ZONES);
  const [selectedZoneId, setSelectedZoneId] = useState('kemang');
  const [mapLayer, setMapLayer] = useState('all');
  const [showRadar, setShowRadar] = useState(true);
  const [chartMetric, setChartMetric] = useState('water');
  
  const [riders, setRiders] = useState(INITIAL_RIDERS);
  const [reports, setReports] = useState(INITIAL_REPORTS);
  const [expandedRiderId, setExpandedRiderId] = useState(null);

  // Audio / Toast States
  const [voiceToast, setVoiceToast] = useState(null);
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [actionFeedback, setActionFeedback] = useState(null);
  const [mapZoom, setMapZoom] = useState(1);

  // Poppins Font
  useEffect(() => {
    const existing = document.getElementById('google-font-poppins');
    if (!existing) {
      const link = document.createElement('link');
      link.id = 'google-font-poppins';
      link.rel = 'stylesheet';
      link.href = 'https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700;800;900&display=swap';
      document.head.appendChild(link);
    }
    return () => {
      if ('speechSynthesis' in window) window.speechSynthesis.cancel();
    };
  }, []);

  // Audio Engine
  const playChime = () => {
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!AudioCtx) return;
      const ctx = new AudioCtx();
      const now = ctx.currentTime;
      [523.25, 659.25, 783.99].forEach((f, i) => {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(f, now + i * 0.1);
        gain.gain.setValueAtTime(0.1, now + i * 0.1);
        gain.gain.exponentialRampToValueAtTime(0.001, now + i * 0.1 + 0.2);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(now + i * 0.1);
        osc.stop(now + i * 0.1 + 0.25);
      });
    } catch (e) {}
  };

  const triggerToast = (msg, color = 'emerald') => {
    setActionFeedback({ msg, color });
    setTimeout(() => setActionFeedback(null), 3000);
  };

  const speakText = (text, target) => {
    playChime();
    setVoiceToast({ target, msg: text });
    setIsSpeaking(true);
    
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = lang === 'id' ? 'id-ID' : 'en-US';
      utterance.onend = () => { setIsSpeaking(false); setVoiceToast(null); };
      utterance.onerror = () => { setIsSpeaking(false); setVoiceToast(null); };
      window.speechSynthesis.speak(utterance);
    } else {
      setTimeout(() => { setIsSpeaking(false); setVoiceToast(null); }, 4000);
    }
  };

  // Interactions
  const handleSim = (mode) => {
    setSimMode(mode);
    playChime();
    if (mode === 'normal') {
      setZones(INITIAL_ZONES.map(z => ({ ...z, rainfall: Math.max(0, z.rainfall - 30), waterLevel: Math.max(10, z.waterLevel - 40), riskLevel: 'low' })));
      triggerToast(lang === 'id' ? 'Simulasi Cuaca Cerah Aktif' : 'Clear Weather Active', 'emerald');
    } else if (mode === 'storm') {
      setZones(INITIAL_ZONES.map(z => ({ ...z, rainfall: z.rainfall + 50, waterLevel: z.waterLevel + 60, riskLevel: 'high' })));
      triggerToast(lang === 'id' ? 'Simulasi Badai Ekstrem Aktif!' : 'Extreme Storm Active!', 'rose');
    } else {
      setZones(INITIAL_ZONES);
      triggerToast(lang === 'id' ? 'Mode Aktual Live Dipulihkan' : 'Live Mode Restored', 'teal');
    }
  };

  const handleVerify = (id) => {
    playChime();
    setReports(prev => prev.map(r => r.id === id ? { ...r, verified: true } : r));
    setRiders(prev => prev.map((r, i) => i === 0 ? { ...r, points: r.points + 50 } : r));
    triggerToast(lang === 'id' ? 'Laporan Terverifikasi! +50 Poin' : 'Report Verified! +50 Pts', 'emerald');
  };

  const handleLocalRain = (zoneId) => {
    playChime();
    setZones(prev => prev.map(z => z.id === zoneId ? { ...z, rainfall: z.rainfall + 20, waterLevel: z.waterLevel + 15 } : z));
    triggerToast(lang === 'id' ? `Hujan Lokal disimulasikan` : `Local rain simulated`, 'teal');
  };

  // Derived Data
  const selectedZone = useMemo(() => zones.find(z => z.id === selectedZoneId) || zones[0], [zones, selectedZoneId]);
  const totalHelmets = useMemo(() => zones.reduce((a, b) => a + b.activeHelmets, 0), [zones]);
  const avgPm25 = useMemo(() => Math.round(zones.reduce((a, b) => a + b.pm25, 0) / zones.length), [zones]);
  const maxSub = useMemo(() => Math.max(...zones.map(z => z.subsidence)), [zones]);

  const chartData = useMemo(() => {
    const slots = ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00', '24:00'];
    const curve = [0.6, 0.8, 1.0, 1.2, 0.9, 0.7, 0.5];
    return slots.map((time, i) => ({
      time,
      waterLevel: Math.round(selectedZone.waterLevel * curve[i]),
      rainfall: Math.round(selectedZone.rainfall * curve[i]),
      pm25: Math.round(selectedZone.pm25 * (0.9 + (i % 3) * 0.1))
    }));
  }, [selectedZone]);

  return (
    <div style={{ fontFamily: "'Poppins', sans-serif" }} className="min-h-screen text-slate-900 bg-slate-900 selection:bg-emerald-500 selection:text-white relative overflow-x-hidden">
      
      {/* BACKGROUND (Un-tinted Jakarta) */}
      <div 
        className="fixed inset-0 z-0 bg-cover bg-center bg-no-repeat"
        style={{ backgroundImage: "url('https://images.unsplash.com/photo-1555899434-94d1368aa7af?auto=format&fit=crop&w=2000&q=80')" }}
      />

      {/* FOREGROUND APP */}
      <div className="relative z-10 min-h-screen flex flex-col pb-10">
        
        {/* NAVBAR */}
        <header className="sticky top-0 z-50 bg-white/20 backdrop-blur-xl border-b border-white/30 px-6 py-3 shadow-lg">
          <div className="max-w-[1440px] mx-auto flex items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center shadow-lg">
                <Compass className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-xl font-extrabold tracking-tight text-white drop-shadow-md">SIGAP-JKT</h1>
                <span className="text-[10px] font-bold uppercase text-emerald-100 drop-shadow-sm">{t.nav.command}</span>
              </div>
            </div>

            <div className="flex items-center gap-3">
               {/* Language Toggle */}
               <div className="flex items-center bg-white/25 border border-white/40 rounded-xl p-1 shadow-inner">
                <Globe className="w-4 h-4 text-white ml-2 mr-1" />
                <button onClick={() => { setLang('id'); playChime(); }} className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${lang === 'id' ? 'bg-emerald-500 text-white shadow-md' : 'text-slate-100 hover:bg-white/20'}`}>ID</button>
                <button onClick={() => { setLang('en'); playChime(); }} className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${lang === 'en' ? 'bg-emerald-500 text-white shadow-md' : 'text-slate-100 hover:bg-white/20'}`}>EN</button>
              </div>
            </div>
          </div>
        </header>

        {/* TOASTS & BANNERS */}
        {actionFeedback && (
          <div className="fixed bottom-6 right-6 z-50 bg-white/90 backdrop-blur-lg border border-white/50 px-5 py-3 rounded-2xl shadow-2xl flex items-center gap-3 animate-bounce">
            <CheckCircle2 className={`w-5 h-5 text-${actionFeedback.color}-500`} />
            <span className="text-sm font-extrabold text-slate-800">{actionFeedback.msg}</span>
          </div>
        )}

        {voiceToast && (
          <div className="fixed top-20 left-1/2 -translate-x-1/2 w-[90%] max-w-2xl z-50 bg-gradient-to-r from-emerald-600/95 to-teal-600/95 backdrop-blur-xl border border-white/40 p-4 rounded-2xl shadow-2xl flex items-center justify-between text-white">
            <div className="flex items-center gap-3">
              <Volume2 className="w-6 h-6 animate-pulse" />
              <div>
                <span className="text-[10px] font-bold uppercase opacity-80 tracking-widest block">{voiceToast.target}</span>
                <span className="text-sm font-extrabold">{voiceToast.msg}</span>
              </div>
            </div>
            <button onClick={() => window.speechSynthesis.cancel()} className="p-2 rounded-xl hover:bg-white/20"><X className="w-5 h-5"/></button>
          </div>
        )}

        {/* MAIN DASHBOARD CONTENT */}
        <main className="flex-1 max-w-[1440px] w-full mx-auto px-4 sm:px-6 pt-6 space-y-6">
          
          {/* HEADER ROW & SIMULATIONS */}
          <div className="bg-white/25 backdrop-blur-xl border border-white/40 shadow-xl rounded-3xl p-5 sm:p-6 flex flex-col lg:flex-row justify-between gap-6">
            <div className="max-w-2xl text-slate-900">
              <span className="inline-block px-3 py-1 rounded-full bg-white/40 border border-white/50 text-[10px] font-extrabold uppercase tracking-widest text-emerald-950 mb-3 shadow-sm">
                {t.header.tag}
              </span>
              <h2 className="text-2xl sm:text-3xl font-extrabold leading-tight">{t.header.title}</h2>
              <p className="text-sm font-semibold mt-2 text-slate-800 leading-relaxed">{t.header.desc}</p>
            </div>
            
            <div className="bg-white/30 border border-white/50 p-4 rounded-2xl shadow-inner flex flex-col justify-center gap-3 min-w-[280px]">
              <span className="text-xs font-bold text-slate-900 uppercase tracking-widest flex items-center gap-2">
                <Radio className="w-4 h-4 text-emerald-700 animate-pulse" />
                {t.nav.cta}
              </span>
              <div className="grid grid-cols-1 gap-2">
                {[
                  { id: 'normal', label: t.sim.normal, color: 'bg-emerald-500' },
                  { id: 'actual', label: t.sim.actual, color: 'bg-teal-600' },
                  { id: 'storm', label: t.sim.storm, color: 'bg-rose-500' }
                ].map(s => (
                  <button 
                    key={s.id} onClick={() => handleSim(s.id)}
                    className={`py-2 px-4 rounded-xl text-sm font-bold transition-all shadow-md flex items-center justify-between ${simMode === s.id ? `${s.color} text-white scale-[1.02]` : 'bg-white/60 hover:bg-white/80 text-slate-800'}`}
                  >
                    <span>{s.label}</span>
                    {simMode === s.id && <CheckCircle2 className="w-4 h-4" />}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* 4 KPI CARDS */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            {[
              { id: 'helmets', icon: Users, val: totalHelmets.toLocaleString(), col: 'text-emerald-900', bg: 'bg-emerald-500', data: t.kpi.helmets },
              { id: 'flood', icon: CloudRain, val: simMode==='storm'? (lang==='id'?'Siaga Badai':'Storm Alert') : (lang==='id'?'Aman':'Safe'), col: simMode==='storm'?'text-rose-600':'text-teal-900', bg: simMode==='storm'?'bg-rose-500':'bg-teal-600', data: t.kpi.flood },
              { id: 'air', icon: Wind, val: avgPm25, col: 'text-slate-900', bg: 'bg-violet-500', data: t.kpi.air },
              { id: 'sub', icon: TrendingDown, val: `-${maxSub}`, col: 'text-violet-950', bg: 'bg-slate-800', data: t.kpi.sub }
            ].map(kpi => {
              const Icon = kpi.icon;
              return (
                <button 
                  key={kpi.id} onClick={() => { setActiveKpi(kpi.id); playChime(); }}
                  className={`text-left bg-white/25 backdrop-blur-xl border transition-all rounded-3xl p-5 flex flex-col justify-between hover:bg-white/40 shadow-lg ${activeKpi === kpi.id ? 'border-white/80 ring-2 ring-white/50 scale-[1.02]' : 'border-white/30'}`}
                >
                  <div className="flex justify-between items-start mb-2">
                    <span className="text-xs font-extrabold text-slate-800 uppercase tracking-widest">{kpi.data.title}</span>
                    <div className={`w-10 h-10 rounded-xl ${kpi.bg} text-white flex items-center justify-center shadow-md`}>
                      <Icon className="w-5 h-5" />
                    </div>
                  </div>
                  <div className="flex items-baseline gap-2">
                    <span className={`text-3xl font-black ${kpi.col} drop-shadow-sm`}>{kpi.val}</span>
                    <span className={`text-[10px] font-bold px-2 py-1 rounded-full text-white shadow-sm ${kpi.bg}`}>{kpi.data.unit}</span>
                  </div>
                  <div className="mt-3 pt-3 border-t border-white/30 text-xs font-bold text-slate-700 flex justify-between">
                    <span>{kpi.data.sub}</span>
                    <ArrowUpRight className="w-4 h-4 opacity-50"/>
                  </div>
                </button>
              )
            })}
          </div>

          {/* MAIN TWO-COLUMN LAYOUT (MAP & SIDE PANEL) */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
            
            {/* LEFT: SVG MAP (7 COLUMNS) */}
            <div className="lg:col-span-7 bg-white/25 backdrop-blur-xl border border-white/40 shadow-2xl rounded-3xl p-5 flex flex-col">
              <div className="flex flex-wrap items-center justify-between gap-4 mb-4">
                <div>
                  <h3 className="text-lg font-extrabold text-slate-900 flex items-center gap-2"><MapPin className="w-5 h-5 text-emerald-700"/> {t.map.title}</h3>
                  <p className="text-xs font-semibold text-slate-800">{t.map.sub}</p>
                </div>
                <div className="flex flex-wrap items-center gap-2 text-xs">
                  <button onClick={() => setShowRadar(!showRadar)} className={`px-3 py-1.5 rounded-xl font-bold shadow-md ${showRadar ? 'bg-teal-600 text-white' : 'bg-white/50 text-slate-800 border border-white/50'}`}>
                    {t.map.radar}
                  </button>
                  <select value={mapLayer} onChange={e => setMapLayer(e.target.value)} className="bg-white/60 border border-white/50 text-slate-900 font-bold px-3 py-1.5 rounded-xl outline-none shadow-sm focus:bg-white/80">
                    <option value="all">{t.layer.all}</option>
                    <option value="flood">{t.layer.flood}</option>
                    <option value="sub">{t.layer.sub}</option>
                  </select>
                </div>
              </div>

              {/* SVG Canvas Map Area */}
              <div className="relative w-full h-[400px] rounded-2xl overflow-hidden bg-gradient-to-b from-teal-900/10 to-emerald-900/20 border border-white/50 shadow-inner">
                {/* Zoom Controls */}
                <div className="absolute top-3 right-3 z-30 flex flex-col gap-1 bg-white/60 backdrop-blur-md p-1 rounded-xl border border-white/50 shadow-md">
                  <button onClick={() => setMapZoom(z => Math.min(1.5, z + 0.1))} className="p-2 rounded-lg hover:bg-white text-slate-800"><ZoomIn className="w-4 h-4"/></button>
                  <button onClick={() => setMapZoom(z => Math.max(0.8, z - 0.1))} className="p-2 rounded-lg hover:bg-white text-slate-800"><ZoomOut className="w-4 h-4"/></button>
                  <button onClick={() => setMapZoom(1)} className="p-2 rounded-lg hover:bg-white text-slate-800"><RotateCcw className="w-4 h-4"/></button>
                </div>

                <div style={{ transform: `scale(${mapZoom})`, transformOrigin: 'center center' }} className="w-full h-full relative transition-transform duration-300">
                  <svg viewBox="0 0 100 100" preserveAspectRatio="none" className="w-full h-full">
                    {/* Background Grid & Sea */}
                    <path d="M 0,0 L 100,0 L 100,15 Q 78,20 55,16 Q 30,12 0,18 Z" fill="rgba(20, 184, 166, 0.2)" />
                    {/* Rivers */}
                    <path d="M 48,100 Q 50,50 47,16 M 76,100 Q 68,50 53,16" fill="none" stroke="rgba(45, 212, 191, 0.5)" strokeWidth="1" strokeDasharray="3 2" />
                    
                    {/* Radar */}
                    {showRadar && (
                      <g className="origin-center animate-[spin_8s_linear_infinite]" style={{ transformOrigin: '50px 50px' }}>
                        <circle cx="50" cy="50" r="45" fill="url(#radarGrad)" />
                        <line x1="50" y1="50" x2="50" y2="5" stroke="rgba(16, 185, 129, 0.4)" strokeWidth="1" />
                        <defs>
                          <radialGradient id="radarGrad">
                            <stop offset="0%" stopColor="rgba(16, 185, 129, 0.2)" />
                            <stop offset="100%" stopColor="rgba(16, 185, 129, 0)" />
                          </radialGradient>
                        </defs>
                      </g>
                    )}

                    {/* Zone Heatmaps & Markers */}
                    {zones.map((z) => {
                      const isSelected = z.id === selectedZoneId;
                      const rad = mapLayer === 'sub' ? z.subsidence * 3 : mapLayer === 'flood' ? z.waterLevel * 0.15 : 10;
                      const color = z.riskLevel === 'high' ? 'rgba(244,63,94,0.4)' : z.riskLevel === 'moderate' ? 'rgba(139,92,246,0.3)' : 'rgba(16,185,129,0.3)';
                      return (
                        <g key={z.id}>
                          <circle cx={z.coords.x} cy={z.coords.y} r={Math.max(5, rad)} fill={color} stroke={isSelected ? '#fff' : 'none'} strokeWidth="1" />
                        </g>
                      )
                    })}
                  </svg>

                  {/* HTML Overlay Pins */}
                  {zones.map(z => {
                    const isSelected = z.id === selectedZoneId;
                    return (
                      <button
                        key={`pin-${z.id}`}
                        onClick={() => { setSelectedZoneId(z.id); playChime(); }}
                        style={{ left: `${z.coords.x}%`, top: `${z.coords.y}%` }}
                        className={`absolute -translate-x-1/2 -translate-y-1/2 transition-all z-20 flex flex-col items-center gap-1 ${isSelected ? 'scale-110 z-30' : 'hover:scale-105'}`}
                      >
                        <div className={`px-2 py-1 rounded-xl text-[10px] font-extrabold shadow-lg border border-white/60 text-white whitespace-nowrap flex items-center gap-1.5 ${z.riskLevel==='high'?'bg-rose-500':z.riskLevel==='moderate'?'bg-violet-500':'bg-emerald-500'} ${isSelected ? 'ring-4 ring-white/50' : ''}`}>
                          <span className="w-1.5 h-1.5 rounded-full bg-white animate-ping"/> {z.shortName}
                        </div>
                        {isSelected && (
                          <div className="bg-white/90 backdrop-blur-md px-2 py-0.5 rounded text-[10px] font-bold text-slate-900 border border-slate-200 shadow-md">
                            {z.waterLevel} cm
                          </div>
                        )}
                      </button>
                    )
                  })}
                </div>
              </div>

              {/* Map Legend */}
              <div className="mt-4 flex flex-wrap items-center gap-4 text-xs font-bold text-slate-800">
                <span className="flex items-center gap-1.5"><div className="w-3 h-3 rounded-full bg-rose-500 shadow-sm border border-white"/> {t.legend.high}</span>
                <span className="flex items-center gap-1.5"><div className="w-3 h-3 rounded-full bg-violet-500 shadow-sm border border-white"/> {t.legend.med}</span>
                <span className="flex items-center gap-1.5"><div className="w-3 h-3 rounded-full bg-emerald-500 shadow-sm border border-white"/> {t.legend.low}</span>
              </div>
            </div>

            {/* RIGHT: SECTOR PANEL & CHART (5 COLUMNS) */}
            <div className="lg:col-span-5 flex flex-col gap-6">
              
              {/* Selected Zone Telemetry */}
              <div className="bg-white/25 backdrop-blur-xl border border-white/40 shadow-xl rounded-3xl p-5 flex flex-col">
                <div className="flex justify-between items-start mb-4">
                  <div>
                    <span className="text-[10px] font-extrabold uppercase tracking-widest text-emerald-900 bg-white/40 px-2 py-1 rounded-lg border border-white/50 shadow-sm mb-2 inline-block">Sektor Terpilih</span>
                    <h3 className="text-2xl font-black text-slate-900">{selectedZone.name}</h3>
                  </div>
                  <span className={`px-3 py-1 rounded-full text-xs font-bold text-white shadow-md ${selectedZone.riskLevel==='high'?'bg-rose-500':selectedZone.riskLevel==='moderate'?'bg-violet-500':'bg-emerald-500'}`}>
                    {selectedZone.riskLabel[lang]}
                  </span>
                </div>

                <div className="grid grid-cols-2 gap-3 mb-4">
                  <div className="bg-white/40 border border-white/50 p-3 rounded-2xl shadow-sm">
                    <span className="text-[10px] font-bold text-slate-700 block uppercase">{t.zone.water}</span>
                    <span className={`text-xl font-extrabold ${selectedZone.waterLevel > 70 ? 'text-rose-600' : 'text-slate-900'}`}>{selectedZone.waterLevel} cm</span>
                  </div>
                  <div className="bg-white/40 border border-white/50 p-3 rounded-2xl shadow-sm">
                    <span className="text-[10px] font-bold text-slate-700 block uppercase">{t.zone.rainfall}</span>
                    <span className="text-xl font-extrabold text-teal-800">{selectedZone.rainfall} mm/h</span>
                  </div>
                  <div className="bg-white/40 border border-white/50 p-3 rounded-2xl shadow-sm">
                    <span className="text-[10px] font-bold text-slate-700 block uppercase">{t.zone.subsidence}</span>
                    <span className="text-xl font-extrabold text-violet-800">-{selectedZone.subsidence} cm</span>
                  </div>
                  <div className="bg-white/40 border border-white/50 p-3 rounded-2xl shadow-sm">
                    <span className="text-[10px] font-bold text-slate-700 block uppercase">{t.zone.helmets}</span>
                    <span className="text-xl font-extrabold text-emerald-800">{selectedZone.activeHelmets}</span>
                  </div>
                </div>

                <div className="bg-white/50 border border-emerald-400 p-3 rounded-xl mb-4 shadow-inner">
                  <span className="text-xs font-extrabold text-emerald-900 flex items-center gap-1.5 mb-1"><Navigation className="w-4 h-4"/> {t.zone.evacTitle}</span>
                  <span className="text-sm font-bold text-slate-900">{selectedZone.evacRoute[lang]}</span>
                </div>

                <div className="flex gap-2">
                  <button onClick={() => {
                    const msg = lang === 'id' 
                      ? `Peringatan untuk sektor ${selectedZone.name}. Tinggi air ${selectedZone.waterLevel} sentimeter. Ikuti rute aman: ${selectedZone.evacRoute.id}`
                      : `Alert for ${selectedZone.name}. Water level at ${selectedZone.waterLevel} centimeters. Follow safe route: ${selectedZone.evacRoute.en}`;
                    speakText(msg, selectedZone.shortName);
                  }} className="flex-1 py-3 px-2 bg-gradient-to-r from-emerald-500 to-teal-600 text-white font-bold text-xs rounded-xl shadow-lg hover:scale-[1.02] transition-all flex items-center justify-center gap-1.5">
                    <Volume2 className="w-4 h-4" /> {t.action.broadcast}
                  </button>
                  <button onClick={() => handleLocalRain(selectedZone.id)} className="py-3 px-3 bg-white/60 hover:bg-white/80 border border-white text-slate-800 font-bold text-xs rounded-xl shadow-sm transition-all" title="Simulate Rain">
                    <CloudRain className="w-4 h-4" />
                  </button>
                </div>
              </div>

              {/* Chart Component */}
              <div className="bg-white/25 backdrop-blur-xl border border-white/40 shadow-xl rounded-3xl p-5 flex-1 flex flex-col min-h-[280px]">
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <h3 className="text-sm font-extrabold text-slate-900">{t.chart.title}</h3>
                    <p className="text-[10px] font-bold text-slate-700">{t.chart.sub}</p>
                  </div>
                  <select value={chartMetric} onChange={(e)=>setChartMetric(e.target.value)} className="text-xs font-bold bg-white/60 border border-white/50 text-slate-900 px-2 py-1 rounded-lg outline-none shadow-sm">
                    <option value="water">{t.chart.water}</option>
                    <option value="rain">{t.chart.rain}</option>
                    <option value="air">{t.chart.air}</option>
                  </select>
                </div>
                <div className="flex-1 w-full mt-2">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={chartData} margin={{ top: 5, right: 0, left: -25, bottom: 0 }}>
                      <defs>
                        <linearGradient id="chartGrad" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor={chartMetric==='water'?'#f43f5e':chartMetric==='rain'?'#0d9488':'#8b5cf6'} stopOpacity={0.8}/>
                          <stop offset="95%" stopColor={chartMetric==='water'?'#f43f5e':chartMetric==='rain'?'#0d9488':'#8b5cf6'} stopOpacity={0}/>
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="rgba(15,23,42,0.1)" vertical={false} />
                      <XAxis dataKey="time" stroke="#1e293b" tick={{fontSize: 10, fontWeight: 700}} axisLine={false} tickLine={false} />
                      <YAxis stroke="#1e293b" tick={{fontSize: 10, fontWeight: 700}} axisLine={false} tickLine={false} />
                      <Tooltip contentStyle={{backgroundColor:'rgba(255,255,255,0.9)', borderRadius:'12px', border:'none', boxShadow:'0 4px 15px rgba(0,0,0,0.1)', fontWeight:'bold', fontSize:'12px', color:'#0f172a'}} />
                      <Area type="monotone" dataKey={chartMetric==='water'?'waterLevel':chartMetric==='rain'?'rainfall':'pm25'} stroke={chartMetric==='water'?'#e11d48':chartMetric==='rain'?'#0f766e':'#7c3aed'} strokeWidth={3} fill="url(#chartGrad)" />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </div>
          </div>

          {/* BOTTOM ROW (FLEET & REPORTS) */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 pb-8">
            
            {/* RIDER FLEET */}
            <div className="bg-white/25 backdrop-blur-xl border border-white/40 shadow-xl rounded-3xl p-5">
              <div className="flex justify-between items-center mb-4 border-b border-white/30 pb-3">
                <div className="flex items-center gap-2">
                  <div className="w-8 h-8 rounded-lg bg-emerald-500 text-white flex items-center justify-center shadow-md"><Users className="w-4 h-4"/></div>
                  <div><h3 className="text-sm font-extrabold text-slate-900">{t.fleet.title}</h3><p className="text-[10px] font-bold text-slate-700">{t.fleet.sub}</p></div>
                </div>
              </div>
              <div className="space-y-3">
                {riders.map(rider => (
                  <div key={rider.id} className="bg-white/40 hover:bg-white/60 border border-white/50 rounded-2xl p-3 shadow-sm transition-all">
                    <div className="flex justify-between items-center cursor-pointer" onClick={() => setExpandedRiderId(expandedRiderId === rider.id ? null : rider.id)}>
                      <div className="flex items-center gap-3">
                        <span className={`px-2 py-1 rounded-md text-[10px] font-black text-white ${rider.status==='alert'?'bg-rose-500':'bg-emerald-600'}`}>{rider.id}</span>
                        <div>
                          <p className="text-sm font-extrabold text-slate-900">{rider.name}</p>
                          <p className="text-[10px] font-bold text-slate-700">{rider.location} • {rider.battery}% Bat</p>
                        </div>
                      </div>
                      <div className="flex flex-col items-end">
                        <span className="text-xs font-black text-violet-700">{rider.points} pts</span>
                        {expandedRiderId === rider.id ? <ChevronUp className="w-4 h-4 text-slate-600"/> : <ChevronDown className="w-4 h-4 text-slate-600"/>}
                      </div>
                    </div>
                    {expandedRiderId === rider.id && (
                      <div className="mt-3 pt-3 border-t border-white/40 grid grid-cols-2 gap-2 text-xs font-bold text-slate-800">
                        <div className="bg-white/50 p-2 rounded-xl">PM2.5: {rider.pm25} µg/m³</div>
                        <div className="bg-white/50 p-2 rounded-xl">Hujan: {rider.rainRate} mm/j</div>
                        <button onClick={() => {
                          const msg = lang === 'id' ? `Halo ${rider.name}, ini adalah tes koneksi audio konduksi tulang.` : `Hello ${rider.name}, this is a bone conduction audio test.`;
                          speakText(msg, rider.id);
                        }} className="col-span-2 py-2 bg-slate-800 text-white rounded-xl flex items-center justify-center gap-2 hover:bg-slate-700 transition-all">
                          <Volume2 className="w-3.5 h-3.5"/> Kirim Suara Audio
                        </button>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>

            {/* GAMIFICATION REPORTS */}
            <div className="bg-white/25 backdrop-blur-xl border border-white/40 shadow-xl rounded-3xl p-5">
              <div className="flex justify-between items-center mb-4 border-b border-white/30 pb-3">
                <div className="flex items-center gap-2">
                  <div className="w-8 h-8 rounded-lg bg-violet-600 text-white flex items-center justify-center shadow-md"><FileText className="w-4 h-4"/></div>
                  <div><h3 className="text-sm font-extrabold text-slate-900">{t.reports.title}</h3><p className="text-[10px] font-bold text-slate-700">{t.reports.sub}</p></div>
                </div>
              </div>
              <div className="space-y-3">
                {reports.map(rep => (
                  <div key={rep.id} className="bg-white/40 border border-white/50 rounded-2xl p-4 shadow-sm flex flex-col sm:flex-row justify-between sm:items-center gap-3">
                    <div>
                      <div className="flex items-center gap-2 mb-1">
                        <span className="text-[10px] font-black uppercase text-teal-900 bg-white/60 px-2 py-0.5 rounded shadow-sm">{rep.zoneName}</span>
                      </div>
                      <p className="text-sm font-extrabold text-slate-900">{rep.title[lang]}</p>
                      <p className="text-[11px] font-bold text-slate-700">Pelapor: {rep.rider}</p>
                    </div>
                    <div>
                      {rep.verified ? (
                        <span className="inline-flex items-center gap-1 text-[11px] font-black px-3 py-1.5 rounded-xl bg-emerald-500 text-white shadow-sm">
                          <CheckCircle2 className="w-3.5 h-3.5"/> Verified
                        </span>
                      ) : (
                        <button onClick={() => handleVerify(rep.id)} className="w-full sm:w-auto text-[11px] font-black px-4 py-2 rounded-xl bg-gradient-to-r from-emerald-500 to-teal-600 text-white shadow-md hover:scale-105 transition-all">
                          {t.action.verify}
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
            
          </div>
        </main>
      </div>
    </div>
  );
}
