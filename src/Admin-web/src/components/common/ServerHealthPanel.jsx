import React, { useCallback, useEffect, useId, useState } from 'react';
import { Link } from 'react-router-dom';
import adminApi from '../../api/admin.api';
import useSocket from '../../hooks/useSocket';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import { Badge, Button, Icon, SecurityConfirmModal, Spinner } from '../ui';

const REFRESH_MS = 60_000;

const normalizePool = (pool, prev) => {
  if (!pool) return prev;
  const clientLimit = pool.clientLimit ?? 16;
  return {
    clientActive: pool.clientActive ?? pool.activeClientConnections ?? 0,
    clientLimit,
    adminActive: pool.adminActive ?? pool.activeAdminConnections ?? 0,
    adminReserved: pool.adminReserved ?? (pool.maxConnections ? pool.maxConnections - clientLimit : 4),
  };
};

const toneOf = (pct, warnAt, critAt) => (pct >= critAt ? 'danger' : pct >= warnAt ? 'warning' : 'success');
const BAR = { danger: 'bg-danger', warning: 'bg-warning', success: 'bg-success' };
const TEXT = { danger: 'text-danger', warning: 'text-warning', success: 'text-success' };

const Gauge = ({ label, pct, detail, warnAt, critAt }) => {
  const value = Math.max(0, Math.round(Number(pct) || 0));
  const tone = toneOf(value, warnAt, critAt);
  return (
    <div>
      <div className="mb-1 flex items-center justify-between text-sm">
        <span className="font-medium text-ink">{label}</span>
        <span className={`tabular-nums ${TEXT[tone]}`}>{detail}</span>
      </div>
      <div role="progressbar" aria-label={label} aria-valuemin={0} aria-valuemax={100} aria-valuenow={value} className="h-2 overflow-hidden rounded-full bg-muted">
        <div className={`h-full rounded-full transition-all duration-500 ${BAR[tone]}`} style={{ width: `${Math.min(value, 100)}%` }} />
      </div>
    </div>
  );
};

const Row = ({ label, value, valueClass = 'text-ink' }) => (
  <div className="flex items-center justify-between gap-3 text-sm">
    <span className="text-ink-muted">{label}</span>
    <span className={`font-medium tabular-nums ${valueClass}`}>{value}</span>
  </div>
);

const formatStart = (iso) =>
  iso
    ? new Intl.DateTimeFormat('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh', day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date(iso))
    : '--';

const ServerHealthPanel = ({ uptimeData }) => {
  const { t } = useLanguageSafe();
  const notify = useAlertSafe();
  const reasonId = useId();
  const [health, setHealth] = useState(null);
  const [healthError, setHealthError] = useState(false);
  const [maintenance, setMaintenance] = useState({ active: false });
  const [maintenanceLoading, setMaintenanceLoading] = useState(true);
  const [reason, setReason] = useState('');
  const [reasonError, setReasonError] = useState(false);
  const [toggling, setToggling] = useState(false);
  const [pinOpen, setPinOpen] = useState(false);

  const fetchMaintenance = useCallback(async () => {
    try {
      const res = await adminApi.getMaintenanceStatus();
      const data = res?.data?.data || res?.data;
      if (data) setMaintenance({ ...data, active: Boolean(data.active), isEmergency: data.isEmergency !== false });
    } catch (_) {
      setMaintenance((prev) => prev);
    } finally {
      setMaintenanceLoading(false);
    }
  }, []);

  const fetchHealth = useCallback(async () => {
    try {
      const res = await adminApi.getSystemHealth();
      const data = res?.data?.data || res?.data;
      if (!data) {
        setHealthError(true);
        return;
      }
      setHealth((prev) => ({ ...prev, ...data, dbPool: normalizePool(data.dbPool, prev?.dbPool) }));
      setHealthError(false);
      if (data.maintenance) setMaintenance(data.maintenance);
    } catch (_) {
      setHealthError(true);
    }
  }, []);

  const refreshAll = useCallback(() => {
    fetchMaintenance();
    fetchHealth();
  }, [fetchMaintenance, fetchHealth]);

  useEffect(() => {
    refreshAll();
    const timer = setInterval(refreshAll, REFRESH_MS);
    return () => clearInterval(timer);
  }, [refreshAll]);

  const socket = useSocket();
  useEffect(() => {
    if (!socket) return undefined;
    const onMetrics = (data) => {
      if (!data) return;
      setHealth((prev) => ({
        ...prev,
        environment: data.environment || prev?.environment,
        uptime: {
          ...(prev?.uptime || {}),
          uptimeFormatted: data.uptimeFormatted || prev?.uptime?.uptimeFormatted,
          uptimePercent: typeof data.uptimePercent === 'number' ? data.uptimePercent : prev?.uptime?.uptimePercent ?? 100,
          downtimeSeconds: typeof data.downtimeSeconds === 'number' ? data.downtimeSeconds : prev?.uptime?.downtimeSeconds ?? 0,
        },
        cpu: { percent: data.cpuPercent, cores: data.cpuCores ?? prev?.cpu?.cores },
        ram: {
          percent: data.ramPercent,
          usedMb: data.ramUsedMb ?? prev?.ram?.usedMb ?? 0,
          totalMb: data.ramTotalMb ?? prev?.ram?.totalMb ?? 0,
        },
        eventLoop: { lagMs: data.eventLoopLagMs },
        dbPool: normalizePool(data.dbPool, prev?.dbPool),
        loadShedding: prev?.loadShedding,
      }));
      setHealthError(false);
      if (data.maintenance) setMaintenance(data.maintenance);
    };
    const onMaintenance = (state) => state && setMaintenance(state);
    socket.on('admin.metrics_stream', onMetrics);
    socket.on('admin.maintenance_changed', onMaintenance);
    return () => {
      socket.off('admin.metrics_stream', onMetrics);
      socket.off('admin.maintenance_changed', onMaintenance);
    };
  }, [socket]);

  const handleToggle = () => {
    if (!reason.trim()) {
      setReasonError(true);
      return;
    }
    setReasonError(false);
    setPinOpen(true);
  };

  const activate = async () => {
    setToggling(true);
    try {
      await adminApi.setMaintenanceStatus({ active: true, reason: reason.trim(), isEmergency: true });
      setMaintenance((prev) => ({ ...prev, active: true, isEmergency: true, reason: reason.trim(), activatedAt: new Date().toISOString() }));
      await fetchMaintenance();
    } catch (err) {
      if (notify) notify.error(err?.response?.data?.message || err?.message || t('serverHealth.toggleFailed'));
    } finally {
      setToggling(false);
    }
  };

  const env = health?.environment;
  const isCloud = env?.mode === 'cloud';
  const cpu = health?.cpu;
  const ram = health?.ram;
  const lag = health?.eventLoop?.lagMs ?? 0;
  const pool = health?.dbPool;
  const shed = health?.loadShedding;
  const uptime = uptimeData || health?.uptime;
  const uptimePct = Number(uptime?.uptimePercent ?? 0);
  const downtimeSec = Number(uptime?.downtimeSeconds ?? 0);
  const ramPct = ram?.totalMb ? (ram.usedMb / ram.totalMb) * 100 : ram?.percent ?? 0;
  const critical = lag > 100 || (cpu?.percent ?? 0) > 85 || ramPct > 85;
  const active = Boolean(maintenance.active);

  return (
    <section className="flex flex-col gap-4 rounded-xl border border-line bg-card p-5">
      <div className="flex items-center justify-between gap-2">
        <div className="flex min-w-0 items-center gap-2">
          <span className={`h-2.5 w-2.5 shrink-0 rounded-full ${critical ? 'bg-danger' : 'bg-success'}`} />
          <h2 className="m-0 text-base font-semibold text-ink">{t('serverHealth.title')}</h2>
          {env && <Badge tone={isCloud ? 'info' : 'neutral'}>{env.provider || (isCloud ? t('serverHealth.cloud') : t('serverHealth.host'))}</Badge>}
        </div>
        <Button variant="ghost" size="sm" icon="refresh" aria-label={t('serverHealth.refresh')} onClick={refreshAll} />
      </div>

      {!health && !healthError && (
        <div className="flex justify-center py-4 text-brand">
          <Spinner />
        </div>
      )}
      {!health && healthError && <p className="m-0 rounded-lg bg-warning-soft p-3 text-sm text-warning">{t('serverHealth.noData')}</p>}

      {health && (
        <>
          <div className="flex flex-col gap-3">
            <Gauge label="CPU" pct={cpu?.percent ?? 0} detail={`${cpu?.percent ?? 0}%${cpu?.cores ? ` · ${t('serverHealth.cores', { n: cpu.cores })}` : ''}`} warnAt={70} critAt={85} />
            <Gauge label="RAM" pct={ramPct} detail={ram?.totalMb ? `${Number(ram.usedMb).toLocaleString('vi-VN')} / ${Number(ram.totalMb).toLocaleString('vi-VN')} MB` : `${ram?.percent ?? 0}%`} warnAt={70} critAt={85} />
            <Gauge label={t('serverHealth.lag')} pct={(lag / 200) * 100} detail={`${lag} ms`} warnAt={25} critAt={50} />
          </div>

          <div className="flex flex-col gap-1.5 rounded-lg bg-muted p-3">
            <Row label={t('serverHealth.uptime')} value={uptime ? `${uptimePct.toFixed(2)}%` : '--'} valueClass={TEXT[uptimePct >= 99.5 ? 'success' : uptimePct >= 95 ? 'warning' : 'danger']} />
            {downtimeSec > 0 && (
              <Row
                label={t('serverHealth.downtime')}
                value={downtimeSec >= 3600 ? t('serverHealth.hours', { n: (downtimeSec / 3600).toFixed(1) }) : t('serverHealth.minutes', { n: Math.ceil(downtimeSec / 60) })}
                valueClass="text-warning"
              />
            )}
            {uptime?.uptimeFormatted && <Row label={t('serverHealth.runtime')} value={uptime.uptimeFormatted} />}
            {uptime?.startedAt && <Row label={t('serverHealth.startedAt')} value={formatStart(uptime.startedAt)} />}
          </div>

          {pool && (
            <div className="flex flex-col gap-1.5 rounded-lg bg-muted p-3">
              <Row label={t('serverHealth.clientPool')} value={`${pool.clientActive}/${pool.clientLimit}`} valueClass={pool.clientActive >= pool.clientLimit ? 'text-danger' : 'text-success'} />
              <Row label={t('serverHealth.adminPool')} value={`${pool.adminActive}/${pool.adminReserved}`} />
              {shed && <Row label={t('serverHealth.loadShed')} value={t('serverHealth.times', { n: shed.shedCount24h ?? 0 })} valueClass={shed.shedCount24h > 0 ? 'text-warning' : 'text-ink'} />}
            </div>
          )}
        </>
      )}

      <div className={`rounded-lg border p-3 ${active ? (maintenance.isEmergency ? 'border-danger bg-danger-soft' : 'border-warning bg-warning-soft') : 'border-line'}`}>
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <Icon name={active && maintenance.isEmergency ? 'crisis_alert' : 'construction'} className={active ? (maintenance.isEmergency ? 'text-danger' : 'text-warning') : 'text-ink-muted'} />
              <span id={`${reasonId}-switch`} className="text-sm font-semibold text-ink">{t('serverHealth.emergency')}</span>
              {active && <Badge tone={maintenance.isEmergency ? 'danger' : 'warning'}>{maintenance.isEmergency ? t('broadcast.banner.emergencyBadge') : t('broadcast.banner.silentBadge')}</Badge>}
            </div>
            <p className="m-0 mt-0.5 text-sm text-ink-muted">{t('serverHealth.emergencyDesc')}</p>
          </div>
          <button
            type="button"
            role="switch"
            aria-checked={active}
            aria-labelledby={`${reasonId}-switch`}
            onClick={handleToggle}
            disabled={active || toggling || maintenanceLoading}
            className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer items-center rounded-full transition-colors disabled:cursor-not-allowed disabled:opacity-60 ${active ? 'bg-danger' : 'bg-line'}`}
          >
            <span className={`inline-block h-5 w-5 rounded-full bg-card shadow transition-transform ${active ? 'translate-x-5' : 'translate-x-0.5'}`} />
          </button>
        </div>

        {!active && (
          <div className="mt-3">
            <label htmlFor={reasonId} className="mb-1 block text-sm font-medium text-ink">{t('serverHealth.reasonLabel')}</label>
            <input
              id={reasonId}
              type="text"
              value={reason}
              onChange={(e) => {
                setReason(e.target.value);
                if (reasonError) setReasonError(false);
              }}
              aria-invalid={reasonError}
              className={`h-9 w-full rounded-lg border bg-card px-3 text-sm text-ink focus:outline-none focus:ring-2 focus:ring-brand/20 ${reasonError ? 'border-danger' : 'border-line focus:border-brand'}`}
            />
            {reasonError && <p className="m-0 mt-1 text-sm text-danger">{t('serverHealth.reasonRequired')}</p>}
          </div>
        )}

        {active && (
          <div className="mt-3 text-sm text-ink">
            <p className="m-0">{maintenance.reason || t('serverHealth.noReason')}</p>
            {maintenance.activatedBy && (
              <p className="m-0 mt-0.5 text-ink-muted">
                {t('serverHealth.activatedBy', { name: maintenance.activatedBy })}
                {maintenance.activatedAt && ` · ${new Date(maintenance.activatedAt).toLocaleTimeString('vi-VN')}`}
              </p>
            )}
          </div>
        )}

        {maintenance.scheduled && !active && (
          <p className="m-0 mt-3 rounded-lg bg-info-soft p-2 text-sm text-info">
            {t('serverHealth.scheduledAt', {
              time: new Date(maintenance.scheduled.scheduledAt).toLocaleString('vi-VN', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit' }),
            })}
          </p>
        )}

        <div className="mt-3 text-right">
          <Link to="/broadcast" className="text-sm font-medium text-brand hover:underline">{t('serverHealth.manage')}</Link>
        </div>
      </div>

      <SecurityConfirmModal
        isOpen={pinOpen}
        onClose={() => setPinOpen(false)}
        actionType="EMERGENCY_MAINTENANCE"
        dangerLevel="critical"
        title={t('serverHealth.pinTitle')}
        description={t('serverHealth.pinDesc')}
        confirmText={t('serverHealth.pinConfirm')}
        onConfirm={activate}
      />
    </section>
  );
};

export default ServerHealthPanel;
