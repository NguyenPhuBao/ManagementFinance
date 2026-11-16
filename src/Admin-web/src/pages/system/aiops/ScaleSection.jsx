import React, { useId } from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { Badge, Button, Card, StatCard } from '../../../components/ui';

const PRESETS = [500, 1000, 5000, 10000];
const fmt = (n) => Number(n || 0).toLocaleString('vi-VN');

const REPORT_TONE = (assessment) => {
  if (assessment?.isOverCapacity) return 'danger';
  if (assessment?.isNearLimit) return 'warning';
  return 'success';
};

const CalibrationReport = ({ report }) => {
  const { t } = useLanguageSafe();
  const specs = report.serverSpecs || {};
  const metrics = report.calculatedMetrics || {};
  return (
    <div className="mt-4 rounded-lg border border-line bg-muted p-4">
      <div className="flex flex-wrap items-center gap-2">
        <h3 className="m-0 text-sm font-semibold text-ink">{t('aiopsPage.scale.reportTitle')}</h3>
        <Badge tone={REPORT_TONE(report.capacityAssessment)}>{report.capacityAssessment?.status || 'OPTIMAL'}</Badge>
      </div>
      {report.capacityAssessment?.recommendation && <p className="m-0 mt-1 text-sm text-ink-muted">{report.capacityAssessment.recommendation}</p>}
      <dl className="m-0 mt-3 grid grid-cols-2 gap-3 text-sm sm:grid-cols-3 lg:grid-cols-6">
        {[
          [t('aiopsPage.scale.reportCores'), specs.cpuCores ?? '--'],
          [t('aiopsPage.scale.reportRam'), `${((specs.totalRamMb || 0) / 1024).toFixed(1)} GB`],
          [t('aiopsPage.scale.reportUsers'), fmt(report.targetConcurrency)],
          [t('aiopsPage.scale.reportCpu'), `${metrics.expectedCpuPercent ?? '--'}%`],
          [t('aiopsPage.scale.reportRamPct'), `${metrics.expectedRamPercent ?? '--'}%`],
          [t('aiopsPage.scale.reportLag'), `${metrics.expectedEventLoopLagMs ?? '--'} ms`],
        ].map(([label, value]) => (
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
  const inputId = useId();
  const { targetConcurrency, customConcurrency, setCustomConcurrency, handleApplyScale, savingScale, calibrationReport } = ops;
  const baselineRpm = targetConcurrency * 10;
  const safePeakRpm = baselineRpm * 3;
  const ipThreshold = Math.max(150, Math.round(20 + 50 * Math.log10(targetConcurrency)));

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
        <StatCard label={t('aiopsPage.scale.baseline')} value={fmt(baselineRpm)} hint={t('aiopsPage.unit.perMinute')} />
        <StatCard label={t('aiopsPage.scale.safePeak')} value={fmt(safePeakRpm)} hint={t('aiopsPage.unit.perMinute')} />
        <StatCard label={t('aiopsPage.scale.ipThreshold')} value={fmt(ipThreshold)} hint={t('aiopsPage.unit.per10s')} />
      </div>

      {calibrationReport && <CalibrationReport report={calibrationReport} />}
    </Card>
  );
};

export default ScaleSection;
