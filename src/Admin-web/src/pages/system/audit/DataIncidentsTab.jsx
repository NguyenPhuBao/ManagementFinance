import React, { useCallback, useEffect, useId, useRef, useState } from 'react';
import adminApi from '../../../api/admin.api';
import useSocket from '../../../hooks/useSocket';
import { useAlertSafe } from '../../../store/alert.context';
import { useLanguageSafe } from '../../../store/language.context';
import { formatDateTime } from '../../../utils/format';
import { Badge, Button, Card, EmptyState, Modal, SecurityConfirmModal, Spinner } from '../../../components/ui';

const SOURCES = ['AIOPS', 'AUDIT_LOG', 'USER_REPORT', 'PROCESSOR', 'OTHER'];
const STATUS_TONE = { OPEN: 'danger', CONTAINED: 'warning', REPORTED: 'info', CLOSED: 'success' };
const fieldClass =
  'w-full rounded-lg border border-line bg-card px-3 text-sm text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';

const pad = (n) => String(n).padStart(2, '0');
const formatDuration = (ms) => {
  const total = Math.floor(Math.abs(ms) / 1000);
  return `${pad(Math.floor(total / 3600))}:${pad(Math.floor((total % 3600) / 60))}:${pad(total % 60)}`;
};
const toLocalInput = (date) => {
  const d = new Date(date);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
};
const fromLocalInput = (value) => (value ? new Date(value).toISOString() : undefined);
const errorText = (err, fallback) => err?.response?.data?.message || err?.message || fallback;

const useNow = () => {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);
  return now;
};

const Field = ({ id, label, children }) => (
  <div>
    <label htmlFor={id} className="mb-1 block text-sm font-medium text-ink">{label}</label>
    {children}
  </div>
);

const EMPTY_FORM = {
  title: '', description: '', source: 'OTHER', detectedAt: '', occurredAt: '', dataTypes: '', sensitive: false,
  affectedUsers: '', affectedRecords: '', consequences: '', measures: '', contact: '',
};

const IncidentForm = ({ initial, onClose, onSaved }) => {
  const { t } = useLanguageSafe();
  const notify = useAlertSafe();
  const ids = useId();
  const editing = Boolean(initial);
  const [form, setForm] = useState(() =>
    initial
      ? {
          title: initial.title || '', description: initial.description || '', source: initial.source || 'OTHER',
          detectedAt: toLocalInput(initial.detected_at), occurredAt: initial.occurred_at ? toLocalInput(initial.occurred_at) : '',
          dataTypes: initial.data_types || '', sensitive: Boolean(initial.sensitive),
          affectedUsers: initial.affected_users ?? '', affectedRecords: initial.affected_records ?? '',
          consequences: initial.consequences || '', measures: initial.measures || '', contact: initial.contact || '',
        }
      : { ...EMPTY_FORM, detectedAt: toLocalInput(Date.now()) }
  );
  const [saving, setSaving] = useState(false);
  const set = (patch) => setForm((prev) => ({ ...prev, ...patch }));
  const ready = form.title.trim() && form.description.trim();

  const submit = async (e) => {
    e.preventDefault();
    setSaving(true);
    const body = { ...form, detectedAt: fromLocalInput(form.detectedAt), occurredAt: fromLocalInput(form.occurredAt) || null };
    try {
      if (editing) await adminApi.updateDataIncident(initial.id, body);
      else await adminApi.createDataIncident(body);
      onSaved();
    } catch (err) {
      if (notify) notify.error(errorText(err, t('dataIncident.saveFailed')));
    } finally {
      setSaving(false);
    }
  };

  const input = (key, extra = {}) => (
    <input id={`${ids}-${key}`} value={form[key]} onChange={(e) => set({ [key]: e.target.value })} className={`${fieldClass} h-10`} {...extra} />
  );
  const area = (key) => (
    <textarea id={`${ids}-${key}`} rows={2} value={form[key]} onChange={(e) => set({ [key]: e.target.value })} className={`${fieldClass} py-2`} />
  );

  return (
    <Modal
      open
      onClose={onClose}
      closeDisabled={saving}
      size="lg"
      title={editing ? t('dataIncident.editTitle', { code: initial.code }) : t('dataIncident.createTitle')}
      description={t('dataIncident.formDesc')}
      footer={
        <>
          <Button onClick={onClose} disabled={saving}>{t('common.cancel', 'Hủy bỏ')}</Button>
          <Button variant="primary" type="submit" form={`${ids}-form`} loading={saving} disabled={!ready}>{t('dataIncident.save')}</Button>
        </>
      }
    >
      <form id={`${ids}-form`} onSubmit={submit} className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div className="sm:col-span-2"><Field id={`${ids}-title`} label={t('dataIncident.fields.title')}>{input('title', { maxLength: 200 })}</Field></div>
        <div className="sm:col-span-2"><Field id={`${ids}-description`} label={t('dataIncident.fields.description')}>{area('description')}</Field></div>
        <Field id={`${ids}-source`} label={t('dataIncident.fields.source')}>
          <select id={`${ids}-source`} value={form.source} onChange={(e) => set({ source: e.target.value })} className={`${fieldClass} h-10 pr-8`}>
            {SOURCES.map((s) => <option key={s} value={s}>{t(`dataIncident.sources.${s}`)}</option>)}
          </select>
        </Field>
        <Field id={`${ids}-detectedAt`} label={t('dataIncident.fields.detectedAt')}>{input('detectedAt', { type: 'datetime-local' })}</Field>
        <Field id={`${ids}-occurredAt`} label={t('dataIncident.fields.occurredAt')}>{input('occurredAt', { type: 'datetime-local' })}</Field>
        <Field id={`${ids}-dataTypes`} label={t('dataIncident.fields.dataTypes')}>{input('dataTypes')}</Field>
        <Field id={`${ids}-affectedUsers`} label={t('dataIncident.fields.affectedUsers')}>{input('affectedUsers', { type: 'number', min: 0 })}</Field>
        <Field id={`${ids}-affectedRecords`} label={t('dataIncident.fields.affectedRecords')}>{input('affectedRecords', { type: 'number', min: 0 })}</Field>
        <label className="flex items-center gap-2 text-sm text-ink sm:col-span-2">
          <input type="checkbox" checked={form.sensitive} onChange={(e) => set({ sensitive: e.target.checked })} className="h-4 w-4 accent-brand" />
          {t('dataIncident.fields.sensitive')}
        </label>
        <div className="sm:col-span-2"><Field id={`${ids}-consequences`} label={t('dataIncident.fields.consequences')}>{area('consequences')}</Field></div>
        <div className="sm:col-span-2"><Field id={`${ids}-measures`} label={t('dataIncident.fields.measures')}>{area('measures')}</Field></div>
        <div className="sm:col-span-2"><Field id={`${ids}-contact`} label={t('dataIncident.fields.contact')}>{input('contact')}</Field></div>
      </form>
    </Modal>
  );
};

const ReportModal = ({ incident, onClose, onSaved }) => {
  const { t } = useLanguageSafe();
  const notify = useAlertSafe();
  const ids = useId();
  const [reportedAt, setReportedAt] = useState(toLocalInput(Date.now()));
  const [reference, setReference] = useState('');
  const [lateReason, setLateReason] = useState('');
  const [saving, setSaving] = useState(false);
  const late = reportedAt && new Date(reportedAt).getTime() > new Date(incident.deadline).getTime();
  const ready = !late || lateReason.trim();

  const save = async () => {
    setSaving(true);
    try {
      await adminApi.dataIncidentAction(incident.id, 'report', { reportedAt: fromLocalInput(reportedAt), reference, ...(late ? { lateReason } : {}) });
      onSaved();
    } catch (err) {
      if (notify) notify.error(errorText(err, t('dataIncident.saveFailed')));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Modal
      open
      onClose={onClose}
      closeDisabled={saving}
      title={t('dataIncident.reportTitle')}
      description={t('dataIncident.reportDesc', { code: incident.code })}
      footer={
        <>
          <Button onClick={onClose} disabled={saving}>{t('common.cancel', 'Hủy bỏ')}</Button>
          <Button variant="primary" loading={saving} disabled={!ready} onClick={save}>{t('dataIncident.save')}</Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        <Field id={`${ids}-at`} label={t('dataIncident.reportedAt')}>
          <input id={`${ids}-at`} type="datetime-local" value={reportedAt} onChange={(e) => setReportedAt(e.target.value)} className={`${fieldClass} h-10`} />
        </Field>
        <Field id={`${ids}-ref`} label={t('dataIncident.reference')}>
          <input id={`${ids}-ref`} value={reference} onChange={(e) => setReference(e.target.value)} className={`${fieldClass} h-10`} />
        </Field>
        {late && (
          <Field id={`${ids}-late`} label={t('dataIncident.lateReason')}>
            <textarea id={`${ids}-late`} rows={2} value={lateReason} onChange={(e) => setLateReason(e.target.value)} className={`${fieldClass} py-2`} />
          </Field>
        )}
      </div>
    </Modal>
  );
};

const CloseModal = ({ incident, onClose, onSaved }) => {
  const { t } = useLanguageSafe();
  const ids = useId();
  const [rootCause, setRootCause] = useState('');
  const [notRequired, setNotRequired] = useState(false);
  const [noReportReason, setNoReportReason] = useState('');
  const [pinOpen, setPinOpen] = useState(false);
  const reported = Boolean(incident.authority_reported_at);
  const ready = rootCause.trim() && (reported || (notRequired && noReportReason.trim()));

  const payload = () => ({ rootCause, ...(!reported && notRequired ? { reportNotRequired: true, noReportReason } : {}) });

  return (
    <Modal
      open
      onClose={onClose}
      closeDisabled={pinOpen}
      title={t('dataIncident.closeTitle')}
      description={t('dataIncident.closeDesc', { code: incident.code })}
      footer={
        <>
          <Button onClick={onClose}>{t('common.cancel', 'Hủy bỏ')}</Button>
          <Button variant="primary" disabled={!ready} onClick={() => setPinOpen(true)}>{t('dataIncident.next')}</Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        <Field id={`${ids}-cause`} label={t('dataIncident.rootCause')}>
          <textarea id={`${ids}-cause`} rows={3} value={rootCause} onChange={(e) => setRootCause(e.target.value)} className={`${fieldClass} py-2`} />
        </Field>
        {!reported && (
          <>
            <label className="flex items-center gap-2 text-sm text-ink">
              <input type="checkbox" checked={notRequired} onChange={(e) => setNotRequired(e.target.checked)} className="h-4 w-4 accent-brand" />
              {t('dataIncident.notRequired')}
            </label>
            {notRequired && (
              <Field id={`${ids}-noreport`} label={t('dataIncident.noReportReason')}>
                <textarea id={`${ids}-noreport`} rows={2} value={noReportReason} onChange={(e) => setNoReportReason(e.target.value)} className={`${fieldClass} py-2`} />
              </Field>
            )}
            {!notRequired && <p className="m-0 text-sm text-warning">{t('dataIncident.mustReportFirst')}</p>}
          </>
        )}
      </div>
      {pinOpen && (
        <SecurityConfirmModal
          isOpen
          onClose={() => setPinOpen(false)}
          onVerify={(credentials) => adminApi.dataIncidentAction(incident.id, 'close', { ...payload(), ...credentials })}
          onConfirm={onSaved}
          title={t('dataIncident.pinTitle')}
          description={t('dataIncident.pinDesc')}
          confirmText={t('dataIncident.close')}
          dangerLevel="primary"
        />
      )}
    </Modal>
  );
};

const Countdown = ({ incident, now }) => {
  const { t } = useLanguageSafe();
  if (incident.status === 'CLOSED' || incident.authority_reported_at || incident.report_not_required) return null;
  const left = new Date(incident.deadline).getTime() - now;
  const tone = left < 0 ? 'bg-danger-soft text-danger' : left < 24 * 3600 * 1000 ? 'bg-warning-soft text-warning' : 'bg-info-soft text-info';
  return (
    <div role="timer" aria-live="off" className={`rounded-lg px-3 py-2 text-sm font-semibold tabular-nums ${tone}`}>
      {left < 0 ? t('dataIncident.overdueBy', { time: formatDuration(left) }) : t('dataIncident.timeLeft', { time: formatDuration(left) })}
    </div>
  );
};

const IncidentCard = ({ incident, now, onEdit, onAction, onReport, onClose, busy }) => {
  const { t } = useLanguageSafe();
  const headingId = useId();
  const open = incident.status !== 'CLOSED';
  const rows = [
    [t('dataIncident.detectedAt'), formatDateTime(incident.detected_at)],
    [t('dataIncident.fields.source'), t(`dataIncident.sources.${incident.source}`)],
    [t('dataIncident.fields.dataTypes'), incident.data_types || '—'],
    [t('dataIncident.fields.affectedUsers'), incident.affected_users ?? '—'],
    [t('dataIncident.authority'), incident.authority_reported_at ? `${formatDateTime(incident.authority_reported_at)}${incident.authority_report_ref ? ` · ${incident.authority_report_ref}` : ''}` : incident.report_not_required ? t('dataIncident.notRequiredShort') : '—'],
    [t('dataIncident.users'), incident.users_notified_at ? formatDateTime(incident.users_notified_at) : '—'],
  ];
  if (incident.root_cause) rows.push([t('dataIncident.rootCause'), incident.root_cause]);

  return (
    <article aria-labelledby={headingId} className="flex flex-col gap-3 rounded-xl border border-line bg-card p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 id={headingId} className="m-0 text-base font-semibold text-ink">
            <span className="font-mono text-ink-muted">{incident.code}</span> {incident.title}
          </h3>
          <div className="mt-1 flex flex-wrap gap-1.5">
            <Badge tone={STATUS_TONE[incident.status] || 'neutral'}>{t(`dataIncident.status.${incident.status}`)}</Badge>
            {incident.sensitive && <Badge tone="danger">{t('dataIncident.sensitiveBadge')}</Badge>}
            {incident.reportedLate && <Badge tone="warning">{t('dataIncident.lateBadge')}</Badge>}
          </div>
        </div>
        <Countdown incident={incident} now={now} />
      </div>
      <p className="m-0 whitespace-pre-wrap text-sm text-ink-muted">{incident.description}</p>
      <dl className="m-0 grid grid-cols-1 gap-x-6 gap-y-1 text-sm sm:grid-cols-2">
        {rows.map(([label, value]) => (
          <div key={label} className="flex gap-2">
            <dt className="shrink-0 text-ink-faint">{label}:</dt>
            <dd className="m-0 text-ink">{value}</dd>
          </div>
        ))}
      </dl>
      {open && (
        <div className="flex flex-wrap gap-2 border-t border-line pt-3">
          <Button size="sm" variant="ghost" icon="edit" onClick={() => onEdit(incident)}>{t('dataIncident.edit')}</Button>
          {incident.status === 'OPEN' && <Button size="sm" loading={busy === 'contain'} onClick={() => onAction(incident, 'contain')}>{t('dataIncident.contain')}</Button>}
          {!incident.authority_reported_at && <Button size="sm" onClick={() => onReport(incident)}>{t('dataIncident.report')}</Button>}
          {!incident.users_notified_at && <Button size="sm" loading={busy === 'notify-users'} onClick={() => onAction(incident, 'notify-users')}>{t('dataIncident.notifyUsers')}</Button>}
          <Button size="sm" variant="danger-ghost" onClick={() => onClose(incident)}>{t('dataIncident.close')}</Button>
        </div>
      )}
    </article>
  );
};

const DataIncidentsTab = () => {
  const { t } = useLanguageSafe();
  const notify = useAlertSafe();
  const socket = useSocket();
  const now = useNow();
  const [list, setList] = useState(null);
  const [form, setForm] = useState(null);
  const [reporting, setReporting] = useState(null);
  const [closing, setClosing] = useState(null);
  const [busy, setBusy] = useState({});

  const latest = useRef({ notify, t });
  latest.current = { notify, t };

  const load = useCallback(async () => {
    try {
      const res = await adminApi.getDataIncidents();
      setList(Array.isArray(res?.data) ? res.data : []);
    } catch (err) {
      setList([]);
      const { notify: alert, t: tr } = latest.current;
      if (alert) alert.error(errorText(err, tr('dataIncident.loadFailed')));
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (!socket) return undefined;
    socket.on('admin.data_incident_changed', load);
    return () => socket.off('admin.data_incident_changed', load);
  }, [socket, load]);

  const done = () => {
    setForm(null);
    setReporting(null);
    setClosing(null);
    load();
  };

  const runAction = async (incident, action) => {
    setBusy((prev) => ({ ...prev, [incident.id]: action }));
    try {
      await adminApi.dataIncidentAction(incident.id, action, {});
      load();
    } catch (err) {
      if (notify) notify.error(errorText(err, t('dataIncident.saveFailed')));
    } finally {
      setBusy((prev) => ({ ...prev, [incident.id]: null }));
    }
  };

  return (
    <Card title={t('dataIncident.title')} actions={<Button variant="primary" size="sm" icon="add" onClick={() => setForm({ mode: 'create' })}>{t('dataIncident.create')}</Button>} padded>
      <p className="m-0 mb-4 text-sm text-ink-muted">{t('dataIncident.intro')}</p>
      {list === null ? (
        <div className="flex justify-center py-8 text-brand"><Spinner /></div>
      ) : list.length === 0 ? (
        <EmptyState icon="verified_user" title={t('dataIncident.empty')} />
      ) : (
        <div className="flex flex-col gap-3">
          {list.map((incident) => (
            <IncidentCard
              key={incident.id}
              incident={incident}
              now={now}
              busy={busy[incident.id]}
              onEdit={(i) => setForm({ mode: 'edit', incident: i })}
              onAction={runAction}
              onReport={setReporting}
              onClose={setClosing}
            />
          ))}
        </div>
      )}
      {form && <IncidentForm initial={form.mode === 'edit' ? form.incident : null} onClose={() => setForm(null)} onSaved={done} />}
      {reporting && <ReportModal incident={reporting} onClose={() => setReporting(null)} onSaved={done} />}
      {closing && <CloseModal incident={closing} onClose={() => setClosing(null)} onSaved={done} />}
    </Card>
  );
};

export default DataIncidentsTab;
