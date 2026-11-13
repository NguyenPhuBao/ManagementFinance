import React, { useCallback, useEffect, useId, useState } from 'react';
import adminApi from '../../../api/admin.api';
import { useAlertSafe } from '../../../store/alert.context';
import { useLanguageSafe } from '../../../store/language.context';
import { formatDateTime } from '../../../utils/format';
import { Badge, Button, Card, DataTable, Modal, SecurityConfirmModal, Spinner } from '../../../components/ui';

const fieldClass =
  'w-full rounded-lg border border-line bg-card px-3 text-sm text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';

const PublishModal = ({ onClose, onPublished }) => {
  const { t } = useLanguageSafe();
  const ids = useId();
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [pinOpen, setPinOpen] = useState(false);
  const ready = title.trim() && content.trim();

  return (
    <Modal
      open
      onClose={onClose}
      closeDisabled={pinOpen}
      size="lg"
      title={t('broadcast.policy.publishTitle')}
      description={t('broadcast.policy.publishDesc')}
      footer={
        <>
          <Button onClick={onClose}>{t('common.cancel', 'Hủy bỏ')}</Button>
          <Button variant="primary" disabled={!ready} onClick={() => setPinOpen(true)}>
            {t('broadcast.policy.next')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        <div>
          <label htmlFor={`${ids}-title`} className="mb-1 block text-sm font-medium text-ink">
            {t('broadcast.policy.fieldTitle')}
          </label>
          <input id={`${ids}-title`} maxLength={200} value={title} onChange={(e) => setTitle(e.target.value)} className={`${fieldClass} h-10`} />
        </div>
        <div>
          <label htmlFor={`${ids}-content`} className="mb-1 block text-sm font-medium text-ink">
            {t('broadcast.policy.fieldContent')}
          </label>
          <textarea id={`${ids}-content`} rows={14} value={content} onChange={(e) => setContent(e.target.value)} className={`${fieldClass} py-2 font-mono`} />
        </div>
      </div>
      {pinOpen && (
        <SecurityConfirmModal
          isOpen
          onClose={() => setPinOpen(false)}
          onVerify={(credentials) => adminApi.publishPolicy({ title: title.trim(), content: content.trim(), ...credentials })}
          onConfirm={onPublished}
          title={t('broadcast.policy.confirmTitle')}
          description={t('broadcast.policy.confirmDesc')}
          confirmText={t('broadcast.policy.confirmBtn')}
          dangerLevel="primary"
        />
      )}
    </Modal>
  );
};

const PolicyTab = () => {
  const { t } = useLanguageSafe();
  const notify = useAlertSafe();
  const headingId = useId();
  const [data, setData] = useState(null);
  const [publishing, setPublishing] = useState(false);

  const load = useCallback(async () => {
    try {
      const res = await adminApi.getPolicies();
      setData(res?.data || { policies: [], activeUsers: 0 });
    } catch (err) {
      setData({ policies: [], activeUsers: 0, error: err.response?.data?.message || t('broadcast.policy.loadFailed') });
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const policies = data?.policies || [];
  const current = policies[0];
  const percent = current && data.activeUsers ? Math.min(100, Math.round((current.acceptedCount / data.activeUsers) * 100)) : 0;

  const published = () => {
    setPublishing(false);
    if (notify) notify.success(t('broadcast.policy.published'));
    load();
  };

  const columns = [
    { key: 'version', title: t('broadcast.policy.colVersion'), width: '6rem', render: (p) => <span className="font-mono tabular-nums">v{p.version}</span> },
    { key: 'title', title: t('broadcast.policy.colTitle'), render: (p) => <span className="font-medium text-ink">{p.title}</span> },
    { key: 'publishedAt', title: t('broadcast.policy.colPublishedAt'), render: (p) => <span className="tabular-nums">{formatDateTime(p.publishedAt)}</span> },
    { key: 'acceptedCount', title: t('broadcast.policy.colAccepted'), render: (p) => <span className="tabular-nums">{p.acceptedCount}</span> },
  ];

  return (
    <div className="flex flex-col gap-5">
      <section aria-labelledby={headingId} className="rounded-xl border border-line bg-card">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line px-5 py-4">
          <h2 id={headingId} className="m-0 text-base font-semibold text-ink">
            {t('broadcast.policy.currentTitle')}
          </h2>
          <Button variant="primary" icon="add" onClick={() => setPublishing(true)}>
            {t('broadcast.policy.publishBtn')}
          </Button>
        </div>
        <div className="p-5">
          {data === null ? (
            <div className="flex justify-center py-6 text-brand">
              <Spinner />
            </div>
          ) : data.error ? (
            <p className="m-0 text-sm text-danger">{data.error}</p>
          ) : !current ? (
            <p className="m-0 text-sm text-ink-muted">{t('broadcast.policy.empty')}</p>
          ) : (
            <div className="flex flex-col gap-4">
              <div className="flex flex-wrap items-center gap-2">
                <Badge tone="info">v{current.version}</Badge>
                <h3 className="m-0 text-base font-semibold text-ink">{current.title}</h3>
                <span className="text-sm text-ink-muted">{t('broadcast.policy.publishedAt', { time: formatDateTime(current.publishedAt) })}</span>
              </div>
              <div>
                <p className="m-0 mb-1.5 text-sm text-ink">
                  {t('broadcast.policy.acceptedOf', { accepted: current.acceptedCount, total: data.activeUsers })}
                </p>
                <div className="h-2 overflow-hidden rounded-full bg-muted">
                  <div className="h-full rounded-full bg-brand" style={{ width: `${percent}%` }} />
                </div>
              </div>
              <div className="max-h-80 overflow-y-auto whitespace-pre-wrap rounded-lg border border-line bg-muted p-4 text-sm text-ink">{current.content}</div>
            </div>
          )}
        </div>
      </section>

      <Card title={t('broadcast.policy.historyTitle')}>
        <DataTable label={t('broadcast.policy.historyTitle')} columns={columns} rows={policies} rowKey="version" loading={data === null} emptyTitle={t('broadcast.policy.empty')} minWidth={560} />
      </Card>

      {publishing && <PublishModal onClose={() => setPublishing(false)} onPublished={published} />}
    </div>
  );
};

export default PolicyTab;
