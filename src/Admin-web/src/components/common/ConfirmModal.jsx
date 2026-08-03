import React from 'react';

const ConfirmModal = ({
  open,
  onConfirm,
  onCancel,
  title = 'Xác nhận',
  message = 'Bạn có chắc chắn muốn thực hiện hành động này?',
  confirmText = 'Xác nhận',
  cancelText = 'Hủy bỏ',
  confirmDanger = false,
  icon = 'warning',
  loading = false,
}) => {
  if (!open) return null;

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 50,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: 'rgba(11, 28, 48, 0.5)',
        backdropFilter: 'blur(2px)',
        padding: 16,
      }}
      onClick={onCancel}
    >
      <div
        style={{
          backgroundColor: '#ffffff',
          borderRadius: 12,
          border: '1px solid var(--color-outline-variant)',
          width: '100%',
          maxWidth: 400,
          padding: 24,
          boxShadow: '0 12px 24px rgba(11, 28, 48, 0.1)',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 16, marginBottom: 16 }}>
          <div style={{
            width: 48,
            height: 48,
            borderRadius: '50%',
            backgroundColor: confirmDanger ? 'var(--color-error-container)' : 'var(--color-surface-container)',
            color: confirmDanger ? 'var(--color-on-error-container)' : 'var(--color-on-surface-variant)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}>
            <span className="material-symbols-outlined">{icon}</span>
          </div>
          <div>
            <h3 style={{ fontSize: 20, fontWeight: 600, color: 'var(--color-on-surface)', marginBottom: 4 }}>
              {title}
            </h3>
            <p style={{ fontSize: 14, color: 'var(--color-secondary)', lineHeight: 1.5 }}>
              {message}
            </p>
          </div>
        </div>

        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 12 }}>
          <button
            onClick={onCancel}
            disabled={loading}
            style={{
              padding: '8px 16px',
              borderRadius: 8,
              border: '1px solid var(--color-outline)',
              backgroundColor: 'transparent',
              color: 'var(--color-secondary)',
              fontSize: 14,
              fontWeight: 500,
              cursor: 'pointer',
            }}
          >
            {cancelText}
          </button>
          <button
            onClick={onConfirm}
            disabled={loading}
            style={{
              padding: '8px 16px',
              borderRadius: 8,
              border: 'none',
              backgroundColor: confirmDanger ? 'var(--color-error)' : 'var(--color-primary)',
              color: '#ffffff',
              fontSize: 14,
              fontWeight: 500,
              cursor: loading ? 'not-allowed' : 'pointer',
              opacity: loading ? 0.7 : 1,
            }}
          >
            {loading ? 'Đang xử lý...' : confirmText}
          </button>
        </div>
      </div>
    </div>
  );
};

export default ConfirmModal;
