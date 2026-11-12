import React, { useEffect, useId, useState } from 'react';
import Modal from './Modal';
import Button from './Button';
import adminApi from '../../api/admin.api';
import { useLanguageSafe } from '../../store/language.context';

const inputClass =
  'h-10 w-full rounded-lg border border-line bg-card px-3 text-sm text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';

const SecurityConfirmModal = ({
  isOpen,
  onClose,
  onConfirm,
  onSuccess,
  title,
  confirmText,
  description,
  actionType = 'CRITICAL_ACTION',
  targetLabel = '',
  dangerLevel = 'danger',
  requirePin = true,
}) => {
  const { t } = useLanguageSafe();
  const fieldId = useId();
  const [mode, setMode] = useState('pin');
  const [pin, setPin] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (isOpen) {
      setMode('pin');
      setPin('');
      setPassword('');
      setShowPassword(false);
      setLoading(false);
      setError('');
    }
  }, [isOpen]);

  const pinValue = pin.trim();
  const submitDisabled =
    loading ||
    (requirePin && mode === 'pin' && pinValue.length < 6) ||
    (requirePin && mode === 'password' && !password.trim()) ||
    (!requirePin && mode === 'pin' && pinValue.length > 0 && pinValue.length < 6);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (submitDisabled) return;
    setLoading(true);
    setError('');
    try {
      if (requirePin || pinValue || password.trim()) {
        await adminApi.verifySecurityAction({
          pin: mode === 'pin' ? pinValue : '',
          password: mode === 'password' ? password : '',
          action: actionType,
          targetId: targetLabel,
        });
      }
      const callback = onConfirm || onSuccess;
      if (typeof callback === 'function') await callback();
      onClose();
    } catch (err) {
      setError(err?.response?.data?.message || err?.message || t('common.security.failed', 'Xác thực thất bại.'));
    } finally {
      setLoading(false);
    }
  };

  const switchMode = () => {
    setMode(mode === 'pin' ? 'password' : 'pin');
    setError('');
  };

  const formId = `${fieldId}-form`;

  return (
    <Modal
      open={isOpen}
      onClose={onClose}
      size="sm"
      closeDisabled={loading}
      title={title || t('common.security.title', 'Xác thực thao tác')}
      description={description || t('common.security.description', 'Nhập mã PIN quản trị để tiếp tục.')}
      footer={
        <>
          <Button onClick={onClose} disabled={loading}>
            {t('common.cancel', 'Hủy bỏ')}
          </Button>
          <Button
            type="submit"
            form={formId}
            variant={dangerLevel === 'critical' ? 'danger' : 'primary'}
            loading={loading}
            disabled={submitDisabled}
          >
            {confirmText || t('common.confirm', 'Xác nhận')}
          </Button>
        </>
      }
    >
      <form id={formId} onSubmit={handleSubmit} className="flex flex-col gap-3">
        {targetLabel && (
          <p className="m-0 text-sm text-ink-muted">
            {t('common.security.target', 'Đối tượng')}: <span className="font-mono text-ink">{targetLabel}</span>
          </p>
        )}
        <div className="flex items-center justify-between gap-3">
          <label htmlFor={fieldId} className="text-sm font-medium text-ink">
            {mode === 'pin'
              ? t('common.security.pinLabel', 'Mã PIN quản trị (6 số)')
              : t('common.security.passwordLabel', 'Mật khẩu quản trị')}
          </label>
          <button type="button" onClick={switchMode} className="cursor-pointer text-sm font-medium text-brand hover:underline">
            {mode === 'pin' ? t('common.security.usePassword', 'Dùng mật khẩu') : t('common.security.usePin', 'Dùng mã PIN')}
          </button>
        </div>
        {mode === 'pin' ? (
          <input
            id={fieldId}
            type="password"
            inputMode="numeric"
            autoComplete="off"
            maxLength={6}
            value={pin}
            autoFocus
            onChange={(e) => {
              setPin(e.target.value.replace(/\D/g, '').slice(0, 6));
              if (error) setError('');
            }}
            className={`${inputClass} text-center font-mono text-lg tracking-[0.5em]`}
          />
        ) : (
          <div className="relative">
            <input
              id={fieldId}
              type={showPassword ? 'text' : 'password'}
              autoComplete="current-password"
              value={password}
              autoFocus
              onChange={(e) => {
                setPassword(e.target.value);
                if (error) setError('');
              }}
              className={`${inputClass} pr-11`}
            />
            <Button
              variant="ghost"
              size="sm"
              icon={showPassword ? 'visibility_off' : 'visibility'}
              aria-label={showPassword ? t('common.security.hidePassword', 'Ẩn mật khẩu') : t('common.security.showPassword', 'Hiện mật khẩu')}
              onClick={() => setShowPassword(!showPassword)}
              className="absolute right-0.5 top-0.5"
            />
          </div>
        )}
        {error && (
          <p role="alert" className="m-0 rounded-lg bg-danger-soft px-3 py-2 text-sm text-danger">
            {error}
          </p>
        )}
      </form>
    </Modal>
  );
};

export default SecurityConfirmModal;
