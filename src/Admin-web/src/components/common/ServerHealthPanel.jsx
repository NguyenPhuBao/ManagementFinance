import React, { useState, useEffect, useCallback } from 'react';
import adminApi from '../../api/admin.api';
import useSocket from '../../hooks/useSocket';
import { useLanguageSafe } from '../../store/language.context';

const REFRESH_MS = 60_000;

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

const UptimeWidget = ({ uptime }) => {
  const { t } = useLanguageSafe();
  if (!uptime) {
    return (
      <div className="bg-surface-container-low rounded-lg p-3 text-xs text-on-surface-variant border border-outline-variant/40 flex items-center justify-between">
        <span className="flex items-center gap-1 font-semibold text-on-surface">
          <span className="material-symbols-outlined text-[14px] text-gray-400">timer</span>
          {t('serverHealth.uptime', 'Uptime & Tính liên tục')}
        </span>
        <span className="text-[11px] text-amber-700 bg-amber-50 border border-amber-200/60 px-2 py-0.5 rounded font-medium">
          {t('serverHealth.awaiting', 'Đang kết nối...')}
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
        {t('serverHealth.uptime', 'Uptime & Tính liên tục')}
        <span className="ml-auto text-[10px] text-gray-400 font-normal">SLA {slaWindowDays}d</span>
      </p>

      {/* Thanh progress uptime */}
      <div className="flex flex-col gap-1">
        <div className="flex justify-between items-center">
          <span className="text-gray-500">{t('serverHealth.continuous', 'Khả năng sẵn sàng (SLA):')}</span>
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
        <span>{t('serverHealth.runtime', 'Thời gian chạy liên tục:')}</span>
        <span className="font-semibold text-on-surface">{uptimeFormatted}</span>
      </div>
      <div className="flex justify-between">
        <span>{t('serverHealth.startedAt', 'Khởi động lúc:')}</span>
        <span className="font-semibold text-on-surface text-[11px]">{startedAtDisplay}</span>
      </div>
    </div>
  );
};

const ServerHealthPanel = () => {
  const { t } = useLanguageSafe();
  const [health, setHealth] = useState(null);
  const [healthLoading, setHealthLoading] = useState(true);
  const [healthError, setHealthError] = useState(null);

  // Trạng thái bảo trì độc lập (Cửa thoát hiểm khẩn cấp - ProcessAdmin.md)
  const [maintenance, setMaintenance] = useState({ active: false, reason: '', activatedBy: null, activatedAt: null });
  const [maintenanceLoading, setMaintenanceLoading] = useState(true);
  const [reason, setReason] = useState('');
  const [toggling, setToggling] = useState(false);

  // 1. Tải trạng thái bảo trì độc lập (siêu nhẹ, không nghẽn)
  const fetchMaintenance = useCallback(async () => {
    try {
      const res = await adminApi.getMaintenanceStatus();
      const data = res?.data?.data || res?.data;
      if (data) {
        setMaintenance({
          active: Boolean(data.active),
          reason: data.reason || '',
          activatedBy: data.activatedBy || null,
          activatedAt: data.activatedAt || null,
        });
      }
    } catch (e) {
      console.warn('[ServerHealthPanel] Lỗi tải trạng thái bảo trì:', e.message);
    } finally {
      setMaintenanceLoading(false);
    }
  }, []);

  // 2. Tải chỉ số tài nguyên hệ thống (CPU/RAM/Lag/Uptime/DBPool)
  const fetchHealth = useCallback(async () => {
    setHealthLoading(true);
    try {
      const res = await adminApi.getSystemHealth();
      const data = res?.data?.data || res?.data;
      if (data) {
        setHealth(data);
        setHealthError(null);
        // Đồng bộ trạng thái bảo trì nếu có kèm theo
        if (data.maintenance) {
          setMaintenance(data.maintenance);
        }
      } else {
        setHealthError(t('serverHealth.noData', 'Không nhận được dữ liệu giám sát'));
      }
    } catch (err) {
      console.warn('[ServerHealthPanel] Không thể tải thông số hệ thống:', err.message);
      setHealthError(t('serverHealth.notSync', 'Chưa có thông số giám sát (API chưa đồng bộ)'));
    } finally {
      setHealthLoading(false);
    }
  }, [t]);

  const refreshAll = useCallback(() => {
    fetchMaintenance();
    fetchHealth();
  }, [fetchMaintenance, fetchHealth]);

  useEffect(() => {
    refreshAll();
    const tTimer = setInterval(refreshAll, REFRESH_MS);
    return () => clearInterval(tTimer);
  }, [refreshAll]);

  // Lắng nghe luồng nhịp tim metrics_stream qua Socket.io thời gian thực (3s/lần)
  const socket = useSocket();
  useEffect(() => {
    if (!socket) return;

    const handleMetricsStream = (data) => {
      if (!data) return;
      setHealth((prev) => ({
        ...prev,
        uptime: {
          uptimeFormatted: data.uptimeFormatted,
          uptimePercent: Math.min(100, parseFloat(((data.uptimeSeconds / (30 * 24 * 3600)) * 100).toFixed(3))),
          startedAt: prev?.uptime?.startedAt || null,
          slaWindowDays: 30,
        },
        cpu: { percent: data.cpuPercent },
        ram: { percent: data.ramPercent, rssMb: data.ramRssMb },
        eventLoop: { lagMs: data.eventLoopLagMs, overloaded: data.eventLoopLagMs > 50 },
        dbPool: data.dbPool || prev?.dbPool,
        loadShedding: prev?.loadShedding || { totalShed: 0 },
      }));
      setHealthLoading(false);
      setHealthError(null);

      if (data.maintenance) {
        setMaintenance(data.maintenance);
      }
    };

    const handleMaintenanceChanged = (mState) => {
      if (mState) {
        setMaintenance(mState);
      }
    };

    socket.on('admin.metrics_stream', handleMetricsStream);
    socket.on('admin.maintenance_changed', handleMaintenanceChanged);
    socket.on('system.maintenance_changed', handleMaintenanceChanged);

    return () => {
      socket.off('admin.metrics_stream', handleMetricsStream);
      socket.off('admin.maintenance_changed', handleMaintenanceChanged);
      socket.off('system.maintenance_changed', handleMaintenanceChanged);
    };
  }, [socket]);

  // 3. Thao tác công tắc bảo trì khẩn cấp (Emergency Switch)
  const toggle = async () => {
    const next = !maintenance.active;
    if (next && !reason.trim()) {
      alert(t('serverHealth.alertReasonRequired', 'Vui lòng nhập lý do trước khi kích hoạt bảo trì khẩn cấp!'));
      return;
    }
    setToggling(true);
    try {
      const payload = { active: next, reason: next ? reason.trim() : null, isEmergency: true };
      await adminApi.setMaintenanceStatus(payload);
      setMaintenance((prev) => ({
        ...prev,
        active: next,
        isEmergency: next,
        reason: next ? reason.trim() : '',
        activatedAt: new Date().toISOString(),
      }));
      if (!next) setReason('');
      // Làm mới lại dữ liệu xác thực
      await fetchMaintenance();
    } catch (e) {
      alert(t('serverHealth.alertToggleError', 'Lỗi thao tác bảo trì: ') + (e.response?.data?.message || e.message));
    } finally {
      setToggling(false);
    }
  };

  const cpu = health?.cpu;
  const ram = health?.ram;
  const eventLoop = health?.eventLoop;
  const dbPool = health?.dbPool;
  const loadShedding = health?.loadShedding;
  const uptime = health?.uptime;
  const critical = eventLoop?.overloaded || (cpu?.percent ?? 0) > 85 || (ram?.percent ?? 0) > 85;

  return (
    <div className="bg-white rounded-xl border border-outline-variant shadow-sm p-5 space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-outline-variant/50 pb-3">
        <div className="flex items-center gap-2">
          <span className={`w-2.5 h-2.5 rounded-full ${critical ? 'bg-red-500 animate-pulse' : 'bg-emerald-500'}`} />
          <h3 className="font-title-md font-bold text-on-surface text-sm">{t('serverHealth.title', 'Sức Khỏe Máy Chủ')}</h3>
        </div>
        <button
          onClick={refreshAll}
          className="text-on-surface-variant hover:text-primary transition-colors cursor-pointer p-1 rounded-md hover:bg-surface-container-low"
          title={t('common.refresh', 'Làm mới')}
        >
          <span className="material-symbols-outlined text-[18px]">refresh</span>
        </button>
      </div>

      {/* KHỐI 1: CHỈ SỐ SỨC KHỎE MÁY CHỦ (CPU, RAM, Event Loop, Uptime, DBPool) */}
      {healthLoading && !health && (
        <div className="flex items-center justify-center py-6 text-on-surface-variant">
          <span className="material-symbols-outlined animate-spin text-primary text-2xl mr-2">progress_activity</span>
          <span className="text-xs">{t('common.loading', 'Đang tải...')}</span>
        </div>
      )}

      {healthError && !health && (
        <div className="bg-amber-50 border border-amber-200/70 rounded-lg p-3 text-xs text-amber-800 space-y-1.5">
          <div className="flex items-center gap-1.5 font-semibold">
            <span className="material-symbols-outlined text-[16px] text-amber-600">info</span>
            <span>{healthError}</span>
          </div>
          <p className="text-[11px] text-amber-700/80">
            {t('serverHealth.hardwareNotice', 'Chức năng giám sát phần cứng và Uptime cần Backend hỗ trợ endpoint')} <code>/admin/system/health</code>.
          </p>
        </div>
      )}

      {health && (
        <>
          {/* CPU / RAM / Event Loop Gauges */}
          <div className="space-y-3">
            <Gauge label="CPU" value={cpu?.percent ?? 0} max={100} unit="%" warnAt={70} critAt={85} icon="memory_alt" />
            <Gauge label="RAM" value={ram?.usedMb ?? 0} max={ram?.totalMb ?? 100} unit="MB" warnAt={70} critAt={85} icon="storage" />
            <Gauge label="Event Loop" value={eventLoop?.lagMs ?? 0} max={200} unit="ms" warnAt={50} critAt={100} icon="speed" />
          </div>

          {/* Uptime Widget */}
          <UptimeWidget uptime={uptime} />

          {/* DB Pool & Load Shedding */}
          {dbPool && (
            <div className="bg-surface-container-low rounded-lg p-3 text-xs text-on-surface-variant space-y-1.5 border border-outline-variant/40">
              <p className="text-on-surface font-semibold mb-1 flex items-center gap-1">
                <span className="material-symbols-outlined text-[14px]">database</span>
                {t('serverHealth.dbPool', 'DB Pool & Cắt Tải (Bulkhead)')}
              </p>
              <div className="flex justify-between">
                <span>{t('serverHealth.clientPool', 'Client Pool:')}</span>
                <span className={`font-semibold ${dbPool.clientActive >= dbPool.clientLimit ? 'text-red-500' : 'text-emerald-600'}`}>
                  {dbPool.clientActive}/{dbPool.clientLimit}
                </span>
              </div>
              <div className="flex justify-between">
                <span>{t('serverHealth.adminPool', 'Admin Pool:')}</span>
                <span className="font-semibold text-on-surface">{dbPool.adminActive}/{dbPool.maxConnections - dbPool.clientLimit}</span>
              </div>
              {loadShedding && (
                <div className="flex justify-between text-gray-500">
                  <span>{t('serverHealth.loadShed', 'Load Shed (24h):')}</span>
                  <span className={`font-semibold ${loadShedding.shedCount24h > 0 ? 'text-amber-600' : 'text-gray-600'}`}>
                    {loadShedding.shedCount24h} {t('serverHealth.times', 'lần')}
                  </span>
                </div>
              )}
            </div>
          )}
        </>
      )}

      {/* KHỐI 2: CÔNG TẮC BẢO TRÌ KHẨN CẤP — LUÔN HOẠT ĐỘNG ĐỘC LẬP (CỬA THOÁT HIỂM) */}
      <div className={`rounded-lg p-3.5 border transition-all ${maintenance.active ? 'border-orange-300 bg-orange-50/90 shadow-xs' : 'border-outline-variant bg-surface-container-lowest'}`}>
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-1.5">
            <span className={`material-symbols-outlined text-[17px] ${maintenance.active ? 'text-orange-600 animate-bounce' : 'text-on-surface-variant'}`}>
              construction
            </span>
            <div>
              <p className="text-xs font-bold text-on-surface">{t('serverHealth.emergencyMaint', 'Bảo trì khẩn cấp')}</p>
              <p className="text-[10px] text-gray-400">{t('serverHealth.emergencyMaintDesc', 'Cắt toàn bộ Client, giữ Admin thông luồng')}</p>
            </div>
          </div>
          <button
            id="btn-maintenance-toggle"
            onClick={toggle}
            disabled={toggling || maintenanceLoading}
            className={`relative inline-flex h-5 w-10 items-center rounded-full transition-colors duration-200 cursor-pointer disabled:opacity-50 ${maintenance.active ? 'bg-orange-500 ring-2 ring-orange-300' : 'bg-gray-300'}`}
            title={maintenance.active ? t('serverHealth.toggleOffTitle', 'Bấm để tắt bảo trì') : t('serverHealth.toggleOnTitle', 'Bấm để bật bảo trì')}
          >
            <span className={`inline-block h-4 w-4 rounded-full bg-white shadow-sm transition-transform duration-200 ${maintenance.active ? 'translate-x-5' : 'translate-x-0.5'}`} />
          </button>
        </div>

        {!maintenance.active && (
          <div className="mt-2 space-y-1.5">
            <input
              type="text"
              placeholder={t('serverHealth.reasonPlaceholder', 'Nhập lý do bảo trì trước khi bật...')}
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              className="w-full text-xs bg-white text-on-surface border border-outline-variant rounded-md px-2.5 py-1.5 placeholder:text-gray-400 focus:outline-none focus:ring-1 focus:ring-primary shadow-2xs"
            />
          </div>
        )}

        {maintenance.active && (
          <div className={`text-xs rounded-md p-2 space-y-1 mt-2 border ${
            maintenance.isEmergency
              ? 'text-red-900 bg-red-100/80 border-red-300'
              : 'text-orange-900 bg-orange-100/70 border-orange-200'
          }`}>
            <p className="font-semibold flex items-center gap-1">
              <span className={`material-symbols-outlined text-[15px] ${maintenance.isEmergency ? 'text-red-700' : 'text-orange-700'}`}>
                {maintenance.isEmergency ? 'error' : 'warning'}
              </span>
              <span>
                {maintenance.isEmergency ? t('serverHealth.emergencyPrefix', 'Bảo trì khẩn cấp: ') : t('serverHealth.techPrefix', 'Bảo trì kỹ thuật: ')}
                {maintenance.reason || t('serverHealth.systemMaintaining', 'Hệ thống đang bảo trì')}
              </span>
            </p>
            {maintenance.activatedBy && (
              <p className="opacity-80 text-[11px]">
                {t('serverHealth.activatedBy', 'Kích hoạt bởi: ')}<b>{maintenance.activatedBy}</b>
                {maintenance.activatedAt && `${t('serverHealth.atTime', ' lúc ')}${new Date(maintenance.activatedAt).toLocaleTimeString('vi-VN')}`}
              </p>
            )}
          </div>
        )}

        {maintenance.scheduled && !maintenance.active && (
          <div className="text-[11px] text-blue-900 bg-blue-50 border border-blue-200 rounded-md p-2 mt-2 flex items-center justify-between">
            <span className="flex items-center gap-1">
              <span className="material-symbols-outlined text-[14px] text-blue-600">event</span>
              {t('serverHealth.scheduledMaint', 'Lịch bảo trì: ')}{new Date(maintenance.scheduled.scheduledAt).toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit' })}
            </span>
          </div>
        )}

        <div className="mt-2 text-right">
          <a href="/broadcast" className="text-[11px] text-primary hover:underline font-medium inline-flex items-center gap-0.5">
            {t('serverHealth.manageSchedule', 'Quản trị & Lên lịch bảo trì →')}
          </a>
        </div>
      </div>
    </div>
  );
};

export default ServerHealthPanel;
