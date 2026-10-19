import React, { useState, useEffect, useCallback, useRef } from 'react';
import adminApi from '../../api/admin.api';
import notificationApi from '../../api/notification.api';
import useSocket from '../../hooks/useSocket';
import { formatDateTime } from '../../utils/format';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import Pagination from '../../components/common/Pagination';
import SecurityConfirmModal from '../../components/common/SecurityConfirmModal';
import useResizableColumns from '../../hooks/useResizableColumns';
import ResizableTh from '../../components/common/ResizableTh';
import TruncateCell from '../../components/common/TruncateCell';

const DEFAULT_BROADCAST_COL_WIDTHS = {
  id: 60,
  type: 110,
  user: 160,
  reason: 240,
  start: 140,
  end: 140,
  duration: 110,
  status: 120,
};

const BROADCAST_LEVELS = [
  { value: 'info', color: 'text-blue-500', icon: 'info' },
  { value: 'warning', color: 'text-amber-500', icon: 'warning' },
  { value: 'critical', color: 'text-red-500', icon: 'error' },
];

const BroadcastPage = () => {
  const alert = useAlertSafe();
  const socket = useSocket();
  const { t } = useLanguageSafe();
  const [activeTab, setActiveTab] = useState('maintenance'); // 'maintenance' | 'broadcast'

  const { widths: colWidths, startResizing, resetColumn } = useResizableColumns({
    tableKey: 'broadcast_history',
    defaultWidths: DEFAULT_BROADCAST_COL_WIDTHS,
    minWidth: 50,
  });

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
  const [showEmergencyConfirmModal, setShowEmergencyConfirmModal] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);

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
  }, [fetchHistory]);

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

  // Xử lý Lên lịch bảo trì
  const handleSaveSchedule = async (e) => {
    e.preventDefault();
    if (maintenance.active) {
      setMaintenanceFeedback({
        ok: false,
        msg: t('broadcast.feedback.scheduleOngoingConflict'),
      });
      return;
    }
    if (!scheduleDatetime) return;

    if (scheduleEndDatetime) {
      if (new Date(scheduleEndDatetime).getTime() <= new Date(scheduleDatetime).getTime()) {
        setMaintenanceFeedback({
          ok: false,
          msg: t('broadcast.feedback.scheduleEndBeforeStart'),
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
        reason: scheduleReason.trim() || t('broadcast.scheduleCardDesc'),
        isEmergency: Boolean(scheduleNotify),
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
    } catch (err) {
      setMaintenanceFeedback({
        ok: false,
        msg: err.response?.data?.message || t('broadcast.feedback.scheduleFailed'),
      });
    } finally {
      setActionLoading(false);
    }
  };

  // Xử lý Hủy lịch bảo trì đã hẹn
  const handleCancelSchedule = async () => {
    if (!window.confirm(t('broadcast.schedule.cancelConfirm'))) return;
    setActionLoading(true);
    setMaintenanceFeedback(null);
    isActionInitiatorRef.current = true;
    try {
      const res = await adminApi.cancelScheduledMaintenance();
      const data = res?.data || res;
      setMaintenance(data);
      setMaintenanceFeedback({
        ok: true,
        msg: t('broadcast.feedback.cancelSuccess'),
      });
    } catch (err) {
      setMaintenanceFeedback({
        ok: false,
        msg: err.response?.data?.message || t('broadcast.feedback.cancelFailed'),
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
    <div className="max-w-[1440px] mx-auto w-full p-4 md:p-6 space-y-6 bg-surface-bright min-h-full">
      {/* Tiêu đề trang & Thanh chuyển Tab */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-outline-variant pb-4">
        <div>
          <h1 className="font-display-md text-display-md font-bold text-on-surface m-0 tracking-tight flex items-center gap-2">
            <span className="material-symbols-outlined text-primary text-[30px]">construction</span>
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
            onClick={() => setActiveTab('broadcast')}
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

      {/* ======================================================== */}
      {/* TAB 1: ĐIỀU HÀNH BẢO TRÌ HỆ THỐNG */}
      {/* ======================================================== */}
      {activeTab === 'maintenance' && (
        <div className="space-y-6">
          {/* 1.1 BANNER TRẠNG THÁI BẢO TRÌ (CHỈ HIỂN THỊ KHI ĐANG BẢO TRÌ) */}
          {maintenance.active && (
            <div
              className={`rounded-2xl border p-5 transition-all shadow-xs ${
                maintenance.isEmergency
                  ? 'border-red-300 bg-red-50/90 text-red-950'
                  : 'border-orange-300 bg-orange-50/90 text-orange-950'
              }`}
            >
              <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div className="flex items-start gap-3.5">
                  <div
                    className={`w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0 shadow-xs ${
                      maintenance.isEmergency
                        ? 'bg-red-600 text-white animate-pulse'
                        : 'bg-orange-500 text-white'
                    }`}
                  >
                    <span className="material-symbols-outlined text-[26px]">
                      {maintenance.isEmergency ? 'error' : 'construction'}
                    </span>
                  </div>
                  <div>
                    <div className="flex items-center gap-2 flex-wrap">
                      <h2 className="text-base font-bold m-0">
                        {maintenance.isEmergency
                          ? t('broadcast.banner.emergencyTitle')
                          : t('broadcast.banner.silentTitle')}
                      </h2>
                      <span
                        className={`px-2.5 py-0.5 rounded-full text-[11px] font-bold tracking-wide uppercase ${
                          maintenance.isEmergency
                            ? 'bg-red-200 text-red-800'
                            : 'bg-orange-200 text-orange-800'
                        }`}
                      >
                        {maintenance.isEmergency ? t('broadcast.banner.emergencyBadge') : t('broadcast.banner.silentBadge')}
                      </span>
                    </div>
                    <p className="text-xs opacity-90 mt-1">
                      {maintenance.isEmergency
                        ? t('broadcast.banner.emergencyDesc')
                        : t('broadcast.banner.silentDesc')}
                    </p>
                    <div className="mt-2 text-xs flex flex-wrap gap-x-4 gap-y-1 font-medium">
                      <span>• {t('broadcast.banner.reasonLabel')} <b>{maintenance.reason || t('broadcast.banner.noReason')}</b></span>
                      {maintenance.activatedBy && <span>• {t('broadcast.banner.activatedByLabel')} <b>{maintenance.activatedBy}</b></span>}
                      {maintenance.activatedAt && (
                        <span>• {t('broadcast.banner.activatedAtLabel')} <b>{formatDateTime(maintenance.activatedAt)}</b></span>
                      )}
                    </div>
                  </div>
                </div>

                {/* Quick toggle if currently active */}
                <button
                  onClick={() => handleToggleMaintenance(false)}
                  disabled={actionLoading}
                  className="px-5 py-2.5 bg-white hover:bg-gray-50 border border-gray-300 text-on-surface text-xs font-bold rounded-xl shadow-xs transition-all cursor-pointer flex items-center justify-center gap-2 self-start md:self-center flex-shrink-0"
                >
                  <span className="material-symbols-outlined text-[18px] text-emerald-600">power_settings_new</span>
                  <span>{t('broadcast.turnOffBtn', 'Tắt Bảo Trì')}</span>
                </button>
              </div>
            </div>
          )}

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

          {/* 1.2 KHUNG ĐIỀU HÀNH & LÊN LỊCH THỜI ĐIỂM BẢO TRÌ (1 BOX DUY NHẤT) */}
          <div className="bg-white rounded-2xl border border-outline-variant p-5 md:p-6 shadow-sm space-y-4">
            <div className="flex items-center justify-between border-b border-outline-variant pb-3">
              <h3 className="font-bold text-sm text-on-surface flex items-center gap-2 m-0">
                <span className="material-symbols-outlined text-primary text-[20px]">calendar_clock</span>
                {t('broadcast.scheduleCardTitle')}
              </h3>
            </div>

            {/* Nếu đã có lịch bảo trì hẹn trước */}
            {maintenance.scheduled ? (
              <div className="p-4 rounded-xl border border-blue-200 bg-blue-50/70 space-y-3">
                <div className="flex items-start justify-between gap-2">
                  <div className="flex items-center gap-2 text-blue-900 font-bold text-xs uppercase tracking-wider">
                    <span className="material-symbols-outlined text-[18px] text-blue-600">event_available</span>
                    {t('broadcast.schedule.upcomingTitle')}
                  </div>
                  <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                    maintenance.scheduled.isEmergency ? 'bg-red-100 text-red-700' : 'bg-blue-100 text-blue-700'
                  }`}>
                    {maintenance.scheduled.isEmergency ? t('broadcast.banner.emergencyBadge') : t('broadcast.banner.silentBadge')}
                  </span>
                </div>

                <div className="space-y-1 text-xs text-blue-950">
                  <p>
                    • {t('broadcast.schedule.startPrefix')} <b className="text-blue-700 text-sm">{formatDateTime(maintenance.scheduled.scheduledAt)}</b>
                  </p>
                  {maintenance.scheduled.scheduledEndAt && (
                    <p>
                      • {t('broadcast.schedule.endPrefix')} <b className="text-blue-700 text-sm">{formatDateTime(maintenance.scheduled.scheduledEndAt)}</b>
                    </p>
                  )}
                  <p>• {t('broadcast.schedule.reasonPrefix')} <b>{maintenance.scheduled.reason}</b></p>
                  <p className="text-[11px] text-blue-800/80">
                    • {t('broadcast.schedule.creatorPrefix')} <b>{maintenance.scheduled.createdBy}</b> ({formatDateTime(maintenance.scheduled.createdAt)})
                  </p>
                </div>

                <div className="pt-2 border-t border-blue-200/60 flex items-center justify-between gap-2">
                  <span className="text-[11px] text-blue-800 italic">
                    {t('broadcast.schedule.autoNotice')}
                  </span>
                  <button
                    onClick={handleCancelSchedule}
                    disabled={actionLoading}
                    className="px-3 py-1.5 bg-white hover:bg-red-50 text-red-600 border border-red-200 rounded-lg text-xs font-semibold transition-colors cursor-pointer flex items-center gap-1 shadow-2xs"
                  >
                    <span className="material-symbols-outlined text-[15px]">delete_sweep</span>
                    <span>{t('broadcast.schedule.cancelBtn')}</span>
                  </button>
                </div>
              </div>
            ) : maintenance.active ? (
              <div className="p-4 rounded-xl border border-amber-300 bg-amber-50/80 space-y-3">
                <div className="flex items-center gap-2 text-amber-900 font-bold text-xs uppercase tracking-wider">
                  <span className="material-symbols-outlined text-[20px] text-amber-600">block</span>
                  {t('broadcast.scheduleActiveNotice', 'Chế độ bảo trì đang kích hoạt')}
                </div>
                <p className="text-xs text-amber-950 leading-relaxed">
                  {t('broadcast.scheduleActiveDesc', 'Không thể thiết lập thêm lịch bảo trì mới để tránh xung đột thời gian')}
                </p>
                <p className="text-[11px] text-amber-800 italic pt-1 border-t border-amber-200">
                  👉 Vui lòng nhấn nút <b>"{t('broadcast.turnOffEmergencyBtn', 'Tắt Bảo Trì Khẩn Cấp')}"</b> ở biểu ngữ phía trên trước khi cài đặt lịch trình bảo trì mới.
                </p>
              </div>
            ) : (
              <form onSubmit={handleSaveSchedule} className="space-y-4">
                <div className={`grid grid-cols-1 sm:grid-cols-2 gap-3 transition-opacity ${isEmergencyAction ? 'opacity-40 pointer-events-none' : ''}`}>
                  <div>
                    <label htmlFor="schedule-start-at" className="block text-xs font-bold text-on-surface uppercase tracking-wider mb-1.5">
                      {t('broadcast.scheduleStartLabel')} {!isEmergencyAction && <span className="text-red-500">*</span>}
                    </label>
                    <input
                      id="schedule-start-at"
                      type="datetime-local"
                      min={currentLocalIso}
                      value={scheduleDatetime}
                      onChange={(e) => setScheduleDatetime(e.target.value)}
                      required={!isEmergencyAction}
                      disabled={isEmergencyAction || maintenance.active}
                      className="w-full border border-outline-variant rounded-lg px-3 py-2 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary disabled:bg-gray-100 disabled:cursor-not-allowed"
                    />
                  </div>

                  <div>
                    <label htmlFor="schedule-end-at" className="block text-xs font-bold text-on-surface uppercase tracking-wider mb-1.5">
                      {t('broadcast.scheduleEndLabel')}
                    </label>
                    <input
                      id="schedule-end-at"
                      type="datetime-local"
                      min={scheduleDatetime || currentLocalIso}
                      value={scheduleEndDatetime}
                      onChange={(e) => setScheduleEndDatetime(e.target.value)}
                      disabled={isEmergencyAction || maintenance.active}
                      className="w-full border border-outline-variant rounded-lg px-3 py-2 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary disabled:bg-gray-100 disabled:cursor-not-allowed"
                    />
                  </div>
                </div>

                {isEmergencyAction ? (
                  <p className="text-[11px] text-red-600 font-semibold -mt-1 flex items-center gap-1">
                    <span className="material-symbols-outlined text-[15px]">info</span>
                    {t('broadcast.schedule.emergencyImmediateNotice', 'Chế độ bảo trì khẩn cấp sẽ có hiệu lực ngay lập tức sau khi xác nhận popup.')}
                  </p>
                ) : (
                  <p className="text-[11px] text-on-surface-variant -mt-1">{t('broadcast.schedule.timezoneNote')}</p>
                )}

                <div>
                  <label htmlFor="schedule-reason" className="block text-xs font-bold text-on-surface uppercase tracking-wider mb-1.5">
                    {t('broadcast.scheduleReasonLabel')}
                  </label>
                  <input
                    id="schedule-reason"
                    type="text"
                    value={scheduleReason}
                    onChange={(e) => setScheduleReason(e.target.value)}
                    placeholder={isEmergencyAction ? t('broadcast.reasonPlaceholder', 'Ví dụ: Nâng cấp cụm máy chủ và tối ưu hóa hệ thống khẩn cấp...') : t('broadcast.scheduleReasonPlaceholder')}
                    disabled={maintenance.active}
                    className="w-full border border-outline-variant rounded-lg px-3.5 py-2.5 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary disabled:bg-gray-100 disabled:cursor-not-allowed"
                  />
                </div>

                {/* Hàng Checkbox: Tự động phát thông báo & Checkbox Bảo trì khẩn cấp nằm bên phải */}
                <div className="flex flex-wrap items-center gap-6 pt-1">
                  <label className={`flex items-center gap-2 cursor-pointer text-xs ${maintenance.active ? 'opacity-50 cursor-not-allowed' : 'text-on-surface'}`}>
                    <input
                      type="checkbox"
                      checked={scheduleNotify}
                      onChange={(e) => setScheduleNotify(e.target.checked)}
                      disabled={maintenance.active}
                      className="w-4 h-4 text-primary rounded border-gray-300 focus:ring-primary cursor-pointer disabled:cursor-not-allowed"
                    />
                    <span className="font-medium">{t('broadcast.schedule.autoNotifyTitle', 'Tự động phát thông báo')}</span>
                  </label>

                  <label className={`flex items-center gap-2 cursor-pointer text-xs ${maintenance.active ? 'opacity-50 cursor-not-allowed' : ''}`}>
                    <input
                      type="checkbox"
                      checked={isEmergencyAction}
                      onChange={(e) => setIsEmergencyAction(e.target.checked)}
                      disabled={maintenance.active}
                      className="w-4 h-4 text-red-600 rounded border-gray-300 focus:ring-red-500 cursor-pointer disabled:cursor-not-allowed"
                    />
                    <span className={`font-bold flex items-center gap-1 ${maintenance.active ? 'text-gray-400' : 'text-red-600'}`}>
                      <span className="material-symbols-outlined text-[16px]">warning</span>
                      {t('broadcast.schedule.emergencyCheckbox', 'Bảo trì khẩn cấp')}
                    </span>
                  </label>
                </div>

                {/* Hàng nút bấm: Nút hành động chính & Nút làm mới */}
                <div className="flex items-center gap-2.5 pt-2">
                  {isEmergencyAction ? (
                    <button
                      type="button"
                      onClick={() => setShowEmergencyConfirmModal(true)}
                      disabled={actionLoading || maintenance.active}
                      className="flex-1 py-2.5 px-4 rounded-xl text-xs font-bold text-white bg-red-600 hover:bg-red-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-all cursor-pointer flex items-center justify-center gap-2 shadow-sm"
                    >
                      <span className="material-symbols-outlined text-[18px]">warning</span>
                      <span>{actionLoading ? t('common.processing') : t('broadcast.schedule.emergencySubmitBtn', 'Bảo trì khẩn cấp')}</span>
                    </button>
                  ) : (
                    <button
                      type="submit"
                      disabled={actionLoading || !scheduleDatetime || maintenance.active}
                      className="flex-1 py-2.5 px-4 rounded-xl text-xs font-bold text-white bg-primary hover:bg-primary/90 disabled:bg-gray-300 disabled:cursor-not-allowed transition-all cursor-pointer flex items-center justify-center gap-2 shadow-sm"
                    >
                      <span className="material-symbols-outlined text-[18px]">alarm_on</span>
                      <span>{actionLoading ? t('common.saving') : t('broadcast.scheduleSubmitBtn', 'Lên lịch bảo trì')}</span>
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
            )}
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
                  <option value="SCHEDULED">{t('broadcast.history.typeScheduled', 'Theo lịch')}</option>
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
                  <option value="COMPLETED">{t('broadcast.history.statusCompleted', 'Đã hoàn thành')}</option>
                  <option value="CANCELLED">{t('broadcast.history.statusCancelled', 'Đã hủy')}</option>
                </select>

                <button
                  type="button"
                  onClick={() => fetchHistory(historyPage, historyLimit)}
                  disabled={loadingHistory}
                  className="p-1.5 hover:bg-surface-container-highest rounded-lg text-on-surface-variant transition-colors cursor-pointer flex items-center justify-center border border-outline-variant"
                  title={t('broadcast.history.refreshBtn', 'Làm mới')}
                >
                  <span className={`material-symbols-outlined text-[18px] ${loadingHistory ? 'animate-spin' : ''}`}>
                    refresh
                  </span>
                </button>
              </div>
            </div>

            {/* Bảng Dữ Liệu */}
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs border-collapse table-fixed">
                <thead>
                  <tr className="border-b border-outline-variant text-[11px] text-on-surface-variant uppercase tracking-wider bg-surface-container-lowest font-semibold">
                    <ResizableTh
                      colKey="id"
                      width={colWidths.id}
                      minWidth={40}
                      onResize={startResizing}
                      onReset={resetColumn}
                      className="py-2.5 px-3"
                    >
                      #
                    </ResizableTh>
                    <ResizableTh
                      colKey="type"
                      width={colWidths.type}
                      minWidth={90}
                      onResize={startResizing}
                      onReset={resetColumn}
                      className="py-2.5 px-3"
                    >
                      {t('broadcast.history.colType', 'Loại')}
                    </ResizableTh>
                    <ResizableTh
                      colKey="user"
                      width={colWidths.user}
                      minWidth={120}
                      onResize={startResizing}
                      onReset={resetColumn}
                      className="py-2.5 px-3"
                    >
                      {t('broadcast.history.colUser', 'Người kích hoạt')}
                    </ResizableTh>
                    <ResizableTh
                      colKey="reason"
                      width={colWidths.reason}
                      minWidth={140}
                      onResize={startResizing}
                      onReset={resetColumn}
                      className="py-2.5 px-3"
                    >
                      {t('broadcast.history.colReason', 'Lý do / Thông điệp')}
                    </ResizableTh>
                    <ResizableTh
                      colKey="start"
                      width={colWidths.start}
                      minWidth={110}
                      onResize={startResizing}
                      onReset={resetColumn}
                      className="py-2.5 px-3"
                    >
                      {t('broadcast.history.colStart', 'Bắt đầu')}
                    </ResizableTh>
                    <ResizableTh
                      colKey="end"
                      width={colWidths.end}
                      minWidth={110}
                      onResize={startResizing}
                      onReset={resetColumn}
                      className="py-2.5 px-3"
                    >
                      {t('broadcast.history.colEnd', 'Kết thúc')}
                    </ResizableTh>
                    <ResizableTh
                      colKey="duration"
                      width={colWidths.duration}
                      minWidth={90}
                      onResize={startResizing}
                      onReset={resetColumn}
                      className="py-2.5 px-3"
                    >
                      {t('broadcast.history.colDuration', 'Thời lượng')}
                    </ResizableTh>
                    <ResizableTh
                      colKey="status"
                      width={colWidths.status}
                      minWidth={100}
                      onResize={startResizing}
                      onReset={resetColumn}
                      className="py-2.5 px-3 text-right"
                    >
                      {t('broadcast.history.colStatus', 'Trạng thái')}
                    </ResizableTh>
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
                              <span>{isEmergency ? t('broadcast.history.typeEmergency', 'Khẩn cấp') : t('broadcast.history.typeScheduled', 'Theo lịch')}</span>
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
                                : isCompleted
                                ? 'bg-emerald-50 text-emerald-800 border-emerald-300'
                                : 'bg-gray-100 text-gray-700 border-gray-300'
                            }`}>
                              <span className="material-symbols-outlined text-[13px]">
                                {isOngoing ? 'sync' : isCompleted ? 'check_circle' : 'cancel'}
                              </span>
                              <span>
                                {isOngoing
                                  ? t('broadcast.history.statusOngoing', 'Đang diễn ra')
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
        <div className="max-w-2xl mx-auto space-y-6">
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

          <div className="bg-surface-container-low border border-outline-variant/60 rounded-xl p-4 text-xs text-on-surface-variant space-y-1.5">
            <p className="font-semibold text-on-surface flex items-center gap-1">
              <span className="material-symbols-outlined text-[15px] text-amber-600">info</span>
              {t('broadcast.rulesTitle')}
            </p>
            <p>{t('broadcast.rule1')}</p>
            <p>{t('broadcast.rule2')}</p>
            <p>{t('broadcast.rule3')}</p>
          </div>
        </div>
      )}

      {/* POPUP MODAL XÁC THỰC MÃ PIN / MẬT KHẨU BẢO TRÌ KHẨN CẤP */}
      <SecurityConfirmModal
        isOpen={showEmergencyConfirmModal}
        onClose={() => setShowEmergencyConfirmModal(false)}
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
    </div>
  );
};

export default BroadcastPage;
