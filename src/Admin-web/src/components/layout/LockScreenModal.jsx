import React, { useState, useMemo } from 'react';
import { useSettingsSafe } from '../../store/settings.context';
import { useAuthContext } from '../../store/auth.context';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import { STORAGE_KEYS } from '../../utils/constants';

const LockScreenModal = () => {
  const settingsCtx = useSettingsSafe();
  const { user, logout, syncAuthSession } = useAuthContext();
  const alert = useAlertSafe();
  const { t } = useLanguageSafe();

  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  const lockedUser = useMemo(() => {
    try {
      if (typeof localStorage === 'undefined') return null;
      const raw = localStorage.getItem(STORAGE_KEYS.LOCKED_USER) || localStorage.getItem(STORAGE_KEYS.USER);
      return raw ? JSON.parse(raw) : null;
    } catch (_) {
      return null;
    }
  }, [settingsCtx?.isLocked]);

  const activeUser = user || lockedUser;
  const displayUsername = activeUser?.username || '';
  const displayEmail = activeUser?.email || '';

  if (!settingsCtx?.isLocked) return null;

  const handleUnlock = async (e) => {
    e.preventDefault();
    if (!password.trim()) {
      setError(t('lockScreen.errorPasswordRequired', 'Vui lòng nhập mật khẩu tài khoản quản trị'));
      return;
    }

    setError('');
    setLoading(true);

    try {
      const sessionData = await settingsCtx.unlockScreen(password, syncAuthSession);
      if (syncAuthSession && sessionData) {
        syncAuthSession(sessionData);
      }
      setPassword('');
      alert?.success?.(
        t('lockScreen.welcomeBack', { name: activeUser?.fullname || activeUser?.username || 'Admin' }),
        t('lockScreen.unlockSuccess', 'Mở Khóa Thành Công')
      );
    } catch (err) {
      const msg = err.response?.data?.message || err.message || t('lockScreen.errorWrongPass', 'Mật khẩu không chính xác. Vui lòng thử lại.');
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    if (window.confirm(t('lockScreen.confirmLogout', 'Bạn có chắc chắn muốn đăng xuất hoàn toàn khỏi phiên quản trị?'))) {
      try {
        localStorage.removeItem(STORAGE_KEYS.IS_LOCKED);
        localStorage.removeItem(STORAGE_KEYS.LOCKED_AT);
        localStorage.removeItem(STORAGE_KEYS.LOCKED_USER);
        localStorage.removeItem(STORAGE_KEYS.ACCESS_TOKEN);
        localStorage.removeItem(STORAGE_KEYS.REFRESH_TOKEN);
        localStorage.removeItem(STORAGE_KEYS.USER);
      } catch (_) {}
      await logout();
    }
  };

  return (
    <div className="fixed inset-0 z-[9999] bg-slate-950/85 backdrop-blur-md flex items-center justify-center p-4 animate-in fade-in duration-300">
      <div className="bg-slate-900/95 border border-slate-700/80 rounded-3xl p-8 max-w-md w-full shadow-2xl text-center space-y-6 relative overflow-hidden">
        {/* Glow effect background */}
        <div className="absolute -top-24 -left-24 w-48 h-48 bg-emerald-500/10 rounded-full blur-3xl pointer-events-none" />
        <div className="absolute -bottom-24 -right-24 w-48 h-48 bg-primary/10 rounded-full blur-3xl pointer-events-none" />

        {/* Header Icon: Ổ khóa an ninh trung tâm trang trọng */}
        <div className="w-16 h-16 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center text-amber-400 shadow-lg mx-auto" title={t('lockScreen.lockedBadge', 'Màn hình đã bị khóa')}>
          <span className="material-symbols-outlined text-3xl font-bold">lock</span>
        </div>

        {/* User Info: Username + Email từ CSDL */}
        <div className="space-y-1">
          <h3 className="text-lg font-bold text-white tracking-tight">{displayUsername || t('lockScreen.defaultAdmin', 'Quản Trị Viên')}</h3>
          {displayEmail ? (
            <p className="text-xs text-slate-400 font-mono">{displayEmail}</p>
          ) : null}
          <div className="pt-2 flex items-center justify-center gap-1.5 text-[11px] text-amber-400 font-medium">
            <span className="w-1.5 h-1.5 rounded-full bg-amber-400 animate-pulse" />
            <span>
              {settingsCtx.lockedAt
                ? t('lockScreen.safeLockAt', { time: settingsCtx.lockedAt })
                : t('lockScreen.safeLockIdle', 'Tạm khóa an toàn khi nhàn rỗi')}
            </span>
          </div>
        </div>

        {/* Unlock Form */}
        <form onSubmit={handleUnlock} className="space-y-4 text-left">
          <div className="space-y-1.5">
            <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-300">
              {t('lockScreen.passwordLabel', 'Nhập mật khẩu quản trị viên để mở khóa:')}
            </label>
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => {
                  setPassword(e.target.value);
                  if (error) setError('');
                }}
                placeholder={t('lockScreen.placeholder', 'Mật khẩu quản trị viên...')}
                className={`w-full px-3.5 pr-10 py-2.5 bg-slate-800/90 border rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/40 transition-all ${
                  error ? 'border-rose-500 ring-1 ring-rose-500' : 'border-slate-700 focus:border-primary'
                }`}
                autoFocus
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white cursor-pointer"
              >
                <span className="material-symbols-outlined text-[18px]">
                  {showPassword ? 'visibility_off' : 'visibility'}
                </span>
              </button>
            </div>
            {error && (
              <p className="text-xs text-rose-400 font-medium flex items-center gap-1 mt-1">
                <span className="material-symbols-outlined text-sm">error</span>
                {error}
              </p>
            )}
          </div>

          {/* Action Buttons: Đăng xuất & Mở khóa màn hình cùng 1 hàng ngang */}
          <div className="flex items-center gap-3 pt-2">
            <button
              type="button"
              onClick={handleLogout}
              className="px-4 py-2.5 bg-slate-800 hover:bg-slate-700/80 border border-slate-700 text-rose-400 hover:text-rose-300 font-semibold rounded-xl text-xs transition-all flex items-center justify-center gap-1.5 cursor-pointer shadow-sm"
            >
              <span className="material-symbols-outlined text-[16px]">logout</span>
              {t('nav.logout', 'Đăng xuất')}
            </button>

            <button
              type="submit"
              disabled={loading}
              className="flex-1 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-xl text-xs transition-all shadow-lg flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? (
                <span className="material-symbols-outlined animate-spin text-sm">progress_activity</span>
              ) : (
                <span className="material-symbols-outlined text-[18px]">lock_open</span>
              )}
              {loading ? t('common.loading', 'Đang tải...') : t('lockScreen.unlockBtn', 'Mở Khóa Màn Hình')}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default LockScreenModal;
