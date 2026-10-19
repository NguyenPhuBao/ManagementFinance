import React, { useState, useEffect } from 'react';
import adminApi from '../../api/admin.api';

const SecurityConfirmModal = ({
  isOpen,
  onClose,
  onConfirm,
  title = 'Xác thực hành động bảo mật',
  description = 'Hành động này có tác động nghiêm trọng đến hệ thống. Vui lòng nhập mã PIN bảo mật để xác nhận.',
  actionType = 'CRITICAL_ACTION',
  targetLabel = '',
  dangerLevel = 'danger', // 'danger' | 'critical'
}) => {
  const [pin, setPin] = useState('');
  const [password, setPassword] = useState('');
  const [mode, setMode] = useState('pin'); // 'pin' | 'password'
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showPassword, setShowPassword] = useState(false);

  useEffect(() => {
    if (isOpen) {
      setPin('');
      setPassword('');
      setError('');
      setLoading(false);
      setMode('pin');
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const isSubmitDisabled =
    loading ||
    (mode === 'pin' && pin.trim().length < 6) ||
    (mode === 'password' && !password.trim());

  const handlePinChange = (e) => {
    const val = e.target.value.replace(/\D/g, '').slice(0, 6);
    setPin(val);
    if (error) setError('');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (isSubmitDisabled) return;

    setLoading(true);
    setError('');

    try {
      await adminApi.verifySecurityAction({
        pin: mode === 'pin' ? pin.trim() : '',
        password: mode === 'password' ? password : '',
        action: actionType,
        targetId: targetLabel,
      });

      if (typeof onConfirm === 'function') {
        await onConfirm();
      }
      onClose();
    } catch (err) {
      const msg =
        err?.response?.data?.message ||
        err?.message ||
        'Xác thực thất bại. Vui lòng kiểm tra lại mã PIN hoặc mật khẩu.';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-4 animate-in fade-in duration-200"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-2xl max-w-md w-full shadow-2xl border border-slate-200 overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="p-5 border-b border-slate-100 flex items-start gap-3 bg-slate-50/60">
          <div
            className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${
              dangerLevel === 'critical'
                ? 'bg-rose-100 text-rose-700 border border-rose-200'
                : 'bg-amber-100 text-amber-800 border border-amber-200'
            }`}
          >
            <span className="material-symbols-outlined text-2xl">
              {dangerLevel === 'critical' ? 'emergency_home' : 'verified_user'}
            </span>
          </div>
          <div className="flex-1">
            <h3 className="text-base font-bold text-slate-900 m-0 leading-tight">
              {title}
            </h3>
            {targetLabel && (
              <span className="inline-block mt-1 px-2 py-0.5 bg-slate-200/70 text-slate-800 font-mono text-[11px] font-semibold rounded">
                {targetLabel}
              </span>
            )}
          </div>
          <button
            type="button"
            onClick={onClose}
            className="text-slate-400 hover:text-slate-600 p-1 rounded-lg transition hover:bg-slate-200/50 cursor-pointer"
          >
            <span className="material-symbols-outlined text-[18px]">close</span>
          </button>
        </div>

        {/* Body */}
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <p className="text-xs text-slate-600 leading-relaxed m-0">
            {description}
          </p>

          <div className="p-3 bg-amber-50/70 border border-amber-200/80 rounded-xl text-amber-900 text-xs flex items-center gap-2">
            <span className="material-symbols-outlined text-amber-600 text-base shrink-0">
              shield
            </span>
            <span className="font-medium">
              Yêu cầu xác thực Re-authentication để đảm bảo an toàn vận hành.
            </span>
          </div>

          {/* Mode Switcher */}
          <div className="flex items-center justify-between text-xs pt-1">
            <label className="font-bold text-slate-800 uppercase tracking-wider text-[11px]">
              {mode === 'pin' ? 'Nhập mã PIN Quản Trị (6 số):' : 'Nhập Mật khẩu Quản Trị:'}
            </label>
            <button
              type="button"
              onClick={() => {
                setMode(mode === 'pin' ? 'password' : 'pin');
                setError('');
              }}
              className="text-[11px] text-primary hover:underline font-semibold cursor-pointer"
            >
              {mode === 'pin' ? 'Dùng mật khẩu đăng nhập' : 'Dùng mã PIN 6 số'}
            </button>
          </div>

          {mode === 'pin' ? (
            <div className="relative">
              <input
                type="password"
                inputMode="numeric"
                maxLength={6}
                value={pin}
                onChange={handlePinChange}
                placeholder="Nhập mã PIN 6 số..."
                autoFocus
                className="w-full text-center text-xl tracking-[0.5em] font-mono py-2.5 px-3 bg-slate-50 border border-slate-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary focus:bg-white transition"
              />
            </div>
          ) : (
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => {
                  setPassword(e.target.value);
                  if (error) setError('');
                }}
                placeholder="Nhập mật khẩu quản trị viên..."
                autoFocus
                className="w-full text-xs py-2.5 pl-3 pr-10 bg-slate-50 border border-slate-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary focus:bg-white transition"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 cursor-pointer"
              >
                <span className="material-symbols-outlined text-[18px]">
                  {showPassword ? 'visibility_off' : 'visibility'}
                </span>
              </button>
            </div>
          )}

          {error && (
            <div className="p-2.5 bg-rose-50 border border-rose-200 text-rose-700 rounded-xl text-xs flex items-center gap-2 animate-in fade-in">
              <span className="material-symbols-outlined text-sm">error</span>
              <span>{error}</span>
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex items-center justify-end gap-2.5 pt-3 border-t border-slate-100">
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className="px-4 py-2 border border-slate-200 rounded-xl text-xs font-semibold text-slate-600 hover:bg-slate-100 transition cursor-pointer"
            >
              Hủy bỏ
            </button>
            <button
              type="submit"
              disabled={isSubmitDisabled}
              className={`px-4 py-2 rounded-xl text-xs font-bold text-white transition shadow-sm flex items-center gap-1.5 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed ${
                dangerLevel === 'critical'
                  ? 'bg-rose-600 hover:bg-rose-700'
                  : 'bg-emerald-600 hover:bg-emerald-700'
              }`}
            >
              {loading && (
                <span className="material-symbols-outlined animate-spin text-sm">
                  progress_activity
                </span>
              )}
              <span>Xác thực & Thực thi</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default SecurityConfirmModal;
