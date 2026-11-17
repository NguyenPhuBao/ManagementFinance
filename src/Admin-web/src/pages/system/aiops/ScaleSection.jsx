import React, { useId } from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { Badge, Button, Card, StatCard } from '../../../components/ui';
import { useNumberFormat } from '../../../utils/format';

const PRESETS = [500, 1000, 5000, 10000];

const REPORT_TONE = { OPTIMAL: 'success', WARNING: 'warning', OVER_CAPACITY: 'danger', INSUFFICIENT_DATA: 'neutral' };

// Báo cáo năng lực do Backend dựng (Luật sử dụng U = X × S); Admin-web chỉ hiển thị.
const CalibrationReport = ({ report }) => {
  const { t } = useLanguageSafe();
  const nf = useNumberFormat();
  const num = (n, opts) => (n === null || n === undefined ? '--' : nf.number(n, opts));
  const specs = report.serverSpecs || {};
  const cap = report.capacity || {};
  const mem = report.memory || {};
  const status = report.capacityAssessment?.status || cap.status || 'INSUFFICIENT_DATA';
  const quota = specs.effectiveCores === undefined || specs.effectiveCores === null
    ? '--'
    : t(specs.cpuQuotaHard ? 'aiopsPage.scale.quotaHard' : 'aiopsPage.scale.quotaSoft', { n: nf.number(specs.effectiveCores, { maxFrac: 2 }) });
  const rows = [
    [t('aiopsPage.scale.reportCpuQuota'), quota],
    [t('aiopsPage.scale.reportCpuPerReq'), cap.cpuMsPerRequest === null || cap.cpuMsPerRequest === undefined ? '--' : `${num(cap.cpuMsPerRequest, { maxFrac: 2 })} ms`],
    [t('aiopsPage.scale.reportMaxRpm'), cap.maxRpm === null || cap.maxRpm === undefined ? '--' : `${num(cap.maxRpm)} ${t('aiopsPage.unit.perMinute')}`],
    [t('aiopsPage.scale.reportAlertRpm'), cap.alertRpm === null || cap.alertRpm === undefined ? '--' : `${num(cap.alertRpm)} ${t('aiopsPage.unit.perMinute')}`],
    [t('aiopsPage.scale.reportUsers'), num(cap.estimatedMaxUsers)],
    [t('aiopsPage.scale.reportWindows'), num(cap.windows)],
    [t('aiopsPage.scale.reportRss'), mem.rssMb === undefined ? '--' : `${num(mem.rssMb)} / ${num(mem.ramLimitMb)} MB`],
    [t('aiopsPage.scale.reportHeap'), mem.heapUsedMb === undefined ? '--' : `${num(mem.heapUsedMb)} / ${num(mem.heapLimitMb)} MB`],
  ];
  return (
    <div className="mt-4 rounded-lg border border-line bg-muted p-4">
      <div className="flex flex-wrap items-center gap-2">
        <h3 className="m-0 text-sm font-semibold text-ink">{t('aiopsPage.scale.reportTitle')}</h3>
        <Badge tone={REPORT_TONE[status] || 'neutral'}>{t(`aiopsPage.scale.status.${status}`, status)}</Badge>
      </div>
      {report.capacityAssessment?.recommendation && <p className="m-0 mt-1 text-sm text-ink-muted">{report.capacityAssessment.recommendation}</p>}
      <dl className="m-0 mt-3 grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
        {rows.map(([label, value]) => (
          <div key={label}>
            <dt className="text-ink-faint">{label}</dt>
            <dd className="m-0 font-semibold tabular-nums text-ink">{value}</dd>
          </div>
        ))}
      </dl>
    </div>
  );
};

const ScaleSection = ({ ops }) => {
  const { t } = useLanguageSafe();
  const nf = useNumberFormat();
  const fmt = (n) => (n === null || n === undefined ? '--' : nf.number(n));
  const inputId = useId();
  const { targetConcurrency, customConcurrency, setCustomConcurrency, handleApplyScale, savingScale, calibrationReport, indicators } = ops;
  const traffic = indicators?.traffic;
  const sourceHint = traffic?.source ? t(`aiopsPage.scale.source.${traffic.source}`) : t('aiopsPage.unit.perMinute');

  return (
    <Card title={t('aiopsPage.scale.title')} padded>
      <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
        <div className="flex flex-wrap gap-2">
          {PRESETS.map((value) => (
            <Button
              key={value}
              size="sm"
              variant={targetConcurrency === value ? 'primary' : 'secondary'}
              aria-pressed={targetConcurrency === value}
              disabled={savingScale}
              onClick={() => {
                setCustomConcurrency(String(value));
                handleApplyScale(value);
              }}
            >
              {fmt(value)}
            </Button>
          ))}
        </div>
        <div className="flex items-end gap-2">
          <div>
            <label htmlFor={inputId} className="mb-1 block text-sm font-medium text-ink">
              {t('aiopsPage.scale.inputLabel')}
            </label>
            <input
              id={inputId}
              type="number"
              min="100"
              max="50000"
              step="100"
              value={customConcurrency}
              onChange={(e) => setCustomConcurrency(e.target.value)}
              className="h-9 w-40 rounded-lg border border-line bg-card px-3 text-sm tabular-nums text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20"
            />
          </div>
          <Button size="sm" variant="primary" loading={savingScale} onClick={() => handleApplyScale(customConcurrency)}>
            {t('aiopsPage.scale.apply')}
          </Button>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-3">
        <StatCard label={t('aiopsPage.scale.baseline')} value={fmt(traffic?.baselineRpm)} hint={sourceHint} />
        <StatCard label={t('aiopsPage.scale.alertRpm')} value={fmt(traffic?.alertRpm)} hint={t('aiopsPage.unit.perMinute')} />
        <StatCard label={t('aiopsPage.scale.ipThreshold')} value={fmt(indicators?.ipBurstPer10s)} hint={t('aiopsPage.unit.per10s')} />
      </div>

      {calibrationReport && <CalibrationReport report={calibrationReport} />}
    </Card>
  );
};

export default ScaleSection;
