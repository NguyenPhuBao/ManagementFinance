import React, { useMemo, useState } from 'react';
import { useSettingsSafe } from '../../store/settings.context';
import { useAuthContext } from '../../store/auth.context';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import { STORAGE_KEYS } from '../../utils/constants';
import { Button, ConfirmModal, Icon, Modal, PasswordInput } from '../ui';
import { FormError } from './settings/settingsUi';

const FORM_ID = 'lock-screen-form';
const SESSION_KEYS = [
  STORAGE_KEYS.IS_LOCKED,
  STORAGE_KEYS.LOCKED_AT,
  STORAGE_KEYS.LOCKED_USER,
  STORAGE_KEYS.ACCESS_TOKEN,
  STORAGE_KEYS.REFRESH_TOKEN,
  STORAGE_KEYS.USER,
];

const readLockedUser = () => {
  try {
    const raw = localStorage.getItem(STORAGE_KEYS.LOCKED_USER) || localStorage.getItem(STORAGE_KEYS.USER);
    return raw ? JSON.parse(raw) : null;
  } catch (_) {
    return null;
  }
};

const LockScreenModal = () => {
  const settingsCtx = useSettingsSafe();
  const { user, logout, syncAuthSession } = useAuthContext();
  const notify = useAlertSafe();
  const { t } = useLanguageSafe();
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [confirmLogout, setConfirmLogout] = useState(false);
  const [loggingOut, setLoggingOut] = useState(false);

  const isLocked = Boolean(settingsCtx?.isLocked);
  const lockedUser = useMemo(() => (isLocked ? readLockedUser() : null), [isLocked]);

  if (!isLocked) return null;

  const activeUser = user || lockedUser;

  const handleUnlock = async (e) => {
    e.preventDefault();
    if (!password.trim()) {
      setError(t('lockScreen.errorPasswordRequired'));
      return;
    }
    setError('');
    setLoading(true);
    try {
      const sessionData = await settingsCtx.unlockScreen(password, syncAuthSession);
      if (syncAuthSession && sessionData) syncAuthSession(sessionData);
      setPassword('');
      notify?.success?.(
        t('lockScreen.welcomeBack', { name: activeUser?.fullname || activeUser?.username || t('lockScreen.defaultAdmin') }),
        t('lockScreen.unlockSuccess')
      );
    } catch (err) {
      setError(err.response?.data?.message || err.message || t('lockScreen.errorWrongPass'));
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    setLoggingOut(true);
    try {
      SESSION_KEYS.forEach((key) => localStorage.removeItem(key));
    } catch (_) {}
    try {
      await logout();
    } finally {
      setLoggingOut(false);
      setConfirmLogout(false);
    }
  };

  return (
    <>
      <Modal
        open
        onClose={() => {}}
        closeDisabled
        hideClose
        backdrop="solid"
        size="sm"
        title={t('lockScreen.title')}
        description={settingsCtx.lockedAt ? t('lockScreen.lockedAt', { time: settingsCtx.lockedAt }) : t('lockScreen.lockedIdle')}
        footer={
          <>
            <Button variant="danger-ghost" icon="logout" onClick={() => setConfirmLogout(true)} disabled={loading}>
              {t('lockScreen.logoutBtn')}
            </Button>
            <Button type="submit" form={FORM_ID} variant="primary" icon="lock_open" loading={loading}>
              {t('lockScreen.unlockBtn')}
            </Button>
          </>
        }
      >
        <form id={FORM_ID} onSubmit={handleUnlock} noValidate className="flex flex-col gap-4">
          <div className="flex items-center gap-3 rounded-lg bg-muted px-3 py-3">
            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-soft text-brand">
              <Icon name="person" />
            </span>
            <div className="min-w-0">
              <p className="m-0 truncate text-sm font-semibold text-ink">{activeUser?.username || t('lockScreen.defaultAdmin')}</p>
              {activeUser?.email && <p className="m-0 truncate text-sm text-ink-muted">{activeUser.email}</p>}
            </div>
          </div>
          <FormError message={error} />
          <div>
            <label htmlFor="lock-screen-password" className="mb-1 block text-sm font-medium text-ink">
              {t('lockScreen.passwordLabel')}
            </label>
            <PasswordInput
              id="lock-screen-password"
              autoComplete="current-password"
              autoFocus
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                if (error) setError('');
              }}
            />
          </div>
        </form>
      </Modal>
      <ConfirmModal
        open={confirmLogout}
        title={t('lockScreen.logoutTitle')}
        message={t('lockScreen.logoutConfirm')}
        confirmText={t('lockScreen.logoutBtn')}
        confirmDanger
        loading={loggingOut}
        onConfirm={handleLogout}
        onCancel={() => setConfirmLogout(false)}
      />
    </>
  );
};

export default LockScreenModal;
