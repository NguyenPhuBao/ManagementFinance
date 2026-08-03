import React from 'react';

const EmptyState = ({
  icon = 'inbox',
  title = 'Không có dữ liệu',
  description = 'Chưa có mục nào để hiển thị.',
  action,
}) => {
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
        {title}
      </h3>
      <p style={{
        fontSize: 14,
        color: 'var(--color-secondary)',
        marginBottom: action ? 20 : 0,
        maxWidth: 400,
      }}>
        {description}
      </p>
      {action && action}
    </div>
  );
};

export default EmptyState;
