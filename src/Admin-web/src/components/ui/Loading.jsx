import React from 'react';
import Spinner from './Spinner';
import { useLanguageSafe } from '../../store/language.context';

const Loading = ({ text, fullScreen = false, overlay = false }) => {
  const { t } = useLanguageSafe();
  const label = text === null ? null : text || t('common.loadingData', 'Đang tải dữ liệu...');
  const position = fullScreen ? 'fixed inset-0 z-[100]' : overlay ? 'absolute inset-0 z-10' : 'py-10';
  const backdrop = fullScreen || overlay ? 'bg-canvas/70' : '';
  return (
    <div className={`flex flex-col items-center justify-center gap-3 text-brand ${position} ${backdrop}`}>
      <Spinner size="lg" label={label || undefined} />
      {label && <p className="m-0 text-sm font-medium text-ink-muted">{label}</p>}
    </div>
  );
};

export default Loading;
