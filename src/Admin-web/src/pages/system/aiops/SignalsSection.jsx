import React from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { useNumberFormat } from '../../../utils/format';
import { Card, StatCard } from '../../../components/ui';

const pct = (v) => Math.round((v || 0) * 100);

// Mức của một tín hiệu theo mốc Backend trả ({ attention, alert }): x ≥ T → vượt; x > A → gần (cùng quy tắc điểm).
const levelOf = (value, marks) => {
  if (!marks || value === null || value === undefined) return null;
  if (value >= marks.alert) return 'alert';
  if (value > marks.attention) return 'near';
  return null;
};
const TONE = { alert: 'danger', near: 'warning' };

const SignalsSection = ({ ops }) => {
  const { t } = useLanguageSafe();
  const f = useNumberFormat();
  const num = (v) => f.number(v, { maxFrac: 1 });
  const sample = ops.sample || {};
  const ind = ops.indicators || {};
  const ram = sample.ramUsedMb && sample.ramTotalMb ? `${num(sample.ramUsedMb)} / ${num(sample.ramTotalMb)} MB` : '-- / -- MB';

  // Thẻ có ngưỡng: chữ phụ là "Vượt ngưỡng" / "Gần ngưỡng" khi chạm mốc, ngược lại là đơn vị.
  const signal = (value, marks, unit) => {
    const level = levelOf(value, marks);
    return {
      hint: level === 'alert' ? t('aiopsPage.signals.high') : level === 'near' ? t('aiopsPage.signals.near') : unit,
      hintTone: TONE[level] || 'neutral',
    };
  };
  const failed = signal(sample.failedLogins, ind.auth?.failedLogins, t('aiopsPage.unit.times'));
  const token = signal(sample.tokenReuseAttacks, ind.auth?.tokenReuse, t('aiopsPage.unit.times'));
  const malformed = signal(sample.malformedRequests, ind.exploit?.malformed, t('aiopsPage.unit.samples'));
  const lagUnit = sample.eventLoopLagMaxMs !== undefined ? t('aiopsPage.signals.lagMax', { n: num(sample.eventLoopLagMaxMs) }) : 'ms';
  const lag = signal(sample.eventLoopLagMs, ind.resource?.lagMs, lagUnit);
  const cpuTone = TONE[levelOf(sample.cpuPercent, ind.resource?.cpuPercent)] || 'neutral';
  const ramTone = TONE[levelOf(sample.ramPercent, ind.resource?.ramPercent)] || 'neutral';
  const err5xxTone = TONE[levelOf(sample.errorRate5xx, ind.resource?.error5xxRate)] || 'neutral';

  return (
    <div className="grid grid-cols-1 gap-5 xl:grid-cols-2">
      <Card title={t('aiopsPage.signals.attackTitle')} padded>
        <div className="grid grid-cols-2 gap-3">
          <StatCard label={t('aiopsPage.signals.failedLogins')} value={num(sample.failedLogins)} {...failed} />
          <StatCard label={t('aiopsPage.signals.tokenReuse')} value={num(sample.tokenReuseAttacks)} {...token} />
          <StatCard label={t('aiopsPage.signals.malformed')} value={num(sample.malformedRequests)} {...malformed} />
          <StatCard label={t('aiopsPage.signals.distinctIps')} value={num(sample.distinctIpsCount)} hint={t('aiopsPage.signals.window', { n: ops.statusData?.windowSeconds || 10 })} />
        </div>
      </Card>

      <Card title={t('aiopsPage.signals.loadTitle')} padded>
        <div className="grid grid-cols-2 gap-3">
          <StatCard label={t('aiopsPage.signals.lag')} value={num(sample.eventLoopLagMs)} {...lag} />
          <StatCard
            label="CPU"
            value={`${num(sample.cpuPercent)}%`}
            hint={sample.cpuCores ? t('aiopsPage.signals.cores', { n: f.number(sample.cpuCores) }) : undefined}
            hintTone={cpuTone}
          />
          <StatCard label={t('aiopsPage.signals.ram')} value={`${num(sample.ramPercent)}%`} hint={ram} hintTone={ramTone} />
          <StatCard
            label={t('aiopsPage.signals.traffic')}
            value={num(sample.requestsPerMin)}
            hint={`${t('aiopsPage.unit.perMinute')} · 4xx ${pct(sample.errorRate4xx)}% · 5xx ${pct(sample.errorRate5xx)}%`}
            hintTone={err5xxTone}
          />
        </div>
      </Card>
    </div>
  );
};

export default SignalsSection;
