import React from 'react';
import Modal from './Modal';
import Button from './Button';
import { useLanguageSafe } from '../../store/language.context';

const ConfirmModal = ({
  open,
  onConfirm,
  onCancel,
  title,
  message,
  confirmText,
  cancelText,
  confirmDanger = false,
  loading = false,
  children,
}) => {
  const { t } = useLanguageSafe();
  return (
    <Modal
      open={open}
      onClose={onCancel}
      size="sm"
      closeDisabled={loading}
      title={title || t('common.confirmModal.title', 'Xác nhận')}
      footer={
        <>
          <Button onClick={onCancel} disabled={loading}>
            {cancelText || t('common.cancel', 'Hủy bỏ')}
          </Button>
          <Button variant={confirmDanger ? 'danger' : 'primary'} onClick={onConfirm} loading={loading}>
            {confirmText || t('common.confirm', 'Xác nhận')}
          </Button>
        </>
      }
    >
      <p className="m-0 text-ink-muted">{message || t('common.confirmModal.message', 'Bạn có chắc muốn thực hiện thao tác này?')}</p>
      {children}
    </Modal>
  );
};

export default ConfirmModal;
