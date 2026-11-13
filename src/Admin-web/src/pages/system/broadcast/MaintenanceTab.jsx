import React, { useEffect, useId, useState } from 'react';
import adminApi from '../../../api/admin.api';
import TruncateCell from '../../../components/common/TruncateCell';
import { useLanguageSafe } from '../../../store/language.context';
import { formatDateTime } from '../../../utils/format';
import { Button, Card, ConfirmModal, DataTable, Icon, SecurityConfirmModal } from '../../../components/ui';
import MaintenanceHistory from './MaintenanceHistory';
import { HOUR, MIN_LEAD_HOURS, plannedDuration, scheduleId, scheduledListOf, toLocalInput } from './maintenanceFormat';

const fieldClass =
  'h-10 w-full rounded-lg border border-line bg-card px-3 text-sm text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';

const MaintenanceTab = ({ maintenance, busy, act, version, onRefresh }) => {
  const { t } = useLanguageSafe();
  const ids = useId();
  const [now, setNow] = useState(Date.now());
  const [emergency, setEmergency] = useState(false);
  const [start, setStart] = useState('');
  const [end, setEnd] = useState('');
  const [reason, setReason] = useState('');
  const [formError, setFormError] = useState('');
  const [confirmEmergency, setConfirmEmergency] = useState(false);
  const [cancelId, setCancelId] = useState(null);

  const emergencyBlocked = Boolean(maintenance.active && maintenance.isEmergency);

  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);

  useEffect(() => {
    if (emergencyBlocked && emergency) setEmergency(false);
  }, [emergencyBlocked, emergency]);

  const resetForm = () => {
    setStart('');
    setEnd('');
    setReason('');
    setFormError('');
  };

  const submit = async (e) => {
    e.preventDefault();
    setFormError('');
    if (emergency) {
      setConfirmEmergency(true);
      return;
    }
    if (!start) return;
    const startMs = new Date(start).getTime();
    if (startMs < Date.now() + MIN_LEAD_HOURS * HOUR) {
      setFormError(t('broadcast.schedule.errorLeadTime'));
      return;
    }
    if (end && new Date(end).getTime() <= startMs) {
      setFormError(t('broadcast.schedule.errorEndBeforeStart'));
      return;
    }
    const ok = await act(
      () =>
        adminApi.setMaintenanceStatus({
          scheduledAt: new Date(start).toISOString(),
          scheduledEndAt: end ? new Date(end).toISOString() : null,
          reason: reason.trim() || t('broadcast.defaults.scheduledReason'),
          isEmergency: false,
          type: 'SCHEDULED',
        }),
      t('broadcast.feedback.scheduled', { time: `${formatDateTime(start)}${end ? ` - ${formatDateTime(end)}` : ''}` }),
      t('broadcast.feedback.scheduleFailed')
    );
    if (ok) resetForm();
  };

  const activateEmergency = async () => {
    const ok = await act(
      () => adminApi.setMaintenanceStatus({ active: true, reason: reason.trim() || t('broadcast.defaults.emergencyReason'), isEmergency: true }),
      t('broadcast.feedback.emergencyOn'),
      t('broadcast.feedback.failed')
    );
    if (ok) {
      setEmergency(false);
      resetForm();
    }
  };

  const cancelSchedule = async () => {
    const id = cancelId;
    setCancelId(null);
    await act(() => adminApi.cancelScheduledMaintenance(id), t('broadcast.feedback.cancelled'), t('broadcast.feedback.cancelFailed'));
  };

  const schedules = scheduledListOf(maintenance);
  const nearest = schedules.find((s) => new Date(s.scheduledAt).getTime() > now) || schedules[0];
  const nearestIn = nearest ? new Date(nearest.scheduledAt).getTime() - now : 0;
  const showImminent = Boolean(nearest) && !maintenance.active && nearestIn > 0 && nearestIn <= HOUR;

  const scheduleColumns = [
    { key: 'start', title: t('broadcast.schedule.colStart'), render: (s) => <span className="whitespace-nowrap font-medium text-ink">{formatDateTime(s.scheduledAt)}</span> },
    { key: 'end', title: t('broadcast.schedule.colEnd'), render: (s) => <span className="whitespace-nowrap text-ink-muted">{s.scheduledEndAt ? formatDateTime(s.scheduledEndAt) : '—'}</span> },
    { key: 'duration', title: t('broadcast.schedule.colDuration'), render: (s) => <span className="font-mono text-xs">{plannedDuration(s.scheduledAt, s.scheduledEndAt)}</span> },
    { key: 'reason', title: t('broadcast.schedule.colReason'), width: '30%', render: (s) => <TruncateCell text={s.reason || '—'} className="text-ink" /> },
    { key: 'by', title: t('broadcast.schedule.colBy'), render: (s) => <span className="text-ink-muted">{s.createdBy || 'admin'}</span> },
    {
      key: 'actions',
      title: t('broadcast.history.colActions'),
      align: 'right',
      render: (s) => (
        <Button size="sm" variant="danger-ghost" icon="event_busy" className="whitespace-nowrap" disabled={busy} onClick={() => setCancelId(scheduleId(s))}>
          {t('broadcast.schedule.cancelBtn')}
        </Button>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-5">
      {showImminent && (
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-warning bg-warning-soft px-5 py-4">
          <div className="flex min-w-0 items-start gap-3">
            <Icon name="timer" className="mt-0.5 text-warning" />
            <div className="min-w-0">
              <p className="m-0 font-semibold text-ink">{t('broadcast.schedule.imminent', { minutes: Math.max(1, Math.ceil(nearestIn / 60000)) })}</p>
              <p className="m-0 mt-0.5 text-sm text-ink-muted">
                {formatDateTime(nearest.scheduledAt)}
                {nearest.reason ? ` · ${nearest.reason}` : ''}
              </p>
            </div>
          </div>
          <Button size="sm" variant="danger-ghost" icon="event_busy" className="whitespace-nowrap" disabled={busy} onClick={() => setCancelId(scheduleId(nearest))}>
            {t('broadcast.schedule.cancelBtn')}
          </Button>
        </div>
      )}

      <Card title={t('broadcast.schedule.title')} padded>
        <p className="m-0 mb-4 text-sm text-ink-muted">{t('broadcast.schedule.rules')}</p>
        <form onSubmit={submit} className="flex flex-col gap-4" noValidate>
          <div className="flex items-start gap-3 rounded-lg border border-line px-4 py-3">
            <input
              id={`${ids}-emergency`}
              type="checkbox"
              checked={emergency}
              disabled={emergencyBlocked}
              onChange={(e) => {
                setEmergency(e.target.checked);
                setFormError('');
              }}
              className="mt-0.5 h-4 w-4 cursor-pointer accent-danger disabled:cursor-not-allowed"
            />
            <div>
              <label htmlFor={`${ids}-emergency`} className="cursor-pointer text-sm font-medium text-ink">
                {t('broadcast.schedule.emergency')}
              </label>
              <p className="m-0 mt-0.5 text-sm text-ink-muted">
                {emergencyBlocked
                  ? t('broadcast.schedule.emergencyBlocked')
                  : emergency
                    ? t('broadcast.schedule.emergencyNow')
                    : t('broadcast.schedule.emergencyHint')}
              </p>
            </div>
          </div>

          {!emergency && (
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div>
                <label htmlFor={`${ids}-start`} className="mb-1 block text-sm font-medium text-ink">
                  {t('broadcast.schedule.start')}
                </label>
                <input
                  id={`${ids}-start`}
                  type="datetime-local"
                  min={toLocalInput(now + MIN_LEAD_HOURS * HOUR)}
                  value={start}
                  onChange={(e) => setStart(e.target.value)}
                  className={fieldClass}
                />
              </div>
              <div>
                <label htmlFor={`${ids}-end`} className="mb-1 block text-sm font-medium text-ink">
                  {t('broadcast.schedule.end')}
                </label>
                <input
                  id={`${ids}-end`}
                  type="datetime-local"
                  min={start || toLocalInput(now + MIN_LEAD_HOURS * HOUR)}
                  value={end}
                  onChange={(e) => setEnd(e.target.value)}
                  className={fieldClass}
                />
              </div>
            </div>
          )}

          <div>
            <label htmlFor={`${ids}-reason`} className="mb-1 block text-sm font-medium text-ink">
              {t('broadcast.schedule.reason')}
            </label>
            <input
              id={`${ids}-reason`}
              type="text"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder={emergency ? t('broadcast.schedule.reasonEmergencyPlaceholder') : t('broadcast.schedule.reasonPlaceholder')}
              className={fieldClass}
            />
          </div>

          {formError && (
            <p role="alert" className="m-0 text-sm text-danger">
              {formError}
            </p>
          )}

          <div className="flex flex-wrap items-center gap-2">
            {emergency ? (
              <Button type="submit" variant="danger" icon="crisis_alert" disabled={busy || emergencyBlocked}>
                {t('broadcast.schedule.emergencySubmit')}
              </Button>
            ) : (
              <Button type="submit" variant="primary" icon="event" loading={busy} disabled={!start}>
                {t('broadcast.schedule.submit')}
              </Button>
            )}
            <Button
              icon="refresh"
              onClick={() => {
                resetForm();
                setEmergency(false);
                onRefresh();
              }}
            >
              {t('broadcast.schedule.refresh')}
            </Button>
          </div>
        </form>
      </Card>

      {schedules.length > 0 && (
        <Card title={t('broadcast.schedule.listTitle', { count: schedules.length })}>
          <DataTable label={t('broadcast.schedule.listLabel')} columns={scheduleColumns} rows={schedules} rowKey={(s, i) => scheduleId(s) || i} minWidth={760} />
        </Card>
      )}

      <MaintenanceHistory version={version} now={now} busy={busy} onCancel={setCancelId} />

      <SecurityConfirmModal
        isOpen={confirmEmergency}
        onClose={() => setConfirmEmergency(false)}
        title={t('broadcast.emergencyModal.title')}
        description={reason.trim() ? t('broadcast.emergencyModal.descReason', { reason: reason.trim() }) : t('broadcast.emergencyModal.desc')}
        confirmText={t('broadcast.emergencyModal.confirm')}
        requirePin={false}
        dangerLevel="critical"
        actionType="EMERGENCY_MAINTENANCE"
        onConfirm={activateEmergency}
      />

      <ConfirmModal
        open={cancelId !== null}
        title={t('broadcast.cancelModal.title')}
        message={t('broadcast.cancelModal.message')}
        confirmText={t('broadcast.schedule.cancelBtn')}
        confirmDanger
        loading={busy}
        onConfirm={cancelSchedule}
        onCancel={() => setCancelId(null)}
      />
    </div>
  );
};

export default MaintenanceTab;
