import React, { useEffect, useId, useState } from 'react';
import Modal from './Modal';
import Button from './Button';
import adminApi from '../../api/admin.api';
import { useLanguageSafe } from '../../store/language.context';

const inputClass =
  'h-10 w-full rounded-lg border border-line bg-card px-3 text-sm text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';

/**
 * Xác nhận thao tác nhạy cảm CHỈ bằng mã PIN quản trị (6 số). Không có lựa chọn mật khẩu:
 * lộ mật khẩu đăng nhập vẫn không đủ để thay đổi hệ thống. Backend cũng chỉ nhận PIN.
 */
const SecurityConfirmModal = ({
  isOpen,
  onClose,
  onConfirm,
  onSuccess,
  onVerify,
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
  const [pin, setPin] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (isOpen) {
      setPin('');
      setLoading(false);
      setError('');
    }
  }, [isOpen]);

  const pinValue = pin.trim();
  const submitDisabled =
    loading ||
    (requirePin && pinValue.length < 6) ||
    (!requirePin && pinValue.length > 0 && pinValue.length < 6);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (submitDisabled) return;
    setLoading(true);
    setError('');
    try {
      if (typeof onVerify === 'function') {
        await onVerify({ pin: pinValue });
      } else if (requirePin || pinValue) {
        await adminApi.verifySecurityAction({ pin: pinValue, action: actionType, targetId: targetLabel });
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
        <label htmlFor={fieldId} className="text-sm font-medium text-ink">
          {t('common.security.pinLabel', 'Mã PIN quản trị (6 số)')}
        </label>
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
