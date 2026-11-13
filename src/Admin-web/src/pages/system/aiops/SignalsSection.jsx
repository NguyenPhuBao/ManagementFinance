import React from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { Card, StatCard } from '../../../components/ui';

const num = (v) => Number(v || 0).toLocaleString('vi-VN');
const pct = (v) => Math.round((v || 0) * 100);

const SignalsSection = ({ ops }) => {
  const { t } = useLanguageSafe();
  const sample = ops.sample || {};
  const ram = sample.ramUsedMb && sample.ramTotalMb ? `${num(sample.ramUsedMb)} / ${num(sample.ramTotalMb)} MB` : '-- / -- MB';

  return (
    <div className="grid grid-cols-1 gap-5 xl:grid-cols-2">
      <Card title={t('aiopsPage.signals.attackTitle')} padded>
        <div className="grid grid-cols-2 gap-3">
          <StatCard
            label={t('aiopsPage.signals.failedLogins')}
            value={num(sample.failedLogins)}
            hint={sample.failedLogins >= 5 ? t('aiopsPage.signals.high') : t('aiopsPage.unit.times')}
            hintTone={sample.failedLogins >= 5 ? 'danger' : 'neutral'}
          />
          <StatCard
            label={t('aiopsPage.signals.tokenReuse')}
            value={num(sample.tokenReuseAttacks)}
            hint={sample.tokenReuseAttacks >= 1 ? t('aiopsPage.signals.high') : t('aiopsPage.unit.times')}
            hintTone={sample.tokenReuseAttacks >= 1 ? 'danger' : 'neutral'}
          />
          <StatCard
            label={t('aiopsPage.signals.malformed')}
            value={num(sample.malformedRequests)}
            hint={sample.malformedRequests >= 3 ? t('aiopsPage.signals.high') : t('aiopsPage.unit.samples')}
            hintTone={sample.malformedRequests >= 3 ? 'warning' : 'neutral'}
          />
          <StatCard label={t('aiopsPage.signals.distinctIps')} value={num(sample.distinctIpsCount)} hint={t('aiopsPage.signals.window', { n: ops.statusData?.windowSeconds || 10 })} />
        </div>
      </Card>

      <Card title={t('aiopsPage.signals.loadTitle')} padded>
        <div className="grid grid-cols-2 gap-3">
          <StatCard
            label={t('aiopsPage.signals.lag')}
            value={num(sample.eventLoopLagMs)}
            hint="ms"
            hintTone={sample.eventLoopLagMs >= 100 ? 'danger' : 'neutral'}
          />
          <StatCard
            label="CPU"
            value={`${sample.cpuPercent ?? 0}%`}
            hint={sample.cpuCores ? t('aiopsPage.signals.cores', { n: sample.cpuCores }) : undefined}
            hintTone={sample.cpuPercent >= 85 ? 'warning' : 'neutral'}
          />
          <StatCard
            label="RAM"
            value={`${sample.ramPercent ?? 0}%`}
            hint={ram}
            hintTone={sample.ramPercent >= 90 ? 'danger' : 'neutral'}
          />
          <StatCard
            label={t('aiopsPage.signals.traffic')}
            value={num(sample.requestsPerMin)}
            hint={`${t('aiopsPage.unit.perMinute')} · 4xx ${pct(sample.errorRate4xx)}% · 5xx ${pct(sample.errorRate5xx)}%`}
            hintTone={(sample.errorRate5xx || 0) >= 0.05 ? 'danger' : 'neutral'}
          />
        </div>
      </Card>
    </div>
  );
};

export default SignalsSection;
