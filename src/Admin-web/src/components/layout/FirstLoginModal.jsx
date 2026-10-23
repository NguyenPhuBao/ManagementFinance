import React, { useState, useEffect } from 'react';
import { useAuthContext } from '../../store/auth.context';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import adminApi from '../../api/admin.api';

const FirstLoginModal = () => {
  const { user, syncAuthSession } = useAuthContext();
  const alert = useAlertSafe();
  const { t } = useLanguageSafe();

  const [form, setForm] = useState({
    newPassword: '',
    confirmPassword: '',
    pin: '',
    confirmPin: '',
  });

  const [showPassword, setShowPassword] = useState(false);
  const [showPin, setShowPin] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Chặn phím Escape để không thể tắt modal
  useEffect(() => {
    if (!user?.is_first_login) return;
    const handleKeyDown = (e) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        e.stopPropagation();
      }
    };
    window.addEventListener('keydown', handleKeyDown, true);
    return () => window.removeEventListener('keydown', handleKeyDown, true);
  }, [user?.is_first_login]);

  // Chỉ hiển thị khi tài khoản admin có cờ is_first_login === true
  if (!user?.is_first_login) return null;

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    // 1. Validation mật khẩu mới
    if (!form.newPassword) {
      setError(t('firstLogin.errPassRequired', 'Vui lòng nhập mật khẩu mới'));
      return;
    }
    if (form.newPassword.length < 6) {
      setError(t('firstLogin.errPassMin', 'Mật khẩu mới phải có tối thiểu 6 ký tự'));
      return;
    }
    if (form.newPassword === '123456') {
      setError(t('firstLogin.errPassDefault', 'Mật khẩu mới không được trùng với mật khẩu mặc định (123456)'));
      return;
    }
    if (form.newPassword !== form.confirmPassword) {
      setError(t('firstLogin.errPassMismatch', 'Xác nhận mật khẩu mới không khớp'));
      return;
    }

    // 2. Validation mã PIN
    if (!form.pin || !/^\d{6}$/.test(form.pin.trim())) {
      setError(t('firstLogin.errPinInvalid', 'Mã PIN bảo mật phải bao gồm đúng 6 chữ số (0-9)'));
      return;
    }
    if (form.pin.trim() === '123456') {
      setError(t('firstLogin.errPinDefault', 'Mã PIN bảo mật không được là mã mặc định (123456)'));
      return;
    }
    if (form.pin.trim() !== form.confirmPin.trim()) {
      setError(t('firstLogin.errPinMismatch', 'Xác nhận mã PIN mới không khớp'));
      return;
    }

    setLoading(true);

    try {
      const res = await adminApi.firstLoginSetup({
        newPassword: form.newPassword,
        confirmPassword: form.confirmPassword,
        pin: form.pin.trim(),
        confirmPin: form.confirmPin.trim(),
      });

      const data = res?.data || res;
      const updatedUser = data?.user || { ...user, is_first_login: false };

      // Cập nhật session tại chỗ để tắt modal ngay mà không làm gián đoạn phiên làm việc
      if (syncAuthSession) {
        syncAuthSession({
          user: { ...updatedUser, is_first_login: false },
          accessToken: localStorage.getItem('wealthcommand_access_token'),
          refreshToken: localStorage.getItem('wealthcommand_refresh_token'),
        });
      }

      alert?.success?.(
        t('firstLogin.successMsg', 'Thiết lập mật khẩu và mã PIN bảo mật thành công! Chào mừng bạn đến với trang quản trị.'),
        t('firstLogin.successTitle', 'Kích Hoạt Tài Khoản Thành Công')
      );
    } catch (err) {
      const msg = err.response?.data?.message || err.message || t('firstLogin.failedMsg', 'Không thể hoàn tất thiết lập lần đầu');
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div 
      data-testid="first-login-modal-overlay"
      className="fixed inset-0 z-[99999] bg-slate-950/90 backdrop-blur-md flex items-center justify-center p-4 animate-in fade-in duration-300"
      onClick={(e) => e.stopPropagation()}
    >
      <div 
        className="bg-slate-900 border border-emerald-500/30 rounded-3xl p-6 sm:p-8 max-w-lg w-full shadow-2xl space-y-6 relative overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Glow hiệu ứng nền */}
        <div className="absolute -top-24 -left-24 w-48 h-48 bg-emerald-500/15 rounded-full blur-3xl pointer-events-none" />
        <div className="absolute -bottom-24 -right-24 w-48 h-48 bg-primary/20 rounded-full blur-3xl pointer-events-none" />

        {/* Header Modal */}
        <div className="text-center space-y-2">
          <div className="w-16 h-16 mx-auto rounded-2xl bg-gradient-to-br from-emerald-500/20 to-primary/20 border border-emerald-500/40 flex items-center justify-center text-emerald-400 shadow-lg">
            <span className="material-symbols-outlined text-[32px]">security</span>
          </div>
          <h2 className="text-xl font-bold text-white tracking-tight">
            {t('firstLogin.title', 'Thiết Lập Bảo Mật Quản Trị Viên')}
          </h2>
          <p className="text-xs text-slate-300 max-w-sm mx-auto leading-relaxed">
            {t('firstLogin.desc', 'Tài khoản của bạn đang sử dụng mật khẩu và mã PIN khởi đầu (123456). Vui lòng cập nhật mật khẩu mới và tạo mã PIN 6 số cá nhân để bảo vệ hệ thống.')}
          </p>
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-amber-500/10 border border-amber-500/30 text-[11px] text-amber-400 font-medium">
            <span className="w-1.5 h-1.5 rounded-full bg-amber-400 animate-pulse" />
            <span>{t('firstLogin.badgeRequired', 'Yêu cầu bắt buộc để tiếp tục làm việc')}</span>
          </div>
        </div>

        {/* Form Nhập liệu */}
        <form onSubmit={handleSubmit} className="space-y-4">
          {error && (
            <div className="p-3 rounded-xl bg-rose-950/60 border border-rose-500/50 text-rose-300 text-xs flex items-center gap-2">
              <span className="material-symbols-outlined text-rose-400 text-sm shrink-0">error</span>
              <span className="font-medium">{error}</span>
            </div>
          )}

          {/* Nhóm 1: Mật khẩu mới */}
          <div className="space-y-3 p-4 rounded-2xl bg-slate-800/50 border border-slate-700/60">
            <div className="flex items-center justify-between text-xs font-semibold text-emerald-400">
              <span className="flex items-center gap-1.5">
                <span className="material-symbols-outlined text-[16px]">key</span>
                {t('firstLogin.groupPassword', '1. Đổi Mật Khẩu Đăng Nhập')}
              </span>
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="text-[11px] text-slate-400 hover:text-white cursor-pointer"
              >
                {showPassword ? t('common.hide', 'Ẩn') : t('common.show', 'Hiện')}
              </button>
            </div>

            <div className="space-y-1">
              <label className="block text-[11px] font-medium text-slate-300">
                {t('firstLogin.labelNewPassword', 'Mật khẩu mới (Tối thiểu 6 ký tự):')}
              </label>
              <input
                type={showPassword ? 'text' : 'password'}
                data-testid="first-login-new-password"
                value={form.newPassword}
                onChange={(e) => setForm({ ...form, newPassword: e.target.value })}
                placeholder={t('firstLogin.placeholderNewPass', 'Nhập mật khẩu mới...')}
                className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-500 transition-all"
                autoComplete="new-password"
              />
            </div>

            <div className="space-y-1">
              <label className="block text-[11px] font-medium text-slate-300">
                {t('firstLogin.labelConfirmPassword', 'Xác nhận lại mật khẩu mới:')}
              </label>
              <input
                type={showPassword ? 'text' : 'password'}
                data-testid="first-login-confirm-password"
                value={form.confirmPassword}
                onChange={(e) => setForm({ ...form, confirmPassword: e.target.value })}
                placeholder={t('firstLogin.placeholderConfirmPass', 'Nhập lại mật khẩu mới...')}
                className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-500 transition-all"
                autoComplete="new-password"
              />
            </div>
          </div>

          {/* Nhóm 2: Mã PIN 6 số */}
          <div className="space-y-3 p-4 rounded-2xl bg-slate-800/50 border border-slate-700/60">
            <div className="flex items-center justify-between text-xs font-semibold text-emerald-400">
              <span className="flex items-center gap-1.5">
                <span className="material-symbols-outlined text-[16px]">pin</span>
                {t('firstLogin.groupPin', '2. Thiết Lập Mã PIN Bảo Mật (6 Chữ Số)')}
              </span>
              <button
                type="button"
                onClick={() => setShowPin(!showPin)}
                className="text-[11px] text-slate-400 hover:text-white cursor-pointer"
              >
                {showPin ? t('common.hide', 'Ẩn') : t('common.show', 'Hiện')}
              </button>
            </div>

            <div className="space-y-1">
              <label className="block text-[11px] font-medium text-slate-300">
                {t('firstLogin.labelPin', 'Mã PIN bảo mật mới (Đúng 6 số):')}
              </label>
              <input
                type={showPin ? 'text' : 'password'}
                data-testid="first-login-new-pin"
                maxLength={6}
                value={form.pin}
                onChange={(e) => setForm({ ...form, pin: e.target.value.replace(/\D/g, '') })}
                placeholder="******"
                className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-white placeholder-slate-500 tracking-widest font-mono text-center focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-500 transition-all"
              />
            </div>

            <div className="space-y-1">
              <label className="block text-[11px] font-medium text-slate-300">
                {t('firstLogin.labelConfirmPin', 'Xác nhận lại mã PIN bảo mật:')}
              </label>
              <input
                type={showPin ? 'text' : 'password'}
                data-testid="first-login-confirm-pin"
                maxLength={6}
                value={form.confirmPin}
                onChange={(e) => setForm({ ...form, confirmPin: e.target.value.replace(/\D/g, '') })}
                placeholder="******"
                className="w-full px-3 py-2 bg-slate-900 border border-slate-700 rounded-xl text-xs text-white placeholder-slate-500 tracking-widest font-mono text-center focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:border-emerald-500 transition-all"
              />
            </div>
          </div>

          {/* Nút Xác nhận */}
          <button
            type="submit"
            data-testid="first-login-submit-btn"
            disabled={loading}
            className="w-full py-3 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-xl text-xs transition-all shadow-lg flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? (
              <span className="material-symbols-outlined animate-spin text-sm">progress_activity</span>
            ) : (
              <span className="material-symbols-outlined text-[18px]">verified_user</span>
            )}
            {loading ? t('common.loading', 'Đang cập nhật...') : t('firstLogin.btnSubmit', 'Xác Nhận & Kích Hoạt Tài Khoản')}
          </button>
        </form>

        <p className="text-[11px] text-slate-500 text-center">
          {t('firstLogin.footerNote', 'Hệ thống sẽ cập nhật dữ liệu ngay lập tức và giữ nguyên phiên làm việc của bạn.')}
        </p>
      </div>
    </div>
  );
};

export default FirstLoginModal;
