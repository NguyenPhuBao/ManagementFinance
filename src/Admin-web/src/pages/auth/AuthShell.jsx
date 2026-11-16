import React from 'react';
import LanguageToggle from '../../components/common/LanguageToggle';
import { useLanguageSafe } from '../../store/language.context';

const AuthShell = ({ title, description, children, footer, brand }) => {
  const { t } = useLanguageSafe();
  return (
    <div className="flex min-h-screen flex-col bg-canvas">
      <header className="flex h-14 items-center justify-between gap-3 border-b border-line bg-card px-4 sm:px-6">
        <div className="flex items-center gap-2.5">
          <span aria-hidden="true" className="flex h-8 w-8 items-center justify-center rounded-lg bg-brand text-sm font-bold text-brand-on">
            F
          </span>
          <span className="text-base font-bold text-ink">{brand || t('nav.brandTitle', 'FlowMoney Admin')}</span>
        </div>
        <LanguageToggle />
      </header>
      <main className="flex flex-1 items-center justify-center px-4 pb-16">
        <div className="w-full max-w-sm rounded-xl border border-line bg-card p-6 shadow-sm sm:p-8">
          <h1 className="m-0 text-2xl font-semibold text-ink">{title}</h1>
          {description && <p className="m-0 mt-1 text-sm text-ink-muted">{description}</p>}
          <div className="mt-6">{children}</div>
          {footer && <div className="mt-6 border-t border-line pt-4 text-center">{footer}</div>}
        </div>
      </main>
    </div>
  );
};

export default AuthShell;
