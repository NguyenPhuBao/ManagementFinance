import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import aiopsApi from '../../../api/aiops.api';
import adminApi from '../../../api/admin.api';
import useSocket from '../../../hooks/useSocket';
import { useAlertSafe } from '../../../store/alert.context';
import { useSettingsSafe } from '../../../store/settings.context';
import { useLanguageSafe } from '../../../store/language.context';
import useAuth from '../../../hooks/useAuth';

const SCALE_KEY = 'aiops_target_concurrency';
const FOUR_HOURS_MS = 4 * 60 * 60 * 1000;
const DEFAULT_SCORES = { auth: 0, traffic: 0, exploit: 0, resource: 0 };
const EMPTY_THRESHOLDS = {
  authFailureThreshold: '',
  trafficSpikeRps: '',
  exploitLimit: '',
  resourceCpuPercent: '',
  resourceMemoryPercent: '',
  eventLoopLagMs: '',
};

const unwrap = (res) => res?.data ?? res;
const rangeOf = (preset, custom) => (custom?.applied && custom.from && custom.to ? { from: custom.from, to: custom.to } : { range: preset });
const validScale = (n) => n >= 100 && n <= 50000;

const readSavedScale = () => {
  try {
    const n = parseInt(localStorage.getItem(SCALE_KEY), 10);
    return validScale(n) ? n : 1000;
  } catch (_) {
    return 1000;
  }
};

const saveScale = (n) => {
  try {
    localStorage.setItem(SCALE_KEY, String(n));
  } catch (_) {
    return undefined;
  }
  return undefined;
};

const isLoopback = (ip) => ['127.0.0.1', '::1', 'localhost'].includes(ip);
const cleanIp = (ip) => String(ip || '').replace(/^::ffff:/, '').trim();

const useCurrentUser = () => {
  try {
    return useAuth()?.user || null;
  } catch (_) {
    return null;
  }
};

const useAIOps = () => {
  const { t } = useLanguageSafe();
  const alert = useAlertSafe();
  const settingsCtx = useSettingsSafe();
  const currentUser = useCurrentUser();
  const socket = useSocket();

  const [statusData, setStatusData] = useState(null);
  const [historyData, setHistoryData] = useState([]);
  const [quarantineList, setQuarantineList] = useState([]);
  const [vectorConfig, setVectorConfig] = useState({ auth: true, traffic: true, exploit: true, resource: true });
  const [maintenanceStatus, setMaintenanceStatus] = useState({ active: false });
  const [loading, setLoading] = useState(true);
  const [fetchingHistory, setFetchingHistory] = useState(false);

  const [timePreset, setTimePreset] = useState('10m');
  const [customRange, setCustomRange] = useState({ from: '', to: '', applied: false });
  const [activeVectorTab, setActiveVectorTab] = useState('all');

  const [selectedConcurrency, setSelectedConcurrency] = useState(readSavedScale);
  const [customConcurrency, setCustomConcurrency] = useState(() => String(readSavedScale()));
  const [savingScale, setSavingScale] = useState(false);

  const [showCalibrateModal, setShowCalibrateModal] = useState(false);
  const [customThresholdsInput, setCustomThresholdsInput] = useState(EMPTY_THRESHOLDS);
  const [calibrating, setCalibrating] = useState(false);
  const [calibrationReport, setCalibrationReport] = useState(null);

  const [showMitigationModal, setShowMitigationModal] = useState(false);
  const [mitigationReason, setMitigationReason] = useState(() => t('aiopsPage.mitigation.defaultReason'));
  const [mitigating, setMitigating] = useState(false);

  const [incidents, setIncidents] = useState([]);
  const [incidentTotal, setIncidentTotal] = useState(0);
  const [incidentPage, setIncidentPage] = useState(1);
  const [incidentPageSize, setIncidentPageSize] = useState(5);
  const [incidentVector, setIncidentVector] = useState('all');
  const [incidentStatus, setIncidentStatus] = useState('all');
  const [incidentSearch, setIncidentSearch] = useState('');

  const [actionLoading, setActionLoading] = useState(null);

  const latest = useRef({});
  latest.current = { timePreset, customRange, incidentPage, incidentPageSize, incidentVector, incidentStatus, incidentSearch };

  const notify = useCallback(
    (ok, msg) => {
      if (!alert || !msg) return;
      if (ok) alert.success(msg);
      else alert.error(msg);
    },
    [alert]
  );
  const errorOf = (err, key, params) => err?.response?.data?.message || err?.message || t(key, params);

  const fetchAIOpsData = useCallback(async () => {
    const { timePreset: preset, customRange: custom } = latest.current;
    try {
      const [statusRes, historyRes, quarantineRes, maintenanceRes, vectorRes] = await Promise.all([
        aiopsApi.getStatus(),
        aiopsApi.getHistory(rangeOf(preset, custom)),
        aiopsApi.getQuarantineList(),
        adminApi.getMaintenanceStatus(),
        Promise.resolve(typeof aiopsApi.getVectorConfig === 'function' ? aiopsApi.getVectorConfig() : null).catch(() => null),
      ]);
      const status = unwrap(statusRes);
      const history = unwrap(historyRes);
      const quarantine = unwrap(quarantineRes);
      const maintenance = unwrap(maintenanceRes);
      const vectors = unwrap(vectorRes);
      if (maintenance) setMaintenanceStatus(maintenance);
      if (vectors && typeof vectors === 'object' && vectors.auth !== undefined) setVectorConfig(vectors);
      else if (status?.vectorConfig) setVectorConfig(status.vectorConfig);
      if (status) {
        setStatusData(status);
        if (validScale(status.targetConcurrency)) {
          setSelectedConcurrency(status.targetConcurrency);
          setCustomConcurrency(String(status.targetConcurrency));
          saveScale(status.targetConcurrency);
        }
      }
      if (Array.isArray(history)) setHistoryData(history);
      if (Array.isArray(quarantine)) setQuarantineList(quarantine);
    } catch (_) {
      setLoading(false);
    } finally {
      setLoading(false);
    }
  }, []);

  const fetchHistory = useCallback(
    async ({ preset, custom } = {}) => {
      const state = latest.current;
      setFetchingHistory(true);
      try {
        const history = unwrap(await aiopsApi.getHistory(rangeOf(preset ?? state.timePreset, custom ?? state.customRange)));
        if (Array.isArray(history)) setHistoryData(history);
      } catch (_) {
        notify(false, t('aiopsPage.feedback.historyFailed'));
      } finally {
        setFetchingHistory(false);
      }
    },
    [notify, t]
  );

  const fetchIncidents = useCallback(async (overrides = {}) => {
    const s = { ...latest.current, ...overrides };
    try {
      const data = unwrap(
        await aiopsApi.getIncidents({
          page: s.incidentPage,
          limit: s.incidentPageSize,
          vector: s.incidentVector,
          status: s.incidentStatus,
          search: s.incidentSearch,
          ...rangeOf(s.timePreset, s.customRange),
        })
      );
      const list = data?.incidents || data?.data || (Array.isArray(data) ? data : null);
      if (Array.isArray(list)) {
        setIncidents(list);
        setIncidentTotal(data.total ?? list.length);
      }
    } catch (_) {
      setIncidents((prev) => prev);
    }
  }, []);

  const metricsInterval = settingsCtx?.settings?.metricsInterval || 3;
  useEffect(() => {
    fetchAIOpsData();
    const timer = setInterval(fetchAIOpsData, Math.max(1000, metricsInterval * 1000));
    return () => clearInterval(timer);
  }, [fetchAIOpsData, metricsInterval]);

  useEffect(() => {
    fetchIncidents();
  }, [fetchIncidents, incidentPage, incidentPageSize, incidentVector, incidentStatus]);

  useEffect(() => {
    if (!socket) return undefined;
    const onMetrics = (m) => {
      if (!m) return;
      if (m.vectorConfig) setVectorConfig(m.vectorConfig);
      setStatusData((prev) => ({
        ...prev,
        threatScore: m.threatScore ?? prev?.threatScore ?? 0,
        status: m.threatStatus || prev?.status || 'NORMAL',
        vectorScores: m.vectorScores || prev?.vectorScores || DEFAULT_SCORES,
        vectorDefenses: m.vectorDefenses || prev?.vectorDefenses || {},
        recommendedAction: m.recommendedAction || prev?.recommendedAction || null,
        targetConcurrency: validScale(m.targetConcurrency) ? m.targetConcurrency : prev?.targetConcurrency,
        sample: {
          ...(prev?.sample || {}),
          cpuPercent: m.cpuPercent,
          cpuCores: m.cpuCores ?? prev?.sample?.cpuCores,
          ramPercent: m.ramPercent,
          ramUsedMb: m.ramUsedMb ?? prev?.sample?.ramUsedMb,
          ramTotalMb: m.ramTotalMb ?? prev?.sample?.ramTotalMb,
          eventLoopLagMs: m.eventLoopLagMs,
          requestsPerMin: m.requestsPerMin,
        },
        lastEvaluatedAt: m.timestamp,
      }));
    };
    const onAlert = (d) => {
      if (!d) return;
      if (d.vectorConfig) setVectorConfig(d.vectorConfig);
      setStatusData((prev) => ({
        ...prev,
        threatScore: d.threatScore,
        status: d.status,
        vectorScores: d.vectorScores || prev?.vectorScores || DEFAULT_SCORES,
        vectorDefenses: d.vectorDefenses || prev?.vectorDefenses || {},
        anomalies: d.anomalies,
        recommendedAction: d.recommendedAction,
        sample: d.sample || prev?.sample,
        lastEvaluatedAt: d.timestamp,
      }));
    };
    const onBlocked = (b) => {
      if (!b) return;
      notify(false, t('aiopsPage.feedback.autoBlocked', { ip: b.maskedIp, reason: b.reason }));
      setQuarantineList((prev) => [b, ...prev.filter((x) => x.hash !== b.hash)]);
    };
    const onQuarantineUpdated = () => {
      Promise.resolve(aiopsApi.getQuarantineList())
        .then((res) => {
          const list = unwrap(res);
          if (Array.isArray(list)) setQuarantineList(list);
        })
        .catch(() => undefined);
    };
    const onAnomaly = (incident) => {
      if (!incident) return;
      setIncidents((prev) => {
        const i = prev.findIndex((x) => x.id === incident.id);
        if (i < 0) return [incident, ...prev];
        const next = [...prev];
        next[i] = incident;
        return next;
      });
      setIncidentTotal((n) => n + 1);
    };
    const onMaintenance = (m) => m && setMaintenanceStatus(m);
    const onVectorConfig = (c) => c && setVectorConfig(c);
    const handlers = {
      'admin.metrics_stream': onMetrics,
      'admin.security_alert': onAlert,
      'admin.security_blocked': onBlocked,
      'admin.quarantine_updated': onQuarantineUpdated,
      'admin.anomaly_detected': onAnomaly,
      'admin.maintenance_changed': onMaintenance,
      'admin.vector_config_changed': onVectorConfig,
    };
    Object.entries(handlers).forEach(([name, fn]) => socket.on(name, fn));
    return () => Object.entries(handlers).forEach(([name, fn]) => socket.off(name, fn));
  }, [socket, notify, t]);

  const handleManualRefresh = async () => {
    try {
      await fetchAIOpsData();
      await fetchIncidents({ incidentPage: 1 });
      notify(true, t('aiopsPage.feedback.refreshed'));
    } catch (_) {
      notify(false, t('aiopsPage.feedback.refreshFailed'));
    }
  };

  const handleSelectTimePreset = (preset) => {
    const custom = { ...customRange, applied: false };
    setTimePreset(preset);
    setCustomRange(custom);
    fetchHistory({ preset, custom });
    fetchIncidents({ incidentPage: 1, timePreset: preset, customRange: custom });
  };

  const handleApplyCustomRange = () => {
    if (!customRange.from || !customRange.to) {
      notify(false, t('aiopsPage.feedback.rangeMissing'));
      return;
    }
    if (customRange.from > customRange.to) {
      notify(false, t('aiopsPage.feedback.rangeInvalid'));
      return;
    }
    const custom = { ...customRange, applied: true };
    setCustomRange(custom);
    fetchHistory({ custom });
    fetchIncidents({ incidentPage: 1, customRange: custom });
  };

  const handleClearCustomRange = () => {
    const custom = { from: '', to: '', applied: false };
    setCustomRange(custom);
    fetchHistory({ custom });
    fetchIncidents({ incidentPage: 1, customRange: custom });
  };

  const handleApplyScale = async (value) => {
    const n = parseInt(value ?? customConcurrency, 10);
    if (!validScale(n)) {
      notify(false, t('aiopsPage.feedback.scaleInvalid'));
      return;
    }
    setSavingScale(true);
    try {
      await aiopsApi.setScale(n);
      setSelectedConcurrency(n);
      setCustomConcurrency(String(n));
      saveScale(n);
      setStatusData((prev) => ({ ...prev, targetConcurrency: n }));
      notify(true, t('aiopsPage.feedback.scaleSaved', { n: n.toLocaleString('vi-VN') }));
    } catch (err) {
      notify(false, errorOf(err, 'aiopsPage.feedback.scaleFailed'));
    } finally {
      setSavingScale(false);
    }
  };

  const vectorScores = statusData?.vectorScores || DEFAULT_SCORES;
  const sample = statusData?.sample || {};
  const recommendedAction = statusData?.recommendedAction;
  const targetConcurrency = statusData?.targetConcurrency || selectedConcurrency || 1000;
  const myCurrentIp = cleanIp(statusData?.currentClientIp || currentUser?.currentClientIp);

  const autoRecommendedThresholds = useMemo(() => {
    const n = Math.max(100, Number(selectedConcurrency || statusData?.targetConcurrency || 1000));
    return {
      authFailureThreshold: Math.max(20, Math.round(15 + 10 * Math.log10(n / 100))),
      trafficSpikeRps: Math.max(50, Math.round(n / 2)),
      exploitLimit: 8,
      resourceCpuPercent: 85,
      resourceMemoryPercent: 85,
      eventLoopLagMs: 100,
    };
  }, [selectedConcurrency, statusData?.targetConcurrency]);

  const handleCalibrate = async () => {
    setCalibrating(true);
    const pick = (value, fallback) => (value !== '' && Number(value) > 0 ? Number(value) : fallback);
    try {
      const res = await aiopsApi.calibrate({
        targetConcurrency: selectedConcurrency || 1000,
        customThresholds: Object.fromEntries(
          Object.keys(EMPTY_THRESHOLDS).map((key) => [key, pick(customThresholdsInput[key], autoRecommendedThresholds[key])])
        ),
      });
      const report = unwrap(res);
      if (report?.serverSpecs) setCalibrationReport(report);
      setShowCalibrateModal(false);
      notify(true, t('aiopsPage.feedback.calibrated'));
      await fetchAIOpsData();
    } catch (err) {
      notify(false, errorOf(err, 'aiopsPage.feedback.calibrateFailed'));
    } finally {
      setCalibrating(false);
    }
  };

  const handleTriggerMitigation = async () => {
    setMitigating(true);
    try {
      await adminApi.setMaintenanceStatus({ active: true, reason: mitigationReason.trim() || t('aiopsPage.mitigation.defaultReason'), isEmergency: true });
      notify(true, t('aiopsPage.feedback.mitigationOn'));
      setShowMitigationModal(false);
    } catch (err) {
      notify(false, errorOf(err, 'aiopsPage.feedback.mitigationFailed'));
    } finally {
      setMitigating(false);
    }
  };

  const isEmergencyResourceRisk = useMemo(() => {
    if (vectorConfig.resource === false) return false;
    return (
      recommendedAction === 'EMERGENCY_MAINTENANCE' ||
      vectorScores.resource >= 85 ||
      (vectorScores.resource >= 70 && (sample.errorRate5xx || 0) >= 0.15 && (sample.eventLoopLagMs || 0) >= 250)
    );
  }, [recommendedAction, vectorScores.resource, sample.errorRate5xx, sample.eventLoopLagMs, vectorConfig.resource]);

  const toggleVector = async (key, enabled) => {
    const name = t(`aiopsPage.vector.${key}`);
    try {
      const data = unwrap(await aiopsApi.toggleVector(key, enabled));
      setVectorConfig(data?.vectorConfig || { ...vectorConfig, [key]: enabled });
      if (data?.currentStatus) setStatusData((prev) => ({ ...prev, ...data.currentStatus }));
      notify(true, t(enabled ? 'aiopsPage.feedback.vectorOn' : 'aiopsPage.feedback.vectorOff', { name }));
      return true;
    } catch (err) {
      notify(false, errorOf(err, 'aiopsPage.feedback.vectorFailed'));
      return false;
    }
  };

  const searchIncidents = () => {
    setIncidentPage(1);
    fetchIncidents({ incidentPage: 1 });
  };

  const blockFromIncident = async (item) => {
    const identity = item.actor?.identity || item.actor_identity || item.actorIdentity || '';
    const hash = item.actor?.ipHash || item.actor_hash || item.actorHash;
    const code = item.code || 'INCIDENT';
    try {
      const data = unwrap(
        await aiopsApi.quarantineActor({
          hash,
          ip: identity && !identity.includes('xx') ? identity : null,
          maskedIp: identity,
          vector: item.vector || 'auth',
          reason: `Admin quarantine (${code})`,
          durationMinutes: 240,
        })
      );
      notify(true, t('aiopsPage.feedback.blocked', { ip: identity || hash }));
      setQuarantineList((prev) => {
        const key = data?.hash || hash;
        if (prev.some((x) => x.hash === key)) return prev;
        return [
          {
            hash: key,
            ipHash: key,
            maskedIp: data?.maskedIp || identity,
            vector: data?.vector || item.vector || 'auth',
            reason: data?.reason || `Admin quarantine (${code})`,
            bannedAt: data?.bannedAt || new Date().toISOString(),
            ipStatus: 'temporary',
            ipExpiresAt: new Date(Date.now() + FOUR_HOURS_MS).toISOString(),
            hits: data?.hits || 1,
          },
          ...prev,
        ];
      });
      return true;
    } catch (err) {
      notify(false, errorOf(err, 'aiopsPage.feedback.blockFailed'));
      return false;
    }
  };

  const runAction = async (key, call, update, okMsg, errKey) => {
    setActionLoading(key);
    try {
      await call();
      setQuarantineList((prev) => prev.map(update));
      notify(true, okMsg);
      return true;
    } catch (err) {
      notify(false, errorOf(err, errKey));
      return false;
    } finally {
      setActionLoading(null);
    }
  };

  const sameIp = (hash) => (item) => item.ipHash === hash || item.hash === hash;
  const sameAccount = (username, idaccount) => (item) => item.username === username || (idaccount && item.idaccount === idaccount);
  const lockIpUntil = () => ({ ipStatus: 'temporary', ipExpiresAt: new Date(Date.now() + FOUR_HOURS_MS).toISOString(), ipRemainingMinutes: 240 });

  const quarantineActions = {
    blockIp: (hash, masked) =>
      runAction(`ip:${hash}`, () => aiopsApi.temporaryBlockIp({ ipHash: hash }), (x) => (sameIp(hash)(x) ? { ...x, ...lockIpUntil() } : x), t('aiopsPage.feedback.ipLocked', { ip: masked }), 'aiopsPage.feedback.ipFailed'),
    extendIp: (hash, masked) =>
      runAction(`ip:${hash}`, () => aiopsApi.permanentBanIp({ ipHash: hash }), (x) => (sameIp(hash)(x) ? { ...x, ...lockIpUntil() } : x), t('aiopsPage.feedback.ipLocked', { ip: masked }), 'aiopsPage.feedback.ipFailed'),
    unblockIp: (hash, masked) =>
      runAction(
        `ip:${hash}`,
        () => aiopsApi.unblockIp({ ipHash: hash }),
        (x) => (sameIp(hash)(x) ? { ...x, ipStatus: 'unlocked', ipExpiresAt: null, ipRemainingMinutes: null } : x),
        t('aiopsPage.feedback.ipUnlocked', { ip: masked || '' }),
        'aiopsPage.feedback.ipFailed'
      ),
    blockAccount: (username, idaccount) =>
      runAction(
        `acc:${username || idaccount}`,
        () => aiopsApi.temporaryBlockAccount({ username, idaccount }),
        (x) => (sameAccount(username, idaccount)(x) ? { ...x, accountStatus: 'temporary', accountExpiresAt: new Date(Date.now() + FOUR_HOURS_MS).toISOString(), accountRemainingMinutes: 240 } : x),
        t('aiopsPage.feedback.accountLocked', { name: username || idaccount }),
        'aiopsPage.feedback.accountFailed'
      ),
    banAccount: (username, idaccount) =>
      runAction(
        `acc:${username || idaccount}`,
        () => aiopsApi.permanentBanAccount({ username, idaccount }),
        (x) => (sameAccount(username, idaccount)(x) ? { ...x, accountStatus: 'permanent', accountExpiresAt: null, accountRemainingMinutes: null } : x),
        t('aiopsPage.feedback.accountBanned', { name: username || idaccount }),
        'aiopsPage.feedback.accountFailed'
      ),
    unblockAccount: (username, idaccount) =>
      runAction(
        `acc:${username || idaccount}`,
        () => aiopsApi.unblockAccount({ username, idaccount }),
        (x) => (sameAccount(username, idaccount)(x) ? { ...x, accountStatus: 'unlocked', accountExpiresAt: null, accountRemainingMinutes: null } : x),
        t('aiopsPage.feedback.accountUnlocked', { name: username || idaccount }),
        'aiopsPage.feedback.accountFailed'
      ),
  };

  const manualQuarantine = async ({ targetType, ipValue, accountValue, reason, durationMinutes }) => {
    const minutes = parseInt(durationMinutes, 10) || 240;
    try {
      if (targetType === 'ip') {
        const ip = cleanIp(ipValue);
        if (!ip) {
          notify(false, t('aiopsPage.feedback.ipRequired'));
          return false;
        }
        if (isLoopback(ip) || (myCurrentIp && ip === myCurrentIp)) {
          notify(false, t('aiopsPage.feedback.protectedSelf'));
          return false;
        }
        await aiopsApi.quarantineActor({ ip, reason: reason || t('aiopsPage.manual.defaultReason'), durationMinutes: minutes, vector: 'auth' });
        notify(true, t('aiopsPage.feedback.ipLocked', { ip }));
      } else {
        const username = String(accountValue || '').trim();
        if (!username) {
          notify(false, t('aiopsPage.feedback.accountRequired'));
          return false;
        }
        await aiopsApi.temporaryBlockAccount({ username, durationMinutes: minutes });
        notify(true, t('aiopsPage.feedback.accountLocked', { name: username }));
      }
      await fetchAIOpsData();
      return true;
    } catch (err) {
      notify(false, errorOf(err, targetType === 'ip' ? 'aiopsPage.feedback.ipFailed' : 'aiopsPage.feedback.accountFailed'));
      return false;
    }
  };

  return {
    t,
    loading,
    statusData,
    sample,
    vectorScores,
    vectorConfig,
    maintenanceStatus,
    historyData,
    quarantineList,
    myCurrentIp,
    notify,
    timePreset,
    customRange,
    setCustomRange,
    activeVectorTab,
    setActiveVectorTab,
    fetchingHistory,
    handleSelectTimePreset,
    handleApplyCustomRange,
    handleClearCustomRange,
    handleManualRefresh,
    targetConcurrency,
    customConcurrency,
    setCustomConcurrency,
    savingScale,
    handleApplyScale,
    showCalibrateModal,
    setShowCalibrateModal,
    customThresholdsInput,
    setCustomThresholdsInput,
    autoRecommendedThresholds,
    calibrating,
    calibrationReport,
    handleCalibrate,
    showMitigationModal,
    setShowMitigationModal,
    mitigationReason,
    setMitigationReason,
    mitigating,
    handleTriggerMitigation,
    isEmergencyResourceRisk,
    toggleVector,
    incidents,
    incidentTotal,
    incidentPage,
    setIncidentPage,
    incidentPageSize,
    setIncidentPageSize,
    incidentVector,
    setIncidentVector,
    incidentStatus,
    setIncidentStatus,
    incidentSearch,
    setIncidentSearch,
    searchIncidents,
    blockFromIncident,
    actionLoading,
    quarantineActions,
    manualQuarantine,
  };
};

export default useAIOps;
