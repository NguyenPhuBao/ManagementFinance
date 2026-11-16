import React, { useEffect, useId, useState } from 'react';
import adminApi from '../../../api/admin.api';
import TruncateCell from '../../../components/common/TruncateCell';
import { useLanguageSafe } from '../../../store/language.context';
import { formatDateTime } from '../../../utils/format';
import { Badge, Button, Card, DataTable, Pagination } from '../../../components/ui';
import { HOUR, MIN_LEAD_HOURS, durationText } from './maintenanceFormat';

const STATUS_TONE = { ONGOING: 'warning', SCHEDULED: 'info', COMPLETED: 'success', CANCELLED: 'neutral' };
const TYPES = ['UPGRADE', 'EMERGENCY', 'SCHEDULED'];
const STATUSES = Object.keys(STATUS_TONE);

const selectClass = 'h-9 cursor-pointer rounded-lg border border-line bg-card px-3 pr-8 text-sm text-ink focus:border-brand focus:outline-none';

const parseRows = (res) => {
  const payload = res?.data !== undefined ? res.data : res;
  if (payload && Array.isArray(payload.data)) {
    const total = Number(payload.pagination?.total ?? payload.total ?? payload.data.length) || 0;
    return { rows: payload.data, total };
  }
  if (payload && Array.isArray(payload.items)) return { rows: payload.items, total: Number(payload.total ?? payload.items.length) || 0 };
  if (Array.isArray(payload)) return { rows: payload, total: payload.length };
  return { rows: [], total: 0 };
};

const MaintenanceHistory = ({ version, now, onCancel, busy }) => {
  const { t } = useLanguageSafe();
  const ids = useId();
  const [rows, setRows] = useState([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [limit, setLimit] = useState(5);
  const [type, setType] = useState('ALL');
  const [status, setStatus] = useState('ALL');

  useEffect(() => {
    let alive = true;
    setLoading(true);
    adminApi
      .getMaintenanceHistory({ page, limit, ...(type !== 'ALL' && { type }), ...(status !== 'ALL' && { status }) })
      .then((res) => {
        if (!alive) return;
        const parsed = parseRows(res);
        setRows(parsed.rows);
        setTotal(parsed.total);
      })
      .catch((err) => console.error('[MAINTENANCE] Lỗi tải lịch sử bảo trì:', err))
      .finally(() => alive && setLoading(false));
    return () => {
      alive = false;
    };
  }, [page, limit, type, status, version]);

  const columns = [
    { key: 'id', title: '#', width: '3.5rem', render: (r) => <span className="font-mono text-ink-faint">{r.id}</span> },
    {
      key: 'type',
      title: t('broadcast.history.colType'),
      render: (r) => (
        <Badge tone={r.type === 'EMERGENCY' ? 'danger' : 'info'}>{r.type === 'EMERGENCY' ? t('broadcast.history.typeEmergency') : t('broadcast.history.typeScheduled')}</Badge>
      ),
    },
    { key: 'user', title: t('broadcast.history.colUser'), render: (r) => <TruncateCell text={r.activated_by || 'system'} className="text-ink" /> },
    { key: 'reason', title: t('broadcast.history.colReason'), width: '24%', render: (r) => <div className="max-w-xs"><TruncateCell text={r.reason || '—'} className="text-ink" /></div> },
    { key: 'start', title: t('broadcast.history.colStart'), render: (r) => <span className="whitespace-nowrap text-ink-muted">{r.started_at ? formatDateTime(r.started_at) : '—'}</span> },
    {
      key: 'end',
      title: t('broadcast.history.colEnd'),
      render: (r) => {
        let text = '—';
        if (r.ended_at) text = r.status === 'CANCELLED' ? t('broadcast.history.cancelledAt', { time: formatDateTime(r.ended_at) }) : formatDateTime(r.ended_at);
        else if (r.status !== 'CANCELLED' && r.scheduled_end_at) text = t('broadcast.history.plannedEnd', { time: formatDateTime(r.scheduled_end_at) });
        return <span className="whitespace-nowrap text-ink-muted">{text}</span>;
      },
    },
    { key: 'duration', title: t('broadcast.history.colDuration'), render: (r) => <span className="whitespace-nowrap font-mono text-xs text-ink">{durationText(r, now, t)}</span> },
    { key: 'status', title: t('broadcast.history.colStatus'), render: (r) => <Badge tone={STATUS_TONE[r.status] || 'neutral'}>{t(`broadcast.history.status.${r.status}`, r.status)}</Badge> },
    {
      key: 'actions',
      title: t('broadcast.history.colActions'),
      align: 'right',
      render: (r) => {
        if (r.status !== 'SCHEDULED') return <span className="text-ink-faint">—</span>;
        const start = r.started_at ? new Date(r.started_at).getTime() : 0;
        if ((start - now) / HOUR < MIN_LEAD_HOURS) {
          return (
            <span className="whitespace-nowrap text-xs text-ink-faint" title={t('broadcast.history.cannotCancelHint')}>
              {t('broadcast.history.cannotCancel')}
            </span>
          );
        }
        return (
          <Button size="sm" variant="danger-ghost" icon="event_busy" className="whitespace-nowrap" disabled={busy} onClick={() => onCancel(r.id)}>
            {t('broadcast.schedule.cancelBtn')}
          </Button>
        );
      },
    },
  ];

  return (
    <Card
      title={t('broadcast.history.title')}
      actions={
        <>
          <label htmlFor={`${ids}-type`} className="sr-only">
            {t('broadcast.history.typeLabel')}
          </label>
          <select
            id={`${ids}-type`}
            value={type}
            onChange={(e) => {
              setType(e.target.value);
              setPage(1);
            }}
            className={selectClass}
          >
            <option value="ALL">{t('broadcast.history.filterAllType')}</option>
            {TYPES.map((v) => (
              <option key={v} value={v}>
                {t(`broadcast.history.type.${v}`)}
              </option>
            ))}
          </select>
          <label htmlFor={`${ids}-status`} className="sr-only">
            {t('broadcast.history.statusLabel')}
          </label>
          <select
            id={`${ids}-status`}
            value={status}
            onChange={(e) => {
              setStatus(e.target.value);
              setPage(1);
            }}
            className={selectClass}
          >
            <option value="ALL">{t('broadcast.history.filterAllStatus')}</option>
            {STATUSES.map((v) => (
              <option key={v} value={v}>
                {t(`broadcast.history.status.${v}`)}
              </option>
            ))}
          </select>
        </>
      }
    >
      <DataTable
        label={t('broadcast.history.title')}
        columns={columns}
        rows={rows}
        rowKey="id"
        loading={loading && rows.length === 0}
        emptyTitle={t('broadcast.history.empty')}
        minWidth={980}
      />
      <Pagination
        currentPage={page}
        pageSize={limit}
        total={total}
        pageSizeOptions={[5, 10, 20, 50]}
        onPageChange={setPage}
        onPageSizeChange={(size) => {
          setLimit(size);
          setPage(1);
        }}
        itemLabel={t('broadcast.history.itemLabel')}
      />
    </Card>
  );
};

export default MaintenanceHistory;
