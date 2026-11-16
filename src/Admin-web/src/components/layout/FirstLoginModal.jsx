import React, { useEffect, useState } from 'react';
import { useAuthContext } from '../../store/auth.context';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import { STORAGE_KEYS } from '../../utils/constants';
import adminApi from '../../api/admin.api';
import { Button, Modal, PasswordInput } from '../ui';
import { FormError, digits6 } from './settings/settingsUi';

const FORM_ID = 'first-login-form';
const DEFAULT_SECRET = '123456';
const EMPTY = { newPassword: '', confirmPassword: '', pin: '', confirmPin: '' };

const validate = (form) => {
  if (!form.newPassword) return 'errPassRequired';
  if (form.newPassword.length < 6) return 'errPassMin';
  if (form.newPassword === DEFAULT_SECRET) return 'errPassDefault';
  if (form.newPassword !== form.confirmPassword) return 'errPassMismatch';
  if (!/^\d{6}$/.test(form.pin)) return 'errPinInvalid';
  if (form.pin === DEFAULT_SECRET) return 'errPinDefault';
  if (form.pin !== form.confirmPin) return 'errPinMismatch';
  return null;
};

const FIELDS = [
  { key: 'newPassword', label: 'newPassword', testId: 'first-login-new-password', group: 'password' },
  { key: 'confirmPassword', label: 'confirmPassword', testId: 'first-login-confirm-password', group: 'password' },
  { key: 'pin', label: 'newPin', testId: 'first-login-new-pin', group: 'pin' },
  { key: 'confirmPin', label: 'confirmPin', testId: 'first-login-confirm-pin', group: 'pin' },
];

const FirstLoginModal = () => {
  const { user, syncAuthSession } = useAuthContext();
  const notify = useAlertSafe();
  const { t } = useLanguageSafe();
  const [form, setForm] = useState(EMPTY);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const open = Boolean(user?.is_first_login);

  useEffect(() => {
    if (!open) return undefined;
    const blockEscape = (e) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        e.stopPropagation();
      }
    };
    window.addEventListener('keydown', blockEscape, true);
    return () => window.removeEventListener('keydown', blockEscape, true);
  }, [open]);

  if (!open) return null;

  const set = (field) => (e) =>
    setForm((f) => ({ ...f, [field.key]: field.group === 'pin' ? digits6(e.target.value) : e.target.value }));

  const handleSubmit = async (e) => {
    e.preventDefault();
    const invalid = validate(form);
    if (invalid) {
      setError(t(`firstLogin.${invalid}`));
      return;
    }
    setError('');
    setLoading(true);
    try {
      const res = await adminApi.firstLoginSetup({
        newPassword: form.newPassword,
        confirmPassword: form.confirmPassword,
        pin: form.pin,
        confirmPin: form.confirmPin,
      });
      const data = res?.data || res;
      const updatedUser = data?.user || user;
      if (syncAuthSession) {
        syncAuthSession({
          user: { ...updatedUser, is_first_login: false },
          accessToken: localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN),
          refreshToken: localStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN),
        });
      }
      notify?.success?.(t('firstLogin.successMsg'), t('firstLogin.successTitle'));
    } catch (err) {
      setError(err.response?.data?.message || err.message || t('firstLogin.failed'));
    } finally {
      setLoading(false);
    }
  };

  const renderGroup = (group) => (
    <fieldset className="m-0 flex flex-col gap-3 rounded-lg border border-line p-4">
      <legend className="px-1 text-sm font-semibold text-ink">{t(`firstLogin.${group}Section`)}</legend>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        {FIELDS.filter((f) => f.group === group).map((field) => (
          <div key={field.key}>
            <label htmlFor={field.testId} className="mb-1 block text-sm font-medium text-ink">
              {t(`firstLogin.${field.label}`)}
            </label>
            <PasswordInput
              id={field.testId}
              data-testid={field.testId}
              autoComplete={group === 'pin' ? 'off' : 'new-password'}
              inputMode={group === 'pin' ? 'numeric' : undefined}
              maxLength={group === 'pin' ? 6 : undefined}
              className={group === 'pin' ? 'font-mono tracking-widest' : ''}
              value={form[field.key]}
              onChange={set(field)}
            />
          </div>
        ))}
      </div>
    </fieldset>
  );

  return (
    <Modal
      open
      onClose={() => {}}
      closeDisabled
      hideClose
      backdrop="solid"
      testId="first-login-modal-overlay"
      title={t('firstLogin.title')}
      description={t('firstLogin.desc')}
      footer={
        <Button type="submit" form={FORM_ID} variant="primary" loading={loading} data-testid="first-login-submit-btn">
          {t('firstLogin.submit')}
        </Button>
      }
    >
      <form id={FORM_ID} onSubmit={handleSubmit} noValidate className="flex flex-col gap-4">
        <FormError message={error} />
        {renderGroup('password')}
        {renderGroup('pin')}
      </form>
    </Modal>
  );
};

export default FirstLoginModal;
