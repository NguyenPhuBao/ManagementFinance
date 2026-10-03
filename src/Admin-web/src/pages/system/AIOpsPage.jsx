import React, { useState, useEffect, useMemo } from 'react';
import aiopsApi from '../../api/aiops.api';
import adminApi from '../../api/admin.api';
import useSocket from '../../hooks/useSocket';
import { formatDateTime } from '../../utils/format';

const AIOpsPage = () => {
  const [statusData, setStatusData] = useState(null);
  const [historyData, setHistoryData] = useState([]);
  const [quarantineList, setQuarantineList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [calibrating, setCalibrating] = useState(false);
  const [unblockingHash, setUnblockingHash] = useState(null);
  const [feedback, setFeedback] = useState(null);

  // Mitigation modal state
  const [showMitigationModal, setShowMitigationModal] = useState(false);
  const [showCalibrateModal, setShowCalibrateModal] = useState(false);
  const [mitigationReason, setMitigationReason] = useState('Phòng vệ khẩn cấp AIOps Sentinel do phát hiện nguy cơ cao');
  const [mitigating, setMitigating] = useState(false);

  // Target Concurrency Scaling state
  const [selectedConcurrency, setSelectedConcurrency] = useState(1000);
  const [customConcurrency, setCustomConcurrency] = useState('1000');
  const [savingScale, setSavingScale] = useState(false);

  // Multi-Vector Trend Chart state & Hover tooltip
  const [activeVectorTab, setActiveVectorTab] = useState('all'); // 'all' | 'auth' | 'traffic' | 'exploit' | 'resource'
  const [hoveredPointIndex, setHoveredPointIndex] = useState(null);

  // Socket.io connection
  const socket = useSocket();

  const fetchAIOpsData = async () => {
    try {
      setLoading(true);
      const [statusRes, historyRes, quarantineRes] = await Promise.all([
        aiopsApi.getStatus(),
        aiopsApi.getHistory(),
        aiopsApi.getQuarantineList(),
      ]);

      const sData = statusRes?.data || statusRes;
      const hData = historyRes?.data || historyRes;
      const qData = quarantineRes?.data || quarantineRes;

      if (sData) {
        setStatusData(sData);
        if (sData.targetConcurrency) {
          setSelectedConcurrency(sData.targetConcurrency);
          setCustomConcurrency(String(sData.targetConcurrency));
        }
      }
      if (Array.isArray(hData)) setHistoryData(hData);
      if (Array.isArray(qData)) setQuarantineList(qData);
    } catch (err) {
      console.error('[AIOpsPage] Error fetching data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAIOpsData();

    // Polling dự phòng mỗi 60 giây (luồng chính đã dùng Socket.io stream 3s/lần)
    const interval = setInterval(() => {
      fetchAIOpsData();
    }, 60000);

    return () => clearInterval(interval);
  }, []);

  // Lắng nghe sự kiện Socket.io thời gian thực
  useEffect(() => {
    if (!socket) return;

    // 1. Nhận luồng nhịp tim phần cứng & Threat Score 3s/lần
    const handleMetricsStream = (metrics) => {
      if (!metrics) return;
      setStatusData((prev) => ({
        ...prev,
        threatScore: metrics.threatScore ?? prev?.threatScore ?? 5,
        status: metrics.threatStatus || prev?.status || 'NORMAL',
        vectorScores: metrics.vectorScores || prev?.vectorScores || { auth: 0, traffic: 0, exploit: 0, resource: 0 },
        vectorDefenses: metrics.vectorDefenses || prev?.vectorDefenses || {},
        recommendedAction: metrics.recommendedAction || prev?.recommendedAction || null,
        targetConcurrency: metrics.targetConcurrency || prev?.targetConcurrency || 1000,
        sample: {
          ...(prev?.sample || {}),
          cpuPercent: metrics.cpuPercent,
          ramPercent: metrics.ramPercent,
          eventLoopLagMs: metrics.eventLoopLagMs,
          requestsPerMin: metrics.requestsPerMin,
        },
        lastEvaluatedAt: metrics.timestamp,
      }));
    };

    const handleAlert = (data) => {
      if (data) {
        setStatusData(prev => ({
          ...prev,
          threatScore: data.threatScore,
          status: data.status,
          vectorScores: data.vectorScores || prev?.vectorScores || { auth: 0, traffic: 0, exploit: 0, resource: 0 },
          vectorDefenses: data.vectorDefenses || prev?.vectorDefenses || {},
          targetConcurrency: data.targetConcurrency || prev?.targetConcurrency || 1000,
          anomalies: data.anomalies,
          recommendedAction: data.recommendedAction,
          sample: data.sample,
          lastEvaluatedAt: data.timestamp,
        }));
      }
    };

    const handleBlocked = (blockData) => {
      console.log('[AIOps] Nguồn IP bị cô lập tự động:', blockData);
      setFeedback({
        ok: false,
        msg: `🛡️ [AIOPS ĐÃ CHẶN ĐỨNG NGUỒN TẤN CÔNG] IP ${blockData.maskedIp} đã bị ngắt kết nối lập tức | Lý do: ${blockData.reason}`,
      });
      setQuarantineList(prev => [blockData, ...prev.filter(x => x.hash !== blockData.hash)]);
    };

    socket.on('admin.metrics_stream', handleMetricsStream);
    socket.on('admin.security_alert', handleAlert);
    socket.on('admin.security_blocked', handleBlocked);

    return () => {
      socket.off('admin.metrics_stream', handleMetricsStream);
      socket.off('admin.security_alert', handleAlert);
      socket.off('admin.security_blocked', handleBlocked);
    };
  }, [socket]);

  // Xử lý cập nhật quy mô người dùng mục tiêu (Concurrency Scaler)
  const handleApplyScale = async (scaleToApply) => {
    const val = parseInt(scaleToApply ?? customConcurrency, 10);
    if (!val || val < 100 || val > 50000) {
      setFeedback({ ok: false, msg: 'Vui lòng chọn hoặc nhập số lượng người dùng từ 100 đến 50,000.' });
      return;
    }
    try {
      setSavingScale(true);
      const res = await aiopsApi.setScale(val);
      setSelectedConcurrency(val);
      setCustomConcurrency(String(val));
      setStatusData(prev => ({
        ...prev,
        targetConcurrency: val,
      }));
      setFeedback({
        ok: true,
        msg: res?.message || `Đã cập nhật quy mô chịu tải mục tiêu: ${val.toLocaleString('vi-VN')} người dùng đồng thời!`
      });
    } catch (err) {
      setFeedback({
        ok: false,
        msg: err?.response?.data?.message || err?.message || 'Cập nhật quy mô thất bại.'
      });
    } finally {
      setSavingScale(false);
    }
  };

  // Xử lý mở khóa / gỡ chặn IP thủ công
  const handleUnblock = async (hash) => {
    if (!window.confirm('Bạn có chắc muốn gỡ chặn và mở khóa kết nối cho IP này?')) return;
    try {
      setUnblockingHash(hash);
      await aiopsApi.unblockQuarantine(hash);
      setFeedback({ ok: true, msg: 'Đã gỡ chặn và khôi phục quyền truy cập cho nguồn IP thành công.' });
      setQuarantineList(prev => prev.filter(x => x.hash !== hash));
    } catch (err) {
      setFeedback({ ok: false, msg: err?.response?.data?.message || err?.message || 'Gỡ chặn thất bại.' });
    } finally {
      setUnblockingHash(null);
    }
  };

  // Xử lý tái hiệu chuẩn đường chuẩn
  const handleCalibrate = async () => {
    setShowCalibrateModal(false);
    try {
      setCalibrating(true);
      setFeedback(null);
      const res = await aiopsApi.calibrate();
      setFeedback({ ok: true, msg: res?.message || 'Đã tái hiệu chuẩn mô hình máy học thành công.' });
      await fetchAIOpsData();
    } catch (err) {
      const errMsg = err?.response?.data?.message || err?.message || '';
      if (errMsg.includes('Route not found')) {
        setFeedback({
          ok: false,
          msg: '⚠️ Endpoint máy học chưa được triển khai trên máy chủ Cloud (Render). Vui lòng kết nối Backend Local (cổng 3000) hoặc chờ quá trình deploy Cloud hoàn tất.',
        });
      } else {
        setFeedback({ ok: false, msg: errMsg || 'Hiệu chuẩn thất bại.' });
      }
    } finally {
      setCalibrating(false);
    }
  };

  // Xử lý kích hoạt bảo trì khẩn cấp 1-click
  const handleTriggerMitigation = async () => {
    try {
      setMitigating(true);
      await adminApi.setMaintenanceStatus({
        active: true,
        reason: mitigationReason.trim() || 'Phòng vệ khẩn cấp AIOps Sentinel',
        isEmergency: true,
      });
      setFeedback({
        ok: true,
        msg: '🚨 ĐÃ KÍCH HOẠT BẢO TRÌ KHẨN CẤP THÀNH CÔNG! Toàn bộ kết nối khách đã bị chặn để bảo vệ hệ thống.',
      });
      setShowMitigationModal(false);
    } catch (err) {
      setFeedback({ ok: false, msg: err?.response?.data?.message || 'Kích hoạt bảo trì khẩn cấp thất bại.' });
    } finally {
      setMitigating(false);
    }
  };

  const threatScore = statusData?.threatScore ?? 5;
  const currentStatus = statusData?.status || 'NORMAL';
  const targetConcurrency = statusData?.targetConcurrency || selectedConcurrency || 1000;
  const vectorScores = statusData?.vectorScores || { auth: 0, traffic: 0, exploit: 0, resource: 0 };
  const vectorDefenses = statusData?.vectorDefenses || {};
  const sample = statusData?.sample || {};
  const anomalies = statusData?.anomalies || [];
  const recommendedAction = statusData?.recommendedAction;

  // Tính toán dung lượng kỳ vọng dựa trên targetConcurrency
  const baselineRpm = targetConcurrency * 10;
  const safePeakRpm = baselineRpm * 3;
  const quarantineThreshold = Math.max(150, Math.round(20 + 50 * Math.log10(targetConcurrency)));

  // Cơ chế phòng vệ cá nhân hóa: Chỉ kích hoạt bảo trì khẩn cấp khi Vector 4 (Tài nguyên) vượt ngưỡng nguy cơ sập dây chuyền
  const isEmergencyResourceRisk = useMemo(() => {
    return (
      recommendedAction === 'EMERGENCY_MAINTENANCE' ||
      (vectorScores.resource >= 85) ||
      (vectorScores.resource >= 70 && (sample?.errorRate5xx || 0) >= 0.15 && (sample?.eventLoopLagMs || 0) >= 250)
    );
  }, [recommendedAction, vectorScores.resource, sample]);

  // Hàm tiện ích lấy style theo điểm số của từng vectơ
  const getVectorTheme = (score) => {
    if (score >= 80) return { bg: 'bg-red-500', text: 'text-red-700', badge: 'bg-red-100 text-red-800 border-red-300', label: 'Nguy cấp' };
    if (score >= 60) return { bg: 'bg-orange-500', text: 'text-orange-700', badge: 'bg-orange-100 text-orange-800 border-orange-300', label: 'Cảnh báo' };
    if (score >= 30) return { bg: 'bg-amber-500', text: 'text-amber-700', badge: 'bg-amber-100 text-amber-800 border-amber-300', label: 'Theo dõi' };
    return { bg: 'bg-emerald-500', text: 'text-emerald-700', badge: 'bg-emerald-100 text-emerald-800 border-emerald-300', label: 'Bình thường' };
  };

  // Tính toán màu sắc hiển thị theo Threat Score tổng hợp
  const theme = useMemo(() => {
    if (threatScore >= 90) {
      return {
        badgeBg: 'bg-red-100 text-red-800 border-red-300',
        color: '#ef4444',
        label: 'NGUY CẤP (CRITICAL)',
        glow: 'ring-4 ring-red-400/40',
        border: 'border-red-400 bg-red-50/50',
      };
    }
    if (threatScore >= 80) {
      return {
        badgeBg: 'bg-orange-100 text-orange-800 border-orange-300',
        color: '#f97316',
        label: 'CẢNH BÁO CAO (WARNING)',
        glow: 'ring-4 ring-orange-400/30',
        border: 'border-orange-400 bg-orange-50/50',
      };
    }
    if (threatScore >= 60) {
      return {
        badgeBg: 'bg-amber-100 text-amber-800 border-amber-300',
        color: '#f59e0b',
        label: 'TĂNG CAO (ELEVATED)',
        glow: 'ring-4 ring-amber-400/20',
        border: 'border-amber-400 bg-amber-50/40',
      };
    }
    return {
      badgeBg: 'bg-emerald-100 text-emerald-800 border-emerald-300',
      color: '#10b981',
      label: 'BÌNH THƯỜNG (NORMAL)',
      glow: '',
      border: 'border-emerald-300 bg-emerald-50/40',
    };
  }, [threatScore]);

  // Chuẩn bị đường vẽ SVG độc lập cho 4 Vectơ Rủi Ro (60 mẫu gần nhất — 10 phút)
  const chartSvgPaths = useMemo(() => {
    if (!historyData || historyData.length === 0) {
      return {
        samples: [],
        auth: { path: '', area: '', points: [], color: '#f59e0b', name: '1. Xác Thực & Danh Tính', id: 'auth' },
        traffic: { path: '', area: '', points: [], color: '#3b82f6', name: '2. Lưu Lượng & DoS', id: 'traffic' },
        exploit: { path: '', area: '', points: [], color: '#f43f5e', name: '3. Khai Thác Lỗ Hổng', id: 'exploit' },
        resource: { path: '', area: '', points: [], color: '#0d9488', name: '4. Tài Nguyên Máy Chủ', id: 'resource' },
        composite: { path: '', area: '', points: [], color: '#8b5cf6', name: 'Điểm Tổng Hợp (Composite)', id: 'composite' },
      };
    }
    const width = 800;
    const height = 180;
    const padding = 25;

    const maxVal = 100;
    const minVal = 0;
    const count = historyData.length;
    const stepX = count > 1 ? (width - 2 * padding) / (count - 1) : width;

    // Trích xuất điểm số của 4 vector cho từng mẫu lịch sử
    const samples = historyData.map((d, i) => {
      const x = padding + i * stepX;
      const vs = d.vectorScores || {};
      
      const authScore = vs.auth !== undefined ? vs.auth : (d.failedLogins ? Math.min(100, d.failedLogins * 10) : 0);
      const trafficScore = vs.traffic !== undefined ? vs.traffic : (d.requestsPerMin ? Math.min(100, Math.round(d.requestsPerMin / 30)) : 0);
      const exploitScore = vs.exploit !== undefined ? vs.exploit : (d.malformedRequests ? Math.min(100, d.malformedRequests * 25) : 0);
      const resourceScore = vs.resource !== undefined ? vs.resource : (d.cpuPercent || d.ramPercent ? Math.max(d.cpuPercent || 0, d.ramPercent || 0) : 0);
      const compScore = d.threatScore ?? Math.max(authScore, trafficScore, exploitScore, resourceScore);

      const getY = (val) => height - padding - ((Math.min(100, Math.max(0, val)) - minVal) / (maxVal - minVal)) * (height - 2 * padding);

      return {
        index: i,
        x,
        time: d.timestamp,
        auth: { y: getY(authScore), score: authScore },
        traffic: { y: getY(trafficScore), score: trafficScore },
        exploit: { y: getY(exploitScore), score: exploitScore },
        resource: { y: getY(resourceScore), score: resourceScore },
        composite: { y: getY(compScore), score: compScore },
        raw: d,
      };
    });

    const buildPath = (key) =>
      samples.map((s, i) => `${i === 0 ? 'M' : 'L'} ${s.x.toFixed(1)} ${s[key].y.toFixed(1)}`).join(' ');

    const buildArea = (pathStr) => {
      if (!pathStr || samples.length === 0) return '';
      const firstX = samples[0].x.toFixed(1);
      const lastX = samples[samples.length - 1].x.toFixed(1);
      return `${pathStr} L ${lastX} 155 L ${firstX} 155 Z`;
    };

    const authPath = buildPath('auth');
    const trafficPath = buildPath('traffic');
    const exploitPath = buildPath('exploit');
    const resourcePath = buildPath('resource');
    const compositePath = buildPath('composite');

    return {
      samples,
      auth: {
        path: authPath,
        area: buildArea(authPath),
        points: samples.map((s) => ({ x: s.x, y: s.auth.y, score: s.auth.score, time: s.time })),
        color: '#f59e0b',
        name: '1. Xác Thực & Danh Tính',
        id: 'auth',
      },
      traffic: {
        path: trafficPath,
        area: buildArea(trafficPath),
        points: samples.map((s) => ({ x: s.x, y: s.traffic.y, score: s.traffic.score, time: s.time })),
        color: '#3b82f6',
        name: '2. Lưu Lượng & DoS',
        id: 'traffic',
      },
      exploit: {
        path: exploitPath,
        area: buildArea(exploitPath),
        points: samples.map((s) => ({ x: s.x, y: s.exploit.y, score: s.exploit.score, time: s.time })),
        color: '#f43f5e',
        name: '3. Khai Thác Lỗ Hổng',
        id: 'exploit',
      },
      resource: {
        path: resourcePath,
        area: buildArea(resourcePath),
        points: samples.map((s) => ({ x: s.x, y: s.resource.y, score: s.resource.score, time: s.time })),
        color: '#0d9488',
        name: '4. Tài Nguyên Máy Chủ',
        id: 'resource',
      },
      composite: {
        path: compositePath,
        area: buildArea(compositePath),
        points: samples.map((s) => ({ x: s.x, y: s.composite.y, score: s.composite.score, time: s.time })),
        color: '#8b5cf6',
        name: 'Điểm Tổng Hợp (Composite)',
        id: 'composite',
      },
    };
  }, [historyData]);

  // Fallback tương thích ngược
  const chartSvgPath = chartSvgPaths.composite;

  return (
    <div className="max-w-[1440px] mx-auto w-full p-4 md:p-6 space-y-6 bg-surface-bright min-h-full">
      {/* Tiêu đề trang & Thanh công cụ */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-outline-variant pb-4">
        <div>
          <h1 className="font-display-md text-display-md font-bold text-on-surface m-0 tracking-tight flex items-center gap-2.5">
            <span className="material-symbols-outlined text-primary text-[32px]">security</span>
            AIOps Sentinel — Giám Sát Máy Học & Phòng Vệ Tự Động
          </h1>
          <p className="font-body-md text-on-surface-variant mt-1">
            Học baseline trực tuyến, tự động phát hiện xâm nhập & chặn đứng nguồn request bất thường từ Client-app
          </p>
        </div>

        <div className="flex items-center gap-2.5 flex-wrap">
          <button
            onClick={fetchAIOpsData}
            disabled={loading}
            className="px-3.5 py-2 bg-white hover:bg-gray-50 border border-outline-variant text-on-surface text-xs font-semibold rounded-xl shadow-2xs transition-all cursor-pointer flex items-center gap-1.5"
          >
            <span className={`material-symbols-outlined text-[16px] ${loading ? 'animate-spin' : ''}`}>refresh</span>
            <span>Làm Mới</span>
          </button>

          <button
            onClick={() => setShowCalibrateModal(true)}
            disabled={calibrating}
            className="px-3.5 py-2 bg-white hover:bg-blue-50 border border-blue-200 text-blue-700 text-xs font-semibold rounded-xl shadow-2xs transition-all cursor-pointer flex items-center gap-1.5"
            title="Nhấn để tìm hiểu công dụng và thực hiện tái hiệu chuẩn baseline máy học"
          >
            <span className="material-symbols-outlined text-[16px]">tune</span>
            <span>{calibrating ? 'Đang hiệu chuẩn...' : 'Tái Hiệu Chuẩn Baseline'}</span>
            <span className="material-symbols-outlined text-[14px] text-blue-400 hover:text-blue-600">help</span>
          </button>

          {isEmergencyResourceRisk && (
            <button
              onClick={() => setShowMitigationModal(true)}
              className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white text-xs font-bold rounded-xl shadow-xs transition-all cursor-pointer flex items-center gap-1.5 animate-pulse"
              title="Chỉ hiển thị khi Vector 4 (Tài nguyên) vượt ngưỡng nguy cơ sập dây chuyền"
            >
              <span className="material-symbols-outlined text-[18px]">emergency</span>
              <span>1-Click Bảo Trì Khẩn Cấp</span>
            </button>
          )}
        </div>
      </div>

      {/* Thông báo phản hồi */}
      {feedback && (
        <div
          className={`rounded-xl px-4 py-3 text-xs flex items-center justify-between gap-2 border font-medium ${
            feedback.ok
              ? 'bg-emerald-50 text-emerald-800 border-emerald-300'
              : 'bg-red-50 text-red-800 border-red-300'
          }`}
        >
          <div className="flex items-center gap-2">
            <span className="material-symbols-outlined text-[18px]">
              {feedback.ok ? 'verified' : 'shield'}
            </span>
            <span>{feedback.msg}</span>
          </div>
          <button onClick={() => setFeedback(null)} className="text-gray-400 hover:text-gray-600 cursor-pointer">
            <span className="material-symbols-outlined text-[16px]">close</span>
          </button>
        </div>
      )}

      {/* ======================================================== */}
      {/* KHỐI 0: BỘ ĐIỀU KHIỂN QUY MÔ NGƯỜI DÙNG & MÔ HÌNH CHỊU TẢI DUNG LƯỢNG */}
      {/* ======================================================== */}
      <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-3 border-b border-outline-variant pb-3">
          <div>
            <h2 className="text-sm font-bold text-on-surface m-0 flex items-center gap-2">
              <span className="material-symbols-outlined text-primary text-[20px]">group</span>
              Quy Mô Người Dùng Mục Tiêu & Mô Hình Chịu Tải (Target Concurrency Scaler)
            </h2>
            <p className="text-[11px] text-slate-500 mt-0.5">
              Admin cập nhật số lượng người dùng đồng thời kỳ vọng (1,000 - 2,000+). Hệ thống tự động hiệu chỉnh trần RPM và ngưỡng tường lửa theo thời gian thực.
            </p>
          </div>

          <div className="flex items-center gap-2 flex-wrap">
            <span className="text-[11px] font-medium text-slate-500">Mẫu chọn nhanh:</span>
            {[
              { label: '500 Người', val: 500 },
              { label: '1,000 Người (Chuẩn)', val: 1000 },
              { label: '2,000 Người (Cao điểm)', val: 2000 },
              { label: '5,000 Người (Lớn)', val: 5000 },
            ].map((preset) => (
              <button
                key={preset.val}
                type="button"
                onClick={() => {
                  setCustomConcurrency(String(preset.val));
                  handleApplyScale(preset.val);
                }}
                disabled={savingScale}
                className={`px-3 py-1 rounded-lg text-xs font-semibold transition-all cursor-pointer border ${
                  targetConcurrency === preset.val
                    ? 'bg-primary text-white border-primary shadow-xs'
                    : 'bg-surface-container-lowest text-on-surface border-outline-variant hover:bg-slate-100'
                }`}
              >
                {preset.label}
              </button>
            ))}
          </div>
        </div>

        {/* Form tùy chỉnh & 3 thẻ thông số suy diễn */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 pt-1">
          {/* Form nhập quy mô tùy biến */}
          <div className="p-4 rounded-xl bg-slate-50 border border-slate-200/80 flex flex-col justify-between space-y-3">
            <div>
              <label className="block text-[11px] font-bold text-slate-700 uppercase tracking-wider mb-1">
                Số người dùng đồng thời (N)
              </label>
              <div className="flex items-center gap-2">
                <input
                  type="number"
                  min="100"
                  max="50000"
                  step="100"
                  value={customConcurrency}
                  onChange={(e) => setCustomConcurrency(e.target.value)}
                  className="w-full bg-white border border-outline-variant rounded-lg px-3 py-1.5 text-xs font-bold text-on-surface focus:outline-none focus:ring-2 focus:ring-primary"
                  placeholder="VD: 1000, 2000"
                />
                <button
                  type="button"
                  onClick={() => handleApplyScale(customConcurrency)}
                  disabled={savingScale}
                  className="px-3 py-1.5 bg-primary hover:bg-primary/90 text-white rounded-lg text-xs font-bold transition-all cursor-pointer shadow-xs whitespace-nowrap flex items-center gap-1"
                >
                  <span className={`material-symbols-outlined text-[15px] ${savingScale ? 'animate-spin' : ''}`}>
                    {savingScale ? 'sync' : 'check'}
                  </span>
                  <span>Áp Dụng</span>
                </button>
              </div>
            </div>
            <div className="text-[10px] text-slate-500">
              Quy mô đang áp dụng: <strong className="text-primary font-mono">{targetConcurrency.toLocaleString('vi-VN')}</strong> CCU
            </div>
          </div>

          {/* Thẻ 1: Baseline RPM kỳ vọng */}
          <div className="p-3.5 rounded-xl border bg-surface-container-lowest border-outline-variant/60 flex flex-col justify-between">
            <div className="flex items-center justify-between text-slate-500">
              <span className="text-[11px] font-medium">Baseline RPM dự kiến</span>
              <span className="material-symbols-outlined text-[16px] text-blue-500">trending_up</span>
            </div>
            <div className="my-1.5">
              <div className="text-xl font-bold text-on-surface font-mono">
                {baselineRpm.toLocaleString('vi-VN')}
                <span className="text-[11px] font-normal text-slate-500 ml-1">req/phút</span>
              </div>
            </div>
            <div className="text-[10px] text-slate-500">
              Công thức: <code className="font-mono text-slate-700 font-semibold">{targetConcurrency.toLocaleString()} × 10 RPM</code>
            </div>
          </div>

          {/* Thẻ 2: Safe Peak Ceiling (3x) */}
          <div className="p-3.5 rounded-xl border bg-surface-container-lowest border-outline-variant/60 flex flex-col justify-between">
            <div className="flex items-center justify-between text-slate-500">
              <span className="text-[11px] font-medium">Trần Đỉnh An Toàn (Safe Peak)</span>
              <span className="material-symbols-outlined text-[16px] text-emerald-500">verified_user</span>
            </div>
            <div className="my-1.5">
              <div className="text-xl font-bold text-on-surface font-mono">
                {safePeakRpm.toLocaleString('vi-VN')}
                <span className="text-[11px] font-normal text-slate-500 ml-1">req/phút</span>
              </div>
            </div>
            <div className="text-[10px] text-slate-500">
              Trần an toàn <code className="font-mono text-slate-700 font-semibold">3× Baseline</code> (Chưa kích hoạt DoS)
            </div>
          </div>

          {/* Thẻ 3: Ngưỡng cách ly IP đơn lẻ */}
          <div className="p-3.5 rounded-xl border bg-surface-container-lowest border-outline-variant/60 flex flex-col justify-between">
            <div className="flex items-center justify-between text-slate-500">
              <span className="text-[11px] font-medium">Ngưỡng Chặn Tường Lửa IP</span>
              <span className="material-symbols-outlined text-[16px] text-red-500">security</span>
            </div>
            <div className="my-1.5">
              <div className="text-xl font-bold text-on-surface font-mono">
                {quarantineThreshold}
                <span className="text-[11px] font-normal text-slate-500 ml-1">req/10s</span>
              </div>
            </div>
            <div className="text-[10px] text-slate-500">
              <code className="font-mono text-slate-700 font-semibold">20 + 50×log10(N)</code> (Tự động cách ly IP càn quét)
            </div>
          </div>
        </div>
      </div>

      {/* ======================================================== */}
      {/* KHỐI 1: THREAT SCORE GAUGE & METRIC HIGHLIGHTS */}
      {/* ======================================================== */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* CỘT 1: ĐỒNG HỒ ĐO RỦI RO THỜI GIAN THỰC (THREAT SCORE GAUGE) */}
        <div className={`bg-white rounded-2xl border p-5 shadow-sm space-y-4 flex flex-col justify-between transition-all ${theme.border}`}>
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <h2 className="text-xs font-bold uppercase tracking-wider text-on-surface m-0 flex items-center gap-1.5">
                <span className="material-symbols-outlined text-[18px] text-primary">speed</span>
                Hệ Số Đe Dọa (Threat Score)
              </h2>
              <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold border ${theme.badgeBg}`}>
                {theme.label}
              </span>
            </div>

            {/* SVG Gauge Graphic */}
            <div className="flex flex-col items-center justify-center py-2 relative">
              <svg className="w-48 h-28 overflow-visible" viewBox="0 0 200 110">
                {/* Background Semicircle Arc */}
                <path
                  d="M 20 100 A 80 80 0 0 1 180 100"
                  fill="none"
                  stroke="#e2e8f0"
                  strokeWidth="18"
                  strokeLinecap="round"
                />
                {/* Active Colored Arc */}
                <path
                  d="M 20 100 A 80 80 0 0 1 180 100"
                  fill="none"
                  stroke={theme.color}
                  strokeWidth="18"
                  strokeLinecap="round"
                  strokeDasharray="251.2"
                  strokeDashoffset={251.2 - (251.2 * Math.min(100, Math.max(0, threatScore))) / 100}
                  className="transition-all duration-700 ease-out"
                />
                {/* Center Score Text */}
                <text
                  x="100"
                  y="92"
                  textAnchor="middle"
                  className="font-bold text-3xl fill-current"
                  style={{ fill: theme.color }}
                >
                  {threatScore}
                </text>
                <text x="100" y="108" textAnchor="middle" className="text-[11px] font-medium fill-slate-500">
                  / 100
                </text>
              </svg>

              <div className="flex items-center justify-between w-44 text-[10px] font-semibold text-slate-500 mt-1">
                <span>0 (An toàn)</span>
                <span>60 (Tăng cao)</span>
                <span>80 (Cảnh báo)</span>
                <span>90+ (Nguy cấp)</span>
              </div>
            </div>
          </div>

          {/* Khuyến nghị hành động */}
          <div className="pt-3 border-t border-outline-variant/60 text-xs space-y-1">
            <div className="flex items-center justify-between text-[11px] text-slate-500">
              <span>Công thức tổng hợp:</span>
              <code className="font-mono font-semibold text-slate-700">max(Vectơ) + Bonus kết hợp</code>
            </div>
            <div>
              <span className="font-semibold text-on-surface">Phòng vệ Sentinel: </span>
              <span className="font-bold text-[11px]" style={{ color: theme.color }}>
                {isEmergencyResourceRisk
                  ? '🚨 [TÀI NGUYÊN] NGUY CƠ SẬP DÂY CHUYỀN (Lag > 250ms & 5xx > 15%) — ĐỀ XUẤT BẢO TRÌ KHẨN CẤP'
                  : vectorScores.exploit >= 70
                  ? '⚔️ [KHAI THÁC] PHÁT HIỆN INJECTION/TRAVERSAL — ĐÃ NGẮT HTTP 403 & PHONG TỎA IP 30 PHÚT'
                  : vectorScores.auth >= 70
                  ? '🛡️ [XÁC THỰC] PHÁT HIỆN BRUTE-FORCE/TOKEN HIJACK — ĐÃ CÔ LẬP NGUỒN IP TẠI GATEWAY'
                  : vectorScores.traffic >= 70
                  ? '⚡ [LƯU LƯỢNG] LƯU LƯỢNG VƯỢT TRẦN CCU — KÍCH HOẠT ADAPTIVE RATE-LIMITING'
                  : recommendedAction === 'INVESTIGATE'
                  ? '⚠️ PHÁT HIỆN BẤT THƯỜNG — NGUỒN ĐÃ BỊ TỰ ĐỘNG CÔ LẬP, THEO DÕI LOGS'
                  : '✅ HỆ THỐNG AN TOÀN — CƠ CHẾ PHÒNG VỆ 4 VECTOR ĐANG HOẠT ĐỘNG ỔN ĐỊNH'}
              </span>
            </div>
          </div>
        </div>

        {/* CỘT 2: CHỈ SỐ TẤN CÔNG & XÂM NHẬP (SECURITY ATTACK SIGNALS) */}
        <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4">
          <div className="flex items-center justify-between border-b border-outline-variant pb-2.5">
            <h2 className="text-xs font-bold uppercase tracking-wider text-on-surface m-0 flex items-center gap-1.5">
              <span className="material-symbols-outlined text-[18px] text-red-500">shield_with_heart</span>
              Tín Hiệu Xâm Nhập & Tấn Công
            </h2>
            <span className="text-[10px] text-slate-500">Cửa sổ 10 giây</span>
          </div>

          <div className="grid grid-cols-2 gap-3 text-xs">
            {/* Failed Logins */}
            <div className={`p-3 rounded-xl border ${sample.failedLogins >= 5 ? 'bg-red-50 border-red-200' : 'bg-surface-container-lowest border-outline-variant/60'}`}>
              <div className="text-[11px] text-slate-500 font-medium">Đăng nhập sai</div>
              <div className="text-lg font-bold text-on-surface mt-1 flex items-baseline justify-between">
                <span>{sample.failedLogins ?? 0}</span>
                <span className="text-[10px] text-slate-400">lần</span>
              </div>
              <div className="text-[10px] text-slate-500 mt-1">Brute-Force Auth (Auto-ban $\ge 5$)</div>
            </div>

            {/* Token Reuse Attacks */}
            <div className={`p-3 rounded-xl border ${sample.tokenReuseAttacks >= 1 ? 'bg-red-50 border-red-200' : 'bg-surface-container-lowest border-outline-variant/60'}`}>
              <div className="text-[11px] text-slate-500 font-medium">Tái dùng Token thu hồi</div>
              <div className="text-lg font-bold text-on-surface mt-1 flex items-baseline justify-between">
                <span>{sample.tokenReuseAttacks ?? 0}</span>
                <span className="text-[10px] text-slate-400">lần</span>
              </div>
              <div className="text-[10px] text-slate-500 mt-1">Token Hijacking (Auto-ban)</div>
            </div>

            {/* Malformed Requests */}
            <div className={`p-3 rounded-xl border ${sample.malformedRequests >= 3 ? 'bg-amber-50 border-amber-200' : 'bg-surface-container-lowest border-outline-variant/60'}`}>
              <div className="text-[11px] text-slate-500 font-medium">Request độc hại (SQLi)</div>
              <div className="text-lg font-bold text-on-surface mt-1 flex items-baseline justify-between">
                <span>{sample.malformedRequests ?? 0}</span>
                <span className="text-[10px] text-slate-400">mẫu</span>
              </div>
              <div className="text-[10px] text-slate-500 mt-1">Injection (Auto-ban $\ge 3$)</div>
            </div>

            {/* Distinct IP Count */}
            <div className="p-3 rounded-xl border bg-surface-container-lowest border-outline-variant/60">
              <div className="text-[11px] text-slate-500 font-medium">Độ phân tán IP</div>
              <div className="text-lg font-bold text-on-surface mt-1 flex items-baseline justify-between">
                <span>{sample.distinctIpsCount ?? 0}</span>
                <span className="text-[10px] text-slate-400">IPs</span>
              </div>
              <div className="text-[10px] text-slate-500 mt-1">IP Entropy (Zero PII)</div>
            </div>
          </div>
        </div>

        {/* CỘT 3: CHỈ SỐ CHỊU TẢI & PHẦN CỨNG (SYSTEM RESILIENCE SIGNALS) */}
        <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4">
          <div className="flex items-center justify-between border-b border-outline-variant pb-2.5">
            <h2 className="text-xs font-bold uppercase tracking-wider text-on-surface m-0 flex items-center gap-1.5">
              <span className="material-symbols-outlined text-[18px] text-primary">memory</span>
              Sức Chịu Tải & Phần Cứng
            </h2>
            <span className="text-[10px] text-slate-500">Node.js Engine</span>
          </div>

          <div className="grid grid-cols-2 gap-3 text-xs">
            {/* Event Loop Lag */}
            <div className={`p-3 rounded-xl border ${sample.eventLoopLagMs >= 100 ? 'bg-red-50 border-red-200' : 'bg-surface-container-lowest border-outline-variant/60'}`}>
              <div className="text-[11px] text-slate-500 font-medium">Event Loop Lag</div>
              <div className="text-lg font-bold text-on-surface mt-1 flex items-baseline justify-between">
                <span>{sample.eventLoopLagMs ?? 0}</span>
                <span className="text-[10px] text-slate-400">ms</span>
              </div>
              <div className="text-[10px] text-slate-500 mt-1">Trễ vòng lặp sự kiện</div>
            </div>

            {/* CPU Usage */}
            <div className={`p-3 rounded-xl border ${sample.cpuPercent >= 85 ? 'bg-amber-50 border-amber-200' : 'bg-surface-container-lowest border-outline-variant/60'}`}>
              <div className="text-[11px] text-slate-500 font-medium">CPU Hệ Thống</div>
              <div className="text-lg font-bold text-on-surface mt-1 flex items-baseline justify-between">
                <span>{sample.cpuPercent ?? 0}%</span>
              </div>
              <div className="text-[10px] text-slate-500 mt-1">Tải đa nhân xử lý</div>
            </div>

            {/* RAM Usage */}
            <div className={`p-3 rounded-xl border ${sample.ramPercent >= 90 ? 'bg-red-50 border-red-200' : 'bg-surface-container-lowest border-outline-variant/60'}`}>
              <div className="text-[11px] text-slate-500 font-medium">Bộ nhớ RAM</div>
              <div className="text-lg font-bold text-on-surface mt-1 flex items-baseline justify-between">
                <span>{sample.ramPercent ?? 0}%</span>
              </div>
              <div className="text-[10px] text-slate-500 mt-1">Nguy cơ Memory Leak</div>
            </div>

            {/* Lưu lượng Request */}
            <div className="p-3 rounded-xl border bg-surface-container-lowest border-outline-variant/60">
              <div className="text-[11px] text-slate-500 font-medium">Lưu lượng ước tính</div>
              <div className="text-lg font-bold text-on-surface mt-1 flex items-baseline justify-between">
                <span>{sample.requestsPerMin ?? 0}</span>
                <span className="text-[10px] text-slate-400">req/p</span>
              </div>
              <div className="text-[10px] text-slate-500 mt-1">4xx: {Math.round((sample.errorRate4xx || 0) * 100)}% | 5xx: {Math.round((sample.errorRate5xx || 0) * 100)}%</div>
            </div>
          </div>
        </div>
      </div>

      {/* ======================================================== */}
      {/* KHỐI 1.5: 4 VECTƠ RỦI RO ĐỘC LẬP & CÁ NHÂN HÓA PHÒNG VỆ */}
      {/* ======================================================== */}
      <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-outline-variant pb-3">
          <div>
            <h2 className="text-sm font-bold text-on-surface m-0 flex items-center gap-2">
              <span className="material-symbols-outlined text-primary text-[20px]">hub</span>
              4 Vectơ Rủi Ro Độc Lập & Cá Nhân Hóa Phòng Vệ (Multi-Vector Risk Architecture)
            </h2>
            <p className="text-[11px] text-slate-500 mt-0.5">
              Tách biệt hoàn toàn cơ chế tính điểm và biện pháp phòng vệ theo từng đặc trưng riêng: Danh tính, Lưu lượng, Khai thác lỗ hổng và Tài nguyên máy chủ
            </p>
          </div>
          <span className="text-[10px] text-slate-600 bg-slate-100 px-3 py-1 rounded-full font-medium self-start sm:self-auto">
            4 Sub-scores độc lập [0 - 100]
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {/* VECTƠ 1: XÁC THỰC & DANH TÍNH */}
          {(() => {
            const vScore = vectorScores.auth || 0;
            const vTheme = getVectorTheme(vScore);
            const isQuarantining = quarantineList.length > 0 || vScore >= 70;
            return (
              <div className="p-4 rounded-xl border border-outline-variant/70 bg-surface-container-lowest flex flex-col justify-between space-y-3">
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-amber-600">badge</span>
                      1. Xác Thực & Danh Tính
                    </span>
                    <span className={`px-2 py-0.5 rounded text-[10px] font-bold border ${vTheme.badge}`}>
                      {vTheme.label}
                    </span>
                  </div>
                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">/ 100 điểm</span>
                  </div>
                  {/* Progress bar */}
                  <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                    <div
                      className={`h-full ${vTheme.bg} transition-all duration-500`}
                      style={{ width: `${Math.min(100, Math.max(0, vScore))}%` }}
                    />
                  </div>
                </div>

                <div className="space-y-1.5 pt-2 border-t border-slate-100 text-[11px]">
                  <div className="flex justify-between text-slate-600">
                    <span>Đăng nhập lỗi:</span>
                    <strong className="font-mono">{sample.failedLogins ?? 0} lần</strong>
                  </div>
                  <div className="flex justify-between text-slate-600">
                    <span>Tái dùng token hủy:</span>
                    <strong className="font-mono">{sample.tokenReuseAttacks ?? 0} lần</strong>
                  </div>
                  {/* Badge hành động phòng vệ động */}
                  <div className="pt-1">
                    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold border ${
                      isQuarantining ? 'bg-red-50 text-red-700 border-red-200' : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                    }`}>
                      <span className="material-symbols-outlined text-[12px]">
                        {isQuarantining ? 'lock' : 'check_circle'}
                      </span>
                      <span>
                        {quarantineList.length > 0
                          ? `Đang cô lập ${quarantineList.length} IP vi phạm`
                          : vScore >= 70
                          ? 'Đã kích hoạt cô lập IP vi phạm'
                          : 'Sẵn sàng cô lập IP vi phạm'}
                      </span>
                    </span>
                  </div>
                  <div className="mt-2 p-2 rounded-lg bg-amber-50/70 border border-amber-200/60 text-amber-950 text-[10px] leading-relaxed">
                    <strong>Phòng vệ:</strong> Chỉ cô lập IP Brute-Force (`/auth/login`). Tuyệt đối không ảnh hưởng khách hàng khác.
                  </div>
                </div>
              </div>
            );
          })()}

          {/* VECTƠ 2: LƯU LƯỢNG & TẤN CÔNG DOS/DDOS */}
          {(() => {
            const vScore = vectorScores.traffic || 0;
            const vTheme = getVectorTheme(vScore);
            const isThrottling = vScore >= 70;
            return (
              <div className="p-4 rounded-xl border border-outline-variant/70 bg-surface-container-lowest flex flex-col justify-between space-y-3">
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-blue-600">waves</span>
                      2. Lưu Lượng & DoS
                    </span>
                    <span className={`px-2 py-0.5 rounded text-[10px] font-bold border ${vTheme.badge}`}>
                      {vTheme.label}
                    </span>
                  </div>
                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">/ 100 điểm</span>
                  </div>
                  {/* Progress bar */}
                  <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                    <div
                      className={`h-full ${vTheme.bg} transition-all duration-500`}
                      style={{ width: `${Math.min(100, Math.max(0, vScore))}%` }}
                    />
                  </div>
                </div>

                <div className="space-y-1.5 pt-2 border-t border-slate-100 text-[11px]">
                  <div className="flex justify-between text-slate-600">
                    <span>Lưu lượng hiện tại:</span>
                    <strong className="font-mono">{sample.requestsPerMin ?? 0} RPM</strong>
                  </div>
                  <div className="flex justify-between text-slate-600">
                    <span>Độ phân tán IP:</span>
                    <strong className="font-mono">{sample.distinctIpsCount ?? 0} IPs</strong>
                  </div>
                  {/* Badge hành động phòng vệ động */}
                  <div className="pt-1">
                    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold border ${
                      isThrottling ? 'bg-blue-100 text-blue-800 border-blue-300' : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                    }`}>
                      <span className="material-symbols-outlined text-[12px]">
                        {isThrottling ? 'speed' : 'check_circle'}
                      </span>
                      <span>
                        {isThrottling
                          ? 'Đang điều tiết Adaptive Rate-Limit'
                          : `Lưu lượng an toàn theo chuẩn ${targetConcurrency} CCU`}
                      </span>
                    </span>
                  </div>
                  <div className="mt-2 p-2 rounded-lg bg-blue-50/70 border border-blue-200/60 text-blue-950 text-[10px] leading-relaxed">
                    <strong>Phòng vệ:</strong> Phân biệt đỉnh người dùng thật qua Entropy. Kích hoạt Rate-Limit theo trần quy mô {targetConcurrency} CCU.
                  </div>
                </div>
              </div>
            );
          })()}

          {/* VECTƠ 3: KHAI THÁC LỖ HỔNG & THĂM DÒ (EXPLOIT) */}
          {(() => {
            const vScore = vectorScores.exploit || 0;
            const vTheme = getVectorTheme(vScore);
            const isExploitActive = vScore >= 70;
            return (
              <div className="p-4 rounded-xl border border-outline-variant/70 bg-surface-container-lowest flex flex-col justify-between space-y-3">
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-rose-600">bug_report</span>
                      3. Khai Thác Lỗ Hổng
                    </span>
                    <span className={`px-2 py-0.5 rounded text-[10px] font-bold border ${vTheme.badge}`}>
                      {vTheme.label}
                    </span>
                  </div>
                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">/ 100 điểm</span>
                  </div>
                  {/* Progress bar */}
                  <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                    <div
                      className={`h-full ${vTheme.bg} transition-all duration-500`}
                      style={{ width: `${Math.min(100, Math.max(0, vScore))}%` }}
                    />
                  </div>
                </div>

                <div className="space-y-1.5 pt-2 border-t border-slate-100 text-[11px]">
                  <div className="flex justify-between text-slate-600">
                    <span>Mẫu tiêm nhiễm (SQLi):</span>
                    <strong className="font-mono">{sample.malformedRequests ?? 0} mẫu</strong>
                  </div>
                  <div className="flex justify-between text-slate-600">
                    <span>Đường dẫn cấm/Traversal:</span>
                    <strong className="font-mono">Tự động phát hiện</strong>
                  </div>
                  {/* Badge hành động phòng vệ động */}
                  <div className="pt-1">
                    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold border ${
                      isExploitActive ? 'bg-rose-100 text-rose-800 border-rose-300' : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                    }`}>
                      <span className="material-symbols-outlined text-[12px]">
                        {isExploitActive ? 'security' : 'check_circle'}
                      </span>
                      <span>
                        {isExploitActive
                          ? 'Đã ngắt HTTP 403 & Blacklist 30p'
                          : 'Sẵn sàng chặn SQLi/Payload'}
                      </span>
                    </span>
                  </div>
                  <div className="mt-2 p-2 rounded-lg bg-rose-50/70 border border-rose-200/60 text-rose-950 text-[10px] leading-relaxed">
                    <strong>Phòng vệ:</strong> Cắt kết nối HTTP 403 tức thì với IP mang injection payload, đưa vào danh sách đen 30 phút.
                  </div>
                </div>
              </div>
            );
          })()}

          {/* VECTƠ 4: SỨC KHỎE TÀI NGUYÊN HẠ TẦNG */}
          {(() => {
            const vScore = vectorScores.resource || 0;
            const vTheme = getVectorTheme(vScore);
            return (
              <div className="p-4 rounded-xl border border-outline-variant/70 bg-surface-container-lowest flex flex-col justify-between space-y-3">
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-teal-600">memory</span>
                      4. Sức Khỏe Tài Nguyên
                    </span>
                    <span className={`px-2 py-0.5 rounded text-[10px] font-bold border ${vTheme.badge}`}>
                      {vTheme.label}
                    </span>
                  </div>
                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">/ 100 điểm</span>
                  </div>
                  {/* Progress bar */}
                  <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                    <div
                      className={`h-full ${vTheme.bg} transition-all duration-500`}
                      style={{ width: `${Math.min(100, Math.max(0, vScore))}%` }}
                    />
                  </div>
                </div>

                <div className="space-y-1.5 pt-2 border-t border-slate-100 text-[11px]">
                  <div className="flex justify-between text-slate-600">
                    <span>Event Loop Lag:</span>
                    <strong className="font-mono">{sample.eventLoopLagMs ?? 0} ms</strong>
                  </div>
                  <div className="flex justify-between text-slate-600">
                    <span>CPU / RAM:</span>
                    <strong className="font-mono">{sample.cpuPercent ?? 0}% / {sample.ramPercent ?? 0}%</strong>
                  </div>
                  {/* Badge hành động phòng vệ động */}
                  <div className="pt-1">
                    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold border ${
                      isEmergencyResourceRisk
                        ? 'bg-red-100 text-red-800 border-red-300'
                        : vScore >= 60
                        ? 'bg-amber-100 text-amber-800 border-amber-300'
                        : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                    }`}>
                      <span className="material-symbols-outlined text-[12px]">
                        {isEmergencyResourceRisk ? 'crisis_alert' : vScore >= 60 ? 'tune' : 'check_circle'}
                      </span>
                      <span>
                        {isEmergencyResourceRisk
                          ? '🚨 Đề xuất Bảo Trì Khẩn Cấp'
                          : vScore >= 60
                          ? 'Đang kích hoạt Load Shedding'
                          : 'Tài nguyên phần cứng ổn định'}
                      </span>
                    </span>
                  </div>
                  <div className="mt-2 p-2 rounded-lg bg-teal-50/70 border border-teal-200/60 text-teal-950 text-[10px] leading-relaxed">
                    <strong>Phòng vệ:</strong> Load Shedding & cảnh báo máy chủ. Chỉ kích hoạt Bảo trì nếu có sập dây chuyền (Lag &gt; 250ms &amp; 5xx &gt; 15%).
                  </div>
                </div>
              </div>
            );
          })()}
        </div>
      </div>

      {/* ======================================================== */}
      {/* KHỐI 2: DANH SÁCH NGUỒN REQUEST BỊ CÔ LẬP & TỰ ĐỘNG CHẶN */}
      {/* ======================================================== */}
      <div className="bg-white rounded-2xl border border-red-200 p-5 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-red-100 pb-3">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-red-100 text-red-700 flex items-center justify-center flex-shrink-0">
              <span className="material-symbols-outlined text-[20px]">block</span>
            </div>
            <div>
              <h2 className="text-sm font-bold text-red-950 m-0">
                Nguồn Request Đang Bị Cô Lập & Tự Động Chặn (Active Quarantine Blacklist)
              </h2>
              <p className="text-[11px] text-slate-500 mt-0.5">
                Các nguồn IP có hành vi tấn công DoS/DDoS, Brute-Force, hoặc SQLi bị cắt kết nối tức thì (HTTP 403)
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <span className="text-xs font-bold px-3 py-1 rounded-full bg-red-100 text-red-800 border border-red-200">
              {quarantineList.length} nguồn bị phong tỏa
            </span>
          </div>
        </div>

        {quarantineList.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b border-red-100 bg-red-50/40 text-slate-700 font-bold uppercase text-[10px] tracking-wider">
                  <th className="py-2.5 px-3">Địa chỉ IP (Masked)</th>
                  <th className="py-2.5 px-3">Nguyên nhân phong tỏa</th>
                  <th className="py-2.5 px-3">Thời điểm chặn</th>
                  <th className="py-2.5 px-3">Thời gian còn lại</th>
                  <th className="py-2.5 px-3">Lần vi phạm (Hits)</th>
                  <th className="py-2.5 px-3 text-right">Thao tác</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-red-50">
                {quarantineList.map((item, idx) => (
                  <tr key={item.hash || idx} className="hover:bg-red-50/30 transition-colors">
                    <td className="py-3 px-3 font-mono font-bold text-red-700 whitespace-nowrap flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[16px] text-red-500">lock</span>
                      <span>{item.maskedIp}</span>
                    </td>
                    <td className="py-3 px-3 font-semibold text-slate-800">
                      {item.reason}
                    </td>
                    <td className="py-3 px-3 text-slate-500 whitespace-nowrap">
                      {item.bannedAt ? formatDateTime(item.bannedAt) : 'Vừa xong'}
                    </td>
                    <td className="py-3 px-3 whitespace-nowrap">
                      <span className="px-2 py-0.5 rounded text-[11px] font-bold bg-amber-100 text-amber-900 border border-amber-200">
                        {item.remainingMinutes !== undefined ? `${item.remainingMinutes} phút` : 'Đang phong tỏa'}
                      </span>
                    </td>
                    <td className="py-3 px-3 font-bold text-slate-700 whitespace-nowrap">
                      {item.hits ?? 1}
                    </td>
                    <td className="py-3 px-3 text-right whitespace-nowrap">
                      <button
                        onClick={() => handleUnblock(item.hash)}
                        disabled={unblockingHash === item.hash}
                        className="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg text-xs font-bold transition-all cursor-pointer shadow-xs inline-flex items-center gap-1"
                        title="Bấm để mở khóa và cho phép IP tiếp tục truy cập"
                      >
                        <span className="material-symbols-outlined text-[15px]">lock_open</span>
                        <span>{unblockingHash === item.hash ? 'Đang mở...' : 'Gỡ Chặn'}</span>
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="p-6 text-center rounded-xl bg-slate-50/80 border border-slate-200/60 space-y-2">
            <span className="material-symbols-outlined text-[36px] text-emerald-600">gpp_good</span>
            <p className="font-bold text-xs text-slate-800">Không có nguồn IP nào đang bị cô lập</p>
            <p className="text-[11px] text-slate-500 max-w-md mx-auto">
              AIOps Sentinel liên tục theo dõi và sẵn sàng kích hoạt tường lửa tức thì nếu phát hiện nguồn bất thường.
            </p>
          </div>
        )}
      </div>

      {/* ======================================================== */}
      {/* KHỐI 3: BIỂU ĐỒ SVG XU HƯỚNG 4 VECTƠ RỦI RO ĐỘC LẬP THỜI GIAN THỰC */}
      {/* ======================================================== */}
      <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4">
        {/* Header & Bộ lọc Tabs cho 4 Vectơ */}
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-3 border-b border-outline-variant pb-3">
          <div>
            <h2 className="text-sm font-bold text-on-surface m-0 flex items-center gap-2">
              <span className="material-symbols-outlined text-[18px] text-primary">show_chart</span>
              Biểu Đồ Xu Hướng 4 Vectơ Rủi Ro Độc Lập Thời Gian Thực (60 Mẫu Gần Nhất — 10 Phút)
            </h2>
            <p className="text-[11px] text-slate-500 mt-0.5">
              Tách biệt đường cong riêng cho từng vectơ: Xác thực, Lưu lượng, Khai thác và Tài nguyên. Loại bỏ hoàn toàn sự sai lệch do gộp chung điểm.
            </p>
          </div>

          {/* Tab Filter Chuyển Đổi Vectơ */}
          <div className="flex items-center gap-1.5 flex-wrap bg-surface-container-low p-1 rounded-xl border border-outline-variant/60">
            {[
              { id: 'all', label: 'Tất Cả 4 Vectơ', icon: 'hub', color: 'text-indigo-600' },
              { id: 'auth', label: '1. Xác Thực', icon: 'badge', color: 'text-amber-600' },
              { id: 'traffic', label: '2. Lưu Lượng', icon: 'waves', color: 'text-blue-600' },
              { id: 'exploit', label: '3. Khai Thác', icon: 'bug_report', color: 'text-rose-600' },
              { id: 'resource', label: '4. Tài Nguyên', icon: 'memory', color: 'text-teal-600' },
            ].map((tab) => {
              const isActive = activeVectorTab === tab.id;
              return (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => {
                    setActiveVectorTab(tab.id);
                    setHoveredPointIndex(null);
                  }}
                  className={`px-2.5 py-1 rounded-lg text-xs font-semibold transition-all cursor-pointer flex items-center gap-1.5 ${
                    isActive
                      ? 'bg-white text-on-surface shadow-xs border border-outline-variant/80'
                      : 'text-slate-600 hover:text-on-surface hover:bg-white/50'
                  }`}
                >
                  <span className={`material-symbols-outlined text-[14px] ${tab.color}`}>
                    {tab.icon}
                  </span>
                  <span>{tab.label}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Legend và Điểm số Thời gian thực */}
        <div className="flex items-center justify-between flex-wrap gap-2 text-[11px] font-medium bg-surface-container-lowest p-2.5 rounded-xl border border-outline-variant/60">
          <div className="flex items-center gap-3.5 flex-wrap">
            <span
              onClick={() => setActiveVectorTab(activeVectorTab === 'auth' ? 'all' : 'auth')}
              className={`flex items-center gap-1.5 cursor-pointer px-2 py-0.5 rounded transition-all ${
                activeVectorTab === 'auth' ? 'bg-amber-100 font-bold ring-1 ring-amber-300' : 'hover:bg-slate-100'
              }`}
            >
              <span className="w-2.5 h-2.5 rounded-full bg-amber-500 inline-block" />
              <span className="text-amber-900">1. Xác Thực: <strong>{vectorScores.auth ?? 0}</strong></span>
            </span>

            <span
              onClick={() => setActiveVectorTab(activeVectorTab === 'traffic' ? 'all' : 'traffic')}
              className={`flex items-center gap-1.5 cursor-pointer px-2 py-0.5 rounded transition-all ${
                activeVectorTab === 'traffic' ? 'bg-blue-100 font-bold ring-1 ring-blue-300' : 'hover:bg-slate-100'
              }`}
            >
              <span className="w-2.5 h-2.5 rounded-full bg-blue-500 inline-block" />
              <span className="text-blue-900">2. Lưu Lượng: <strong>{vectorScores.traffic ?? 0}</strong></span>
            </span>

            <span
              onClick={() => setActiveVectorTab(activeVectorTab === 'exploit' ? 'all' : 'exploit')}
              className={`flex items-center gap-1.5 cursor-pointer px-2 py-0.5 rounded transition-all ${
                activeVectorTab === 'exploit' ? 'bg-rose-100 font-bold ring-1 ring-rose-300' : 'hover:bg-slate-100'
              }`}
            >
              <span className="w-2.5 h-2.5 rounded-full bg-rose-500 inline-block" />
              <span className="text-rose-900">3. Khai Thác: <strong>{vectorScores.exploit ?? 0}</strong></span>
            </span>

            <span
              onClick={() => setActiveVectorTab(activeVectorTab === 'resource' ? 'all' : 'resource')}
              className={`flex items-center gap-1.5 cursor-pointer px-2 py-0.5 rounded transition-all ${
                activeVectorTab === 'resource' ? 'bg-teal-100 font-bold ring-1 ring-teal-300' : 'hover:bg-slate-100'
              }`}
            >
              <span className="w-2.5 h-2.5 rounded-full bg-teal-600 inline-block" />
              <span className="text-teal-900">4. Tài Nguyên: <strong>{vectorScores.resource ?? 0}</strong></span>
            </span>

            {activeVectorTab === 'all' && (
              <span className="flex items-center gap-1.5 text-purple-700">
                <span className="w-2.5 h-0.5 bg-purple-500 inline-block border-b border-dashed border-purple-700" />
                <span>Trần Max: <strong>{threatScore}</strong></span>
              </span>
            )}
          </div>

          <div className="flex items-center gap-3 text-slate-500">
            <span className="flex items-center gap-1">
              <span className="w-2.5 h-0.5 bg-red-500 inline-block" />
              <span>Ngưỡng Khẩn cấp (85)</span>
            </span>
            <span className="flex items-center gap-1">
              <span className="w-2.5 h-0.5 bg-amber-500 inline-block" />
              <span>Ngưỡng Cảnh báo (70)</span>
            </span>
          </div>
        </div>

        {/* SVG Multi-Vector Chart Container */}
        <div className="w-full overflow-x-auto">
          <div className="min-w-[640px] h-[210px] relative select-none">
            <svg
              className="w-full h-full"
              viewBox="0 0 800 180"
              preserveAspectRatio="none"
              onMouseLeave={() => setHoveredPointIndex(null)}
            >
              <defs>
                <linearGradient id="authGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                  <stop offset="0%" stopColor="#f59e0b" stopOpacity="0.35" />
                  <stop offset="100%" stopColor="#f59e0b" stopOpacity="0.0" />
                </linearGradient>
                <linearGradient id="trafficGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                  <stop offset="0%" stopColor="#3b82f6" stopOpacity="0.35" />
                  <stop offset="100%" stopColor="#3b82f6" stopOpacity="0.0" />
                </linearGradient>
                <linearGradient id="exploitGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                  <stop offset="0%" stopColor="#f43f5e" stopOpacity="0.35" />
                  <stop offset="100%" stopColor="#f43f5e" stopOpacity="0.0" />
                </linearGradient>
                <linearGradient id="resourceGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                  <stop offset="0%" stopColor="#0d9488" stopOpacity="0.35" />
                  <stop offset="100%" stopColor="#0d9488" stopOpacity="0.0" />
                </linearGradient>
              </defs>

              {/* Ngưỡng 85 (Critical line) */}
              <line
                x1="25"
                y1={180 - 25 - (85 / 100) * 130}
                x2="775"
                y2={180 - 25 - (85 / 100) * 130}
                stroke="#ef4444"
                strokeWidth="1.5"
                strokeDasharray="4 4"
                strokeOpacity="0.7"
              />
              <text x="780" y={180 - 21 - (85 / 100) * 130} fill="#ef4444" fontSize="10" fontWeight="bold">85</text>

              {/* Ngưỡng 70 (Warning line) */}
              <line
                x1="25"
                y1={180 - 25 - (70 / 100) * 130}
                x2="775"
                y2={180 - 25 - (70 / 100) * 130}
                stroke="#f59e0b"
                strokeWidth="1.5"
                strokeDasharray="4 4"
                strokeOpacity="0.7"
              />
              <text x="780" y={180 - 21 - (70 / 100) * 130} fill="#f59e0b" fontSize="10" fontWeight="bold">70</text>

              {/* Baseline 0 */}
              <line x1="25" y1="155" x2="775" y2="155" stroke="#cbd5e1" strokeWidth="1" />

              {/* 1. Đường & Vùng phủ Vectơ Xác thực (Amber) */}
              {(activeVectorTab === 'all' || activeVectorTab === 'auth') && chartSvgPaths.auth.path && (
                <>
                  {activeVectorTab === 'auth' && chartSvgPaths.auth.area && (
                    <path
                      d={chartSvgPaths.auth.area}
                      fill="url(#authGradient)"
                    />
                  )}
                  <path
                    d={chartSvgPaths.auth.path}
                    fill="none"
                    stroke="#f59e0b"
                    strokeWidth={activeVectorTab === 'auth' ? '2.8' : '2'}
                    strokeOpacity={activeVectorTab === 'all' || activeVectorTab === 'auth' ? 1 : 0.15}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                  {chartSvgPaths.auth.points.map((p, idx) => (
                    <circle
                      key={`auth-${idx}`}
                      cx={p.x}
                      cy={p.y}
                      r={hoveredPointIndex === idx ? 4.5 : p.score >= 70 ? 3.5 : 2}
                      fill="#f59e0b"
                      stroke="#ffffff"
                      strokeWidth={hoveredPointIndex === idx ? 1.5 : 0.8}
                    />
                  ))}
                </>
              )}

              {/* 2. Đường & Vùng phủ Vectơ Lưu lượng (Blue) */}
              {(activeVectorTab === 'all' || activeVectorTab === 'traffic') && chartSvgPaths.traffic.path && (
                <>
                  {activeVectorTab === 'traffic' && chartSvgPaths.traffic.area && (
                    <path
                      d={chartSvgPaths.traffic.area}
                      fill="url(#trafficGradient)"
                    />
                  )}
                  <path
                    d={chartSvgPaths.traffic.path}
                    fill="none"
                    stroke="#3b82f6"
                    strokeWidth={activeVectorTab === 'traffic' ? '2.8' : '2'}
                    strokeOpacity={activeVectorTab === 'all' || activeVectorTab === 'traffic' ? 1 : 0.15}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                  {chartSvgPaths.traffic.points.map((p, idx) => (
                    <circle
                      key={`traffic-${idx}`}
                      cx={p.x}
                      cy={p.y}
                      r={hoveredPointIndex === idx ? 4.5 : p.score >= 70 ? 3.5 : 2}
                      fill="#3b82f6"
                      stroke="#ffffff"
                      strokeWidth={hoveredPointIndex === idx ? 1.5 : 0.8}
                    />
                  ))}
                </>
              )}

              {/* 3. Đường & Vùng phủ Vectơ Khai thác (Rose) */}
              {(activeVectorTab === 'all' || activeVectorTab === 'exploit') && chartSvgPaths.exploit.path && (
                <>
                  {activeVectorTab === 'exploit' && chartSvgPaths.exploit.area && (
                    <path
                      d={chartSvgPaths.exploit.area}
                      fill="url(#exploitGradient)"
                    />
                  )}
                  <path
                    d={chartSvgPaths.exploit.path}
                    fill="none"
                    stroke="#f43f5e"
                    strokeWidth={activeVectorTab === 'exploit' ? '2.8' : '2'}
                    strokeOpacity={activeVectorTab === 'all' || activeVectorTab === 'exploit' ? 1 : 0.15}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                  {chartSvgPaths.exploit.points.map((p, idx) => (
                    <circle
                      key={`exploit-${idx}`}
                      cx={p.x}
                      cy={p.y}
                      r={hoveredPointIndex === idx ? 4.5 : p.score >= 70 ? 3.5 : 2}
                      fill="#f43f5e"
                      stroke="#ffffff"
                      strokeWidth={hoveredPointIndex === idx ? 1.5 : 0.8}
                    />
                  ))}
                </>
              )}

              {/* 4. Đường & Vùng phủ Vectơ Tài nguyên (Teal) */}
              {(activeVectorTab === 'all' || activeVectorTab === 'resource') && chartSvgPaths.resource.path && (
                <>
                  {activeVectorTab === 'resource' && chartSvgPaths.resource.area && (
                    <path
                      d={chartSvgPaths.resource.area}
                      fill="url(#resourceGradient)"
                    />
                  )}
                  <path
                    d={chartSvgPaths.resource.path}
                    fill="none"
                    stroke="#0d9488"
                    strokeWidth={activeVectorTab === 'resource' ? '2.8' : '2'}
                    strokeOpacity={activeVectorTab === 'all' || activeVectorTab === 'resource' ? 1 : 0.15}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                  {chartSvgPaths.resource.points.map((p, idx) => (
                    <circle
                      key={`resource-${idx}`}
                      cx={p.x}
                      cy={p.y}
                      r={hoveredPointIndex === idx ? 4.5 : p.score >= 70 ? 3.5 : 2}
                      fill="#0d9488"
                      stroke="#ffffff"
                      strokeWidth={hoveredPointIndex === idx ? 1.5 : 0.8}
                    />
                  ))}
                </>
              )}

              {/* Đường trần tham chiếu Max composite nếu ở Tab All */}
              {activeVectorTab === 'all' && chartSvgPaths.composite.path && (
                <path
                  d={chartSvgPaths.composite.path}
                  fill="none"
                  stroke="#8b5cf6"
                  strokeWidth="1.5"
                  strokeDasharray="4 3"
                  strokeOpacity="0.5"
                />
              )}

              {/* Cột bắt sự kiện chuột tương tác hover cho từng mẫu thời gian */}
              {chartSvgPaths.samples && chartSvgPaths.samples.map((s, idx) => (
                <g key={`hover-zone-${idx}`}>
                  {hoveredPointIndex === idx && (
                    <line
                      x1={s.x}
                      y1="15"
                      x2={s.x}
                      y2="155"
                      stroke="#64748b"
                      strokeWidth="1.2"
                      strokeDasharray="3 3"
                    />
                  )}
                  <rect
                    x={s.x - 6}
                    y="10"
                    width="12"
                    height="150"
                    fill="transparent"
                    className="cursor-pointer"
                    onMouseEnter={() => setHoveredPointIndex(idx)}
                  />
                </g>
              ))}
            </svg>

            {/* Tooltip Card hiển thị chi tiết khi rê chuột */}
            {hoveredPointIndex !== null && chartSvgPaths.samples[hoveredPointIndex] && (() => {
              const hs = chartSvgPaths.samples[hoveredPointIndex];
              const timeStr = hs.time ? new Date(hs.time).toLocaleTimeString('vi-VN') : 'Mẫu vừa xong';
              const leftPercent = Math.min(85, Math.max(15, (hs.x / 800) * 100));
              return (
                <div
                  className="absolute top-1 pointer-events-none z-20 bg-slate-900/95 text-white p-2.5 rounded-xl shadow-xl border border-slate-700 text-[11px] space-y-1.5 backdrop-blur-xs min-w-[210px] transform -translate-x-1/2 transition-transform duration-75"
                  style={{ left: `${leftPercent}%` }}
                >
                  <div className="flex items-center justify-between border-b border-slate-700 pb-1">
                    <span className="font-semibold text-slate-300 flex items-center gap-1">
                      <span className="material-symbols-outlined text-[13px] text-primary">schedule</span>
                      {timeStr}
                    </span>
                    <span className="text-[10px] text-slate-400">Mẫu #{hoveredPointIndex + 1}</span>
                  </div>

                  <div className="space-y-1">
                    <div className="flex items-center justify-between">
                      <span className="flex items-center gap-1 text-amber-400">
                        <span className="w-2 h-2 rounded-full bg-amber-400" />
                        1. Xác Thực:
                      </span>
                      <strong className="font-mono">{hs.auth.score}/100</strong>
                    </div>

                    <div className="flex items-center justify-between">
                      <span className="flex items-center gap-1 text-blue-400">
                        <span className="w-2 h-2 rounded-full bg-blue-400" />
                        2. Lưu Lượng:
                      </span>
                      <strong className="font-mono">{hs.traffic.score}/100</strong>
                    </div>

                    <div className="flex items-center justify-between">
                      <span className="flex items-center gap-1 text-rose-400">
                        <span className="w-2 h-2 rounded-full bg-rose-400" />
                        3. Khai Thác:
                      </span>
                      <strong className="font-mono">{hs.exploit.score}/100</strong>
                    </div>

                    <div className="flex items-center justify-between">
                      <span className="flex items-center gap-1 text-teal-400">
                        <span className="w-2 h-2 rounded-full bg-teal-400" />
                        4. Tài Nguyên:
                      </span>
                      <strong className="font-mono">{hs.resource.score}/100</strong>
                    </div>

                    <div className="pt-1 border-t border-slate-700/80 flex items-center justify-between text-purple-300 font-bold">
                      <span>Threat Score:</span>
                      <span className="font-mono">{hs.composite.score}/100</span>
                    </div>
                  </div>
                </div>
              );
            })()}
          </div>
        </div>

        {/* Chân biểu đồ & Nguyên tắc bảo vệ */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between text-[11px] text-slate-500 px-2 pt-2 border-t border-slate-100 gap-2">
          <div className="flex items-center gap-4">
            <span>🕒 10 phút trước</span>
            <span>🕒 5 phút trước</span>
            <span className="font-semibold text-slate-700">🕒 Hiện tại</span>
          </div>

          <div className="text-[10px] text-slate-600 bg-slate-50 px-2.5 py-1 rounded-md border border-slate-200">
            🛡️ <strong>Nguyên tắc:</strong> Phòng vệ được kích hoạt độc lập theo từng vectơ. Tuyệt đối không dùng điểm gộp chung để ngắt kết nối hệ thống.
          </div>
        </div>
      </div>

      {/* ======================================================== */}
      {/* KHỐI 4: BẢNG PHÂN TÍCH NGUYÊN NHÂN GỐC RỄ (ROOT CAUSE ANALYSIS) */}
      {/* ======================================================== */}
      <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4">
        <div className="flex items-center justify-between border-b border-outline-variant pb-3">
          <div>
            <h2 className="text-sm font-bold text-on-surface m-0 flex items-center gap-2">
              <span className="material-symbols-outlined text-[18px] text-primary">troubleshoot</span>
              Bóc Tách & Phân Tích Nguyên Nhân Bất Thường (Root Cause Analysis)
            </h2>
            <p className="text-[11px] text-slate-500 mt-0.5">
              Giải trình cơ chế phát hiện tự động bằng thuật toán AI và mức độ ảnh hưởng của từng bất thường
            </p>
          </div>

          <span className="text-xs font-semibold px-2.5 py-1 rounded-lg bg-surface-container-low border border-outline-variant/60">
            {anomalies.length} mối nguy hiểm ghi nhận
          </span>
        </div>

        {anomalies.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b border-outline-variant/80 bg-surface-container-low/50 text-slate-600 font-bold uppercase text-[10px] tracking-wider">
                  <th className="py-2.5 px-3">Mức độ</th>
                  <th className="py-2.5 px-3">Mã Bất Thường</th>
                  <th className="py-2.5 px-3">Chỉ số đo được</th>
                  <th className="py-2.5 px-3">Đường chuẩn (Baseline)</th>
                  <th className="py-2.5 px-3">Mô tả chi tiết từ AI</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-outline-variant/40">
                {anomalies.map((a, idx) => (
                  <tr key={idx} className="hover:bg-slate-50/80 transition-colors">
                    <td className="py-3 px-3 whitespace-nowrap">
                      <span
                        className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                          a.severity === 'HIGH'
                            ? 'bg-red-100 text-red-800'
                            : a.severity === 'MEDIUM'
                            ? 'bg-amber-100 text-amber-800'
                            : 'bg-blue-100 text-blue-800'
                        }`}
                      >
                        {a.severity}
                      </span>
                    </td>
                    <td className="py-3 px-3 font-mono font-bold text-slate-800 whitespace-nowrap">
                      {a.code}
                    </td>
                    <td className="py-3 px-3 font-semibold text-red-600 whitespace-nowrap">
                      {a.current}
                    </td>
                    <td className="py-3 px-3 text-slate-500 whitespace-nowrap">
                      {a.baseline}
                    </td>
                    <td className="py-3 px-3 text-slate-700 font-medium">
                      {a.message}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="p-8 text-center rounded-xl bg-emerald-50/50 border border-emerald-200/80 space-y-2">
            <span className="material-symbols-outlined text-[44px] text-emerald-600">verified</span>
            <p className="font-bold text-sm text-emerald-950">Không phát hiện mối đe dọa nào</p>
            <p className="text-xs text-emerald-800/80 max-w-md mx-auto">
              Tất cả 12 thông số hệ thống (lưu lượng, mã phản hồi 4xx/5xx, chu kỳ xác thực, tải CPU/RAM và độ trễ Event Loop) đang dao động hoàn toàn trong ngưỡng an toàn.
            </p>
          </div>
        )}
      </div>

      {/* ======================================================== */}
      {/* MODAL 1-CLICK BẢO TRÌ KHẨN CẤP */}
      {/* ======================================================== */}
      {showMitigationModal && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4 backdrop-blur-xs">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-xl border border-red-200 space-y-4 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-xl bg-red-100 text-red-600 flex items-center justify-center flex-shrink-0">
                <span className="material-symbols-outlined text-[24px]">crisis_alert</span>
              </div>
              <div>
                <h3 className="text-base font-bold text-red-950 m-0">Xác nhận Bật Bảo Trì Khẩn Cấp</h3>
                <p className="text-xs text-slate-600 mt-1">
                  Thao tác này sẽ lập tức kích hoạt mã phản hồi HTTP 503 cho toàn bộ Client-app, phát cảnh báo đỏ tới người dùng, và bảo toàn an ninh máy chủ.
                </p>
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                Lý do hiển thị tới người dùng
              </label>
              <textarea
                value={mitigationReason}
                onChange={(e) => setMitigationReason(e.target.value)}
                rows={3}
                className="w-full border border-outline-variant rounded-lg p-2.5 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-red-400"
              />
            </div>

            <div className="flex items-center justify-end gap-2.5 pt-2 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setShowMitigationModal(false)}
                disabled={mitigating}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-600 hover:bg-slate-100 transition-colors cursor-pointer"
              >
                Hủy bỏ
              </button>

              <button
                type="button"
                onClick={handleTriggerMitigation}
                disabled={mitigating}
                className="px-4 py-2 rounded-xl text-xs font-bold text-white bg-red-600 hover:bg-red-700 transition-all cursor-pointer flex items-center gap-1.5 shadow-sm"
              >
                <span className="material-symbols-outlined text-[16px]">lock</span>
                <span>{mitigating ? 'Đang kích hoạt...' : 'Khóa Hệ Thống Ngay'}</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ======================================================== */}
      {/* MODAL GIẢI THÍCH & XÁC NHẬN TÁI HIỆU CHUẨN BASELINE */}
      {/* ======================================================== */}
      {showCalibrateModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-xs p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-xl border border-blue-200 space-y-4 animate-in fade-in zoom-in-95 duration-150">
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-xl bg-blue-100 text-blue-700 flex items-center justify-center flex-shrink-0">
                <span className="material-symbols-outlined text-[24px]">tune</span>
              </div>
              <div>
                <h3 className="text-base font-bold text-blue-950 m-0">Tái Hiệu Chuẩn Baseline Máy Học (Calibrate Baseline)</h3>
                <p className="text-xs text-slate-600 mt-1">
                  Đặt lại đường chuẩn thống kê cho khung giờ hiện tại dựa trên lưu lượng thực tế.
                </p>
              </div>
            </div>

            <div className="rounded-xl bg-blue-50/70 border border-blue-100 p-3.5 space-y-2 text-xs text-slate-700 leading-relaxed">
              <div className="font-bold text-blue-950 flex items-center gap-1.5">
                <span className="material-symbols-outlined text-[16px] text-blue-600">help</span>
                <span>Nút này dùng để làm gì?</span>
              </div>
              <ul className="list-disc pl-4 space-y-1.5 text-[11px] text-slate-600">
                <li>
                  <strong>Học đường chuẩn (Baseline):</strong> AIOps Sentinel liên tục học mức request/phút, tỷ lệ lỗi, RAM/CPU bình thường của 24 khung giờ Việt Nam (GMT+7).
                </li>
                <li>
                  <strong>Khi có sự kiện lớn:</strong> Khi doanh nghiệp mở chiến dịch khuyến mãi hoặc vừa nâng cấp máy chủ, lưu lượng hợp pháp tăng vọt. Nhấn nút này để máy học cập nhật lại ngưỡng an toàn mới, tránh hiểu nhầm là tấn công DoS.
                </li>
                <li>
                  <strong>Chống đầu độc mô hình:</strong> Hệ thống tự động ngăn chặn kẻ tấn công thao túng đường chuẩn khi Threat Score $\ge 70$.
                </li>
              </ul>
            </div>

            <div className="flex items-center justify-end gap-2.5 pt-2 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setShowCalibrateModal(false)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-600 hover:bg-slate-100 transition-colors cursor-pointer"
              >
                Đóng
              </button>

              <button
                type="button"
                onClick={handleCalibrate}
                disabled={calibrating}
                className="px-4 py-2 rounded-xl text-xs font-bold text-white bg-blue-600 hover:bg-blue-700 transition-all cursor-pointer flex items-center gap-1.5 shadow-sm"
              >
                <span className="material-symbols-outlined text-[16px]">check_circle</span>
                <span>{calibrating ? 'Đang hiệu chuẩn...' : 'Xác Nhận Tái Hiệu Chuẩn'}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AIOpsPage;
