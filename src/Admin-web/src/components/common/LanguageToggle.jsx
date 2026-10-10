// src/Admin-web/src/components/common/LanguageToggle.jsx
import React, { useState } from 'react';
import { useLanguageSafe } from '../../store/language.context';

const LanguageToggle = () => {
  const { language, changeLanguage, isVietnamese, isEnglish, t } = useLanguageSafe();
  const [showTooltip, setShowTooltip] = useState(false);

  return (
    <div 
      className="relative inline-flex items-center" 
      data-testid="language-toggle"
      onMouseEnter={() => setShowTooltip(true)}
      onMouseLeave={() => setShowTooltip(false)}
      onFocus={() => setShowTooltip(true)}
      onBlur={() => setShowTooltip(false)}
    >
      {/* Outer Pill Container */}
      <div 
        role="group"
        aria-label={t('header.languageTooltip') || 'Ngôn ngữ giao diện'}
        className="flex items-center p-0.5 rounded-full border border-slate-200/90 bg-slate-100/90 shadow-2xs transition-all hover:border-slate-300"
      >
        {/* Nút EN */}
        <button
          type="button"
          data-testid="lang-btn-en"
          onClick={() => changeLanguage('en')}
          aria-pressed={isEnglish}
          title="English"
          className={`px-2.5 py-0.5 text-[11px] font-bold rounded-full transition-all cursor-pointer ${
            isEnglish
              ? 'bg-blue-600 text-white shadow-xs'
              : 'text-blue-500 hover:text-blue-700 hover:bg-slate-200/50'
          }`}
        >
          EN
        </button>

        {/* Nút VI */}
        <button
          type="button"
          data-testid="lang-btn-vi"
          onClick={() => changeLanguage('vi')}
          aria-pressed={isVietnamese}
          title="Tiếng Việt"
          className={`px-2.5 py-0.5 text-[11px] font-bold rounded-full transition-all cursor-pointer ${
            isVietnamese
              ? 'bg-blue-600 text-white shadow-xs'
              : 'text-blue-500 hover:text-blue-700 hover:bg-slate-200/50'
          }`}
        >
          VI
        </button>
      </div>

      {/* Tooltip Hover Bên Dưới */}
      {showTooltip && (
        <div 
          role="tooltip"
          className="absolute top-full left-1/2 -translate-x-1/2 mt-2 flex flex-col items-center z-50 pointer-events-none animate-in fade-in duration-150"
        >
          {/* Mũi tên tam giác hướng lên */}
          <div className="w-0 h-0 border-x-4 border-x-transparent border-b-4 border-b-slate-800"></div>
          {/* Hộp nội dung tooltip */}
          <div className="px-2.5 py-1 bg-slate-800 text-white text-[11px] font-medium rounded-md shadow-lg whitespace-nowrap">
            {t('header.languageTooltip') || 'Ngôn ngữ giao diện'}
          </div>
        </div>
      )}
    </div>
  );
};

export default LanguageToggle;
