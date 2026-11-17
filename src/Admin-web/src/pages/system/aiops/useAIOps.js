import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import aiopsApi from '../../../api/aiops.api';
import adminApi from '../../../api/admin.api';
import useSocket from '../../../hooks/useSocket';
import { useAlertSafe } from '../../../store/alert.context';
import { useSettingsSafe } from '../../../store/settings.context';
import { useLanguageSafe } from '../../../store/language.context';
import useAuth from '../../../hooks/useAuth';
import { formatNumber } from '../../../utils/format';
import { maskIp } from './aiopsFormat';

const SCALE_KEY = 'aiops_target_concurrency';
// Tiêu đề / nội dung / nút của hộp PIN cho từng thao tác trên dòng khoá (khoá trong locales aiopsPage.quarantine).
const QUARANTINE_ACTIONS = {
  blockIp: { title: 'blockIpTitle', msg: 'blockIpMsg', confirm: 'blockIpConfirm' },
  extendIp: { title: 'extendIpTitle', msg: 'extendIpMsg', confirm: 'extendIpConfirm' },
  unblockIp: { title: 'unblockIpTitle', msg: 'unblockIpMsg', confirm: 'unblockConfirm' },
  blockAccount: { title: 'blockAccountTitle', msg: 'blockAccountMsg', confirm: 'blockIpConfirm' },
  banAccount: { title: 'banAccountTitle', msg: 'banAccountMsg', confirm: 'banAccountConfirm', danger: true },
  unblockAccount: { title: 'unblockAccountTitle', msg: 'unblockAccountMsg', confirm: 'unblockConfirm' },
};
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

const endOfRange = (to) => {
  const d = new Date(to);
  if (typeof to === 'string' && to.length === 10) d.setHours(23, 59, 59, 999);
  return d.getTime();
};

// Sự cố có thuộc trang đang xem không: cùng điều kiện lọc với Backend (aiops.repository.getIncidents).
const matchesIncidentView = (incident, s) => {
  if (s.incidentVector !== 'all' && incident.vector !== s.incidentVector) return false;
  if (s.incidentStatus !== 'all' && incident.status !== s.incidentStatus) return false;
  const q = String(s.incidentSearch || '').trim().toLowerCase();
  if (q) {
    const fields = [incident.actorIdentity ?? incident.actor_identity, incident.username, incident.code, incident.message];
    if (!fields.some((f) => String(f || '').toLowerCase().includes(q))) return false;
  }
  const custom = s.customRange;
  if (custom?.applied && custom.from && custom.to) {
    const at = new Date(incident.firstDetectedAt ?? incident.first_detected_at).getTime();
    if (Number.isNaN(at) || at < new Date(custom.from).getTime() || at > endOfRange(custom.to)) return false;
  }
  return true;
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
  const { t, language } = useLanguageSafe();
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

  const [incidents, setIncidents] = useState([]);
  const [incidentTotal, setIncidentTotal] = useState(0);
  const [incidentPage, setIncidentPage] = useState(1);
  const [incidentPageSize, setIncidentPageSize] = useState(5);
  const [incidentVector, setIncidentVector] = useState('all');
  const [incidentStatus, setIncidentStatus] = useState('all');
  const [incidentSearch, setIncidentSearch] = useState('');


  const latest = useRef({});
  latest.current = { timePreset, customRange, incidentPage, incidentPageSize, incidentVector, incidentStatus, incidentSearch };
  // Bản danh sách sự cố mới nhất, cập nhật ngay khi đổi (sự kiện realtime đến dồn trước khi kịp render).
  const incidentsRef = useRef([]);
  const applyIncidents = useCallback((next) => {
    incidentsRef.current = next;
    setIncidents(next);
  }, []);

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
      return true;
    } catch (_) {
      return false;
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
        applyIncidents(list);
        setIncidentTotal(data.total ?? list.length);
      }
      return true;
    } catch (_) {
      return false;
    }
  }, [applyIncidents]);

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
        indicators: d.indicators || prev?.indicators,
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
    // Backend phát cùng sự kiện cho sự cố mới (hits = 1, ACTIVE) và cho sự cố cũ đổi số lần / trạng thái.
    // Chỉ sự cố mới khớp bộ lọc mới làm tăng tổng; chỉ chèn khi đang xem trang 1.
    const onAnomaly = (incident) => {
      if (!incident) return;
      const view = latest.current;
      const list = incidentsRef.current;
      const i = list.findIndex((x) => x.id === incident.id);
      const matches = matchesIncidentView(incident, view);
      if (i >= 0) {
        if (matches) {
          const next = [...list];
          next[i] = { ...list[i], ...incident };
          applyIncidents(next);
        } else {
          applyIncidents(list.filter((x) => x.id !== incident.id));
          setIncidentTotal((n) => Math.max(0, n - 1));
        }
        return;
      }
      const isNew = Number(incident.hits) === 1 && incident.status === 'ACTIVE';
      if (!isNew || !matches) return;
      setIncidentTotal((n) => n + 1);
      if (view.incidentPage === 1) applyIncidents([incident, ...list].slice(0, view.incidentPageSize));
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
  }, [socket, notify, t, applyIncidents]);

  // Tải lại đúng trang và bộ lọc đang xem; báo theo kết quả thật của cả hai lần gọi.
  const handleManualRefresh = async () => {
    const [okData, okIncidents] = await Promise.all([fetchAIOpsData(), fetchIncidents()]);
    if (okData && okIncidents) notify(true, t('aiopsPage.feedback.refreshed'));
    else notify(false, t('aiopsPage.feedback.refreshFailed'));
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

  // ── Hộp PIN dùng chung: mọi thao tác ghi trên trang AIOps (mục 2.3) ──
  // run(credentials) gọi API kèm PIN; lỗi ném lại để hộp PIN hiện, thành công thì hộp tự đóng.
  const [pinRequest, setPinRequest] = useState(null);
  const closePinRequest = useCallback(() => setPinRequest(null), []);
  const friendlyError = (err, fallbackKey) => {
    if (err?.response?.data?.code === 'CANNOT_LOCK_SELF') return new Error(t('aiopsPage.feedback.cannotLockSelf'));
    if (err?.response?.data?.code === 'ROOT_ACCOUNT_PROTECTED') return new Error(t('aiopsPage.feedback.rootProtected'));
    if (err?.response?.data?.message || err?.message) return err;
    return new Error(t(fallbackKey));
  };
  const askPin = ({ run, errorKey, ...view }) =>
    setPinRequest({
      ...view,
      run: async (credentials) => {
        try {
          await run(credentials);
        } catch (err) {
          throw friendlyError(err, errorKey);
        }
      },
    });

  const handleApplyScale = (value) => {
    const n = parseInt(value ?? customConcurrency, 10);
    if (!validScale(n)) {
      notify(false, t('aiopsPage.feedback.scaleInvalid'));
      return;
    }
    askPin({
      title: t('aiopsPage.scale.pinTitle'),
      description: t('aiopsPage.scale.pinDesc', { n: formatNumber(n, {}, language) }),
      confirmText: t('aiopsPage.scale.apply'),
      errorKey: 'aiopsPage.feedback.scaleFailed',
      run: async (credentials) => {
        setSavingScale(true);
        try {
          const scaled = unwrap(await aiopsApi.setScale(n, credentials));
          setSelectedConcurrency(n);
          setCustomConcurrency(String(n));
          saveScale(n);
          setStatusData((prev) => ({ ...prev, targetConcurrency: n, indicators: scaled?.indicators || prev?.indicators }));
          notify(true, t('aiopsPage.feedback.scaleSaved', { n: formatNumber(n, {}, language) }));
        } finally {
          setSavingScale(false);
        }
      },
    });
  };

  const vectorScores = statusData?.vectorScores || DEFAULT_SCORES;
  const sample = statusData?.sample || {};
  const recommendedAction = statusData?.recommendedAction;
  const targetConcurrency = statusData?.targetConcurrency || selectedConcurrency || 1000;
  const myCurrentIp = cleanIp(statusData?.currentClientIp || currentUser?.currentClientIp);

  const indicators = statusData?.indicators || null;

  // Ngưỡng đang hiệu lực (Backend) hiện làm gợi ý trong hộp Hiệu chuẩn; Admin-web không tự tính.
  const currentThresholds = useMemo(() => {
    if (!indicators) return {};
    return {
      authFailureThreshold: indicators.auth?.failedLogins?.alert,
      trafficSpikeRps: indicators.traffic?.alertRpm ? Math.round(indicators.traffic.alertRpm / 60) : undefined,
      exploitLimit: indicators.exploit?.malformed?.alert,
      resourceCpuPercent: indicators.resource?.cpuPercent?.alert,
      resourceMemoryPercent: indicators.resource?.ramPercent?.alert,
      eventLoopLagMs: indicators.resource?.lagMs?.alert,
    };
  }, [indicators]);

  // Gửi lệnh hiệu chuẩn qua hộp PIN; Backend trả { success, data: báo cáo, status } (báo cáo nằm trong data).
  const runCalibrate = (payload, pinText) =>
    askPin({
      ...pinText,
      errorKey: 'aiopsPage.feedback.calibrateFailed',
      run: async (credentials) => {
        setCalibrating(true);
        try {
          const result = unwrap(await aiopsApi.calibrate(payload, credentials));
          const report = result?.data?.serverSpecs ? result.data : result?.serverSpecs ? result : null;
          if (report) setCalibrationReport(report);
          if (result?.status?.indicators) setStatusData((prev) => ({ ...prev, indicators: result.status.indicators }));
          setCustomThresholdsInput(EMPTY_THRESHOLDS);
          setShowCalibrateModal(false);
          notify(true, t(payload.resetThresholds ? 'aiopsPage.feedback.thresholdsReset' : 'aiopsPage.feedback.calibrated'));
          fetchAIOpsData();
        } finally {
          setCalibrating(false);
        }
      },
    });

  const handleCalibrate = () => {
    // Chỉ gửi ô đã nhập; ô trống để Backend giữ ngưỡng đang dùng.
    runCalibrate(
      {
        targetConcurrency: selectedConcurrency || 1000,
        customThresholds: Object.fromEntries(
          Object.keys(EMPTY_THRESHOLDS)
            .filter((key) => customThresholdsInput[key] !== '' && Number(customThresholdsInput[key]) > 0)
            .map((key) => [key, Number(customThresholdsInput[key])])
        ),
      },
      { title: t('aiopsPage.calibrate.pinTitle'), description: t('aiopsPage.calibrate.pinDesc'), confirmText: t('aiopsPage.calibrate.confirm') }
    );
  };

  // Về mặc định: Backend xoá mọi ngưỡng tuỳ chỉnh (resetThresholds), lưu lại và trả ngưỡng mặc định.
  const handleResetThresholds = () => {
    runCalibrate(
      { targetConcurrency: selectedConcurrency || 1000, resetThresholds: true },
      { title: t('aiopsPage.calibrate.resetPinTitle'), description: t('aiopsPage.calibrate.resetPinDesc'), confirmText: t('aiopsPage.calibrate.reset') }
    );
  };

  // PIN gửi kèm lệnh (máy chủ kiểm); lỗi, kể cả PIN sai, ném lại cho hộp PIN hiện.
  const handleTriggerMitigation = async (credentials) => {
    await adminApi.setMaintenanceStatus({
      active: true,
      reason: mitigationReason.trim() || t('aiopsPage.mitigation.defaultReason'),
      isEmergency: true,
      ...credentials,
    });
    notify(true, t('aiopsPage.feedback.mitigationOn'));
    setShowMitigationModal(false);
  };

  // Theo kết luận của Backend: khuyến nghị bảo trì khẩn cấp hoặc vectơ tài nguyên ở mức CRITICAL.
  const resourceDefenseStatus = statusData?.vectorDefenses?.resource?.status;
  const isEmergencyResourceRisk = useMemo(() => {
    if (vectorConfig.resource === false) return false;
    return recommendedAction === 'EMERGENCY_MAINTENANCE' || resourceDefenseStatus === 'CRITICAL';
  }, [recommendedAction, resourceDefenseStatus, vectorConfig.resource]);

  const toggleVector = (key, enabled) => {
    const name = t(`aiopsPage.vector.${key}`);
    askPin({
      title: t(enabled ? 'aiopsPage.vectorCard.enableTitle' : 'aiopsPage.vectorCard.disableTitle', { name }),
      description: t(enabled ? 'aiopsPage.vectorCard.enableMsg' : 'aiopsPage.vectorCard.disableMsg'),
      confirmText: t(enabled ? 'aiopsPage.vectorCard.enable' : 'aiopsPage.vectorCard.disable'),
      danger: !enabled,
      errorKey: 'aiopsPage.feedback.vectorFailed',
      run: async (credentials) => {
        const data = unwrap(await aiopsApi.toggleVector(key, enabled, credentials));
        setVectorConfig((prev) => data?.vectorConfig || { ...prev, [key]: enabled });
        if (data?.currentStatus) setStatusData((prev) => ({ ...prev, ...data.currentStatus }));
        notify(true, t(enabled ? 'aiopsPage.feedback.vectorOn' : 'aiopsPage.feedback.vectorOff', { name }));
      },
    });
  };

  const searchIncidents = () => {
    setIncidentPage(1);
    fetchIncidents({ incidentPage: 1 });
  };

  const blockFromIncident = (item) => {
    const identity = item.actor?.identity || item.actor_identity || item.actorIdentity || '';
    const hash = item.actor?.ipHash || item.actor_hash || item.actorHash;
    const code = item.code || 'INCIDENT';
    const label = identity ? maskIp(identity) : hash;
    askPin({
      title: t('aiopsPage.incidents.blockTitle', { ip: label }),
      description: t('aiopsPage.incidents.blockMsg'),
      confirmText: t('aiopsPage.incidents.block'),
      danger: true,
      errorKey: 'aiopsPage.feedback.blockFailed',
      run: async (credentials) => {
        await aiopsApi.quarantineActor(
          {
            hash,
            ip: identity && !identity.includes('xx') ? identity : null,
            maskedIp: identity,
            vector: item.vector || 'auth',
            reason: `Admin quarantine (${code})`,
            durationMinutes: 240,
          },
          credentials
        );
        notify(true, t('aiopsPage.feedback.blocked', { ip: identity || hash }));
        reloadQuarantine();
      },
    });
  };

  const reloadQuarantine = () =>
    Promise.resolve(aiopsApi.getQuarantineList())
      .then((res) => {
        const list = unwrap(res);
        if (Array.isArray(list)) setQuarantineList(list);
      })
      .catch(() => undefined);

  // Thao tác trên một dòng khoá: hỏi PIN, gọi API, rồi tải lại danh sách từ máy chủ (danh sách lấy từ CSDL).
  const rowAction = (kind, target, call, okMsg, errorKey) => {
    const meta = QUARANTINE_ACTIONS[kind];
    askPin({
      title: t(`aiopsPage.quarantine.${meta.title}`, { target }),
      description: t(`aiopsPage.quarantine.${meta.msg}`),
      confirmText: t(`aiopsPage.quarantine.${meta.confirm}`),
      danger: Boolean(meta.danger),
      errorKey,
      run: async (credentials) => {
        await call(credentials);
        notify(true, okMsg);
        await reloadQuarantine();
      },
    });
  };

  const quarantineActions = {
    blockIp: (hash, masked) =>
      rowAction('blockIp', masked, (c) => aiopsApi.temporaryBlockIp({ ipHash: hash }, c), t('aiopsPage.feedback.ipLocked', { ip: masked }), 'aiopsPage.feedback.ipFailed'),
    extendIp: (hash, masked) =>
      rowAction('extendIp', masked, (c) => aiopsApi.extendIp({ ipHash: hash }, c), t('aiopsPage.feedback.ipLocked', { ip: masked }), 'aiopsPage.feedback.ipFailed'),
    unblockIp: (hash, masked) =>
      rowAction('unblockIp', masked, (c) => aiopsApi.unblockIp({ ipHash: hash }, c), t('aiopsPage.feedback.ipUnlocked', { ip: masked || '' }), 'aiopsPage.feedback.ipFailed'),
    blockAccount: (username, idaccount) =>
      rowAction('blockAccount', username || idaccount, (c) => aiopsApi.temporaryBlockAccount({ username, idaccount }, c), t('aiopsPage.feedback.accountLocked', { name: username || idaccount }), 'aiopsPage.feedback.accountFailed'),
    banAccount: (username, idaccount) =>
      rowAction('banAccount', username || idaccount, (c) => aiopsApi.permanentBanAccount({ username, idaccount }, c), t('aiopsPage.feedback.accountBanned', { name: username || idaccount }), 'aiopsPage.feedback.accountFailed'),
    unblockAccount: (username, idaccount) =>
      rowAction('unblockAccount', username || idaccount, (c) => aiopsApi.unblockAccount({ username, idaccount }, c), t('aiopsPage.feedback.accountUnlocked', { name: username || idaccount }), 'aiopsPage.feedback.accountFailed'),
  };

  // Khoá thủ công: kiểm dữ liệu nhập, hỏi PIN, rồi gọi API; onDone đóng hộp nhập khi thành công.
  // Admin được khoá cả IP mình đang dùng (Chủ dự án chốt 2026-11-16); chỉ IP máy chủ là không khoá được.
  const manualQuarantine = ({ targetType, ipValue, accountValue, reason, durationMinutes }, onDone) => {
    const minutes = parseInt(durationMinutes, 10) || 240;
    const ip = cleanIp(ipValue);
    const username = String(accountValue || '').trim();
    if (targetType === 'ip' && !ip) return notify(false, t('aiopsPage.feedback.ipRequired'));
    if (targetType === 'ip' && isLoopback(ip)) return notify(false, t('aiopsPage.feedback.protectedSelf'));
    if (targetType !== 'ip' && !username) return notify(false, t('aiopsPage.feedback.accountRequired'));
    askPin({
      title: t('aiopsPage.manual.pinTitle'),
      description: targetType === 'ip' ? ip : username,
      confirmText: t('aiopsPage.manual.submit'),
      danger: true,
      errorKey: targetType === 'ip' ? 'aiopsPage.feedback.ipFailed' : 'aiopsPage.feedback.accountFailed',
      run: async (credentials) => {
        if (targetType === 'ip') {
          await aiopsApi.quarantineActor({ ip, reason: reason || t('aiopsPage.manual.defaultReason'), durationMinutes: minutes, vector: 'auth' }, credentials);
          notify(true, t('aiopsPage.feedback.ipLocked', { ip }));
        } else {
          await aiopsApi.temporaryBlockAccount({ username, durationMinutes: minutes }, credentials);
          notify(true, t('aiopsPage.feedback.accountLocked', { name: username }));
        }
        if (typeof onDone === 'function') onDone();
        fetchAIOpsData();
      },
    });
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
    currentThresholds,
    indicators,
    calibrating,
    calibrationReport,
    handleCalibrate,
    handleResetThresholds,
    showMitigationModal,
    setShowMitigationModal,
    mitigationReason,
    setMitigationReason,
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
    quarantineActions,
    manualQuarantine,
    pinRequest,
    closePinRequest,
  };
};

export default useAIOps;
