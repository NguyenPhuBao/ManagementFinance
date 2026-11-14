import React, { useId, useState } from 'react';
import adminApi from '../../../api/admin.api';
import { useAlertSafe } from '../../../store/alert.context';
import { useLanguageSafe } from '../../../store/language.context';
import { Button, Modal } from '../../ui';
import { Field, FormError, digits6, inputClass } from './settingsUi';

const PIN_EMPTY = { password: '', oldPin: '', newPin: '', confirmPin: '' };
const PASSWORD_EMPTY = { oldPassword: '', pin: '', newPassword: '', confirmPassword: '' };
const isPin = (v) => /^\d{6}$/.test(v);
const apiError = (err, fallback) => err?.response?.data?.message || err?.message || fallback;

export const ChangePinModal = ({ open, onClose }) => {
  const { t } = useLanguageSafe();
  const notify = useAlertSafe();
  const ids = useId();
  const formId = `${ids}-form`;
  const [form, setForm] = useState(PIN_EMPTY);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const set = (key) => (e) => setForm((f) => ({ ...f, [key]: key === 'password' ? e.target.value : digits6(e.target.value) }));

  const submit = async (e) => {
    e.preventDefault();
    setError('');
    if (!form.password) return setError(t('settings.pin.errorPassword'));
    if (form.oldPin && !isPin(form.oldPin)) return setError(t('settings.pin.errorOldPin'));
    if (!isPin(form.newPin)) return setError(t('settings.pin.errorNewPin'));
    if (form.oldPin && form.newPin === form.oldPin) return setError(t('settings.pin.errorSame'));
    if (form.newPin !== form.confirmPin) return setError(t('settings.pin.errorMismatch'));
    setLoading(true);
    try {
      await adminApi.changePin({ password: form.password, oldPin: form.oldPin || undefined, newPin: form.newPin });
      if (notify) notify.success(t('settings.pin.success'));
      onClose();
    } catch (err) {
      setError(apiError(err, t('settings.pin.failed')));
    } finally {
      setLoading(false);
    }
    return undefined;
  };

  return (
    <Modal
      open={open}
      onClose={onClose}
      size="sm"
      closeDisabled={loading}
      title={t('settings.pin.title')}
      footer={
        <>
          <Button onClick={onClose} disabled={loading}>
            {t('common.cancel', 'Hủy bỏ')}
          </Button>
          <Button type="submit" form={formId} variant="primary" loading={loading} data-testid="submit-change-pin-btn">
            {t('settings.pin.submit')}
          </Button>
        </>
      }
    >
      <form id={formId} onSubmit={submit} noValidate className="flex flex-col gap-3">
        <FormError message={error} />
        <Field id={`${ids}-password`} label={t('settings.pin.password')}>
          <input id={`${ids}-password`} type="password" data-testid="pin-input-password" value={form.password} onChange={set('password')} className={inputClass} />
        </Field>
        <Field id={`${ids}-old`} label={t('settings.pin.oldPin')}>
          <input id={`${ids}-old`} type="password" inputMode="numeric" maxLength={6} data-testid="pin-input-old" value={form.oldPin} onChange={set('oldPin')} placeholder={t('settings.pin.oldPinHint')} className={`${inputClass} font-mono tracking-widest`} />
        </Field>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <Field id={`${ids}-new`} label={t('settings.pin.newPin')}>
            <input id={`${ids}-new`} type="password" inputMode="numeric" maxLength={6} data-testid="pin-input-new" value={form.newPin} onChange={set('newPin')} className={`${inputClass} font-mono tracking-widest`} />
          </Field>
          <Field id={`${ids}-confirm`} label={t('settings.pin.confirmPin')}>
            <input id={`${ids}-confirm`} type="password" inputMode="numeric" maxLength={6} data-testid="pin-input-confirm" value={form.confirmPin} onChange={set('confirmPin')} className={`${inputClass} font-mono tracking-widest`} />
          </Field>
        </div>
      </form>
    </Modal>
  );
};

export const ChangePasswordModal = ({ open, onClose }) => {
  const { t } = useLanguageSafe();
  const notify = useAlertSafe();
  const ids = useId();
  const formId = `${ids}-form`;
  const [form, setForm] = useState(PASSWORD_EMPTY);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const set = (key) => (e) => setForm((f) => ({ ...f, [key]: key === 'pin' ? digits6(e.target.value) : e.target.value }));

  const submit = async (e) => {
    e.preventDefault();
    setError('');
    if (!form.oldPassword) return setError(t('settings.password.errorOld'));
    if (!isPin(form.pin)) return setError(t('settings.password.errorPin'));
    if (!form.newPassword || form.newPassword.length < 6) return setError(t('settings.password.errorLength'));
    if (form.newPassword === form.oldPassword) return setError(t('settings.password.errorSame'));
    if (form.newPassword !== form.confirmPassword) return setError(t('settings.password.errorMismatch'));
    setLoading(true);
    try {
      await adminApi.changePassword({ oldPassword: form.oldPassword, pin: form.pin, oldPin: form.pin, newPassword: form.newPassword });
      if (notify) notify.success(t('settings.password.success'));
      onClose();
    } catch (err) {
      setError(apiError(err, t('settings.password.failed')));
    } finally {
      setLoading(false);
    }
    return undefined;
  };

  return (
    <Modal
      open={open}
      onClose={onClose}
      size="sm"
      closeDisabled={loading}
      title={t('settings.password.title')}
      footer={
        <>
          <Button onClick={onClose} disabled={loading}>
            {t('common.cancel', 'Hủy bỏ')}
          </Button>
          <Button type="submit" form={formId} variant="primary" loading={loading} data-testid="submit-change-password-btn">
            {t('settings.password.submit')}
          </Button>
        </>
      }
    >
      <form id={formId} onSubmit={submit} noValidate className="flex flex-col gap-3">
        <FormError message={error} />
        <Field id={`${ids}-old`} label={t('settings.password.old')}>
          <input id={`${ids}-old`} type="password" data-testid="password-input-old" value={form.oldPassword} onChange={set('oldPassword')} className={inputClass} />
        </Field>
        <Field id={`${ids}-pin`} label={t('settings.password.pin')}>
          <input id={`${ids}-pin`} type="password" inputMode="numeric" maxLength={6} data-testid="password-input-pin" value={form.pin} onChange={set('pin')} className={`${inputClass} font-mono tracking-widest`} />
        </Field>
        <Field id={`${ids}-new`} label={t('settings.password.new')}>
          <input id={`${ids}-new`} type="password" data-testid="password-input-new" value={form.newPassword} onChange={set('newPassword')} placeholder={t('settings.password.newHint')} className={inputClass} />
        </Field>
        <Field id={`${ids}-confirm`} label={t('settings.password.confirm')}>
          <input id={`${ids}-confirm`} type="password" data-testid="password-input-confirm" value={form.confirmPassword} onChange={set('confirmPassword')} className={inputClass} />
        </Field>
      </form>
    </Modal>
  );
};
