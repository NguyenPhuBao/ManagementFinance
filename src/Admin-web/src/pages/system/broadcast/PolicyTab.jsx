import React, { useCallback, useEffect, useId, useState } from 'react';
import adminApi from '../../../api/admin.api';
import { useAlertSafe } from '../../../store/alert.context';
import { useLanguageSafe } from '../../../store/language.context';
import { formatDateTime } from '../../../utils/format';
import { Badge, Button, Card, DataTable, Modal, SecurityConfirmModal, Spinner } from '../../../components/ui';

const fieldClass =
  'w-full rounded-lg border border-line bg-card px-3 text-sm text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';

const NEW_POLICY = 'new';

/** Thêm chính sách: chọn chính sách có sẵn (tạo phiên bản kế tiếp) hoặc "Chính sách mới". Luôn tạo ở trạng thái Ngừng sử dụng. */
const AddPolicyModal = ({ documents, policies, onClose, onAdded }) => {
  const { t } = useLanguageSafe();
  const ids = useId();
  const [docId, setDocId] = useState(NEW_POLICY);
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [pinOpen, setPinOpen] = useState(false);
  const isNew = docId === NEW_POLICY;
  const ready = content.trim() && (!isNew || title.trim());
  const nextVersion = isNew ? 1 : Math.max(0, ...policies.filter((p) => String(p.policyId) === docId).map((p) => p.docVersion)) + 1;
  const payload = () => (isNew ? { title: title.trim(), content: content.trim() } : { documentId: Number(docId), content: content.trim() });

  return (
    <Modal
      open
      onClose={onClose}
      closeDisabled={pinOpen}
      size="lg"
      title={t('broadcast.policy.addTitle')}
      description={t('broadcast.policy.addDesc')}
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
          <label htmlFor={`${ids}-doc`} className="mb-1 block text-sm font-medium text-ink">
            {t('broadcast.policy.fieldPolicy')}
          </label>
          <select id={`${ids}-doc`} value={docId} onChange={(e) => setDocId(e.target.value)} className={`${fieldClass} h-10 cursor-pointer`}>
            <option value={NEW_POLICY}>{t('broadcast.policy.newPolicy')}</option>
            {documents.map((d) => (
              <option key={d.id} value={String(d.id)}>
                {d.title}
              </option>
            ))}
          </select>
          <p className="m-0 mt-1.5 text-sm text-ink-muted">
            {isNew ? t('broadcast.policy.willCreateNew') : t('broadcast.policy.willCreateVersion', { version: nextVersion })}
          </p>
        </div>
        {isNew && (
          <div>
            <label htmlFor={`${ids}-title`} className="mb-1 block text-sm font-medium text-ink">
              {t('broadcast.policy.fieldTitle')}
            </label>
            <input id={`${ids}-title`} maxLength={200} value={title} onChange={(e) => setTitle(e.target.value)} className={`${fieldClass} h-10`} />
          </div>
        )}
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
          onVerify={(credentials) => adminApi.publishPolicy({ ...payload(), ...credentials })}
          onConfirm={onAdded}
          title={t('broadcast.policy.confirmTitle')}
          description={t('broadcast.policy.confirmDesc')}
          confirmText={t('broadcast.policy.confirmBtn')}
          dangerLevel="primary"
        />
      )}
    </Modal>
  );
};

const policyLabel = (p) => `${p.title} v${p.docVersion}`;

const StatusBadge = ({ status }) => {
  const { t } = useLanguageSafe();
  return status === 'ACTIVE' ? <Badge tone="success">{t('broadcast.policy.statusActive')}</Badge> : <Badge tone="neutral">{t('broadcast.policy.statusInactive')}</Badge>;
};

const ViewPolicyModal = ({ policy, onClose }) => {
  const { t } = useLanguageSafe();
  return (
    <Modal open onClose={onClose} size="lg" title={policyLabel(policy)} footer={<Button onClick={onClose}>{t('common.close', 'Đóng')}</Button>}>
      <div className="flex flex-col gap-3">
        <div className="flex flex-wrap items-center gap-2 text-sm text-ink-muted">
          <StatusBadge status={policy.status} />
          <span>{t('broadcast.policy.publishedAt', { time: formatDateTime(policy.publishedAt) })}</span>
        </div>
        <div className="max-h-[60vh] overflow-y-auto whitespace-pre-wrap rounded-lg border border-line bg-muted p-4 text-sm text-ink">{policy.content}</div>
      </div>
    </Modal>
  );
};

const PolicyTab = () => {
  const { t } = useLanguageSafe();
  const notify = useAlertSafe();
  const headingId = useId();
  const [data, setData] = useState(null);
  const [adding, setAdding] = useState(false);
  const [viewing, setViewing] = useState(null);
  // { policy, status } — phiên bản đang chờ nhập PIN để đổi trạng thái
  const [changing, setChanging] = useState(null);

  const load = useCallback(async () => {
    try {
      const res = await adminApi.getPolicies();
      setData(res?.data || { policies: [], documents: [], activeUsers: 0 });
    } catch (err) {
      setData({ policies: [], documents: [], activeUsers: 0, error: err.response?.data?.message || t('broadcast.policy.loadFailed') });
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const policies = data?.policies || [];
  const active = policies.filter((p) => p.status === 'ACTIVE');
  const percent = (p) => (data?.activeUsers ? Math.min(100, Math.round((p.acceptedCount / data.activeUsers) * 100)) : 0);

  const added = () => {
    setAdding(false);
    if (notify) notify.success(t('broadcast.policy.added'));
    load();
  };

  const statusChanged = () => {
    const activating = changing?.status === 'ACTIVE';
    setChanging(null);
    if (notify) notify.success(t(activating ? 'broadcast.policy.activated' : 'broadcast.policy.deactivated'));
    load();
  };

  const columns = [
    { key: 'title', title: t('broadcast.policy.colPolicy'), render: (p) => <span className="font-medium text-ink">{p.title}</span> },
    { key: 'docVersion', title: t('broadcast.policy.colVersion'), width: '6rem', render: (p) => <span className="font-mono tabular-nums">v{p.docVersion}</span> },
    { key: 'status', title: t('broadcast.policy.colStatus'), render: (p) => <StatusBadge status={p.status} /> },
    { key: 'publishedAt', title: t('broadcast.policy.colPublishedAt'), render: (p) => <span className="whitespace-nowrap tabular-nums">{formatDateTime(p.publishedAt)}</span> },
    { key: 'acceptedCount', title: t('broadcast.policy.colAccepted'), render: (p) => <span className="tabular-nums">{p.acceptedCount}</span> },
    {
      key: 'actions',
      title: t('broadcast.policy.colActions'),
      align: 'right',
      render: (p) => (
        <div className="flex items-center justify-end gap-1">
          <Button variant="ghost" size="sm" icon="visibility" aria-label={t('broadcast.policy.view')} title={t('broadcast.policy.view')} onClick={() => setViewing(p)} />
          {p.status === 'ACTIVE' ? (
            <Button size="sm" variant="danger-ghost" icon="block" className="whitespace-nowrap" onClick={() => setChanging({ policy: p, status: 'INACTIVE' })}>
              {t('broadcast.policy.deactivateBtn')}
            </Button>
          ) : (
            <Button size="sm" variant="secondary" icon="check_circle" className="whitespace-nowrap" onClick={() => setChanging({ policy: p, status: 'ACTIVE' })}>
              {t('broadcast.policy.activateBtn')}
            </Button>
          )}
        </div>
      ),
    },
  ];

  const activating = changing?.status === 'ACTIVE';

  return (
    <div className="flex flex-col gap-5">
      <section aria-labelledby={headingId} className="rounded-xl border border-line bg-card">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line px-5 py-4">
          <h2 id={headingId} className="m-0 text-base font-semibold text-ink">
            {t('broadcast.policy.activeTitle')}
          </h2>
          <Button variant="primary" icon="add" onClick={() => setAdding(true)}>
            {t('broadcast.policy.addBtn')}
          </Button>
        </div>
        <div className="p-5">
          {data === null ? (
            <div className="flex justify-center py-6 text-brand">
              <Spinner />
            </div>
          ) : data.error ? (
            <p className="m-0 text-sm text-danger">{data.error}</p>
          ) : active.length === 0 ? (
            <p className="m-0 text-sm text-ink-muted">{t('broadcast.policy.emptyActive')}</p>
          ) : (
            <ul className="m-0 flex list-none flex-col gap-4 p-0">
              {active.map((p) => (
                <li key={p.version} className="flex flex-col gap-1.5">
                  <div className="flex flex-wrap items-center gap-2">
                    <Badge tone="info">v{p.docVersion}</Badge>
                    <span className="font-semibold text-ink">{p.title}</span>
                    <span className="text-sm text-ink-muted">{t('broadcast.policy.publishedAt', { time: formatDateTime(p.publishedAt) })}</span>
                  </div>
                  <p className="m-0 text-sm text-ink">{t('broadcast.policy.acceptedOf', { accepted: p.acceptedCount, total: data.activeUsers })}</p>
                  <div className="h-2 overflow-hidden rounded-full bg-muted">
                    <div className="h-full rounded-full bg-brand" style={{ width: `${percent(p)}%` }} />
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </section>

      <Card title={t('broadcast.policy.listTitle')}>
        <DataTable label={t('broadcast.policy.listTitle')} columns={columns} rows={policies} rowKey="version" loading={data === null} emptyTitle={t('broadcast.policy.empty')} minWidth={760} />
      </Card>

      {adding && <AddPolicyModal documents={data?.documents || []} policies={policies} onClose={() => setAdding(false)} onAdded={added} />}
      {viewing && <ViewPolicyModal policy={viewing} onClose={() => setViewing(null)} />}
      {changing && (
        <SecurityConfirmModal
          isOpen
          onClose={() => setChanging(null)}
          onVerify={(credentials) => adminApi.setPolicyStatus(changing.policy.version, { status: changing.status, ...credentials })}
          onConfirm={statusChanged}
          title={t(activating ? 'broadcast.policy.activateTitle' : 'broadcast.policy.deactivateTitle')}
          description={t(activating ? 'broadcast.policy.activateDesc' : 'broadcast.policy.deactivateDesc', { policy: policyLabel(changing.policy) })}
          confirmText={t(activating ? 'broadcast.policy.activateConfirm' : 'broadcast.policy.deactivateConfirm')}
          dangerLevel={activating ? 'primary' : 'critical'}
        />
      )}
    </div>
  );
};

export default PolicyTab;
