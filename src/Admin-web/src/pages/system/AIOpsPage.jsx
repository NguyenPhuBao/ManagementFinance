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

      if (sData) setStatusData(sData);
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
  const sample = statusData?.sample || {};
  const anomalies = statusData?.anomalies || [];
  const recommendedAction = statusData?.recommendedAction;

  // Tính toán màu sắc hiển thị theo Threat Score
  const theme = useMemo(() => {
    if (threatScore >= 85) {
      return {
        badgeBg: 'bg-red-100 text-red-800 border-red-300',
        color: '#ef4444',
        label: 'NGUY CẤP (CRITICAL)',
        glow: 'ring-4 ring-red-400/40',
        border: 'border-red-400 bg-red-50/50',
      };
    }
    if (threatScore >= 70) {
      return {
        badgeBg: 'bg-amber-100 text-amber-800 border-amber-300',
        color: '#f59e0b',
        label: 'CẢNH BÁO (WARNING)',
        glow: 'ring-4 ring-amber-400/30',
        border: 'border-amber-400 bg-amber-50/50',
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

  // Chuẩn bị đường vẽ SVG cho Timeline (60 mẫu)
  const chartSvgPath = useMemo(() => {
    if (!historyData || historyData.length === 0) return { path: '', area: '', points: [] };
    const width = 800;
    const height = 180;
    const padding = 20;

    const maxVal = 100;
    const minVal = 0;
    const count = historyData.length;
    const stepX = count > 1 ? (width - 2 * padding) / (count - 1) : width;

    const points = historyData.map((d, i) => {
      const x = padding + i * stepX;
      const y = height - padding - ((d.threatScore - minVal) / (maxVal - minVal)) * (height - 2 * padding);
      return { x, y, score: d.threatScore, time: d.timestamp };
    });

    const path = points.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(' ');
    const area = `${path} L ${points[points.length - 1].x.toFixed(1)} ${height - padding} L ${points[0].x.toFixed(1)} ${height - padding} Z`;

    return { path, area, points };
  }, [historyData]);

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

          {threatScore >= 70 && (
            <button
              onClick={() => setShowMitigationModal(true)}
              className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white text-xs font-bold rounded-xl shadow-xs transition-all cursor-pointer flex items-center gap-1.5 animate-pulse"
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
                <span>70 (Cảnh báo)</span>
                <span>100 (Khẩn cấp)</span>
              </div>
            </div>
          </div>

          {/* Khuyến nghị hành động */}
          <div className="pt-3 border-t border-outline-variant/60 text-xs">
            <span className="font-semibold text-on-surface">Phòng vệ AIOps: </span>
            <span className="font-bold" style={{ color: theme.color }}>
              {recommendedAction === 'EMERGENCY_MAINTENANCE'
                ? '🚨 KÍCH HOẠT BẢO TRÌ KHẨN CẤP ĐỂ NGĂN CHẶN SẬP DÂY CHUYỀN'
                : recommendedAction === 'INVESTIGATE'
                ? '⚠️ NGUỒN TẤN CÔNG ĐÃ BỊ TỰ ĐỘNG CHẶN — THEO DÕI LOGS'
                : '✅ HỆ THỐNG AN TOÀN, HOẠT ĐỘNG ỔN ĐỊNH'}
            </span>
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
      {/* KHỐI 3: BIỂU ĐỒ SVG XU HƯỚNG NGUY CƠ REAL-TIME (THREAT TIMELINE) */}
      {/* ======================================================== */}
      <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-3">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-outline-variant pb-3">
          <div>
            <h2 className="text-sm font-bold text-on-surface m-0 flex items-center gap-2">
              <span className="material-symbols-outlined text-[18px] text-primary">show_chart</span>
              Biểu Đồ Xu Hướng Rủi Ro Thời Gian Thực (60 Mẫu Gần Nhất — 10 Phút)
            </h2>
            <p className="text-[11px] text-slate-500 mt-0.5">
              Theo dõi biến thiên Threat Score liên tục, hỗ trợ nhận diện các đợt càn quét hoặc suy giảm phần cứng kéo dài
            </p>
          </div>

          <div className="flex items-center gap-3 text-[11px] font-medium self-end sm:self-auto">
            <span className="flex items-center gap-1">
              <span className="w-2.5 h-0.5 bg-red-500 inline-block" />
              <span>Khẩn cấp (85)</span>
            </span>
            <span className="flex items-center gap-1">
              <span className="w-2.5 h-0.5 bg-amber-500 inline-block" />
              <span>Cảnh báo (70)</span>
            </span>
            <span className="flex items-center gap-1">
              <span className="w-2.5 h-2.5 rounded-full bg-primary inline-block" />
              <span>Threat Score</span>
            </span>
          </div>
        </div>

        {/* SVG Container */}
        <div className="w-full overflow-x-auto">
          <div className="min-w-[640px] h-[200px] relative">
            <svg className="w-full h-full" viewBox="0 0 800 180" preserveAspectRatio="none">
              <defs>
                <linearGradient id="threatGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                  <stop offset="0%" stopColor="#ef4444" stopOpacity="0.4" />
                  <stop offset="50%" stopColor="#f59e0b" stopOpacity="0.2" />
                  <stop offset="100%" stopColor="#10b981" stopOpacity="0.02" />
                </linearGradient>
              </defs>

              {/* Ngưỡng 85 (Critical line) */}
              <line
                x1="20"
                y1={180 - 20 - (85 / 100) * 140}
                x2="780"
                y2={180 - 20 - (85 / 100) * 140}
                stroke="#ef4444"
                strokeWidth="1.5"
                strokeDasharray="4 4"
                strokeOpacity="0.6"
              />
              <text x="785" y={180 - 16 - (85 / 100) * 140} fill="#ef4444" fontSize="10" fontWeight="bold">85</text>

              {/* Ngưỡng 70 (Warning line) */}
              <line
                x1="20"
                y1={180 - 20 - (70 / 100) * 140}
                x2="780"
                y2={180 - 20 - (70 / 100) * 140}
                stroke="#f59e0b"
                strokeWidth="1.5"
                strokeDasharray="4 4"
                strokeOpacity="0.6"
              />
              <text x="785" y={180 - 16 - (70 / 100) * 140} fill="#f59e0b" fontSize="10" fontWeight="bold">70</text>

              {/* Baseline 0 */}
              <line x1="20" y1="160" x2="780" y2="160" stroke="#cbd5e1" strokeWidth="1" />

              {/* Area Under Curve */}
              {chartSvgPath.area && (
                <path d={chartSvgPath.area} fill="url(#threatGradient)" />
              )}

              {/* Line Curve */}
              {chartSvgPath.path && (
                <path
                  d={chartSvgPath.path}
                  fill="none"
                  stroke="#2563eb"
                  strokeWidth="2.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              )}

              {/* Point Markers */}
              {chartSvgPath.points.map((p, idx) => (
                <circle
                  key={idx}
                  cx={p.x}
                  cy={p.y}
                  r={p.score >= 70 ? 4 : 2.5}
                  fill={p.score >= 85 ? '#ef4444' : p.score >= 70 ? '#f59e0b' : '#2563eb'}
                  stroke="#ffffff"
                  strokeWidth="1"
                />
              ))}
            </svg>
          </div>
        </div>

        <div className="flex items-center justify-between text-[11px] text-slate-400 px-2 pt-1 border-t border-slate-100">
          <span>10 phút trước</span>
          <span>5 phút trước</span>
          <span>Thời điểm hiện tại</span>
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
