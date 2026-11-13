import React, { useEffect, useId, useMemo, useState } from 'react';
import aiopsApi from '../../../api/aiops.api';
import { useLanguageSafe } from '../../../store/language.context';
import { formatDateTime } from '../../../utils/format';
import { Badge, Button, Card, ConfirmModal, DataTable, Modal, Pagination, SecurityConfirmModal, Spinner, Tabs } from '../../../components/ui';
import { VECTOR_TONE, formatMinutes, lockState, maskIp } from './aiopsFormat';

const fieldClass =
  'w-full rounded-lg border border-line bg-card px-3 text-sm text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';
const DURATIONS = [60, 240, 720, 1440];

const ACTIONS = {
  blockIp: { title: 'blockIpTitle', msg: 'blockIpMsg', confirm: 'blockIpConfirm' },
  extendIp: { title: 'extendIpTitle', msg: 'extendIpMsg', confirm: 'extendIpConfirm' },
  unblockIp: { title: 'unblockIpTitle', msg: 'unblockIpMsg', confirm: 'unblockConfirm' },
  blockAccount: { title: 'blockAccountTitle', msg: 'blockAccountMsg', confirm: 'blockIpConfirm' },
  banAccount: { title: 'banAccountTitle', msg: 'banAccountMsg', confirm: 'banAccountConfirm', danger: true },
  unblockAccount: { title: 'unblockAccountTitle', msg: 'unblockAccountMsg', confirm: 'unblockConfirm' },
};

const ForensicsModal = ({ target, onClose }) => {
  const { t } = useLanguageSafe();
  const [filter, setFilter] = useState('all');
  const [page, setPage] = useState(1);
  const [state, setState] = useState({ loading: true, rows: [], total: 0 });
  const hasAccount = Boolean(target.username);

  useEffect(() => {
    let alive = true;
    const params = { page, limit: 5 };
    if (filter === 'username') params.username = target.username;
    else if (filter === 'ip' || target.ipHash) params.ipHash = target.ipHash;
    else if (hasAccount) params.username = target.username;
    setState((prev) => ({ ...prev, loading: true }));
    Promise.resolve(aiopsApi.getForensics(params))
      .then((res) => {
        const data = res?.data || res || {};
        const rows = Array.isArray(data.incidents) ? data.incidents : Array.isArray(data) ? data : [];
        if (alive) setState({ loading: false, rows, total: typeof data.total === 'number' ? data.total : rows.length });
      })
      .catch(() => alive && setState({ loading: false, rows: [], total: 0 }));
    return () => {
      alive = false;
    };
  }, [filter, page, target.ipHash, target.username, hasAccount]);

  const tabs = [
    { key: 'all', label: t('aiopsPage.forensics.all') },
    ...(target.ipHash ? [{ key: 'ip', label: t('aiopsPage.forensics.byIp') }] : []),
    ...(hasAccount ? [{ key: 'username', label: t('aiopsPage.forensics.byAccount') }] : []),
  ];
  const columns = [
    { key: 'code', title: t('aiopsPage.forensics.colCode'), render: (r) => <span className="font-mono font-medium text-ink">{r.incident_code || `#${r.id}`}</span> },
    { key: 'time', title: t('aiopsPage.forensics.colTime'), render: (r) => <span className="tabular-nums">{r.detected_at ? formatDateTime(r.detected_at) : '--'}</span> },
    { key: 'hash', title: t('aiopsPage.forensics.colHash'), render: (r) => <span className="font-mono text-ink-muted">{r.ip_hash ? `${r.ip_hash.slice(0, 10)}…` : '--'}</span> },
    { key: 'user', title: t('aiopsPage.forensics.colAccount'), render: (r) => r.username || '--' },
    { key: 'reason', title: t('aiopsPage.forensics.colReason'), render: (r) => r.reason || '--' },
  ];

  return (
    <Modal
      open
      onClose={onClose}
      size="lg"
      title={t('aiopsPage.forensics.title')}
      description={[target.maskedIp, target.username].filter(Boolean).join(' · ')}
      footer={
        <>
          <span className="mr-auto text-sm text-ink-muted">{t('aiopsPage.forensics.total', { n: state.total })}</span>
          <Button onClick={onClose}>{t('common.close', 'Đóng')}</Button>
        </>
      }
    >
      <div className="mb-3">
        <Tabs ariaLabel={t('aiopsPage.forensics.filter')} items={tabs} value={filter} onChange={(key) => { setFilter(key); setPage(1); }} />
      </div>
      {state.loading ? (
        <div className="flex justify-center py-8 text-brand">
          <Spinner />
        </div>
      ) : (
        <DataTable label={t('aiopsPage.forensics.title')} columns={columns} rows={state.rows} rowKey={(r, i) => r.id ?? i} emptyTitle={t('aiopsPage.forensics.empty')} minWidth={640} />
      )}
      {state.total > 5 && <Pagination currentPage={page} pageSize={5} total={state.total} pageSizeOptions={[5]} onPageChange={setPage} />}
    </Modal>
  );
};

const ManualQuarantineModal = ({ onClose, onSubmit }) => {
  const { t } = useLanguageSafe();
  const ids = useId();
  const [form, setForm] = useState({ targetType: 'ip', ipValue: '', accountValue: '', reason: t('aiopsPage.manual.defaultReason'), durationMinutes: 240 });
  const [saving, setSaving] = useState(false);
  const set = (patch) => setForm((prev) => ({ ...prev, ...patch }));

  const submit = async (e) => {
    e.preventDefault();
    setSaving(true);
    const ok = await onSubmit(form);
    setSaving(false);
    if (ok) onClose();
  };

  return (
    <Modal
      open
      onClose={onClose}
      closeDisabled={saving}
      title={t('aiopsPage.manual.title')}
      description={t('aiopsPage.manual.desc')}
      footer={
        <>
          <Button onClick={onClose} disabled={saving}>{t('common.cancel', 'Hủy bỏ')}</Button>
          <Button variant="danger" type="submit" form={`${ids}-form`} loading={saving}>{t('aiopsPage.manual.submit')}</Button>
        </>
      }
    >
      <form id={`${ids}-form`} onSubmit={submit} className="flex flex-col gap-4">
        <Tabs
          ariaLabel={t('aiopsPage.manual.typeLabel')}
          items={[
            { key: 'ip', label: t('aiopsPage.manual.typeIp') },
            { key: 'account', label: t('aiopsPage.manual.typeAccount') },
          ]}
          value={form.targetType}
          onChange={(key) => set({ targetType: key })}
        />
        {form.targetType === 'ip' ? (
          <div>
            <label htmlFor={`${ids}-ip`} className="mb-1 block text-sm font-medium text-ink">{t('aiopsPage.manual.ipLabel')}</label>
            <input id={`${ids}-ip`} value={form.ipValue} onChange={(e) => set({ ipValue: e.target.value })} className={`${fieldClass} h-10 font-mono`} />
          </div>
        ) : (
          <div>
            <label htmlFor={`${ids}-acc`} className="mb-1 block text-sm font-medium text-ink">{t('aiopsPage.manual.accountLabel')}</label>
            <input id={`${ids}-acc`} value={form.accountValue} onChange={(e) => set({ accountValue: e.target.value })} className={`${fieldClass} h-10`} />
          </div>
        )}
        <div>
          <label htmlFor={`${ids}-dur`} className="mb-1 block text-sm font-medium text-ink">{t('aiopsPage.manual.duration')}</label>
          <select id={`${ids}-dur`} value={form.durationMinutes} onChange={(e) => set({ durationMinutes: Number(e.target.value) })} className={`${fieldClass} h-10 pr-8`}>
            {DURATIONS.map((m) => (
              <option key={m} value={m}>{formatMinutes(m, t)}</option>
            ))}
          </select>
        </div>
        <div>
          <label htmlFor={`${ids}-reason`} className="mb-1 block text-sm font-medium text-ink">{t('aiopsPage.manual.reason')}</label>
          <textarea id={`${ids}-reason`} rows={2} value={form.reason} onChange={(e) => set({ reason: e.target.value })} className={`${fieldClass} py-2`} />
        </div>
      </form>
    </Modal>
  );
};

const QuarantineSection = ({ ops }) => {
  const { t } = useLanguageSafe();
  const ids = useId();
  const { quarantineList, actionLoading, quarantineActions } = ops;
  const [ipFilter, setIpFilter] = useState('');
  const [accountFilter, setAccountFilter] = useState('');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(5);
  const [pending, setPending] = useState(null);
  const [revealTarget, setRevealTarget] = useState(null);
  const [revealed, setRevealed] = useState({});
  const [forensics, setForensics] = useState(null);
  const [manualOpen, setManualOpen] = useState(false);

  const filtered = useMemo(() => {
    const ipQ = ipFilter.trim().toLowerCase();
    const accQ = accountFilter.trim().toLowerCase();
    return quarantineList.filter((item) => {
      const ip = String(item.maskedIp || item.hash || '').toLowerCase();
      const acc = String(item.username || item.idaccount || '').toLowerCase();
      return (!ipQ || ip.includes(ipQ)) && (!accQ || acc.includes(accQ));
    });
  }, [quarantineList, ipFilter, accountFilter]);
  const rows = filtered.slice((page - 1) * pageSize, page * pageSize);

  const ask = (kind, item, label) => setPending({ kind, item, label });
  const runPending = async () => {
    const { kind, item } = pending;
    const hash = item.ipHash || item.hash;
    const masked = maskIp(item.maskedIp);
    const map = {
      blockIp: () => quarantineActions.blockIp(hash, masked),
      extendIp: () => quarantineActions.extendIp(hash, masked),
      unblockIp: () => quarantineActions.unblockIp(hash, masked),
      blockAccount: () => quarantineActions.blockAccount(item.username, item.idaccount),
      banAccount: () => quarantineActions.banAccount(item.username, item.idaccount),
      unblockAccount: () => quarantineActions.unblockAccount(item.username, item.idaccount),
    };
    const ok = await map[kind]();
    if (ok) setPending(null);
  };

  const columns = [
    {
      key: 'ip',
      title: 'IP',
      render: (item) => {
        const hash = item.ipHash || item.hash;
        return <span className="font-mono text-ink">{revealed[hash] || maskIp(item.maskedIp)}</span>;
      },
    },
    { key: 'account', title: t('aiopsPage.quarantine.colAccount'), render: (item) => lockState(item).accountLabel || '--' },
    { key: 'vector', title: t('aiopsPage.incidents.colVector'), render: (item) => <Badge tone={VECTOR_TONE[item.vector || 'auth'] || 'neutral'}>{t(`aiopsPage.vector.${item.vector || 'auth'}`)}</Badge> },
    { key: 'reason', title: t('aiopsPage.quarantine.colReason'), render: (item) => <span className="line-clamp-2 text-ink" title={item.reason}>{item.reason || '--'}</span> },
    { key: 'time', title: t('aiopsPage.quarantine.colTime'), render: (item) => <span className="tabular-nums">{item.bannedAt ? formatDateTime(item.bannedAt) : '--'}</span> },
    {
      key: 'remaining',
      title: t('aiopsPage.quarantine.colRemaining'),
      render: (item) => {
        const s = lockState(item);
        return (
          <div className="flex flex-col text-sm tabular-nums">
            <span>IP: {s.ip.kind === 'locked' ? formatMinutes(s.ip.minutes, t) : '--'}</span>
            <span className="text-ink-muted">{t('aiopsPage.quarantine.accountShort')}: {s.account?.kind === 'locked' ? formatMinutes(s.account.minutes, t) : '--'}</span>
          </div>
        );
      },
    },
    {
      key: 'ipActions',
      title: t('aiopsPage.quarantine.colIpActions'),
      render: (item) => {
        const s = lockState(item);
        const hash = item.ipHash || item.hash;
        const busy = actionLoading === `ip:${hash}`;
        if (s.ip.kind === 'permanent') return <Badge tone="danger">{t('aiopsPage.quarantine.ipBlocked')}</Badge>;
        if (s.ip.kind === 'unlocked') return <Button size="sm" className="whitespace-nowrap" loading={busy} onClick={() => ask('blockIp', item, maskIp(item.maskedIp))}>{t('aiopsPage.quarantine.blockIp')}</Button>;
        return (
          <div className="flex flex-wrap gap-1.5">
            <Button size="sm" className="whitespace-nowrap" loading={busy} onClick={() => ask('extendIp', item, maskIp(item.maskedIp))}>{t('aiopsPage.quarantine.extendIp')}</Button>
            <Button size="sm" className="whitespace-nowrap" variant="ghost" disabled={busy} onClick={() => ask('unblockIp', item, maskIp(item.maskedIp))}>{t('aiopsPage.quarantine.unblockIp')}</Button>
          </div>
        );
      },
    },
    {
      key: 'accountActions',
      title: t('aiopsPage.quarantine.colAccountActions'),
      render: (item) => {
        const s = lockState(item);
        if (!s.account) return <span className="text-ink-faint">--</span>;
        const busy = actionLoading === `acc:${item.username || item.idaccount}`;
        if (s.account.kind === 'permanent') return <Badge tone="danger">{t('aiopsPage.quarantine.banned')}</Badge>;
        if (s.account.kind === 'unlocked') return <Button size="sm" className="whitespace-nowrap" loading={busy} onClick={() => ask('blockAccount', item, s.accountLabel)}>{t('aiopsPage.quarantine.blockAccount')}</Button>;
        return (
          <div className="flex flex-wrap gap-1.5">
            <Button size="sm" className="whitespace-nowrap" variant="danger-ghost" loading={busy} onClick={() => ask('banAccount', item, s.accountLabel)}>{t('aiopsPage.quarantine.banAccount')}</Button>
            <Button size="sm" className="whitespace-nowrap" variant="ghost" disabled={busy} onClick={() => ask('unblockAccount', item, s.accountLabel)}>{t('aiopsPage.quarantine.unblockAccount')}</Button>
          </div>
        );
      },
    },
    {
      key: 'tools',
      title: '',
      render: (item) => {
        const hash = item.ipHash || item.hash;
        const s = lockState(item);
        return (
          <div className="flex gap-1">
            <Button size="sm" className="whitespace-nowrap" variant="ghost" icon="visibility" aria-label={t('aiopsPage.quarantine.reveal')} disabled={Boolean(revealed[hash])} onClick={() => setRevealTarget(hash)} />
            <Button size="sm" className="whitespace-nowrap" variant="ghost" icon="policy" aria-label={t('aiopsPage.forensics.title')} onClick={() => setForensics({ ipHash: hash, maskedIp: maskIp(item.maskedIp), username: s.account ? s.accountLabel : null })} />
          </div>
        );
      },
    },
  ];

  const action = pending ? ACTIONS[pending.kind] : null;
  const filtering = ipFilter || accountFilter;

  return (
    <Card
      title={t('aiopsPage.quarantine.title')}
      actions={<Button variant="danger" size="sm" icon="lock_clock" onClick={() => setManualOpen(true)}>{t('aiopsPage.manual.title')}</Button>}
    >
      <div className="flex flex-wrap items-end gap-3 border-b border-line px-5 py-4">
        <div className="w-full sm:w-56">
          <label htmlFor={`${ids}-ip`} className="mb-1 block text-sm font-medium text-ink">{t('aiopsPage.quarantine.filterIp')}</label>
          <input id={`${ids}-ip`} value={ipFilter} onChange={(e) => { setIpFilter(e.target.value); setPage(1); }} className={`${fieldClass} h-9`} />
        </div>
        <div className="w-full sm:w-56">
          <label htmlFor={`${ids}-acc`} className="mb-1 block text-sm font-medium text-ink">{t('aiopsPage.quarantine.filterAccount')}</label>
          <input id={`${ids}-acc`} value={accountFilter} onChange={(e) => { setAccountFilter(e.target.value); setPage(1); }} className={`${fieldClass} h-9`} />
        </div>
        {filtering && (
          <Button size="sm" className="whitespace-nowrap" variant="ghost" icon="close" onClick={() => { setIpFilter(''); setAccountFilter(''); setPage(1); }}>
            {t('aiopsPage.quarantine.clearFilter')}
          </Button>
        )}
      </div>
      <DataTable
        label={t('aiopsPage.quarantine.title')}
        columns={columns}
        rows={rows}
        rowKey={(row, i) => `${row.id || row.ipHash || row.hash}-${row.username || ''}-${i}`}
        emptyTitle={quarantineList.length === 0 ? t('aiopsPage.quarantine.empty') : t('aiopsPage.quarantine.noMatch')}
        minWidth={1080}
      />
      {filtered.length > 0 && (
        <Pagination
          currentPage={page}
          pageSize={pageSize}
          total={filtered.length}
          pageSizeOptions={[5, 10, 20]}
          onPageChange={setPage}
          onPageSizeChange={(size) => {
            setPageSize(size);
            setPage(1);
          }}
          itemLabel={t('aiopsPage.quarantine.itemLabel')}
        />
      )}

      <ConfirmModal
        open={Boolean(pending)}
        onCancel={() => setPending(null)}
        onConfirm={runPending}
        loading={Boolean(pending) && Boolean(actionLoading)}
        confirmDanger={Boolean(action?.danger)}
        title={action ? t(`aiopsPage.quarantine.${action.title}`, { target: pending.label }) : ''}
        message={action ? t(`aiopsPage.quarantine.${action.msg}`) : ''}
        confirmText={action ? t(`aiopsPage.quarantine.${action.confirm}`) : ''}
      />

      {revealTarget && (
        <SecurityConfirmModal
          isOpen
          onClose={() => setRevealTarget(null)}
          onVerify={async (credentials) => {
            const res = await aiopsApi.revealQuarantineIp(revealTarget, credentials);
            const ip = res?.data?.data?.ip || res?.data?.ip || res?.ip;
            if (!ip) throw new Error(t('aiopsPage.quarantine.revealMissing'));
            setRevealed((prev) => ({ ...prev, [revealTarget]: ip }));
          }}
          title={t('aiopsPage.quarantine.revealTitle')}
          description={t('aiopsPage.quarantine.revealDesc')}
          confirmText={t('aiopsPage.quarantine.revealConfirm')}
          dangerLevel="primary"
        />
      )}
      {forensics && <ForensicsModal target={forensics} onClose={() => setForensics(null)} />}
      {manualOpen && <ManualQuarantineModal onClose={() => setManualOpen(false)} onSubmit={ops.manualQuarantine} />}
    </Card>
  );
};

export default QuarantineSection;
