import React, { useId, useMemo, useState } from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { formatFullDateTime } from '../../../utils/format';
import { Button, Card, EmptyState, Spinner, Tabs } from '../../../components/ui';

const W = 800;
const H = 190;
const PAD_X = 40;
const TOP = 20;
const BASE = 155;
const SPAN = BASE - TOP;

const SERIES = [
  { key: 'auth', tone: 'text-warning' },
  { key: 'traffic', tone: 'text-info' },
  { key: 'exploit', tone: 'text-danger' },
  { key: 'resource', tone: 'text-brand' },
];

const PRESETS = ['10m', '1h', '24h', '7d', '30d'];
const WINDOW_MS = { '10m': 10 * 60e3, '1h': 60 * 60e3, '24h': 24 * 3600e3, '7d': 7 * 24 * 3600e3, '30d': 30 * 24 * 3600e3 };
const RELATIVE_TICKS = {
  '10m': { values: [-10, -8, -6, -4, -2, 0], unit: 'unitMinute' },
  '1h': { values: [-60, -45, -30, -15, 0], unit: 'unitMinute' },
  '24h': { values: [-24, -20, -16, -12, -8, -4, 0], unit: 'unitHour' },
  '7d': { values: [-6, -5, -4, -3, -2, -1, 0], unit: 'unitDay' },
  '30d': { values: [-30, -24, -18, -12, -6, 0], unit: 'unitDay' },
};

const yOf = (score) => BASE - (Math.min(100, Math.max(0, Number(score) || 0)) / 100) * SPAN;
const xAt = (ratio) => PAD_X + Math.min(1, Math.max(0, ratio)) * (W - 2 * PAD_X);

const scoreOf = (d, key) => {
  const vs = d.vectorScores || {};
  if (vs[key] !== undefined) return vs[key];
  if (key === 'auth') return d.failedLogins ? Math.min(100, d.failedLogins * 10) : 0;
  if (key === 'traffic') return d.requestsPerMin ? Math.min(100, Math.round(d.requestsPerMin / 30)) : 0;
  if (key === 'exploit') return d.malformedRequests ? Math.min(100, d.malformedRequests * 25) : 0;
  return Math.max(d.cpuPercent || 0, d.ramPercent || 0);
};

const buildChart = (history, range) => {
  const now = Date.now();
  const start = range.from ? new Date(range.from).getTime() : now - (WINDOW_MS[range.preset] || WINDOW_MS['10m']);
  const end = range.to ? new Date(range.to).getTime() : now;
  const total = Math.max(1000, end - start);
  const sorted = [...history].sort((a, b) => new Date(a.timestamp || 0) - new Date(b.timestamp || 0));
  const samples = sorted.map((d, i) => {
    const ts = d.timestamp ? new Date(d.timestamp).getTime() : NaN;
    const x = Number.isNaN(ts) ? xAt(sorted.length > 1 ? i / (sorted.length - 1) : 0.5) : xAt((ts - start) / total);
    const scores = Object.fromEntries(SERIES.map((s) => [s.key, scoreOf(d, s.key)]));
    return { x, time: d.timestamp, scores };
  });
  const paths = Object.fromEntries(
    SERIES.map((s) => [s.key, samples.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x.toFixed(1)} ${yOf(p.scores[s.key]).toFixed(1)}`).join(' ')])
  );
  return { samples, paths, start, total };
};

const buildTicks = (range, chart, t) => {
  if (range.from && range.to) {
    const long = chart.total > 24 * 3600e3;
    return {
      unit: long ? t('aiopsPage.trend.unitDay') : t('aiopsPage.trend.unitHour'),
      ticks: [0, 0.2, 0.4, 0.6, 0.8, 1].map((r) => {
        const d = new Date(chart.start + r * chart.total);
        const label = long ? `${d.getDate()}/${d.getMonth() + 1}` : `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
        return { x: xAt(r), label };
      }),
    };
  }
  const cfg = RELATIVE_TICKS[range.preset] || RELATIVE_TICKS['10m'];
  return {
    unit: t(`aiopsPage.trend.${cfg.unit}`),
    ticks: cfg.values.map((v, i) => ({ x: xAt(i / (cfg.values.length - 1)), label: String(v) })),
  };
};

const fieldClass =
  'h-9 rounded-lg border border-line bg-card px-3 text-sm text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';

const TrendSection = ({ ops }) => {
  const { t } = useLanguageSafe();
  const ids = useId();
  const [hover, setHover] = useState(null);
  const {
    historyData,
    vectorScores,
    timePreset,
    customRange,
    setCustomRange,
    handleSelectTimePreset,
    handleApplyCustomRange,
    handleClearCustomRange,
    fetchingHistory,
    activeVectorTab,
    setActiveVectorTab,
  } = ops;

  const preset = timePreset === 'realtime' ? '10m' : timePreset === 'day' ? '24h' : timePreset === 'month' ? '30d' : timePreset;
  const rangeFrom = customRange.applied && customRange.from && customRange.to ? customRange.from : '';
  const rangeTo = rangeFrom ? customRange.to : '';
  const range = useMemo(() => (rangeFrom ? { from: rangeFrom, to: rangeTo } : { preset }), [rangeFrom, rangeTo, preset]);
  const chart = useMemo(() => buildChart(historyData || [], range), [historyData, range]);
  const axis = buildTicks(range, chart, t);
  const visible = SERIES.filter((s) => activeVectorTab === 'all' || activeVectorTab === s.key);
  const hovered = hover !== null ? chart.samples[hover] : null;
  const empty = !historyData || historyData.length === 0;

  const tabs = [
    { key: 'all', label: t('aiopsPage.vector.all') },
    ...SERIES.map((s) => ({ key: s.key, label: t(`aiopsPage.vector.${s.key}`) })),
  ];

  return (
    <Card
      title={t('aiopsPage.trend.title')}
      actions={<Tabs ariaLabel={t('aiopsPage.trend.tabsLabel')} items={tabs} value={activeVectorTab} onChange={(key) => { setActiveVectorTab(key); setHover(null); }} />}
      padded
    >
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div role="group" aria-label={t('aiopsPage.trend.rangeLabel')} className="flex flex-wrap gap-2">
          {PRESETS.map((id) => {
            const selected = preset === id && !customRange.applied;
            return (
              <Button key={id} size="sm" variant={selected ? 'primary' : 'secondary'} aria-pressed={selected} onClick={() => handleSelectTimePreset(id)}>
                {t(`aiopsPage.trend.preset.${id}`)}
              </Button>
            );
          })}
        </div>
        <div className="flex flex-wrap items-end gap-2">
          <div>
            <label htmlFor={`${ids}-from`} className="mb-1 block text-sm font-medium text-ink">{t('aiopsPage.trend.from')}</label>
            <input id={`${ids}-from`} type="datetime-local" value={customRange.from} onChange={(e) => setCustomRange((prev) => ({ ...prev, from: e.target.value }))} className={fieldClass} />
          </div>
          <div>
            <label htmlFor={`${ids}-to`} className="mb-1 block text-sm font-medium text-ink">{t('aiopsPage.trend.to')}</label>
            <input id={`${ids}-to`} type="datetime-local" value={customRange.to} onChange={(e) => setCustomRange((prev) => ({ ...prev, to: e.target.value }))} className={fieldClass} />
          </div>
          <Button size="sm" variant="primary" onClick={handleApplyCustomRange}>{t('aiopsPage.trend.apply')}</Button>
          {customRange.applied && <Button size="sm" variant="ghost" onClick={handleClearCustomRange}>{t('aiopsPage.trend.clear')}</Button>}
        </div>
      </div>

      <ul className="m-0 mt-4 flex list-none flex-wrap gap-x-5 gap-y-2 p-0 text-sm">
        {SERIES.map((s) => (
          <li key={s.key} className="flex items-center gap-2 text-ink-muted">
            <span className={`h-2.5 w-2.5 rounded-full bg-current ${s.tone}`} />
            {t(`aiopsPage.vector.${s.key}`)}
            <span className="font-semibold tabular-nums text-ink">{vectorScores[s.key] ?? 0}</span>
          </li>
        ))}
        {fetchingHistory && (
          <li className="flex items-center gap-2 text-brand">
            <Spinner size="sm" />
            {t('aiopsPage.trend.loading')}
          </li>
        )}
      </ul>

      <div className="relative mt-3 w-full overflow-x-auto">
        {empty ? (
          <div className="py-6">
            <EmptyState
              icon="query_stats"
              title={t('aiopsPage.trend.emptyTitle')}
              action={!customRange.applied && preset !== '10m' ? <Button size="sm" onClick={() => handleSelectTimePreset('10m')}>{t('aiopsPage.trend.backTo10m')}</Button> : null}
            />
          </div>
        ) : (
          <div className="relative min-w-[640px]">
            <svg role="img" aria-label={t('aiopsPage.trend.title')} viewBox={`0 0 ${W} ${H}`} className="block h-auto w-full select-none" onMouseLeave={() => setHover(null)}>
              {[
                [85, 'stroke-danger', 'fill-danger'],
                [70, 'stroke-warning', 'fill-warning'],
              ].map(([v, stroke, fill]) => (
                <g key={v}>
                  <line x1={PAD_X} y1={yOf(v)} x2={W - PAD_X} y2={yOf(v)} className={stroke} strokeWidth="1" strokeDasharray="4 4" />
                  <text x={W - PAD_X + 6} y={yOf(v) + 4} fontSize="11" className={fill}>{v}</text>
                </g>
              ))}
              <line x1={PAD_X} y1={BASE} x2={W - PAD_X} y2={BASE} className="stroke-line" />
              {axis.ticks.map((tick) => (
                <text key={`${tick.x}-${tick.label}`} x={tick.x} y={BASE + 18} fontSize="11" textAnchor="middle" className="fill-ink-faint tabular-nums">{tick.label}</text>
              ))}
              <text x={W - PAD_X} y={BASE - 6} fontSize="11" textAnchor="end" className="fill-ink-faint">{axis.unit}</text>

              {visible.map((s) => (
                <g key={s.key} className={s.tone}>
                  <path d={chart.paths[s.key]} fill="none" stroke="currentColor" strokeWidth={activeVectorTab === s.key ? 2.5 : 2} strokeLinecap="round" strokeLinejoin="round" />
                  {chart.samples.map((p, i) => (
                    <circle key={i} cx={p.x} cy={yOf(p.scores[s.key])} r={hover === i ? 4.5 : p.scores[s.key] >= 70 ? 3.5 : 2} fill="currentColor" className="stroke-card" strokeWidth="1" />
                  ))}
                </g>
              ))}

              {chart.samples.map((p, i) => (
                <g key={`hit-${i}`}>
                  {hover === i && <line x1={p.x} y1={TOP} x2={p.x} y2={BASE} className="stroke-ink-faint" strokeDasharray="3 3" />}
                  <rect data-testid="trend-hit" x={p.x - 6} y={TOP - 10} width="12" height={SPAN + 10} fill="transparent" className="cursor-pointer" onMouseEnter={() => setHover(i)} />
                </g>
              ))}
            </svg>

            {hovered && (
              <div
                role="tooltip"
                className="pointer-events-none absolute top-1 z-10 min-w-52 -translate-x-1/2 rounded-lg border border-line bg-card p-3 text-sm shadow-lg"
                style={{ left: `${Math.min(85, Math.max(15, (hovered.x / W) * 100))}%` }}
              >
                <div className="mb-1.5 font-medium text-ink">{hovered.time ? formatFullDateTime(hovered.time) : '--'}</div>
                {SERIES.map((s) => (
                  <div key={s.key} className="flex items-center justify-between gap-4">
                    <span className="flex items-center gap-2 text-ink-muted">
                      <span className={`h-2 w-2 rounded-full bg-current ${s.tone}`} />
                      {t(`aiopsPage.vector.${s.key}`)}
                    </span>
                    <span className="font-semibold tabular-nums text-ink">{hovered.scores[s.key]}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </Card>
  );
};

export default TrendSection;
