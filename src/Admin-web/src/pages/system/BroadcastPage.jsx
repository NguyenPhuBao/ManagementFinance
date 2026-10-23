import React, { useState, useEffect, useCallback, useRef } from 'react';
import adminApi from '../../api/admin.api';
import notificationApi from '../../api/notification.api';
import useSocket from '../../hooks/useSocket';
import { formatDateTime } from '../../utils/format';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import Pagination from '../../components/common/Pagination';
import SecurityConfirmModal from '../../components/common/SecurityConfirmModal';
import TruncateCell from '../../components/common/TruncateCell';

const BROADCAST_LEVELS = [
  { value: 'info', color: 'text-blue-500', icon: 'info' },
  { value: 'warning', color: 'text-amber-500', icon: 'warning' },
  { value: 'critical', color: 'text-red-500', icon: 'error' },
];

const toLocalInputString = (date) => {
  const d = new Date(date);
  const pad = (n) => String(n).padStart(2, '0');
  const year = d.getFullYear();
  const month = pad(d.getMonth() + 1);
  const day = pad(d.getDate());
  const hours = pad(d.getHours());
  const minutes = pad(d.getMinutes());
  return `${year}-${month}-${day}T${hours}:${minutes}`;
};

const BroadcastPage = () => {
  const alert = useAlertSafe();
  const socket = useSocket();
  const { t } = useLanguageSafe();
  const [activeTab, setActiveTab] = useState('maintenance'); // 'maintenance' | 'broadcast'



  // --- State Quản trị Bảo trì ---
  const [maintenance, setMaintenance] = useState({
    active: false,
    isEmergency: true,
    reason: '',
    activatedBy: null,
    activatedAt: null,
    scheduled: null,
  });
  const [loadingMaintenance, setLoadingMaintenance] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [maintenanceFeedback, _setMaintenanceFeedback] = useState(null);

  // Wrapper kích hoạt Global Floating Alert toast đồng thời lưu feedback
  const setMaintenanceFeedback = (fb) => {
    _setMaintenanceFeedback(fb);
    if (fb && alert) {
      if (fb.ok) {
        alert.success(fb.msg, t('broadcast.feedback.maintenanceTitle'));
      } else {
        alert.error(fb.msg, t('broadcast.feedback.errorTitle'));
      }
    }
  };

  // Form Bật/Tắt tức thì (MẶC ĐỊNH LUÔN LÀ BẢO TRÌ KHẨN CẤP)
  const isActionInitiatorRef = useRef(false);
  const [instantReason, setInstantReason] = useState('');

  const [scheduleDatetime, setScheduleDatetime] = useState('');
  const [scheduleEndDatetime, setScheduleEndDatetime] = useState('');
  const [scheduleReason, setScheduleReason] = useState('');
  const [scheduleNotify, setScheduleNotify] = useState(false);
  const [isEmergencyAction, setIsEmergencyAction] = useState(false);
  const [isEmergencySchedule, setIsEmergencySchedule] = useState(false);
  const [showEmergencyConfirmModal, setShowEmergencyConfirmModal] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // PO QUY ĐỊNH: Nút checkbox "Bảo trì khẩn cấp" bị chặn (disabled) khi bảo trì khẩn cấp đã được kích hoạt.
  // Nút KHÔNG bị chặn khi bảo trì định kỳ đang diễn ra hoặc đã lên lịch.
  const isEmergencyBlocked = Boolean(maintenance.active && maintenance.isEmergency);

  useEffect(() => {
    if (isEmergencyBlocked && isEmergencySchedule) {
      setIsEmergencySchedule(false);
    }
  }, [isEmergencyBlocked, isEmergencySchedule]);

  // --- State Lịch Sử Bảo Trì (PostgreSQL Persistence) ---
  const [historyData, setHistoryData] = useState([]);
  const [historyPage, setHistoryPage] = useState(1);
  const [historyLimit, setHistoryLimit] = useState(5);
  const [historyTotal, setHistoryTotal] = useState(0);
  const [historyTotalPages, setHistoryTotalPages] = useState(1);
  const [loadingHistory, setLoadingHistory] = useState(false);
  const [historyFilterType, setHistoryFilterType] = useState('ALL');
  const [historyFilterStatus, setHistoryFilterStatus] = useState('ALL');

  const historyPagination = {
    page: historyPage,
    limit: historyLimit,
    total: historyTotal,
    totalPages: historyTotalPages,
  };

  // --- State Phát Thông Báo ---
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [level, setLevel] = useState('info');
  const [sending, setSending] = useState(false);
  const [broadcastResult, setBroadcastResult] = useState(null);

  // --- State Lịch Sử Phát Thông Báo (PostgreSQL Persistence) ---
  const [broadcastHistory, setBroadcastHistory] = useState([]);
  const [broadcastPage, setBroadcastPage] = useState(1);
  const [broadcastLimit, setBroadcastLimit] = useState(5);
  const [broadcastTotal, setBroadcastTotal] = useState(0);
  const [loadingBroadcastHistory, setLoadingBroadcastHistory] = useState(false);

  // State Modal popup xác nhận kết thúc bảo trì
  const [showStopMaintenanceConfirmModal, setShowStopMaintenanceConfirmModal] = useState(false);

  // Tải trạng thái bảo trì
  const fetchMaintenance = async () => {
    try {
      setLoadingMaintenance(true);
      const res = await adminApi.getMaintenanceStatus();
      const data = res?.data || res;
      if (data) {
        setMaintenance(data);
        if (data.reason && data.active) {
          setInstantReason(data.reason);
        }
      }
    } catch (err) {
      console.error('[BroadcastPage] Lỗi lấy trạng thái bảo trì', err);
    } finally {
      setLoadingMaintenance(false);
    }
  };

  // Tải lịch sử phát thông báo từ CSDL PostgreSQL (Phân trang mặc định 5/page)
  const fetchBroadcastHistory = useCallback(async (pageToFetch = 1, limitToFetch = 5) => {
    try {
      setLoadingBroadcastHistory(true);
      const res = await notificationApi.getBroadcastHistory({ page: pageToFetch, limit: limitToFetch });
      const payload = res?.data?.data || res?.data || res;
      let rows = [];
      let total = 0;

      if (payload && Array.isArray(payload.data)) {
        rows = payload.data;
        if (payload.pagination) {
          total = Number(payload.pagination.total) || 0;
        } else {
          total = rows.length;
        }
      } else if (Array.isArray(payload)) {
        rows = payload;
        total = rows.length;
      }

      setBroadcastHistory(rows);
      setBroadcastTotal(total);
      setBroadcastPage(pageToFetch);
      setBroadcastLimit(limitToFetch);
    } catch (err) {
      console.error('[BroadcastPage] Lỗi tải lịch sử phát thông báo:', err);
    } finally {
      setLoadingBroadcastHistory(false);
    }
  }, []);

  // Tải lịch sử bảo trì từ CSDL PostgreSQL (Trích xuất payload chuẩn hóa)
  const fetchHistory = useCallback(
    async (pageToFetch = 1, limitToFetch = 5) => {
      try {
        setLoadingHistory(true);
        const res = await adminApi.getMaintenanceHistory({
          page: pageToFetch,
          limit: limitToFetch,
          type: historyFilterType !== 'ALL' ? historyFilterType : undefined,
          status: historyFilterStatus !== 'ALL' ? historyFilterStatus : undefined,
        });

        let rows = [];
        let total = 0;
        let totalPages = 1;

        const payload = res?.data !== undefined ? res.data : res;

        if (payload && Array.isArray(payload.data)) {
          rows = payload.data;
          if (payload.pagination) {
            total = Number(payload.pagination.total) || 0;
            totalPages = Number(payload.pagination.totalPages) || Math.max(1, Math.ceil(total / limitToFetch));
          } else {
            total = payload.total !== undefined ? Number(payload.total) : rows.length;
            totalPages = Math.max(1, Math.ceil(total / limitToFetch));
          }
        } else if (Array.isArray(payload)) {
          rows = payload;
          total = rows.length;
          totalPages = Math.max(1, Math.ceil(rows.length / limitToFetch));
        } else if (payload && Array.isArray(payload.items)) {
          rows = payload.items;
          total = payload.total !== undefined ? Number(payload.total) : rows.length;
          totalPages = payload.totalPages || Math.max(1, Math.ceil(total / limitToFetch));
        }

        setHistoryData(rows);
        setHistoryTotal(total);
        setHistoryTotalPages(totalPages);
        setHistoryPage(pageToFetch);
        setHistoryLimit(limitToFetch);
      } catch (err) {
        console.error('[BroadcastPage] Lỗi tải lịch sử bảo trì:', err);
      } finally {
        setLoadingHistory(false);
      }
    },
    [historyFilterType, historyFilterStatus]
  );

  useEffect(() => {
    fetchMaintenance();
    fetchHistory(1, historyLimit);
    fetchBroadcastHistory(1, broadcastLimit);
  }, [fetchHistory, fetchBroadcastHistory]);

  // Lắng nghe sự kiện bảo trì Realtime qua Socket.io
  useEffect(() => {
    if (!socket) return;

    const handleMaintenanceChanged = (mState) => {
      console.log('[BroadcastPage] Nhận sự kiện maintenance_changed realtime:', mState);
      if (mState) {
        setMaintenance(mState);
        if (mState.reason && mState.active) {
          setInstantReason(mState.reason);
        }

        // Nếu chính admin tại tab này vừa nhấn nút thao tác, setMaintenanceFeedback đã báo toast thành công
        // -> Không kích hoạt thêm toast từ socket để chống lặp thông báo
        if (isActionInitiatorRef.current) {
          isActionInitiatorRef.current = false;
        } else if (alert) {
          if (mState.active) {
            alert.warning(
              mState.reason || t('broadcast.feedback.emergencyActivated', 'Hệ thống đã chuyển sang chế độ BẢO TRÌ KHẨN CẤP!'),
              t('broadcast.feedback.maintenanceTitle', 'Quản Trị Bảo Trì')
            );
          } else {
            alert.success(
              t('broadcast.feedback.maintenanceRestored', 'Đã kết thúc bảo trì, hệ thống hoạt động bình thường trở lại.'),
              t('broadcast.feedback.maintenanceTitle', 'Quản Trị Bảo Trì')
            );
          }
        }
        // Tự động làm mới danh sách lịch sử khi có biến động
        fetchHistory(historyPage, historyLimit);
      }
    };

    // CHỈ lắng nghe kênh admin.maintenance_changed (bỏ system.maintenance_changed dành cho client-app)
    socket.on('admin.maintenance_changed', handleMaintenanceChanged);

    return () => {
      socket.off('admin.maintenance_changed', handleMaintenanceChanged);
    };
  }, [socket, fetchHistory, historyPage, historyLimit]);

  // Hàm tính thời lượng bảo trì
  const formatDuration = (startedAt, endedAt) => {
    if (!startedAt) return '—';
    const start = new Date(startedAt).getTime();
    const end = endedAt ? new Date(endedAt).getTime() : Date.now();
    const diffSec = Math.max(0, Math.floor((end - start) / 1000));
    if (!endedAt) return t('broadcast.history.ongoingText', 'Đang diễn ra...');
    if (diffSec < 60) return `${diffSec}s`;
    const min = Math.floor(diffSec / 60);
    const sec = diffSec % 60;
    if (min < 60) return `${min}m ${sec}s`;
    const h = Math.floor(min / 60);
    const remMin = min % 60;
    return `${h}h ${remMin}m`;
  };

  // Xử lý Bật/Tắt bảo trì khẩn cấp
  const handleToggleMaintenance = async (nextActive) => {
    isActionInitiatorRef.current = true;
    setActionLoading(true);
    setMaintenanceFeedback(null);
    try {
      const payload = {
        active: nextActive,
        reason: instantReason.trim() || t('broadcast.banner.emergencyDesc'),
        isEmergency: true, // MẶC ĐỊNH 100% LUÔN LÀ BẢO TRÌ KHẨN CẤP
      };

      const res = await adminApi.setMaintenanceStatus(payload);
      const data = res?.data || res;
      setMaintenance(data);
      setMaintenanceFeedback({
        ok: true,
        msg: nextActive
          ? t('broadcast.feedback.emergencyActivated')
          : t('broadcast.feedback.maintenanceRestored'),
      });
      if (!nextActive) {
        setInstantReason('');
      }
      fetchHistory(1, historyLimit);
    } catch (err) {
      setMaintenanceFeedback({
        ok: false,
        msg: err.response?.data?.message || t('broadcast.feedback.operationFailed'),
      });
    } finally {
      setActionLoading(false);
    }
  };

  // Xử lý nộp biểu mẫu: Phân nhánh Lên lịch định kỳ vs Kích hoạt khẩn cấp
  const handleScheduleFormSubmit = (e) => {
    e.preventDefault();
    if (isEmergencySchedule) {
      setShowEmergencyConfirmModal(true);
    } else {
      handleSaveSchedule(e);
    }
  };

  // Xử lý Lên lịch bảo trì
  const handleSaveSchedule = async (e) => {
    if (e && e.preventDefault) e.preventDefault();
    if (!scheduleDatetime) return;

    const startMs = new Date(scheduleDatetime).getTime();
    const now = Date.now();
    const minLeadTimeMs = 4 * 3600 * 1000;

    // PO RÀNG BUỘC 1: Bắt buộc đặt trước thời điểm kích hoạt ít nhất 4 tiếng
    if (startMs < now + minLeadTimeMs) {
      setMaintenanceFeedback({
        ok: false,
        msg: t('broadcast.feedback.scheduleMinLeadTime', 'Thời gian bảo trì theo lịch phải được thiết lập trước ít nhất 4 tiếng!'),
      });
      return;
    }

    if (scheduleEndDatetime) {
      const endMs = new Date(scheduleEndDatetime).getTime();
      if (endMs <= startMs) {
        setMaintenanceFeedback({
          ok: false,
          msg: t('broadcast.feedback.scheduleEndBeforeStart', 'Thời điểm kết thúc bảo trì phải sau thời điểm bắt đầu bảo trì!'),
        });
        return;
      }
    }

    setActionLoading(true);
    setMaintenanceFeedback(null);
    isActionInitiatorRef.current = true;
    try {
      const payload = {
        scheduledAt: new Date(scheduleDatetime).toISOString(),
        scheduledEndAt: scheduleEndDatetime ? new Date(scheduleEndDatetime).toISOString() : null,
        reason: scheduleReason.trim() || t('broadcast.scheduleCardDesc', 'Bảo trì hệ thống theo lịch trình định kỳ.'),
        isEmergency: false, // PO: Bảo trì theo lịch luôn là isEmergency: false
      };

      const res = await adminApi.setMaintenanceStatus(payload);
      const data = res?.data || res;
      setMaintenance(data);
      setMaintenanceFeedback({
        ok: true,
        msg: t('broadcast.feedback.scheduleSuccess', {
          time: `${formatDateTime(scheduleDatetime)}${scheduleEndDatetime ? ` - ${formatDateTime(scheduleEndDatetime)}` : ''}`,
        }),
      });
      setScheduleDatetime('');
      setScheduleEndDatetime('');
      setScheduleReason('');
      setScheduleNotify(false);
      fetchHistory(1, historyLimit);
    } catch (err) {
      setMaintenanceFeedback({
        ok: false,
        msg: err.response?.data?.message || t('broadcast.feedback.scheduleFailed', 'Lên lịch bảo trì thất bại'),
      });
    } finally {
      setActionLoading(false);
    }
  };

  // Xử lý Hủy lịch bảo trì đã hẹn (hỗ trợ hủy theo ID cụ thể)
  const handleCancelSchedule = async (id = null) => {
    if (!window.confirm(t('broadcast.schedule.cancelConfirm', 'Bạn có chắc chắn muốn hủy lịch bảo trì này?'))) return;
    setActionLoading(true);
    setMaintenanceFeedback(null);
    isActionInitiatorRef.current = true;
    try {
      const res = await adminApi.cancelScheduledMaintenance(id);
      const data = res?.data || res;
      setMaintenance(data);
      setMaintenanceFeedback({
        ok: true,
        msg: t('broadcast.feedback.cancelSuccess', 'Đã hủy lịch bảo trì thành công'),
      });
      fetchHistory(1, historyLimit);
    } catch (err) {
      setMaintenanceFeedback({
        ok: false,
        msg: err.response?.data?.message || t('broadcast.feedback.cancelFailed', 'Hủy lịch bảo trì thất bại'),
      });
    } finally {
      setActionLoading(false);
    }
  };

  // Xử lý Kích hoạt bảo trì khẩn cấp tức thì (sau khi Admin xác nhận popup)
  const handleConfirmEmergencyMaintenance = async () => {
    setActionLoading(true);
    setMaintenanceFeedback(null);
    isActionInitiatorRef.current = true;
    try {
      const payload = {
        active: true,
        reason: scheduleReason.trim() || instantReason.trim() || t('broadcast.banner.emergencyDesc'),
        isEmergency: true,
      };

      const res = await adminApi.setMaintenanceStatus(payload);
      const data = res?.data || res;
      setMaintenance(data);
      setMaintenanceFeedback({
        ok: true,
        msg: t('broadcast.feedback.emergencyActivated'),
      });
      setIsEmergencySchedule(false);
      fetchHistory(1, historyLimit);
    } catch (err) {
      setMaintenanceFeedback({
        ok: false,
        msg: err.response?.data?.message || t('broadcast.feedback.operationFailed'),
      });
    } finally {
      setActionLoading(false);
    }
  };

  // Xử lý Làm mới trạng thái & Đặt lại biểu mẫu lên lịch bảo trì
  const handleResetScheduleFormAndRefresh = async () => {
    try {
      setIsRefreshing(true);
      setScheduleDatetime('');
      setScheduleEndDatetime('');
      setScheduleReason('');
      setScheduleNotify(false);
      setIsEmergencyAction(false);
      setIsEmergencySchedule(false);
      setMaintenanceFeedback({
        ok: true,
        msg: t('broadcast.feedback.formResetSuccess'),
      });
      await fetchMaintenance();
    } catch (err) {
      console.error('[BroadcastPage] Lỗi làm mới biểu mẫu lên lịch', err);
    } finally {
      setTimeout(() => setIsRefreshing(false), 500);
    }
  };


  // Xử lý Phát Thông Báo Thủ Công
  const handleSendBroadcast = async (e) => {
    e.preventDefault();
    if (!title.trim() || !message.trim()) return;
    setSending(true);
    setBroadcastResult(null);
    try {
      await notificationApi.broadcastToAll({ title: title.trim(), message: message.trim(), level });
      setBroadcastResult({ ok: true, msg: t('broadcast.broadcastSuccessToast') });
      if (alert) alert.success(t('broadcast.broadcastSuccessToast'), t('broadcast.feedback.broadcastSuccessTitle'));
      setTitle('');
      setMessage('');
      setLevel('info');
      fetchBroadcastHistory(1, broadcastLimit);
    } catch (e) {
      const errMsg = e.response?.data?.message || t('broadcast.feedback.broadcastErrorTitle');
      setBroadcastResult({ ok: false, msg: errMsg });
      if (alert) alert.error(errMsg, t('broadcast.feedback.broadcastErrorTitle'));
    } finally {
      setSending(false);
    }
  };

  const selectedBroadcastLevel = BROADCAST_LEVELS.find((l) => l.value === level);

  // Tính toán min datetime cho input
  const currentLocalIso = new Date(Date.now() + 60000).toISOString().slice(0, 16);

  return (
    <div className="max-w-[1720px] mx-auto w-full p-4 md:p-6 space-y-6 bg-surface-bright min-h-full">
      {/* Tiêu đề trang & Thanh chuyển Tab */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-outline-variant pb-4">
        <div>
          <h1 className="font-display-md text-display-md font-bold text-on-surface m-0 tracking-tight flex items-center gap-2">
            {t('broadcast.title')}
          </h1>
        </div>

        {/* Tab Controls */}
        <div className="inline-flex p-1 bg-surface-container-low border border-outline-variant rounded-xl self-start md:self-auto">
          <button
            onClick={() => setActiveTab('maintenance')}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
              activeTab === 'maintenance'
                ? 'bg-white text-primary shadow-xs font-bold'
                : 'text-on-surface-variant hover:text-on-surface'
            }`}
          >
            <span className="material-symbols-outlined text-[18px]">build_circle</span>
            <span>{t('broadcast.tabMaintenance')}</span>
            {maintenance.active ? (
              <span className={`w-2.5 h-2.5 rounded-full ${maintenance.isEmergency ? 'bg-red-500 animate-ping' : 'bg-orange-500'}`} />
            ) : maintenance.scheduled ? (
              <span className="w-2.5 h-2.5 rounded-full bg-blue-500" />
            ) : null}
          </button>

          <button
            onClick={() => {
              setActiveTab('broadcast');
              fetchBroadcastHistory(1, broadcastLimit);
            }}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
              activeTab === 'broadcast'
                ? 'bg-white text-primary shadow-xs font-bold'
                : 'text-on-surface-variant hover:text-on-surface'
            }`}
          >
            <span className="material-symbols-outlined text-[18px]">campaign</span>
            <span>{t('broadcast.tabBroadcast')}</span>
          </button>
        </div>
      </div>

      {/* BANNER THÔNG BÁO ĐANG BẢO TRÌ Ở GẦN ĐẦU TRANG (HIỂN THỊ KHI ĐANG BẢO TRÌ) */}
      {maintenance.active && (
        <div
          id="banner-active-maintenance"
          className={`rounded-2xl border p-5 transition-all shadow-xs ${
            maintenance.isEmergency
              ? 'border-rose-300 bg-rose-50/90 text-rose-950'
              : 'border-amber-300 bg-amber-50/90 text-amber-950'
          }`}
        >
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div className="flex items-start gap-3.5">
              <div
                className={`w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0 shadow-xs ${
                  maintenance.isEmergency
                    ? 'bg-rose-600 text-white animate-pulse'
                    : 'bg-amber-500 text-white'
                }`}
              >
                <span className="material-symbols-outlined text-[26px]">
                  {maintenance.isEmergency ? 'crisis_alert' : 'construction'}
                </span>
              </div>
              <div>
                <div className="flex items-center gap-2 flex-wrap">
                  <h2 className="text-base font-bold m-0">
                    {maintenance.isEmergency
                      ? t('broadcast.banner.emergencyTitle', 'HỆ THỐNG ĐANG BẢO TRÌ KHẨN CẤP')
                      : t('broadcast.banner.scheduledTitle', 'HỆ THỐNG ĐANG BẢO TRÌ')}
                  </h2>
                  <span
                    className={`px-2.5 py-0.5 rounded-full text-[11px] font-bold tracking-wide uppercase ${
                      maintenance.isEmergency
                        ? 'bg-rose-200 text-rose-800'
                        : 'bg-amber-200 text-amber-800'
                    }`}
                  >
                    {maintenance.isEmergency
                      ? t('broadcast.banner.emergencyBadge', 'Khẩn cấp')
                      : t('broadcast.banner.scheduledBadge', 'Theo lịch')}
                  </span>
                </div>
                <p className="text-xs opacity-90 mt-1">
                  {maintenance.isEmergency
                    ? t('broadcast.banner.emergencyDesc', 'Toàn bộ kết nối Client-app bị chặn (HTTP 503). Đã tự động phát cảnh báo đỏ tới người dùng.')
                    : t('broadcast.banner.scheduledDesc', 'Hệ thống đang tiến hành bảo trì kỹ thuật định kỳ theo lịch trình. Toàn bộ tính năng sẽ sớm khôi phục.')}
                </p>
                <div className="mt-2 text-xs flex flex-wrap gap-x-4 gap-y-1 font-medium">
                  <span>• {t('broadcast.banner.reasonLabel', 'Lý do:')} <b>{maintenance.reason || t('broadcast.banner.noReason', 'Bảo trì hệ thống')}</b></span>
                  {maintenance.activatedBy && <span>• {t('broadcast.banner.activatedByLabel', 'Người kích hoạt:')} <b>{maintenance.activatedBy}</b></span>}
                  {maintenance.activatedAt && (
                    <span>• {t('broadcast.banner.activatedAtLabel', 'Bắt đầu lúc:')} <b>{formatDateTime(maintenance.activatedAt)}</b></span>
                  )}
                </div>
              </div>
            </div>

            {/* Nút Tắt Bảo Trì */}
            <button
              id="btn-turn-off-maintenance"
              onClick={() => setShowStopMaintenanceConfirmModal(true)}
              disabled={actionLoading}
              className="px-5 py-2.5 bg-white hover:bg-gray-50 border border-gray-300 text-on-surface text-xs font-bold rounded-xl shadow-xs transition-all cursor-pointer flex items-center justify-center gap-2 self-start md:self-center flex-shrink-0"
            >
              <span className="material-symbols-outlined text-[18px] text-emerald-600">power_settings_new</span>
              <span>{t('broadcast.turnOffBtn', 'Tắt Bảo Trì')}</span>
            </button>
          </div>
        </div>
      )}

      {/* ======================================================== */}
      {/* TAB 1: ĐIỀU HÀNH BẢO TRÌ HỆ THỐNG */}
      {/* ======================================================== */}
      {activeTab === 'maintenance' && (
        <div className="space-y-6">

          {/* Feedback Alert */}
          {maintenanceFeedback && (
            <div
              className={`rounded-xl px-4 py-3 text-xs flex items-center justify-between gap-2 border font-medium ${
                maintenanceFeedback.ok
                  ? 'bg-emerald-50 text-emerald-800 border-emerald-300'
                  : 'bg-red-50 text-red-800 border-red-300'
              }`}
            >
              <div className="flex items-center gap-2">
                <span className="material-symbols-outlined text-[18px]">
                  {maintenanceFeedback.ok ? 'check_circle' : 'cancel'}
                </span>
                <span>{maintenanceFeedback.msg}</span>
              </div>
              <button
                onClick={() => setMaintenanceFeedback(null)}
                className="text-gray-400 hover:text-gray-600 cursor-pointer"
              >
                <span className="material-symbols-outlined text-[16px]">close</span>
              </button>
            </div>
          )}

          {/* PO YÊU CẦU: CARD CẢNH BÁO "LỊCH BẢO TRÌ SẮP DIỄN RA" */}
          {/* CHỈ ĐƯỢC HIỂN THỊ KHI CÒN <= 1 TIẾNG VÀ KHÔNG LÀM MẤT FORM LẬP LỊCH */}
          {(() => {
            const list = Array.isArray(maintenance.scheduledList) && maintenance.scheduledList.length > 0
              ? maintenance.scheduledList
              : (maintenance.scheduled ? [maintenance.scheduled] : []);
            const nearest = list.find((x) => new Date(x.scheduledAt).getTime() > Date.now()) || list[0];
            if (!nearest || maintenance.active) return null;
            const diffMs = new Date(nearest.scheduledAt).getTime() - Date.now();
            if (diffMs <= 0 || diffMs > 3600 * 1000) return null; // ẨN HOÀN TOÀN KHI > 1 TIẾNG
            const minutesLeft = Math.max(1, Math.ceil(diffMs / 60000));

            return (
              <div
                id="card-imminent-maintenance"
                className="p-4 rounded-2xl border border-amber-300 bg-amber-50/95 shadow-xs flex flex-col md:flex-row md:items-center justify-between gap-4 text-amber-950 animate-pulse"
              >
                <div className="flex items-center gap-3.5">
                  <div className="w-11 h-11 rounded-xl bg-amber-500 text-white flex items-center justify-center flex-shrink-0 shadow-xs">
                    <span className="material-symbols-outlined text-[24px]">timer</span>
                  </div>
                  <div>
                    <div className="flex items-center gap-2 flex-wrap">
                      <h3 className="font-bold text-xs uppercase tracking-wider text-amber-900 m-0">
                        ⚠️ LỊCH BẢO TRÌ SẮP DIỄN RA
                      </h3>
                      <span className="px-2 py-0.5 rounded-full text-[11px] font-bold bg-amber-200 text-amber-900">
                        Bắt đầu sau {minutesLeft} phút
                      </span>
                    </div>
                    <p className="text-xs text-amber-900/90 mt-1">
                      Hệ thống sẽ chuyển sang chế độ bảo trì kỹ thuật vào lúc <b>{formatDateTime(nearest.scheduledAt)}</b>.
                      {nearest.reason && <span> Lý do: <i>"{nearest.reason}"</i>.</span>}
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => handleCancelSchedule(nearest.id || nearest.recordId)}
                  disabled={actionLoading}
                  className="px-3 py-1.5 bg-white hover:bg-red-50 text-red-600 border border-red-200 rounded-lg text-xs font-semibold transition-colors cursor-pointer flex items-center gap-1 shadow-2xs self-start md:self-center flex-shrink-0"
                >
                  <span className="material-symbols-outlined text-[15px]">delete_sweep</span>
                  <span>Hủy lịch này</span>
                </button>
              </div>
            );
          })()}

          {/* 1.2 KHUNG ĐIỀU HÀNH & LÊN LỊCH THỜI ĐIỂM BẢO TRÌ */}
          {/* PO QUY ĐỊNH: FORM LẬP LỊCH BẢO TRÌ ĐỊNH KỲ LUÔN LUÔN HIỆN DIỆN VÀ SẴN SÀNG */}
          <div className="bg-white rounded-2xl border border-outline-variant p-5 md:p-6 shadow-sm space-y-5">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-outline-variant pb-3">
              <div>
                <h3 className="font-bold text-sm text-on-surface flex items-center gap-2 m-0">
                  <span className="material-symbols-outlined text-primary text-[20px]">calendar_clock</span>
                  <span>{t('broadcast.scheduleCardTitle', 'Lập Lịch Bảo Trì Kỹ Thuật Định Kỳ')}</span>
                </h3>
                <p className="text-[11px] text-on-surface-variant mt-0.5">
                  Lịch bảo trì phải được đặt trước ít nhất <b>4 tiếng</b> và cách các phiên khác tối thiểu <b>5 tiếng</b>.
                </p>
              </div>
            </div>

            {/* FORM ĐẶT LỊCH / BẢO TRÌ KHẨN CẤP */}
            <form onSubmit={handleScheduleFormSubmit} className="space-y-4">
              {/* PO QUY ĐỊNH: MẶC ĐỊNH KHI BẢO TRÌ ĐỊNH KỲ HAY KHẨN CẤP ĐỀU SẼ PHÁT THÔNG BÁO TỚI USER VÀ ADMIN */}
              <div className="flex items-start gap-2.5 text-xs text-primary bg-primary/5 border border-primary/20 rounded-xl px-3.5 py-2.5">
                <span className="material-symbols-outlined text-[18px] text-primary shrink-0 mt-0.5">campaign</span>
                <span className="leading-relaxed">
                  {t('broadcast.schedule.defaultNotifyNote', 'Mặc định khi bảo trì (Định kỳ hay khẩn cấp), hệ thống đều sẽ tự động phát thông báo tới Client-app người dùng và Quản trị viên.')}
                </span>
              </div>

              {/* PO QUY ĐỊNH: NÚT CHECKBOX "BẢO TRÌ KHẨN CẤP" */}
              {/* Nút bị chặn khi khẩn cấp đã kích hoạt. KHÔNG bị chặn khi bảo trì định kỳ */}
              <div className="flex items-center justify-between p-3.5 rounded-xl border border-outline-variant bg-surface-container-lowest">
                <label htmlFor="checkbox-emergency-schedule" className="flex items-start sm:items-center gap-2.5 cursor-pointer select-none">
                  <input
                    id="checkbox-emergency-schedule"
                    type="checkbox"
                    checked={isEmergencySchedule}
                    disabled={isEmergencyBlocked}
                    onChange={(e) => setIsEmergencySchedule(e.target.checked)}
                    className="w-4 h-4 mt-0.5 sm:mt-0 rounded text-rose-600 focus:ring-rose-500 border-outline-variant cursor-pointer disabled:cursor-not-allowed disabled:opacity-50"
                  />
                  <div>
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[16px] text-rose-600">crisis_alert</span>
                      {t('broadcast.schedule.emergencyCheckbox', 'Bảo trì khẩn cấp')}
                    </span>
                    {isEmergencyBlocked ? (
                      <span className="text-[11px] text-rose-600 block mt-0.5 font-medium">
                        {t('broadcast.schedule.emergencyBlockedHint', 'Hệ thống đang trong chế độ bảo trì khẩn cấp')}
                      </span>
                    ) : (
                      <span className="text-[11px] text-on-surface-variant block mt-0.5">
                        {isEmergencySchedule
                          ? t('broadcast.schedule.emergencyImmediateNotice', 'Chế độ bảo trì khẩn cấp sẽ có hiệu lực ngay lập tức sau khi xác nhận.')
                          : t('broadcast.schedule.policyDesc', 'Bảo trì khẩn cấp sẽ đè trực tiếp lên bảo trì định kỳ nếu có xung đột.')}
                      </span>
                    )}
                  </div>
                </label>
              </div>

              {/* Khi KHÔNG tick bảo trì khẩn cấp -> Hiện các trường chọn thời gian */}
              {!isEmergencySchedule ? (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label htmlFor="schedule-start-at" className="block text-xs font-bold text-on-surface uppercase tracking-wider mb-1.5">
                      {t('broadcast.scheduleStartLabel', 'Thời điểm bắt đầu')} <span className="text-red-500">*</span>
                    </label>
                    <input
                      id="schedule-start-at"
                      type="datetime-local"
                      min={toLocalInputString(Date.now() + 4 * 3600 * 1000)}
                      value={scheduleDatetime}
                      onChange={(e) => setScheduleDatetime(e.target.value)}
                      required={!isEmergencySchedule}
                      className="w-full border border-outline-variant rounded-lg px-3 py-2 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                    />
                    <span className="text-[10px] text-gray-500 mt-1 block">Tối thiểu trước 4 tiếng kể từ hiện tại</span>
                  </div>

                  <div>
                    <label htmlFor="schedule-end-at" className="block text-xs font-bold text-on-surface uppercase tracking-wider mb-1.5">
                      {t('broadcast.scheduleEndLabel', 'Thời điểm kết thúc dự kiến')}
                    </label>
                    <input
                      id="schedule-end-at"
                      type="datetime-local"
                      min={scheduleDatetime || toLocalInputString(Date.now() + 4 * 3600 * 1000)}
                      value={scheduleEndDatetime}
                      onChange={(e) => setScheduleEndDatetime(e.target.value)}
                      className="w-full border border-outline-variant rounded-lg px-3 py-2 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                    />
                  </div>
                </div>
              ) : (
                <div className="p-3.5 bg-rose-50 border border-rose-200 rounded-xl text-rose-950 text-xs flex items-center gap-2.5">
                  <span className="material-symbols-outlined text-[20px] text-rose-600 shrink-0">bolt</span>
                  <span>Chế độ bảo trì khẩn cấp sẽ kích hoạt tức thời, cắt tải toàn bộ traffic và hủy các đợt bảo trì định kỳ bị dính khung thời gian.</span>
                </div>
              )}

              <div>
                <label htmlFor="schedule-reason" className="block text-xs font-bold text-on-surface uppercase tracking-wider mb-1.5">
                  {t('broadcast.scheduleReasonLabel', 'Lý do / Nội dung bảo trì')}
                </label>
                <input
                  id="schedule-reason"
                  type="text"
                  value={scheduleReason}
                  onChange={(e) => setScheduleReason(e.target.value)}
                  placeholder={
                    isEmergencySchedule
                      ? 'Nhập lý do bảo trì khẩn cấp gửi tới người dùng...'
                      : t('broadcast.scheduleReasonPlaceholder', 'Ví dụ: Nâng cấp cụm máy chủ và tối ưu hóa hệ thống định kỳ...')
                  }
                  className="w-full border border-outline-variant rounded-lg px-3.5 py-2.5 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                />
              </div>

              {/* Hàng nút bấm */}
              <div className="flex items-center gap-2.5 pt-1">
                {isEmergencySchedule ? (
                  <button
                    type="submit"
                    id="btn-submit-emergency-maintenance"
                    disabled={actionLoading || isEmergencyBlocked}
                    className="flex-1 py-2.5 px-4 rounded-xl text-xs font-bold text-white bg-rose-600 hover:bg-rose-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-all cursor-pointer flex items-center justify-center gap-2 shadow-sm"
                  >
                    <span className="material-symbols-outlined text-[18px]">crisis_alert</span>
                    <span>{actionLoading ? t('common.processing', 'Đang xử lý...') : t('broadcast.schedule.emergencySubmitBtn', 'Kích hoạt bảo trì khẩn cấp')}</span>
                  </button>
                ) : (
                  <button
                    type="submit"
                    id="btn-submit-schedule-maintenance"
                    disabled={actionLoading || !scheduleDatetime}
                    className="flex-1 py-2.5 px-4 rounded-xl text-xs font-bold text-white bg-primary hover:bg-primary/90 disabled:bg-gray-300 disabled:cursor-not-allowed transition-all cursor-pointer flex items-center justify-center gap-2 shadow-sm"
                  >
                    <span className="material-symbols-outlined text-[18px]">alarm_on</span>
                    <span>{actionLoading ? t('common.saving', 'Đang lưu...') : t('broadcast.scheduleSubmitBtn', 'Lên lịch bảo trì')}</span>
                  </button>
                )}

                <button
                  type="button"
                  onClick={handleResetScheduleFormAndRefresh}
                  disabled={isRefreshing}
                  className="py-2.5 px-4 rounded-xl text-xs font-semibold text-on-surface bg-surface-container-low hover:bg-surface-container border border-outline-variant transition-all cursor-pointer flex items-center justify-center gap-1.5 disabled:opacity-50"
                  title={t('broadcast.schedule.resetTooltip', 'Làm mới')}
                >
                  <span className={`material-symbols-outlined text-[18px] ${isRefreshing ? 'animate-spin' : ''}`}>
                    refresh
                  </span>
                  <span>{isRefreshing ? t('broadcast.schedule.refreshing', 'Đang làm mới...') : t('broadcast.schedule.resetBtn', 'Làm mới')}</span>
                </button>
              </div>
            </form>

            {/* BẢNG CÁC LỊCH BẢO TRÌ ĐÃ ĐẶT (UPCOMING SCHEDULES TABLE) */}
            {(() => {
              const list = Array.isArray(maintenance.scheduledList) && maintenance.scheduledList.length > 0
                ? maintenance.scheduledList
                : (maintenance.scheduled ? [maintenance.scheduled] : []);

              if (!list || list.length === 0) return null;

              return (
                <div className="pt-4 border-t border-outline-variant space-y-3">
                  <div className="flex items-center justify-between">
                    <h4 className="font-bold text-xs text-on-surface uppercase tracking-wider flex items-center gap-1.5 m-0">
                      <span className="material-symbols-outlined text-blue-600 text-[18px]">event_upcoming</span>
                      <span>Danh Sách Lịch Bảo Trì Đã Lên Lịch ({list.length})</span>
                    </h4>
                  </div>

                  <div className="overflow-x-auto border border-blue-200 rounded-xl bg-blue-50/30">
                    <table className="w-full text-left text-xs">
                      <thead>
                        <tr className="border-b border-blue-200 bg-blue-100/60 text-blue-950 font-bold">
                          <th className="py-2.5 px-3">#</th>
                          <th className="py-2.5 px-3">Bắt đầu</th>
                          <th className="py-2.5 px-3">Kết thúc dự kiến</th>
                          <th className="py-2.5 px-3">Thời lượng</th>
                          <th className="py-2.5 px-3">Lý do</th>
                          <th className="py-2.5 px-3">Người lên lịch</th>
                          <th className="py-2.5 px-3 text-center">Thao tác</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-blue-200/50">
                        {list.map((sched, idx) => (
                          <tr key={sched.id || sched.recordId || idx} className="hover:bg-blue-100/40">
                            <td className="py-2.5 px-3 font-semibold text-blue-900">{idx + 1}</td>
                            <td className="py-2.5 px-3 font-bold text-blue-700">{formatDateTime(sched.scheduledAt)}</td>
                            <td className="py-2.5 px-3 text-blue-950">{sched.scheduledEndAt ? formatDateTime(sched.scheduledEndAt) : '—'}</td>
                            <td className="py-2.5 px-3">{sched.scheduledEndAt ? formatDuration(sched.scheduledAt, sched.scheduledEndAt) : '—'}</td>
                            <td className="py-2.5 px-3 max-w-[220px] truncate" title={sched.reason}>{sched.reason || 'Bảo trì định kỳ'}</td>
                            <td className="py-2.5 px-3 text-gray-600">{sched.createdBy || 'admin'}</td>
                            <td className="py-2.5 px-3 text-center">
                              <button
                                onClick={() => handleCancelSchedule(sched.id || sched.recordId)}
                                disabled={actionLoading}
                                className="px-2.5 py-1 bg-white hover:bg-red-50 text-red-600 border border-red-200 rounded-lg text-[11px] font-semibold transition-colors cursor-pointer inline-flex items-center gap-1 shadow-2xs"
                              >
                                <span className="material-symbols-outlined text-[14px]">delete</span>
                                <span>Hủy</span>
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              );
            })()}
          </div>

          {/* 1.3 BẢNG LỊCH SỬ BẢO TRÌ HỆ THỐNG (POSTGRESQL PERSISTENCE) */}
          <div className="bg-white rounded-2xl border border-outline-variant shadow-sm p-5 space-y-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-outline-variant pb-3">
              <div>
                <h3 className="font-bold text-sm text-on-surface flex items-center gap-2 m-0">
                  <span className="material-symbols-outlined text-primary text-[20px]">history</span>
                  <span>{t('broadcast.history.title', 'Lịch Sử Các Phiên Bảo Trì Hệ Thống')}</span>
                </h3>
              </div>

              {/* Bộ lọc Type & Status & Nút Làm Mới */}
              <div className="flex items-center gap-2 flex-wrap">
                <select
                  value={historyFilterType}
                  onChange={(e) => {
                    setHistoryFilterType(e.target.value);
                    setHistoryPage(1);
                  }}
                  className="text-xs border border-outline-variant rounded-lg pl-2.5 pr-8 py-1.5 bg-surface text-on-surface focus:outline-none focus:ring-1 focus:ring-primary cursor-pointer"
                >
                  <option value="ALL">{t('broadcast.history.filterAllType', 'Tất cả loại')}</option>
                  <option value="EMERGENCY">{t('broadcast.history.typeEmergency', 'Khẩn cấp')}</option>
                  <option value="SCHEDULED">{t('broadcast.history.typeScheduled', 'Định kỳ')}</option>
                </select>

                <select
                  value={historyFilterStatus}
                  onChange={(e) => {
                    setHistoryFilterStatus(e.target.value);
                    setHistoryPage(1);
                  }}
                  className="text-xs border border-outline-variant rounded-lg pl-2.5 pr-8 py-1.5 bg-surface text-on-surface focus:outline-none focus:ring-1 focus:ring-primary cursor-pointer"
                >
                  <option value="ALL">{t('broadcast.history.filterAllStatus', 'Tất cả trạng thái')}</option>
                  <option value="ONGOING">{t('broadcast.history.statusOngoing', 'Đang diễn ra')}</option>
                  <option value="SCHEDULED">{t('broadcast.history.statusScheduled', 'Đã lên lịch')}</option>
                  <option value="COMPLETED">{t('broadcast.history.statusCompleted', 'Đã hoàn thành')}</option>
                  <option value="CANCELLED">{t('broadcast.history.statusCancelled', 'Đã hủy')}</option>
                </select>
              </div>
            </div>

            {/* Bảng Dữ Liệu */}
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs border-collapse min-w-[850px]">
                <thead>
                  <tr className="border-b border-outline-variant text-[11px] text-on-surface-variant uppercase tracking-wider bg-surface-container-lowest font-semibold">
                    <th className="w-14 py-2.5 px-3">
                      #
                    </th>
                    <th className="w-[13%] min-w-[100px] py-2.5 px-3">
                      {t('broadcast.history.colType', 'Loại')}
                    </th>
                    <th className="w-[17%] min-w-[130px] py-2.5 px-3">
                      {t('broadcast.history.colUser', 'Người kích hoạt')}
                    </th>
                    <th className="w-[26%] min-w-[180px] py-2.5 px-3">
                      {t('broadcast.history.colReason', 'Lý do / Thông điệp')}
                    </th>
                    <th className="w-[15%] min-w-[110px] py-2.5 px-3">
                      {t('broadcast.history.colStart', 'Bắt đầu')}
                    </th>
                    <th className="w-[15%] min-w-[110px] py-2.5 px-3">
                      {t('broadcast.history.colEnd', 'Kết thúc')}
                    </th>
                    <th className="w-[14%] min-w-[100px] py-2.5 px-3">
                      {t('broadcast.history.colDuration', 'Thời lượng')}
                    </th>
                    <th className="w-24 min-w-[90px] py-2.5 px-3 text-right">
                      {t('broadcast.history.colStatus', 'Trạng thái')}
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-outline-variant/50">
                  {loadingHistory && historyData.length === 0 ? (
                    <tr>
                      <td colSpan="8" className="py-8 text-center text-on-surface-variant">
                        <div className="flex items-center justify-center gap-2">
                          <span className="material-symbols-outlined animate-spin text-[18px]">progress_activity</span>
                          <span>{t('common.loading', 'Đang tải dữ liệu...')}</span>
                        </div>
                      </td>
                    </tr>
                  ) : historyData.length === 0 ? (
                    <tr>
                      <td colSpan="8" className="py-8 text-center text-on-surface-variant">
                        <div className="flex flex-col items-center justify-center gap-1">
                          <span className="material-symbols-outlined text-[28px] text-gray-400">event_busy</span>
                          <span className="text-xs">{t('broadcast.history.emptyText', 'Chưa có phiên bảo trì nào được ghi nhận trong CSDL.')}</span>
                        </div>
                      </td>
                    </tr>
                  ) : (
                    historyData.map((row, idx) => {
                      const isEmergency = row.type === 'EMERGENCY';
                      const isOngoing = row.status === 'ONGOING';
                      const isScheduled = row.status === 'SCHEDULED';
                      const isCompleted = row.status === 'COMPLETED';

                      return (
                        <tr key={row.id || idx} className="hover:bg-surface-container-lowest/60 transition-colors">
                          <td className="py-3 px-3 font-mono text-[11px] text-gray-400">
                            {row.id || idx + 1}
                          </td>
                          <td className="py-3 px-3 whitespace-nowrap">
                            <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-bold border ${
                              isEmergency
                                ? 'bg-red-50 text-red-700 border-red-200'
                                : 'bg-blue-50 text-blue-700 border-blue-200'
                            }`}>
                              <span className="material-symbols-outlined text-[13px]">
                                {isEmergency ? 'warning' : 'event'}
                              </span>
                              <span>{isEmergency ? t('broadcast.history.typeEmergency', 'Khẩn cấp') : t('broadcast.history.typeScheduled', 'Định kỳ')}</span>
                            </span>
                          </td>
                          <td className="py-3 px-3 font-medium text-on-surface overflow-hidden">
                            <span className="inline-flex items-center gap-1.5 font-semibold text-slate-800 min-w-0 max-w-full">
                              <span className="material-symbols-outlined text-[15px] text-slate-500 shrink-0">account_circle</span>
                              <TruncateCell text={row.activated_by || 'system'} className="min-w-0" />
                            </span>
                          </td>
                          <td className="py-3 px-3 overflow-hidden">
                            <TruncateCell text={row.reason} className="text-on-surface" />
                          </td>
                          <td className="py-3 px-3 whitespace-nowrap text-on-surface-variant text-[11px]">
                            {row.started_at ? formatDateTime(row.started_at) : '—'}
                          </td>
                          <td className="py-3 px-3 whitespace-nowrap text-on-surface-variant text-[11px]">
                            {row.ended_at
                              ? formatDateTime(row.ended_at)
                              : row.scheduled_end_at
                              ? `${formatDateTime(row.scheduled_end_at)} (Dự kiến)`
                              : '—'}
                          </td>
                          <td className="py-3 px-3 whitespace-nowrap text-on-surface font-mono text-[11px]">
                            {formatDuration(row.started_at, row.ended_at)}
                          </td>
                          <td className="py-3 px-3 text-right whitespace-nowrap">
                            <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-bold border ${
                              isOngoing
                                ? 'bg-amber-50 text-amber-800 border-amber-300 animate-pulse'
                                : isScheduled
                                ? 'bg-blue-50 text-blue-800 border-blue-300'
                                : isCompleted
                                ? 'bg-emerald-50 text-emerald-800 border-emerald-300'
                                : 'bg-gray-100 text-gray-700 border-gray-300'
                            }`}>
                              <span className="material-symbols-outlined text-[13px]">
                                {isOngoing ? 'sync' : isScheduled ? 'calendar_clock' : isCompleted ? 'check_circle' : 'cancel'}
                              </span>
                              <span>
                                {isOngoing
                                  ? t('broadcast.history.statusOngoing', 'Đang diễn ra')
                                  : isScheduled
                                  ? t('broadcast.history.statusScheduled', 'Đã lên lịch')
                                  : isCompleted
                                  ? t('broadcast.history.statusCompleted', 'Đã hoàn thành')
                                  : t('broadcast.history.statusCancelled', 'Đã hủy')}
                              </span>
                            </span>
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>

            {/* Phân trang Chuẩn */}
            <Pagination
              currentPage={historyPage}
              pageSize={historyLimit}
              total={historyTotal}
              pageSizeOptions={[5, 10, 20, 50]}
              onPageChange={(p) => {
                setHistoryPage(p);
                fetchHistory(p, historyLimit);
              }}
              onPageSizeChange={(s) => {
                setHistoryLimit(s);
                setHistoryPage(1);
                fetchHistory(1, s);
              }}
              itemLabel={t('broadcast.history.itemLabel', 'phiên bảo trì')}
            />
          </div>
        </div>
      )}

      {/* ======================================================== */}
      {/* TAB 2: PHÁT THÔNG BÁO HỆ THỐNG (SYSTEM BROADCAST) */}
      {/* ======================================================== */}
      {activeTab === 'broadcast' && (
        <div className="max-w-5xl mx-auto space-y-6">
          <form onSubmit={handleSendBroadcast} className="bg-white rounded-2xl border border-outline-variant shadow-sm p-6 space-y-5">
            <div>
              <label className="block text-xs font-bold text-on-surface uppercase tracking-wider mb-2">
                {t('broadcast.broadcastLevelLabel')}
              </label>
              <div className="grid grid-cols-3 gap-3">
                {BROADCAST_LEVELS.map((l) => (
                  <button
                    key={l.value}
                    type="button"
                    onClick={() => setLevel(l.value)}
                    className={`flex items-center justify-center gap-2 p-3 rounded-lg border-2 transition-all cursor-pointer font-medium text-xs ${
                      level === l.value
                        ? 'border-primary bg-primary/5 text-primary shadow-xs font-bold'
                        : 'border-outline-variant hover:border-gray-300 text-on-surface-variant'
                    }`}
                  >
                    <span className={`material-symbols-outlined text-[18px] ${l.color}`}>{l.icon}</span>
                    <span>{l.value.toUpperCase()}</span>
                  </button>
                ))}
              </div>
              <p className="text-xs text-on-surface-variant mt-1.5">{t('broadcast.levels.' + level)}</p>
            </div>

            <div>
              <label htmlFor="broadcast-title" className="block text-xs font-bold text-on-surface uppercase tracking-wider mb-1.5">
                {t('broadcast.broadcastTitleLabel')} <span className="text-red-500">*</span>
              </label>
              <input
                id="broadcast-title"
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                maxLength={120}
                placeholder={t('broadcast.broadcastTitlePlaceholder')}
                className="w-full border border-outline-variant rounded-lg px-3.5 py-2.5 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                required
              />
              <p className="text-[11px] text-on-surface-variant text-right mt-1">
                {t('broadcast.charCount', { current: title.length, max: 120 })}
              </p>
            </div>

            <div>
              <label htmlFor="broadcast-message" className="block text-xs font-bold text-on-surface uppercase tracking-wider mb-1.5">
                {t('broadcast.broadcastMsgLabel')} <span className="text-red-500">*</span>
              </label>
              <textarea
                id="broadcast-message"
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                rows={4}
                maxLength={500}
                placeholder={t('broadcast.broadcastMsgPlaceholder')}
                className="w-full border border-outline-variant rounded-lg px-3.5 py-2.5 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary resize-none"
                required
              />
              <p className="text-[11px] text-on-surface-variant text-right mt-1">
                {t('broadcast.charCount', { current: message.length, max: 500 })}
              </p>
            </div>

            {/* Live Preview Box */}
            {(title || message) && (
              <div
                className={`rounded-lg border p-4 transition-colors ${
                  level === 'critical'
                    ? 'border-red-300 bg-red-50 text-red-900'
                    : level === 'warning'
                    ? 'border-amber-300 bg-amber-50 text-amber-900'
                    : 'border-blue-300 bg-blue-50 text-blue-900'
                }`}
              >
                <div className="flex items-center gap-1.5 text-[11px] font-bold uppercase tracking-wider mb-1.5 opacity-75">
                  <span className="material-symbols-outlined text-[15px]">{selectedBroadcastLevel?.icon}</span>
                  {t('broadcast.previewTitle')}
                </div>
                <p className="font-bold text-sm mb-1">{title || t('broadcast.previewDefaultTitle')}</p>
                <p className="text-xs whitespace-pre-wrap opacity-90">{message || t('broadcast.previewDefaultMsg')}</p>
              </div>
            )}

            {broadcastResult && (
              <div
                className={`rounded-lg px-4 py-3 text-xs flex items-center gap-2 border font-medium ${
                  broadcastResult.ok
                    ? 'bg-emerald-50 text-emerald-800 border-emerald-300'
                    : 'bg-red-50 text-red-800 border-red-300'
                }`}
              >
                <span className="material-symbols-outlined text-[18px]">
                  {broadcastResult.ok ? 'check_circle' : 'cancel'}
                </span>
                <span>{broadcastResult.msg}</span>
              </div>
            )}

            <button
              id="btn-send-broadcast"
              type="submit"
              disabled={sending || !title.trim() || !message.trim()}
              className="w-full bg-primary hover:bg-primary/90 disabled:bg-gray-300 disabled:cursor-not-allowed text-white font-semibold py-2.5 rounded-lg transition-colors cursor-pointer flex items-center justify-center gap-2 text-xs shadow-sm"
            >
              {sending ? (
                <>
                  <span className="material-symbols-outlined animate-spin text-[16px]">progress_activity</span>
                  {t('broadcast.sendingBroadcast')}
                </>
              ) : (
                <>
                  <span className="material-symbols-outlined text-[16px]">send</span>
                  {t('broadcast.broadcastSubmitBtn')}
                </>
              )}
            </button>
          </form>

          {/* 2.2 BẢNG HIỂN THỊ DANH SÁCH THÔNG BÁO VÀ NGƯỜI GỬI (POSTGRESQL PERSISTENCE - PHÂN TRANG 5/PAGE) */}
          <div className="bg-white rounded-2xl border border-outline-variant shadow-sm p-5 space-y-4">
            <div className="border-b border-outline-variant pb-3">
              <h3 className="font-bold text-sm text-on-surface flex items-center gap-2 m-0">
                <span className="material-symbols-outlined text-primary text-[20px]">mark_email_read</span>
                <span>{t('broadcast.historyBroadcast.title', 'Lịch Sử Các Thông Báo Đã Phát Sóng')}</span>
              </h3>
              <p className="text-[11px] text-on-surface-variant mt-0.5 m-0">
                {t('broadcast.historyBroadcast.subtitle', 'Lưu vết Audit Trail vĩnh viễn trong CSDL PostgreSQL, theo dõi người phát sóng, mức độ và nội dung')}
              </p>
            </div>

            {/* Bảng Dữ Liệu */}
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs border-collapse min-w-[700px]">
                <thead>
                  <tr className="border-b border-outline-variant text-[11px] text-on-surface-variant uppercase tracking-wider bg-surface-container-lowest font-semibold">
                    <th className="w-12 py-2.5 px-3">#</th>
                    <th className="w-28 py-2.5 px-3">{t('broadcast.historyBroadcast.colLevel', 'Mức độ')}</th>
                    <th className="w-1/4 min-w-[150px] py-2.5 px-3">{t('broadcast.historyBroadcast.colTitle', 'Tiêu đề')}</th>
                    <th className="w-2/5 min-w-[200px] py-2.5 px-3">{t('broadcast.historyBroadcast.colMessage', 'Nội dung thông báo')}</th>
                    <th className="w-28 py-2.5 px-3">{t('broadcast.historyBroadcast.colSender', 'Người gửi')}</th>
                    <th className="w-36 py-2.5 px-3 text-right">{t('broadcast.historyBroadcast.colTime', 'Thời điểm phát sóng')}</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-outline-variant/50">
                  {loadingBroadcastHistory && broadcastHistory.length === 0 ? (
                    <tr>
                      <td colSpan="6" className="py-8 text-center text-on-surface-variant">
                        <div className="flex items-center justify-center gap-2">
                          <span className="material-symbols-outlined animate-spin text-[18px]">progress_activity</span>
                          <span>{t('common.loading', 'Đang tải dữ liệu...')}</span>
                        </div>
                      </td>
                    </tr>
                  ) : broadcastHistory.length === 0 ? (
                    <tr>
                      <td colSpan="6" className="py-8 text-center text-on-surface-variant">
                        <div className="flex flex-col items-center justify-center gap-1">
                          <span className="material-symbols-outlined text-[28px] text-gray-400">chat_bubble_outline</span>
                          <span className="text-xs">{t('broadcast.historyBroadcast.emptyText', 'Chưa có thông báo nào được phát sóng.')}</span>
                        </div>
                      </td>
                    </tr>
                  ) : (
                    broadcastHistory.map((row, idx) => {
                      const lvl = (row.level || 'INFO').toUpperCase();
                      const isCritical = lvl === 'CRITICAL';
                      const isWarning = lvl === 'WARNING';
                      return (
                        <tr key={row.id || idx} className="hover:bg-surface-container-lowest transition-colors">
                          <td className="py-3 px-3 font-mono text-[11px] text-on-surface-variant">{row.id || (idx + 1)}</td>
                          <td className="py-3 px-3 whitespace-nowrap">
                            <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold border ${
                              isCritical
                                ? 'bg-rose-50 text-rose-700 border-rose-300'
                                : isWarning
                                ? 'bg-amber-50 text-amber-700 border-amber-300'
                                : 'bg-blue-50 text-blue-700 border-blue-300'
                            }`}>
                              <span className="material-symbols-outlined text-[12px]">
                                {isCritical ? 'error' : isWarning ? 'warning' : 'info'}
                              </span>
                              <span>{lvl}</span>
                            </span>
                          </td>
                          <td className="py-3 px-3 font-semibold text-on-surface max-w-[180px]">
                            <TruncateCell text={row.title} className="font-semibold text-on-surface" />
                          </td>
                          <td className="py-3 px-3 text-on-surface-variant max-w-[280px]">
                            <TruncateCell text={row.message} className="text-on-surface-variant" />
                          </td>
                          <td className="py-3 px-3 whitespace-nowrap">
                            <span className="inline-flex items-center gap-1 text-[11px] font-medium bg-surface-container-low px-2 py-0.5 rounded-md border border-outline-variant/60 text-on-surface">
                              <span className="material-symbols-outlined text-[13px] text-primary">account_circle</span>
                              <span>{row.sender_username || 'admin'}</span>
                            </span>
                          </td>
                          <td className="py-3 px-3 text-right whitespace-nowrap text-on-surface-variant text-[11px]">
                            {row.created_at ? formatDateTime(row.created_at) : '—'}
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>

            {/* Phân trang Chuẩn (Mặc định 5/page) */}
            <Pagination
              currentPage={broadcastPage}
              pageSize={broadcastLimit}
              total={broadcastTotal}
              pageSizeOptions={[5, 10, 20]}
              onPageChange={(p) => {
                setBroadcastPage(p);
                fetchBroadcastHistory(p, broadcastLimit);
              }}
              onPageSizeChange={(s) => {
                setBroadcastLimit(s);
                setBroadcastPage(1);
                fetchBroadcastHistory(1, s);
              }}
              itemLabel={t('broadcast.historyBroadcast.itemLabel', 'thông báo')}
            />
          </div>
        </div>
      )}

      {/* POPUP MODAL XÁC THỰC MÃ PIN / MẬT KHẨU BẢO TRÌ KHẨN CẤP */}
      <SecurityConfirmModal
        isOpen={showEmergencyConfirmModal}
        onClose={() => setShowEmergencyConfirmModal(false)}
        title="Xác nhận BẢO TRÌ KHẨN CẤP"
        confirmText="Xác thực & Thực thi"
        requirePin={false}
        actionType="EMERGENCY_MAINTENANCE"
        actionDescription={
          scheduleReason
            ? `Kích hoạt chế độ BẢO TRÌ KHẨN CẤP toàn hệ thống (Lý do: ${scheduleReason})`
            : 'Kích hoạt chế độ BẢO TRÌ KHẨN CẤP toàn hệ thống. Mọi người dùng sẽ bị chặn truy cập và nhận thông báo khẩn.'
        }
        onSuccess={async () => {
          setShowEmergencyConfirmModal(false);
          await handleConfirmEmergencyMaintenance();
        }}
      />

      {/* POPUP MODAL XÁC NHẬN KẾT THÚC BẢO TRÌ */}
      {showStopMaintenanceConfirmModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 space-y-4 shadow-xl border border-outline-variant animate-fade-in">
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-xl bg-amber-100 text-amber-700 flex items-center justify-center flex-shrink-0">
                <span className="material-symbols-outlined text-[24px]">power_settings_new</span>
              </div>
              <div className="space-y-1">
                <h3 className="font-bold text-base text-on-surface m-0">
                  {t('broadcast.stopConfirm.title', 'Xác Nhận Kết Thúc Bảo Trì')}
                </h3>
                <p className="text-xs text-on-surface-variant leading-relaxed">
                  {t('broadcast.stopConfirm.desc', 'Bạn có chắc chắn muốn kết thúc phiên bảo trì này và khôi phục hoạt động bình thường cho toàn bộ người dùng?')}
                </p>
              </div>
            </div>

            <div className="flex items-center justify-end gap-2.5 pt-2 border-t border-outline-variant">
              <button
                type="button"
                onClick={() => setShowStopMaintenanceConfirmModal(false)}
                disabled={actionLoading}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-on-surface bg-surface-container-low hover:bg-surface-container border border-outline-variant transition-colors cursor-pointer"
              >
                {t('broadcast.stopConfirm.cancelBtn', 'Hủy Bỏ')}
              </button>
              <button
                type="button"
                id="btn-confirm-stop-maintenance"
                onClick={async () => {
                  setShowStopMaintenanceConfirmModal(false);
                  await handleToggleMaintenance(false);
                }}
                disabled={actionLoading}
                className="px-4 py-2 rounded-xl text-xs font-bold text-white bg-primary hover:bg-primary/90 transition-colors cursor-pointer flex items-center gap-1.5 shadow-sm"
              >
                <span className="material-symbols-outlined text-[16px]">check_circle</span>
                <span>{actionLoading ? t('common.processing') : t('broadcast.stopConfirm.confirmBtn', 'Xác Nhận Kết Thúc')}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default BroadcastPage;
