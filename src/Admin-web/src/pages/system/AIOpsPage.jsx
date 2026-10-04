import React, { useState, useEffect, useMemo } from 'react';
import aiopsApi from '../../api/aiops.api';
import adminApi from '../../api/admin.api';
import useSocket from '../../hooks/useSocket';
import { formatDateTime } from '../../utils/format';
import Pagination from '../../components/common/Pagination';
import ConfirmModal from '../../components/common/ConfirmModal';

const VECTOR_LABELS = {
  auth: '1. Xác Thực & Danh Tính',
  traffic: '2. Lưu Lượng & DoS',
  exploit: '3. Khai Thác Lỗ Hổng',
  resource: '4. Sức Khỏe Tài Nguyên',
};

const AIOpsPage = () => {
  const [statusData, setStatusData] = useState(null);
  const [historyData, setHistoryData] = useState([]);
  const [quarantineList, setQuarantineList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [calibrating, setCalibrating] = useState(false);
  const [unblockingHash, setUnblockingHash] = useState(null);
  const [feedback, setFeedback] = useState(null);

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
  const [mitigationReason, setMitigationReason] = useState('Phòng vệ khẩn cấp AIOps Sentinel do phát hiện nguy cơ cao');
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
      return '1000';
    }
  });
  const [savingScale, setSavingScale] = useState(false);

  // Multi-Vector Trend Chart state & Hover tooltip
  const [activeVectorTab, setActiveVectorTab] = useState('all'); // 'all' | 'auth' | 'traffic' | 'exploit' | 'resource'
  const [hoveredPointIndex, setHoveredPointIndex] = useState(null);

  // Time Selection & Precision Range State (Multi-Vector Trend Chart)
  const [timePreset, setTimePreset] = useState('realtime'); // 'realtime' | 'day' | 'month' | 'year'
  const [customFilterType, setCustomFilterType] = useState('date'); // 'date' | 'month' | 'year'
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
  const [incidentPageSize, setIncidentPageSize] = useState(10);
  const [incidentTotal, setIncidentTotal] = useState(0);
  const [incidentVectorFilter, setIncidentVectorFilter] = useState('all');
  const [incidentStatusFilter, setIncidentStatusFilter] = useState('all');
  const [incidentSearch, setIncidentSearch] = useState('');
  const [showClearIncidentsModal, setShowClearIncidentsModal] = useState(false);
  const [clearingIncidents, setClearingIncidents] = useState(false);
  const [quarantineModalTarget, setQuarantineModalTarget] = useState(null);
  const [quarantiningActor, setQuarantiningActor] = useState(false);

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
        typeof aiopsApi.getVectorConfig === 'function' ? aiopsApi.getVectorConfig().catch(() => null) : Promise.resolve(null),
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
      setFeedback({ ok: false, msg: 'Không thể tải dữ liệu lịch sử xu hướng.' });
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
      vectorName: VECTOR_LABELS[vectorKey] || vectorKey,
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
      setFeedback({
        ok: true,
        msg: `Đã ${vectorToggleModal.targetState ? 'BẬT' : 'TẮT'} tính điểm cho "${vectorToggleModal.vectorName}". ${
          vectorToggleModal.targetState
            ? 'Vector này hiện được tính vào Threat Score và các cơ chế phòng vệ tự động.'
            : 'Vector này vẫn được đo lường hiển thị nhưng KHÔNG tính vào Threat Score chung.'
        }`,
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
  };

  // Xử lý áp dụng bộ lọc chính xác (Từ ... Đến ...)
  const handleApplyCustomRange = () => {
    if (!customRange.from || !customRange.to) {
      setFeedback({
        ok: false,
        msg: 'Vui lòng chọn đầy đủ thời điểm bắt đầu (Từ) và kết thúc (Đến).',
      });
      return;
    }
    if (customRange.from > customRange.to) {
      setFeedback({
        ok: false,
        msg: 'Thời điểm bắt đầu không được lớn hơn thời điểm kết thúc.',
      });
      return;
    }

    setCustomRange((prev) => ({ ...prev, applied: true }));
    fetchHistoryFiltered({ from: customRange.from, to: customRange.to, customApplied: true });
  };

  // Xử lý hủy bỏ bộ lọc chính xác để dùng lại bộ select nhanh
  const handleClearCustomRange = () => {
    setCustomRange({ from: '', to: '', applied: false });
    fetchHistoryFiltered({ customApplied: false, preset: timePreset });
  };

  const fetchIncidents = async (
    page = incidentPage,
    limit = incidentPageSize,
    vector = incidentVectorFilter,
    status = incidentStatusFilter,
    search = incidentSearch
  ) => {
    try {
      const res = await aiopsApi.getIncidents({ page, limit, vector, status, search });
      const data = res?.data || res;
      if (data && data.incidents) {
        setIncidentsList(data.incidents);
        setIncidentTotal(data.total || 0);
      }
    } catch (err) {
      console.error('[AIOpsPage] Error fetching incidents:', err);
    }
  };

  useEffect(() => {
    fetchAIOpsData();
    fetchIncidents(1, incidentPageSize, incidentVectorFilter, incidentStatusFilter, incidentSearch);

    // Polling dự phòng mỗi 60 giây (luồng chính đã dùng Socket.io stream 3s/lần)
    const interval = setInterval(() => {
      fetchAIOpsData();
    }, 60000);

    return () => clearInterval(interval);
  }, []);

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
      setFeedback({ ok: true, msg: 'Đã làm sạch toàn bộ nhật ký sự cố bất thường thành công.' });
    } catch (err) {
      setFeedback({ ok: false, msg: err?.response?.data?.message || err?.message || 'Xóa nhật ký thất bại' });
    } finally {
      setClearingIncidents(false);
    }
  };

  // Mở modal xác nhận phong tỏa IP từ bảng RCA
  const handleOpenQuarantineModal = (item) => {
    setQuarantineModalTarget(item);
  };

  // Xác nhận phong tỏa IP từ modal
  const handleConfirmQuarantine = async () => {
    if (!quarantineModalTarget) return;
    try {
      setQuarantiningActor(true);
      const actorHash = quarantineModalTarget.actor_hash || quarantineModalTarget.actorHash;
      const actorIdentity = quarantineModalTarget.actor_identity || quarantineModalTarget.actorIdentity;
      const code = quarantineModalTarget.code || 'SỰ CỐ AN NINH';

      const res = await aiopsApi.quarantineActor({
        hash: actorHash,
        ip: actorIdentity && !actorIdentity.includes('xx') ? actorIdentity : null,
        maskedIp: actorIdentity,
        reason: `Admin chủ động phong tỏa từ nhật ký RCA (${code})`,
        durationMinutes: 15,
      });

      const resData = res?.data || res;
      setFeedback({
        ok: true,
        msg: res?.message || `Đã kích hoạt khiên chắn phong tỏa nguồn IP ${actorIdentity || actorHash} thành công trong 15 phút.`,
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
              reason: resData.reason || `Admin phong tỏa từ sự cố ${code}`,
              bannedAt: resData.bannedAt || new Date().toISOString(),
              expiresAt: resData.expiresAt || new Date(Date.now() + 15 * 60 * 1000).toISOString(),
              remainingMinutes: 15,
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
        msg: err?.response?.data?.message || err?.message || 'Phong tỏa nguồn IP thất bại.',
      });
    } finally {
      setQuarantiningActor(false);
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
          threatScore: metrics.threatScore ?? prev?.threatScore ?? 5,
          status: metrics.threatStatus || prev?.status || 'NORMAL',
          vectorScores: metrics.vectorScores || prev?.vectorScores || { auth: 0, traffic: 0, exploit: 0, resource: 0 },
          vectorDefenses: metrics.vectorDefenses || prev?.vectorDefenses || {},
          recommendedAction: metrics.recommendedAction || prev?.recommendedAction || null,
          targetConcurrency: streamConcurrency,
          sample: {
            ...(prev?.sample || {}),
            cpuPercent: metrics.cpuPercent,
            ramPercent: metrics.ramPercent,
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
        msg: `🛡️ [AIOPS ĐÃ CHẶN ĐỨNG NGUỒN TẤN CÔNG] IP ${blockData.maskedIp} đã bị ngắt kết nối lập tức | Lý do: ${blockData.reason}`,
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

    socket.on('admin.metrics_stream', handleMetricsStream);
    socket.on('admin.security_alert', handleAlert);
    socket.on('admin.security_blocked', handleBlocked);
    socket.on('admin.anomaly_detected', handleAnomalyDetected);
    socket.on('admin.maintenance_changed', handleMaintenanceChanged);
    socket.on('system.maintenance_changed', handleMaintenanceChanged);
    socket.on('admin.vector_config_changed', handleVectorConfigChanged);

    return () => {
      socket.off('admin.metrics_stream', handleMetricsStream);
      socket.off('admin.security_alert', handleAlert);
      socket.off('admin.security_blocked', handleBlocked);
      socket.off('admin.anomaly_detected', handleAnomalyDetected);
      socket.off('admin.maintenance_changed', handleMaintenanceChanged);
      socket.off('system.maintenance_changed', handleMaintenanceChanged);
      socket.off('admin.vector_config_changed', handleVectorConfigChanged);
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
      try {
        localStorage.setItem('aiops_target_concurrency', String(val));
      } catch (_) {}
      setStatusData(prev => ({
        ...prev,
        targetConcurrency: val,
      }));
      setFeedback({
        ok: true,
        msg: res?.message || `Đã cập nhật và lưu cứng quy mô chịu tải mục tiêu: ${val.toLocaleString('vi-VN')} người dùng đồng thời!`
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
                  Tình Trạng Hệ Thống:
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
                    <span>Đang bảo trì</span>
                    <span className="text-[10px] opacity-80 uppercase">
                      ({maintenanceStatus.isEmergency ? 'Khẩn cấp' : 'Kỹ thuật'})
                    </span>
                  </span>
                ) : (
                  <span className="px-3 py-1 rounded-full text-xs font-bold tracking-wide flex items-center gap-1.5 shadow-2xs border bg-emerald-100 text-emerald-800 border-emerald-300">
                    <span className="w-2 h-2 rounded-full bg-emerald-500" />
                    <span>Đang hoạt động</span>
                  </span>
                )}
              </div>

              <p className="text-xs opacity-90 mt-1 m-0">
                {maintenanceStatus?.active
                  ? `Hệ thống đang chặn các kết nối Client-app. Lý do: "${maintenanceStatus.reason || 'Bảo trì hệ thống'}"${
                      maintenanceStatus.activatedAt ? ` • Từ: ${formatDateTime(maintenanceStatus.activatedAt)}` : ''
                    }`
                  : 'Các tiến trình lõi, lưu lượng và kết nối Client-app & Admin-web đang vận hành trơn tru không bị giới hạn.'}
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
              <span className="text-slate-400">Quy mô:</span>
              <b className="text-primary">{targetConcurrency.toLocaleString('vi-VN')} CCU</b>
            </div>
            {maintenanceStatus?.active && (
              <a
                href="/broadcast"
                className="px-3 py-1.5 bg-white hover:bg-slate-50 border border-amber-300 text-amber-900 text-xs font-bold rounded-xl shadow-2xs transition-all flex items-center gap-1 cursor-pointer no-underline"
              >
                <span className="material-symbols-outlined text-[15px] text-amber-600">settings</span>
                <span>Điều Hành Bảo Trì</span>
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
            const isEnabled = vectorConfig.auth !== false;
            return (
              <div className={`p-4 rounded-xl border flex flex-col justify-between space-y-3 transition-all ${
                isEnabled ? 'border-outline-variant/70 bg-surface-container-lowest' : 'border-slate-300 bg-slate-50/70 opacity-90'
              }`}>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-amber-600">badge</span>
                      1. Xác Thực & Danh Tính
                    </span>
                    <div className="flex items-center gap-1.5">
                      <span className={`px-2 py-0.5 rounded text-[10px] font-bold border ${isEnabled ? vTheme.badge : 'bg-slate-100 text-slate-500 border-slate-200'}`}>
                        {isEnabled ? vTheme.label : 'Chỉ đo lường'}
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
                        title={`Bấm để ${isEnabled ? 'TẮT' : 'BẬT'} tính điểm vector Xác Thực`}
                      >
                        <span
                          className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                            isEnabled ? 'translate-x-4' : 'translate-x-0'
                          }`}
                        />
                      </button>
                    </div>
                  </div>

                  {!isEnabled && (
                    <div className="px-2 py-1 rounded bg-amber-50 border border-amber-200 text-amber-900 text-[10px] font-semibold flex items-center gap-1">
                      <span className="material-symbols-outlined text-[13px] text-amber-600">visibility</span>
                      <span>Chế độ chỉ đo lường — Bỏ qua khỏi Threat Score</span>
                    </div>
                  )}

                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">/ 100 điểm</span>
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
                          ? 'Đã tắt phòng vệ — Chỉ đo lường'
                          : quarantineList.length > 0
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
            const isEnabled = vectorConfig.traffic !== false;
            return (
              <div className={`p-4 rounded-xl border flex flex-col justify-between space-y-3 transition-all ${
                isEnabled ? 'border-outline-variant/70 bg-surface-container-lowest' : 'border-slate-300 bg-slate-50/70 opacity-90'
              }`}>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-blue-600">waves</span>
                      2. Lưu Lượng & DoS
                    </span>
                    <div className="flex items-center gap-1.5">
                      <span className={`px-2 py-0.5 rounded text-[10px] font-bold border ${isEnabled ? vTheme.badge : 'bg-slate-100 text-slate-500 border-slate-200'}`}>
                        {isEnabled ? vTheme.label : 'Chỉ đo lường'}
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
                        title={`Bấm để ${isEnabled ? 'TẮT' : 'BẬT'} tính điểm vector Lưu Lượng`}
                      >
                        <span
                          className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                            isEnabled ? 'translate-x-4' : 'translate-x-0'
                          }`}
                        />
                      </button>
                    </div>
                  </div>

                  {!isEnabled && (
                    <div className="px-2 py-1 rounded bg-amber-50 border border-amber-200 text-amber-900 text-[10px] font-semibold flex items-center gap-1">
                      <span className="material-symbols-outlined text-[13px] text-amber-600">visibility</span>
                      <span>Chế độ chỉ đo lường — Bỏ qua khỏi Threat Score</span>
                    </div>
                  )}

                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">/ 100 điểm</span>
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
                          ? 'Đã tắt phòng vệ — Chỉ đo lường'
                          : isThrottling
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
            const isEnabled = vectorConfig.exploit !== false;
            return (
              <div className={`p-4 rounded-xl border flex flex-col justify-between space-y-3 transition-all ${
                isEnabled ? 'border-outline-variant/70 bg-surface-container-lowest' : 'border-slate-300 bg-slate-50/70 opacity-90'
              }`}>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-rose-600">bug_report</span>
                      3. Khai Thác Lỗ Hổng
                    </span>
                    <div className="flex items-center gap-1.5">
                      <span className={`px-2 py-0.5 rounded text-[10px] font-bold border ${isEnabled ? vTheme.badge : 'bg-slate-100 text-slate-500 border-slate-200'}`}>
                        {isEnabled ? vTheme.label : 'Chỉ đo lường'}
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
                        title={`Bấm để ${isEnabled ? 'TẮT' : 'BẬT'} tính điểm vector Khai Thác`}
                      >
                        <span
                          className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                            isEnabled ? 'translate-x-4' : 'translate-x-0'
                          }`}
                        />
                      </button>
                    </div>
                  </div>

                  {!isEnabled && (
                    <div className="px-2 py-1 rounded bg-amber-50 border border-amber-200 text-amber-900 text-[10px] font-semibold flex items-center gap-1">
                      <span className="material-symbols-outlined text-[13px] text-amber-600">visibility</span>
                      <span>Chế độ chỉ đo lường — Bỏ qua khỏi Threat Score</span>
                    </div>
                  )}

                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">/ 100 điểm</span>
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
                          ? 'Đã tắt phòng vệ — Chỉ đo lường'
                          : isExploitActive
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
            const isEnabled = vectorConfig.resource !== false;
            return (
              <div className={`p-4 rounded-xl border flex flex-col justify-between space-y-3 transition-all ${
                isEnabled ? 'border-outline-variant/70 bg-surface-container-lowest' : 'border-slate-300 bg-slate-50/70 opacity-90'
              }`}>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-teal-600">memory</span>
                      4. Sức Khỏe Tài Nguyên
                    </span>
                    <div className="flex items-center gap-1.5">
                      <span className={`px-2 py-0.5 rounded text-[10px] font-bold border ${isEnabled ? vTheme.badge : 'bg-slate-100 text-slate-500 border-slate-200'}`}>
                        {isEnabled ? vTheme.label : 'Chỉ đo lường'}
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
                        title={`Bấm để ${isEnabled ? 'TẮT' : 'BẬT'} tính điểm vector Tài Nguyên`}
                      >
                        <span
                          className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                            isEnabled ? 'translate-x-4' : 'translate-x-0'
                          }`}
                        />
                      </button>
                    </div>
                  </div>

                  {!isEnabled && (
                    <div className="px-2 py-1 rounded bg-amber-50 border border-amber-200 text-amber-900 text-[10px] font-semibold flex items-center gap-1">
                      <span className="material-symbols-outlined text-[13px] text-amber-600">visibility</span>
                      <span>Chế độ chỉ đo lường — Bỏ qua khỏi Threat Score</span>
                    </div>
                  )}

                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">/ 100 điểm</span>
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
                          ? 'Đã tắt phòng vệ — Chỉ đo lường'
                          : isEmergencyResourceRisk
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
              {(() => {
                if (customRange.applied && customRange.from && customRange.to) {
                  return `Biểu Đồ Xu Hướng 4 Vectơ Rủi Ro — Tùy Biến Chính Xác (${customRange.from} → ${customRange.to})`;
                }
                if (timePreset === 'day') return 'Biểu Đồ Xu Hướng 4 Vectơ Rủi Ro — 24 Giờ Qua (Theo Ngày)';
                if (timePreset === 'month') return 'Biểu Đồ Xu Hướng 4 Vectơ Rủi Ro — 30 Ngày Qua (Theo Tháng)';
                if (timePreset === 'year') return 'Biểu Đồ Xu Hướng 4 Vectơ Rủi Ro — 12 Tháng Qua (Theo Năm)';
                return 'Biểu Đồ Xu Hướng 4 Vectơ Rủi Ro Độc Lập Thời Gian Thực (60 Mẫu Gần Nhất — 10 Phút)';
              })()}
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

        {/* ======================================================== */}
        {/* BỘ LỌC THỜI GIAN: BỘ SELECT PRESETS VÀ BỘ LỌC CHÍNH XÁC */}
        {/* ======================================================== */}
        <div className="p-3.5 rounded-xl bg-slate-50/80 border border-slate-200/80 space-y-3">
          {/* Hàng 1: Bộ Select thời gian nhanh (Presets) */}
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="text-xs font-bold text-slate-700 flex items-center gap-1">
                <span className="material-symbols-outlined text-[16px] text-primary">history_toggle_drop_down</span>
                <span>Bộ chọn thời gian quan sát:</span>
              </span>
              {[
                { id: 'realtime', label: 'Thời gian thực (10 phút)' },
                { id: 'day', label: 'Ngày (24 giờ qua)' },
                { id: 'month', label: 'Tháng (30 ngày qua)' },
                { id: 'year', label: 'Năm (12 tháng qua)' },
              ].map((p) => {
                const isSelected = timePreset === p.id && !customRange.applied;
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
                    title={customRange.applied ? 'Click để bỏ qua bộ lọc chính xác và áp dụng preset này' : undefined}
                  >
                    {p.label}
                  </button>
                );
              })}
            </div>

            {fetchingHistory && (
              <span className="text-[11px] font-semibold text-primary flex items-center gap-1">
                <span className="material-symbols-outlined text-[14px] animate-spin">sync</span>
                <span>Đang tải dữ liệu...</span>
              </span>
            )}
          </div>

          {/* Hàng 2: Bộ lọc chọn từ ... đến ... chi tiết chính xác */}
          <div className="pt-2 border-t border-slate-200/60 flex flex-col lg:flex-row lg:items-center justify-between gap-3">
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-xs font-bold text-slate-700 flex items-center gap-1">
                <span className="material-symbols-outlined text-[16px] text-indigo-600">date_range</span>
                <span>Bộ lọc chính xác:</span>
              </span>

              {/* Loại bộ lọc: Ngày / Tháng / Năm */}
              <div className="inline-flex rounded-lg border border-slate-300 p-0.5 bg-white text-xs">
                {[
                  { id: 'date', label: 'Theo Ngày' },
                  { id: 'month', label: 'Theo Tháng' },
                  { id: 'year', label: 'Theo Năm' },
                ].map((type) => (
                  <button
                    key={type.id}
                    type="button"
                    onClick={() => {
                      setCustomFilterType(type.id);
                      setCustomRange((prev) => ({ ...prev, from: '', to: '' }));
                    }}
                    className={`px-2.5 py-0.5 rounded-md text-[11px] font-semibold transition-all cursor-pointer ${
                      customFilterType === type.id
                        ? 'bg-indigo-600 text-white shadow-2xs'
                        : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
                    }`}
                  >
                    {type.label}
                  </button>
                ))}
              </div>

              {/* Inputs Từ ... Đến ... */}
              <div className="flex items-center gap-1.5 text-xs">
                <span className="text-slate-500 font-medium">Từ:</span>
                {customFilterType === 'date' && (
                  <input
                    type="date"
                    data-testid="filter-from-date"
                    value={customRange.from}
                    onChange={(e) => setCustomRange((prev) => ({ ...prev, from: e.target.value }))}
                    className="bg-white border border-slate-300 rounded-lg px-2.5 py-1 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-primary"
                  />
                )}
                {customFilterType === 'month' && (
                  <input
                    type="month"
                    data-testid="filter-from-month"
                    value={customRange.from}
                    onChange={(e) => setCustomRange((prev) => ({ ...prev, from: e.target.value }))}
                    className="bg-white border border-slate-300 rounded-lg px-2.5 py-1 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-primary"
                  />
                )}
                {customFilterType === 'year' && (
                  <input
                    type="number"
                    data-testid="filter-from-year"
                    min="2020"
                    max="2035"
                    placeholder="2024"
                    value={customRange.from}
                    onChange={(e) => setCustomRange((prev) => ({ ...prev, from: e.target.value }))}
                    className="w-20 bg-white border border-slate-300 rounded-lg px-2.5 py-1 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-primary"
                  />
                )}

                <span className="text-slate-500 font-medium">Đến:</span>
                {customFilterType === 'date' && (
                  <input
                    type="date"
                    data-testid="filter-to-date"
                    value={customRange.to}
                    onChange={(e) => setCustomRange((prev) => ({ ...prev, to: e.target.value }))}
                    className="bg-white border border-slate-300 rounded-lg px-2.5 py-1 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-primary"
                  />
                )}
                {customFilterType === 'month' && (
                  <input
                    type="month"
                    data-testid="filter-to-month"
                    value={customRange.to}
                    onChange={(e) => setCustomRange((prev) => ({ ...prev, to: e.target.value }))}
                    className="bg-white border border-slate-300 rounded-lg px-2.5 py-1 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-primary"
                  />
                )}
                {customFilterType === 'year' && (
                  <input
                    type="number"
                    data-testid="filter-to-year"
                    min="2020"
                    max="2035"
                    placeholder="2026"
                    value={customRange.to}
                    onChange={(e) => setCustomRange((prev) => ({ ...prev, to: e.target.value }))}
                    className="w-20 bg-white border border-slate-300 rounded-lg px-2.5 py-1 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-primary"
                  />
                )}
              </div>

              {/* Action Buttons */}
              <button
                type="button"
                data-testid="apply-custom-range-btn"
                onClick={handleApplyCustomRange}
                className="px-3 py-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-xs font-bold transition-all cursor-pointer shadow-2xs inline-flex items-center gap-1"
              >
                <span className="material-symbols-outlined text-[14px]">tune</span>
                <span>Lọc Chính Xác</span>
              </button>

              {customRange.applied && (
                <button
                  type="button"
                  data-testid="clear-custom-range-btn"
                  onClick={handleClearCustomRange}
                  className="px-2.5 py-1 bg-white hover:bg-slate-100 text-slate-700 border border-slate-300 rounded-lg text-xs font-medium transition-all cursor-pointer inline-flex items-center gap-1"
                >
                  <span className="material-symbols-outlined text-[14px]">close</span>
                  <span>Xóa bộ lọc</span>
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
                  <strong>ĐANG ƯU TIÊN BỘ LỌC CHÍNH XÁC:</strong> Dữ liệu từ <strong>{customRange.from}</strong> đến <strong>{customRange.to}</strong>. Bộ select nhanh đang tạm thời bị bỏ qua.
                </span>
              </div>
              <button
                type="button"
                onClick={handleClearCustomRange}
                className="text-xs font-bold text-amber-800 hover:text-amber-950 underline cursor-pointer whitespace-nowrap self-end sm:self-auto"
              >
                Dùng lại bộ select
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
            {historyData && historyData.length > 0 ? (
              <>
                <span>🕒 Mẫu đầu: {historyData[0]?.timestamp ? formatDateTime(historyData[0].timestamp) : '10 phút trước'}</span>
                {historyData.length > 2 && (
                  <span>🕒 Giữa kỳ: {historyData[Math.floor(historyData.length / 2)]?.timestamp ? formatDateTime(historyData[Math.floor(historyData.length / 2)].timestamp) : '5 phút trước'}</span>
                )}
                <span className="font-semibold text-slate-700">🕒 Mẫu mới nhất: {historyData[historyData.length - 1]?.timestamp ? formatDateTime(historyData[historyData.length - 1].timestamp) : 'Hiện tại'}</span>
              </>
            ) : (
              <>
                <span>🕒 10 phút trước</span>
                <span>🕒 5 phút trước</span>
                <span className="font-semibold text-slate-700">🕒 Hiện tại</span>
              </>
            )}
          </div>

          <div className="text-[10px] text-slate-600 bg-slate-50 px-2.5 py-1 rounded-md border border-slate-200">
            🛡️ <strong>Nguyên tắc:</strong> Phòng vệ được kích hoạt độc lập theo từng vectơ. Tuyệt đối không dùng điểm gộp chung để ngắt kết nối hệ thống.
          </div>
        </div>
      </div>

      {/* ======================================================== */}
      {/* KHỐI 4: BẢNG PHÂN TÍCH NGUYÊN NHÂN GỐC RỄ (ROOT CAUSE ANALYSIS) - CSDL PERSISTENT JOURNAL */}
      {/* ======================================================== */}
      <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between border-b border-outline-variant pb-3 gap-3">
          <div>
            <h2 className="text-sm font-bold text-on-surface m-0 flex items-center gap-2">
              <span className="material-symbols-outlined text-[18px] text-primary">troubleshoot</span>
              Bóc Tách & Phân Tích Nguyên Nhân Bất Thường (Root Cause Analysis - RCA)
            </h2>
            <p className="text-[11px] text-slate-500 mt-0.5">
              Nhật ký sự cố lưu trữ bền vững trong CSDL (PostgreSQL) — Lưu vĩnh viễn phục vụ điều tra truy vết, tuân thủ Luật An ninh mạng & Nghị định 13/2023/NĐ-CP.
            </p>
          </div>

          <div className="flex items-center gap-2.5">
            <span className="text-xs font-semibold px-2.5 py-1 rounded-lg bg-surface-container-low border border-outline-variant/60 flex items-center gap-1.5">
              <span className="material-symbols-outlined text-[15px] text-primary">database</span>
              <span>{incidentTotal} sự cố ghi nhận trong CSDL</span>
            </span>

            {incidentTotal > 0 && (
              <button
                type="button"
                onClick={() => setShowClearIncidentsModal(true)}
                className="px-2.5 py-1 rounded-lg text-xs font-medium text-slate-600 hover:text-red-700 hover:bg-red-50 border border-outline-variant/60 transition-colors flex items-center gap-1 cursor-pointer"
                title="Làm sạch toàn bộ nhật ký sự cố trong CSDL"
              >
                <span className="material-symbols-outlined text-[14px]">delete_sweep</span>
                <span>Làm sạch CSDL</span>
              </button>
            )}
          </div>
        </div>

        {/* Toolbar: Bộ lọc Vector, Trạng thái & Tìm kiếm */}
        <div className="flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-3 pt-1">
          {/* Filters */}
          <div className="flex flex-wrap items-center gap-2">
            {/* Vector Filter Pills */}
            <div className="inline-flex rounded-lg border border-outline-variant/60 p-0.5 bg-surface-container-lowest text-xs">
              {[
                { key: 'all', label: 'Tất cả Vector' },
                { key: 'auth', label: '🛡️ Xác thực' },
                { key: 'traffic', label: '🌐 Lưu lượng' },
                { key: 'exploit', label: '💉 Khai thác' },
                { key: 'resource', label: '⚡ Tài nguyên' },
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
                { key: 'all', label: 'Mọi trạng thái' },
                { key: 'ACTIVE', label: '🔴 Đang diễn ra' },
                { key: 'MITIGATED', label: '🟢 Đã giảm thiểu' },
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
                placeholder="Tìm IP, Hash, User, Mã..."
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
              Lọc
            </button>
          </form>
        </div>

        {/* Table Content */}
        {incidentsList.length > 0 ? (
          <div className="overflow-x-auto rounded-xl border border-outline-variant/70">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b border-outline-variant/80 bg-surface-container-low/60 text-slate-600 font-bold uppercase text-[10px] tracking-wider">
                  <th className="py-2.5 px-3 whitespace-nowrap">Thời điểm & Trạng thái</th>
                  <th className="py-2.5 px-3 whitespace-nowrap">Đối tượng vi phạm (Actor)</th>
                  <th className="py-2.5 px-3 whitespace-nowrap">Vector & Mã Bất Thường</th>
                  <th className="py-2.5 px-3 whitespace-nowrap">Chỉ số đo vs Ngưỡng</th>
                  <th className="py-2.5 px-3">Bóc tách nguyên nhân & Xử lý</th>
                  <th className="py-2.5 px-3 whitespace-nowrap text-center">Thao tác & Phòng vệ</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-outline-variant/40 bg-white">
                {incidentsList.map((item) => {
                  const firstTime = item.first_detected_at || item.firstDetectedAt;
                  const lastTime = item.last_seen_at || item.lastSeenAt;
                  const status = item.status || 'ACTIVE';
                  const hits = item.hits || 1;
                  const actorIdentity = item.actor_identity || item.actorIdentity || '127.0.0.1';
                  const actorHash = item.actor_hash || item.actorHash || '';
                  const userId = item.user_id || item.userId;
                  const username = item.username;
                  const userAgent = item.user_agent || item.userAgent;
                  const endpoint = item.target_endpoint || item.targetEndpoint;
                  const vector = item.vector || 'traffic';
                  const severity = item.severity || 'MEDIUM';
                  const metricCurrent = item.metric_current ?? item.metricCurrent ?? item.current ?? 0;
                  const metricBaseline = item.metric_baseline ?? item.metricBaseline ?? item.baseline ?? 0;
                  const metricUnit = item.metric_unit || item.metricUnit || item.unit || '';
                  const message = item.message || '';
                  const rootCause = item.root_cause_diagnosis || item.rootCauseDiagnosis;
                  const mitigation = item.mitigation_taken || item.mitigationTaken;

                  // Tính tỷ lệ vượt ngưỡng
                  const ratio = metricBaseline > 0 ? (Number(metricCurrent) / Number(metricBaseline)).toFixed(1) : null;

                  // Kiểm tra IP đã nằm trong danh sách cô lập Shield chưa
                  const isQuarantined = quarantineList.some(
                    (q) => q.hash === actorHash || q.maskedIp === actorIdentity
                  );

                  return (
                    <tr key={item.id} className="hover:bg-slate-50/80 transition-colors">
                      {/* Cột 1: Thời điểm & Trạng thái */}
                      <td className="py-3 px-3 align-top whitespace-nowrap space-y-1">
                        <div className="font-semibold text-slate-800 text-[11px]">
                          {formatDateTime(firstTime)}
                        </div>
                        <div>
                          {status === 'ACTIVE' ? (
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-red-100 text-red-800 border border-red-200">
                              <span className="w-1.5 h-1.5 rounded-full bg-red-600 animate-pulse"></span>
                              ĐANG DIỄN RA
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800 border border-emerald-200">
                              <span className="material-symbols-outlined text-[12px]">check_circle</span>
                              ĐÃ GIẢM THIỂU
                            </span>
                          )}
                        </div>
                        <div className="text-[10px] text-slate-500 font-medium">
                          {hits > 1 ? `Lặp lại ${hits} lần` : 'Phát hiện lần 1'}
                        </div>
                        {lastTime && lastTime !== firstTime && (
                          <div className="text-[9px] text-slate-400">
                            Gần nhất: {formatDateTime(lastTime)}
                          </div>
                        )}
                      </td>

                      {/* Cột 2: Đối tượng vi phạm (Actor Identity) */}
                      <td className="py-3 px-3 align-top space-y-1">
                        <div className="flex items-center gap-1.5">
                          <span className="material-symbols-outlined text-[15px] text-slate-500">
                            {userId ? 'account_circle' : 'router'}
                          </span>
                          <span className="font-mono font-bold text-slate-800 text-xs">
                            {actorIdentity}
                          </span>
                          {actorHash && (
                            <span
                              className="text-[10px] font-mono px-1 py-0.2 rounded bg-slate-100 text-slate-600 border border-slate-200"
                              title={`SHA-256 IP Hash: ${actorHash}`}
                            >
                              #{actorHash.slice(0, 8)}
                            </span>
                          )}
                        </div>

                        {(username || userId) && (
                          <div className="text-[10px] font-semibold text-primary flex items-center gap-1">
                            <span className="material-symbols-outlined text-[12px]">badge</span>
                            <span>{username ? `User: ${username}` : `UID: #${userId}`}</span>
                          </div>
                        )}

                        {endpoint && (
                          <div
                            className="text-[10px] font-mono text-slate-600 bg-slate-50 px-1.5 py-0.5 rounded border border-slate-200 max-w-[210px] truncate"
                            title={`Mục tiêu: ${endpoint}`}
                          >
                            🎯 {endpoint}
                          </div>
                        )}

                        {userAgent && (
                          <div
                            className="text-[9px] text-slate-400 max-w-[210px] truncate"
                            title={`User-Agent: ${userAgent}`}
                          >
                            🌐 {userAgent}
                          </div>
                        )}
                      </td>

                      {/* Cột 3: Vector & Mã Bất Thường */}
                      <td className="py-3 px-3 align-top whitespace-nowrap space-y-1.5">
                        <div className="flex items-center gap-1.5">
                          <span
                            className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${
                              vector === 'auth'
                                ? 'bg-purple-100 text-purple-800 border border-purple-200'
                                : vector === 'traffic'
                                ? 'bg-blue-100 text-blue-800 border border-blue-200'
                                : vector === 'exploit'
                                ? 'bg-rose-100 text-rose-800 border border-rose-200'
                                : 'bg-amber-100 text-amber-800 border border-amber-200'
                            }`}
                          >
                            {vector}
                          </span>
                          <span
                            className={`px-1.5 py-0.5 rounded text-[10px] font-bold ${
                              severity === 'HIGH'
                                ? 'bg-red-100 text-red-800'
                                : severity === 'MEDIUM'
                                ? 'bg-amber-100 text-amber-800'
                                : 'bg-slate-100 text-slate-800'
                            }`}
                          >
                            {severity}
                          </span>
                        </div>
                        <div className="font-mono font-bold text-slate-900 text-xs">
                          {item.code}
                        </div>
                      </td>

                      {/* Cột 4: Chỉ số đo được vs Baseline */}
                      <td className="py-3 px-3 align-top whitespace-nowrap space-y-1">
                        <div className="font-bold text-red-600 text-xs">
                          {metricCurrent} {metricUnit}
                        </div>
                        <div className="text-[11px] text-slate-500">
                          Ngưỡng: {metricBaseline} {metricUnit}
                        </div>
                        {ratio && Number(ratio) > 1 && (
                          <span className="inline-block text-[10px] font-bold px-1.5 py-0.2 rounded bg-red-50 text-red-700 border border-red-200">
                            Vượt {ratio}x
                          </span>
                        )}
                      </td>

                      {/* Cột 5: Bóc tách nguyên nhân & Hành động xử lý */}
                      <td className="py-3 px-3 align-top space-y-1.5 max-w-sm">
                        <div className="text-slate-800 font-medium text-xs leading-relaxed">
                          {message}
                        </div>

                        {rootCause && (
                          <div className="text-[11px] text-slate-600 bg-slate-50 p-2 rounded-lg border border-slate-200 flex items-start gap-1.5 leading-relaxed">
                            <span className="material-symbols-outlined text-[15px] text-amber-600 shrink-0 mt-0.5">
                              psychology
                            </span>
                            <span>{rootCause}</span>
                          </div>
                        )}

                        {mitigation && (
                          <div className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                            <span className="material-symbols-outlined text-[12px]">security</span>
                            <span>{mitigation}</span>
                          </div>
                        )}
                      </td>

                      {/* Cột 6: Thao tác & Phòng vệ */}
                      <td className="py-3 px-3 align-top text-center whitespace-nowrap">
                        {isQuarantined ? (
                          <div className="space-y-1">
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-lg text-[10px] font-bold bg-red-100 text-red-700 border border-red-200">
                              <span className="material-symbols-outlined text-[13px]">block</span>
                              Đã cách ly Shield
                            </span>
                            <div>
                              <button
                                type="button"
                                onClick={() => handleUnblock(actorHash)}
                                disabled={unblockingHash === actorHash}
                                className="text-[10px] font-semibold text-slate-500 hover:text-slate-800 underline transition-colors cursor-pointer"
                                title="Mở khóa và gỡ bỏ địa chỉ IP khỏi danh sách cô lập"
                              >
                                {unblockingHash === actorHash ? 'Đang mở...' : 'Gỡ chặn'}
                              </button>
                            </div>
                          </div>
                        ) : vector === 'resource' || actorHash === 'system_host' ? (
                          <span className="inline-flex items-center gap-1 px-2 py-1 rounded-lg text-[10px] font-semibold bg-slate-100 text-slate-600 border border-slate-200">
                            <span className="material-symbols-outlined text-[13px]">tune</span>
                            Nội bộ hệ thống
                          </span>
                        ) : (
                          <div className="space-y-1">
                            <button
                              type="button"
                              onClick={() => handleOpenQuarantineModal(item)}
                              className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[10px] font-bold bg-red-50 hover:bg-red-100 text-red-700 border border-red-200 hover:border-red-300 transition-all shadow-xs active:scale-95 cursor-pointer"
                              title={`Kích hoạt khiên chắn phong tỏa IP ${actorIdentity}`}
                            >
                              <span className="material-symbols-outlined text-[13px]">shield</span>
                              <span>Phong Tỏa IP</span>
                            </button>
                            <div className="text-[9px] text-slate-400">
                              Sentinel giám sát
                            </div>
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
              itemLabel="sự cố ghi nhận"
            />
          </div>
        ) : (
          <div className="p-8 text-center rounded-xl bg-emerald-50/50 border border-emerald-200/80 space-y-2">
            <span className="material-symbols-outlined text-[44px] text-emerald-600">verified</span>
            <p className="font-bold text-sm text-emerald-950">
              {incidentSearch || incidentVectorFilter !== 'all' || incidentStatusFilter !== 'all'
                ? 'Không tìm thấy sự cố nào phù hợp với bộ lọc'
                : 'Chưa có mối nguy hiểm hoặc bất thường nào được ghi nhận'}
            </p>
            <p className="text-xs text-emerald-800/80 max-w-md mx-auto">
              {incidentSearch || incidentVectorFilter !== 'all' || incidentStatusFilter !== 'all' ? (
                <button
                  type="button"
                  onClick={() => {
                    setIncidentVectorFilter('all');
                    setIncidentStatusFilter('all');
                    setIncidentSearch('');
                    setIncidentPage(1);
                    fetchIncidents(1, incidentPageSize, 'all', 'all', '');
                  }}
                  className="font-bold text-primary underline cursor-pointer"
                >
                  Xóa bộ lọc để xem toàn bộ sự cố trong CSDL
                </button>
              ) : (
                'Tất cả 12 thông số hệ thống đang hoạt động ổn định. Mọi bất thường phát sinh sẽ được ghi nhận và lưu trữ vĩnh viễn vào CSDL tại đây.'
              )}
            </p>
          </div>
        )}
      </div>

      {/* Modal xác nhận làm sạch CSDL Sự Cố */}
      <ConfirmModal
        open={showClearIncidentsModal}
        onConfirm={handleClearIncidents}
        onCancel={() => setShowClearIncidentsModal(false)}
        title="Làm sạch Toàn bộ Nhật ký Sự cố CSDL"
        message="Bạn có chắc chắn muốn xóa toàn bộ lịch sử sự cố AIOps trong CSDL PostgreSQL? Thao tác này chỉ dùng khi hoàn tất nghiệm thu kiểm thử hoặc bảo trì hệ thống. Hành động này không thể hoàn tác."
        confirmDanger={true}
        confirmText="Xác nhận Xóa CSDL"
        cancelText="Hủy bỏ"
        loading={clearingIncidents}
      />

      {/* Modal xác nhận phong tỏa nguồn IP từ bảng RCA */}
      <ConfirmModal
        open={quarantineModalTarget !== null}
        onConfirm={handleConfirmQuarantine}
        onCancel={() => setQuarantineModalTarget(null)}
        title="Xác nhận Phong Tỏa Nguồn IP (Active Quarantine)"
        message={
          quarantineModalTarget
            ? `Bạn có chắc chắn muốn kích hoạt Khiên Chắn Active Quarantine cô lập kết nối từ nguồn IP [${
                quarantineModalTarget.actor_identity || quarantineModalTarget.actorIdentity || 'xx.xx.xx.xx'
              }]${
                quarantineModalTarget.actor_hash || quarantineModalTarget.actorHash
                  ? ` (Hash: #${(quarantineModalTarget.actor_hash || quarantineModalTarget.actorHash).slice(0, 8)})`
                  : ''
              } trong vòng 15 phút? Mọi request từ IP này sẽ bị ngắt kết nối với mã lỗi HTTP 403.`
            : ''
        }
        confirmDanger={true}
        confirmText={quarantiningActor ? 'Đang kích hoạt...' : 'Xác Nhận Phong Tỏa'}
        cancelText="Hủy bỏ"
        loading={quarantiningActor}
      />

      {/* Modal xác nhận BẬT / TẮT Vector Rủi Ro */}
      <ConfirmModal
        open={vectorToggleModal.open}
        onConfirm={handleConfirmToggleVector}
        onCancel={() => setVectorToggleModal({ open: false, vector: null, targetState: false, vectorName: '', loading: false })}
        title={`Xác nhận ${vectorToggleModal.targetState ? 'BẬT' : 'TẮT'} Vector`}
        message={
          vectorToggleModal.targetState
            ? `Bạn có chắc chắn muốn BẬT lại "${vectorToggleModal.vectorName}"? Vector này sẽ được tính vào Threat Score tổng hợp và kích hoạt các phản ứng phòng vệ tự động khi vượt ngưỡng an toàn.`
            : `Bạn có chắc chắn muốn TẮT "${vectorToggleModal.vectorName}"? Hệ thống VẪN TIẾP TỤC ĐO LƯỜNG thông số để bạn quan sát, nhưng HOÀN TOÀN KHÔNG TÍNH vào Threat Score chung và KHÔNG kích hoạt phản ứng phòng vệ cho vector này.`
        }
        confirmDanger={!vectorToggleModal.targetState}
        confirmText={
          vectorToggleModal.loading
            ? 'Đang xử lý...'
            : vectorToggleModal.targetState
            ? 'Xác nhận BẬT'
            : 'Xác nhận TẮT'
        }
        cancelText="Hủy bỏ"
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
