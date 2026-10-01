import React, { useState, useEffect, useCallback } from 'react';
import adminApi from '../../api/admin.api';

const REFRESH_MS = 30_000;

const Gauge = ({ label, value, max, unit, warnAt, critAt, icon }) => {
  const pct = max > 0 ? Math.round((value / max) * 100) : value;
  const color = pct >= critAt ? 'text-red-500' : pct >= warnAt ? 'text-amber-500' : 'text-emerald-500';
  const bar = pct >= critAt ? 'bg-red-500' : pct >= warnAt ? 'bg-amber-400' : 'bg-emerald-500';
  return (
    <div className="flex flex-col gap-1">
      <div className="flex items-center justify-between text-xs text-gray-500">
        <span className="flex items-center gap-1 font-medium text-gray-700">
          <span className="material-symbols-outlined text-[14px]">{icon}</span>
          {label}
        </span>
        <span className={`font-semibold ${color}`}>
          {max > 0 ? `${value}/${max} ${unit}` : `${value}${unit}`}
        </span>
      </div>
      <div className="w-full h-2 bg-gray-100 rounded-full overflow-hidden">
        <div className={`h-full rounded-full transition-all duration-500 ${bar}`} style={{ width: `${Math.min(pct, 100)}%` }} />
      </div>
    </div>
  );
};

/**
 * UptimeWidget — Hiển thị uptime thực tế của server.
 *
 * Công thức (tính ở backend, hiển thị ở đây):
 *   uptimePercent = uptimeSeconds / max(uptimeSeconds, slaWindow) × 100
 *   slaWindow = 30 ngày = 2,592,000 giây
 *
 * - Server chạy ≥ 30 ngày liên tục → uptimePercent = 100%
 * - Server mới khởi động (vd: 1 giờ) → uptimePercent ≈ 0.14%
 *   → phản ánh đúng thực tế, khuyến khích admin giữ server ổn định
 */
const UptimeWidget = ({ uptime }) => {
  if (!uptime) {
    return (
      <div className="bg-surface-container-low rounded-lg p-3 text-xs text-on-surface-variant border border-outline-variant/40 flex items-center justify-between">
        <span className="flex items-center gap-1 font-semibold text-on-surface">
          <span className="material-symbols-outlined text-[14px] text-gray-400">timer</span>
          Uptime Hệ thống
        </span>
        <span className="text-[11px] text-amber-700 bg-amber-50 border border-amber-200/60 px-2 py-0.5 rounded font-medium">
          Chờ cập nhật API
        </span>
      </div>
    );
  }

  const { uptimeFormatted, uptimePercent, startedAt, slaWindowDays } = uptime;
  const pct = uptimePercent ?? 0;

  // Màu sắc theo ngưỡng SLA
  const barColor = pct >= 99.5 ? 'bg-emerald-500' : pct >= 95 ? 'bg-amber-400' : 'bg-red-500';
  const textColor = pct >= 99.5 ? 'text-emerald-600' : pct >= 95 ? 'text-amber-600' : 'text-red-600';

  // Format startedAt → giờ Việt Nam (vi-VN locale)
  const startedAtDisplay = startedAt
    ? new Intl.DateTimeFormat('vi-VN', {
        timeZone: 'Asia/Ho_Chi_Minh',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        hour12: false,
      }).format(new Date(startedAt))
    : '—';

  return (
    <div className="bg-surface-container-low rounded-lg p-3 text-xs text-on-surface-variant space-y-2 border border-outline-variant/40">
      <p className="text-on-surface font-semibold flex items-center gap-1">
        <span className="material-symbols-outlined text-[14px] text-emerald-600">timer</span>
        Uptime Hệ thống
        <span className="ml-auto text-[10px] text-gray-400 font-normal">SLA {slaWindowDays}d</span>
      </p>

      {/* Thanh progress uptime */}
      <div className="flex flex-col gap-1">
        <div className="flex justify-between items-center">
          <span className="text-gray-500">Hoạt động liên tục:</span>
          <span className={`font-bold text-[13px] ${textColor}`}>{pct.toFixed(3)}%</span>
        </div>
        <div className="w-full h-2.5 bg-gray-100 rounded-full overflow-hidden">
          <div
            className={`h-full rounded-full transition-all duration-700 ${barColor}`}
            style={{ width: `${Math.min(pct, 100)}%` }}
          />
        </div>
      </div>

      {/* Chi tiết */}
      <div className="flex justify-between pt-0.5">
        <span>Thời gian chạy:</span>
        <span className="font-semibold text-on-surface">{uptimeFormatted}</span>
      </div>
      <div className="flex justify-between">
        <span>Khởi động lúc:</span>
        <span className="font-semibold text-on-surface text-[11px]">{startedAtDisplay}</span>
      </div>
    </div>
  );
};

const ServerHealthPanel = () => {
  const [health, setHealth] = useState(null);
  const [loading, setLoading] = useState(true);
  const [reason, setReason] = useState('');
  const [toggling, setToggling] = useState(false);
  const [error, setError] = useState(null);

  const fetchHealth = useCallback(async () => {
    try {
      const res = await adminApi.getSystemHealth();
      setHealth(res.data?.data || res.data);
      setError(null);
    } catch {
      setError('Không thể tải thông tin hệ thống');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchHealth();
    const t = setInterval(fetchHealth, REFRESH_MS);
    return () => clearInterval(t);
  }, [fetchHealth]);

  const toggle = async () => {
    if (!health) return;
    const next = !health.maintenance.active;
    if (next && !reason.trim()) {
      alert('Nhập lý do bảo trì trước khi bật!');
      return;
    }
    setToggling(true);
    try {
      await adminApi.setMaintenanceStatus({ active: next, reason: next ? reason.trim() : null });
      await fetchHealth();
      if (!next) setReason('');
    } catch (e) {
      alert('Lỗi: ' + (e.response?.data?.message || e.message));
    } finally {
      setToggling(false);
    }
  };

  if (loading) {
    return (
      <div className="bg-white rounded-xl border border-outline-variant shadow-sm p-5 flex items-center justify-center h-48">
        <span className="material-symbols-outlined animate-spin text-primary text-2xl">progress_activity</span>
      </div>
    );
  }

  if (error || !health) {
    return (
      <div className="bg-white rounded-xl border border-red-200 shadow-sm p-4 text-red-600 text-sm flex items-center gap-2">
        <span className="material-symbols-outlined text-[18px]">error</span>
        <span>{error || 'Không có dữ liệu'}</span>
      </div>
    );
  }

  const { cpu, ram, eventLoop, dbPool, maintenance, loadShedding, uptime } = health;
  const critical = eventLoop.overloaded || cpu.percent > 85 || ram.percent > 85;

  return (
    <div className="bg-white rounded-xl border border-outline-variant shadow-sm p-5 space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-outline-variant/50 pb-3">
        <div className="flex items-center gap-2">
          <span className={`w-2.5 h-2.5 rounded-full ${critical ? 'bg-red-500 animate-pulse' : 'bg-emerald-500'}`} />
          <h3 className="font-title-md font-bold text-on-surface text-sm">Server Health</h3>
        </div>
        <button
          onClick={fetchHealth}
          className="text-on-surface-variant hover:text-primary transition-colors cursor-pointer"
          title="Làm mới"
        >
          <span className="material-symbols-outlined text-[18px]">refresh</span>
        </button>
      </div>

      {/* CPU / RAM / Event Loop Gauges */}
      <div className="space-y-3">
        <Gauge label="CPU" value={cpu.percent} max={100} unit="%" warnAt={70} critAt={85} icon="memory_alt" />
        <Gauge label="RAM" value={ram.usedMb} max={ram.totalMb} unit="MB" warnAt={70} critAt={85} icon="storage" />
        <Gauge label="Event Loop" value={eventLoop.lagMs} max={200} unit="ms" warnAt={50} critAt={100} icon="speed" />
      </div>

      {/* Uptime Widget — dữ liệu thực từ process.uptime() */}
      <UptimeWidget uptime={uptime} />

      {/* DB Pool & Load Shedding */}
      <div className="bg-surface-container-low rounded-lg p-3 text-xs text-on-surface-variant space-y-1.5 border border-outline-variant/40">
        <p className="text-on-surface font-semibold mb-1 flex items-center gap-1">
          <span className="material-symbols-outlined text-[14px]">database</span>
          DB Pool & Cắt Tải
        </p>
        <div className="flex justify-between">
          <span>Client Pool:</span>
          <span className={`font-semibold ${dbPool.clientActive >= dbPool.clientLimit ? 'text-red-500' : 'text-emerald-600'}`}>
            {dbPool.clientActive}/{dbPool.clientLimit}
          </span>
        </div>
        <div className="flex justify-between">
          <span>Admin Pool:</span>
          <span className="font-semibold text-on-surface">{dbPool.adminActive}/{dbPool.maxConnections - dbPool.clientLimit}</span>
        </div>
        <div className="flex justify-between text-gray-500">
          <span>Load Shed (24h):</span>
          <span className={`font-semibold ${loadShedding.shedCount24h > 0 ? 'text-amber-600' : 'text-gray-600'}`}>
            {loadShedding.shedCount24h} lần
          </span>
        </div>
      </div>

      {/* Maintenance Toggle */}
      <div className={`rounded-lg p-3 border transition-colors ${maintenance.active ? 'border-orange-300 bg-orange-50' : 'border-outline-variant bg-surface-container-lowest'}`}>
        <div className="flex items-center justify-between mb-2">
          <p className="text-xs font-semibold text-on-surface flex items-center gap-1">
            <span className="material-symbols-outlined text-[15px] text-amber-600">construction</span>
            Bảo trì khẩn cấp
          </p>
          <button
            id="btn-maintenance-toggle"
            onClick={toggle}
            disabled={toggling}
            className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors duration-200 cursor-pointer disabled:opacity-50 ${maintenance.active ? 'bg-orange-500' : 'bg-gray-300'}`}
          >
            <span className={`inline-block h-4 w-4 rounded-full bg-white shadow transition-transform duration-200 ${maintenance.active ? 'translate-x-4' : 'translate-x-0.5'}`} />
          </button>
        </div>
        {!maintenance.active && (
          <input
            type="text"
            placeholder="Lý do bảo trì (bắt buộc khi bật)..."
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            className="w-full text-xs bg-white text-on-surface border border-outline-variant rounded-md px-2.5 py-1.5 placeholder:text-gray-400 focus:outline-none focus:ring-1 focus:ring-primary"
          />
        )}
        {maintenance.active && (
          <div className="text-xs text-orange-800 space-y-0.5">
            <p className="font-semibold">⚠️ {maintenance.reason}</p>
            {maintenance.activatedBy && (
              <p className="text-gray-500 text-[11px]">Bởi: {maintenance.activatedBy} · {maintenance.activatedAt ? new Date(maintenance.activatedAt).toLocaleString('vi-VN') : ''}</p>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default ServerHealthPanel;
