import React, { useState, useEffect, useMemo } from 'react';
import aiopsApi from '../../api/aiops.api';
import adminApi from '../../api/admin.api';
import useSocket from '../../hooks/useSocket';
import { formatDateTime, formatFullDateTime } from '../../utils/format';
import Pagination from '../../components/common/Pagination';
import ConfirmModal from '../../components/common/ConfirmModal';
import { useAlertSafe } from '../../store/alert.context';
import { useSettingsSafe } from '../../store/settings.context';
import { useLanguageSafe } from '../../store/language.context';
import useAuth from '../../hooks/useAuth';

const VECTOR_KEYS = {
  auth: 'aiops.vectors.auth',
  traffic: 'aiops.vectors.traffic',
  exploit: 'aiops.vectors.exploit',
  resource: 'aiops.vectors.resource',
};

const AIOpsPage = () => {
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

  // Wrapper kích hoạt Global Floating Alert toast đồng thời lưu feedback
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

  // System Maintenance Status state
  const [maintenanceStatus, setMaintenanceStatus] = useState({
    active: false,
    isEmergency: false,
    reason: '',
    activatedBy: null,
    activatedAt: null,
  });

  // Mitigation modal state
  const [showMitigationModal, setShowMitigationModal] = useState(false);
  const [showCalibrateModal, setShowCalibrateModal] = useState(false);
  const [calibrationReport, setCalibrationReport] = useState(null);
  const [mitigationReason, setMitigationReason] = useState(() => t('aiops.mitigation.defaultReason', 'Phòng vệ khẩn cấp AIOps Sentinel do phát hiện nguy cơ cao'));
  const [mitigating, setMitigating] = useState(false);

  // Target Concurrency Scaling state (Lưu cứng vào localStorage làm bộ nhớ đệm ban đầu)
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

  // Multi-Vector Trend Chart state & Hover tooltip
  const [activeVectorTab, setActiveVectorTab] = useState('all'); // 'all' | 'auth' | 'traffic' | 'exploit' | 'resource'
  const [hoveredPointIndex, setHoveredPointIndex] = useState(null);

  // Time Selection & Precision Range State (Multi-Vector Trend Chart)
  const [timePreset, setTimePreset] = useState('10m'); // '10m' | '1h' | '24h' | '7d' | '30d'
  const [customRange, setCustomRange] = useState({
    from: '',
    to: '',
    applied: false,
  });
  const [fetchingHistory, setFetchingHistory] = useState(false);

  // 4 Vector Config & Toggle Confirmation State
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

  // Persistent Incident Journal (CSDL) & Phân Trang State
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

  // Hồ Sơ Điều Tra An Ninh (Security Forensics & Incident Links N-N)
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

  // Phân trang & Bộ lọc danh sách Nguồn theo dõi đặc biệt (Quarantine Table)
  const [quarantinePage, setQuarantinePage] = useState(1);
  const [quarantinePageSize, setQuarantinePageSize] = useState(5);
  const [quarantineIpFilter, setQuarantineIpFilter] = useState('');
  const [quarantineAccountFilter, setQuarantineAccountFilter] = useState('');

  // Tạm khóa thủ công IP / Tài khoản (Manual Quarantine)
  const [showManualQuarantineModal, setShowManualQuarantineModal] = useState(false);
  const [manualQuarantineForm, setManualQuarantineForm] = useState({
    targetType: 'ip', // 'ip' | 'account'
    ipValue: '',
    accountValue: '',
    reason: 'Admin tạm khóa an ninh thủ công qua Audit Log',
    durationMinutes: 240,
  });
  const [manualQuarantineLoading, setManualQuarantineLoading] = useState(false);

  // Bộ đếm thời gian thực trên Client phục vụ đếm ngược và tự động mở khóa (mỗi 5s)
  const [currentClientTime, setCurrentClientTime] = useState(Date.now());
  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentClientTime(Date.now());
    }, 5000);
    return () => clearInterval(timer);
  }, []);

  // Helper chuẩn hóa hiển thị Masked IP theo chuẩn PO (192.168.xxx.xxx)
  const formatMaskedIp = (raw) => {
    if (!raw || raw === 'N/A' || raw === '--') return '192.168.xxx.xxx';
    const clean = String(raw).replace(/^::ffff:/, '').trim();

    // Nếu là loopback / localhost
    if (clean === '127.0.0.1' || clean === '::1' || clean === 'localhost') {
      return '127.0.xxx.xxx';
    }

    // Nếu là mockup hoàn toàn bằng x (xx.xx.xx.xx hoặc xx.xx.xxx.xxx)
    if (clean === 'xx.xx.xx.xx' || clean === 'xx.xx.xxx.xxx' || clean.startsWith('xx.xx.')) {
      return '192.168.xxx.xxx';
    }

    // Nếu đã có chứa định dạng che mờ xxx (ví dụ 113.161.xxx.xxx, xxx.xxx.12.34)
    if (clean.includes('xxx')) {
      return clean;
    }

    // Nếu có 2 octet đầu là số hợp lệ (ví dụ: 113.161.xx.xx, 42.112.xxx.xxx, 192.168.1.15)
    const matchPrefix = clean.match(/^(\d{1,3}\.\d{1,3})\./);
    if (matchPrefix) {
      return `${matchPrefix[1]}.xxx.xxx`;
    }

    // Nếu là IPv6
    if (clean.includes(':')) {
      const parts = clean.split(':');
      if (parts.length > 2) {
        return `${parts[0]}:${parts[1]}:xxxx:xxxx`;
      }
    }

    // Các trường hợp mockup / placeholder (xx.xx.xx.xx, xx.xx.xxx.xxx, '1 địa chỉ IP tập trung', 'traffic_cluster_ip')
    return '192.168.xxx.xxx';
  };

  // Helper hiển thị thời gian tạm khóa còn lại dạng thân thiện (X giờ Y phút)
  const formatRemainingTime = (minutes) => {
    if (minutes === null || minutes === undefined || isNaN(minutes)) return '--';
    const m = Math.round(Number(minutes));
    if (m <= 0) return 'Đã hết hạn tạm khóa';
    if (m < 60) return `${m} phút`;
    const hours = Math.floor(m / 60);
    const remMin = m % 60;
    return remMin > 0 ? `${hours} giờ ${remMin} phút` : `${hours} giờ`;
  };

  // Danh sách Nguồn theo dõi đặc biệt sau bộ lọc và phân trang
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

  // Socket.io connection
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
      console.error('[AIOpsPage] Error fetching data:', err);
    } finally {
      setLoading(false);
    }
  };

  // Làm mới thủ công toàn bộ dữ liệu AIOps Sentinel (Header Refresh Button)
  const handleManualRefresh = async () => {
    try {
      await fetchAIOpsData();
      await fetchIncidents(1);
      setFeedback({ ok: true, msg: t('aiops.feedback.refreshSuccess', 'Đã làm mới dữ liệu AIOps Sentinel thành công!') });
    } catch (err) {
      console.error('[AIOpsPage] Error refreshing data:', err);
      setFeedback({ ok: false, msg: t('aiops.feedback.refreshError', 'Không thể làm mới dữ liệu AIOps Sentinel.') });
    }
  };

  // Lấy dữ liệu lịch sử xu hướng theo bộ lọc (Ưu tiên bộ lọc chính xác nếu cả 2 được áp dụng)
  const fetchHistoryFiltered = async (options = {}) => {
    try {
      setFetchingHistory(true);
      const targetApplied = options.customApplied !== undefined ? options.customApplied : customRange.applied;
      const targetFrom = options.from !== undefined ? options.from : customRange.from;
      const targetTo = options.to !== undefined ? options.to : customRange.to;
      const targetPreset = options.preset !== undefined ? options.preset : timePreset;

      const params = {};
      // PO Priority Rule: Ưu tiên bộ lọc chọn chính xác thay vì bộ select nếu cả 2 được áp dụng
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
      console.error('[AIOpsPage] Error fetching history:', err);
      setFeedback({ ok: false, msg: t('aiops.feedback.historyError', 'Không thể tải dữ liệu lịch sử xu hướng.') });
    } finally {
      setFetchingHistory(false);
    }
  };

  // Mở popup xác nhận bật/tắt từng vector
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

  // Xác nhận bật/tắt vector sau khi nhấn trên popup xác nhận
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

  // Xử lý chuyển đổi bộ Preset nhanh
  const handleSelectTimePreset = (presetKey) => {
    setTimePreset(presetKey);
    setCustomRange((prev) => ({ ...prev, applied: false }));
    fetchHistoryFiltered({ preset: presetKey, customApplied: false });
    fetchIncidents(1, incidentPageSize, incidentVectorFilter, incidentStatusFilter, incidentSearch, presetKey, '', '');
  };

  // Xử lý áp dụng bộ lọc thời gian (Từ ... Đến ...)
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

  // Xử lý hủy bỏ bộ lọc thời gian để dùng lại bộ chọn nhanh
  const handleClearCustomRange = () => {
    setCustomRange({ from: '', to: '', applied: false });
    fetchHistoryFiltered({ customApplied: false, preset: timePreset });
    fetchIncidents(1, incidentPageSize, incidentVectorFilter, incidentStatusFilter, incidentSearch, timePreset, '', '');
  };

  // Xử lý làm mới bộ lọc thời gian
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
      console.error('[AIOpsPage] Error fetching incidents:', err);
    }
  };

  useEffect(() => {
    fetchAIOpsData();
    fetchIncidents(1, incidentPageSize, incidentVectorFilter, incidentStatusFilter, incidentSearch);

    // Chu kỳ cập nhật theo cấu hình metricsInterval trong Settings (1s, 3s, 5s, 10s)
    const intervalSec = settingsCtx?.settings?.metricsInterval || 3;
    const intervalMs = Math.max(1000, intervalSec * 1000);
    const interval = setInterval(() => {
      fetchAIOpsData();
    }, intervalMs);

    return () => clearInterval(interval);
  }, [settingsCtx?.settings?.metricsInterval]);

  // Gọi lại API sự cố khi thay đổi phân trang hoặc bộ lọc
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

  // Mở modal xác nhận phong tỏa IP từ bảng RCA
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

  // Xác nhận phong tỏa IP từ modal
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

      // Cập nhật ngay vào danh sách cô lập cục bộ
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

  // Mở modal Tạm khóa thủ công IP / Tài khoản
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

  // Xác nhận thực thi Tạm khóa thủ công IP hoặc Tài khoản
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
      // Bảo vệ loopback và IP bản thân
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

  // Lắng nghe sự kiện Socket.io thời gian thực
  useEffect(() => {
    if (!socket) return;

    // 1. Nhận luồng nhịp tim phần cứng & Threat Score 3s/lần
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
      console.log('[AIOps] Nguồn IP bị cô lập tự động:', blockData);
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

  // Xử lý cập nhật quy mô người dùng mục tiêu (Concurrency Scaler)
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

  // State theo dõi hành động đang thực thi trên từng nút IP / Tài khoản
  const [quarantineActionLoading, setQuarantineActionLoading] = useState(null);

  // Xử lý tạm khóa IP (Khóa 4 tiếng)
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

  // Xử lý mở khóa IP (Đồng bộ mọi dòng có cùng IP)
  const handleUnblockIp = async (ipHash, maskedIp) => {
    if (!window.confirm(t('aiops.confirmUnblockMsg', `Bạn có chắc muốn gỡ chặn và mở khóa kết nối cho địa chỉ IP ${maskedIp || ''}? Tất cả các dòng có cùng địa chỉ IP này sẽ được đồng bộ mở khóa.`))) return;
    const actionKey = `unblock_ip_${ipHash}`;
    try {
      setQuarantineActionLoading(actionKey);
      await aiopsApi.unblockIp({ ipHash });
      // Optimistic Update: Cập nhật toàn bộ các dòng có cùng ipHash thành 'unlocked' và xóa ipRemainingMinutes
      setQuarantineList(prev => prev.map(item => (item.ipHash === ipHash || item.hash === ipHash) ? { ...item, ipStatus: 'unlocked', ipRemainingMinutes: null, ipExpiresAt: null } : item));
      setFeedback({ ok: true, msg: `Đã mở khóa IP ${maskedIp || ''} thành công trên toàn bộ hệ thống.` });
    } catch (err) {
      setFeedback({ ok: false, msg: err?.response?.data?.message || err?.message || 'Gỡ chặn IP thất bại.' });
    } finally {
      setQuarantineActionLoading(null);
    }
  };

  // Xử lý khóa vĩnh viễn IP (Đồng bộ mọi dòng có cùng IP)
  const handlePermanentBanIp = async (ipHash, maskedIp) => {
    if (!window.confirm(`Bạn có chắc muốn KHÓA VĨNH VIỄN địa chỉ IP ${maskedIp || ''}? Toàn bộ kết nối từ IP này sẽ bị chặn vĩnh viễn.`)) return;
    const actionKey = `ban_ip_${ipHash}`;
    try {
      setQuarantineActionLoading(actionKey);
      await aiopsApi.permanentBanIp({ ipHash });
      setQuarantineList(prev => prev.map(item => (item.ipHash === ipHash || item.hash === ipHash) ? { ...item, ipStatus: 'permanent', ipRemainingMinutes: null, ipExpiresAt: null } : item));
      setFeedback({ ok: true, msg: `Đã khóa vĩnh viễn IP ${maskedIp || ''} thành công.` });
    } catch (err) {
      setFeedback({ ok: false, msg: err?.response?.data?.message || err?.message || 'Khóa vĩnh viễn IP thất bại.' });
    } finally {
      setQuarantineActionLoading(null);
    }
  };

  // Xử lý tạm khóa Tài khoản (Khóa 4 tiếng)
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

  // Xử lý mở khóa Tài khoản (Đồng bộ mọi dòng có cùng Tài khoản & CSDL)
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

  // Xử lý khóa vĩnh viễn Tài khoản (Đồng bộ mọi dòng có cùng Tài khoản & CSDL)
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

  // Fallback tương thích ngược
  const handleUnblock = async (hash) => {
    return handleUnblockIp(hash, '');
  };

  // Xử lý nạp và mở Modal Hồ Sơ Điều Tra An Ninh N-N
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

  // Xử lý tái hiệu chuẩn đường chuẩn theo phần cứng thực tế
  const handleCalibrate = async () => {
    try {
      setCalibrating(true);
      setFeedback(null);
      const targetVal = selectedConcurrency || 1000;
      const res = await aiopsApi.calibrate({ targetConcurrency: targetVal });
      const report = res?.data || res;
      if (report?.serverSpecs) {
        setCalibrationReport(report);
      }
      setShowCalibrateModal(false);
      setFeedback({ ok: true, msg: res?.message || t('aiops.feedback.calibrateSuccess', 'Đã tái hiệu chuẩn mô hình máy học thành công.') });
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

  // Xử lý kích hoạt bảo trì khẩn cấp 1-click
  const handleTriggerMitigation = async () => {
    try {
      setMitigating(true);
      await adminApi.setMaintenanceStatus({
        active: true,
        reason: mitigationReason.trim() || t('aiops.mitigation.defaultReason', 'Phòng vệ khẩn cấp AIOps Sentinel do phát hiện nguy cơ cao'),
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

  // Tính toán dung lượng kỳ vọng dựa trên targetConcurrency
  const baselineRpm = targetConcurrency * 10;
  const safePeakRpm = baselineRpm * 3;
  const quarantineThreshold = Math.max(150, Math.round(20 + 50 * Math.log10(targetConcurrency)));

  // Cơ chế phòng vệ cá nhân hóa: Chỉ kích hoạt bảo trì khẩn cấp khi Vector 4 (Tài nguyên) vượt ngưỡng nguy cơ sập dây chuyền (và Vector Tài nguyên đang bật)
  const isEmergencyResourceRisk = useMemo(() => {
    if (vectorConfig.resource === false) return false;
    return (
      recommendedAction === 'EMERGENCY_MAINTENANCE' ||
      (vectorScores.resource >= 85) ||
      (vectorScores.resource >= 70 && (sample?.errorRate5xx || 0) >= 0.15 && (sample?.eventLoopLagMs || 0) >= 250)
    );
  }, [recommendedAction, vectorScores.resource, sample, vectorConfig.resource]);

  // Hàm tiện ích lấy style theo điểm số của từng vectơ
  const getVectorTheme = (score) => {
    if (score >= 80) return { bg: 'bg-red-500', text: 'text-red-700', badge: 'bg-red-100 text-red-800 border-red-300', label: t('aiops.theme.critical', 'Nguy cấp') };
    if (score >= 60) return { bg: 'bg-orange-500', text: 'text-orange-700', badge: 'bg-orange-100 text-orange-800 border-orange-300', label: t('aiops.theme.warning', 'Cảnh báo') };
    if (score >= 30) return { bg: 'bg-amber-500', text: 'text-amber-700', badge: 'bg-amber-100 text-amber-800 border-amber-300', label: t('aiops.theme.watching', 'Theo dõi') };
    return { bg: 'bg-emerald-500', text: 'text-emerald-700', badge: 'bg-emerald-100 text-emerald-800 border-emerald-300', label: t('aiops.theme.normal', 'Bình thường') };
  };

  // Tính toán màu sắc hiển thị theo Threat Score tổng hợp
  const theme = useMemo(() => {
    if (threatScore >= 90) {
      return {
        badgeBg: 'bg-red-100 text-red-800 border-red-300',
        color: '#ef4444',
        label: t('aiops.statusCritical', 'NGUY CẤP (CRITICAL)'),
        glow: 'ring-4 ring-red-400/40',
        border: 'border-red-400 bg-red-50/50',
      };
    }
    if (threatScore >= 80) {
      return {
        badgeBg: 'bg-orange-100 text-orange-800 border-orange-300',
        color: '#f97316',
        label: t('aiops.statusWarning', 'CẢNH BÁO CAO (WARNING)'),
        glow: 'ring-4 ring-orange-400/30',
        border: 'border-orange-400 bg-orange-50/50',
      };
    }
    if (threatScore >= 60) {
      return {
        badgeBg: 'bg-amber-100 text-amber-800 border-amber-300',
        color: '#f59e0b',
        label: t('aiops.statusElevated', 'TĂNG CAO (ELEVATED)'),
        glow: 'ring-4 ring-amber-400/20',
        border: 'border-amber-400 bg-amber-50/40',
      };
    }
    return {
      badgeBg: 'bg-emerald-100 text-emerald-800 border-emerald-300',
      color: '#10b981',
      label: t('aiops.statusNormal', 'BÌNH THƯỜNG (NORMAL)'),
      glow: '',
      border: 'border-emerald-300 bg-emerald-50/40',
    };
  }, [threatScore, t]);

  // Chuẩn bị đường vẽ SVG độc lập cho 4 Vectơ Rủi Ro
  const chartSvgPaths = useMemo(() => {
    if (!historyData || historyData.length === 0) {
      return {
        samples: [],
        auth: { path: '', area: '', points: [], color: '#f59e0b', name: t('aiops.vectors.auth', '1. Xác Thực & Danh Tính'), id: 'auth' },
        traffic: { path: '', area: '', points: [], color: '#3b82f6', name: t('aiops.vectors.traffic', '2. Lưu Lượng & DoS'), id: 'traffic' },
        exploit: { path: '', area: '', points: [], color: '#f43f5e', name: t('aiops.vectors.exploit', '3. Khai Thác Lỗ Hổng'), id: 'exploit' },
        resource: { path: '', area: '', points: [], color: '#0d9488', name: t('aiops.vectors.resource', '4. Sức Khỏe Tài Nguyên'), id: 'resource' },
        composite: { path: '', area: '', points: [], color: '#8b5cf6', name: t('aiops.vectors.composite', 'Điểm Tổng Hợp (Composite)'), id: 'composite' },
      };
    }
    const width = 800;
    const height = 180;
    const padding = 35;

    const maxVal = 100;
    const minVal = 0;
    const count = historyData.length;
    const stepX = count > 1 ? (width - 2 * padding) / (count - 1) : 0;

    // Trích xuất điểm số của 4 vector cho từng mẫu lịch sử
    const samples = historyData.map((d, i) => {
      const x = count === 1 ? width / 2 : padding + i * stepX;
      const vs = d.vectorScores || {};
      
      const authScore = vs.auth !== undefined ? vs.auth : (d.failedLogins ? Math.min(100, d.failedLogins * 10) : 0);
      const trafficScore = vs.traffic !== undefined ? vs.traffic : (d.requestsPerMin ? Math.min(100, Math.round(d.requestsPerMin / 30)) : 0);
      const exploitScore = vs.exploit !== undefined ? vs.exploit : (d.malformedRequests ? Math.min(100, d.malformedRequests * 25) : 0);
      const resourceScore = vs.resource !== undefined ? vs.resource : (d.cpuPercent || d.ramPercent ? Math.max(d.cpuPercent || 0, d.ramPercent || 0) : 0);
      // Điểm tổng hợp Composite: Chỉ tính max trên các vector đang BẬT
      const activeForComp = [];
      if (vectorConfig.auth !== false) activeForComp.push(authScore);
      if (vectorConfig.traffic !== false) activeForComp.push(trafficScore);
      if (vectorConfig.exploit !== false) activeForComp.push(exploitScore);
      if (vectorConfig.resource !== false) activeForComp.push(resourceScore);
      const fallbackComp = activeForComp.length > 0 ? Math.max(...activeForComp) : 0;
      const compScore = d.threatScore ?? fallbackComp;

      const getY = (val) => height - 25 - ((Math.min(100, Math.max(0, val)) - minVal) / (maxVal - minVal)) * 130;

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
  }, [historyData, vectorConfig, t]);

  // Cấu hình và tính toán vạch số liệu trục X (Chuẩn hóa bước nhảy 5 mẫu cho 10m/1h và 4 mẫu cho 24h/7d/30d)
  const xAxisConfig = useMemo(() => {
    const width = 800;
    const padding = 35;
    const usableWidth = width - 2 * padding;

    // A. Ưu tiên Bộ Lọc Thời Gian (Custom Time Range)
    if (customRange.applied && customRange.from && customRange.to) {
      const d1 = new Date(customRange.from).getTime();
      const d2 = new Date(customRange.to).getTime();
      const diffMs = Math.max(1000, d2 - d1);

      let unit = t('common.minute', 'Phút');
      const ticks = [];

      if (diffMs <= 90 * 60 * 1000) {
        // <= 1.5 giờ: 60 mẫu, 5 mẫu đánh 1 lần (0 -> 5 -> 10 -> ... -> 60)
        unit = t('common.minute', 'Phút');
        const step = 5;
        const totalSamples = 60;
        for (let i = 0; i <= totalSamples; i += step) {
          ticks.push({
            x: padding + (i / totalSamples) * usableWidth,
            label: String(i),
          });
        }
      } else if (diffMs <= 36 * 3600 * 1000) {
        // <= 36 giờ: 48 mẫu, 4 mẫu đánh 1 lần (0 -> 4 -> 8 -> ... -> 48)
        unit = t('common.hour', 'Giờ');
        const step = 4;
        const totalSamples = 48;
        for (let i = 0; i <= totalSamples; i += step) {
          ticks.push({
            x: padding + (i / totalSamples) * usableWidth,
            label: String(i),
          });
        }
      } else {
        // > 36 giờ: 4 mẫu đánh 1 lần (0 -> 4 -> 8 -> ... -> 48)
        unit = t('common.day', 'Ngày');
        const step = 4;
        const totalSamples = 48;
        for (let i = 0; i <= totalSamples; i += step) {
          ticks.push({
            x: padding + (i / totalSamples) * usableWidth,
            label: String(i),
          });
        }
      }

      return {
        title: t('aiops.chart.title', 'Biểu Đồ Xu Hướng 4 Vectơ Rủi Ro'),
        unit,
        ticks,
      };
    }

    // B. Bộ Chọn Thời Gian Quan Sát (Presets):
    // 10 phút, 1 giờ: 5 mẫu đánh 1 lần (0 -> 5 -> 10 -> 15 -> ... -> 60)
    // 24 giờ, 7 ngày, 1 tháng: 4 mẫu đánh 1 lần (0 -> 4 -> 8 -> 12 -> ... -> 48)
    if (timePreset === '1h') {
      const step = 5;
      const totalSamples = 60;
      const ticks = [];
      for (let i = 0; i <= totalSamples; i += step) {
        ticks.push({
          x: padding + (i / totalSamples) * usableWidth,
          label: String(i),
        });
      }
      return {
        title: t('aiops.chart.preset1h', '1 giờ qua'),
        unit: t('common.minute', 'Phút'),
        ticks,
      };
    }

    if (timePreset === '24h' || timePreset === 'day') {
      const step = 4;
      const totalSamples = 48;
      const ticks = [];
      for (let i = 0; i <= totalSamples; i += step) {
        ticks.push({
          x: padding + (i / totalSamples) * usableWidth,
          label: String(i),
        });
      }
      return {
        title: t('aiops.chart.preset24h', '24 giờ qua'),
        unit: t('common.hour', 'Giờ'),
        ticks,
      };
    }

    if (timePreset === '7d') {
      const step = 4;
      const totalSamples = 48;
      const ticks = [];
      for (let i = 0; i <= totalSamples; i += step) {
        ticks.push({
          x: padding + (i / totalSamples) * usableWidth,
          label: String(i),
        });
      }
      return {
        title: t('aiops.chart.preset7d', '7 ngày qua'),
        unit: t('common.day', 'Ngày'),
        ticks,
      };
    }

    if (timePreset === '30d' || timePreset === 'month') {
      const step = 4;
      const totalSamples = 60;
      const ticks = [];
      for (let i = 0; i <= totalSamples; i += step) {
        ticks.push({
          x: padding + (i / totalSamples) * usableWidth,
          label: String(i),
        });
      }
      return {
        title: t('aiops.chart.preset30d', '1 tháng qua'),
        unit: t('common.day', 'Ngày'),
        ticks,
      };
    }

    // Mặc định: 10 phút qua (10m / realtime: 60 mẫu, 5 mẫu đánh 1 lần)
    const step = 5;
    const totalSamples = 60;
    const ticks = [];
    for (let i = 0; i <= totalSamples; i += step) {
      ticks.push({
        x: padding + (i / totalSamples) * usableWidth,
        label: String(i),
      });
    }
    return {
      title: t('aiops.chart.preset10m', '10 phút qua'),
      unit: t('common.minute', 'Phút'),
      ticks,
    };
  }, [timePreset, customRange, t]);

  // Fallback tương thích ngược
  const chartSvgPath = chartSvgPaths.composite;

  return (
    <div className="max-w-[1440px] mx-auto w-full p-4 md:p-6 space-y-6 bg-surface-bright min-h-full">
      {/* Tiêu đề trang & Thanh công cụ */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-outline-variant pb-4">
        <div>
          <h1 className="font-display-md text-display-md font-bold text-on-surface m-0 tracking-tight flex items-center gap-2.5">
            <span className="material-symbols-outlined text-primary text-[32px]">security</span>
            {t('aiops.title', 'AIOps Sentinel — Giám Sát Máy Học & Phòng Vệ Tự Động')}
          </h1>
        </div>

        <div className="flex items-center gap-2.5 flex-wrap">
          <button
            onClick={handleManualRefresh}
            disabled={loading}
            className="px-3.5 py-2 bg-white hover:bg-gray-50 border border-outline-variant text-on-surface text-xs font-semibold rounded-xl shadow-2xs transition-all cursor-pointer flex items-center gap-1.5"
          >
            <span className={`material-symbols-outlined text-[16px] ${loading ? 'animate-spin' : ''}`}>refresh</span>
            <span>{t('common.refresh', 'Làm Mới')}</span>
          </button>

          <button
            onClick={() => setShowCalibrateModal(true)}
            disabled={calibrating}
            className="px-3.5 py-2 bg-white hover:bg-blue-50 border border-blue-200 text-blue-700 text-xs font-semibold rounded-xl shadow-2xs transition-all cursor-pointer flex items-center gap-1.5"
            title={t('aiops.calibrate.btnTooltip', 'Nhấn để tìm hiểu công dụng và thực hiện tái hiệu chuẩn baseline máy học')}
          >
            <span className="material-symbols-outlined text-[16px]">tune</span>
            <span>{calibrating ? t('aiops.calibrate.calibratingBtn', 'Đang hiệu chuẩn...') : t('aiops.calibrate.btn', 'Tái Hiệu Chuẩn Baseline')}</span>
            <span className="material-symbols-outlined text-[14px] text-blue-400 hover:text-blue-600">help</span>
          </button>

          {isEmergencyResourceRisk && (
            <button
              onClick={() => setShowMitigationModal(true)}
              className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white text-xs font-bold rounded-xl shadow-xs transition-all cursor-pointer flex items-center gap-1.5 animate-pulse"
              title={t('aiops.mitigation.emergencyTooltip', 'Chỉ hiển thị khi Vector 4 (Tài nguyên) vượt ngưỡng nguy cơ sập dây chuyền')}
            >
              <span className="material-symbols-outlined text-[18px]">emergency</span>
              <span>{t('aiops.mitigation.emergencyBtn', '1-Click Bảo Trì Khẩn Cấp')}</span>
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
      {/* THẺ TÌNH TRẠNG HỆ THỐNG (SYSTEM OPERATIONAL STATUS) */}
      {/* ======================================================== */}
      <div
        className={`rounded-2xl border p-4.5 transition-all shadow-xs ${
          maintenanceStatus?.active
            ? maintenanceStatus.isEmergency
              ? 'border-red-300 bg-red-50/90 text-red-950'
              : 'border-amber-300 bg-amber-50/90 text-amber-950'
            : 'border-emerald-300 bg-emerald-50/80 text-emerald-950'
        }`}
      >
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-3.5">
          <div className="flex items-center gap-3.5">
            <div
              className={`w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 shadow-2xs ${
                maintenanceStatus?.active
                  ? maintenanceStatus.isEmergency
                    ? 'bg-red-600 text-white animate-pulse'
                    : 'bg-amber-600 text-white'
                  : 'bg-emerald-600 text-white'
              }`}
            >
              <span className="material-symbols-outlined text-[24px]">
                {maintenanceStatus?.active ? (maintenanceStatus.isEmergency ? 'error' : 'engineering') : 'check_circle'}
              </span>
            </div>

            <div>
              <div className="flex items-center gap-2 flex-wrap">
                <h2 className="text-sm font-bold m-0 tracking-tight">
                  {t('aiops.systemStatusLabel', 'Tình Trạng Hệ Thống:')}
                </h2>
                {maintenanceStatus?.active ? (
                  <span
                    className={`px-3 py-1 rounded-full text-xs font-bold tracking-wide flex items-center gap-1.5 shadow-2xs border ${
                      maintenanceStatus.isEmergency
                        ? 'bg-red-100 text-red-800 border-red-300'
                        : 'bg-amber-100 text-amber-900 border-amber-300'
                    }`}
                  >
                    <span className="w-2 h-2 rounded-full bg-red-500 animate-ping" />
                    <span>{t('aiops.statusMaintenance', 'Đang bảo trì')}</span>
                    <span className="text-[10px] opacity-80 uppercase">
                      ({maintenanceStatus.isEmergency ? t('broadcast.levels.critical', 'Khẩn cấp') : t('broadcast.banner.silentBadge', 'Kỹ thuật')})
                    </span>
                  </span>
                ) : (
                  <span className="px-3 py-1 rounded-full text-xs font-bold tracking-wide flex items-center gap-1.5 shadow-2xs border bg-emerald-100 text-emerald-800 border-emerald-300">
                    <span className="w-2 h-2 rounded-full bg-emerald-500" />
                    <span>{t('aiops.statusRunning', 'Đang hoạt động')}</span>
                  </span>
                )}
              </div>

              <p className="text-xs opacity-90 mt-1 m-0">
                {maintenanceStatus?.active
                  ? `${t('aiops.banner.maintenanceActive', { reason: maintenanceStatus.reason || t('broadcast.feedback.maintenanceTitle', 'Bảo trì hệ thống') })}${
                      maintenanceStatus.activatedAt ? t('aiops.banner.fromTime', { time: formatDateTime(maintenanceStatus.activatedAt) }) : ''
                    }`
                  : t('aiops.banner.runningActive', 'Các tiến trình lõi, lưu lượng và kết nối Client-app & Admin-web đang vận hành trơn tru không bị giới hạn.')}
              </p>
            </div>
          </div>

          {/* Thông tin nhanh & Điều hướng */}
          <div className="flex items-center gap-2 self-start md:self-center flex-wrap">
            <div className="flex items-center gap-1.5 px-3 py-1.5 bg-white/80 border border-outline-variant/60 rounded-xl text-[11px] font-medium text-slate-700 shadow-2xs">
              <span className="text-slate-400">Threat Score:</span>
              <b className={threatScore >= 70 ? 'text-red-600' : 'text-emerald-700'}>{threatScore}/100</b>
            </div>
            <div className="flex items-center gap-1.5 px-3 py-1.5 bg-white/80 border border-outline-variant/60 rounded-xl text-[11px] font-medium text-slate-700 shadow-2xs">
              <span className="text-slate-400">{t('aiops.scaler.currentApplied', 'Quy mô:')}</span>
              <b className="text-primary">{targetConcurrency.toLocaleString()} {t('aiops.scaler.unitCcu', 'CCU')}</b>
            </div>
            {maintenanceStatus?.active && (
              <a
                href="/broadcast"
                className="px-3 py-1.5 bg-white hover:bg-slate-50 border border-amber-300 text-amber-900 text-xs font-bold rounded-xl shadow-2xs transition-all flex items-center gap-1 cursor-pointer no-underline"
              >
                <span className="material-symbols-outlined text-[15px] text-amber-600">settings</span>
                <span>{t('aiops.manageMaintenanceBtn', 'Điều Hành Bảo Trì')}</span>
              </a>
            )}
          </div>
        </div>
      </div>

      {/* ======================================================== */}
      {/* KHỐI 0: BỘ ĐIỀU KHIỂN QUY MÔ NGƯỜI DÙNG & MÔ HÌNH CHỊU TẢI DUNG LƯỢNG */}
      {/* ======================================================== */}
      <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-3 border-b border-outline-variant pb-3">
          <div>
            <h2 className="text-sm font-bold text-on-surface m-0 flex items-center gap-2">
              <span className="material-symbols-outlined text-primary text-[20px]">group</span>
              {t('aiops.scaler.title', 'Quy Mô Người Dùng Mục Tiêu & Mô Hình Chịu Tải')}
            </h2>
          </div>

          <div className="flex items-center gap-2 flex-wrap">
            {[
              { label: t('aiops.scaler.preset500', '500 Người'), val: 500 },
              { label: t('aiops.scaler.preset1000', '1.000 Người'), val: 1000 },
              { label: t('aiops.scaler.preset5000', '5.000 Người'), val: 5000 },
              { label: t('aiops.scaler.preset10000', '10.000 Người'), val: 10000 },
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
          <div className="p-4 rounded-xl bg-slate-50 border border-slate-200/80 flex flex-col justify-center space-y-2">
            <div>
              <label className="block text-[11px] font-bold text-slate-700 uppercase tracking-wider mb-1">
                {t('aiops.scaler.inputLabel', 'Số người dùng đồng thời (N)')}
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
                  placeholder={t('aiops.scaler.inputPlaceholder', 'VD: 1000, 2000')}
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
                  <span>{t('aiops.scaler.applyBtn', 'Áp Dụng')}</span>
                </button>
              </div>
            </div>
          </div>

          {/* Thẻ 1: Baseline RPM kỳ vọng */}
          <div className="p-3.5 rounded-xl border bg-surface-container-lowest border-outline-variant/60 flex flex-col justify-between">
            <div className="flex items-center justify-between text-slate-500">
              <span className="text-[11px] font-medium">{t('aiops.scaler.baselineRpmTitle', 'Baseline RPM dự kiến')}</span>
              <span className="material-symbols-outlined text-[16px] text-blue-500">trending_up</span>
            </div>
            <div className="my-1.5">
              <div className="text-xl font-bold text-on-surface font-mono">
                {baselineRpm.toLocaleString('vi-VN')}
                <span className="text-[11px] font-normal text-slate-500 ml-1">{t('aiops.scaler.unitRpm', 'req/phút')}</span>
              </div>
            </div>
            <div className="text-[10px] text-slate-500">
              {t('aiops.scaler.formula', 'Công thức:')} <code className="font-mono text-slate-700 font-semibold">{targetConcurrency.toLocaleString()} × 10 RPM</code>
            </div>
          </div>

          {/* Thẻ 2: Safe Peak Ceiling (3x) */}
          <div className="p-3.5 rounded-xl border bg-surface-container-lowest border-outline-variant/60 flex flex-col justify-between">
            <div className="flex items-center justify-between text-slate-500">
              <span className="text-[11px] font-medium">{t('aiops.scaler.safePeakTitle', 'Trần Đỉnh An Toàn (Safe Peak)')}</span>
              <span className="material-symbols-outlined text-[16px] text-emerald-500">verified_user</span>
            </div>
            <div className="my-1.5">
              <div className="text-xl font-bold text-on-surface font-mono">
                {safePeakRpm.toLocaleString('vi-VN')}
                <span className="text-[11px] font-normal text-slate-500 ml-1">{t('aiops.scaler.unitRpm', 'req/phút')}</span>
              </div>
            </div>
            <div className="text-[10px] text-slate-500">
              {t('aiops.scaler.safePeakDesc', 'Trần an toàn 3× Baseline (Chưa kích hoạt DoS)')}
            </div>
          </div>

          {/* Thẻ 3: Ngưỡng cách ly IP đơn lẻ */}
          <div className="p-3.5 rounded-xl border bg-surface-container-lowest border-outline-variant/60 flex flex-col justify-between">
            <div className="flex items-center justify-between text-slate-500">
              <span className="text-[11px] font-medium">{t('aiops.scaler.firewallThresholdTitle', 'Ngưỡng Chặn Tường Lửa IP')}</span>
              <span className="material-symbols-outlined text-[16px] text-red-500">security</span>
            </div>
            <div className="my-1.5">
              <div className="text-xl font-bold text-on-surface font-mono">
                {quarantineThreshold}
                <span className="text-[11px] font-normal text-slate-500 ml-1">{t('aiops.scaler.unitReq10s', 'req/10s')}</span>
              </div>
            </div>
            <div className="text-[10px] text-slate-500">
              {t('aiops.scaler.firewallThresholdDesc', '20 + 50×log10(N) (Tự động cách ly IP càn quét)')}
            </div>
          </div>
        </div>

        {/* Kết quả Tái Hiệu Chuẩn Thực Tế theo phần cứng máy chủ */}
        {calibrationReport && (
          <div className="mt-4 p-4 rounded-xl bg-blue-50/80 border border-blue-200/90 flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <span className="material-symbols-outlined text-[18px] text-blue-600">tune</span>
                <span className="text-xs font-bold text-blue-950">
                  {t('aiops.calibrate.reportTitle', 'Báo Cáo Hiệu Chuẩn Baseline Phần Cứng Thực Tế')}
                </span>
                <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                  calibrationReport.capacityAssessment?.isOverCapacity
                    ? 'bg-red-100 text-red-700 border border-red-300'
                    : calibrationReport.capacityAssessment?.isNearLimit
                    ? 'bg-amber-100 text-amber-700 border border-amber-300'
                    : 'bg-emerald-100 text-emerald-700 border border-emerald-300'
                }`}>
                  {calibrationReport.capacityAssessment?.status || 'OPTIMAL'}
                </span>
              </div>
              <p className="text-[11px] text-slate-600 leading-relaxed">
                {calibrationReport.capacityAssessment?.recommendation}
              </p>
              <div className="text-[10px] text-slate-500 flex items-center gap-3 pt-0.5 flex-wrap">
                <span>💻 Máy chủ: <strong>{calibrationReport.serverSpecs?.cpuCores} Cores</strong> ({calibrationReport.serverSpecs?.platform})</span>
                <span>🗄️ Tổng RAM: <strong>{((calibrationReport.serverSpecs?.totalRamMb || 0) / 1024).toFixed(1)} GB</strong></span>
                <span>👥 Quy mô áp dụng: <strong>{calibrationReport.targetConcurrency?.toLocaleString('vi-VN')} CCU</strong></span>
                <span>⏱️ Cập nhật: {new Date(calibrationReport.calibratedAt || Date.now()).toLocaleTimeString('vi-VN')}</span>
              </div>
            </div>
            <div className="flex items-center gap-2.5 flex-wrap flex-shrink-0">
              <div className="bg-white px-3 py-1.5 rounded-lg border border-blue-100 text-center shadow-2xs">
                <div className="text-[10px] text-slate-400">CPU Kỳ Vọng</div>
                <div className="text-xs font-bold text-slate-800">{calibrationReport.calculatedMetrics?.expectedCpuPercent}%</div>
              </div>
              <div className="bg-white px-3 py-1.5 rounded-lg border border-blue-100 text-center shadow-2xs">
                <div className="text-[10px] text-slate-400">RAM Kỳ Vọng</div>
                <div className="text-xs font-bold text-slate-800">{calibrationReport.calculatedMetrics?.expectedRamPercent}%</div>
              </div>
              <div className="bg-white px-3 py-1.5 rounded-lg border border-blue-100 text-center shadow-2xs">
                <div className="text-[10px] text-slate-400">Event Loop Lag</div>
                <div className="text-xs font-bold text-slate-800">{calibrationReport.calculatedMetrics?.expectedEventLoopLagMs} ms</div>
              </div>
            </div>
          </div>
        )}
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
                {t('aiops.threatScoreTitle', 'Hệ Số Đe Dọa (Threat Score)')}
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

              {/* Chú thích thang điểm: dạng lưới 2x2 badges gọn gàng, tránh dàn ngang chen chúc */}
              <div className="grid grid-cols-2 gap-1.5 w-full max-w-[240px] text-[10px] font-medium text-slate-600 mt-2">
                <div className="flex items-center gap-1.5 px-2 py-0.5 rounded bg-emerald-50 text-emerald-800 border border-emerald-200">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                  <span>{t('aiops.gauge.safe', '0-59: An toàn')}</span>
                </div>
                <div className="flex items-center gap-1.5 px-2 py-0.5 rounded bg-amber-50 text-amber-800 border border-amber-200">
                  <span className="w-1.5 h-1.5 rounded-full bg-amber-500" />
                  <span>{t('aiops.gauge.elevated', '60-79: Tăng cao')}</span>
                </div>
                <div className="flex items-center gap-1.5 px-2 py-0.5 rounded bg-orange-50 text-orange-800 border border-orange-200">
                  <span className="w-1.5 h-1.5 rounded-full bg-orange-500" />
                  <span>{t('aiops.gauge.warning', '80-89: Cảnh báo')}</span>
                </div>
                <div className="flex items-center gap-1.5 px-2 py-0.5 rounded bg-red-50 text-red-800 border border-red-200">
                  <span className="w-1.5 h-1.5 rounded-full bg-red-500" />
                  <span>{t('aiops.gauge.critical', '90+: Nguy cấp')}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* CỘT 2: CHỈ SỐ TẤN CÔNG & XÂM NHẬP (SECURITY ATTACK SIGNALS) */}
        <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4">
          <div className="flex items-center justify-between border-b border-outline-variant pb-2.5">
            <h2 className="text-xs font-bold uppercase tracking-wider text-on-surface m-0 flex items-center gap-1.5">
              <span className="material-symbols-outlined text-[18px] text-red-500">shield_with_heart</span>
              {t('aiops.signals.attackSignalsTitle', 'Tín Hiệu Xâm Nhập & Tấn Công')}
            </h2>
            <span className="text-[10px] text-slate-500">
              {t('aiops.signals.windowFrequency', { n: statusData?.windowSeconds || 10 }, `Tần suất: ${statusData?.windowSeconds || 10} Giây`)}
            </span>
          </div>

          <div className="grid grid-cols-2 gap-3 text-xs">
            {/* Failed Logins */}
            <div className={`p-3 rounded-xl border flex flex-col justify-center ${sample.failedLogins >= 5 ? 'bg-red-50 border-red-200' : 'bg-surface-container-lowest border-outline-variant/60'}`}>
              <div className="text-[11px] text-slate-500 font-medium">{t('aiops.signals.failedLogins', 'Đăng nhập sai')}</div>
              <div className="text-lg font-bold text-on-surface mt-1 flex items-baseline justify-between">
                <span>{sample.failedLogins ?? 0}</span>
                <span className="text-[10px] text-slate-400">{t('aiops.signals.times', 'lần')}</span>
              </div>
            </div>

            {/* Token Reuse Attacks */}
            <div className={`p-3 rounded-xl border flex flex-col justify-center ${sample.tokenReuseAttacks >= 1 ? 'bg-red-50 border-red-200' : 'bg-surface-container-lowest border-outline-variant/60'}`}>
              <div className="text-[11px] text-slate-500 font-medium">{t('aiops.signals.tokenReuse', 'Tái dùng Token thu hồi')}</div>
              <div className="text-lg font-bold text-on-surface mt-1 flex items-baseline justify-between">
                <span>{sample.tokenReuseAttacks ?? 0}</span>
                <span className="text-[10px] text-slate-400">{t('aiops.signals.times', 'lần')}</span>
              </div>
            </div>

            {/* Malformed Requests */}
            <div className={`p-3 rounded-xl border flex flex-col justify-center ${sample.malformedRequests >= 3 ? 'bg-amber-50 border-amber-200' : 'bg-surface-container-lowest border-outline-variant/60'}`}>
              <div className="text-[11px] text-slate-500 font-medium">{t('aiops.signals.malformedReq', 'Request độc hại (SQLi)')}</div>
              <div className="text-lg font-bold text-on-surface mt-1 flex items-baseline justify-between">
                <span>{sample.malformedRequests ?? 0}</span>
                <span className="text-[10px] text-slate-400">{t('aiops.signals.samples', 'mẫu')}</span>
              </div>
            </div>

            {/* Distinct IP Count */}
            <div className="p-3 rounded-xl border bg-surface-container-lowest border-outline-variant/60 flex flex-col justify-center">
              <div className="text-[11px] text-slate-500 font-medium">{t('aiops.signals.ipDispersion', 'Độ phân tán IP')}</div>
              <div className="text-lg font-bold text-on-surface mt-1 flex items-baseline justify-between">
                <span>{sample.distinctIpsCount ?? 0}</span>
                <span className="text-[10px] text-slate-400">{t('aiops.signals.ips', 'IPs')}</span>
              </div>
            </div>
          </div>
        </div>

        {/* CỘT 3: CHỈ SỐ CHỊU TẢI & PHẦN CỨNG (SYSTEM RESILIENCE SIGNALS) */}
        <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4">
          <div className="flex items-center justify-between border-b border-outline-variant pb-2.5">
            <h2 className="text-xs font-bold uppercase tracking-wider text-on-surface m-0 flex items-center gap-1.5">
              <span className="material-symbols-outlined text-[18px] text-primary">memory</span>
              {t('aiops.signals.resilienceTitle', 'Sức Chịu Tải & Phần Cứng')}
            </h2>
          </div>

          <div className="grid grid-cols-2 gap-3 text-xs">
            {/* Event Loop Lag */}
            <div className={`p-3 rounded-xl border flex flex-col justify-center ${sample.eventLoopLagMs >= 100 ? 'bg-red-50 border-red-200' : 'bg-surface-container-lowest border-outline-variant/60'}`}>
              <div className="text-[11px] text-slate-500 font-medium">{t('aiops.signals.eventLoopLag', 'Event Loop Lag')}</div>
              <div className="text-lg font-bold text-on-surface mt-1 flex items-baseline justify-between">
                <span>{sample.eventLoopLagMs ?? 0}</span>
                <span className="text-[10px] text-slate-400">{t('aiops.signals.unitMs', 'ms')}</span>
              </div>
            </div>

            {/* CPU Usage */}
            <div className={`p-3 rounded-xl border flex flex-col justify-center ${sample.cpuPercent >= 85 ? 'bg-amber-50 border-amber-200' : 'bg-surface-container-lowest border-outline-variant/60'}`}>
              <div className="text-[11px] text-slate-500 font-medium">{t('aiops.signals.cpuPercent', 'CPU Hệ Thống')}</div>
              <div className="text-lg font-bold text-on-surface mt-1 flex items-baseline justify-between">
                <span>{sample.cpuPercent ?? 0}%</span>
                {sample.cpuCores ? (
                  <span className="text-[11px] font-mono text-slate-500 font-normal">
                    {sample.cpuCores} cores
                  </span>
                ) : null}
              </div>
            </div>

            {/* RAM Usage */}
            <div className={`p-3 rounded-xl border ${sample.ramPercent >= 90 ? 'bg-red-50 border-red-200' : 'bg-surface-container-lowest border-outline-variant/60'}`}>
              <div className="text-[11px] text-slate-500 font-medium">{t('aiops.signals.ramPercent', 'Bộ nhớ RAM')}</div>
              <div className="text-base font-bold text-on-surface mt-1 font-mono">
                {sample.ramUsedMb && sample.ramTotalMb ? (
                  <span>
                    {sample.ramUsedMb.toLocaleString()} / {sample.ramTotalMb.toLocaleString()} MB
                  </span>
                ) : (
                  <span>-- / -- MB</span>
                )}
              </div>
              <div className="text-[10px] text-slate-500 mt-1">
                {t('aiops.signals.memoryLeakRisk', { percent: sample.ramPercent ?? 0 }, `Nguy cơ Memory Leak: ${sample.ramPercent ?? 0}%`)}
              </div>
            </div>

            {/* Lưu lượng Request */}
            <div className="p-3 rounded-xl border bg-surface-container-lowest border-outline-variant/60">
              <div className="text-[11px] text-slate-500 font-medium">{t('aiops.signals.estimatedTraffic', 'Lưu lượng ước tính')}</div>
              <div className="text-lg font-bold text-on-surface mt-1 flex items-baseline justify-between">
                <span>{sample.requestsPerMin ?? 0}</span>
                <span className="text-[10px] text-slate-400">{t('aiops.signals.unitRpmShort', 'req/p')}</span>
              </div>
              <div className="text-[10px] text-slate-500 mt-1">4xx: {Math.round((sample.errorRate4xx || 0) * 100)}% | 5xx: {Math.round((sample.errorRate5xx || 0) * 100)}%</div>
            </div>
          </div>
        </div>
      </div>
      {/* KHỐI 1.5: 4 VECTƠ RỦI RO ĐỘC LẬP & CÁ NHÂN HÓA PHÒNG VỆ */}
      {/* ======================================================== */}
      <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-outline-variant pb-3">
          <div>
            <h2 className="text-sm font-bold text-on-surface m-0 flex items-center gap-2">
              <span className="material-symbols-outlined text-primary text-[20px]">hub</span>
              {t('aiops.multiVector.title', '4 Vectơ Rủi Ro Độc Lập & Cá Nhân Hóa Phòng Vệ (Multi-Vector Risk Architecture)')}
            </h2>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {/* VECTƠ 1: XÁC THỰC & DANH TÍNH */}
          {(() => {
            const vScore = vectorScores.auth || 0;
            const vTheme = getVectorTheme(vScore);
            const isQuarantining = quarantineList.length > 0 || vScore >= 70;
            const isEnabled = vectorConfig.auth !== false;
            return (
              <div className={`p-4 rounded-xl border flex flex-col justify-between space-y-3 transition-all ${
                isEnabled ? 'border-outline-variant/70 bg-surface-container-lowest' : 'border-slate-300 bg-slate-50/70 opacity-90'
              }`}>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-amber-600">badge</span>
                      {t('aiops.vectors.auth', '1. Xác Thực & Danh Tính')}
                    </span>
                    <button
                      type="button"
                      role="switch"
                      aria-checked={isEnabled}
                      data-testid="toggle-vector-auth"
                      onClick={() => handleOpenToggleVectorModal('auth')}
                      className={`relative inline-flex h-5 w-9 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                        isEnabled ? 'bg-emerald-600' : 'bg-slate-300'
                      }`}
                      title={isEnabled ? t('aiops.toggleVector.titleDisable', 'Xác nhận TẮT Vector') : t('aiops.toggleVector.titleEnable', 'Xác nhận BẬT Vector')}
                    >
                      <span
                        className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                          isEnabled ? 'translate-x-4' : 'translate-x-0'
                        }`}
                      />
                    </button>
                  </div>

                  {!isEnabled && (
                    <div className="px-2 py-1 rounded bg-amber-50 border border-amber-200 text-amber-900 text-[10px] font-semibold flex items-center gap-1">
                      <span className="material-symbols-outlined text-[13px] text-amber-600">visibility</span>
                      <span>{t('aiops.multiVector.measureOnlyNotice', 'Chế độ chỉ đo lường — Bỏ qua khỏi Threat Score')}</span>
                    </div>
                  )}

                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">{t('aiops.multiVector.pointsMax', '/ 100 điểm')}</span>
                  </div>
                  {/* Progress bar */}
                  <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                    <div
                      className={`h-full ${isEnabled ? vTheme.bg : 'bg-slate-400'} transition-all duration-500`}
                      style={{ width: `${Math.min(100, Math.max(0, vScore))}%` }}
                    />
                  </div>
                </div>

                <div className="space-y-1.5 pt-2 border-t border-slate-100 text-[11px]">
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.authFailures', 'Đăng nhập lỗi:')}</span>
                    <strong className="font-mono">{sample.failedLogins ?? 0} {t('aiops.signals.times', 'lần')}</strong>
                  </div>
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.tokenReuse', 'Tái dùng token hủy:')}</span>
                    <strong className="font-mono">{sample.tokenReuseAttacks ?? 0} {t('aiops.signals.times', 'lần')}</strong>
                  </div>
                  {/* Badge hành động phòng vệ động */}
                  <div className="pt-1">
                    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold border ${
                      !isEnabled
                        ? 'bg-slate-100 text-slate-600 border-slate-200'
                        : isQuarantining
                        ? 'bg-red-50 text-red-700 border-red-200'
                        : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                    }`}>
                      <span className="material-symbols-outlined text-[12px]">
                        {!isEnabled ? 'visibility' : isQuarantining ? 'lock' : 'check_circle'}
                      </span>
                      <span>
                        {!isEnabled
                          ? t('aiops.multiVector.defenseDisabled', 'Đã tắt phòng vệ — Chỉ đo lường')
                          : quarantineList.length > 0
                          ? t('aiops.multiVector.isolatingIps', `Đang cô lập ${quarantineList.length} IP vi phạm`, { count: quarantineList.length })
                          : vScore >= 70
                          ? t('aiops.multiVector.isolationActivated', 'Đã kích hoạt cô lập IP vi phạm')
                          : t('aiops.multiVector.isolationReady', 'Sẵn sàng cô lập IP vi phạm')}
                      </span>
                    </span>
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
            const isEnabled = vectorConfig.traffic !== false;
            return (
              <div className={`p-4 rounded-xl border flex flex-col justify-between space-y-3 transition-all ${
                isEnabled ? 'border-outline-variant/70 bg-surface-container-lowest' : 'border-slate-300 bg-slate-50/70 opacity-90'
              }`}>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-blue-600">waves</span>
                      {t('aiops.vectors.traffic', '2. Lưu Lượng & DoS')}
                    </span>
                    <button
                      type="button"
                      role="switch"
                      aria-checked={isEnabled}
                      data-testid="toggle-vector-traffic"
                      onClick={() => handleOpenToggleVectorModal('traffic')}
                      className={`relative inline-flex h-5 w-9 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                        isEnabled ? 'bg-emerald-600' : 'bg-slate-300'
                      }`}
                      title={isEnabled ? t('aiops.toggleVector.titleDisable', 'Xác nhận TẮT Vector') : t('aiops.toggleVector.titleEnable', 'Xác nhận BẬT Vector')}
                    >
                      <span
                        className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                          isEnabled ? 'translate-x-4' : 'translate-x-0'
                        }`}
                      />
                    </button>
                  </div>

                  {!isEnabled && (
                    <div className="px-2 py-1 rounded bg-amber-50 border border-amber-200 text-amber-900 text-[10px] font-semibold flex items-center gap-1">
                      <span className="material-symbols-outlined text-[13px] text-amber-600">visibility</span>
                      <span>{t('aiops.multiVector.measureOnlyNotice', 'Chế độ chỉ đo lường — Bỏ qua khỏi Threat Score')}</span>
                    </div>
                  )}

                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">{t('aiops.multiVector.pointsMax', '/ 100 điểm')}</span>
                  </div>
                  {/* Progress bar */}
                  <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                    <div
                      className={`h-full ${isEnabled ? vTheme.bg : 'bg-slate-400'} transition-all duration-500`}
                      style={{ width: `${Math.min(100, Math.max(0, vScore))}%` }}
                    />
                  </div>
                </div>

                <div className="space-y-1.5 pt-2 border-t border-slate-100 text-[11px]">
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.currentTraffic', 'Lưu lượng hiện tại:')}</span>
                    <strong className="font-mono">{sample.requestsPerMin ?? 0} RPM</strong>
                  </div>
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.distinctIps', 'Độ phân tán IP:')}</span>
                    <strong className="font-mono">{sample.distinctIpsCount ?? 0} {t('aiops.signals.ips', 'IPs')}</strong>
                  </div>
                  {/* Badge hành động phòng vệ động */}
                  <div className="pt-1">
                    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold border ${
                      !isEnabled
                        ? 'bg-slate-100 text-slate-600 border-slate-200'
                        : isThrottling
                        ? 'bg-blue-100 text-blue-800 border-blue-300'
                        : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                    }`}>
                      <span className="material-symbols-outlined text-[12px]">
                        {!isEnabled ? 'visibility' : isThrottling ? 'speed' : 'check_circle'}
                      </span>
                      <span>
                        {!isEnabled
                          ? t('aiops.multiVector.defenseDisabled', 'Đã tắt phòng vệ — Chỉ đo lường')
                          : isThrottling
                          ? t('aiops.multiVector.adaptiveThrottling', 'Đang điều tiết Adaptive Rate-Limit')
                          : t('aiops.multiVector.trafficSafe', `Lưu lượng an toàn theo chuẩn ${targetConcurrency} CCU`, { count: targetConcurrency })}
                      </span>
                    </span>
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
            const isEnabled = vectorConfig.exploit !== false;
            return (
              <div className={`p-4 rounded-xl border flex flex-col justify-between space-y-3 transition-all ${
                isEnabled ? 'border-outline-variant/70 bg-surface-container-lowest' : 'border-slate-300 bg-slate-50/70 opacity-90'
              }`}>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-rose-600">bug_report</span>
                      {t('aiops.vectors.exploit', '3. Khai Thác Lỗ Hổng')}
                    </span>
                    <button
                      type="button"
                      role="switch"
                      aria-checked={isEnabled}
                      data-testid="toggle-vector-exploit"
                      onClick={() => handleOpenToggleVectorModal('exploit')}
                      className={`relative inline-flex h-5 w-9 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                        isEnabled ? 'bg-emerald-600' : 'bg-slate-300'
                      }`}
                      title={isEnabled ? t('aiops.toggleVector.titleDisable', 'Xác nhận TẮT Vector') : t('aiops.toggleVector.titleEnable', 'Xác nhận BẬT Vector')}
                    >
                      <span
                        className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                          isEnabled ? 'translate-x-4' : 'translate-x-0'
                        }`}
                      />
                    </button>
                  </div>

                  {!isEnabled && (
                    <div className="px-2 py-1 rounded bg-amber-50 border border-amber-200 text-amber-900 text-[10px] font-semibold flex items-center gap-1">
                      <span className="material-symbols-outlined text-[13px] text-amber-600">visibility</span>
                      <span>{t('aiops.multiVector.measureOnlyNotice', 'Chế độ chỉ đo lường — Bỏ qua khỏi Threat Score')}</span>
                    </div>
                  )}

                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">{t('aiops.multiVector.pointsMax', '/ 100 điểm')}</span>
                  </div>
                  {/* Progress bar */}
                  <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                    <div
                      className={`h-full ${isEnabled ? vTheme.bg : 'bg-slate-400'} transition-all duration-500`}
                      style={{ width: `${Math.min(100, Math.max(0, vScore))}%` }}
                    />
                  </div>
                </div>

                <div className="space-y-1.5 pt-2 border-t border-slate-100 text-[11px]">
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.injectionSamples', 'Mẫu tiêm nhiễm (SQLi):')}</span>
                    <strong className="font-mono">{sample.malformedRequests ?? 0} {t('aiops.signals.samples', 'mẫu')}</strong>
                  </div>
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.traversal', 'Đường dẫn cấm/Traversal:')}</span>
                    <strong className="font-mono">{t('aiops.multiVector.autoDetected', 'Tự động phát hiện')}</strong>
                  </div>
                  {/* Badge hành động phòng vệ động */}
                  <div className="pt-1">
                    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold border ${
                      !isEnabled
                        ? 'bg-slate-100 text-slate-600 border-slate-200'
                        : isExploitActive
                        ? 'bg-rose-100 text-rose-800 border-rose-300'
                        : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                    }`}>
                      <span className="material-symbols-outlined text-[12px]">
                        {!isEnabled ? 'visibility' : isExploitActive ? 'security' : 'check_circle'}
                      </span>
                      <span>
                        {!isEnabled
                          ? t('aiops.multiVector.defenseDisabled', 'Đã tắt phòng vệ — Chỉ đo lường')
                          : isExploitActive
                          ? t('aiops.multiVector.blacklisted30m', 'Đã ngắt HTTP 403 & Blacklist 30p')
                          : t('aiops.multiVector.sqliReady', 'Sẵn sàng chặn SQLi/Payload')}
                      </span>
                    </span>
                  </div>
                </div>
              </div>
            );
          })()}

          {/* VECTƠ 4: SỨC KHỎE TÀI NGUYÊN HẠ TẦNG */}
          {(() => {
            const vScore = vectorScores.resource || 0;
            const vTheme = getVectorTheme(vScore);
            const isEnabled = vectorConfig.resource !== false;
            return (
              <div className={`p-4 rounded-xl border flex flex-col justify-between space-y-3 transition-all ${
                isEnabled ? 'border-outline-variant/70 bg-surface-container-lowest' : 'border-slate-300 bg-slate-50/70 opacity-90'
              }`}>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-teal-600">memory</span>
                      {t('aiops.vectors.resource', '4. Sức Khỏe Tài Nguyên')}
                    </span>
                    <button
                      type="button"
                      role="switch"
                      aria-checked={isEnabled}
                      data-testid="toggle-vector-resource"
                      onClick={() => handleOpenToggleVectorModal('resource')}
                      className={`relative inline-flex h-5 w-9 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                        isEnabled ? 'bg-emerald-600' : 'bg-slate-300'
                      }`}
                      title={isEnabled ? t('aiops.toggleVector.titleDisable', 'Xác nhận TẮT Vector') : t('aiops.toggleVector.titleEnable', 'Xác nhận BẬT Vector')}
                    >
                      <span
                        className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                          isEnabled ? 'translate-x-4' : 'translate-x-0'
                        }`}
                      />
                    </button>
                  </div>

                  {!isEnabled && (
                    <div className="px-2 py-1 rounded bg-amber-50 border border-amber-200 text-amber-900 text-[10px] font-semibold flex items-center gap-1">
                      <span className="material-symbols-outlined text-[13px] text-amber-600">visibility</span>
                      <span>{t('aiops.multiVector.measureOnlyNotice', 'Chế độ chỉ đo lường — Bỏ qua khỏi Threat Score')}</span>
                    </div>
                  )}

                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">{t('aiops.multiVector.pointsMax', '/ 100 điểm')}</span>
                  </div>
                  {/* Progress bar */}
                  <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                    <div
                      className={`h-full ${isEnabled ? vTheme.bg : 'bg-slate-400'} transition-all duration-500`}
                      style={{ width: `${Math.min(100, Math.max(0, vScore))}%` }}
                    />
                  </div>
                </div>

                <div className="space-y-1.5 pt-2 border-t border-slate-100 text-[11px]">
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.lag', 'Event Loop Lag:')}</span>
                    <strong className="font-mono">{sample.eventLoopLagMs ?? 0} {t('aiops.signals.unitMs', 'ms')}</strong>
                  </div>
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.cpuRam', 'CPU / RAM:')}</span>
                    <strong className="font-mono">{sample.cpuPercent ?? 0}% / {sample.ramPercent ?? 0}%</strong>
                  </div>
                  {/* Badge hành động phòng vệ động */}
                  <div className="pt-1">
                    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold border ${
                      !isEnabled
                        ? 'bg-slate-100 text-slate-600 border-slate-200'
                        : isEmergencyResourceRisk
                        ? 'bg-red-100 text-red-800 border-red-300'
                        : vScore >= 60
                        ? 'bg-amber-100 text-amber-800 border-amber-300'
                        : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                    }`}>
                      <span className="material-symbols-outlined text-[12px]">
                        {!isEnabled ? 'visibility' : isEmergencyResourceRisk ? 'crisis_alert' : vScore >= 60 ? 'tune' : 'check_circle'}
                      </span>
                      <span>
                        {!isEnabled
                          ? t('aiops.multiVector.defenseDisabled', 'Đã tắt phòng vệ — Chỉ đo lường')
                          : isEmergencyResourceRisk
                          ? t('aiops.multiVector.emergencyRecommend', '🚨 Đề xuất Bảo Trì Khẩn Cấp')
                          : vScore >= 60
                          ? t('aiops.multiVector.loadSheddingActive', 'Đang kích hoạt Load Shedding')
                          : t('aiops.multiVector.hardwareStable', 'Tài nguyên phần cứng ổn định')}
                      </span>
                    </span>
                  </div>
                </div>
              </div>
            );
          })()}
        </div>
      </div>

      {/* ======================================================== */}
      {/* KHỐI 2: BIỂU ĐỒ SVG XU HƯỚNG 4 VECTƠ RỦI RO ĐỘC LẬP THỜI GIAN THỰC */}
      {/* ======================================================== */}
      <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4">
        {/* Header & Bộ lọc Tabs cho 4 Vectơ */}
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-3 border-b border-outline-variant pb-3">
          <div>
            <h2 className="text-sm font-bold text-on-surface m-0 flex items-center gap-2">
              <span className="material-symbols-outlined text-[18px] text-primary">show_chart</span>
              <span>{t('aiops.chart.title', 'Biểu Đồ Xu Hướng 4 Vectơ Rủi Ro')}</span>
            </h2>
          </div>

          {/* Tab Filter Chuyển Đổi Vectơ */}
          <div className="flex items-center gap-1.5 flex-wrap bg-surface-container-low p-1 rounded-xl border border-outline-variant/60">
            {[
              { id: 'all', label: t('aiops.tabs.all', 'Tất Cả Vectơ'), icon: 'hub', color: 'text-indigo-600' },
              { id: 'auth', label: t('aiops.tabs.auth', '1. Xác Thực'), icon: 'badge', color: 'text-amber-600' },
              { id: 'traffic', label: t('aiops.tabs.traffic', '2. Lưu Lượng'), icon: 'waves', color: 'text-blue-600' },
              { id: 'exploit', label: t('aiops.tabs.exploit', '3. Khai Thác'), icon: 'bug_report', color: 'text-rose-600' },
              { id: 'resource', label: t('aiops.tabs.resource', '4. Tài Nguyên'), icon: 'memory', color: 'text-teal-600' },
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

        {/* ======================================================== */}
        {/* BỘ LỌC THỜI GIAN: BỘ CHỌN PRESETS VÀ BỘ LỌC THỜI GIAN */}
        {/* ======================================================== */}
        <div className="p-3.5 rounded-xl bg-slate-50/80 border border-slate-200/80 space-y-3">
          {/* Hàng 1: Bộ chọn thời gian quan sát (5 Presets) */}
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="text-xs font-bold text-slate-700 flex items-center gap-1">
                <span className="material-symbols-outlined text-[16px] text-primary">schedule</span>
                <span>{t('aiops.chart.selectObsTime', 'Bộ chọn thời gian quan sát:')}</span>
              </span>
              {[
                { id: '10m', label: t('aiops.chart.preset10m', '10 phút qua') },
                { id: '1h', label: t('aiops.chart.preset1h', '1 giờ qua') },
                { id: '24h', label: t('aiops.chart.preset24h', '24 giờ qua') },
                { id: '7d', label: t('aiops.chart.preset7d', '7 ngày qua') },
                { id: '30d', label: t('aiops.chart.preset30d', '1 tháng qua') },
              ].map((p) => {
                const isSelected =
                  (timePreset === p.id ||
                    (p.id === '10m' && timePreset === 'realtime') ||
                    (p.id === '24h' && timePreset === 'day') ||
                    (p.id === '30d' && timePreset === 'month')) &&
                  !customRange.applied;
                return (
                  <button
                    key={p.id}
                    type="button"
                    data-testid={`preset-${p.id}`}
                    onClick={() => handleSelectTimePreset(p.id)}
                    className={`px-3 py-1 rounded-lg text-xs font-semibold transition-all cursor-pointer border ${
                      isSelected
                        ? 'bg-primary text-white border-primary shadow-xs'
                        : customRange.applied
                        ? 'bg-white/60 text-slate-400 border-slate-200 hover:bg-white hover:text-slate-700'
                        : 'bg-white text-slate-700 border-outline-variant hover:bg-slate-100'
                    }`}
                    title={customRange.applied ? t('aiops.chart.reuseSelect', 'Dùng lại bộ chọn') : undefined}
                  >
                    {p.label}
                  </button>
                );
              })}
            </div>

            {fetchingHistory && (
              <span className="text-[11px] font-semibold text-primary flex items-center gap-1">
                <span className="material-symbols-outlined text-[14px] animate-spin">sync</span>
                <span>{t('common.loadingData', 'Đang tải dữ liệu...')}</span>
              </span>
            )}
          </div>

          {/* Hàng 2: Bộ lọc thời gian từ ... đến ... (ngày tháng năm giờ phút) */}
          <div className="pt-2 border-t border-slate-200/60 flex flex-col lg:flex-row lg:items-center justify-between gap-3">
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-xs font-bold text-slate-700 flex items-center gap-1">
                <span className="material-symbols-outlined text-[16px] text-indigo-600">date_range</span>
                <span>{t('aiops.chart.timeFilter', 'Bộ lọc thời gian:')}</span>
              </span>

              {/* Inputs Từ ... Đến ... */}
              <div className="flex items-center gap-1.5 text-xs flex-wrap">
                <span className="text-slate-500 font-medium">{t('aiops.chart.from', 'Từ:')}</span>
                <input
                  type="datetime-local"
                  data-testid="filter-from-date"
                  value={customRange.from}
                  onChange={(e) => setCustomRange((prev) => ({ ...prev, from: e.target.value }))}
                  className="bg-white border border-slate-300 rounded-lg px-2.5 py-1 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-primary"
                />

                <span className="text-slate-500 font-medium">{t('aiops.chart.to', 'Đến:')}</span>
                <input
                  type="datetime-local"
                  data-testid="filter-to-date"
                  value={customRange.to}
                  onChange={(e) => setCustomRange((prev) => ({ ...prev, to: e.target.value }))}
                  className="bg-white border border-slate-300 rounded-lg px-2.5 py-1 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-primary"
                />
              </div>

              {/* Action Buttons: Nút Lọc (Icon search) & Làm mới */}
              <button
                type="button"
                data-testid="apply-custom-range-btn"
                onClick={handleApplyCustomRange}
                className="px-3 py-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-xs font-bold transition-all cursor-pointer shadow-2xs inline-flex items-center gap-1"
              >
                <span className="material-symbols-outlined text-[14px]">search</span>
                <span>{t('aiops.chart.btnApplyFilter', 'Lọc')}</span>
              </button>

              <button
                type="button"
                data-testid="refresh-custom-range-btn"
                onClick={handleResetCustomRange}
                className="px-2.5 py-1 bg-white hover:bg-slate-100 text-slate-700 border border-slate-300 rounded-lg text-xs font-semibold transition-all cursor-pointer shadow-2xs inline-flex items-center gap-1"
                title={t('aiops.chart.refreshFilterTooltip', 'Làm mới bộ lọc thời gian về mặc định')}
              >
                <span className="material-symbols-outlined text-[14px]">refresh</span>
                <span>{t('common.refresh', 'Làm mới')}</span>
              </button>

              {customRange.applied && (
                <button
                  type="button"
                  data-testid="clear-custom-range-btn"
                  onClick={handleClearCustomRange}
                  className="px-2.5 py-1 bg-white hover:bg-slate-100 text-slate-700 border border-slate-300 rounded-lg text-xs font-medium transition-all cursor-pointer inline-flex items-center gap-1"
                >
                  <span className="material-symbols-outlined text-[14px]">close</span>
                  <span>{t('aiops.chart.btnClearFilter', 'Xóa bộ lọc')}</span>
                </button>
              )}
            </div>
          </div>

          {/* Banner Ưu Tiên Bộ Lọc Chính Xác (PO Rule) */}
          {customRange.applied && customRange.from && customRange.to && (
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 p-2.5 rounded-lg bg-amber-50 border border-amber-200 text-amber-900 text-xs">
              <div className="flex items-center gap-2">
                <span className="material-symbols-outlined text-[18px] text-amber-600">verified</span>
                <span>
                  {t('aiops.chart.priorityNotice', `ĐANG ƯU TIÊN BỘ LỌC CHÍNH XÁC: Dữ liệu từ ${customRange.from} đến ${customRange.to}. Bộ select nhanh đang tạm thời bị bỏ qua.`, { from: customRange.from, to: customRange.to })}
                </span>
              </div>
              <button
                type="button"
                onClick={handleClearCustomRange}
                className="text-xs font-bold text-amber-800 hover:text-amber-950 underline cursor-pointer whitespace-nowrap self-end sm:self-auto"
              >
                {t('aiops.chart.reuseSelect', 'Dùng lại bộ select')}
              </button>
            </div>
          )}
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
              <span className="text-amber-900">{t('aiops.tabs.auth', '1. Xác Thực')}: <strong>{vectorScores.auth ?? 0}</strong></span>
            </span>

            <span
              onClick={() => setActiveVectorTab(activeVectorTab === 'traffic' ? 'all' : 'traffic')}
              className={`flex items-center gap-1.5 cursor-pointer px-2 py-0.5 rounded transition-all ${
                activeVectorTab === 'traffic' ? 'bg-blue-100 font-bold ring-1 ring-blue-300' : 'hover:bg-slate-100'
              }`}
            >
              <span className="w-2.5 h-2.5 rounded-full bg-blue-500 inline-block" />
              <span className="text-blue-900">{t('aiops.tabs.traffic', '2. Lưu Lượng')}: <strong>{vectorScores.traffic ?? 0}</strong></span>
            </span>

            <span
              onClick={() => setActiveVectorTab(activeVectorTab === 'exploit' ? 'all' : 'exploit')}
              className={`flex items-center gap-1.5 cursor-pointer px-2 py-0.5 rounded transition-all ${
                activeVectorTab === 'exploit' ? 'bg-rose-100 font-bold ring-1 ring-rose-300' : 'hover:bg-slate-100'
              }`}
            >
              <span className="w-2.5 h-2.5 rounded-full bg-rose-500 inline-block" />
              <span className="text-rose-900">{t('aiops.tabs.exploit', '3. Khai Thác')}: <strong>{vectorScores.exploit ?? 0}</strong></span>
            </span>

            <span
              onClick={() => setActiveVectorTab(activeVectorTab === 'resource' ? 'all' : 'resource')}
              className={`flex items-center gap-1.5 cursor-pointer px-2 py-0.5 rounded transition-all ${
                activeVectorTab === 'resource' ? 'bg-teal-100 font-bold ring-1 ring-teal-300' : 'hover:bg-slate-100'
              }`}
            >
              <span className="w-2.5 h-2.5 rounded-full bg-teal-600 inline-block" />
              <span className="text-teal-900">{t('aiops.tabs.resource', '4. Tài Nguyên')}: <strong>{vectorScores.resource ?? 0}</strong></span>
            </span>

            {activeVectorTab === 'all' && (
              <span className="flex items-center gap-1.5 text-purple-700">
                <span className="w-2.5 h-0.5 bg-purple-500 inline-block border-b border-dashed border-purple-700" />
                <span>{t('aiops.chart.maxCeiling', 'Trần Max:')} <strong>{threatScore}</strong></span>
              </span>
            )}
          </div>
        </div>

        {/* SVG Multi-Vector Chart Container */}
        <div className="w-full overflow-x-auto">
          <div className="min-w-[640px] h-[230px] relative select-none">
            <svg
              className="w-full h-full"
              viewBox="0 0 800 190"
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
                x1="35"
                y1={180 - 25 - (85 / 100) * 130}
                x2="765"
                y2={180 - 25 - (85 / 100) * 130}
                stroke="#ef4444"
                strokeWidth="1.5"
                strokeDasharray="4 4"
                strokeOpacity="0.7"
              />
              <text x="770" y={180 - 21 - (85 / 100) * 130} fill="#ef4444" fontSize="10" fontWeight="bold">85</text>

              {/* Ngưỡng 70 (Warning line) */}
              <line
                x1="35"
                y1={180 - 25 - (70 / 100) * 130}
                x2="765"
                y2={180 - 25 - (70 / 100) * 130}
                stroke="#f59e0b"
                strokeWidth="1.5"
                strokeDasharray="4 4"
                strokeOpacity="0.7"
              />
              <text x="770" y={180 - 21 - (70 / 100) * 130} fill="#f59e0b" fontSize="10" fontWeight="bold">70</text>

              {/* Gridlines dọc tương ứng với các mốc trên trục X */}
              {xAxisConfig.ticks.map((t, idx) => (
                <line
                  key={`x-grid-${idx}`}
                  x1={t.x}
                  y1="20"
                  x2={t.x}
                  y2="155"
                  stroke="#f1f5f9"
                  strokeWidth="1"
                  strokeDasharray="2 3"
                />
              ))}

              {/* Baseline 0 (Đường trục hoành) */}
              <line x1="35" y1="155" x2="765" y2="155" stroke="#cbd5e1" strokeWidth="1.2" />

              {/* Vạch ticks và số liệu hiển thị trên trục X */}
              {xAxisConfig.ticks.map((t, idx) => (
                <g key={`x-tick-group-${idx}`}>
                  <line
                    x1={t.x}
                    y1="155"
                    x2={t.x}
                    y2="161"
                    stroke="#94a3b8"
                    strokeWidth="1.2"
                  />
                  <text
                    x={t.x}
                    y="174"
                    fill="#64748b"
                    fontSize="10"
                    fontWeight="600"
                    textAnchor="middle"
                  >
                    {t.label}
                  </text>
                </g>
              ))}

              {/* Đơn vị đo trục X đặt ở phía trên trục hoành để không đè lên số trục X */}
              <text
                x="765"
                y="148"
                fill="#64748b"
                fontSize="10"
                fontWeight="bold"
                textAnchor="end"
              >
                ({xAxisConfig.unit})
              </text>

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

            {/* Trạng thái rỗng (Empty State) khi khoảng thời gian không có mẫu thật (Yêu cầu 2 của PO) */}
            {(!historyData || historyData.length === 0) && (
              <div className="absolute inset-0 flex flex-col items-center justify-center bg-white/85 backdrop-blur-[1px] rounded-xl z-10 p-4 text-center">
                <div className="w-10 h-10 rounded-full bg-slate-100 flex items-center justify-center text-slate-500 mb-2">
                  <span className="material-symbols-outlined text-[24px]">query_stats</span>
                </div>
                <p className="text-xs font-bold text-slate-800">
                  {t('aiops.chart.emptyTitle', 'Không có dữ liệu đo lường trong khoảng thời gian đã chọn')}
                </p>
                <p className="text-[11px] text-slate-500 max-w-md mt-1 leading-relaxed">
                  {t('aiops.chart.emptyDesc', 'Hệ thống cam kết 100% dữ liệu thực tế, không sinh dữ liệu ảo giả lập. Dữ liệu chỉ hiển thị khi có các mẫu ghi nhận thực từ máy chủ.')}
                </p>
                <div className="mt-3 flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => handleSelectTimePreset('realtime')}
                    className="px-3 py-1 bg-primary text-white text-xs font-semibold rounded-lg hover:bg-primary/90 transition-all cursor-pointer shadow-xs"
                  >
                    {t('aiops.chart.backToRealtime', 'Quay lại Thời gian thực')}
                  </button>
                  {customRange.applied && (
                    <button
                      type="button"
                      onClick={handleClearCustomRange}
                      className="px-3 py-1 bg-white border border-slate-300 text-slate-700 text-xs font-medium rounded-lg hover:bg-slate-100 transition-all cursor-pointer"
                    >
                      {t('aiops.chart.removeFilter', 'Bỏ bộ lọc chính xác')}
                    </button>
                  )}
                </div>
              </div>
            )}

            {/* Tooltip Card hiển thị chi tiết khi rê chuột (Yêu cầu 1 của PO: Ngày tháng năm giờ phút giây) */}
            {hoveredPointIndex !== null && chartSvgPaths.samples[hoveredPointIndex] && (() => {
              const hs = chartSvgPaths.samples[hoveredPointIndex];
              const timeStr = hs.time ? formatFullDateTime(hs.time) : t('common.justNow', 'Mẫu vừa xong');
              const leftPercent = Math.min(85, Math.max(15, (hs.x / 800) * 100));
              return (
                <div
                  className="absolute top-1 pointer-events-none z-20 bg-slate-900/95 text-white p-2.5 rounded-xl shadow-xl border border-slate-700 text-[11px] space-y-1.5 backdrop-blur-xs min-w-[230px] transform -translate-x-1/2 transition-transform duration-75"
                  style={{ left: `${leftPercent}%` }}
                >
                  <div className="flex items-center justify-between border-b border-slate-700 pb-1">
                    <span className="font-semibold text-slate-200 flex items-center gap-1">
                      <span className="material-symbols-outlined text-[13px] text-primary">schedule</span>
                      {timeStr}
                    </span>
                    <span className="text-[10px] text-slate-400">{t('aiops.chart.sampleNum', 'Mẫu #{num}', { num: hoveredPointIndex + 1 })}</span>
                  </div>

                  <div className="space-y-1">
                    <div className="flex items-center justify-between">
                      <span className="flex items-center gap-1 text-amber-400">
                        <span className="w-2 h-2 rounded-full bg-amber-400" />
                        {t('aiops.tabs.auth', '1. Xác Thực')}:
                      </span>
                      <strong className="font-mono">{hs.auth.score}/100</strong>
                    </div>

                    <div className="flex items-center justify-between">
                      <span className="flex items-center gap-1 text-blue-400">
                        <span className="w-2 h-2 rounded-full bg-blue-400" />
                        {t('aiops.tabs.traffic', '2. Lưu Lượng')}:
                      </span>
                      <strong className="font-mono">{hs.traffic.score}/100</strong>
                    </div>

                    <div className="flex items-center justify-between">
                      <span className="flex items-center gap-1 text-rose-400">
                        <span className="w-2 h-2 rounded-full bg-rose-400" />
                        {t('aiops.tabs.exploit', '3. Khai Thác')}:
                      </span>
                      <strong className="font-mono">{hs.exploit.score}/100</strong>
                    </div>

                    <div className="flex items-center justify-between">
                      <span className="flex items-center gap-1 text-teal-400">
                        <span className="w-2 h-2 rounded-full bg-teal-400" />
                        {t('aiops.tabs.resource', '4. Tài Nguyên')}:
                      </span>
                      <strong className="font-mono">{hs.resource.score}/100</strong>
                    </div>

                    <div className="pt-1 border-t border-slate-700/80 flex items-center justify-between text-purple-300 font-bold">
                      <span>{t('aiops.threatScoreTitle', 'Threat Score')}:</span>
                      <span className="font-mono">{hs.composite.score}/100</span>
                    </div>
                  </div>
                </div>
              );
            })()}
          </div>
        </div>
      </div>

      {/* ======================================================== */}
      {/* KHỐI 3: TỔNG QUAN NGUYÊN NHÂN BẤT THƯỜNG - CSDL PERSISTENT JOURNAL */}
      {/* ======================================================== */}
      <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between border-b border-outline-variant pb-3 gap-3">
          <div>
            <h2 className="text-sm font-bold text-on-surface m-0 flex items-center gap-2">
              <span className="material-symbols-outlined text-[18px] text-primary">troubleshoot</span>
              <span>{t('aiops.rca.title', 'Tổng quan nguyên nhân bất thường')}</span>
            </h2>
          </div>

          <div className="flex items-center gap-2.5">
            <span className="text-xs font-semibold px-2.5 py-1 rounded-lg bg-surface-container-low border border-outline-variant/60 flex items-center gap-1.5">
              <span className="material-symbols-outlined text-[15px] text-primary">database</span>
              <span>{t('aiops.rca.incidentsInDb', `${incidentTotal} sự cố`, { count: incidentTotal })}</span>
            </span>
          </div>
        </div>

        {/* Toolbar: Bộ lọc Vector, Trạng thái & Tìm kiếm */}
        <div className="flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-3 pt-1">
          {/* Filters */}
          <div className="flex flex-wrap items-center gap-2">
            {/* Vector Filter Pills */}
            <div className="inline-flex rounded-lg border border-outline-variant/60 p-0.5 bg-surface-container-lowest text-xs">
              {[
                { key: 'all', label: t('aiops.rca.vectorAll', 'Tất cả Vector') },
                { key: 'auth', label: t('aiops.rca.vectorAuth', '🛡️ Xác thực') },
                { key: 'traffic', label: t('aiops.rca.vectorTraffic', '🌐 Lưu lượng') },
                { key: 'exploit', label: t('aiops.rca.vectorExploit', '💉 Khai thác') },
                { key: 'resource', label: t('aiops.rca.vectorResource', '⚡ Tài nguyên') },
              ].map((v) => (
                <button
                  key={v.key}
                  type="button"
                  onClick={() => {
                    setIncidentVectorFilter(v.key);
                    setIncidentPage(1);
                  }}
                  className={`px-2.5 py-1 rounded-md text-[11px] font-semibold transition-all cursor-pointer ${
                    incidentVectorFilter === v.key
                      ? 'bg-primary text-white shadow-2xs'
                      : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
                  }`}
                >
                  {v.label}
                </button>
              ))}
            </div>

            {/* Status Filter Pills */}
            <div className="inline-flex rounded-lg border border-outline-variant/60 p-0.5 bg-surface-container-lowest text-xs">
              {[
                { key: 'all', label: t('aiops.rca.statusAll', 'Mọi trạng thái') },
                { key: 'ACTIVE', label: t('aiops.rca.statusActive', '🔴 Đang diễn ra') },
                { key: 'MITIGATED', label: t('aiops.rca.statusMitigated', '🟢 Đã giảm thiểu') },
              ].map((s) => (
                <button
                  key={s.key}
                  type="button"
                  onClick={() => {
                    setIncidentStatusFilter(s.key);
                    setIncidentPage(1);
                  }}
                  className={`px-2.5 py-1 rounded-md text-[11px] font-semibold transition-all cursor-pointer ${
                    incidentStatusFilter === s.key
                      ? 'bg-slate-800 text-white shadow-2xs'
                      : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
                  }`}
                >
                  {s.label}
                </button>
              ))}
            </div>
          </div>

          {/* Search Form */}
          <form onSubmit={handleSearchSubmit} className="flex items-center gap-1.5">
            <div className="relative flex-1 sm:w-64">
              <span className="material-symbols-outlined text-[16px] text-slate-400 absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none">
                search
              </span>
              <input
                type="text"
                value={incidentSearch}
                onChange={(e) => setIncidentSearch(e.target.value)}
                placeholder={t('aiops.rca.searchPlaceholder', 'Tìm IP, Hash, User, Mã...')}
                className="w-full pl-8 pr-7 py-1 text-xs border border-outline-variant/80 rounded-lg focus:outline-none focus:border-primary bg-white text-slate-800 placeholder:text-slate-400"
              />
              {incidentSearch && (
                <button
                  type="button"
                  onClick={() => {
                    setIncidentSearch('');
                    setIncidentPage(1);
                    fetchIncidents(1, incidentPageSize, incidentVectorFilter, incidentStatusFilter, '');
                  }}
                  className="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 cursor-pointer"
                >
                  <span className="material-symbols-outlined text-[14px]">close</span>
                </button>
              )}
            </div>
            <button
              type="submit"
              className="px-3 py-1 bg-slate-100 hover:bg-slate-200 border border-outline-variant/80 rounded-lg text-xs font-semibold text-slate-700 cursor-pointer transition-colors"
            >
              {t('common.filter', 'Lọc')}
            </button>
          </form>
        </div>

        {/* Table Content */}
        {incidentsList.length > 0 ? (
          <div className="overflow-x-auto rounded-xl border border-outline-variant/70">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b border-outline-variant/80 bg-surface-container-low/60 text-slate-600 font-bold uppercase text-[10px] tracking-wider">
                  <th className="py-2.5 px-3 whitespace-nowrap">{t('aiops.rca.colStatus', 'Tình trạng')}</th>
                  <th className="py-2.5 px-3 whitespace-nowrap">{t('aiops.rca.colActor', 'Đối tượng')}</th>
                  <th className="py-2.5 px-3 whitespace-nowrap">{t('aiops.rca.colVector', 'Vector')}</th>
                  <th className="py-2.5 px-3 whitespace-nowrap">{t('aiops.rca.colMetric', 'Chỉ số')}</th>
                  <th className="py-2.5 px-3">{t('aiops.rca.colRootCause', 'Nguyên nhân')}</th>
                  <th className="py-2.5 px-3">{t('aiops.rca.colMitigation', 'Xử lý')}</th>
                  <th className="py-2.5 px-3 whitespace-nowrap text-center">{t('aiops.rca.colDefense', 'Phòng vệ')}</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-outline-variant/40 bg-white">
                {incidentsList.map((item) => {
                  const firstTime = item.first_detected_at || item.firstDetectedAt;
                  const lastTime = item.last_seen_at || item.lastSeenAt;
                  const status = item.status || 'ACTIVE';
                  const hits = item.hits || 1;
                  const actorIdentity = item.actor?.identity || item.actor_identity || item.actorIdentity || '192.168.xxx.xxx';
                  const actorHash = item.actor?.ipHash || item.actor_hash || item.actorHash || '';
                  const actorType = item.actor?.type || item.actor_type || 'IP_SOURCE';
                  const userId = item.actor?.userId || item.user_id || item.userId;
                  const targetAccount = item.actor?.username || item.username || item.actor?.targetAccount || item.targetAccount;
                  const username = (targetAccount && targetAccount !== 'all' && targetAccount !== 'Khách vãng lai / Ẩn danh') ? targetAccount : null;
                  const actorTargetIp = item.actor?.maskedIp || item.actor?.rawIp || actorIdentity;
                  const vector = item.vector || 'traffic';
                  const metricCurrent = item.metric_current ?? item.metricCurrent ?? item.current ?? 0;
                  const metricBaseline = item.metric_baseline ?? item.metricBaseline ?? item.baseline ?? 0;
                  const metricUnit = item.metric_unit || item.metricUnit || item.unit || '';
                  const message = item.message || '';
                  const mitigation = item.mitigation_taken || item.mitigationTaken;

                  const clientIpClean = String(myCurrentIp || '').replace(/^::ffff:/, '').trim();
                  const clientIpPrefix = clientIpClean ? clientIpClean.split('.').slice(0, 2).join('.') : '';
                  const isMyCurrentIp = Boolean(
                    clientIpClean && (
                      actorIdentity === clientIpClean ||
                      actorIdentity.replace(/^::ffff:/, '').trim() === clientIpClean ||
                      (clientIpPrefix && actorIdentity.startsWith(`${clientIpPrefix}.`)) ||
                      actorIdentity.includes(clientIpClean)
                    )
                  );

                  // Kiểm tra đối tượng có thuộc diện bảo vệ an toàn (Phiên Admin động, Internal, Loopback, hoặc Resource)
                  const isProtectedActor =
                    actorType === 'SYSTEM_INTERNAL' ||
                    vector === 'resource' ||
                    actorHash === 'system_core' ||
                    actorHash === 'system_host' ||
                    isMyCurrentIp ||
                    actorIdentity === '127.0.0.1' ||
                    actorIdentity.includes('127.0.0.1') ||
                    actorIdentity.includes('::1') ||
                    actorIdentity.includes('localhost') ||
                    actorIdentity.includes('Internal') ||
                    actorIdentity.includes('Loopback');

                  // Tính tỷ lệ vượt ngưỡng
                  const ratio = metricBaseline > 0 ? (Number(metricCurrent) / Number(metricBaseline)).toFixed(1) : null;

                  // Kiểm tra IP đã nằm trong danh sách cô lập Shield chưa
                  const isQuarantined = quarantineList.some(
                    (q) => q.hash === actorHash || q.maskedIp === actorIdentity
                  );

                  return (
                    <tr key={item.id} className="hover:bg-slate-50/80 transition-colors">
                      {/* Cột 1: Tình trạng */}
                      <td className="py-3 px-3 align-top whitespace-nowrap space-y-1">
                        <div className="font-semibold text-slate-800 text-[11px]">
                          {formatDateTime(firstTime)}
                        </div>
                        <div>
                          {status === 'ACTIVE' ? (
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-50 text-rose-700 border border-rose-200/70">
                              <span className="w-1.5 h-1.5 rounded-full bg-rose-500 animate-pulse"></span>
                              {t('aiops.rca.badgeActive', 'ĐANG DIỄN RA')}
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200/70">
                              <span className="material-symbols-outlined text-[12px]">check_circle</span>
                              {t('aiops.rca.badgeMitigated', 'ĐÃ GIẢM THIỂU')}
                            </span>
                          )}
                        </div>
                        <div className="text-[10px] text-slate-500 font-medium">
                          {hits > 1 ? t('aiops.rca.repeatedTimes', `Lặp lại ${hits} lần`, { count: hits }) : t('aiops.rca.firstDetected', 'Phát hiện lần 1')}
                        </div>
                      </td>

                      {/* Cột 2: Đối tượng (Tài khoản phía trên, IP vi phạm tương ứng phía dưới) */}
                      <td className="py-3 px-3 align-top whitespace-nowrap space-y-1">
                        <div className="font-semibold text-slate-800 text-xs">
                          <span className="text-slate-500 font-normal mr-1">TK:</span>
                          <span className="text-primary font-bold">
                            {vector === 'resource' || actorType === 'SYSTEM_INTERNAL'
                              ? t('aiops.rca.internalSystemLabel', 'Hệ thống nội bộ')
                              : (username || (userId ? `UID #${userId}` : t('aiops.rca.anonymousUser', 'Khách vãng lai / Ẩn danh')))}
                          </span>
                        </div>
                        <div className="font-mono text-[11px] text-slate-600">
                          <span className="text-slate-400 font-normal mr-1">IP:</span>
                          <span>
                            {vector === 'resource' || actorType === 'SYSTEM_INTERNAL'
                              ? t('aiops.rca.internalSystem', 'Nội bộ hệ thống')
                              : isMyCurrentIp
                              ? `${formatMaskedIp(actorTargetIp)} (${t('aiops.rca.protectedMyIpLabel', 'Máy bạn')})`
                              : formatMaskedIp(actorTargetIp)}
                          </span>
                        </div>
                      </td>

                      {/* Cột 3: Vector */}
                      <td className="py-3 px-3 align-top whitespace-nowrap">
                        <span
                          className={`inline-block px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${
                            vector === 'auth'
                              ? 'bg-purple-50 text-purple-700 border border-purple-200/60'
                              : vector === 'traffic'
                              ? 'bg-blue-50 text-blue-700 border border-blue-200/60'
                              : vector === 'exploit'
                              ? 'bg-rose-50 text-rose-700 border border-rose-200/60'
                              : 'bg-amber-50 text-amber-700 border border-amber-200/60'
                          }`}
                        >
                          {vector}
                        </span>
                      </td>

                      {/* Cột 4: Chỉ số */}
                      <td className="py-3 px-3 align-top whitespace-nowrap space-y-1">
                        <div className="font-bold text-rose-600 text-xs">
                          {metricCurrent} {metricUnit}
                        </div>
                        <div className="text-[11px] text-slate-500">
                          {t('aiops.rca.threshold', 'Ngưỡng:')} {metricBaseline} {metricUnit}
                        </div>
                        {ratio && Number(ratio) > 1 && (
                          <span className="inline-block text-[10px] font-bold px-1.5 py-0.2 rounded bg-rose-50 text-rose-700 border border-rose-200/60">
                            {t('aiops.rca.exceededRatio', `Vượt ${ratio}x`, { ratio })}
                          </span>
                        )}
                      </td>

                      {/* Cột 5: Nguyên nhân */}
                      <td className="py-3 px-3 align-top max-w-sm">
                        <div className="text-slate-800 font-medium text-xs leading-relaxed">
                          {message}
                        </div>
                      </td>

                      {/* Cột 6: Xử lý */}
                      <td className="py-3 px-3 align-top max-w-xs">
                        {mitigation ? (
                          <div className="text-slate-700 text-xs font-medium leading-relaxed bg-emerald-50/70 border border-emerald-200/80 p-2 rounded-lg">
                            {mitigation}
                          </div>
                        ) : (
                          <span className="text-slate-400 text-xs italic">
                            {t('aiops.rca.noMitigation', 'Hệ thống đang theo dõi')}
                          </span>
                        )}
                      </td>

                      {/* Cột 7: Phòng vệ */}
                      <td className="py-3 px-3 align-top text-center whitespace-nowrap">
                        {isQuarantined ? (
                          <div className="space-y-1">
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-lg text-[10px] font-bold bg-rose-50 text-rose-700 border border-rose-200/70">
                              <span className="material-symbols-outlined text-[13px]">block</span>
                              {t('aiops.rca.quarantinedShield', 'Đã cách ly Shield')}
                            </span>
                            <div>
                              <button
                                type="button"
                                onClick={() => handleUnblock(actorHash)}
                                disabled={unblockingHash === actorHash}
                                className="text-[10px] font-semibold text-slate-500 hover:text-slate-800 underline transition-colors cursor-pointer"
                                title={t('aiops.unblockTooltip', 'Mở khóa và gỡ bỏ địa chỉ IP khỏi danh sách cô lập')}
                              >
                                {unblockingHash === actorHash ? t('common.processing', 'Đang xử lý...') : t('aiops.unblockBtn', 'Gỡ chặn')}
                              </button>
                            </div>
                          </div>
                        ) : isProtectedActor ? (
                          <span className="text-[11px] font-semibold text-emerald-700">
                            {actorType === 'SYSTEM_INTERNAL' || vector === 'resource'
                              ? t('aiops.rca.internalSystem', 'Nội bộ hệ thống')
                              : isMyCurrentIp
                              ? t('aiops.rca.protectedMyIp', 'IP Máy bạn (Đang đăng nhập)')
                              : t('aiops.rca.protectedIp', 'IP Được bảo vệ')}
                          </span>
                        ) : (
                          <div>
                            <button
                              type="button"
                              onClick={() => handleOpenQuarantineModal(item)}
                              className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[10px] font-semibold bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-200/70 transition-all shadow-2xs active:scale-95 cursor-pointer"
                              title={`${t('aiops.rca.btnQuarantine', 'Phong Tỏa IP')} ${formatMaskedIp(actorTargetIp)}`}
                            >
                              <span className="material-symbols-outlined text-[13px]">shield</span>
                              <span>{t('aiops.rca.btnQuarantine', 'Phong Tỏa IP')}</span>
                            </button>
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>

            {/* Phân trang Server-side */}
            <Pagination
              currentPage={incidentPage}
              pageSize={incidentPageSize}
              total={incidentTotal}
              pageSizeOptions={[5, 10, 20, 50]}
              onPageChange={(p) => setIncidentPage(p)}
              onPageSizeChange={(s) => {
                setIncidentPageSize(s);
                setIncidentPage(1);
              }}
              itemLabel={t('aiops.rca.itemLabel', 'sự cố ghi nhận')}
            />
          </div>
        ) : (
          <div className="p-8 text-center rounded-xl bg-surface-container-low/40 border border-outline-variant/60">
            <p className="text-xs font-semibold text-slate-500 m-0">
              {t('aiops.rca.emptyCompact', 'Không tìm thấy sự cố')}
            </p>
          </div>
        )}
      </div>

      {/* ======================================================== */}
      {/* KHỐI 4: BẢNG NGUỒN THEO DÕI ĐẶC BIỆT */}
      {/* ======================================================== */}
      <div className="bg-white rounded-2xl border border-slate-200/80 p-5 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-100 pb-3">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-slate-100 text-slate-700 flex items-center justify-center flex-shrink-0">
              <span className="material-symbols-outlined text-[20px]">shield_with_heart</span>
            </div>
            <div>
              <h2 className="text-sm font-bold text-slate-800 m-0">
                {t('aiops.quarantine.title', 'Nguồn theo dõi đặc biệt')}
              </h2>
              <p className="text-[11px] text-slate-500 m-0">
                {t('aiops.quarantine.subtitle', 'Danh sách IP & Tài khoản bị phong tỏa hoặc cách ly giám sát')}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2 flex-wrap">
            <button
              id="btn-open-manual-quarantine"
              type="button"
              onClick={handleOpenManualQuarantine}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-rose-600 hover:bg-rose-700 text-white rounded-lg text-xs font-bold transition-all shadow-2xs cursor-pointer active:scale-95"
              title={t('aiops.quarantine.manualBtnTitle', 'Tạm khóa thủ công địa chỉ IP hoặc tài khoản người dùng')}
            >
              <span className="material-symbols-outlined text-[16px]">lock_clock</span>
              <span>{t('aiops.quarantine.btnManualLock', 'Tạm khóa thủ công')}</span>
            </button>
          </div>
        </div>

        {/* Thanh tìm kiếm & bộ lọc IP / Tài khoản */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-slate-50/70 p-3 rounded-xl border border-slate-200/60">
          <div className="flex flex-wrap items-center gap-2 flex-1">
            <div className="relative min-w-[170px] flex-1 sm:max-w-xs">
              <span className="material-symbols-outlined absolute left-2.5 top-2 text-slate-400 text-[16px]">search</span>
              <input
                type="text"
                data-testid="quarantine-ip-filter-input"
                placeholder={t('aiops.quarantine.filterIpPlaceholder', 'Lọc theo IP...')}
                value={quarantineIpFilter}
                onChange={(e) => {
                  setQuarantineIpFilter(e.target.value);
                  setQuarantinePage(1);
                }}
                className="w-full bg-white border border-slate-300 rounded-lg pl-8 pr-3 py-1.5 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-primary"
              />
            </div>

            <div className="relative min-w-[170px] flex-1 sm:max-w-xs">
              <span className="material-symbols-outlined absolute left-2.5 top-2 text-slate-400 text-[16px]">person_search</span>
              <input
                type="text"
                data-testid="quarantine-account-filter-input"
                placeholder={t('aiops.quarantine.filterAccountPlaceholder', 'Lọc theo Tài khoản...')}
                value={quarantineAccountFilter}
                onChange={(e) => {
                  setQuarantineAccountFilter(e.target.value);
                  setQuarantinePage(1);
                }}
                className="w-full bg-white border border-slate-300 rounded-lg pl-8 pr-3 py-1.5 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-primary"
              />
            </div>

            {(quarantineIpFilter || quarantineAccountFilter) && (
              <button
                type="button"
                data-testid="clear-quarantine-filter-btn"
                onClick={() => {
                  setQuarantineIpFilter('');
                  setQuarantineAccountFilter('');
                  setQuarantinePage(1);
                }}
                className="inline-flex items-center gap-1 px-2.5 py-1.5 bg-white hover:bg-slate-100 text-slate-700 border border-slate-300 rounded-lg text-xs font-medium transition-all cursor-pointer shadow-2xs"
              >
                <span className="material-symbols-outlined text-[14px]">close</span>
                <span>{t('common.clearFilter', 'Xóa lọc')}</span>
              </button>
            )}
          </div>

          <div className="text-[11px] font-semibold text-slate-500 whitespace-nowrap self-end sm:self-auto">
            {t('aiops.quarantine.showingCount', `Hiển thị ${filteredQuarantineList.length} / ${quarantineList.length} đối tượng`, { count: filteredQuarantineList.length, total: quarantineList.length })}
          </div>
        </div>

        {quarantineList.length > 0 ? (
          filteredQuarantineList.length > 0 ? (
          <div className="rounded-xl border border-slate-200/80 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs border-collapse">
                <thead>
                  <tr className="border-b border-slate-200 bg-slate-50/70 text-slate-600 font-bold uppercase text-[10px] tracking-wider">
                    <th className="py-2.5 px-3 whitespace-nowrap">{t('aiops.quarantine.colIp', 'Địa chỉ IP')}</th>
                    <th className="py-2.5 px-3 whitespace-nowrap">{t('aiops.quarantine.colAccount', 'Tài khoản')}</th>
                    <th className="py-2.5 px-3 whitespace-nowrap">Vector</th>
                    <th className="py-2.5 px-3">{t('aiops.quarantine.colReason', 'Nguyên nhân phong tỏa')}</th>
                    <th className="py-2.5 px-3 whitespace-nowrap">{t('aiops.quarantine.colTime', 'Thời điểm chặn')}</th>
                    <th className="py-2.5 px-3 whitespace-nowrap">{t('aiops.quarantine.colRemaining', 'Thời gian còn lại')}</th>
                    <th className="py-2.5 px-3 text-center whitespace-nowrap">{t('aiops.quarantine.colIpActions', 'Thao tác IP')}</th>
                    <th className="py-2.5 px-3 text-center whitespace-nowrap">{t('aiops.quarantine.colAccountActions', 'Thao tác Tài khoản')}</th>
                    <th className="py-2.5 px-3 text-center whitespace-nowrap">Thao tác</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 bg-white">
                  {paginatedQuarantineList.map((item, idx) => {
                    const targetIpHash = item.ipHash || item.hash;
                    const targetAccount = item.username || item.idaccount;

                    // Tính thời gian đếm ngược thực tế (Client countdown)
                    const isIpTemp = item.ipStatus === 'temporary' || item.ipStatus === 'temp';
                    const isAccountTemp = item.accountStatus === 'temporary' || item.accountStatus === 'temp';

                    let isIpExpired = false;
                    let effectiveIpMin = null;
                    if (isIpTemp) {
                      if (item.ipExpiresAt) {
                        const diffMs = new Date(item.ipExpiresAt).getTime() - currentClientTime;
                        effectiveIpMin = Math.ceil(diffMs / 60000);
                        if (effectiveIpMin <= 0) {
                          isIpExpired = true;
                          effectiveIpMin = null;
                        }
                      } else if (item.ipRemainingMinutes !== undefined && item.ipRemainingMinutes !== null) {
                        effectiveIpMin = item.ipRemainingMinutes;
                        if (effectiveIpMin <= 0) {
                          isIpExpired = true;
                          effectiveIpMin = null;
                        }
                      } else if (item.remainingMinutes !== undefined && item.remainingMinutes !== null) {
                        effectiveIpMin = item.remainingMinutes;
                        if (effectiveIpMin <= 0) {
                          isIpExpired = true;
                          effectiveIpMin = null;
                        }
                      } else {
                        isIpExpired = true;
                      }
                    }

                    let isAccountExpired = false;
                    let effectiveAccountMin = null;
                    if (isAccountTemp) {
                      if (item.accountExpiresAt) {
                        const diffMs = new Date(item.accountExpiresAt).getTime() - currentClientTime;
                        effectiveAccountMin = Math.ceil(diffMs / 60000);
                        if (effectiveAccountMin <= 0) {
                          isAccountExpired = true;
                          effectiveAccountMin = null;
                        }
                      } else if (item.accountRemainingMinutes !== undefined && item.accountRemainingMinutes !== null) {
                        effectiveAccountMin = item.accountRemainingMinutes;
                        if (effectiveAccountMin <= 0) {
                          isAccountExpired = true;
                          effectiveAccountMin = null;
                        }
                      } else if (item.remainingMinutes !== undefined && item.remainingMinutes !== null) {
                        effectiveAccountMin = item.remainingMinutes;
                        if (effectiveAccountMin <= 0) {
                          isAccountExpired = true;
                          effectiveAccountMin = null;
                        }
                      } else {
                        isAccountExpired = true;
                      }
                    }

                    const isIpPermanent = item.ipStatus === 'permanent';
                    const isIpUnlocked = item.ipStatus === 'unlocked' || isIpExpired;

                    const isAccountPermanent = item.accountStatus === 'permanent';
                    const isAccountUnlocked = item.accountStatus === 'unlocked' || isAccountExpired;
                    const vector = item.vector || 'auth';
                    const rowKey = `quarantine-${item.id || item.ipHash || item.hash || 'row'}-${item.username || 'acc'}-${item.bannedAt || ''}-${idx}`;

                    return (
                      <tr key={rowKey} className="hover:bg-slate-50/60 transition-colors">
                        {/* CỘT IP */}
                        <td className="py-3 px-3 font-mono font-medium text-slate-700 whitespace-nowrap">
                          {formatMaskedIp(item.maskedIp || item.ip || item.raw_ip) || '192.168.xxx.xxx'}
                        </td>

                        {/* CỘT TÀI KHOẢN */}
                        <td className="py-3 px-3 font-mono font-medium text-slate-700 whitespace-nowrap">
                          {targetAccount || '--'}
                        </td>

                        {/* CỘT VECTOR */}
                        <td className="py-3 px-3 whitespace-nowrap">
                          <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${
                            vector === 'auth'
                              ? 'bg-purple-50 text-purple-700 border border-purple-200/60'
                              : vector === 'exploit'
                              ? 'bg-rose-50 text-rose-700 border border-rose-200/60'
                              : 'bg-blue-50 text-blue-700 border border-blue-200/60'
                          }`}>
                            {vector === 'auth' ? 'Xác thực' : vector === 'exploit' ? 'Khai thác' : 'Lưu lượng'}
                          </span>
                        </td>

                        {/* CỘT NGUYÊN NHÂN */}
                        <td className="py-3 px-3 text-slate-700 max-w-xs font-normal" title={item.reason}>
                          <span className="truncate block max-w-[200px]">
                            {item.reason || '--'}
                          </span>
                        </td>

                        {/* CỘT THỜI ĐIỂM */}
                        <td className="py-3 px-3 text-slate-500 whitespace-nowrap">
                          {item.bannedAt ? formatDateTime(item.bannedAt) : t('common.justNow', 'Vừa xong')}
                        </td>

                        {/* CỘT THỜI GIAN CÒN LẠI */}
                        <td className="py-2.5 px-3 whitespace-nowrap">
                          <div className="flex flex-col gap-1 items-start text-[10px]">
                            {/* Dòng IP */}
                            {!isIpPermanent && !isIpUnlocked && effectiveIpMin && effectiveIpMin > 0 ? (
                              <span className="px-1.5 py-0.5 rounded font-bold bg-amber-50 text-amber-700 border border-amber-200/60 inline-flex items-center gap-1">
                                <span className="font-semibold text-slate-500">IP:</span>
                                <span>{formatRemainingTime(effectiveIpMin)}</span>
                              </span>
                            ) : (
                              <span className="text-slate-400 font-medium px-1">
                                IP: --
                              </span>
                            )}

                            {/* Dòng Tài khoản */}
                            {targetAccount && targetAccount !== '--' ? (
                              !isAccountPermanent && !isAccountUnlocked && effectiveAccountMin && effectiveAccountMin > 0 ? (
                                <span className="px-1.5 py-0.5 rounded font-bold bg-amber-50 text-amber-700 border border-amber-200/60 inline-flex items-center gap-1">
                                  <span className="font-semibold text-slate-500">TK:</span>
                                  <span>{formatRemainingTime(effectiveAccountMin)}</span>
                                </span>
                              ) : (
                                <span className="text-slate-400 font-medium px-1">
                                  TK: --
                                </span>
                              )
                            ) : (
                              <span className="text-slate-400 font-medium px-1">
                                TK: --
                              </span>
                            )}
                          </div>
                        </td>

                        {/* CỘT THAO TÁC IP */}
                        <td className="py-3 px-3 text-center whitespace-nowrap">
                          {isIpPermanent ? (
                            <span className="px-2.5 py-1 rounded-md text-[11px] font-semibold bg-rose-50 text-rose-700 border border-rose-200/60 inline-block">
                              IP đã bị phong tỏa
                            </span>
                          ) : isIpUnlocked ? (
                            <button
                              type="button"
                              onClick={() => handleTemporaryBlockIp(targetIpHash, item.maskedIp)}
                              disabled={quarantineActionLoading === `temp_ip_${targetIpHash}`}
                              className="px-2.5 py-1 bg-amber-50 hover:bg-amber-100 text-amber-700 border border-amber-200/70 rounded-lg text-[11px] font-semibold transition-all cursor-pointer shadow-2xs disabled:opacity-50"
                            >
                              Tạm khóa IP
                            </button>
                          ) : (
                            <div className="inline-flex items-center gap-1.5">
                              <button
                                type="button"
                                onClick={() => handlePermanentBanIp(targetIpHash, item.maskedIp)}
                                disabled={quarantineActionLoading === `ban_ip_${targetIpHash}`}
                                className="px-2.5 py-1 bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-200/70 rounded-lg text-[11px] font-semibold transition-all cursor-pointer shadow-2xs disabled:opacity-50"
                              >
                                Phong tỏa IP
                              </button>
                              <button
                                type="button"
                                onClick={() => handleUnblockIp(targetIpHash, item.maskedIp)}
                                disabled={quarantineActionLoading === `unblock_ip_${targetIpHash}`}
                                className="px-2.5 py-1 bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200/70 rounded-lg text-[11px] font-semibold transition-all cursor-pointer shadow-2xs disabled:opacity-50"
                              >
                                Mở khóa IP
                              </button>
                            </div>
                          )}
                        </td>

                        {/* CỘT THAO TÁC TÀI KHOẢN */}
                        <td className="py-3 px-3 text-center whitespace-nowrap">
                          {targetAccount ? (
                            isAccountPermanent ? (
                              <span className="px-2.5 py-1 rounded-md text-[11px] font-semibold bg-rose-50 text-rose-700 border border-rose-200/60 inline-block">
                                Tài khoản đã bị phong tỏa
                              </span>
                            ) : isAccountUnlocked ? (
                              <button
                                type="button"
                                onClick={() => handleTemporaryBlockAccount(item.username, item.idaccount)}
                                disabled={quarantineActionLoading === `temp_acc_${targetAccount}`}
                                className="px-2.5 py-1 bg-amber-50 hover:bg-amber-100 text-amber-700 border border-amber-200/70 rounded-lg text-[11px] font-semibold transition-all cursor-pointer shadow-2xs disabled:opacity-50"
                              >
                                Tạm khóa TK
                              </button>
                            ) : (
                              <div className="inline-flex items-center gap-1.5">
                                <button
                                  type="button"
                                  onClick={() => handlePermanentBanAccount(item.username, item.idaccount)}
                                  disabled={quarantineActionLoading === `ban_acc_${targetAccount}`}
                                  className="px-2.5 py-1 bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-200/70 rounded-lg text-[11px] font-semibold transition-all cursor-pointer shadow-2xs disabled:opacity-50"
                                >
                                  Phong tỏa TK
                                </button>
                                <button
                                  type="button"
                                  onClick={() => handleUnblockAccount(item.username, item.idaccount)}
                                  disabled={quarantineActionLoading === `unblock_acc_${targetAccount}`}
                                  className="px-2.5 py-1 bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200/70 rounded-lg text-[11px] font-semibold transition-all cursor-pointer shadow-2xs disabled:opacity-50"
                                >
                                  Mở khóa TK
                                </button>
                              </div>
                            )
                          ) : (
                            <span className="text-slate-400 font-normal italic">--</span>
                          )}
                        </td>

                        {/* CỘT THAO TÁC - CON MẮT MỞ FORENSICS */}
                        <td className="py-3 px-3 text-center whitespace-nowrap">
                          <button
                            type="button"
                            onClick={() => handleOpenForensics(targetIpHash, item.maskedIp, targetAccount)}
                            className="w-7 h-7 rounded-lg bg-blue-50 hover:bg-blue-100 text-blue-600 border border-blue-200 flex items-center justify-center transition-all cursor-pointer mx-auto shadow-2xs"
                            title={t('aiops.quarantine.viewForensicsTitle', 'Mở hồ sơ điều tra an ninh')}
                            data-testid={`forensics-action-btn-${targetIpHash || idx}`}
                          >
                            <span className="material-symbols-outlined text-[16px]">visibility</span>
                          </button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            {/* Phân trang Nguồn theo dõi đặc biệt */}
            <Pagination
              currentPage={quarantinePage}
              pageSize={quarantinePageSize}
              total={filteredQuarantineList.length}
              pageSizeOptions={[5, 10, 20]}
              onPageChange={(p) => setQuarantinePage(p)}
              onPageSizeChange={(s) => {
                setQuarantinePageSize(s);
                setQuarantinePage(1);
              }}
              itemLabel={t('aiops.quarantine.itemLabel', 'nguồn theo dõi')}
            />
          </div>
          ) : (
            <div className="p-8 text-center rounded-xl bg-slate-50/80 border border-slate-200/60 space-y-2">
              <span className="material-symbols-outlined text-[32px] text-slate-400">filter_alt_off</span>
              <p className="font-bold text-xs text-slate-700 m-0">
                {t('aiops.quarantine.noFilteredResults', 'Không tìm thấy nguồn nào khớp với bộ lọc IP / Tài khoản')}
              </p>
              <p className="text-[11px] text-slate-500 m-0">
                {t('aiops.quarantine.noFilteredResultsDesc', 'Hãy thử điều chỉnh từ khóa tìm kiếm hoặc bấm Xóa lọc để xem toàn bộ danh sách.')}
              </p>
            </div>
          )
        ) : (
          <div className="p-6 text-center rounded-xl bg-slate-50/80 border border-slate-200/60 space-y-2">
            <span className="material-symbols-outlined text-[36px] text-emerald-600">gpp_good</span>
            <p className="font-bold text-xs text-slate-800">{t('aiops.quarantine.emptyTitle', 'Không có nguồn nào trong danh sách theo dõi đặc biệt')}</p>
            <p className="text-[11px] text-slate-500 max-w-md mx-auto">
              {t('aiops.quarantine.emptyDesc', 'AIOps Sentinel liên tục theo dõi và sẵn sàng kích hoạt tường lửa tức thì nếu phát hiện nguồn bất thường.')}
            </p>
          </div>
        )}
      </div>

      
      {/* Modal xác nhận làm sạch CSDL Sự Cố */}
      <ConfirmModal
        open={showClearIncidentsModal}
        onConfirm={handleClearIncidents}
        onCancel={() => setShowClearIncidentsModal(false)}
        title={t('aiops.confirmCleanDbTitle', 'Làm sạch Toàn bộ Nhật ký Sự cố CSDL')}
        message={t('aiops.confirmCleanDbMsg', 'Bạn có chắc chắn muốn xóa toàn bộ lịch sử sự cố AIOps trong CSDL PostgreSQL? Thao tác này chỉ dùng khi hoàn tất nghiệm thu kiểm thử hoặc bảo trì hệ thống. Hành động này không thể hoàn tác.')}
        confirmDanger={true}
        confirmText={t('aiops.confirmCleanDbBtn', 'Xác nhận Xóa CSDL')}
        cancelText={t('common.cancel', 'Hủy bỏ')}
        loading={clearingIncidents}
      />

      {/* Modal xác nhận phong tỏa nguồn IP từ bảng RCA */}
      <ConfirmModal
        open={quarantineModalTarget !== null}
        onConfirm={handleConfirmQuarantine}
        onCancel={() => setQuarantineModalTarget(null)}
        title={t('aiops.confirmQuarantineTitle', 'Xác nhận Phong Tỏa Nguồn IP (Active Quarantine)')}
        message={
          quarantineModalTarget
            ? t('aiops.confirmQuarantineMsg', `Bạn có chắc chắn muốn kích hoạt Khiên Chắn Active Quarantine cô lập kết nối từ nguồn IP [${
                formatMaskedIp(quarantineModalTarget.actor?.maskedIp || quarantineModalTarget.actor?.rawIp || quarantineModalTarget.actor_identity || quarantineModalTarget.actorIdentity || '192.168.xxx.xxx')
              }]${
                quarantineModalTarget.actor_hash || quarantineModalTarget.actorHash
                  ? ` (Hash: #${(quarantineModalTarget.actor_hash || quarantineModalTarget.actorHash).slice(0, 8)})`
                  : ''
              } trong vòng 4 giờ? Mọi request từ IP này sẽ bị ngắt kết nối với mã lỗi HTTP 403.`, {
                ip: formatMaskedIp(quarantineModalTarget.actor?.maskedIp || quarantineModalTarget.actor?.rawIp || quarantineModalTarget.actor_identity || quarantineModalTarget.actorIdentity || '192.168.xxx.xxx'),
                hash: quarantineModalTarget.actor_hash || quarantineModalTarget.actorHash
                  ? ` (Hash: #${(quarantineModalTarget.actor_hash || quarantineModalTarget.actorHash).slice(0, 8)})`
                  : ''
              })
            : ''
        }
        confirmDanger={true}
        confirmText={quarantiningActor ? t('common.processing', 'Đang xử lý...') : t('aiops.confirmQuarantineBtn', 'Xác Nhận Phong Tỏa')}
        cancelText={t('common.cancel', 'Hủy bỏ')}
        loading={quarantiningActor}
      />

      {/* Modal xác nhận BẬT / TẮT Vector Rủi Ro */}
      <ConfirmModal
        open={vectorToggleModal.open}
        onConfirm={handleConfirmToggleVector}
        onCancel={() => setVectorToggleModal({ open: false, vector: null, targetState: false, vectorName: '', loading: false })}
        title={vectorToggleModal.targetState ? t('aiops.toggleVector.titleEnable', 'Xác nhận BẬT Vector') : t('aiops.toggleVector.titleDisable', 'Xác nhận TẮT Vector')}
        message={
          vectorToggleModal.targetState
            ? t('aiops.toggleVector.messageEnable', `Bạn có chắc chắn muốn BẬT lại "${vectorToggleModal.vectorName}"? Vector này sẽ được tính vào Threat Score tổng hợp và kích hoạt các phản ứng phòng vệ tự động khi vượt ngưỡng an toàn.`, { name: vectorToggleModal.vectorName })
            : t('aiops.toggleVector.messageDisable', `Bạn có chắc chắn muốn TẮT "${vectorToggleModal.vectorName}"? Hệ thống VẪN TIẾP TỤC ĐO LƯỜNG thông số để bạn quan sát, nhưng HOÀN TOÀN KHÔNG TÍNH vào Threat Score chung và KHÔNG kích hoạt phản ứng phòng vệ cho vector này.`, { name: vectorToggleModal.vectorName })
        }
        confirmDanger={!vectorToggleModal.targetState}
        confirmText={
          vectorToggleModal.loading
            ? t('common.processing', 'Đang xử lý...')
            : vectorToggleModal.targetState
            ? t('aiops.toggleVector.confirmEnable', 'Xác nhận BẬT')
            : t('aiops.toggleVector.confirmDisable', 'Xác nhận TẮT')
        }
        cancelText={t('common.cancel', 'Hủy bỏ')}
        loading={vectorToggleModal.loading}
      />

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
                <h3 className="text-base font-bold text-red-950 m-0">{t('aiops.mitigation.modalTitle')}</h3>
                <p className="text-xs text-slate-600 mt-1">
                  {t('aiops.mitigation.modalDesc')}
                </p>
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                {t('aiops.mitigation.reasonLabel')}
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
                {t('common.cancel')}
              </button>

              <button
                type="button"
                onClick={handleTriggerMitigation}
                disabled={mitigating}
                className="px-4 py-2 rounded-xl text-xs font-bold text-white bg-red-600 hover:bg-red-700 transition-all cursor-pointer flex items-center gap-1.5 shadow-sm"
              >
                <span className="material-symbols-outlined text-[16px]">lock</span>
                <span>{mitigating ? t('aiops.mitigation.activating') : t('aiops.mitigation.confirmBtn')}</span>
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
                <h3 className="text-base font-bold text-blue-950 m-0">{t('aiops.calibrate.modalTitle')}</h3>
                <p className="text-xs text-slate-600 mt-1">
                  {t('aiops.calibrate.modalDesc')}
                </p>
              </div>
            </div>

            <div className="rounded-xl bg-blue-50/70 border border-blue-100 p-3.5 space-y-2 text-xs text-slate-700 leading-relaxed">
              <div className="font-bold text-blue-950 flex items-center justify-between">
                <span className="flex items-center gap-1.5">
                  <span className="material-symbols-outlined text-[16px] text-blue-600">tune</span>
                  <span>Quy mô áp dụng:</span>
                </span>
                <span className="font-mono text-blue-700 font-bold bg-blue-100 px-2 py-0.5 rounded-md text-[11px]">
                  {selectedConcurrency.toLocaleString('vi-VN')} CCU
                </span>
              </div>
              <p className="text-[11px] text-slate-600">
                Hệ thống sẽ lấy thông số phần cứng thực tế của máy chủ đang chạy (Số nhân CPU, Tổng RAM vật lý) kết hợp với quy mô <strong>{selectedConcurrency.toLocaleString('vi-VN')} người dùng</strong> để tính toán lại chính xác đường chuẩn 24h và đánh giá năng lực chịu tải thực tế.
              </p>
              <div className="font-bold text-blue-950 flex items-center gap-1.5 pt-1">
                <span className="material-symbols-outlined text-[16px] text-blue-600">help</span>
                <span>{t('aiops.calibrate.warningTitle')}</span>
              </div>
              <ul className="list-disc pl-4 space-y-1 text-[11px] text-slate-600">
                <li>
                  {t('aiops.calibrate.point1')}
                </li>
                <li>
                  {t('aiops.calibrate.point2')}
                </li>
              </ul>
            </div>

            <div className="flex items-center justify-end gap-2.5 pt-2 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setShowCalibrateModal(false)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-600 hover:bg-slate-100 transition-colors cursor-pointer"
              >
                {t('common.close')}
              </button>

              <button
                type="button"
                onClick={handleCalibrate}
                disabled={calibrating}
                className="px-4 py-2 rounded-xl text-xs font-bold text-white bg-blue-600 hover:bg-blue-700 transition-all cursor-pointer flex items-center gap-1.5 shadow-sm"
              >
                <span className="material-symbols-outlined text-[16px]">check_circle</span>
                <span>{calibrating ? t('aiops.calibrate.calibratingBtn') : t('aiops.calibrate.confirmBtn')}</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ======================================================== */}
      {/* MODAL HỒ SƠ ĐIỀU TRA AN NINH & QUAN HỆ N-N (FORENSICS) */}
      {/* ======================================================== */}
      {forensicsModal.open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-xs p-4" data-testid="forensics-modal">
          <div className="bg-white rounded-2xl max-w-3xl w-full p-6 shadow-xl border border-slate-200 space-y-4 animate-in fade-in zoom-in-95 duration-150 flex flex-col max-h-[90vh]">
            {/* Header */}
            <div className="flex items-start justify-between border-b border-slate-100 pb-3">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-blue-100 text-blue-700 flex items-center justify-center flex-shrink-0">
                  <span className="material-symbols-outlined text-[24px]">policy</span>
                </div>
                <div>
                  <h3 className="text-base font-bold text-slate-900 m-0">
                    {t('aiops.forensics.modalTitle', 'Hồ Sơ Điều Tra An Ninh (AIOps Security Forensics)')}
                  </h3>
                  <p className="text-xs text-slate-500 mt-0.5 m-0">
                    {t('aiops.forensics.modalDesc', 'Truy vết liên kết vi phạm N-N giữa Địa chỉ IP và Danh tính Tài khoản đã được lưu trữ bền vững')}
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setForensicsModal(prev => ({ ...prev, open: false }))}
                className="text-slate-400 hover:text-slate-600 p-1 rounded-lg hover:bg-slate-100 transition-colors cursor-pointer"
              >
                <span className="material-symbols-outlined text-[20px]">close</span>
              </button>
            </div>

            {/* Target Information & Filter Tabs */}
            <div className="flex flex-wrap items-center justify-between gap-3 bg-slate-50 p-3 rounded-xl border border-slate-200/70">
              <div className="flex items-center gap-3 text-xs">
                <div className="flex items-center gap-1 font-mono">
                  <span className="text-slate-500">IP:</span>
                  <span className="font-bold text-slate-800 bg-white px-2 py-0.5 rounded border border-slate-200">
                    {forensicsModal.maskedIp || 'N/A'}
                  </span>
                </div>
                {forensicsModal.username && forensicsModal.username !== 'N/A' && forensicsModal.username !== 'all' && (
                  <div className="flex items-center gap-1 font-mono">
                    <span className="text-slate-500">Tài khoản:</span>
                    <span className="font-bold text-blue-700 bg-white px-2 py-0.5 rounded border border-blue-200">
                      {forensicsModal.username}
                    </span>
                  </div>
                )}
              </div>

              {/* Filter Tabs */}
              <div className="flex items-center gap-1.5 text-xs">
                <button
                  type="button"
                  onClick={() => fetchForensicsLogs(forensicsModal.ipHash, forensicsModal.username, 1, 'all')}
                  className={`px-2.5 py-1 rounded-lg font-semibold transition-all cursor-pointer ${
                    forensicsModal.activeFilter === 'all'
                      ? 'bg-blue-600 text-white shadow-xs'
                      : 'bg-white text-slate-700 hover:bg-slate-100 border border-slate-200'
                  }`}
                >
                  {t('aiops.forensics.filterAll', 'Tất cả liên kết')}
                </button>
                {forensicsModal.ipHash && (
                  <button
                    type="button"
                    onClick={() => fetchForensicsLogs(forensicsModal.ipHash, forensicsModal.username, 1, 'ip')}
                    className={`px-2.5 py-1 rounded-lg font-semibold transition-all cursor-pointer ${
                      forensicsModal.activeFilter === 'ip'
                        ? 'bg-blue-600 text-white shadow-xs'
                        : 'bg-white text-slate-700 hover:bg-slate-100 border border-slate-200'
                    }`}
                  >
                    {t('aiops.forensics.filterIpOnly', 'Theo IP này')}
                  </button>
                )}
                {forensicsModal.username && forensicsModal.username !== 'N/A' && forensicsModal.username !== 'all' && (
                  <button
                    type="button"
                    onClick={() => fetchForensicsLogs(forensicsModal.ipHash, forensicsModal.username, 1, 'username')}
                    className={`px-2.5 py-1 rounded-lg font-semibold transition-all cursor-pointer ${
                      forensicsModal.activeFilter === 'username'
                        ? 'bg-blue-600 text-white shadow-xs'
                        : 'bg-white text-slate-700 hover:bg-slate-100 border border-slate-200'
                    }`}
                  >
                    {t('aiops.forensics.filterUserOnly', 'Theo TK này')}
                  </button>
                )}
              </div>
            </div>

            {/* Table Incident Logs */}
            <div className="overflow-y-auto flex-1 min-h-[200px]">
              {forensicsModal.loading ? (
                <div className="flex flex-col items-center justify-center h-48 space-y-2 text-slate-500">
                  <span className="material-symbols-outlined text-[32px] animate-spin text-blue-600">sync</span>
                  <span className="text-xs">{t('common.loading', 'Đang nạp hồ sơ điều tra an ninh...')}</span>
                </div>
              ) : forensicsModal.incidents.length > 0 ? (
                <table className="w-full text-left text-xs border-collapse">
                  <thead>
                    <tr className="border-b border-slate-200 bg-slate-100/70 text-slate-700 font-bold uppercase text-[10px] tracking-wider sticky top-0">
                      <th className="py-2.5 px-3">Mã sự cố</th>
                      <th className="py-2.5 px-3">Thời điểm phát hiện</th>
                      <th className="py-2.5 px-3">IP Hash</th>
                      <th className="py-2.5 px-3">Tài khoản vi phạm</th>
                      <th className="py-2.5 px-3">Lý do & Hành vi</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 font-mono">
                    {forensicsModal.incidents.map((incident, idx) => (
                      <tr key={incident.id || idx} className="hover:bg-slate-50 transition-colors">
                        <td className="py-2.5 px-3 font-bold text-slate-800">
                          {incident.incident_code || `#INC-${incident.id}`}
                        </td>
                        <td className="py-2.5 px-3 text-slate-500 font-sans">
                          {incident.detected_at ? formatDateTime(incident.detected_at) : '--'}
                        </td>
                        <td className="py-2.5 px-3 text-slate-700">
                          {incident.ip_hash ? `${incident.ip_hash.slice(0, 10)}...` : '--'}
                        </td>
                        <td className="py-2.5 px-3 font-bold text-blue-700">
                          {incident.username || 'N/A'}
                        </td>
                        <td className="py-2.5 px-3 font-sans font-medium text-slate-800">
                          {incident.reason || '--'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <div className="p-8 text-center rounded-xl bg-slate-50 border border-slate-200/60 space-y-2">
                  <span className="material-symbols-outlined text-[36px] text-slate-400">inventory_2</span>
                  <p className="font-bold text-xs text-slate-700 m-0">
                    {t('aiops.forensics.emptyTitle', 'Chưa có nhật ký sự cố liên đới nào trong CSDL')}
                  </p>
                  <p className="text-[11px] text-slate-500 m-0">
                    {t('aiops.forensics.emptyDesc', 'Hệ thống tự động ghi nhận dữ liệu liên kết N-N khi có hành vi bất thường phát sinh.')}
                  </p>
                </div>
              )}
            </div>

            {/* Footer */}
            <div className="flex items-center justify-between pt-3 border-t border-slate-100 text-xs">
              <span className="text-slate-500 font-medium">
                {t('aiops.forensics.totalCount', `Tổng số: ${forensicsModal.total} sự cố liên đới`, { count: forensicsModal.total })}
              </span>
              <button
                type="button"
                onClick={() => setForensicsModal(prev => ({ ...prev, open: false }))}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl font-bold transition-all cursor-pointer"
              >
                {t('common.close', 'Đóng')}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ======================================================== */}
      {/* MODAL TẠM KHÓA AN NINH THỦ CÔNG (MANUAL QUARANTINE MODAL) */}
      {/* ======================================================== */}
      {showManualQuarantineModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs animate-fadeIn">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-200 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div className="flex items-center gap-2 text-rose-600 font-bold text-base">
                <span className="material-symbols-outlined text-[24px]">lock_clock</span>
                <h3>{t('aiops.quarantine.manualModalTitle', 'Tạm Khóa An Ninh Thủ Công')}</h3>
              </div>
              <button
                type="button"
                onClick={() => setShowManualQuarantineModal(false)}
                className="text-slate-400 hover:text-slate-600 cursor-pointer"
              >
                <span className="material-symbols-outlined text-[20px]">close</span>
              </button>
            </div>

            <form onSubmit={handleSubmitManualQuarantine} className="space-y-4 text-xs">
              {/* Chọn loại đối tượng */}
              <div>
                <label className="block font-bold text-slate-700 mb-1.5">
                  {t('aiops.quarantine.targetTypeLabel', 'Chọn loại đối tượng cần tạm khóa:')}
                </label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setManualQuarantineForm(prev => ({ ...prev, targetType: 'ip' }))}
                    className={`py-2 px-3 rounded-xl border text-center font-bold flex items-center justify-center gap-1.5 cursor-pointer transition-all ${
                      manualQuarantineForm.targetType === 'ip'
                        ? 'bg-rose-50 border-rose-300 text-rose-700 shadow-2xs'
                        : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    <span className="material-symbols-outlined text-[16px]">public</span>
                    <span>Địa chỉ IP</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setManualQuarantineForm(prev => ({ ...prev, targetType: 'account' }))}
                    className={`py-2 px-3 rounded-xl border text-center font-bold flex items-center justify-center gap-1.5 cursor-pointer transition-all ${
                      manualQuarantineForm.targetType === 'account'
                        ? 'bg-rose-50 border-rose-300 text-rose-700 shadow-2xs'
                        : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    <span className="material-symbols-outlined text-[16px]">person</span>
                    <span>Tài khoản</span>
                  </button>
                </div>
              </div>

              {/* Input giá trị */}
              {manualQuarantineForm.targetType === 'ip' ? (
                <div>
                  <label className="block font-bold text-slate-700 mb-1">
                    {t('aiops.quarantine.ipInputLabel', 'Địa chỉ IP (IPv4 / IPv6):')}
                  </label>
                  <input
                    type="text"
                    data-testid="manual-quarantine-ip-input"
                    placeholder="VD: 192.168.1.100 hoặc 203.113.152.12"
                    value={manualQuarantineForm.ipValue}
                    onChange={(e) => setManualQuarantineForm(prev => ({ ...prev, ipValue: e.target.value }))}
                    className="w-full bg-slate-50 border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-800 font-mono focus:bg-white focus:outline-none focus:ring-1 focus:ring-rose-500"
                    autoFocus
                  />
                  <p className="text-[10px] text-slate-500 mt-1">
                    * IP sẽ bị chặn ngay tại tầng mạng và đưa vào danh sách cô lập an ninh.
                  </p>
                </div>
              ) : (
                <div>
                  <label className="block font-bold text-slate-700 mb-1">
                    {t('aiops.quarantine.accountInputLabel', 'Tên đăng nhập (Username) hoặc ID Tài khoản:')}
                  </label>
                  <input
                    type="text"
                    data-testid="manual-quarantine-account-input"
                    placeholder="VD: user_test hoặc id 123"
                    value={manualQuarantineForm.accountValue}
                    onChange={(e) => setManualQuarantineForm(prev => ({ ...prev, accountValue: e.target.value }))}
                    className="w-full bg-slate-50 border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-800 focus:bg-white focus:outline-none focus:ring-1 focus:ring-rose-500"
                    autoFocus
                  />
                  <p className="text-[10px] text-slate-500 mt-1">
                    * Tài khoản sẽ bị khóa tạm thời trong CSDL (status = Locked) ngăn đăng nhập.
                  </p>
                </div>
              )}

              {/* Thời gian tạm khóa */}
              <div>
                <label className="block font-bold text-slate-700 mb-1">
                  {t('aiops.quarantine.durationLabel', 'Thời hạn tạm khóa:')}
                </label>
                <select
                  data-testid="manual-quarantine-duration-select"
                  value={manualQuarantineForm.durationMinutes}
                  onChange={(e) => setManualQuarantineForm(prev => ({ ...prev, durationMinutes: Number(e.target.value) }))}
                  className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-rose-500 cursor-pointer"
                >
                  <option value={60}>1 giờ (60 phút)</option>
                  <option value={240}>4 giờ (240 phút - Chuẩn an ninh)</option>
                  <option value={720}>12 giờ (720 phút)</option>
                  <option value={1440}>24 giờ (1 ngày)</option>
                </select>
              </div>

              {/* Lý do tạm khóa */}
              <div>
                <label className="block font-bold text-slate-700 mb-1">
                  {t('aiops.quarantine.reasonLabel', 'Lý do tạm khóa an ninh:')}
                </label>
                <textarea
                  rows={2}
                  data-testid="manual-quarantine-reason-input"
                  placeholder="Ghi chú lý do..."
                  value={manualQuarantineForm.reason}
                  onChange={(e) => setManualQuarantineForm(prev => ({ ...prev, reason: e.target.value }))}
                  className="w-full bg-slate-50 border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-800 focus:bg-white focus:outline-none focus:ring-1 focus:ring-rose-500"
                />
              </div>

              {/* Action buttons */}
              <div className="flex items-center justify-end gap-2 pt-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setShowManualQuarantineModal(false)}
                  className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl font-bold cursor-pointer transition-colors"
                >
                  {t('common.cancel', 'Hủy')}
                </button>
                <button
                  type="submit"
                  data-testid="submit-manual-quarantine-btn"
                  disabled={manualQuarantineLoading}
                  className="px-4 py-2 bg-rose-600 hover:bg-rose-700 text-white rounded-xl font-bold shadow-xs cursor-pointer transition-all disabled:opacity-50 inline-flex items-center gap-1.5"
                >
                  {manualQuarantineLoading && <span className="material-symbols-outlined text-[16px] animate-spin">sync</span>}
                  <span>{manualQuarantineLoading ? t('common.processing', 'Đang xử lý...') : t('aiops.quarantine.btnConfirmLock', 'Xác nhận Tạm khóa')}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default AIOpsPage;
