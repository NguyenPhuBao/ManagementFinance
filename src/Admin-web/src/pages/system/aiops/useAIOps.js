import { useState, useEffect, useMemo, useRef } from 'react';
import aiopsApi from '../../../api/aiops.api';
import adminApi from '../../../api/admin.api';
import useSocket from '../../../hooks/useSocket';
import { useAlertSafe } from '../../../store/alert.context';
import { useSettingsSafe } from '../../../store/settings.context';
import { useLanguageSafe } from '../../../store/language.context';
import useAuth from '../../../hooks/useAuth';

const useAIOps = () => {
  const { t } = useLanguageSafe();
  const alert = useAlertSafe();
  const settingsCtx = useSettingsSafe();
  let currentUser = null;
  try {
    const auth = useAuth();
    currentUser = auth?.user || null;
  } catch (_) {}
  const [statusData, setStatusData] = useState(null);
  const myCurrentIp = statusData?.currentClientIp || currentUser?.currentClientIp || '';
  const [historyData, setHistoryData] = useState([]);
  const [quarantineList, setQuarantineList] = useState([]);
  const [loading, setLoading] = useState(true);


  const [calibrating, setCalibrating] = useState(false);
  const [unblockingHash, setUnblockingHash] = useState(null);
  const [feedback, _setFeedback] = useState(null);

  const setFeedback = (fb) => {
    _setFeedback(fb);
    if (fb && alert) {
      if (fb.ok) {
        alert.success(fb.msg, t('aiops.alerts.sentinelTitle', 'AIOps Sentinel'));
      } else {
        alert.error(fb.msg, t('aiops.alerts.warningTitle', 'Cảnh Báo AIOps'));
      }
    }
  };

  const [maintenanceStatus, setMaintenanceStatus] = useState({
    active: false,
    isEmergency: false,
    reason: '',
    activatedBy: null,
    activatedAt: null,
  });

  const [showMitigationModal, setShowMitigationModal] = useState(false);
  const [showCalibrateModal, setShowCalibrateModal] = useState(false);
  const [calibrationReport, setCalibrationReport] = useState(null);
  const [mitigationReason, setMitigationReason] = useState(() => t('aiopsPage.mitigation.defaultReason'));
  const [mitigating, setMitigating] = useState(false);

  const [selectedConcurrency, setSelectedConcurrency] = useState(() => {
    try {
      const saved = localStorage.getItem('aiops_target_concurrency');
      const parsed = parseInt(saved, 10);
      return parsed >= 100 && parsed <= 50000 ? parsed : 1000;
    } catch (_) {
      return 1000;
    }
  });
  const [customConcurrency, setCustomConcurrency] = useState(() => {
    try {
      const saved = localStorage.getItem('aiops_target_concurrency');
      const parsed = parseInt(saved, 10);
      return parsed >= 100 && parsed <= 50000 ? String(parsed) : '1000';
    } catch (_) {
      return 1000;
    }
  });
  const [savingScale, setSavingScale] = useState(false);

  const [activeVectorTab, setActiveVectorTab] = useState('all');
  const [hoveredPointIndex, setHoveredPointIndex] = useState(null);

  const [timePreset, setTimePreset] = useState('10m');
  const [customRange, setCustomRange] = useState({
    from: '',
    to: '',
    applied: false,
  });

  const [customThresholdsInput, setCustomThresholdsInput] = useState({
    authFailureThreshold: '',
    trafficSpikeRps: '',
    exploitLimit: '',
    resourceCpuPercent: '',
    resourceMemoryPercent: '',
    eventLoopLagMs: '',
  });
  const [fetchingHistory, setFetchingHistory] = useState(false);

  const [vectorConfig, setVectorConfig] = useState({
    auth: true,
    traffic: true,
    exploit: true,
    resource: true,
  });
  const [vectorToggleModal, setVectorToggleModal] = useState({
    open: false,
    vector: null,
    targetState: false,
    vectorName: '',
    loading: false,
  });

  const [incidentsList, setIncidentsList] = useState([]);
  const [incidentPage, setIncidentPage] = useState(1);
  const [incidentPageSize, setIncidentPageSize] = useState(5);
  const [incidentTotal, setIncidentTotal] = useState(0);
  const [incidentVectorFilter, setIncidentVectorFilter] = useState('all');
  const [incidentStatusFilter, setIncidentStatusFilter] = useState('all');
  const [incidentSearch, setIncidentSearch] = useState('');
  const [showClearIncidentsModal, setShowClearIncidentsModal] = useState(false);
  const [clearingIncidents, setClearingIncidents] = useState(false);
  const [quarantineModalTarget, setQuarantineModalTarget] = useState(null);
  const [quarantiningActor, setQuarantiningActor] = useState(false);

  const [forensicsModal, setForensicsModal] = useState({
    open: false,
    ipHash: null,
    maskedIp: null,
    username: null,
    loading: false,
    incidents: [],
    total: 0,
    page: 1,
    limit: 5,
    activeFilter: 'all',
  });

  const [quarantinePage, setQuarantinePage] = useState(1);
  const [quarantinePageSize, setQuarantinePageSize] = useState(5);
  const [quarantineIpFilter, setQuarantineIpFilter] = useState('');
  const [quarantineAccountFilter, setQuarantineAccountFilter] = useState('');

  const [showManualQuarantineModal, setShowManualQuarantineModal] = useState(false);
  const [manualQuarantineForm, setManualQuarantineForm] = useState({
    targetType: 'ip',
    ipValue: '',
    accountValue: '',
    reason: 'Admin tạm khóa an ninh thủ công qua Audit Log',
    durationMinutes: 240,
  });
  const [manualQuarantineLoading, setManualQuarantineLoading] = useState(false);

  const [currentClientTime, setCurrentClientTime] = useState(Date.now());
  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentClientTime(Date.now());
    }, 5000);
    return () => clearInterval(timer);
  }, []);

  const formatMaskedIp = (raw) => {
    if (!raw || raw === 'N/A' || raw === '--') return '192.168.xxx.xxx';
    const clean = String(raw).replace(/^::ffff:/, '').trim();

    if (clean === '127.0.0.1' || clean === '::1' || clean === 'localhost') {
      return '127.0.xxx.xxx';
    }

    if (clean === 'xx.xx.xx.xx' || clean === 'xx.xx.xxx.xxx' || clean.startsWith('xx.xx.')) {
      return '192.168.xxx.xxx';
    }

    if (clean.includes('xxx')) {
      return clean;
    }

    const matchPrefix = clean.match(/^(\d{1,3}\.\d{1,3})\./);
    if (matchPrefix) {
      return `${matchPrefix[1]}.xxx.xxx`;
    }

    if (clean.includes(':')) {
      const parts = clean.split(':');
      if (parts.length > 2) {
        return `${parts[0]}:${parts[1]}:xxxx:xxxx`;
      }
    }

    return '192.168.xxx.xxx';
  };

  const formatRemainingTime = (minutes) => {
    if (minutes === null || minutes === undefined || isNaN(minutes)) return '--';
    const m = Math.round(Number(minutes));
    if (m <= 0) return 'Đã hết hạn tạm khóa';
    if (m < 60) return `${m} phút`;
    const hours = Math.floor(m / 60);
    const remMin = m % 60;
    return remMin > 0 ? `${hours} giờ ${remMin} phút` : `${hours} giờ`;
  };

  const filteredQuarantineList = useMemo(() => {
    return quarantineList.filter((item) => {
      const ipStr = String(item.maskedIp || item.ip || item.raw_ip || item.hash || '').toLowerCase();
      const accountStr = String(item.username || item.idaccount || '').toLowerCase();

      const matchesIp = !quarantineIpFilter.trim() || ipStr.includes(quarantineIpFilter.trim().toLowerCase());
      const matchesAccount = !quarantineAccountFilter.trim() || accountStr.includes(quarantineAccountFilter.trim().toLowerCase());

      return matchesIp && matchesAccount;
    });
  }, [quarantineList, quarantineIpFilter, quarantineAccountFilter]);

  const paginatedQuarantineList = useMemo(() => {
    const start = (quarantinePage - 1) * quarantinePageSize;
    return filteredQuarantineList.slice(start, start + quarantinePageSize);
  }, [filteredQuarantineList, quarantinePage, quarantinePageSize]);

  const socket = useSocket();

  const fetchAIOpsData = async () => {
    try {
      setLoading(true);
      const historyParams = (customRange.applied && customRange.from && customRange.to)
        ? { from: customRange.from, to: customRange.to }
        : { range: timePreset };

      const [statusRes, historyRes, quarantineRes, maintenanceRes, vectorConfigRes] = await Promise.all([
        aiopsApi.getStatus(),
        aiopsApi.getHistory(historyParams),
        aiopsApi.getQuarantineList(),
        adminApi.getMaintenanceStatus(),
        typeof aiopsApi.getVectorConfig === 'function' ? Promise.resolve(aiopsApi.getVectorConfig()).catch(() => null) : Promise.resolve(null),
      ]);

      const sData = statusRes?.data || statusRes;
      const hData = historyRes?.data || historyRes;
      const qData = quarantineRes?.data || quarantineRes;
      const mData = maintenanceRes?.data || maintenanceRes;
      const vConfigData = vectorConfigRes?.data || vectorConfigRes;

      if (mData) {
        setMaintenanceStatus(mData);
      }

      if (vConfigData && typeof vConfigData === 'object' && vConfigData.auth !== undefined) {
        setVectorConfig(vConfigData);
      } else if (sData?.vectorConfig) {
        setVectorConfig(sData.vectorConfig);
      }

      if (sData) {
        setStatusData(sData);
        if (sData.targetConcurrency && sData.targetConcurrency >= 100) {
          setSelectedConcurrency(sData.targetConcurrency);
          setCustomConcurrency(String(sData.targetConcurrency));
          try {
            localStorage.setItem('aiops_target_concurrency', String(sData.targetConcurrency));
          } catch (_) {}
        }
      }
      if (Array.isArray(hData)) setHistoryData(hData);
      if (Array.isArray(qData)) setQuarantineList(qData);
    } catch (err) {
    } finally {
      setLoading(false);
    }
  };

  const handleManualRefresh = async () => {
    try {
      await fetchAIOpsData();
      await fetchIncidents(1);
      setFeedback({ ok: true, msg: t('aiops.feedback.refreshSuccess', 'Đã làm mới dữ liệu AIOps Sentinel thành công!') });
    } catch (err) {
      setFeedback({ ok: false, msg: t('aiops.feedback.refreshError', 'Không thể làm mới dữ liệu AIOps Sentinel.') });
    }
  };

  const fetchHistoryFiltered = async (options = {}) => {
    try {
      setFetchingHistory(true);
      const targetApplied = options.customApplied !== undefined ? options.customApplied : customRange.applied;
      const targetFrom = options.from !== undefined ? options.from : customRange.from;
      const targetTo = options.to !== undefined ? options.to : customRange.to;
      const targetPreset = options.preset !== undefined ? options.preset : timePreset;

      const params = {};
      if (targetApplied && targetFrom && targetTo) {
        params.from = targetFrom;
        params.to = targetTo;
      } else {
        params.range = targetPreset;
      }

      const historyRes = await aiopsApi.getHistory(params);
      const hData = historyRes?.data || historyRes;
      if (Array.isArray(hData)) {
        setHistoryData(hData);
      }
    } catch (err) {
      setFeedback({ ok: false, msg: t('aiops.feedback.historyError', 'Không thể tải dữ liệu lịch sử xu hướng.') });
    } finally {
      setFetchingHistory(false);
    }
  };

  const handleOpenToggleVectorModal = (vectorKey) => {
    const currentState = vectorConfig[vectorKey] !== false;
    const nextState = !currentState;
    setVectorToggleModal({
      open: true,
      vector: vectorKey,
      targetState: nextState,
      vectorName: t('aiops.vectors.' + vectorKey, vectorKey),
      loading: false,
    });
  };

  const handleConfirmToggleVector = async () => {
    if (!vectorToggleModal.vector) return;
    try {
      setVectorToggleModal((prev) => ({ ...prev, loading: true }));
      const res = await aiopsApi.toggleVector(vectorToggleModal.vector, vectorToggleModal.targetState);
      const resData = res?.data || res;
      const updatedConfig = resData?.vectorConfig || {
        ...vectorConfig,
        [vectorToggleModal.vector]: vectorToggleModal.targetState,
      };
      setVectorConfig(updatedConfig);
      if (resData?.currentStatus) {
        setStatusData((prev) => ({
          ...prev,
          ...resData.currentStatus,
        }));
      } else {
        fetchAIOpsData();
      }
      setFeedback({
        ok: true,
        msg: vectorToggleModal.targetState
          ? t('aiops.feedback.toggleVectorTurnedOn', { name: vectorToggleModal.vectorName })
          : t('aiops.feedback.toggleVectorTurnedOff', { name: vectorToggleModal.vectorName }),
      });
      setVectorToggleModal({ open: false, vector: null, targetState: false, vectorName: '', loading: false });
    } catch (err) {
      setFeedback({
        ok: false,
        msg: err?.response?.data?.message || err?.message || 'Không thể thay đổi cấu hình vector.',
      });
      setVectorToggleModal((prev) => ({ ...prev, loading: false }));
    }
  };

  const handleSelectTimePreset = (presetKey) => {
    setTimePreset(presetKey);
    setCustomRange((prev) => ({ ...prev, applied: false }));
    fetchHistoryFiltered({ preset: presetKey, customApplied: false });
    fetchIncidents(1, incidentPageSize, incidentVectorFilter, incidentStatusFilter, incidentSearch, presetKey, '', '');
  };

  const handleApplyCustomRange = () => {
    if (!customRange.from || !customRange.to) {
      setFeedback({
        ok: false,
        msg: t('aiops.feedback.fillRange', 'Vui lòng chọn đầy đủ thời điểm bắt đầu (Từ) và kết thúc (Đến).'),
      });
      return;
    }
    if (customRange.from > customRange.to) {
      setFeedback({
        ok: false,
        msg: t('aiops.feedback.invalidRange', 'Thời điểm bắt đầu không được lớn hơn thời điểm kết thúc.'),
      });
      return;
    }

    setCustomRange((prev) => ({ ...prev, applied: true }));
    fetchHistoryFiltered({ from: customRange.from, to: customRange.to, customApplied: true });
    fetchIncidents(1, incidentPageSize, incidentVectorFilter, incidentStatusFilter, incidentSearch, 'custom', customRange.from, customRange.to);
  };

  const handleClearCustomRange = () => {
    setCustomRange({ from: '', to: '', applied: false });
    fetchHistoryFiltered({ customApplied: false, preset: timePreset });
    fetchIncidents(1, incidentPageSize, incidentVectorFilter, incidentStatusFilter, incidentSearch, timePreset, '', '');
  };

  const handleResetCustomRange = () => {
    setCustomRange({ from: '', to: '', applied: false });
    fetchHistoryFiltered({ customApplied: false, preset: timePreset });
    fetchIncidents(1, incidentPageSize, incidentVectorFilter, incidentStatusFilter, incidentSearch, timePreset, '', '');
    setFeedback({ ok: true, msg: t('aiops.feedback.resetRange', 'Đã làm mới bộ lọc thời gian về trạng thái ban đầu.') });
  };

  const fetchIncidents = async (
    page = incidentPage,
    limit = incidentPageSize,
    vector = incidentVectorFilter,
    status = incidentStatusFilter,
    search = incidentSearch,
    preset = timePreset,
    fromVal = customRange.applied ? customRange.from : '',
    toVal = customRange.applied ? customRange.to : ''
  ) => {
    try {
      const params = { page, limit, vector, status, search };
      if (fromVal && toVal) {
        params.from = fromVal;
        params.to = toVal;
      } else if (preset) {
        params.range = preset;
      }
      const res = await aiopsApi.getIncidents(params);
      const data = res?.data || res;
      const list = data?.incidents || data?.data || (Array.isArray(data) ? data : null);
      if (list !== null && Array.isArray(list)) {
        setIncidentsList(list);
        setIncidentTotal(data.total ?? list.length ?? 0);
      }
    } catch (err) {
    }
  };

  const fetchAIOpsDataRef = useRef(fetchAIOpsData);
  fetchAIOpsDataRef.current = fetchAIOpsData;

  useEffect(() => {
    fetchAIOpsData();
    fetchIncidents(1, incidentPageSize, incidentVectorFilter, incidentStatusFilter, incidentSearch);

    const intervalSec = settingsCtx?.settings?.metricsInterval || 3;
    const intervalMs = Math.max(1000, intervalSec * 1000);
    const interval = setInterval(() => {
      fetchAIOpsDataRef.current();
    }, intervalMs);

    return () => clearInterval(interval);
  }, [settingsCtx?.settings?.metricsInterval]);

  useEffect(() => {
    fetchIncidents(incidentPage, incidentPageSize, incidentVectorFilter, incidentStatusFilter, incidentSearch);
  }, [incidentPage, incidentPageSize, incidentVectorFilter, incidentStatusFilter]);

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    setIncidentPage(1);
    fetchIncidents(1, incidentPageSize, incidentVectorFilter, incidentStatusFilter, incidentSearch);
  };

  const handleClearIncidents = async () => {
    try {
      setClearingIncidents(true);
      await aiopsApi.clearIncidents();
      setIncidentsList([]);
      setIncidentTotal(0);
      setIncidentPage(1);
      setShowClearIncidentsModal(false);
      setFeedback({ ok: true, msg: t('aiops.feedback.clearIncidentsSuccess', 'Đã làm sạch toàn bộ nhật ký sự cố bất thường thành công.') });
    } catch (err) {
      setFeedback({ ok: false, msg: err?.response?.data?.message || err?.message || t('aiops.feedback.clearIncidentsError', 'Xóa nhật ký thất bại') });
    } finally {
      setClearingIncidents(false);
    }
  };

  const handleOpenQuarantineModal = (item) => {
    const actorType = item.actor?.type || item.actor_type;
    const actorIdentity = item.actor?.identity || item.actor_identity || item.actorIdentity || '';
    const actorHash = item.actor?.ipHash || item.actor_hash || item.actorHash || '';
    const clientIpClean = String(myCurrentIp || '').replace(/^::ffff:/, '').trim();
    const isMyIp = Boolean(
      clientIpClean && (
        actorIdentity === clientIpClean ||
        actorIdentity.includes(clientIpClean) ||
        (clientIpClean.split('.').slice(0, 2).join('.') && actorIdentity.startsWith(clientIpClean.split('.').slice(0, 2).join('.')))
      )
    );
    if (
      actorType === 'SYSTEM_INTERNAL' ||
      item.vector === 'resource' ||
      actorHash === 'system_core' ||
      actorHash === 'system_host' ||
      isMyIp ||
      actorIdentity.includes('127.0.0.1') ||
      actorIdentity.includes('::1') ||
      actorIdentity.includes('localhost') ||
      actorIdentity.includes('Internal')
    ) {
      setFeedback({
        ok: false,
        msg: isMyIp
          ? '🛡️ Đây là địa chỉ IP máy bạn đang đăng nhập. Không thể tự phong tỏa chính mình!'
          : '🛡️ Đối tượng này thuộc diện bảo vệ an toàn (Hạ tầng máy chủ/Loopback). Không thể phong tỏa.',
      });
      return;
    }
    setQuarantineModalTarget(item);
  };

  const handleConfirmQuarantine = async () => {
    if (!quarantineModalTarget) return;
    try {
      setQuarantiningActor(true);
      const actorHash = quarantineModalTarget.actor?.ipHash || quarantineModalTarget.actor_hash || quarantineModalTarget.actorHash;
      const actorIdentity = quarantineModalTarget.actor?.identity || quarantineModalTarget.actor_identity || quarantineModalTarget.actorIdentity;
      const code = quarantineModalTarget.code || 'SỰ CỐ AN NINH';

      const res = await aiopsApi.quarantineActor({
        hash: actorHash,
        ip: actorIdentity && !actorIdentity.includes('xx') ? actorIdentity : null,
        maskedIp: actorIdentity,
        vector: quarantineModalTarget.vector || 'auth',
        reason: `Admin quarantine (${code})`,
        durationMinutes: 240,
      });

      const resData = res?.data || res;
      setFeedback({
        ok: true,
        msg: res?.message || t('aiops.feedback.quarantineSuccess', { actor: actorIdentity || actorHash }),
      });

      if (resData) {
        setQuarantineList((prev) => {
          const exists = prev.some((x) => x.hash === (resData.hash || actorHash));
          if (exists) return prev;
          return [
            {
              hash: resData.hash || actorHash,
              maskedIp: resData.maskedIp || actorIdentity,
              vector: resData.vector || quarantineModalTarget.vector || 'auth',
              reason: resData.reason || `Admin quarantine (${code})`,
              bannedAt: resData.bannedAt || new Date().toISOString(),
              expiresAt: resData.expiresAt || new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString(),
              remainingMinutes: 240,
              hits: resData.hits || 1,
            },
            ...prev,
          ];
        });
      }
      setQuarantineModalTarget(null);
    } catch (err) {
      setFeedback({
        ok: false,
        msg: err?.response?.data?.message || err?.message || t('aiops.feedback.quarantineError', 'Phong tỏa nguồn IP thất bại.'),
      });
    } finally {
      setQuarantiningActor(false);
    }
  };

  const handleOpenManualQuarantine = () => {
    setManualQuarantineForm({
      targetType: 'ip',
      ipValue: '',
      accountValue: '',
      reason: t('aiops.quarantine.manualDefaultReason', 'Admin tạm khóa an ninh thủ công qua Audit Log'),
      durationMinutes: 240,
    });
    setShowManualQuarantineModal(true);
  };

  const handleSubmitManualQuarantine = async (e) => {
    if (e && e.preventDefault) e.preventDefault();
    const { targetType, ipValue, accountValue, reason, durationMinutes } = manualQuarantineForm;
    const durMin = parseInt(durationMinutes, 10) || 240;

    if (targetType === 'ip') {
      const cleanIp = ipValue.trim();
      if (!cleanIp) {
        setFeedback({ ok: false, msg: t('aiops.quarantine.errEmptyIp', 'Vui lòng nhập địa chỉ IP cần tạm khóa.') });
        return;
      }
      const myClean = String(myCurrentIp || '').replace(/^::ffff:/, '').trim();
      if (cleanIp === '127.0.0.1' || cleanIp === '::1' || cleanIp === 'localhost' || (myClean && cleanIp === myClean)) {
        setFeedback({ ok: false, msg: t('aiops.quarantine.errProtectedIp', 'Không thể tạm khóa địa chỉ IP loopback hoặc IP máy bạn đang đăng nhập.') });
        return;
      }
      try {
        setManualQuarantineLoading(true);
        const res = await aiopsApi.quarantineActor({
          ip: cleanIp,
          reason: reason || 'Admin tạm khóa IP thủ công qua Audit Log',
          durationMinutes: durMin,
          vector: 'auth',
        });
        const resData = res?.data || res;
        setFeedback({
          ok: true,
          msg: t('aiops.quarantine.manualIpSuccess', `Đã tạm khóa IP ${cleanIp} thành công (${Math.round(durMin / 60)} giờ).`, { ip: cleanIp, hours: Math.round(durMin / 60) }),
        });
        setShowManualQuarantineModal(false);
        await fetchAIOpsData();
      } catch (err) {
        setFeedback({
          ok: false,
          msg: err?.response?.data?.message || err?.message || 'Tạm khóa IP thất bại.',
        });
      } finally {
        setManualQuarantineLoading(false);
      }
    } else {
      const cleanUser = accountValue.trim();
      if (!cleanUser) {
        setFeedback({ ok: false, msg: t('aiops.quarantine.errEmptyAccount', 'Vui lòng nhập Username hoặc ID tài khoản cần tạm khóa.') });
        return;
      }
      try {
        setManualQuarantineLoading(true);
        const res = await aiopsApi.temporaryBlockAccount({
          username: cleanUser,
          durationMinutes: durMin,
        });
        setFeedback({
          ok: true,
          msg: t('aiops.quarantine.manualAccountSuccess', `Đã tạm khóa tài khoản ${cleanUser} thành công (${Math.round(durMin / 60)} giờ).`, { user: cleanUser, hours: Math.round(durMin / 60) }),
        });
        setShowManualQuarantineModal(false);
        await fetchAIOpsData();
      } catch (err) {
        setFeedback({
          ok: false,
          msg: err?.response?.data?.message || err?.message || 'Tạm khóa tài khoản thất bại.',
        });
      } finally {
        setManualQuarantineLoading(false);
      }
    }
  };

  useEffect(() => {
    if (!socket) return;

    const handleMetricsStream = (metrics) => {
      if (!metrics) return;
      if (metrics.vectorConfig) {
        setVectorConfig(metrics.vectorConfig);
      }
      setStatusData((prev) => {
        const streamConcurrency = metrics.targetConcurrency && metrics.targetConcurrency >= 100
          ? metrics.targetConcurrency
          : (prev?.targetConcurrency || selectedConcurrency || 1000);

        return {
          ...prev,
          threatScore: metrics.threatScore ?? prev?.threatScore ?? 0,
          status: metrics.threatStatus || prev?.status || 'NORMAL',
          vectorScores: metrics.vectorScores || prev?.vectorScores || { auth: 0, traffic: 0, exploit: 0, resource: 0 },
          vectorDefenses: metrics.vectorDefenses || prev?.vectorDefenses || {},
          recommendedAction: metrics.recommendedAction || prev?.recommendedAction || null,
          targetConcurrency: streamConcurrency,
          sample: {
            ...(prev?.sample || {}),
            cpuPercent: metrics.cpuPercent,
            cpuCores: metrics.cpuCores ?? prev?.sample?.cpuCores,
            ramPercent: metrics.ramPercent,
            ramUsedMb: metrics.ramUsedMb ?? prev?.sample?.ramUsedMb,
            ramTotalMb: metrics.ramTotalMb ?? prev?.sample?.ramTotalMb,
            ramFreeMb: metrics.ramFreeMb ?? prev?.sample?.ramFreeMb,
            ramRssMb: metrics.ramRssMb ?? prev?.sample?.ramRssMb,
            eventLoopLagMs: metrics.eventLoopLagMs,
            requestsPerMin: metrics.requestsPerMin,
          },
          lastEvaluatedAt: metrics.timestamp,
        };
      });
    };

    const handleAlert = (data) => {
      if (data) {
        if (data.vectorConfig) {
          setVectorConfig(data.vectorConfig);
        }
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
      setFeedback({
        ok: false,
        msg: t('aiops.feedback.blockedAlert', { ip: blockData.maskedIp, reason: blockData.reason }, `🛡️ [AIOPS ĐÃ CHẶN ĐỨNG NGUỒN TẤN CÔNG] IP ${blockData.maskedIp} đã bị ngắt kết nối lập tức | Lý do: ${blockData.reason}`),
      });
      setQuarantineList(prev => [blockData, ...prev.filter(x => x.hash !== blockData.hash)]);
    };

    const handleAnomalyDetected = (newIncident) => {
      if (!newIncident) return;
      setIncidentsList((prev) => {
        const existingIdx = prev.findIndex((i) => i.id === newIncident.id);
        if (existingIdx >= 0) {
          const updated = [...prev];
          updated[existingIdx] = newIncident;
          return updated;
        }
        return [newIncident, ...prev];
      });
      setIncidentTotal((prev) => prev + 1);
    };

    const handleMaintenanceChanged = (mState) => {
      if (mState) {
        setMaintenanceStatus(mState);
      }
    };

    const handleVectorConfigChanged = (newConfig) => {
      if (newConfig) {
        setVectorConfig(newConfig);
      }
    };

    const handleQuarantineUpdated = () => {
      if (typeof aiopsApi.getQuarantineList === 'function') {
        aiopsApi.getQuarantineList().then((res) => {
          const qData = res?.data || res;
          if (Array.isArray(qData)) setQuarantineList(qData);
        }).catch(() => {});
      }
    };

    socket.on('admin.metrics_stream', handleMetricsStream);
    socket.on('admin.security_alert', handleAlert);
    socket.on('admin.security_blocked', handleBlocked);
    socket.on('admin.quarantine_updated', handleQuarantineUpdated);
    socket.on('admin.anomaly_detected', handleAnomalyDetected);
    socket.on('admin.maintenance_changed', handleMaintenanceChanged);
    socket.on('admin.vector_config_changed', handleVectorConfigChanged);

    return () => {
      socket.off('admin.metrics_stream', handleMetricsStream);
      socket.off('admin.security_alert', handleAlert);
      socket.off('admin.security_blocked', handleBlocked);
      socket.off('admin.quarantine_updated', handleQuarantineUpdated);
      socket.off('admin.anomaly_detected', handleAnomalyDetected);
      socket.off('admin.maintenance_changed', handleMaintenanceChanged);
      socket.off('admin.vector_config_changed', handleVectorConfigChanged);
    };
  }, [socket]);

  const handleApplyScale = async (scaleToApply) => {
    const val = parseInt(scaleToApply ?? customConcurrency, 10);
    if (!val || val < 100 || val > 50000) {
      setFeedback({ ok: false, msg: t('aiops.feedback.invalidConcurrency', 'Vui lòng chọn hoặc nhập số lượng người dùng từ 100 đến 50,000.') });
      return;
    }
    try {
      setSavingScale(true);
      const res = await aiopsApi.setScale(val);
      setSelectedConcurrency(val);
      setCustomConcurrency(String(val));
      try {
        localStorage.setItem('aiops_target_concurrency', String(val));
      } catch (_) {}
      setStatusData(prev => ({
        ...prev,
        targetConcurrency: val,
      }));
      setFeedback({
        ok: true,
        msg: res?.message || t('aiops.feedback.scaleSuccess', { count: val.toLocaleString() }, `Đã cập nhật và lưu cứng quy mô chịu tải mục tiêu: ${val.toLocaleString()} người dùng đồng thời!`)
      });
    } catch (err) {
      setFeedback({
        ok: false,
        msg: err?.response?.data?.message || err?.message || t('aiops.feedback.scaleError', 'Cập nhật quy mô thất bại.')
      });
    } finally {
      setSavingScale(false);
    }
  };

  const [quarantineActionLoading, setQuarantineActionLoading] = useState(null);

  const handleTemporaryBlockIp = async (ipHash, maskedIp) => {
    if (!window.confirm(`Bạn có chắc muốn TẠM KHÓA kết nối từ IP ${maskedIp || ''} trong vòng 4 giờ?`)) return;
    const actionKey = `temp_ip_${ipHash}`;
    try {
      setQuarantineActionLoading(actionKey);
      await aiopsApi.temporaryBlockIp({ ipHash });
      setQuarantineList(prev => prev.map(item => (item.ipHash === ipHash || item.hash === ipHash) ? { ...item, ipStatus: 'temporary', ipRemainingMinutes: 240, remainingMinutes: 240 } : item));
      setFeedback({ ok: true, msg: `Đã tạm khóa IP ${maskedIp || ''} thành công.` });
    } catch (err) {
      setFeedback({ ok: false, msg: err?.response?.data?.message || err?.message || 'Tạm khóa IP thất bại.' });
    } finally {
      setQuarantineActionLoading(null);
    }
  };

  const handleUnblockIp = async (ipHash, maskedIp) => {
    if (!window.confirm(t('aiops.confirmUnblockMsg', `Bạn có chắc muốn gỡ chặn và mở khóa kết nối cho địa chỉ IP ${maskedIp || ''}? Tất cả các dòng có cùng địa chỉ IP này sẽ được đồng bộ mở khóa.`))) return;
    const actionKey = `unblock_ip_${ipHash}`;
    try {
      setQuarantineActionLoading(actionKey);
      await aiopsApi.unblockIp({ ipHash });
      setQuarantineList(prev => prev.map(item => (item.ipHash === ipHash || item.hash === ipHash) ? { ...item, ipStatus: 'unlocked', ipRemainingMinutes: null, ipExpiresAt: null } : item));
      setFeedback({ ok: true, msg: `Đã mở khóa IP ${maskedIp || ''} thành công trên toàn bộ hệ thống.` });
    } catch (err) {
      setFeedback({ ok: false, msg: err?.response?.data?.message || err?.message || 'Gỡ chặn IP thất bại.' });
    } finally {
      setQuarantineActionLoading(null);
    }
  };

  const handlePermanentBanIp = async (ipHash, maskedIp) => {
    if (!window.confirm(`Bạn có chắc muốn TẠM KHÓA địa chỉ IP ${maskedIp || ''} trong vòng 4 giờ?\n(Hệ thống áp dụng chính sách tạm khóa 4 giờ thay vì khóa vĩnh viễn để bảo vệ người dùng mạng di động/CGNAT).`)) return;
    const actionKey = `ban_ip_${ipHash}`;
    try {
      setQuarantineActionLoading(actionKey);
      await aiopsApi.permanentBanIp({ ipHash });
      const exp = Date.now() + 4 * 60 * 60 * 1000;
      setQuarantineList(prev => prev.map(item => (item.ipHash === ipHash || item.hash === ipHash) ? { ...item, ipStatus: 'temporary', ipRemainingMinutes: 240, ipExpiresAt: exp } : item));
      setFeedback({ ok: true, msg: `Đã tạm khóa IP ${maskedIp || ''} trong 4 giờ thành công.` });
    } catch (err) {
      setFeedback({ ok: false, msg: err?.response?.data?.message || err?.message || 'Tạm khóa IP thất bại.' });
    } finally {
      setQuarantineActionLoading(null);
    }
  };

  const handleTemporaryBlockAccount = async (username, idaccount) => {
    if (!window.confirm(`Bạn có chắc muốn TẠM KHÓA tài khoản [${username || idaccount}] trong vòng 4 giờ?`)) return;
    const actionKey = `temp_acc_${username || idaccount}`;
    try {
      setQuarantineActionLoading(actionKey);
      await aiopsApi.temporaryBlockAccount({ username, idaccount });
      setQuarantineList(prev => prev.map(item => (item.username === username || (idaccount && item.idaccount === idaccount)) ? { ...item, accountStatus: 'temporary', accountRemainingMinutes: 240, remainingMinutes: 240 } : item));
      setFeedback({ ok: true, msg: `Đã tạm khóa tài khoản [${username || idaccount}] thành công.` });
    } catch (err) {
      setFeedback({ ok: false, msg: err?.response?.data?.message || err?.message || 'Tạm khóa tài khoản thất bại.' });
    } finally {
      setQuarantineActionLoading(null);
    }
  };

  const handleUnblockAccount = async (username, idaccount) => {
    if (!window.confirm(`Bạn có chắc muốn MỞ KHÓA tài khoản [${username || idaccount}]? Mọi dòng liên quan đến tài khoản này và trạng thái tài khoản trong CSDL sẽ được kích hoạt lại.`)) return;
    const actionKey = `unblock_acc_${username || idaccount}`;
    try {
      setQuarantineActionLoading(actionKey);
      await aiopsApi.unblockAccount({ username, idaccount });
      setQuarantineList(prev => prev.map(item => (item.username === username || (idaccount && item.idaccount === idaccount)) ? { ...item, accountStatus: 'unlocked', accountRemainingMinutes: null, accountExpiresAt: null } : item));
      setFeedback({ ok: true, msg: `Đã mở khóa tài khoản [${username || idaccount}] thành công.` });
    } catch (err) {
      setFeedback({ ok: false, msg: err?.response?.data?.message || err?.message || 'Mở khóa tài khoản thất bại.' });
    } finally {
      setQuarantineActionLoading(null);
    }
  };

  const handlePermanentBanAccount = async (username, idaccount) => {
    if (!window.confirm(`Bạn có chắc muốn KHÓA VĨNH VIỄN tài khoản [${username || idaccount}]? Tài khoản sẽ bị vô hiệu hóa trong CSDL và chặn đăng nhập vĩnh viễn.`)) return;
    const actionKey = `ban_acc_${username || idaccount}`;
    try {
      setQuarantineActionLoading(actionKey);
      await aiopsApi.permanentBanAccount({ username, idaccount });
      setQuarantineList(prev => prev.map(item => (item.username === username || (idaccount && item.idaccount === idaccount)) ? { ...item, accountStatus: 'permanent', accountRemainingMinutes: null, accountExpiresAt: null } : item));
      setFeedback({ ok: true, msg: `Đã khóa vĩnh viễn tài khoản [${username || idaccount}] thành công.` });
    } catch (err) {
      setFeedback({ ok: false, msg: err?.response?.data?.message || err?.message || 'Khóa tài khoản thất bại.' });
    } finally {
      setQuarantineActionLoading(null);
    }
  };

  const handleUnblock = async (hash) => {
    return handleUnblockIp(hash, '');
  };

  const fetchForensicsLogs = async (ipHash, username, page = 1, filterType = 'all') => {
    try {
      setForensicsModal(prev => ({ ...prev, loading: true }));
      const params = { page, limit: 5 };
      if (filterType === 'ip') {
        if (ipHash) params.ipHash = ipHash;
      } else if (filterType === 'username') {
        if (username && username !== 'all' && username !== 'N/A') params.username = username;
      } else {
        if (ipHash) params.ipHash = ipHash;
        else if (username && username !== 'all' && username !== 'N/A') params.username = username;
      }
      const res = await aiopsApi.getForensics(params);
      const data = res?.data || res || {};
      const incidents = Array.isArray(data.incidents) ? data.incidents : (Array.isArray(data) ? data : []);
      const total = typeof data.total === 'number' ? data.total : incidents.length;
      setForensicsModal(prev => ({
        ...prev,
        loading: false,
        incidents,
        total,
        page,
        activeFilter: filterType,
      }));
    } catch (err) {
      setForensicsModal(prev => ({ ...prev, loading: false }));
      setFeedback({ ok: false, msg: err?.response?.data?.message || err?.message || 'Không thể tải hồ sơ điều tra an ninh.' });
    }
  };

  const handleOpenForensics = (ipHash, maskedIp, username) => {
    setForensicsModal({
      open: true,
      ipHash: ipHash || null,
      maskedIp: maskedIp || 'IP N/A',
      username: username || null,
      loading: true,
      incidents: [],
      total: 0,
      page: 1,
      limit: 5,
      activeFilter: 'all',
    });
    fetchForensicsLogs(ipHash, username, 1, 'all');
  };

  const autoRecommendedThresholds = useMemo(() => {
    const N = Math.max(100, Number(selectedConcurrency || statusData?.targetConcurrency || 1000));
    const authLimit = Math.max(20, Math.round(15 + 10 * Math.log10(N / 100)));
    const trafficRps = Math.max(50, Math.round(N / 2));
    const exploitLimit = 8;
    const resourceCpu = 85;
    const resourceRam = 85;
    const resourceLag = 100;
    return {
      authFailureThreshold: authLimit,
      trafficSpikeRps: trafficRps,
      exploitLimit: exploitLimit,
      resourceCpuPercent: resourceCpu,
      resourceMemoryPercent: resourceRam,
      eventLoopLagMs: resourceLag,
    };
  }, [selectedConcurrency, statusData?.targetConcurrency]);

  const handleCalibrate = async () => {
    try {
      setCalibrating(true);
      setFeedback(null);
      const targetVal = selectedConcurrency || 1000;
      const parseField = (val, fallback) => {
        if (val !== '' && val !== null && val !== undefined && !isNaN(Number(val)) && Number(val) > 0) {
          return Number(val);
        }
        return fallback;
      };

      const res = await aiopsApi.calibrate({
        targetConcurrency: targetVal,
        customThresholds: {
          authFailureThreshold: parseField(customThresholdsInput.authFailureThreshold, autoRecommendedThresholds.authFailureThreshold),
          trafficSpikeRps: parseField(customThresholdsInput.trafficSpikeRps, autoRecommendedThresholds.trafficSpikeRps),
          exploitLimit: parseField(customThresholdsInput.exploitLimit, autoRecommendedThresholds.exploitLimit),
          resourceCpuPercent: parseField(customThresholdsInput.resourceCpuPercent, autoRecommendedThresholds.resourceCpuPercent),
          resourceMemoryPercent: parseField(customThresholdsInput.resourceMemoryPercent, autoRecommendedThresholds.resourceMemoryPercent),
          eventLoopLagMs: parseField(customThresholdsInput.eventLoopLagMs, autoRecommendedThresholds.eventLoopLagMs),
        },
      });
      const report = res?.data || res;
      if (report?.serverSpecs) {
        setCalibrationReport(report);
      }
      setShowCalibrateModal(false);
      setFeedback({ ok: true, msg: res?.message || t('aiops.feedback.calibrateSuccess', 'Đã tái hiệu chuẩn mô hình thành công.') });
      await fetchAIOpsData();
    } catch (err) {
      const errMsg = err?.response?.data?.message || err?.message || '';
      if (errMsg.includes('Route not found')) {
        setFeedback({
          ok: false,
          msg: t('aiops.feedback.calibrateCloudWarning', '⚠️ Endpoint máy học chưa được triển khai trên máy chủ Cloud (Render). Vui lòng kết nối Backend Local (cổng 3000) hoặc chờ quá trình deploy Cloud hoàn tất.'),
        });
      } else {
        setFeedback({ ok: false, msg: errMsg || t('aiops.feedback.calibrateError', 'Hiệu chuẩn thất bại.') });
      }
    } finally {
      setCalibrating(false);
    }
  };

  const handleTriggerMitigation = async () => {
    try {
      setMitigating(true);
      await adminApi.setMaintenanceStatus({
        active: true,
        reason: mitigationReason.trim() || t('aiopsPage.mitigation.defaultReason'),
        isEmergency: true,
      });
      setFeedback({
        ok: true,
        msg: t('aiops.feedback.mitigationSuccess', '🚨 ĐÃ KÍCH HOẠT BẢO TRÌ KHẨN CẤP THÀNH CÔNG! Toàn bộ kết nối khách đã bị chặn để bảo vệ hệ thống.'),
      });
      setShowMitigationModal(false);
    } catch (err) {
      setFeedback({ ok: false, msg: err?.response?.data?.message || t('aiops.feedback.mitigationError', 'Kích hoạt bảo trì khẩn cấp thất bại.') });
    } finally {
      setMitigating(false);
    }
  };

  const threatScore = statusData?.threatScore ?? 0;
  const currentStatus = statusData?.status || 'NORMAL';
  const targetConcurrency = statusData?.targetConcurrency || selectedConcurrency || 1000;
  const vectorScores = statusData?.vectorScores || { auth: 0, traffic: 0, exploit: 0, resource: 0 };
  const vectorDefenses = statusData?.vectorDefenses || {};
  const sample = statusData?.sample || {};
  const anomalies = statusData?.anomalies || [];
  const recommendedAction = statusData?.recommendedAction;

  const baselineRpm = targetConcurrency * 10;
  const safePeakRpm = baselineRpm * 3;
  const quarantineThreshold = Math.max(150, Math.round(20 + 50 * Math.log10(targetConcurrency)));

  const isEmergencyResourceRisk = useMemo(() => {
    if (vectorConfig.resource === false) return false;
    return (
      recommendedAction === 'EMERGENCY_MAINTENANCE' ||
      (vectorScores.resource >= 85) ||
      (vectorScores.resource >= 70 && (sample?.errorRate5xx || 0) >= 0.15 && (sample?.eventLoopLagMs || 0) >= 250)
    );
  }, [recommendedAction, vectorScores.resource, sample, vectorConfig.resource]);

  const getVectorTheme = (score) => {
    if (score >= 80) return { bg: 'bg-red-500', text: 'text-red-700', badge: 'bg-red-100 text-red-800 border-red-300', label: t('aiops.theme.critical', 'Nguy cấp') };
    if (score >= 60) return { bg: 'bg-orange-500', text: 'text-orange-700', badge: 'bg-orange-100 text-orange-800 border-orange-300', label: t('aiops.theme.warning', 'Cảnh báo') };
    if (score >= 30) return { bg: 'bg-amber-500', text: 'text-amber-700', badge: 'bg-amber-100 text-amber-800 border-amber-300', label: t('aiops.theme.watching', 'Theo dõi') };
    return { bg: 'bg-emerald-500', text: 'text-emerald-700', badge: 'bg-emerald-100 text-emerald-800 border-emerald-300', label: t('aiops.theme.normal', 'Bình thường') };
  };

  return {
    alert,
    settingsCtx,
    currentUser,
    statusData,
    setStatusData,
    myCurrentIp,
    historyData,
    setHistoryData,
    quarantineList,
    setQuarantineList,
    loading,
    setLoading,
    calibrating,
    setCalibrating,
    unblockingHash,
    setUnblockingHash,
    feedback,
    setFeedback,
    maintenanceStatus,
    setMaintenanceStatus,
    showMitigationModal,
    setShowMitigationModal,
    showCalibrateModal,
    setShowCalibrateModal,
    calibrationReport,
    setCalibrationReport,
    mitigationReason,
    setMitigationReason,
    mitigating,
    setMitigating,
    selectedConcurrency,
    setSelectedConcurrency,
    customConcurrency,
    setCustomConcurrency,
    savingScale,
    setSavingScale,
    activeVectorTab,
    setActiveVectorTab,
    hoveredPointIndex,
    setHoveredPointIndex,
    timePreset,
    setTimePreset,
    customRange,
    setCustomRange,
    customThresholdsInput,
    setCustomThresholdsInput,
    fetchingHistory,
    setFetchingHistory,
    vectorConfig,
    setVectorConfig,
    vectorToggleModal,
    setVectorToggleModal,
    incidentsList,
    setIncidentsList,
    incidentPage,
    setIncidentPage,
    incidentPageSize,
    setIncidentPageSize,
    incidentTotal,
    setIncidentTotal,
    incidentVectorFilter,
    setIncidentVectorFilter,
    incidentStatusFilter,
    setIncidentStatusFilter,
    incidentSearch,
    setIncidentSearch,
    showClearIncidentsModal,
    setShowClearIncidentsModal,
    clearingIncidents,
    setClearingIncidents,
    quarantineModalTarget,
    setQuarantineModalTarget,
    quarantiningActor,
    setQuarantiningActor,
    forensicsModal,
    setForensicsModal,
    quarantinePage,
    setQuarantinePage,
    quarantinePageSize,
    setQuarantinePageSize,
    quarantineIpFilter,
    setQuarantineIpFilter,
    quarantineAccountFilter,
    setQuarantineAccountFilter,
    showManualQuarantineModal,
    setShowManualQuarantineModal,
    manualQuarantineForm,
    setManualQuarantineForm,
    manualQuarantineLoading,
    setManualQuarantineLoading,
    currentClientTime,
    setCurrentClientTime,
    formatMaskedIp,
    formatRemainingTime,
    filteredQuarantineList,
    paginatedQuarantineList,
    socket,
    fetchAIOpsData,
    handleManualRefresh,
    fetchHistoryFiltered,
    handleOpenToggleVectorModal,
    handleConfirmToggleVector,
    handleSelectTimePreset,
    handleApplyCustomRange,
    handleClearCustomRange,
    handleResetCustomRange,
    fetchIncidents,
    handleSearchSubmit,
    handleClearIncidents,
    handleOpenQuarantineModal,
    handleConfirmQuarantine,
    handleOpenManualQuarantine,
    handleSubmitManualQuarantine,
    handleApplyScale,
    quarantineActionLoading,
    setQuarantineActionLoading,
    handleTemporaryBlockIp,
    handleUnblockIp,
    handlePermanentBanIp,
    handleTemporaryBlockAccount,
    handleUnblockAccount,
    handlePermanentBanAccount,
    handleUnblock,
    fetchForensicsLogs,
    handleOpenForensics,
    autoRecommendedThresholds,
    handleCalibrate,
    handleTriggerMitigation,
    threatScore,
    currentStatus,
    targetConcurrency,
    vectorScores,
    vectorDefenses,
    sample,
    anomalies,
    recommendedAction,
    baselineRpm,
    safePeakRpm,
    quarantineThreshold,
    isEmergencyResourceRisk,
    getVectorTheme,
    t,
  };
};

export default useAIOps;
