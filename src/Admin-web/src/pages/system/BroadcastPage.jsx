import React, { useCallback, useEffect, useRef, useState } from 'react';
import adminApi from '../../api/admin.api';
import useSocket from '../../hooks/useSocket';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import { formatDateTime } from '../../utils/format';
import { Badge, Button, ConfirmModal, Icon, PageHeader, Tabs } from '../../components/ui';
import MaintenanceTab from './broadcast/MaintenanceTab';
import BroadcastTab from './broadcast/BroadcastTab';
import PolicyTab from './broadcast/PolicyTab';
import { scheduledListOf } from './broadcast/maintenanceFormat';

const IDLE = { active: false, isEmergency: false, reason: '', activatedBy: null, activatedAt: null, scheduled: null, scheduledList: [] };
const unwrap = (res) => res?.data || res;

const BroadcastPage = () => {
  const { t } = useLanguageSafe();
  const notify = useAlertSafe();
  const socket = useSocket();
  const [tab, setTab] = useState('maintenance');
  const [maintenance, setMaintenance] = useState(IDLE);
  const [busy, setBusy] = useState(false);
  const [version, setVersion] = useState(0);
  const [confirmStop, setConfirmStop] = useState(false);
  const initiator = useRef(false);
  const tRef = useRef(t);
  tRef.current = t;
  const notifyRef = useRef(notify);
  notifyRef.current = notify;

  const loadStatus = useCallback(async () => {
    try {
      const data = unwrap(await adminApi.getMaintenanceStatus());
      if (data) setMaintenance(data);
    } catch (err) {
      console.error('[MAINTENANCE] Lỗi tải trạng thái bảo trì:', err);
    }
  }, []);

  useEffect(() => {
    loadStatus();
  }, [loadStatus]);

  useEffect(() => {
    if (!socket) return undefined;
    const onChanged = (state) => {
      if (!state) return;
      setMaintenance(state);
      setVersion((v) => v + 1);
      if (initiator.current) {
        initiator.current = false;
        return;
      }
      const n = notifyRef.current;
      if (!n) return;
      if (state.active) n.warning(state.reason || tRef.current('broadcast.feedback.emergencyOn'), tRef.current('broadcast.feedback.title'));
      else n.success(tRef.current('broadcast.feedback.ended'), tRef.current('broadcast.feedback.title'));
    };
    socket.on('admin.maintenance_changed', onChanged);
    return () => socket.off('admin.maintenance_changed', onChanged);
  }, [socket]);

  const act = useCallback(
    async (call, successText, failText) => {
      initiator.current = true;
      setBusy(true);
      try {
        const data = unwrap(await call());
        if (data) setMaintenance(data);
        setVersion((v) => v + 1);
        if (notify) notify.success(successText, t('broadcast.feedback.title'));
        return true;
      } catch (err) {
        initiator.current = false;
        if (notify) notify.error(err?.response?.data?.message || failText, t('broadcast.feedback.errorTitle'));
        return false;
      } finally {
        setBusy(false);
      }
    },
    [notify, t]
  );

  const stopMaintenance = async () => {
    setConfirmStop(false);
    await act(
      () =>
        adminApi.setMaintenanceStatus({
          active: false,
          reason: (maintenance.reason || '').trim() || t('broadcast.defaults.emergencyReason'),
          isEmergency: true,
        }),
      t('broadcast.feedback.ended'),
      t('broadcast.feedback.failed')
    );
  };

  const dot = maintenance.active ? (maintenance.isEmergency ? 'bg-danger' : 'bg-warning') : scheduledListOf(maintenance).length ? 'bg-info' : null;

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t('broadcast.title')}
        description={t('broadcast.subtitle')}
        actions={
          <Tabs
            ariaLabel={t('broadcast.tabsLabel')}
            value={tab}
            onChange={setTab}
            items={[
              {
                key: 'maintenance',
                label: (
                  <span className="inline-flex items-center gap-1.5">
                    {t('broadcast.tabMaintenance')}
                    {dot && <span aria-hidden="true" className={`h-2 w-2 rounded-full ${dot}`} />}
                  </span>
                ),
              },
              { key: 'broadcast', label: t('broadcast.tabBroadcast') },
              { key: 'policy', label: t('broadcast.tabPolicy') },
            ]}
          />
        }
      />

      {maintenance.active && (
        <div
          className={`flex flex-wrap items-center justify-between gap-4 rounded-xl border px-5 py-4 ${
            maintenance.isEmergency ? 'border-danger bg-danger-soft' : 'border-warning bg-warning-soft'
          }`}
        >
          <div className="flex min-w-0 items-start gap-3">
            <Icon name={maintenance.isEmergency ? 'crisis_alert' : 'construction'} className={maintenance.isEmergency ? 'text-danger' : 'text-warning'} />
            <div className="min-w-0">
              <div className="flex flex-wrap items-center gap-2">
                <p className="m-0 font-semibold text-ink">
                  {maintenance.isEmergency ? t('broadcast.banner.emergencyTitle') : t('broadcast.banner.scheduledTitle')}
                </p>
                <Badge tone={maintenance.isEmergency ? 'danger' : 'warning'}>
                  {maintenance.isEmergency ? t('broadcast.banner.emergencyBadge') : t('broadcast.banner.scheduledBadge')}
                </Badge>
              </div>
              <p className="m-0 mt-1 text-sm text-ink">{maintenance.reason || t('broadcast.banner.noReason')}</p>
              <p className="m-0 mt-0.5 text-sm text-ink-muted">
                {[
                  maintenance.activatedBy && t('broadcast.banner.by', { name: maintenance.activatedBy }),
                  maintenance.activatedAt && t('broadcast.banner.since', { time: formatDateTime(maintenance.activatedAt) }),
                ]
                  .filter(Boolean)
                  .join(' · ')}
              </p>
            </div>
          </div>
          <Button icon="power_settings_new" disabled={busy} onClick={() => setConfirmStop(true)}>
            {t('broadcast.banner.stop')}
          </Button>
        </div>
      )}

      {tab === 'maintenance' ? (
        <MaintenanceTab maintenance={maintenance} busy={busy} act={act} version={version} onRefresh={loadStatus} />
      ) : tab === 'policy' ? (
        <PolicyTab />
      ) : (
        <BroadcastTab />
      )}

      <ConfirmModal
        open={confirmStop}
        title={t('broadcast.stopModal.title')}
        message={t('broadcast.stopModal.message')}
        confirmText={t('broadcast.stopModal.confirm')}
        loading={busy}
        onConfirm={stopMaintenance}
        onCancel={() => setConfirmStop(false)}
      />
    </div>
  );
};

export default BroadcastPage;
