import React, { useEffect, useId, useState } from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { Badge, Button, Modal } from '../../../components/ui';

const PermissionScopeDrawer = ({ feature, plan, initialScope, onApply, onClose }) => {
  const { t } = useLanguageSafe();
  const editorId = useId();
  const [text, setText] = useState('{}');
  const [error, setError] = useState('');

  useEffect(() => {
    if (!feature) return;
    setText(JSON.stringify(initialScope || {}, null, 2));
    setError('');
  }, [feature, plan, initialScope]);

  const apply = () => {
    try {
      const parsed = text.trim() ? JSON.parse(text) : {};
      onApply(parsed);
      onClose();
    } catch {
      setError(t('permissions.scope.invalid'));
    }
  };

  const hasSchema = feature?.scope_schema && Object.keys(feature.scope_schema).length > 0;

  return (
    <Modal
      open={Boolean(feature)}
      onClose={onClose}
      size="md"
      title={feature ? t('permissions.scope.title', { name: feature.name }) : ''}
      footer={
        <>
          <Button data-testid="btn-close-drawer" onClick={onClose}>
            {t('common.cancel', 'Hủy bỏ')}
          </Button>
          <Button variant="primary" data-testid="btn-apply-drawer" onClick={apply}>
            {t('permissions.scope.apply')}
          </Button>
        </>
      }
    >
      {feature && (
        <div className="flex flex-col gap-4">
          <div className="flex flex-wrap items-center gap-2">
            <Badge tone={plan === 'Premium' ? 'success' : 'neutral'}>{plan}</Badge>
            <span className="font-mono text-xs text-ink-faint">{feature.id}</span>
          </div>
          {hasSchema && (
            <div>
              <div className="mb-1 text-xs font-semibold text-ink-muted">{t('permissions.scope.schema')}</div>
              <pre className="m-0 overflow-x-auto rounded-lg border border-line bg-muted p-3 font-mono text-xs text-ink">{JSON.stringify(feature.scope_schema, null, 2)}</pre>
            </div>
          )}
          <div>
            <label htmlFor={editorId} className="mb-1 block text-sm font-medium text-ink">
              {t('permissions.scope.editor')}
            </label>
            <textarea
              id={editorId}
              data-testid="textarea-scope-json"
              rows={8}
              value={text}
              aria-invalid={Boolean(error)}
              onChange={(e) => {
                setText(e.target.value);
                if (error) setError('');
              }}
              className={`w-full rounded-lg border bg-card p-3 font-mono text-xs text-ink focus:outline-none focus:ring-2 focus:ring-brand/20 ${error ? 'border-danger' : 'border-line focus:border-brand'}`}
            />
            {error && <p className="m-0 mt-1 text-sm text-danger">{error}</p>}
          </div>
        </div>
      )}
    </Modal>
  );
};

export default PermissionScopeDrawer;
