import React, { useState, useEffect } from 'react';
import { useSettings } from '../../store/settings.context';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import useSocket from '../../hooks/useSocket';
import soundService from '../../services/sound.service';
import { API_BASE_URL } from '../../utils/constants';

const SettingsModal = ({ isOpen, onClose }) => {
  const alert = useAlertSafe();
  const socket = useSocket();
  const { language, changeLanguage, t } = useLanguageSafe();
  const {
    settings,
    updateSetting,
    resetSettings,
    lockScreen,
    pingLatency,
    isPinging,
    testPingLatency,
    safeClearCache,
    getStorageUsageKb,
  } = useSettings();

  const [activeTab, setActiveTab] = useState('general'); // 'general' | 'notifications' | 'realtime' | 'system'
  const [testingSound, setTestingSound] = useState(false);
  const [isSocketLive, setIsSocketLive] = useState(Boolean(socket?.connected));
  const [liveSocketId, setLiveSocketId] = useState(socket?.id || '');

  // Lắng nghe trực tiếp trạng thái Socket và cập nhật realtime
  useEffect(() => {
    if (!socket || typeof socket.on !== 'function') return;
    setIsSocketLive(Boolean(socket.connected));
    setLiveSocketId(socket.id || '');

    const onConnect = () => {
      setIsSocketLive(true);
      setLiveSocketId(socket.id || '');
      testPingLatency(socket);
    };

    const onDisconnect = () => {
      setIsSocketLive(false);
    };

    socket.on('connect', onConnect);
    socket.on('disconnect', onDisconnect);

    return () => {
      if (typeof socket.off === 'function') {
        socket.off('connect', onConnect);
        socket.off('disconnect', onDisconnect);
      }
    };
  }, [socket, testPingLatency]);

  // Tự động đo ping latency khi vào tab realtime và định kỳ cập nhật mỗi 5 giây
  useEffect(() => {
    if (!isOpen || activeTab !== 'realtime' || !socket || !isSocketLive) return;

    // Ping ngay khi mở tab
    testPingLatency(socket);

    const timer = setInterval(() => {
      if (socket.connected) {
        testPingLatency(socket);
      }
    }, 5000);

    return () => clearInterval(timer);
  }, [isOpen, activeTab, socket, isSocketLive, testPingLatency]);

  if (!isOpen) return null;

  // Xử lý nghe thử âm thanh cảnh báo
  const handleTestSound = () => {
    setTestingSound(true);
    soundService.playCriticalAlarm();
    setTimeout(() => {
      setTestingSound(false);
      alert?.info?.(
        t('settings.soundSection.soundSampleSent', 'Đã phát âm thanh cảnh báo mẫu qua Web Audio API'),
        t('settings.soundSection.soundCheckTitle', 'Kiểm Tra Loa')
      );
    }, 600);
  };

  // Xử lý đo độ trễ Socket (Ping test thủ công)
  const handlePingTest = async () => {
    const latency = await testPingLatency(socket);
    if (latency === -1) {
      alert?.error?.(
        t('settings.socketSection.latencyError', 'Không thể kết nối đến Socket Gateway server'),
        t('settings.socketSection.latencyErrorTitle', 'Đo Độ Trễ Thất Bại')
      );
    } else {
      alert?.success?.(
        t('settings.socketSection.latencyResult', { latency }),
        t('settings.socketSection.latencyTitle', 'Kiểm Tra Độ Trễ')
      );
    }
  };

  // Xử lý dọn dẹp cache an toàn (Bộ nhớ nhanh)
  const handleClearCacheConfirm = () => {
    if (window.confirm(t('settings.securitySection.confirmClearCache', 'Bạn có chắc chắn muốn dọn dẹp bộ nhớ đệm tạm thời của ứng dụng không?\n\nLưu ý an toàn: Toàn bộ phiên đăng nhập và các cài đặt tùy chỉnh của bạn sẽ được bảo toàn nguyên vẹn 100%.'))) {
      safeClearCache();
      alert?.success?.(
        t('settings.securitySection.clearCacheSuccess', 'Đã dọn dẹp bộ nhớ đệm nhanh của ứng dụng thành công.'),
        t('settings.securitySection.clearCacheSuccessTitle', 'Dọn Dẹp Bộ Nhớ')
      );
    }
  };

  // Xử lý khôi phục cài đặt gốc
  const handleResetDefaultsConfirm = () => {
    if (window.confirm(t('settings.footer.confirmResetDefaults', 'Bạn có chắc chắn muốn khôi phục toàn bộ cài đặt hệ thống về mặc định ban đầu không?\n\n(Bao gồm: Giao diện Sáng, mật độ Thoải mái, bật âm thanh, thông báo 4.5 giây, nhịp tim 3 giây, tự khóa 30 phút).'))) {
      resetSettings();
      alert?.info?.(
        t('settings.footer.resetDefaultsSuccess', 'Đã khôi phục toàn bộ cài đặt về mặc định ban đầu thành công!'),
        t('settings.footer.resetDefaultsSuccessTitle', 'Khôi Phục Cài Đặt Gốc')
      );
    }
  };

  // Xử lý khóa màn hình ngay
  const handleLockNow = () => {
    onClose();
    lockScreen();
  };

  const currentUsageKb = getStorageUsageKb();

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs animate-in fade-in duration-150">
      <div className="bg-white rounded-2xl border border-outline-variant max-w-2xl w-full shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        {/* Modal Header */}
        <div className="px-6 py-4 border-b border-outline-variant flex items-center justify-between bg-surface-bright">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center">
              <span className="material-symbols-outlined text-[24px]">settings</span>
            </div>
            <div>
              <h3 className="text-base font-bold text-on-surface m-0 tracking-tight">{t('settings.title', 'Cài Đặt Hệ Thống Admin')}</h3>
              <p className="text-xs text-on-surface-variant m-0">{t('settings.subtitle', 'Tùy chỉnh giao diện, cảnh báo, nhịp tim và phiên quản trị')}</p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="w-8 h-8 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-600 flex items-center justify-center cursor-pointer transition"
          >
            <span className="material-symbols-outlined text-[20px]">close</span>
          </button>
        </div>

        {/* Navigation Tabs */}
        <div className="flex items-center gap-1 px-6 pt-3 border-b border-outline-variant bg-slate-50/50">
          {[
            { id: 'general', label: t('settings.tabs.general', 'Giao Diện & Hiển Thị'), icon: 'palette' },
            { id: 'notifications', label: t('settings.tabs.notifications', 'Cảnh Báo & Âm Thanh'), icon: 'volume_up' },
            { id: 'realtime', label: t('settings.tabs.realtime', 'Thời Gian Thực & Socket'), icon: 'sync' },
            { id: 'system', label: t('settings.tabs.system', 'Bảo Mật & Thông Tin'), icon: 'shield' },
          ].map((tab) => (
            <button
              key={tab.id}
              type="button"
              onClick={() => setActiveTab(tab.id)}
              className={`px-3.5 py-2 text-xs font-bold border-b-2 transition-all cursor-pointer flex items-center gap-1.5 ${
                activeTab === tab.id
                  ? 'border-primary text-primary'
                  : 'border-transparent text-slate-500 hover:text-slate-700'
              }`}
            >
              <span className="material-symbols-outlined text-[16px]">{tab.icon}</span>
              <span>{tab.label}</span>
            </button>
          ))}
        </div>

        {/* Modal Body */}
        <div className="p-6 overflow-y-auto space-y-5 flex-1 text-xs">
          {/* TAB 1: Giao diện & Hiển thị */}
          {activeTab === 'general' && (
            <div className="space-y-4">
              {/* Khối Cài Đặt Ngôn Ngữ Giao Diện */}
              <div className="p-4 rounded-xl border border-outline-variant/60 bg-slate-50/60 flex items-center justify-between" data-testid="settings-language-section">
                <div>
                  <div className="font-bold text-slate-800">{t('settings.languageSection.title', 'Ngôn ngữ giao diện')}</div>
                  <div className="text-[11px] text-slate-500 mt-0.5">{t('settings.languageSection.desc', 'Lựa chọn ngôn ngữ hiển thị trên toàn bộ trang quản trị')}</div>
                </div>
                <div className="flex items-center gap-1.5 bg-white p-1 rounded-xl border border-slate-200">
                  <button
                    type="button"
                    data-testid="settings-lang-vi"
                    onClick={() => changeLanguage('vi')}
                    className={`px-3 py-1.5 rounded-lg font-bold transition cursor-pointer ${
                      language === 'vi' ? 'bg-primary text-white shadow-2xs' : 'text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    {t('settings.languageSection.vi', 'Tiếng Việt (VI)')}
                  </button>
                  <button
                    type="button"
                    data-testid="settings-lang-en"
                    onClick={() => changeLanguage('en')}
                    className={`px-3 py-1.5 rounded-lg font-bold transition cursor-pointer ${
                      language === 'en' ? 'bg-primary text-white shadow-2xs' : 'text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    {t('settings.languageSection.en', 'English (EN)')}
                  </button>
                </div>
              </div>

              <div className="p-4 rounded-xl border border-outline-variant/60 bg-slate-50/60 space-y-3">
                <div className="font-bold text-slate-800 flex items-center justify-between">
                  <span>{t('settings.themeSection.title', 'Chế độ hiển thị màu sắc:')}</span>
                  <span className="text-[11px] text-primary font-semibold">{t('settings.themeSection.recommended', 'Khuyến nghị: Sáng Enterprise')}</span>
                </div>
                <div className="grid grid-cols-2 gap-3">
                  {[
                    { id: 'light', label: t('settings.themeSection.light', 'Giao diện Sáng'), icon: 'light_mode' },
                    { id: 'dark', label: t('settings.themeSection.dark', 'Giao diện Tối'), icon: 'dark_mode' },
                  ].map((mode) => (
                    <button
                      key={mode.id}
                      type="button"
                      onClick={() => updateSetting('theme', mode.id)}
                      className={`p-3 rounded-xl border flex flex-col items-center gap-1.5 font-bold transition cursor-pointer ${
                        settings.theme === mode.id
                          ? 'border-primary bg-primary/5 text-primary shadow-2xs'
                          : 'border-slate-200 bg-white text-slate-600 hover:bg-slate-50'
                      }`}
                    >
                      <span className="material-symbols-outlined text-[20px]">{mode.icon}</span>
                      <span>{mode.label}</span>
                    </button>
                  ))}
                </div>
              </div>

              <div className="p-4 rounded-xl border border-outline-variant/60 bg-slate-50/60 flex items-center justify-between">
                <div>
                  <div className="font-bold text-slate-800">{t('settings.densitySection.title', 'Mật độ dòng bảng dữ liệu (Table Density)')}</div>
                  <div className="text-[11px] text-slate-500 mt-0.5">{t('settings.densitySection.desc', 'Khoảng cách hàng trong danh sách Người dùng và Danh mục')}</div>
                </div>
                <div className="flex items-center gap-1.5 bg-white p-1 rounded-xl border border-slate-200">
                  <button
                    type="button"
                    onClick={() => updateSetting('tableDensity', 'comfortable')}
                    className={`px-3 py-1.5 rounded-lg font-bold transition cursor-pointer ${
                      settings.tableDensity === 'comfortable' ? 'bg-primary text-white shadow-2xs' : 'text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    {t('settings.densitySection.comfortable', 'Thoải mái')}
                  </button>
                  <button
                    type="button"
                    onClick={() => updateSetting('tableDensity', 'compact')}
                    className={`px-3 py-1.5 rounded-lg font-bold transition cursor-pointer ${
                      settings.tableDensity === 'compact' ? 'bg-primary text-white shadow-2xs' : 'text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    {t('settings.densitySection.compact', 'Thu gọn')}
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* TAB 2: Cảnh báo & Âm thanh */}
          {activeTab === 'notifications' && (
            <div className="space-y-4">
              <div className="p-4 rounded-xl border border-outline-variant/60 bg-slate-50/60 flex items-center justify-between gap-4">
                <div className="flex-1">
                  <div className="font-bold text-slate-800">{t('settings.soundSection.title', 'Âm thanh chuông cảnh báo khẩn cấp')}</div>
                  <div className="text-[11px] text-slate-500 mt-0.5">{t('settings.soundSection.desc', 'Phát âm thanh cảnh báo khi Sentinel AIOps phát hiện DDoS / Threat Score cao')}</div>
                </div>
                <div className="flex items-center gap-3">
                  <button
                    type="button"
                    onClick={handleTestSound}
                    disabled={testingSound}
                    className="px-2.5 py-1 bg-white hover:bg-slate-100 border border-slate-300 rounded-lg text-slate-700 font-semibold text-[11px] flex items-center gap-1 cursor-pointer transition shadow-2xs"
                    title={t('settings.soundSection.testTooltip', 'Nghe thử âm lượng cảnh báo')}
                  >
                    <span className="material-symbols-outlined text-[15px] text-primary">volume_up</span>
                    <span>{testingSound ? t('settings.soundSection.testing', 'Đang phát...') : t('settings.soundSection.testBtn', 'Nghe thử')}</span>
                  </button>
                  <label className="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      checked={settings.soundEnabled}
                      onChange={(e) => updateSetting('soundEnabled', e.target.checked)}
                      className="sr-only peer"
                    />
                    <div className="w-11 h-6 bg-slate-300 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary" />
                  </label>
                </div>
              </div>

              <div className="p-4 rounded-xl border border-outline-variant/60 bg-slate-50/60 flex items-center justify-between">
                <div>
                  <div className="font-bold text-slate-800">{t('settings.toastSection.title', 'Thời gian tự ẩn thông báo Toast')}</div>
                  <div className="text-[11px] text-slate-500 mt-0.5">{t('settings.toastSection.desc', 'Khoảng thời gian hộp thoại thông báo nổi tự động đóng')}</div>
                </div>
                <select
                  value={settings.toastDuration}
                  onChange={(e) => updateSetting('toastDuration', Number(e.target.value))}
                  className="px-3 py-1.5 bg-white border border-outline-variant rounded-xl font-bold text-on-surface focus:outline-none focus:ring-2 focus:ring-primary cursor-pointer"
                >
                  <option value={3000}>{t('settings.toastSection.seconds3', '3 giây (Nhanh)')}</option>
                  <option value={4500}>{t('settings.toastSection.seconds45', '4.5 giây (Chuẩn)')}</option>
                  <option value={7000}>{t('settings.toastSection.seconds7', '7 giây (Đọc chậm)')}</option>
                  <option value={10000}>{t('settings.toastSection.seconds10', '10 giây')}</option>
                </select>
              </div>

              <div className="p-4 rounded-xl border border-outline-variant/60 bg-slate-50/60 flex items-center justify-between">
                <div>
                  <div className="font-bold text-slate-800">{t('settings.badgeSection.title', 'Huy hiệu số lượng thông báo chưa đọc')}</div>
                  <div className="text-[11px] text-slate-500 mt-0.5">{t('settings.badgeSection.desc', 'Hiển thị chấm đỏ số lượng trên icon chuông ở góc trên màn hình')}</div>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={settings.showUnreadBadge}
                    onChange={(e) => updateSetting('showUnreadBadge', e.target.checked)}
                    className="sr-only peer"
                  />
                  <div className="w-11 h-6 bg-slate-300 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary" />
                </label>
              </div>
            </div>
          )}

          {/* TAB 3: Thời gian thực & Socket */}
          {activeTab === 'realtime' && (
            <div className="space-y-4">
              <div className={`p-4 rounded-xl border flex flex-col md:flex-row md:items-center justify-between gap-3 ${
                isSocketLive ? 'border-emerald-300 bg-emerald-50/80 text-emerald-950' : 'border-rose-300 bg-rose-50/80 text-rose-950'
              }`}>
                <div className="flex items-center gap-3">
                  <span className={`w-3 h-3 rounded-full flex-shrink-0 ${
                    isSocketLive ? 'bg-emerald-500 animate-ping' : 'bg-rose-500'
                  }`} />
                  <div>
                    <div className="font-bold flex items-center gap-2">
                      <span>{t('settings.socketSection.title', 'Trạng Thái Kết Nối Socket.IO: ')}{isSocketLive ? t('settings.socketSection.online', 'Trực Tuyến') : t('settings.socketSection.offline', 'Mất Kết Nối')}</span>
                      {liveSocketId && (
                        <span className="text-[10px] font-mono px-1.5 py-0.2 bg-white/60 rounded border border-emerald-200">
                          ID: {liveSocketId.slice(0, 8)}...
                        </span>
                      )}
                    </div>
                    <div className="text-[11px] opacity-90">{t('settings.socketSection.desc', 'Kênh truyền hai chiều độ trễ cực thấp giữa Backend và Admin-web')}</div>
                  </div>
                </div>

                <div className="flex items-center gap-2 self-end md:self-center">
                  <button
                    type="button"
                    onClick={handlePingTest}
                    disabled={isPinging || !isSocketLive}
                    className="px-2.5 py-1 bg-white hover:bg-slate-50 border border-slate-300 rounded-lg text-slate-800 font-semibold text-[11px] flex items-center gap-1 cursor-pointer transition shadow-2xs disabled:opacity-50"
                    title={t('settings.socketSection.pingTooltip', 'Kiểm tra lại độ trễ phản hồi ngay lập tức')}
                  >
                    <span className={`material-symbols-outlined text-[15px] ${isPinging ? 'animate-spin' : 'text-primary'}`}>
                      {isPinging ? 'progress_activity' : 'speed'}
                    </span>
                    <span>{isPinging ? t('settings.socketSection.pinging', 'Đang ping...') : pingLatency !== null && pingLatency !== -1 ? `${pingLatency}ms` : t('settings.socketSection.pingBtn', 'Ping Test')}</span>
                  </button>
                  <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold bg-white border ${
                    isSocketLive ? 'text-emerald-800 border-emerald-300' : 'text-rose-800 border-rose-300'
                  }`}>
                    {isSocketLive ? t('settings.socketSection.activePort', 'Cổng 3000 (Active)') : t('settings.socketSection.offline', 'Mất Kết Nối')}
                  </span>
                </div>
              </div>

              <div className="p-4 rounded-xl border border-outline-variant/60 bg-slate-50/60 flex items-center justify-between">
                <div>
                  <div className="font-bold text-slate-800">{t('settings.metricsSection.title', 'Tần suất nhịp tim AIOps Metrics')}</div>
                  <div className="text-[11px] text-slate-500 mt-0.5">{t('settings.metricsSection.desc', 'Khoảng thời gian cập nhật biểu đồ phần cứng & Threat Score')}</div>
                </div>
                <select
                  value={settings.metricsInterval}
                  onChange={(e) => updateSetting('metricsInterval', Number(e.target.value))}
                  className="px-3 py-1.5 bg-white border border-outline-variant rounded-xl font-bold text-on-surface focus:outline-none focus:ring-2 focus:ring-primary cursor-pointer"
                >
                  <option value={1}>{t('settings.metricsSection.sec1', '1 giây (Thời gian thực cao)')}</option>
                  <option value={3}>{t('settings.metricsSection.sec3', '3 giây (Mặc định chuẩn)')}</option>
                  <option value={5}>{t('settings.metricsSection.sec5', '5 giây (Tiết kiệm tải)')}</option>
                  <option value={10}>{t('settings.metricsSection.sec10', '10 giây')}</option>
                </select>
              </div>
            </div>
          )}

          {/* TAB 4: Bảo mật & Thông tin */}
          {activeTab === 'system' && (
            <div className="space-y-4">
              <div className="p-4 rounded-xl border border-outline-variant/60 bg-slate-50/60 flex items-center justify-between gap-4">
                <div className="flex-1">
                  <div className="font-bold text-slate-800">{t('settings.securitySection.title', 'Tự động khóa an toàn khi không hoạt động')}</div>
                  <div className="text-[11px] text-slate-500 mt-0.5">{t('settings.securitySection.desc', 'Tự động khóa an toàn khi không mở website (chuyển tab hoặc rời trang) quá thời gian quy định')}</div>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={handleLockNow}
                    className="px-2.5 py-1.5 bg-white hover:bg-slate-100 border border-slate-300 text-slate-700 rounded-xl font-semibold text-[11px] flex items-center gap-1 cursor-pointer transition shadow-2xs"
                    title={t('settings.securitySection.lockTooltip', 'Khóa màn hình làm việc tức thì')}
                  >
                    <span className="material-symbols-outlined text-[15px] text-amber-500">lock</span>
                    <span>{t('settings.securitySection.lockNowBtn', 'Khóa ngay')}</span>
                  </button>
                  <select
                    value={settings.autoLockMinutes}
                    onChange={(e) => updateSetting('autoLockMinutes', Number(e.target.value))}
                    className="px-3 py-1.5 bg-white border border-outline-variant rounded-xl font-bold text-on-surface focus:outline-none focus:ring-2 focus:ring-primary cursor-pointer"
                  >
                    <option value={15}>{t('settings.securitySection.min15', '15 phút')}</option>
                    <option value={30}>{t('settings.securitySection.min30', '30 phút (Khuyên dùng)')}</option>
                    <option value={60}>{t('settings.securitySection.min60', '60 phút')}</option>
                    <option value={0}>{t('settings.securitySection.never', 'Không bao giờ')}</option>
                  </select>
                </div>
              </div>

              <div className="p-4 rounded-xl border border-rose-200 bg-rose-50/50 flex items-center justify-between">
                <div>
                  <div className="font-bold text-rose-900 flex items-center gap-2">
                    <span>{t('settings.securitySection.clearCacheTitle', 'Dọn dẹp bộ nhớ đệm (Clear Cache)')}</span>
                    <span className="text-[10px] font-mono px-1.5 py-0.2 bg-white rounded border border-rose-200 text-rose-800">
                      {t('settings.securitySection.using', 'Đang dùng: ')}{currentUsageKb} KB
                    </span>
                  </div>
                  <div className="text-[11px] text-rose-700 mt-0.5">{t('settings.securitySection.clearCacheHelp', 'Làm sạch bộ nhớ tạm thời của trình duyệt (sessionStorage và cache nhanh) giúp ứng dụng hoạt động mượt mà hơn.')}</div>
                </div>
                <button
                  type="button"
                  onClick={handleClearCacheConfirm}
                  className="px-3.5 py-1.5 bg-white hover:bg-rose-50 border border-rose-300 text-rose-700 font-bold rounded-xl transition cursor-pointer shadow-2xs"
                >
                  {t('settings.securitySection.clearCacheBtn', 'Xóa Cache')}
                </button>
              </div>

              <div className="p-4 rounded-xl border border-slate-200 bg-white space-y-1.5 text-[11px] text-slate-600">
                <div className="font-bold text-slate-800 text-xs mb-1">{t('settings.securitySection.platformInfo', 'Thông Tin Nền Tảng:')}</div>
                <div className="flex justify-between"><span>{t('settings.securitySection.adminVersion', 'Phiên bản quản trị:')}</span><strong className="font-mono text-slate-900">FinanceAdmin v2.5.0 (Enterprise)</strong></div>
                <div className="flex justify-between"><span>{t('settings.securitySection.runtimeEnv', 'Môi trường runtime:')}</span><strong className="text-slate-900 uppercase font-mono">{import.meta.env.MODE || 'development'}</strong></div>
                <div className="flex justify-between"><span>{t('settings.securitySection.gatewayApi', 'Gateway API Backend:')}</span><strong className="text-slate-900 font-mono">{API_BASE_URL}</strong></div>
                <div className="flex justify-between"><span>{t('settings.securitySection.database', 'Cơ sở dữ liệu:')}</span><strong className="text-slate-900">PostgreSQL Supabase (Tokyo, AWS)</strong></div>
                <div className="flex justify-between"><span>{t('settings.securitySection.timezone', 'Múi giờ hệ thống:')}</span><strong className="text-slate-900">Asia/Ho_Chi_Minh (GMT+7)</strong></div>
              </div>
            </div>
          )}
        </div>

        {/* Modal Footer */}
        <div className="px-6 py-3.5 border-t border-outline-variant bg-slate-50 flex items-center justify-between">
          <button
            type="button"
            onClick={handleResetDefaultsConfirm}
            className="text-xs font-semibold text-slate-500 hover:text-slate-700 hover:underline cursor-pointer"
          >
            {t('settings.footer.resetDefaults', 'Khôi phục cài đặt gốc')}
          </button>
          <button
            type="button"
            onClick={onClose}
            className="px-5 py-2 bg-primary hover:bg-primary/90 text-white font-bold rounded-xl text-xs shadow-xs transition cursor-pointer"
          >
            {t('settings.footer.complete', 'Hoàn Tất')}
          </button>
        </div>
      </div>
    </div>
  );
};

export default SettingsModal;
