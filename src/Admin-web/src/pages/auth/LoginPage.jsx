import React, { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuthContext } from '../../store/auth.context';
import { useSettingsSafe } from '../../store/settings.context';
import { useLanguageSafe } from '../../store/language.context';
import { Button, PasswordInput } from '../../components/ui';
import { Field, FormError, inputClass } from '../../components/layout/settings/settingsUi';
import AuthShell from './AuthShell';

const LoginPage = () => {
  const navigate = useNavigate();
  const { login } = useAuthContext();
  const settingsCtx = useSettingsSafe();
  const resetLockState = settingsCtx?.resetLockState;
  const { t } = useLanguageSafe();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (resetLockState) resetLockState();
  }, [resetLockState]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      await login({ username, password });
      if (resetLockState) resetLockState();
      navigate('/dashboard');
    } catch (err) {
      setError(
        err.response?.status === 401
          ? t('auth.login.invalidCredentials')
          : err.response?.data?.message || err.message || t('auth.login.failed')
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthShell title={t('auth.login.title')} description={t('auth.login.subtitle')}>
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <FormError message={error} />
        <Field id="login-username" label={t('auth.login.usernameLabel')}>
          <input
            id="login-username"
            name="username"
            autoComplete="username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            disabled={loading}
            required
            autoFocus
            className={inputClass}
          />
        </Field>
        <div>
          <div className="mb-1 flex items-center justify-between gap-3">
            <label htmlFor="login-password" className="text-sm font-medium text-ink">
              {t('auth.login.passwordLabel')}
            </label>
            <Link to="/forgot-password" className="text-sm font-medium text-brand hover:underline">
              {t('auth.login.forgotPasswordLink')}
            </Link>
          </div>
          <PasswordInput
            id="login-password"
            name="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            disabled={loading}
            required
          />
        </div>
        <Button type="submit" variant="primary" loading={loading} className="mt-2 w-full">
          {t('auth.login.submitBtn')}
        </Button>
      </form>
    </AuthShell>
  );
};

export default LoginPage;
