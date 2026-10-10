import React from 'react';
import { useLanguageSafe } from '../../store/language.context';

const EmptyState = ({
  icon = 'inbox',
  title,
  description,
  action,
}) => {
  const { t } = useLanguageSafe();
  const resolvedTitle = title || t('common.emptyState.title', 'Không có dữ liệu');
  const resolvedDescription = description || t('common.emptyState.description', 'Chưa có mục nào để hiển thị.');

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      padding: 48,
      textAlign: 'center',
    }}>
      <span
        className="material-symbols-outlined"
        style={{ fontSize: 48, color: 'var(--color-outline)', marginBottom: 16 }}
      >
        {icon}
      </span>
      <h3 style={{
        fontSize: 16,
        fontWeight: 600,
        color: 'var(--color-on-surface)',
        marginBottom: 8,
      }}>
        {resolvedTitle}
      </h3>
      <p style={{
        fontSize: 14,
        color: 'var(--color-secondary)',
        marginBottom: action ? 20 : 0,
        maxWidth: 400,
      }}>
        {resolvedDescription}
      </p>
      {action && action}
    </div>
  );
};

export default EmptyState;
