import React from 'react';
import { useLanguageSafe } from '../../store/language.context';

const OPTIONS = [
  { code: 'en', label: 'EN', title: 'English', testId: 'lang-btn-en' },
  { code: 'vi', label: 'VI', title: 'Tiếng Việt', testId: 'lang-btn-vi' },
];

const LanguageToggle = () => {
  const { language, changeLanguage, t } = useLanguageSafe();
  return (
    <div
      role="group"
      data-testid="language-toggle"
      aria-label={t('header.languageTooltip', 'Ngôn ngữ')}
      className="inline-flex items-center gap-0.5 rounded-lg bg-muted p-0.5"
    >
      {OPTIONS.map((opt) => {
        const active = language === opt.code;
        return (
          <button
            key={opt.code}
            type="button"
            data-testid={opt.testId}
            aria-pressed={active}
            title={opt.title}
            onClick={() => changeLanguage(opt.code)}
            className={`h-7 cursor-pointer rounded-md px-2 text-xs font-semibold transition-colors ${
              active ? 'bg-card text-ink shadow-sm' : 'text-ink-muted hover:text-ink'
            }`}
          >
            {opt.label}
          </button>
        );
      })}
    </div>
  );
};

export default LanguageToggle;
