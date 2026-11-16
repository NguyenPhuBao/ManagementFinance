import React from 'react';
import Icon from './Icon';
import { useLanguageSafe } from '../../store/language.context';

const EmptyState = ({ icon = 'inbox', title, description, action }) => {
  const { t } = useLanguageSafe();
  return (
    <div className="flex flex-col items-center justify-center px-6 py-12 text-center">
      <Icon name={icon} size="lg" className="mb-3 text-ink-faint" />
      <p className="m-0 text-base font-semibold text-ink">{title || t('common.emptyState.title', 'Không có dữ liệu')}</p>
      {description && <p className="m-0 mt-1 text-sm text-ink-muted">{description}</p>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
};

export default EmptyState;
