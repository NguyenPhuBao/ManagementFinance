import React, { useEffect, useState } from 'react';
import { useNumberFormat } from '../../../utils/format';
import adminApi from '../../../api/admin.api';
import { useLanguageSafe } from '../../../store/language.context';
import { Badge, DataTable, Modal, Spinner, Tabs } from '../../../components/ui';

const selectClass =
  'h-9 cursor-pointer rounded-lg border border-line bg-card px-3 pr-8 text-sm text-ink focus:border-brand focus:outline-none';

const TONE_TEXT = { success: 'text-success', warning: 'text-warning', danger: 'text-danger' };
const TONE_BAR = { success: 'bg-success', warning: 'bg-warning', danger: 'bg-danger' };
export const availabilityTone = (pct) => (pct >= 99.5 ? 'success' : pct >= 95 ? 'warning' : 'danger');

const KIND_TONE = { EMERGENCY: 'danger', PLANNED: 'warning', UNPLANNED: 'danger', PLANNED_STOP: 'neutral' };

const formatDate = (iso) =>
  new Intl.DateTimeFormat('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh', day: '2-digit', month: '2-digit', year: 'numeric' }).format(new Date(iso));
const formatDateTime = (iso) =>
  new Intl.DateTimeFormat('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh', day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date(iso));

export const formatDuration = (sec, t) => {
  const s = Number(sec) || 0;
  if (s === 0) return t('dashboard.availability.durM', { m: 0 });
  if (s < 60) return t('dashboard.availability.durLt');
  const h = Math.floor(s / 3600);
  const m = Math.round((s % 3600) / 60);
  if (h === 0) return t('dashboard.availability.durM', { m });
  return m === 0 ? t('dashboard.availability.durH', { h }) : t('dashboard.availability.durHM', { h, m });
};

const queryOf = ({ kind, year, month, quarter }) =>
  kind === 'month' ? { period: 'month', year, month } : kind === 'quarter' ? { period: 'quarter', year, quarter } : { period: 'year', year };

/**
 * Chi tiết độ khả dụng theo kỳ lịch (tháng / quý / năm, giờ Việt Nam).
 * Mở từ thẻ "Độ khả dụng" trên dashboard; mặc định là tháng hiện tại.
 */
const AvailabilityModal = ({ open, onClose, initialYear, initialMonth }) => {
  const { t } = useLanguageSafe();
  const nf = useNumberFormat();
  const [sel, setSel] = useState({ kind: 'month', year: initialYear, month: initialMonth, quarter: Math.ceil(initialMonth / 3) });
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [failed, setFailed] = useState(false);
  const [years, setYears] = useState([initialYear]);

  useEffect(() => {
    if (!open) return undefined;
    let alive = true;
    setLoading(true);
    setFailed(false);
    adminApi
      .getAvailability(queryOf(sel))
      .then((res) => {
        if (!alive) return;
        const d = res?.data?.data || res?.data || null;
        setData(d);
        if (Array.isArray(d?.availableYears) && d.availableYears.length) setYears(d.availableYears);
      })
      .catch(() => alive && setFailed(true))
      .finally(() => alive && setLoading(false));
    return () => {
      alive = false;
    };
  }, [open, sel]);

  const update = (patch) => setSel((prev) => ({ ...prev, ...patch }));
  const yearOptions = years.includes(sel.year) ? years : [sel.year, ...years];
  const pct = typeof data?.percent === 'number' ? data.percent : null;
  const breakdown = data
    ? [
        ['planned', data.plannedMaintenanceSeconds],
        ['emergency', data.emergencyMaintenanceSeconds],
        ['unplanned', data.unplannedSeconds],
        ['plannedStop', data.plannedStopSeconds],
      ]
    : [];

  const columns = [
    { key: 'start', title: t('dashboard.availability.columns.time'), width: '8rem', render: (i) => <span className="whitespace-nowrap tabular-nums">{formatDateTime(i.start)}</span> },
    { key: 'kind', title: t('dashboard.availability.columns.kind'), render: (i) => <Badge tone={KIND_TONE[i.kind] || 'neutral'}>{t(`dashboard.availability.kinds.${i.kind}`)}</Badge> },
    {
      key: 'duration',
      title: t('dashboard.availability.columns.duration'),
      render: (i) => (
        <span className="whitespace-nowrap tabular-nums">
          {formatDuration(i.durationSeconds, t)}
          {i.ongoing ? ` (${t('dashboard.availability.ongoing')})` : ''}
        </span>
      ),
    },
    { key: 'reason', title: t('dashboard.availability.columns.reason'), render: (i) => <span className="text-ink-muted">{i.reason || '—'}</span> },
  ];

  return (
    <Modal open={open} onClose={onClose} title={t('dashboard.availability.title')} description={t('dashboard.availability.formula')} size="xl">
      <div className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center gap-2">
          <Tabs
            ariaLabel={t('dashboard.availability.kindLabel')}
            value={sel.kind}
            onChange={(kind) => update({ kind })}
            items={['month', 'quarter', 'year'].map((k) => ({ key: k, label: t(`dashboard.availability.${k}`) }))}
          />
          {sel.kind === 'month' && (
            <select aria-label={t('dashboard.availability.pickMonth')} className={selectClass} value={String(sel.month)} onChange={(e) => update({ month: Number(e.target.value) })}>
              {Array.from({ length: 12 }, (_, i) => i + 1).map((m) => (
                <option key={m} value={String(m)}>{t('dashboard.availability.monthOption', { n: m })}</option>
              ))}
            </select>
          )}
          {sel.kind === 'quarter' && (
            <select aria-label={t('dashboard.availability.pickQuarter')} className={selectClass} value={String(sel.quarter)} onChange={(e) => update({ quarter: Number(e.target.value) })}>
              {[1, 2, 3, 4].map((q) => (
                <option key={q} value={String(q)}>{t('dashboard.availability.quarterOption', { n: q })}</option>
              ))}
            </select>
          )}
          <select aria-label={t('dashboard.availability.pickYear')} className={selectClass} value={String(sel.year)} onChange={(e) => update({ year: Number(e.target.value) })}>
            {yearOptions.map((y) => (
              <option key={y} value={String(y)}>{y}</option>
            ))}
          </select>
          {loading && <span className="text-brand"><Spinner /></span>}
        </div>

        {failed && <p className="m-0 rounded-lg bg-warning-soft p-3 text-sm text-warning">{t('dashboard.availability.loadFailed')}</p>}

        {data && !failed && (
          <>
            {data.trackingAvailable === false && <p className="m-0 rounded-lg bg-warning-soft p-3 text-sm text-warning">{t('dashboard.availability.notTracking')}</p>}
            <div className="flex flex-wrap items-end gap-x-6 gap-y-2">
              {pct === null ? (
                <div className="text-lg font-semibold text-ink-muted">{t('dashboard.availability.noData')}</div>
              ) : (
                <div className={`text-3xl font-bold tabular-nums ${TONE_TEXT[availabilityTone(pct)]}`}>{nf.percent(pct, 2)}</div>
              )}
              {data.coverageFrom && pct !== null && (
                <div className="text-sm text-ink-muted">{t('dashboard.availability.coverageFrom', { date: formatDate(data.coverageFrom) })}</div>
              )}
            </div>

            <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
              {breakdown.map(([key, sec]) => (
                <div key={key} className="flex items-center justify-between gap-2 rounded-lg bg-muted px-3 py-2">
                  <span className="text-ink-muted">{t(`dashboard.availability.${key}`)}</span>
                  <span className="font-medium tabular-nums">{formatDuration(sec, t)}</span>
                </div>
              ))}
            </div>

            {Array.isArray(data.buckets) && data.buckets.length > 0 && (
              <div className="flex flex-col gap-1.5">
                <div className="text-xs font-medium text-ink-muted">
                  {t(data.period === 'month' ? 'dashboard.availability.byDay' : 'dashboard.availability.byMonth')}
                </div>
                <div className="flex h-12 items-end gap-0.5" role="img" aria-label={t(data.period === 'month' ? 'dashboard.availability.byDay' : 'dashboard.availability.byMonth')}>
                  {data.buckets.map((b) => {
                    const has = typeof b.percent === 'number';
                    return (
                      <div
                        key={`${b.label}-${b.start}`}
                        title={`${b.label}: ${has ? nf.percent(b.percent, 2) : '—'}`}
                        className={`flex-1 rounded-sm ${has ? TONE_BAR[availabilityTone(b.percent)] : 'bg-line'}`}
                        style={{ height: has ? `${Math.max(15, b.percent)}%` : '15%' }}
                      />
                    );
                  })}
                </div>
              </div>
            )}

            <div className="flex flex-col gap-2">
              <div className="text-sm font-semibold text-ink">{t('dashboard.availability.incidents')}</div>
              <DataTable
                columns={columns}
                rows={data.incidents || []}
                rowKey={(i, idx) => `${i.kind}-${i.start}-${idx}`}
                emptyTitle={t('dashboard.availability.noIncidents')}
                minWidth={560}
              />
            </div>
          </>
        )}
      </div>
    </Modal>
  );
};

export default AvailabilityModal;
