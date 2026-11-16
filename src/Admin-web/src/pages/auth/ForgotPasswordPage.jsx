import React from 'react';
import { Link } from 'react-router-dom';
import { useLanguageSafe } from '../../store/language.context';
import { Icon } from '../../components/ui';
import AuthShell from './AuthShell';

const SUPPORT_PHONE = { href: 'tel:+84355281276', label: '+84 355 281 276' };

const ForgotPasswordPage = () => {
  const { t } = useLanguageSafe();
  return (
    <AuthShell
      title={t('auth.forgotPassword.title')}
      footer={
        <Link to="/login" className="inline-flex items-center gap-1.5 text-sm font-medium text-brand hover:underline">
          <Icon name="arrow_back" size="sm" />
          {t('auth.forgotPassword.backToLogin')}
        </Link>
      }
    >
      <div className="flex flex-col gap-4">
        <p className="m-0 flex items-start gap-2 rounded-lg bg-warning-soft px-3 py-2 text-sm text-warning">
          <Icon name="info" size="sm" className="mt-0.5" />
          {t('auth.forgotPassword.warning')}
        </p>
        <p className="m-0 text-sm text-ink-muted">{t('auth.forgotPassword.instruction')}</p>
        <a
          href={SUPPORT_PHONE.href}
          className="flex items-center justify-center gap-2 rounded-lg border border-line bg-muted px-4 py-3 text-xl font-semibold tabular-nums text-ink hover:border-brand hover:text-brand"
        >
          <Icon name="call" />
          {SUPPORT_PHONE.label}
        </a>
      </div>
    </AuthShell>
  );
};

export default ForgotPasswordPage;
