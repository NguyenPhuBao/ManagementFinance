import React, { useEffect, useId } from 'react';
import Button from './Button';
import { useLanguageSafe } from '../../store/language.context';

const WIDTHS = {
  sm: 'max-w-md',
  md: 'max-w-lg',
  lg: 'max-w-2xl',
  xl: 'max-w-4xl',
};

const Modal = ({ open, onClose, title, description, footer, size = 'md', closeDisabled = false, hideClose = false, backdrop = 'dim', testId, children }) => {
  const { t } = useLanguageSafe();
  const titleId = useId();

  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => {
      if (e.key === 'Escape' && !closeDisabled) onClose();
    };
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    window.addEventListener('keydown', onKey);
    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = previousOverflow;
    };
  }, [open, closeDisabled, onClose]);

  if (!open) return null;

  return (
    <div
      className={`fixed inset-0 z-50 flex items-center justify-center p-4 ${backdrop === 'solid' ? 'bg-canvas' : 'bg-overlay'}`}
      onClick={closeDisabled ? undefined : onClose}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        data-testid={testId}
        className={`flex max-h-[90vh] w-full flex-col overflow-hidden rounded-xl border border-line bg-card shadow-xl ${WIDTHS[size]}`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3 border-b border-line px-5 py-4">
          <div className="min-w-0">
            <h2 id={titleId} className="m-0 text-base font-semibold text-ink">
              {title}
            </h2>
            {description && <p className="m-0 mt-1 text-sm text-ink-muted">{description}</p>}
          </div>
          {!hideClose && (
            <Button
              variant="ghost"
              size="sm"
              icon="close"
              aria-label={t('common.close', 'Đóng')}
              disabled={closeDisabled}
              onClick={onClose}
            />
          )}
        </div>
        <div className="overflow-y-auto px-5 py-4 text-sm text-ink">{children}</div>
        {footer && <div className="flex flex-wrap justify-end gap-2 border-t border-line px-5 py-3">{footer}</div>}
      </div>
    </div>
  );
};

export default Modal;
