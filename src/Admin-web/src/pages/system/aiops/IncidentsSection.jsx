import React, { useState } from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { formatDateTime } from '../../../utils/format';
import { Badge, Button, Card, ConfirmModal, DataTable, Pagination, SearchInput, Tabs } from '../../../components/ui';
import { VECTOR_TONE, incidentActor, maskIp } from './aiopsFormat';

const IncidentsSection = ({ ops }) => {
  const { t } = useLanguageSafe();
  const [target, setTarget] = useState(null);
  const [blocking, setBlocking] = useState(false);
  const { incidents, incidentTotal, quarantineList, myCurrentIp, actionLoading } = ops;

  const isBlocked = (actor) => Boolean(actor.hash) && quarantineList.some((q) => q.hash === actor.hash || q.ipHash === actor.hash);

  const confirmBlock = async () => {
    setBlocking(true);
    const ok = await ops.blockFromIncident(target);
    setBlocking(false);
    if (ok) setTarget(null);
  };

  const columns = [
    {
      key: 'time',
      title: t('aiopsPage.incidents.colTime'),
      render: (item) => (
        <div className="flex flex-col items-start gap-1">
          <span className="tabular-nums text-ink">{formatDateTime(item.first_detected_at || item.firstDetectedAt)}</span>
          {(item.status || 'ACTIVE') === 'ACTIVE' ? <Badge tone="danger">{t('aiopsPage.incidents.active')}</Badge> : <Badge tone="success">{t('aiopsPage.incidents.mitigated')}</Badge>}
          <span className="text-xs text-ink-faint">{(item.hits || 1) > 1 ? t('aiopsPage.incidents.repeated', { n: item.hits }) : t('aiopsPage.incidents.firstTime')}</span>
        </div>
      ),
    },
    {
      key: 'actor',
      title: t('aiopsPage.incidents.colActor'),
      render: (item) => {
        const actor = incidentActor(item, myCurrentIp);
        if (actor.system) return <span className="font-medium text-ink">{t('aiopsPage.incidents.system')}</span>;
        return (
          <div className="flex flex-col">
            <span className="font-medium text-ink">{actor.username || (actor.userId ? `#${actor.userId}` : t('aiopsPage.incidents.guest'))}</span>
            <span className="font-mono text-xs text-ink-muted">
              {maskIp(item.actor?.maskedIp || actor.identity)}
              {actor.mine ? ` (${t('aiopsPage.incidents.mine')})` : ''}
            </span>
          </div>
        );
      },
    },
    {
      key: 'vector',
      title: t('aiopsPage.incidents.colVector'),
      render: (item) => <Badge tone={VECTOR_TONE[item.vector] || 'neutral'}>{t(`aiopsPage.vector.${item.vector || 'traffic'}`)}</Badge>,
    },
    {
      key: 'metric',
      title: t('aiopsPage.incidents.colMetric'),
      render: (item) => {
        const current = item.metric_current ?? item.metricCurrent ?? 0;
        const baseline = item.metric_baseline ?? item.metricBaseline ?? 0;
        const unit = item.metric_unit || item.metricUnit || '';
        const ratio = baseline > 0 ? Number(current) / Number(baseline) : 0;
        return (
          <div className="flex flex-col items-start gap-0.5">
            <span className="font-semibold tabular-nums text-danger">{current} {unit}</span>
            <span className="text-xs text-ink-faint">{t('aiopsPage.incidents.threshold', { v: `${baseline} ${unit}`.trim() })}</span>
            {ratio > 1 && <Badge tone="danger">{t('aiopsPage.incidents.exceeded', { r: Number(ratio.toFixed(1)).toLocaleString('vi-VN') })}</Badge>}
          </div>
        );
      },
    },
    { key: 'message', title: t('aiopsPage.incidents.colCause'), render: (item) => <span className="line-clamp-3 text-ink" title={item.message}>{item.message || '--'}</span> },
    {
      key: 'mitigation',
      title: t('aiopsPage.incidents.colMitigation'),
      render: (item) => {
        const text = item.mitigation_taken || item.mitigationTaken;
        return text ? <span className="line-clamp-3 text-ink" title={text}>{text}</span> : <span className="text-ink-faint">{t('aiopsPage.incidents.watching')}</span>;
      },
    },
    {
      key: 'defense',
      title: t('aiopsPage.incidents.colDefense'),
      render: (item) => {
        const actor = incidentActor(item, myCurrentIp);
        if (isBlocked(actor)) {
          return (
            <div className="flex flex-col items-start gap-1">
              <Badge tone="danger">{t('aiopsPage.incidents.blocked')}</Badge>
              <Button size="sm" variant="ghost" loading={actionLoading === `ip:${actor.hash}`} onClick={() => ops.quarantineActions.unblockIp(actor.hash, maskIp(actor.identity))}>
                {t('aiopsPage.incidents.unblock')}
              </Button>
            </div>
          );
        }
        if (actor.protectedActor) {
          return <span className="text-sm text-success">{actor.system ? t('aiopsPage.incidents.system') : actor.mine ? t('aiopsPage.incidents.mine') : t('aiopsPage.incidents.protected')}</span>;
        }
        return (
          <Button size="sm" variant="danger-ghost" icon="shield" onClick={() => setTarget(item)}>
            {t('aiopsPage.incidents.block')}
          </Button>
        );
      },
    },
  ];

  const vectorTabs = ['all', 'auth', 'traffic', 'exploit', 'resource'].map((key) => ({ key, label: t(`aiopsPage.vector.${key}`) }));
  const statusTabs = [
    { key: 'all', label: t('aiopsPage.incidents.statusAll') },
    { key: 'ACTIVE', label: t('aiopsPage.incidents.active') },
    { key: 'MITIGATED', label: t('aiopsPage.incidents.mitigated') },
  ];
  const targetIp = target ? maskIp(incidentActor(target, myCurrentIp).identity) : '';

  return (
    <Card title={t('aiopsPage.incidents.title')} actions={<Badge tone="neutral">{t('aiopsPage.incidents.count', { n: incidentTotal })}</Badge>}>
      <div className="flex flex-col gap-3 border-b border-line px-5 py-4 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex flex-wrap gap-2">
          <Tabs ariaLabel={t('aiopsPage.incidents.vectorFilter')} items={vectorTabs} value={ops.incidentVector} onChange={(key) => { ops.setIncidentVector(key); ops.setIncidentPage(1); }} />
          <Tabs ariaLabel={t('aiopsPage.incidents.statusFilter')} items={statusTabs} value={ops.incidentStatus} onChange={(key) => { ops.setIncidentStatus(key); ops.setIncidentPage(1); }} />
        </div>
        <form
          className="flex items-center gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            ops.searchIncidents();
          }}
        >
          <SearchInput label={t('aiopsPage.incidents.search')} placeholder={t('aiopsPage.incidents.searchHint')} value={ops.incidentSearch} onChange={ops.setIncidentSearch} className="w-full sm:w-64" />
          <Button type="submit">{t('aiopsPage.incidents.searchBtn')}</Button>
        </form>
      </div>
      <DataTable label={t('aiopsPage.incidents.title')} columns={columns} rows={incidents} rowKey={(row, i) => row.id ?? i} emptyTitle={t('aiopsPage.incidents.empty')} minWidth={960} />
      {incidentTotal > 0 && (
        <Pagination
          currentPage={ops.incidentPage}
          pageSize={ops.incidentPageSize}
          total={incidentTotal}
          pageSizeOptions={[5, 10, 20, 50]}
          onPageChange={ops.setIncidentPage}
          onPageSizeChange={(size) => {
            ops.setIncidentPageSize(size);
            ops.setIncidentPage(1);
          }}
          itemLabel={t('aiopsPage.incidents.itemLabel')}
        />
      )}
      <ConfirmModal
        open={Boolean(target)}
        onCancel={() => setTarget(null)}
        onConfirm={confirmBlock}
        loading={blocking}
        confirmDanger
        title={t('aiopsPage.incidents.blockTitle', { ip: targetIp })}
        message={t('aiopsPage.incidents.blockMsg')}
        confirmText={t('aiopsPage.incidents.block')}
      />
    </Card>
  );
};

export default IncidentsSection;
