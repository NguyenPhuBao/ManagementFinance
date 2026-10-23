import React, { useState, useEffect } from 'react';
import { useSettings } from '../../store/settings.context';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import { useAuthContext } from '../../store/auth.context';
import useSocket from '../../hooks/useSocket';
import soundService from '../../services/sound.service';
import adminApi from '../../api/admin.api';
import { API_BASE_URL } from '../../utils/constants';

const SettingsModal = ({ isOpen, onClose }) => {
  const alert = useAlertSafe();
  const socket = useSocket();
  let authCtx = {};
  try {
    if (typeof useAuthContext === 'function') {
      authCtx = useAuthContext() || {};
    }
  } catch (_) {
    authCtx = {};
  }
  const user = authCtx?.user || authCtx?.admin;
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

  const [activeTab, setActiveTab] = useState('general'); // 'general' | 'notifications' | 'realtime' | 'system' | 'admin_mgmt'
  const [testingSound, setTestingSound] = useState(false);
  const [isSocketLive, setIsSocketLive] = useState(Boolean(socket?.connected));
  const [liveSocketId, setLiveSocketId] = useState(socket?.id || '');

  // State 1: Modal Đổi mã PIN Admin
  const [showPinModal, setShowPinModal] = useState(false);
  const [showPinChange, setShowPinChange] = useState(false);
  const [pinForm, setPinForm] = useState({ password: '', oldPin: '', newPin: '', confirmPin: '' });
  const [pinLoading, setPinLoading] = useState(false);
  const [pinError, setPinError] = useState('');

  // State 2: Modal Đổi Mật Khẩu Admin
  const [showPasswordModal, setShowPasswordModal] = useState(false);
  const [passwordForm, setPasswordForm] = useState({ oldPassword: '', pin: '', newPassword: '', confirmPassword: '' });
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [passwordError, setPasswordError] = useState('');

  // State 3: Modal Cấp Tài Khoản Admin Mới
  const [showCreateAdminModal, setShowCreateAdminModal] = useState(false);
  const [createAdminStep, setCreateAdminStep] = useState(1); // 1: Info (fullname, username, email, phone, address) | 2: PIN verification | 3: Success result
  const [createAdminForm, setCreateAdminForm] = useState({
    username: '',
    email: '',
    fullName: '',
    phone: '',
    address: '',
    countryCode: '+84',
    pin: '',
  });
  const [createAdminLoading, setCreateAdminLoading] = useState(false);
  const [createAdminError, setCreateAdminError] = useState('');
  const [createdAdminResult, setCreatedAdminResult] = useState(null);

  // Xử lý Đổi mã PIN
  const handleChangePin = async (e) => {
    e?.preventDefault?.();
    setPinError('');
    if (!pinForm.password) {
      setPinError(t('settings.pinSection.requirePassword', 'Vui lòng nhập mật khẩu tài khoản hiện tại'));
      return;
    }
    if (pinForm.oldPin && !/^\d{6}$/.test(pinForm.oldPin)) {
      setPinError(t('settings.pinSection.requireOldPin', 'Vui lòng nhập đúng mã PIN cũ (6 chữ số)'));
      return;
    }
    if (!/^\d{6}$/.test(pinForm.newPin)) {
      setPinError(t('settings.pinSection.invalidPin', 'Mã PIN mới phải bao gồm đúng 6 chữ số'));
      return;
    }
    if (pinForm.oldPin && pinForm.newPin.trim() === pinForm.oldPin.trim()) {
      setPinError(t('settings.pinSection.samePin', 'Mã PIN mới không được trùng với mã PIN hiện tại'));
      return;
    }
    if (pinForm.newPin !== pinForm.confirmPin) {
      setPinError(t('settings.pinSection.mismatchPin', 'Mã PIN xác nhận không khớp'));
      return;
    }

    setPinLoading(true);
    try {
      await adminApi.changePin({
        password: pinForm.password,
        oldPin: pinForm.oldPin || undefined,
        newPin: pinForm.newPin,
      });
      alert?.success?.(
        t('settings.pinSection.successMessage', 'Cập nhật mã PIN bảo mật thành công!'),
        t('settings.pinSection.successTitle', 'Mã PIN Bảo Mật')
      );
      setPinForm({ password: '', oldPin: '', newPin: '', confirmPin: '' });
      setShowPinModal(false);
      setShowPinChange(false);
    } catch (err) {
      const msg = err.response?.data?.message || err.message || t('settings.pinSection.failMessage', 'Không thể đổi mã PIN');
      setPinError(msg);
    } finally {
      setPinLoading(false);
    }
  };

  // Xử lý Đổi Mật Khẩu
  const handleChangePassword = async (e) => {
    e?.preventDefault?.();
    setPasswordError('');
    if (!passwordForm.oldPassword) {
      setPasswordError(t('settings.passwordSection.requireOldPassword', 'Vui lòng nhập mật khẩu hiện tại'));
      return;
    }
    if (!passwordForm.pin || !/^\d{6}$/.test(passwordForm.pin)) {
      setPasswordError(t('settings.passwordSection.requirePin', 'Vui lòng nhập mã PIN bảo mật cũ (6 chữ số)'));
      return;
    }
    if (!passwordForm.newPassword || passwordForm.newPassword.length < 6) {
      setPasswordError(t('settings.passwordSection.invalidPassword', 'Mật khẩu mới phải có ít nhất 6 ký tự'));
      return;
    }
    if (passwordForm.newPassword === passwordForm.oldPassword) {
      setPasswordError(t('settings.passwordSection.samePassword', 'Mật khẩu mới không được trùng với mật khẩu hiện tại'));
      return;
    }
    if (passwordForm.newPassword !== passwordForm.confirmPassword) {
      setPasswordError(t('settings.passwordSection.mismatchPassword', 'Mật khẩu mới xác nhận không khớp'));
      return;
    }

    setPasswordLoading(true);
    try {
      await adminApi.changePassword({
        oldPassword: passwordForm.oldPassword,
        pin: passwordForm.pin,
        newPassword: passwordForm.newPassword,
      });
      alert?.success?.(
        t('settings.passwordSection.successMessage', 'Cập nhật mật khẩu quản trị thành công!'),
        t('settings.passwordSection.successTitle', 'Đổi Mật Khẩu')
      );
      setPasswordForm({ oldPassword: '', pin: '', newPassword: '', confirmPassword: '' });
      setShowPasswordModal(false);
    } catch (err) {
      const msg = err.response?.data?.message || err.message || t('settings.passwordSection.failMessage', 'Không thể đổi mật khẩu');
      setPasswordError(msg);
    } finally {
      setPasswordLoading(false);
    }
  };

  // Xử lý Cấp Tài Khoản Admin - Bước 1
  const handleNextCreateAdminStep = (e) => {
    e?.preventDefault?.();
    setCreateAdminError('');
    const fullNameTrimmed = createAdminForm.fullName?.trim();
    const usernameTrimmed = createAdminForm.username?.trim();
    const emailTrimmed = createAdminForm.email?.trim();
    const phoneClean = createAdminForm.phone?.trim().replace(/[\s.-]/g, '');

    if (!fullNameTrimmed || fullNameTrimmed.length < 2) {
      setCreateAdminError(t('settings.createAdmin.requireFullName', 'Họ và tên quản trị viên phải có ít nhất 2 ký tự'));
      return;
    }

    if (!usernameTrimmed || usernameTrimmed.length < 3) {
      setCreateAdminError(t('settings.createAdmin.requireUsername', 'Tên đăng nhập admin phải có ít nhất 3 ký tự'));
      return;
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailTrimmed || !emailRegex.test(emailTrimmed)) {
      setCreateAdminError(t('settings.createAdmin.requireEmail', 'Email không đúng định dạng'));
      return;
    }

    if (!phoneClean) {
      setCreateAdminError(t('settings.createAdmin.requirePhone', 'Vui lòng nhập số điện thoại quản trị viên'));
      return;
    }

    if (!/^\+?[0-9]{8,15}$/.test(phoneClean)) {
      setCreateAdminError(t('settings.createAdmin.invalidPhone', 'Số điện thoại không đúng định dạng (từ 8 đến 15 chữ số)'));
      return;
    }

    setCreateAdminStep(2);
  };

  // Xử lý Cấp Tài Khoản Admin - Bước 2 (Xác thực PIN & Tạo)
  const handleConfirmCreateAdmin = async (e) => {
    e?.preventDefault?.();
    setCreateAdminError('');
    if (!createAdminForm.pin || !/^\d{6}$/.test(createAdminForm.pin)) {
      setCreateAdminError(t('settings.createAdmin.requirePin', 'Vui lòng nhập mã PIN bảo mật của bạn (6 chữ số)'));
      return;
    }

    setCreateAdminLoading(true);
    try {
      const payload = {
        fullName: createAdminForm.fullName.trim(),
        username: createAdminForm.username.trim(),
        email: createAdminForm.email.trim(),
        phone: createAdminForm.phone.trim().replace(/[\s.-]/g, ''),
        address: createAdminForm.address?.trim() || null,
        countryCode: (createAdminForm.countryCode || '+84').trim().slice(0, 4),
        pin: createAdminForm.pin,
      };

      const res = await adminApi.createAdmin(payload);
      setCreatedAdminResult(res.data?.data || payload);
      setCreateAdminStep(3);
      alert?.success?.(
        t('settings.createAdmin.successMessage', 'Cấp tài khoản Admin mới thành công!'),
        t('settings.createAdmin.successTitle', 'Cấp Tài Khoản')
      );
    } catch (err) {
      const msg = err.response?.data?.message || err.message || t('settings.createAdmin.failMessage', 'Không thể cấp tài khoản admin');
      setCreateAdminError(msg);
    } finally {
      setCreateAdminLoading(false);
    }
  };

  // Đóng modal cấp admin và reset
  const handleCloseCreateAdminModal = () => {
    setShowCreateAdminModal(false);
    setCreateAdminStep(1);
    setCreateAdminForm({
      username: '',
      email: '',
      fullName: '',
      phone: '',
      address: '',
      countryCode: '+84',
      pin: '',
    });
    setCreateAdminError('');
    setCreatedAdminResult(null);
  };

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
        <div className="flex items-center gap-1 px-6 pt-3 border-b border-outline-variant bg-slate-50/50 overflow-x-auto">
          {[
            { id: 'general', label: t('settings.tabs.general', 'Giao Diện & Hiển Thị'), icon: 'palette' },
            { id: 'notifications', label: t('settings.tabs.notifications', 'Cảnh Báo & Âm Thanh'), icon: 'volume_up' },
            { id: 'realtime', label: t('settings.tabs.realtime', 'Thời Gian Thực & Socket'), icon: 'sync' },
            { id: 'system', label: t('settings.tabs.system', 'Bảo Mật & Thông Tin'), icon: 'shield' },
            { id: 'admin_mgmt', label: t('settings.tabs.adminMgmt', 'Quản Lý Admin'), icon: 'admin_panel_settings' },
          ].map((tab) => (
            <button
              key={tab.id}
              type="button"
              data-testid={`settings-tab-${tab.id}`}
              onClick={() => setActiveTab(tab.id)}
              className={`px-3.5 py-2 text-xs font-bold border-b-2 transition-all cursor-pointer flex items-center gap-1.5 whitespace-nowrap ${
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
              {/* Khối Quản lý Mã PIN Bảo Mật Admin */}
              <div className="p-4 rounded-xl border border-primary/20 bg-primary/5 space-y-3" data-testid="settings-pin-section">
                <div className="flex items-center justify-between">
                  <div>
                    <div className="font-bold text-slate-800 flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[18px] text-primary">pin</span>
                      <span>{t('settings.pinSection.title', 'Mã PIN Bảo Mật Admin')}</span>
                      <span className="text-[10px] font-mono font-bold px-1.5 py-0.2 bg-emerald-100 text-emerald-800 rounded border border-emerald-300">
                        {t('settings.pinSection.statusSecure', 'CSDL Bcrypt')}
                      </span>
                    </div>
                    <div className="text-[11px] text-slate-500 mt-0.5">
                      {t('settings.pinSection.desc', 'Mã PIN 6 số dùng xác thực các hành động nhạy cảm (Bảo trì khẩn cấp, thao tác dữ liệu,...).')}
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setShowPinChange(!showPinChange);
                      setPinError('');
                    }}
                    className="px-3.5 py-1.5 bg-white hover:bg-slate-50 border border-primary/30 text-primary font-bold rounded-xl transition cursor-pointer shadow-2xs flex items-center gap-1"
                  >
                    <span className="material-symbols-outlined text-[15px]">edit</span>
                    <span>{showPinChange ? t('common.cancel', 'Hủy') : t('settings.pinSection.changePinBtn', 'Đổi mã PIN')}</span>
                  </button>
                </div>

                {showPinChange && (
                  <form onSubmit={handleChangePin} className="mt-3 p-3 bg-white rounded-xl border border-outline-variant space-y-3 animate-in fade-in duration-150">
                    {pinError && (
                      <div className="p-2 text-[11px] bg-rose-50 border border-rose-200 text-rose-700 rounded-lg flex items-center gap-1.5">
                        <span className="material-symbols-outlined text-[15px] shrink-0">error</span>
                        <span>{pinError}</span>
                      </div>
                    )}
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                      <div>
                        <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                          {t('settings.pinSection.passwordLabel', 'Mật khẩu hiện tại *')}
                        </label>
                        <input
                          type="password"
                          value={pinForm.password}
                          onChange={(e) => setPinForm({ ...pinForm, password: e.target.value })}
                          placeholder="••••••••"
                          className="w-full px-3 py-1.5 text-xs bg-slate-50 border border-slate-200 rounded-lg focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary"
                          required
                        />
                      </div>
                      <div>
                        <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                          {t('settings.pinSection.oldPinLabel', 'Mã PIN cũ (Nếu có)')}
                        </label>
                        <input
                          type="password"
                          inputMode="numeric"
                          pattern="[0-9]*"
                          maxLength={6}
                          value={pinForm.oldPin}
                          onChange={(e) => setPinForm({ ...pinForm, oldPin: e.target.value.replace(/\D/g, '').slice(0, 6) })}
                          placeholder="6 chữ số cũ"
                          className="w-full px-3 py-1.5 text-xs bg-slate-50 border border-slate-200 rounded-lg focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary font-mono tracking-widest"
                        />
                      </div>
                    </div>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                      <div>
                        <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                          {t('settings.pinSection.newPinLabel', 'Mã PIN mới (6 chữ số) *')}
                        </label>
                        <input
                          type="password"
                          inputMode="numeric"
                          pattern="[0-9]*"
                          maxLength={6}
                          value={pinForm.newPin}
                          onChange={(e) => setPinForm({ ...pinForm, newPin: e.target.value.replace(/\D/g, '').slice(0, 6) })}
                          placeholder="6 chữ số mới"
                          className="w-full px-3 py-1.5 text-xs bg-slate-50 border border-slate-200 rounded-lg focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary font-mono tracking-widest"
                          required
                        />
                      </div>
                      <div>
                        <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                          {t('settings.pinSection.confirmPinLabel', 'Xác nhận mã PIN mới *')}
                        </label>
                        <input
                          type="password"
                          inputMode="numeric"
                          pattern="[0-9]*"
                          maxLength={6}
                          value={pinForm.confirmPin}
                          onChange={(e) => setPinForm({ ...pinForm, confirmPin: e.target.value.replace(/\D/g, '').slice(0, 6) })}
                          placeholder="Nhập lại 6 số"
                          className="w-full px-3 py-1.5 text-xs bg-slate-50 border border-slate-200 rounded-lg focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary font-mono tracking-widest"
                          required
                        />
                      </div>
                    </div>
                    <div className="flex justify-end gap-2 pt-1">
                      <button
                        type="button"
                        onClick={() => setShowPinChange(false)}
                        className="px-3 py-1.5 text-xs text-slate-600 hover:bg-slate-100 rounded-lg transition cursor-pointer"
                      >
                        {t('common.cancel', 'Hủy')}
                      </button>
                      <button
                        type="submit"
                        disabled={pinLoading}
                        className="px-4 py-1.5 bg-primary hover:bg-primary/90 text-white font-bold rounded-lg text-xs shadow-2xs transition cursor-pointer flex items-center gap-1.5 disabled:opacity-50"
                      >
                        {pinLoading && <span className="material-symbols-outlined animate-spin text-[14px]">progress_activity</span>}
                        <span>{t('settings.pinSection.submitBtn', 'Lưu mã PIN mới')}</span>
                      </button>
                    </div>
                  </form>
                )}
              </div>

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

          {/* TAB 5: Quản Lý Admin */}
          {activeTab === 'admin_mgmt' && (
            <div className="space-y-4" data-testid="settings-admin-mgmt-section">
              {/* Card thông tin Admin đang đăng nhập */}
              <div className="p-4 rounded-xl border border-primary/20 bg-primary/5 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-primary text-white font-bold flex items-center justify-center text-sm shadow-2xs">
                    {user?.Username?.[0]?.toUpperCase() || 'A'}
                  </div>
                  <div>
                    <div className="font-bold text-slate-900 text-xs flex items-center gap-2">
                      <span>{user?.Username || 'Admin'}</span>
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-primary/10 text-primary border border-primary/20">
                        {user?.Role || 'Admin'}
                      </span>
                    </div>
                    <div className="text-[11px] text-slate-500 mt-0.5">
                      {user?.Email || 'admin@managementfinance.com'}
                    </div>
                  </div>
                </div>
                <div className="text-right">
                  <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded-lg border border-emerald-200">
                    <span className="w-2 h-2 rounded-full bg-emerald-500"></span>
                    <span>Đang hoạt động</span>
                  </span>
                </div>
              </div>

              {/* 3 Thẻ tính năng: Đổi PIN, Đổi Mật Khẩu, Cấp Admin */}
              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                {/* Tính năng 1: Đổi mã PIN */}
                <div className="p-4 rounded-xl border border-slate-200 bg-white hover:border-amber-400 hover:shadow-2xs transition flex flex-col justify-between">
                  <div className="space-y-2">
                    <div className="w-9 h-9 rounded-lg bg-amber-50 text-amber-600 flex items-center justify-center">
                      <span className="material-symbols-outlined text-[20px]">pin</span>
                    </div>
                    <div>
                      <h4 className="font-bold text-slate-800 text-xs">Đổi Mã PIN</h4>
                      <p className="text-[11px] text-slate-500 mt-1 leading-relaxed">
                        Cập nhật mã PIN 6 số dùng để xác thực các tác vụ nhạy cảm của hệ thống.
                      </p>
                    </div>
                  </div>
                  <button
                    type="button"
                    data-testid="open-change-pin-btn"
                    onClick={() => {
                      setPinError('');
                      setPinForm({ password: '', oldPin: '', newPin: '', confirmPin: '' });
                      setShowPinModal(true);
                    }}
                    className="mt-4 w-full py-2 px-3 bg-amber-500 hover:bg-amber-600 text-white font-bold rounded-lg text-xs transition cursor-pointer flex items-center justify-center gap-1.5 shadow-2xs"
                  >
                    <span className="material-symbols-outlined text-[15px]">edit</span>
                    <span>Đổi mã PIN</span>
                  </button>
                </div>

                {/* Tính năng 2: Đổi Mật Khẩu */}
                <div className="p-4 rounded-xl border border-slate-200 bg-white hover:border-primary/40 hover:shadow-2xs transition flex flex-col justify-between">
                  <div className="space-y-2">
                    <div className="w-9 h-9 rounded-lg bg-blue-50 text-blue-600 flex items-center justify-center">
                      <span className="material-symbols-outlined text-[20px]">key</span>
                    </div>
                    <div>
                      <h4 className="font-bold text-slate-800 text-xs">Đổi Mật Khẩu</h4>
                      <p className="text-[11px] text-slate-500 mt-1 leading-relaxed">
                        Cập nhật mật khẩu tài khoản Admin với xác thực mật khẩu hiện tại và mã PIN.
                      </p>
                    </div>
                  </div>
                  <button
                    type="button"
                    data-testid="open-change-password-btn"
                    onClick={() => {
                      setPasswordError('');
                      setPasswordForm({ oldPassword: '', pin: '', newPassword: '', confirmPassword: '' });
                      setShowPasswordModal(true);
                    }}
                    className="mt-4 w-full py-2 px-3 bg-primary hover:bg-primary/90 text-white font-bold rounded-lg text-xs transition cursor-pointer flex items-center justify-center gap-1.5 shadow-2xs"
                  >
                    <span className="material-symbols-outlined text-[15px]">lock_reset</span>
                    <span>Đổi mật khẩu</span>
                  </button>
                </div>

                {/* Tính năng 3: Cấp Tài Khoản Admin */}
                <div className="p-4 rounded-xl border border-slate-200 bg-white hover:border-emerald-500 hover:shadow-2xs transition flex flex-col justify-between">
                  <div className="space-y-2">
                    <div className="w-9 h-9 rounded-lg bg-emerald-50 text-emerald-600 flex items-center justify-center">
                      <span className="material-symbols-outlined text-[20px]">person_add</span>
                    </div>
                    <div>
                      <h4 className="font-bold text-slate-800 text-xs">Cấp Tài Khoản</h4>
                      <p className="text-[11px] text-slate-500 mt-1 leading-relaxed">
                        Cấp tài khoản Admin mới cho đồng nghiệp với mật khẩu & PIN khởi tạo 123456.
                      </p>
                    </div>
                  </div>
                  <button
                    type="button"
                    data-testid="open-create-admin-btn"
                    onClick={() => {
                      setCreateAdminError('');
                      setCreateAdminStep(1);
                      setCreateAdminForm({
                        username: '',
                        email: '',
                        fullName: '',
                        phone: '',
                        address: '',
                        countryCode: '+84',
                        pin: '',
                      });
                      setCreatedAdminResult(null);
                      setShowCreateAdminModal(true);
                    }}
                    className="mt-4 w-full py-2 px-3 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-lg text-xs transition cursor-pointer flex items-center justify-center gap-1.5 shadow-2xs"
                  >
                    <span className="material-symbols-outlined text-[15px]">add_moderator</span>
                    <span>Cấp Admin mới</span>
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* ==================== SUB-MODAL 1: ĐỔI MÃ PIN ==================== */}
        {showPinModal && (
          <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs animate-in fade-in duration-150">
            <div className="bg-white rounded-2xl border border-outline-variant max-w-md w-full shadow-2xl overflow-hidden animate-in zoom-in-95 duration-150">
              <div className="px-5 py-4 border-b border-outline-variant flex items-center justify-between bg-surface-bright">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-lg bg-amber-50 text-amber-600 flex items-center justify-center">
                    <span className="material-symbols-outlined text-[18px]">pin</span>
                  </div>
                  <h4 className="text-sm font-bold text-on-surface m-0">Đổi Mã PIN Bảo Mật</h4>
                </div>
                <button
                  type="button"
                  onClick={() => setShowPinModal(false)}
                  className="w-7 h-7 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-600 flex items-center justify-center cursor-pointer"
                >
                  <span className="material-symbols-outlined text-[18px]">close</span>
                </button>
              </div>

              <form onSubmit={handleChangePin} className="p-5 space-y-3.5">
                {pinError && (
                  <div className="p-2.5 text-xs bg-rose-50 border border-rose-200 text-rose-700 rounded-xl flex items-center gap-2">
                    <span className="material-symbols-outlined text-[16px] shrink-0">error</span>
                    <span>{pinError}</span>
                  </div>
                )}

                <div>
                  <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                    Mật khẩu tài khoản hiện tại <span className="text-rose-500">*</span>
                  </label>
                  <input
                    type="password"
                    data-testid="pin-input-password"
                    value={pinForm.password}
                    onChange={(e) => setPinForm({ ...pinForm, password: e.target.value })}
                    placeholder="••••••••"
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary"
                    required
                  />
                </div>

                <div>
                  <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                    Mã PIN cũ (6 chữ số) <span className="text-rose-500">*</span>
                  </label>
                  <input
                    type="password"
                    inputMode="numeric"
                    pattern="[0-9]*"
                    maxLength={6}
                    data-testid="pin-input-old"
                    value={pinForm.oldPin}
                    onChange={(e) => setPinForm({ ...pinForm, oldPin: e.target.value.replace(/\D/g, '').slice(0, 6) })}
                    placeholder="6 chữ số cũ"
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary font-mono tracking-widest"
                    required
                  />
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                      Mã PIN mới <span className="text-rose-500">*</span>
                    </label>
                    <input
                      type="password"
                      inputMode="numeric"
                      pattern="[0-9]*"
                      maxLength={6}
                      data-testid="pin-input-new"
                      value={pinForm.newPin}
                      onChange={(e) => setPinForm({ ...pinForm, newPin: e.target.value.replace(/\D/g, '').slice(0, 6) })}
                      placeholder="6 chữ số"
                      className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary font-mono tracking-widest"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                      Xác nhận PIN mới <span className="text-rose-500">*</span>
                    </label>
                    <input
                      type="password"
                      inputMode="numeric"
                      pattern="[0-9]*"
                      maxLength={6}
                      data-testid="pin-input-confirm"
                      value={pinForm.confirmPin}
                      onChange={(e) => setPinForm({ ...pinForm, confirmPin: e.target.value.replace(/\D/g, '').slice(0, 6) })}
                      placeholder="Nhập lại 6 số"
                      className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary font-mono tracking-widest"
                      required
                    />
                  </div>
                </div>

                <div className="flex justify-end gap-2 pt-2 border-t border-slate-100">
                  <button
                    type="button"
                    onClick={() => setShowPinModal(false)}
                    className="px-4 py-2 text-xs text-slate-600 hover:bg-slate-100 rounded-xl transition cursor-pointer font-semibold"
                  >
                    Hủy
                  </button>
                  <button
                    type="submit"
                    data-testid="submit-change-pin-btn"
                    disabled={pinLoading}
                    className="px-5 py-2 bg-amber-500 hover:bg-amber-600 text-white font-bold rounded-xl text-xs shadow-2xs transition cursor-pointer flex items-center gap-1.5 disabled:opacity-50"
                  >
                    {pinLoading && <span className="material-symbols-outlined animate-spin text-[14px]">progress_activity</span>}
                    <span>Xác nhận đổi PIN</span>
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* ==================== SUB-MODAL 2: ĐỔI MẬT KHẨU ==================== */}
        {showPasswordModal && (
          <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs animate-in fade-in duration-150">
            <div className="bg-white rounded-2xl border border-outline-variant max-w-md w-full shadow-2xl overflow-hidden animate-in zoom-in-95 duration-150">
              <div className="px-5 py-4 border-b border-outline-variant flex items-center justify-between bg-surface-bright">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-lg bg-blue-50 text-blue-600 flex items-center justify-center">
                    <span className="material-symbols-outlined text-[18px]">key</span>
                  </div>
                  <h4 className="text-sm font-bold text-on-surface m-0">Đổi Mật Khẩu Đăng Nhập</h4>
                </div>
                <button
                  type="button"
                  onClick={() => setShowPasswordModal(false)}
                  className="w-7 h-7 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-600 flex items-center justify-center cursor-pointer"
                >
                  <span className="material-symbols-outlined text-[18px]">close</span>
                </button>
              </div>

              <form onSubmit={handleChangePassword} className="p-5 space-y-3.5">
                {passwordError && (
                  <div className="p-2.5 text-xs bg-rose-50 border border-rose-200 text-rose-700 rounded-xl flex items-center gap-2">
                    <span className="material-symbols-outlined text-[16px] shrink-0">error</span>
                    <span>{passwordError}</span>
                  </div>
                )}

                <div>
                  <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                    Mật khẩu hiện tại <span className="text-rose-500">*</span>
                  </label>
                  <input
                    type="password"
                    data-testid="password-input-old"
                    value={passwordForm.oldPassword}
                    onChange={(e) => setPasswordForm({ ...passwordForm, oldPassword: e.target.value })}
                    placeholder="••••••••"
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary"
                    required
                  />
                </div>

                <div>
                  <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                    Mã PIN bảo mật cũ (6 chữ số) <span className="text-rose-500">*</span>
                  </label>
                  <input
                    type="password"
                    inputMode="numeric"
                    pattern="[0-9]*"
                    maxLength={6}
                    data-testid="password-input-pin"
                    value={passwordForm.pin}
                    onChange={(e) => setPasswordForm({ ...passwordForm, pin: e.target.value.replace(/\D/g, '').slice(0, 6) })}
                    placeholder="Nhập mã PIN cũ của bạn"
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary font-mono tracking-widest"
                    required
                  />
                </div>

                <div>
                  <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                    Mật khẩu mới (tối thiểu 6 ký tự) <span className="text-rose-500">*</span>
                  </label>
                  <input
                    type="password"
                    data-testid="password-input-new"
                    value={passwordForm.newPassword}
                    onChange={(e) => setPasswordForm({ ...passwordForm, newPassword: e.target.value })}
                    placeholder="Mật khẩu mới an toàn"
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary"
                    required
                  />
                </div>

                <div>
                  <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                    Xác nhận mật khẩu mới <span className="text-rose-500">*</span>
                  </label>
                  <input
                    type="password"
                    data-testid="password-input-confirm"
                    value={passwordForm.confirmPassword}
                    onChange={(e) => setPasswordForm({ ...passwordForm, confirmPassword: e.target.value })}
                    placeholder="Nhập lại mật khẩu mới"
                    className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary"
                    required
                  />
                </div>

                <div className="flex justify-end gap-2 pt-2 border-t border-slate-100">
                  <button
                    type="button"
                    onClick={() => setShowPasswordModal(false)}
                    className="px-4 py-2 text-xs text-slate-600 hover:bg-slate-100 rounded-xl transition cursor-pointer font-semibold"
                  >
                    Hủy
                  </button>
                  <button
                    type="submit"
                    data-testid="submit-change-password-btn"
                    disabled={passwordLoading}
                    className="px-5 py-2 bg-primary hover:bg-primary/90 text-white font-bold rounded-xl text-xs shadow-2xs transition cursor-pointer flex items-center gap-1.5 disabled:opacity-50"
                  >
                    {passwordLoading && <span className="material-symbols-outlined animate-spin text-[14px]">progress_activity</span>}
                    <span>Xác nhận đổi mật khẩu</span>
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* ==================== SUB-MODAL 3: CẤP TÀI KHOẢN ADMIN ==================== */}
        {showCreateAdminModal && (
          <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs animate-in fade-in duration-150">
            <div className="bg-white rounded-2xl border border-outline-variant max-w-lg w-full shadow-2xl overflow-hidden animate-in zoom-in-95 duration-150">
              <div className="px-5 py-4 border-b border-outline-variant flex items-center justify-between bg-surface-bright">
                <div className="flex items-center gap-2.5">
                  <div className="w-8 h-8 rounded-lg bg-emerald-50 text-emerald-600 flex items-center justify-center">
                    <span className="material-symbols-outlined text-[18px]">person_add</span>
                  </div>
                  <div>
                    <h4 className="text-sm font-bold text-on-surface m-0">Cấp Tài Khoản Admin</h4>
                    <p className="text-[10px] text-slate-500 m-0">
                      {createAdminStep === 1 && 'Bước 1/2: Nhập thông tin quản trị viên'}
                      {createAdminStep === 2 && 'Bước 2/2: Xác thực mã PIN phê duyệt'}
                      {createAdminStep === 3 && 'Hoàn tất cấp tài khoản thành công'}
                    </p>
                  </div>
                </div>
                <button
                  type="button"
                  onClick={handleCloseCreateAdminModal}
                  className="w-7 h-7 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-600 flex items-center justify-center cursor-pointer"
                >
                  <span className="material-symbols-outlined text-[18px]">close</span>
                </button>
              </div>

              <div className="p-5">
                {createAdminError && (
                  <div className="mb-3.5 p-2.5 text-xs bg-rose-50 border border-rose-200 text-rose-700 rounded-xl flex items-center gap-2">
                    <span className="material-symbols-outlined text-[16px] shrink-0">error</span>
                    <span>{createAdminError}</span>
                  </div>
                )}

                {/* BƯỚC 1: NHẬP THÔNG TIN QUẢN TRỊ VIÊN (FULLNAME, USERNAME, EMAIL, PHONE, COUNTRY CODE, ADDRESS) */}
                {createAdminStep === 1 && (
                  <form onSubmit={handleNextCreateAdminStep} noValidate className="space-y-3.5">
                    {/* HÀNG 1: FULLNAME & USERNAME (GRID 2 CỘT) */}
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <div>
                        <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                          {t('settings.createAdmin.fullNameLabel', 'Họ và tên quản trị viên')} <span className="text-rose-500">*</span>
                        </label>
                        <input
                          type="text"
                          data-testid="create-admin-fullname"
                          value={createAdminForm.fullName}
                          onChange={(e) => setCreateAdminForm({ ...createAdminForm, fullName: e.target.value })}
                          placeholder={t('settings.createAdmin.fullNamePlaceholder', 'VD: Nguyễn Văn Quản Trị')}
                          className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary"
                          required
                          autoFocus
                        />
                      </div>

                      <div>
                        <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                          {t('settings.createAdmin.usernameLabel', 'Tên đăng nhập Admin mới')} <span className="text-rose-500">*</span>
                        </label>
                        <input
                          type="text"
                          data-testid="create-admin-username"
                          value={createAdminForm.username}
                          onChange={(e) => setCreateAdminForm({ ...createAdminForm, username: e.target.value })}
                          placeholder={t('settings.createAdmin.usernamePlaceholder', 'VD: admin_finance_2')}
                          className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary"
                          required
                        />
                      </div>
                    </div>

                    {/* HÀNG 2: EMAIL QUẢN TRỊ VIÊN */}
                    <div>
                      <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                        {t('settings.createAdmin.emailLabel', 'Email quản trị viên')} <span className="text-rose-500">*</span>
                      </label>
                      <input
                        type="email"
                        data-testid="create-admin-email"
                        value={createAdminForm.email}
                        onChange={(e) => setCreateAdminForm({ ...createAdminForm, email: e.target.value })}
                        placeholder={t('settings.createAdmin.emailPlaceholder', 'admin2@domain.com')}
                        className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary"
                        required
                      />
                    </div>

                    {/* HÀNG 3: MÃ VÙNG / QUỐC GIA (1/3) & SỐ ĐIỆN THOẠI (2/3) */}
                    <div className="grid grid-cols-3 gap-3">
                      <div className="col-span-1">
                        <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                          {t('settings.createAdmin.countryCodeLabel', 'Mã vùng')}
                        </label>
                        <input
                          type="text"
                          maxLength={4}
                          data-testid="create-admin-country-code"
                          value={createAdminForm.countryCode}
                          onChange={(e) => setCreateAdminForm({ ...createAdminForm, countryCode: e.target.value.slice(0, 4) })}
                          placeholder={t('settings.createAdmin.countryCodePlaceholder', '+84')}
                          className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary font-mono text-center"
                        />
                      </div>

                      <div className="col-span-2">
                        <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                          {t('settings.createAdmin.phoneLabel', 'Số điện thoại')} <span className="text-rose-500">*</span>
                        </label>
                        <input
                          type="tel"
                          data-testid="create-admin-phone"
                          value={createAdminForm.phone}
                          onChange={(e) => setCreateAdminForm({ ...createAdminForm, phone: e.target.value })}
                          placeholder={t('settings.createAdmin.phonePlaceholder', 'VD: 0912345678')}
                          className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary"
                          required
                        />
                      </div>
                    </div>

                    {/* HÀNG 4: ĐỊA CHỈ LIÊN HỆ */}
                    <div>
                      <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                        {t('settings.createAdmin.addressLabel', 'Địa chỉ liên hệ')}
                      </label>
                      <input
                        type="text"
                        data-testid="create-admin-address"
                        value={createAdminForm.address}
                        onChange={(e) => setCreateAdminForm({ ...createAdminForm, address: e.target.value })}
                        placeholder={t('settings.createAdmin.addressPlaceholder', 'VD: 123 Nguyễn Huệ, Quận 1, TP.HCM')}
                        className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary"
                      />
                    </div>

                    <div className="p-3 bg-amber-50 rounded-xl border border-amber-200/60 text-[11px] text-amber-800 flex gap-2">
                      <span className="material-symbols-outlined text-[16px] text-amber-600 shrink-0 mt-0.5">info</span>
                      <div>
                        Tài khoản mới sẽ được khởi tạo với mật khẩu mặc định là <strong className="font-mono">123456</strong> và mã PIN mặc định là <strong className="font-mono">123456</strong>.
                      </div>
                    </div>

                    <div className="flex justify-end gap-2 pt-2 border-t border-slate-100">
                      <button
                        type="button"
                        onClick={handleCloseCreateAdminModal}
                        className="px-4 py-2 text-xs text-slate-600 hover:bg-slate-100 rounded-xl transition cursor-pointer font-semibold"
                      >
                        Hủy
                      </button>
                      <button
                        type="submit"
                        data-testid="btn-next-create-admin"
                        className="px-5 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-xl text-xs shadow-2xs transition cursor-pointer flex items-center gap-1.5"
                      >
                        <span>Xác nhận thông tin</span>
                        <span className="material-symbols-outlined text-[15px]">arrow_forward</span>
                      </button>
                    </div>
                  </form>
                )}

                {/* BƯỚC 2: XÁC THỰC MÃ PIN CỦA ADMIN HIỆN TẠI */}
                {createAdminStep === 2 && (
                  <form onSubmit={handleConfirmCreateAdmin} className="space-y-3.5">
                    <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-200 text-xs space-y-1.5">
                      <div className="font-semibold text-slate-700 pb-1 border-b border-slate-200/60">Thông tin cấp quyền quản trị:</div>
                      <div className="flex justify-between text-[11px]">
                        <span className="text-slate-500">Họ và tên:</span>
                        <strong className="text-slate-900">{createAdminForm.fullName}</strong>
                      </div>
                      <div className="flex justify-between text-[11px]">
                        <span className="text-slate-500">Tài khoản:</span>
                        <strong className="text-slate-900 font-mono">{createAdminForm.username}</strong>
                      </div>
                      <div className="flex justify-between text-[11px]">
                        <span className="text-slate-500">Email:</span>
                        <strong className="text-slate-900">{createAdminForm.email}</strong>
                      </div>
                      <div className="flex justify-between text-[11px]">
                        <span className="text-slate-500">Số điện thoại:</span>
                        <strong className="text-slate-900 font-mono">{(createAdminForm.countryCode || '+84')} {createAdminForm.phone}</strong>
                      </div>
                      {createAdminForm.address && (
                        <div className="flex justify-between text-[11px]">
                          <span className="text-slate-500">Địa chỉ:</span>
                          <strong className="text-slate-900">{createAdminForm.address}</strong>
                        </div>
                      )}
                    </div>

                    <div>
                      <label className="block text-[11px] font-semibold text-slate-700 mb-1">
                        Nhập mã PIN bảo mật của bạn để phê duyệt <span className="text-rose-500">*</span>
                      </label>
                      <input
                        type="password"
                        inputMode="numeric"
                        pattern="[0-9]*"
                        maxLength={6}
                        data-testid="create-admin-pin-auth"
                        value={createAdminForm.pin}
                        onChange={(e) => setCreateAdminForm({ ...createAdminForm, pin: e.target.value.replace(/\D/g, '').slice(0, 6) })}
                        placeholder="6 chữ số PIN của bạn"
                        className="w-full px-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-1 focus:ring-primary font-mono tracking-widest text-center text-sm"
                        required
                        autoFocus
                      />
                      <div className="text-[10px] text-slate-400 mt-1 text-center">
                        Xác thực danh tính người cấp tài khoản theo quy định bảo mật
                      </div>
                    </div>

                    <div className="flex justify-between gap-2 pt-2 border-t border-slate-100">
                      <button
                        type="button"
                        onClick={() => setCreateAdminStep(1)}
                        className="px-4 py-2 text-xs text-slate-600 hover:bg-slate-100 rounded-xl transition cursor-pointer font-semibold flex items-center gap-1"
                      >
                        <span className="material-symbols-outlined text-[15px]">arrow_back</span>
                        <span>Quay lại</span>
                      </button>
                      <button
                        type="submit"
                        data-testid="submit-create-admin-btn"
                        disabled={createAdminLoading}
                        className="px-5 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-xl text-xs shadow-2xs transition cursor-pointer flex items-center gap-1.5 disabled:opacity-50"
                      >
                        {createAdminLoading && <span className="material-symbols-outlined animate-spin text-[14px]">progress_activity</span>}
                        <span>Xác nhận cấp tài khoản</span>
                      </button>
                    </div>
                  </form>
                )}

                {/* BƯỚC 3: THÀNH CÔNG VÀ HIỂN THỊ KẾT QUẢ */}
                {createAdminStep === 3 && createdAdminResult && (
                  <div className="space-y-4 animate-in zoom-in-95 duration-150">
                    <div className="text-center py-2">
                      <div className="w-12 h-12 bg-emerald-100 text-emerald-600 rounded-full flex items-center justify-center mx-auto mb-2">
                        <span className="material-symbols-outlined text-[28px]">check_circle</span>
                      </div>
                      <h4 className="text-sm font-bold text-slate-900 m-0">Cấp Tài Khoản Admin Thành Công!</h4>
                      <p className="text-[11px] text-slate-500 mt-0.5">
                        Tài khoản quản trị viên mới đã được lưu vào hệ thống CSDL.
                      </p>
                    </div>

                    <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-200 text-xs space-y-2">
                      <div className="flex justify-between pb-1 border-b border-slate-200/60">
                        <span className="text-slate-500">Họ và tên:</span>
                        <strong className="text-slate-900">{createdAdminResult.fullname || createdAdminResult.fullName || createAdminForm.fullName}</strong>
                      </div>
                      <div className="flex justify-between pb-1 border-b border-slate-200/60">
                        <span className="text-slate-500">Tên đăng nhập:</span>
                        <strong className="font-mono text-slate-900">{createdAdminResult.username}</strong>
                      </div>
                      <div className="flex justify-between pb-1 border-b border-slate-200/60">
                        <span className="text-slate-500">Email:</span>
                        <strong className="text-slate-900">{createdAdminResult.email}</strong>
                      </div>
                      <div className="flex justify-between pb-1 border-b border-slate-200/60">
                        <span className="text-slate-500">Số điện thoại:</span>
                        <strong className="font-mono text-slate-900">
                          {(createdAdminResult.country_code || createdAdminResult.countryCode || createAdminForm.countryCode || '+84')}{' '}
                          {createdAdminResult.phone || createAdminForm.phone}
                        </strong>
                      </div>
                      <div className="flex justify-between pb-1 border-b border-slate-200/60">
                        <span className="text-slate-500">Mật khẩu khởi đầu:</span>
                        <span className="font-mono font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded border border-emerald-200">123456</span>
                      </div>
                      <div className="flex justify-between pb-1 border-b border-slate-200/60">
                        <span className="text-slate-500">Mã PIN khởi đầu:</span>
                        <span className="font-mono font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded border border-emerald-200">123456</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-slate-500">Trạng thái bảo mật:</span>
                        <span className="font-semibold text-amber-700 bg-amber-50 px-2 py-0.5 rounded text-[10px] border border-amber-200">
                          Bắt buộc đổi khi đăng nhập lần đầu
                        </span>
                      </div>
                    </div>

                    <div className="flex justify-end pt-2 border-t border-slate-100">
                      <button
                        type="button"
                        data-testid="btn-finish-create-admin"
                        onClick={handleCloseCreateAdminModal}
                        className="w-full py-2 bg-primary hover:bg-primary/90 text-white font-bold rounded-xl text-xs shadow-2xs transition cursor-pointer"
                      >
                        Hoàn tất
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

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
