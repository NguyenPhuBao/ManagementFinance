import React, { useState, useEffect } from 'react';
import adminApi from '../../api/admin.api';
import notificationApi from '../../api/notification.api';
import useSocket from '../../hooks/useSocket';
import { formatDateTime } from '../../utils/format';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';

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

  // --- State Quản trị Bảo trì ---
  const [maintenance, setMaintenance] = useState({
    active: false,
    isEmergency: false,
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

  // Form Bật/Tắt tức thì
  const [instantReason, setInstantReason] = useState('');
  const [instantEmergency, setInstantEmergency] = useState(false);

  const [scheduleDatetime, setScheduleDatetime] = useState('');
  const [scheduleEndDatetime, setScheduleEndDatetime] = useState('');
  const [scheduleReason, setScheduleReason] = useState('');
  const [scheduleNotify, setScheduleNotify] = useState(false);
  const [isRefreshing, setIsRefreshing] = useState(false);


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
          setInstantEmergency(Boolean(data.isEmergency));
        }
      }
    } catch (err) {
      console.error('[BroadcastPage] Lỗi lấy trạng thái bảo trì', err);
    } finally {
      setLoadingMaintenance(false);
    }
  };

  useEffect(() => {
    fetchMaintenance();
  }, []);

  // Lắng nghe sự kiện bảo trì Realtime qua Socket.io
  useEffect(() => {
    if (!socket) return;

    const handleMaintenanceChanged = (mState) => {
      console.log('[BroadcastPage] Nhận sự kiện maintenance_changed realtime:', mState);
      if (mState) {
        setMaintenance(mState);
        if (mState.reason && mState.active) {
          setInstantReason(mState.reason);
          setInstantEmergency(Boolean(mState.isEmergency));
        }
      }
    };

    socket.on('admin.maintenance_changed', handleMaintenanceChanged);
    socket.on('system.maintenance_changed', handleMaintenanceChanged);

    return () => {
      socket.off('admin.maintenance_changed', handleMaintenanceChanged);
      socket.off('system.maintenance_changed', handleMaintenanceChanged);
    };
  }, [socket]);

  // Xử lý Bật/Tắt bảo trì tức thì
  const handleToggleMaintenance = async (nextActive) => {
    setActionLoading(true);
    setMaintenanceFeedback(null);
    try {
      const payload = {
        active: nextActive,
        reason: instantReason.trim() || (instantEmergency ? t('broadcast.banner.emergencyDesc') : t('broadcast.banner.silentDesc')),
        isEmergency: Boolean(instantEmergency),
      };

      const res = await adminApi.setMaintenanceStatus(payload);
      const data = res?.data || res;
      setMaintenance(data);
      setMaintenanceFeedback({
        ok: true,
        msg: nextActive
          ? (instantEmergency ? t('broadcast.feedback.emergencyActivated') : t('broadcast.feedback.silentActivated'))
          : t('broadcast.feedback.maintenanceRestored'),
      });
      if (!nextActive) {
        setInstantReason('');
        setInstantEmergency(false);
      }
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

  // Xử lý Làm mới trạng thái & Đặt lại biểu mẫu lên lịch bảo trì
  const handleResetScheduleFormAndRefresh = async () => {
    try {
      setIsRefreshing(true);
      setScheduleDatetime('');
      setScheduleEndDatetime('');
      setScheduleReason('');
      setScheduleNotify(false);
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
          <p className="font-body-md text-on-surface-variant mt-1">
            {t('broadcast.subtitle')}
          </p>
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
          {/* 1.1 BANNER TRẠNG THÁI TOÀN CỤC */}
          <div
            className={`rounded-2xl border p-5 transition-all shadow-xs ${
              maintenance.active
                ? maintenance.isEmergency
                  ? 'border-red-300 bg-red-50/90 text-red-950'
                  : 'border-orange-300 bg-orange-50/90 text-orange-950'
                : 'border-emerald-300 bg-emerald-50/80 text-emerald-950'
            }`}
          >
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
              <div className="flex items-start gap-3.5">
                <div
                  className={`w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0 shadow-xs ${
                    maintenance.active
                      ? maintenance.isEmergency
                        ? 'bg-red-600 text-white animate-pulse'
                        : 'bg-orange-500 text-white'
                      : 'bg-emerald-600 text-white'
                  }`}
                >
                  <span className="material-symbols-outlined text-[26px]">
                    {maintenance.active ? (maintenance.isEmergency ? 'error' : 'construction') : 'verified_user'}
                  </span>
                </div>
                <div>
                  <div className="flex items-center gap-2 flex-wrap">
                    <h2 className="text-base font-bold m-0">
                      {maintenance.active
                        ? maintenance.isEmergency
                          ? t('broadcast.banner.emergencyTitle')
                          : t('broadcast.banner.silentTitle')
                        : t('broadcast.banner.normalTitle')}
                    </h2>
                    <span
                      className={`px-2.5 py-0.5 rounded-full text-[11px] font-bold tracking-wide uppercase ${
                        maintenance.active
                          ? maintenance.isEmergency
                            ? 'bg-red-200 text-red-800'
                            : 'bg-orange-200 text-orange-800'
                          : 'bg-emerald-200 text-emerald-800'
                      }`}
                    >
                      {maintenance.active ? (maintenance.isEmergency ? t('broadcast.banner.emergencyBadge') : t('broadcast.banner.silentBadge')) : t('broadcast.banner.normalBadge')}
                    </span>
                  </div>
                  <p className="text-xs opacity-90 mt-1">
                    {maintenance.active
                      ? maintenance.isEmergency
                        ? t('broadcast.banner.emergencyDesc')
                        : t('broadcast.banner.silentDesc')
                      : t('broadcast.banner.normalDesc')}
                  </p>
                  {maintenance.active && (
                    <div className="mt-2 text-xs flex flex-wrap gap-x-4 gap-y-1 font-medium">
                      <span>• {t('broadcast.banner.reasonLabel')} <b>{maintenance.reason || t('broadcast.banner.noReason')}</b></span>
                      {maintenance.activatedBy && <span>• {t('broadcast.banner.activatedByLabel')} <b>{maintenance.activatedBy}</b></span>}
                      {maintenance.activatedAt && (
                        <span>• {t('broadcast.banner.activatedAtLabel')} <b>{formatDateTime(maintenance.activatedAt)}</b></span>
                      )}
                    </div>
                  )}
                </div>
              </div>

              {/* Quick toggle if currently active */}
              {maintenance.active && (
                <button
                  onClick={() => handleToggleMaintenance(false)}
                  disabled={actionLoading}
                  className="px-5 py-2.5 bg-white hover:bg-gray-50 border border-gray-300 text-on-surface text-xs font-bold rounded-xl shadow-xs transition-all cursor-pointer flex items-center justify-center gap-2 self-start md:self-center flex-shrink-0"
                >
                  <span className="material-symbols-outlined text-[18px] text-emerald-600">power_settings_new</span>
                  <span>{t('broadcast.turnOffBtn')}</span>
                </button>
              )}
            </div>
          </div>

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

          {/* 1.2 LƯỚI 2 CỘT: BẬT TỨC THÌ VS. LÊN LỊCH */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* CỘT TRÁI: BẬT / TẮT BẢO TRÌ TỨC THÌ */}
            <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4 flex flex-col justify-between">
              <div className="space-y-4">
                <div className="flex items-center justify-between border-b border-outline-variant pb-3">
                  <h3 className="font-bold text-sm text-on-surface flex items-center gap-2 m-0">
                    <span className="material-symbols-outlined text-primary text-[20px]">flash_on</span>
                    {t('broadcast.instantCardTitle')}
                  </h3>
                  <span className="text-[11px] text-on-surface-variant font-medium">{t('broadcast.instant.impactTag')}</span>
                </div>

                {!maintenance.active ? (
                  <>
                    <div>
                      <label className="block text-xs font-bold text-on-surface uppercase tracking-wider mb-1.5">
                        {t('broadcast.reasonLabel')}
                      </label>
                      <input
                        type="text"
                        value={instantReason}
                        onChange={(e) => setInstantReason(e.target.value)}
                        placeholder={t('broadcast.reasonPlaceholder')}
                        className="w-full border border-outline-variant rounded-lg px-3.5 py-2.5 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                      />
                    </div>

                    {/* Checkbox Bảo trì khẩn cấp */}
                    <div className="p-3.5 rounded-xl border border-red-200 bg-red-50/50 space-y-2">
                      <label className="flex items-start gap-2.5 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={instantEmergency}
                          onChange={(e) => setInstantEmergency(e.target.checked)}
                          className="mt-0.5 w-4 h-4 text-red-600 rounded border-gray-300 focus:ring-red-500 cursor-pointer"
                        />
                        <div className="text-xs">
                          <span className="font-bold text-red-900 block">
                            {t('broadcast.emergencyCheckbox')}
                          </span>
                          <span className="text-red-700/80 text-[11px] block mt-0.5">
                            {t('broadcast.emergencyHint')}
                          </span>
                        </div>
                      </label>
                    </div>

                    <div className="bg-surface-container-lowest p-3 rounded-lg border border-outline-variant text-[11px] text-on-surface-variant space-y-1">
                      <p className="font-semibold text-on-surface">{t('broadcast.instant.hintNormalTitle')}</p>
                      <p className="pl-2.5">{t('broadcast.instant.hintNormalDesc')}</p>
                      <p className="font-semibold text-on-surface">{t('broadcast.instant.hintEmergencyTitle')}</p>
                      <p className="pl-2.5">{t('broadcast.instant.hintEmergencyDesc')}</p>
                    </div>
                  </>
                ) : (
                  <div className="p-4 rounded-xl border border-orange-200 bg-orange-50/70 space-y-3">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2 font-bold text-xs text-orange-950 uppercase">
                        <span className="material-symbols-outlined text-[20px] text-orange-600 animate-spin">build</span>
                        <span>{t('broadcast.instant.sessionOngoing')}</span>
                      </div>
                      <span className={`px-2.5 py-0.5 rounded-full text-[11px] font-bold ${
                        maintenance.isEmergency ? 'bg-red-200 text-red-800' : 'bg-orange-200 text-orange-800'
                      }`}>
                        {maintenance.isEmergency ? t('broadcast.banner.emergencyBadge') : t('broadcast.banner.silentBadge')}
                      </span>
                    </div>

                    <div className="space-y-1 text-xs text-orange-950">
                      <p>• {t('broadcast.banner.reasonLabel')} <b className="text-orange-900">{maintenance.reason || t('broadcast.banner.noReason')}</b></p>
                      {maintenance.activatedBy && <p>• {t('broadcast.banner.activatedByLabel')} <b>{maintenance.activatedBy}</b></p>}
                      {maintenance.activatedAt && <p>• {t('broadcast.banner.activatedAtLabel')} <b>{formatDateTime(maintenance.activatedAt)}</b></p>}
                    </div>

                    <p className="text-[11px] text-orange-800/90 pt-1.5 border-t border-orange-200/60 leading-relaxed">
                      {t('broadcast.instant.sessionBlockedHint')}
                    </p>
                  </div>
                )}
              </div>

              <div>
                {!maintenance.active ? (
                  <button
                    onClick={() => handleToggleMaintenance(true)}
                    disabled={actionLoading}
                    className={`w-full py-2.5 px-4 rounded-xl text-xs font-bold text-white transition-all cursor-pointer flex items-center justify-center gap-2 shadow-sm ${
                      instantEmergency
                        ? 'bg-red-600 hover:bg-red-700 focus:ring-4 focus:ring-red-200'
                        : 'bg-primary hover:bg-primary/90 focus:ring-4 focus:ring-primary/20'
                    }`}
                  >
                    <span className="material-symbols-outlined text-[18px]">
                      {instantEmergency ? 'warning' : 'play_arrow'}
                    </span>
                    <span>
                      {actionLoading
                        ? t('common.processing')
                        : instantEmergency
                        ? t('broadcast.turnOnEmergencyBtn')
                        : t('broadcast.turnOnNormalBtn')}
                    </span>
                  </button>
                ) : (
                  <button
                    onClick={() => handleToggleMaintenance(false)}
                    disabled={actionLoading}
                    className="w-full py-2.5 px-4 rounded-xl text-xs font-bold text-white bg-emerald-600 hover:bg-emerald-700 transition-all cursor-pointer flex items-center justify-center gap-2 shadow-sm"
                  >
                    <span className="material-symbols-outlined text-[18px]">power_settings_new</span>
                    <span>{actionLoading ? t('common.processing') : t('broadcast.scheduleEndMaintGuide')}</span>
                  </button>
                )}
              </div>
            </div>

            {/* CỘT PHẢI: LÊN LỊCH THỜI ĐIỂM BẢO TRÌ */}
            <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4 flex flex-col justify-between">
              <div className="space-y-4">
                <div className="flex items-center justify-between border-b border-outline-variant pb-3">
                  <h3 className="font-bold text-sm text-on-surface flex items-center gap-2 m-0">
                    <span className="material-symbols-outlined text-primary text-[20px]">calendar_clock</span>
                    {t('broadcast.scheduleCardTitle')}
                  </h3>
                  <span className="text-[11px] text-on-surface-variant font-medium">{t('broadcast.schedule.autoTimerTag')}</span>
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
                      {t('broadcast.scheduleActiveNotice')}
                    </div>
                    <p className="text-xs text-amber-950 leading-relaxed">
                      {t('broadcast.scheduleActiveDesc')}
                    </p>
                    <p className="text-[11px] text-amber-800 italic pt-1 border-t border-amber-200">
                      👉 Vui lòng nhấn nút <b>"{t('broadcast.scheduleEndMaintBtnName')}"</b> ở cột bên trái trước khi cài đặt lịch trình bảo trì mới.
                    </p>
                  </div>
                ) : (
                  <form onSubmit={handleSaveSchedule} className="space-y-3.5">
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <div>
                        <label htmlFor="schedule-start-at" className="block text-xs font-bold text-on-surface uppercase tracking-wider mb-1.5">
                          {t('broadcast.scheduleStartLabel')} <span className="text-red-500">*</span>
                        </label>
                        <input
                          id="schedule-start-at"
                          type="datetime-local"
                          min={currentLocalIso}
                          value={scheduleDatetime}
                          onChange={(e) => setScheduleDatetime(e.target.value)}
                          required
                          className="w-full border border-outline-variant rounded-lg px-3 py-2 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
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
                          className="w-full border border-outline-variant rounded-lg px-3 py-2 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                        />
                      </div>
                    </div>
                    <p className="text-[11px] text-on-surface-variant -mt-1">{t('broadcast.schedule.timezoneNote')}</p>

                    <div>
                      <label htmlFor="schedule-reason" className="block text-xs font-bold text-on-surface uppercase tracking-wider mb-1.5">
                        {t('broadcast.scheduleReasonLabel')}
                      </label>
                      <input
                        id="schedule-reason"
                        type="text"
                        value={scheduleReason}
                        onChange={(e) => setScheduleReason(e.target.value)}
                        placeholder={t('broadcast.scheduleReasonPlaceholder')}
                        className="w-full border border-outline-variant rounded-lg px-3.5 py-2.5 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
                      />
                    </div>

                    <label className="flex items-start gap-2.5 cursor-pointer text-xs text-on-surface">
                      <input
                        type="checkbox"
                        checked={scheduleNotify}
                        onChange={(e) => setScheduleNotify(e.target.checked)}
                        className="w-4 h-4 mt-0.5 text-primary rounded border-gray-300 focus:ring-primary cursor-pointer"
                      />
                      <div>
                        <span className="font-medium">{t('broadcast.schedule.autoNotifyTitle')}</span>
                        <p className="text-[11px] text-on-surface-variant mt-0.5">
                          {t('broadcast.schedule.autoNotifyDesc')}
                        </p>
                      </div>
                    </label>

                    <button
                      type="submit"
                      disabled={actionLoading || !scheduleDatetime}
                      className="w-full py-2.5 px-4 rounded-xl text-xs font-bold text-white bg-primary hover:bg-primary/90 disabled:bg-gray-300 disabled:cursor-not-allowed transition-all cursor-pointer flex items-center justify-center gap-2 shadow-sm"
                    >
                      <span className="material-symbols-outlined text-[18px]">alarm_on</span>
                      <span>{actionLoading ? t('common.saving') : t('broadcast.scheduleSubmitBtn')}</span>
                    </button>
                  </form>
                )}

                {/* Ghi chú quy tắc ghi đè của PO */}
                <div className="bg-amber-50/60 border border-amber-200/80 rounded-xl p-3 text-[11px] text-amber-900 space-y-1">
                  <p className="font-bold flex items-center gap-1">
                    <span className="material-symbols-outlined text-[14px] text-amber-600">rule</span>
                    {t('broadcast.schedule.policyTitle')}
                  </p>
                  <p>
                    {t('broadcast.schedule.policyDesc')}
                  </p>
                </div>
              </div>

              <div className="flex items-center justify-end border-t border-outline-variant/60 pt-3">
                <button
                  type="button"
                  onClick={handleResetScheduleFormAndRefresh}
                  disabled={isRefreshing}
                  className="text-primary hover:underline flex items-center gap-1.5 cursor-pointer font-medium text-xs disabled:opacity-50"
                  title={t('broadcast.schedule.resetTooltip')}
                >
                  <span className={`material-symbols-outlined text-[16px] ${isRefreshing ? 'animate-spin' : ''}`}>
                    refresh
                  </span>
                  <span>{isRefreshing ? t('broadcast.schedule.refreshing') : t('broadcast.resetFormBtn')}</span>
                </button>
              </div>
            </div>
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
    </div>
  );
};

export default BroadcastPage;
