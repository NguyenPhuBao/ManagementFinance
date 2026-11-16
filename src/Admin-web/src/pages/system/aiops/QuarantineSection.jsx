import React, { useEffect, useId, useMemo, useState } from 'react';
import aiopsApi from '../../../api/aiops.api';
import { useLanguageSafe } from '../../../store/language.context';
import { formatDateTime } from '../../../utils/format';
import { Badge, Button, Card, DataTable, Modal, Pagination, SecurityConfirmModal, Spinner, Tabs } from '../../../components/ui';
import { VECTOR_TONE, formatMinutes, lockState, maskIp } from './aiopsFormat';

const fieldClass =
  'w-full rounded-lg border border-line bg-card px-3 text-sm text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';
const DURATIONS = [60, 240, 720, 1440];

// Dòng còn hiệu lực khoá (IP hoặc tài khoản); dòng đã mở vẫn giữ trong danh sách để theo dõi.
const isActiveLock = (item) => {
  const s = lockState(item);
  return Boolean((s.ip && s.ip.kind !== 'unlocked') || (s.account && s.account.kind !== 'unlocked'));
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
  const set = (patch) => setForm((prev) => ({ ...prev, ...patch }));

  // Gửi qua hộp PIN chung; khoá xong thì đóng hộp này.
  const submit = (e) => {
    e.preventDefault();
    onSubmit(form, onClose);
  };

  return (
    <Modal
      open
      onClose={onClose}
      title={t('aiopsPage.manual.title')}
      description={t('aiopsPage.manual.desc')}
      footer={
        <>
          <Button onClick={onClose}>{t('common.cancel', 'Hủy bỏ')}</Button>
          <Button variant="danger" type="submit" form={`${ids}-form`}>{t('aiopsPage.manual.submit')}</Button>
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
  const { quarantineList, quarantineActions } = ops;
  const [lockFilter, setLockFilter] = useState('all');
  const [ipFilter, setIpFilter] = useState('');
  const [accountFilter, setAccountFilter] = useState('');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(5);
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
      const active = isActiveLock(item);
      const status = lockFilter === 'all' || (lockFilter === 'active' ? active : !active);
      return status && (!ipQ || ip.includes(ipQ)) && (!accQ || acc.includes(accQ));
    });
  }, [quarantineList, ipFilter, accountFilter, lockFilter]);
  const rows = filtered.slice((page - 1) * pageSize, page * pageSize);

  // Mỗi thao tác mở hộp PIN chung của trang (ops.quarantineActions).
  const ask = (kind, item) => {
    const hash = item.ipHash || item.hash;
    const masked = maskIp(item.maskedIp);
    if (kind.endsWith('Ip')) return quarantineActions[kind](hash, masked);
    return quarantineActions[kind](item.username, item.idaccount);
  };
  const released = (by, at) => (by ? (at ? t('aiopsPage.quarantine.releasedByAt', { by, time: formatDateTime(at) }) : t('aiopsPage.quarantine.releasedBy', { by })) : null);

  const columns = [
    {
      key: 'ip',
      title: 'IP',
      render: (item) => {
        const hash = item.ipHash || item.hash;
        if (!hash) return <span className="text-ink-faint">--</span>;
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
            {s.ip && <span>IP: {s.ip.kind === 'locked' ? formatMinutes(s.ip.minutes, t) : '--'}</span>}
            {s.ip?.kind === 'unlocked' && released(item.ipUnblockedBy, item.ipUnblockedAt) && <span className="text-xs text-ink-faint">{released(item.ipUnblockedBy, item.ipUnblockedAt)}</span>}
            {s.account && <span className="text-ink-muted">{t('aiopsPage.quarantine.accountShort')}: {s.account.kind === 'locked' ? formatMinutes(s.account.minutes, t) : '--'}</span>}
            {s.account?.kind === 'unlocked' && released(item.accountUnblockedBy, item.accountUnblockedAt) && <span className="text-xs text-ink-faint">{released(item.accountUnblockedBy, item.accountUnblockedAt)}</span>}
          </div>
        );
      },
    },
    {
      key: 'ipActions',
      title: t('aiopsPage.quarantine.colIpActions'),
      render: (item) => {
        const s = lockState(item);
        if (!s.ip) return <span className="text-ink-faint">--</span>;
        if (s.ip.kind === 'unlocked') return <Button size="sm" className="whitespace-nowrap" onClick={() => ask('blockIp', item)}>{t('aiopsPage.quarantine.blockIp')}</Button>;
        return (
          <div className="flex flex-wrap gap-1.5">
            <Button size="sm" className="whitespace-nowrap" onClick={() => ask('extendIp', item)}>{t('aiopsPage.quarantine.extendIp')}</Button>
            <Button size="sm" className="whitespace-nowrap" variant="ghost" onClick={() => ask('unblockIp', item)}>{t('aiopsPage.quarantine.unblockIp')}</Button>
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
        if (s.account.kind === 'permanent') {
          return (
            <div className="flex flex-wrap items-center gap-1.5">
              <Badge tone="danger">{t('aiopsPage.quarantine.banned')}</Badge>
              <Button size="sm" className="whitespace-nowrap" variant="ghost" onClick={() => ask('unblockAccount', item)}>{t('aiopsPage.quarantine.unblockAccount')}</Button>
            </div>
          );
        }
        if (s.account.kind === 'unlocked') return <Button size="sm" className="whitespace-nowrap" onClick={() => ask('blockAccount', item)}>{t('aiopsPage.quarantine.blockAccount')}</Button>;
        return (
          <div className="flex flex-wrap gap-1.5">
            <Button size="sm" className="whitespace-nowrap" variant="danger-ghost" onClick={() => ask('banAccount', item)}>{t('aiopsPage.quarantine.banAccount')}</Button>
            <Button size="sm" className="whitespace-nowrap" variant="ghost" onClick={() => ask('unblockAccount', item)}>{t('aiopsPage.quarantine.unblockAccount')}</Button>
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
            {hash && <Button size="sm" className="whitespace-nowrap" variant="ghost" icon="visibility" aria-label={t('aiopsPage.quarantine.reveal')} disabled={Boolean(revealed[hash])} onClick={() => setRevealTarget(hash)} />}
            <Button size="sm" className="whitespace-nowrap" variant="ghost" icon="policy" aria-label={t('aiopsPage.forensics.title')} onClick={() => setForensics({ ipHash: hash, maskedIp: maskIp(item.maskedIp), username: s.account ? s.accountLabel : null })} />
          </div>
        );
      },
    },
  ];

  const filtering = ipFilter || accountFilter;
  const lockTabs = [
    { key: 'all', label: t('aiopsPage.quarantine.lockAll') },
    { key: 'active', label: t('aiopsPage.quarantine.lockActive') },
    { key: 'released', label: t('aiopsPage.quarantine.lockReleased') },
  ];

  return (
    <Card
      title={t('aiopsPage.quarantine.title')}
      actions={<Button variant="danger" size="sm" icon="lock_clock" onClick={() => setManualOpen(true)}>{t('aiopsPage.manual.title')}</Button>}
    >
      <div className="flex flex-wrap items-end gap-3 border-b border-line px-5 py-4">
        <Tabs ariaLabel={t('aiopsPage.quarantine.lockFilter')} items={lockTabs} value={lockFilter} onChange={(key) => { setLockFilter(key); setPage(1); }} />
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
