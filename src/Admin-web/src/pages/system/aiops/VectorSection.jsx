import React, { useState } from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { Badge, Card, ConfirmModal } from '../../../components/ui';
import { lockState } from './aiopsFormat';

const BAR = { danger: 'bg-danger', warning: 'bg-warning', info: 'bg-info', success: 'bg-success', neutral: 'bg-ink-faint' };
const barTone = (score) => (score >= 80 ? 'danger' : score >= 60 ? 'warning' : score >= 30 ? 'info' : 'success');
const num = (v) => Number(v || 0).toLocaleString('vi-VN');

const statusOf = (key, score, ops, t) => {
  if (key === 'auth') {
    const n = ops.quarantineList.filter((item) => {
      const s = lockState(item);
      return s.ip.kind !== 'unlocked' || (s.account && s.account.kind !== 'unlocked');
    }).length;
    if (n > 0) return { tone: 'danger', text: t('aiopsPage.vectorCard.blocking', { n }) };
    if (score >= 70) return { tone: 'danger', text: t('aiopsPage.vectorCard.blockingOn') };
    return { tone: 'success', text: t('aiopsPage.vectorCard.ready') };
  }
  if (key === 'traffic') {
    if (score >= 70) return { tone: 'info', text: t('aiopsPage.vectorCard.throttling') };
    return { tone: 'success', text: t('aiopsPage.vectorCard.trafficOk', { n: num(ops.targetConcurrency) }) };
  }
  if (key === 'exploit') {
    if (score >= 70) return { tone: 'danger', text: t('aiopsPage.vectorCard.exploitBlocked') };
    return { tone: 'success', text: t('aiopsPage.vectorCard.ready') };
  }
  if (ops.isEmergencyResourceRisk) return { tone: 'danger', text: t('aiopsPage.vectorCard.needMaintenance') };
  if (score >= 60) return { tone: 'warning', text: t('aiopsPage.vectorCard.shedding') };
  return { tone: 'success', text: t('aiopsPage.vectorCard.stable') };
};

const metricsOf = (key, sample, t) => {
  if (key === 'auth') return [[t('aiopsPage.signals.failedLogins'), num(sample.failedLogins)], [t('aiopsPage.signals.tokenReuse'), num(sample.tokenReuseAttacks)]];
  if (key === 'traffic') return [[t('aiopsPage.signals.traffic'), `${num(sample.requestsPerMin)} ${t('aiopsPage.unit.perMinute')}`], [t('aiopsPage.signals.distinctIps'), num(sample.distinctIpsCount)]];
  if (key === 'exploit') return [[t('aiopsPage.signals.malformed'), num(sample.malformedRequests)], [t('aiopsPage.vectorCard.traversal'), t('aiopsPage.vectorCard.autoDetect')]];
  return [[t('aiopsPage.signals.lag'), `${sample.eventLoopLagMs ?? 0} ms`], ['CPU / RAM', `${sample.cpuPercent ?? 0}% / ${sample.ramPercent ?? 0}%`]];
};

const VectorCard = ({ vectorKey, ops, onToggle }) => {
  const { t } = useLanguageSafe();
  const name = t(`aiopsPage.vector.${vectorKey}`);
  const score = Number(ops.vectorScores[vectorKey] || 0);
  const enabled = ops.vectorConfig[vectorKey] !== false;
  const status = enabled ? statusOf(vectorKey, score, ops, t) : { tone: 'neutral', text: t('aiopsPage.vectorCard.measureOnly') };
  const tone = enabled ? barTone(score) : 'neutral';

  return (
    <div className={`flex flex-col gap-3 rounded-xl border border-line p-4 ${enabled ? 'bg-card' : 'bg-muted'}`}>
      <div className="flex items-center justify-between gap-2">
        <h3 className="m-0 text-sm font-semibold text-ink">{name}</h3>
        <button
          type="button"
          role="switch"
          aria-checked={enabled}
          aria-label={t('aiopsPage.vectorCard.toggle', { name })}
          onClick={() => onToggle(vectorKey, !enabled)}
          className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer items-center rounded-full transition-colors ${enabled ? 'bg-brand' : 'bg-line'}`}
        >
          <span className={`inline-block h-5 w-5 rounded-full bg-card shadow transition-transform ${enabled ? 'translate-x-5' : 'translate-x-0.5'}`} />
        </button>
      </div>
      <div>
        <div className="flex items-baseline gap-1">
          <span className="text-2xl font-bold tabular-nums text-ink">{score}</span>
          <span className="text-sm text-ink-faint">/100</span>
        </div>
        <div role="progressbar" aria-label={name} aria-valuemin={0} aria-valuemax={100} aria-valuenow={score} className="mt-2 h-2 overflow-hidden rounded-full bg-muted">
          <div className={`h-full rounded-full transition-all duration-500 ${BAR[tone]}`} style={{ width: `${Math.min(100, Math.max(0, score))}%` }} />
        </div>
      </div>
      <dl className="m-0 flex flex-col gap-1 border-t border-line pt-3 text-sm">
        {metricsOf(vectorKey, ops.sample, t).map(([label, value]) => (
          <div key={label} className="flex justify-between gap-2">
            <dt className="text-ink-muted">{label}</dt>
            <dd className="m-0 font-medium tabular-nums text-ink">{value}</dd>
          </div>
        ))}
      </dl>
      <div>
        <Badge tone={status.tone}>{status.text}</Badge>
      </div>
    </div>
  );
};

const VectorSection = ({ ops }) => {
  const { t } = useLanguageSafe();
  const [pending, setPending] = useState(null);
  const [saving, setSaving] = useState(false);

  const confirm = async () => {
    setSaving(true);
    const ok = await ops.toggleVector(pending.key, pending.enabled);
    setSaving(false);
    if (ok) setPending(null);
  };

  const name = pending ? t(`aiopsPage.vector.${pending.key}`) : '';

  return (
    <Card title={t('aiopsPage.vectorCard.title')} padded>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {['auth', 'traffic', 'exploit', 'resource'].map((key) => (
          <VectorCard key={key} vectorKey={key} ops={ops} onToggle={(k, enabled) => setPending({ key: k, enabled })} />
        ))}
      </div>
      <ConfirmModal
        open={Boolean(pending)}
        onCancel={() => setPending(null)}
        onConfirm={confirm}
        loading={saving}
        confirmDanger={pending ? !pending.enabled : false}
        title={pending ? t(pending.enabled ? 'aiopsPage.vectorCard.enableTitle' : 'aiopsPage.vectorCard.disableTitle', { name }) : ''}
        message={pending ? t(pending.enabled ? 'aiopsPage.vectorCard.enableMsg' : 'aiopsPage.vectorCard.disableMsg') : ''}
        confirmText={pending ? t(pending.enabled ? 'aiopsPage.vectorCard.enable' : 'aiopsPage.vectorCard.disable') : ''}
      />
    </Card>
  );
};

export default VectorSection;
