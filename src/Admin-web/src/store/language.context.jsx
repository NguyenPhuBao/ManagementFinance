// src/Admin-web/src/store/language.context.jsx
import React, { createContext, useContext, useState, useEffect, useMemo, useCallback } from 'react';
import { vi, en, SUPPORTED_LANGUAGES, DEFAULT_LANGUAGE, STORAGE_KEY } from '../locales';

const LanguageContext = createContext(null);

export const LanguageProvider = ({ children }) => {
  const [language, setLanguageState] = useState(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved && SUPPORTED_LANGUAGES.includes(saved)) {
        return saved;
      }
    } catch (_) {}
    return DEFAULT_LANGUAGE;
  });

  const changeLanguage = useCallback((newLang) => {
    if (!SUPPORTED_LANGUAGES.includes(newLang)) return;
    setLanguageState(newLang);
    try {
      localStorage.setItem(STORAGE_KEY, newLang);
    } catch (e) {
      console.warn('[LanguageContext] Failed to save language to localStorage', e);
    }
  }, []);

  // Tác động Root DOM thực tế (Tuân thủ Rule 11 - Kiểm thử Tầng 2)
  useEffect(() => {
    try {
      document.documentElement.setAttribute('lang', language);
      document.documentElement.setAttribute('data-language', language);
    } catch (_) {}
  }, [language]);

  const dictionary = useMemo(() => {
    return language === 'en' ? en : vi;
  }, [language]);

  // Hàm dịch thuật hỗ trợ dot-notation ('common.confirm'), interpolation ('{param}') và fallback text
  const t = useCallback((keyPath, fallbackOrParams, maybeParams) => {
    if (!keyPath || typeof keyPath !== 'string') return '';
    const keys = keyPath.split('.');

    const fallback = typeof fallbackOrParams === 'string' ? fallbackOrParams : undefined;
    const params = typeof fallbackOrParams === 'object' && fallbackOrParams !== null
      ? fallbackOrParams
      : (typeof maybeParams === 'object' && maybeParams !== null ? maybeParams : {});

    // Tra cứu trong từ điển ngôn ngữ hiện tại
    let value = keys.reduce((acc, curr) => (acc && acc[curr] !== undefined ? acc[curr] : undefined), dictionary);

    // Fallback sang Tiếng Việt nếu ngôn ngữ hiện tại (EN) bị thiếu key
    if (value === undefined && language !== 'vi') {
      value = keys.reduce((acc, curr) => (acc && acc[curr] !== undefined ? acc[curr] : undefined), vi);
    }

    // Nếu vẫn không có key trong cả từ điển hiện tại lẫn từ điển gốc
    if (value === undefined) {
      value = fallback !== undefined ? fallback : keyPath;
    }

    // Thay thế tham số {param} nếu có
    if (typeof value === 'string' && params && typeof params === 'object') {
      return value.replace(/{([^{}]+)}/g, (_, paramKey) => {
        return params[paramKey] !== undefined ? params[paramKey] : `{${paramKey}}`;
      });
    }

    return value;
  }, [dictionary, language]);

  const value = useMemo(() => ({
    language,
    isVietnamese: language === 'vi',
    isEnglish: language === 'en',
    changeLanguage,
    t,
  }), [language, changeLanguage, t]);

  return (
    <LanguageContext.Provider value={value}>
      {children}
    </LanguageContext.Provider>
  );
};

export const useLanguage = () => {
  const context = useContext(LanguageContext);
  if (!context) {
    throw new Error('useLanguage must be used within a LanguageProvider');
  }
  return context;
};

// Hook an toàn sử dụng trong unit tests hoặc khi component render ngoài provider
export const useLanguageSafe = () => {
  const context = useContext(LanguageContext);
  if (!context) {
    return {
      language: DEFAULT_LANGUAGE,
      isVietnamese: true,
      isEnglish: false,
      changeLanguage: () => {},
      t: (keyPath, fallbackOrParams, maybeParams) => {
        if (!keyPath || typeof keyPath !== 'string') return '';
        const keys = keyPath.split('.');

        const fallback = typeof fallbackOrParams === 'string' ? fallbackOrParams : undefined;
        const params = typeof fallbackOrParams === 'object' && fallbackOrParams !== null
          ? fallbackOrParams
          : (typeof maybeParams === 'object' && maybeParams !== null ? maybeParams : {});

        let value = keys.reduce((acc, curr) => (acc && acc[curr] !== undefined ? acc[curr] : undefined), vi);
        if (value === undefined) {
          value = fallback !== undefined ? fallback : keyPath;
        }
        if (typeof value === 'string' && params && typeof params === 'object') {
          return value.replace(/{([^{}]+)}/g, (_, paramKey) => {
            return params[paramKey] !== undefined ? params[paramKey] : `{${paramKey}}`;
          });
        }
        return value;
      },
    };
  }
  return context;
};

export default LanguageContext;
