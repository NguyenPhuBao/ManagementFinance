import React, { useState } from 'react';
import { useSettings } from '../../store/settings.context';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import { useAuthContext } from '../../store/auth.context';
import useSocket from '../../hooks/useSocket';
import { Button, ConfirmModal, Modal, Tabs } from '../ui';
import { AdminSection, ConnectionSection, GeneralSection, NotificationSection, SecuritySection } from './settings/SettingsSections';
import { ChangePasswordModal, ChangePinModal } from './settings/AccountModals';
import CreateAdminModal from './settings/CreateAdminModal';

const TABS = [
  { key: 'general', label: 'settings.tabs.general' },
  { key: 'notifications', label: 'settings.tabs.notifications' },
  { key: 'realtime', label: 'settings.tabs.realtime' },
  { key: 'system', label: 'settings.tabs.system' },
  { key: 'admin_mgmt', label: 'settings.tabs.admin' },
];

const useCurrentAdmin = () => {
  try {
    const ctx = useAuthContext() || {};
    return ctx.user || ctx.admin || null;
  } catch {
    return null;
  }
};

const SettingsModal = ({ isOpen, onClose }) => {
  const { t } = useLanguageSafe();
  const notify = useAlertSafe();
  const socket = useSocket();
  const user = useCurrentAdmin();
  const { settings, updateSetting, resetSettings, lockScreen, pingLatency, isPinging, testPingLatency, safeClearCache, getStorageUsageKb } = useSettings();
  const [tab, setTab] = useState('general');
  const [dialog, setDialog] = useState(null);

  if (!isOpen) return null;

  const closeDialog = () => setDialog(null);
  const shared = { settings, updateSetting };

  const clearCache = () => {
    safeClearCache();
    closeDialog();
    if (notify) notify.success(t('settings.security.cacheCleared'));
  };

  const resetDefaults = () => {
    resetSettings();
    closeDialog();
    if (notify) notify.info(t('settings.reset.done'));
  };

  const lockNow = () => {
    onClose();
    lockScreen();
  };

  return (
    <>
      <Modal
        open
        onClose={onClose}
        size="lg"
        closeDisabled={Boolean(dialog)}
        title={t('settings.title')}
        description={t('settings.subtitle')}
        footer={
          <div className="flex w-full items-center justify-between gap-2">
            <Button variant="ghost" icon="restart_alt" onClick={() => setDialog('reset')}>
              {t('settings.reset.button')}
            </Button>
            <Button variant="primary" onClick={onClose}>
              {t('settings.done')}
            </Button>
          </div>
        }
      >
        <div className="flex flex-col gap-4">
          <div className="overflow-x-auto">
            <Tabs
              ariaLabel={t('settings.title')}
              value={tab}
              onChange={setTab}
              items={TABS.map((x) => ({ key: x.key, label: t(x.label), testId: `settings-tab-${x.key}` }))}
            />
          </div>
          {tab === 'general' && <GeneralSection {...shared} />}
          {tab === 'notifications' && <NotificationSection {...shared} />}
          {tab === 'realtime' && <ConnectionSection {...shared} socket={socket} pingLatency={pingLatency} isPinging={isPinging} testPingLatency={testPingLatency} />}
          {tab === 'system' && (
            <SecuritySection
              {...shared}
              usageKb={getStorageUsageKb()}
              onChangePin={() => setDialog('pin')}
              onLockNow={lockNow}
              onClearCache={() => setDialog('cache')}
            />
          )}
          {tab === 'admin_mgmt' && (
            <AdminSection
              user={user}
              onChangePin={() => setDialog('pin')}
              onChangePassword={() => setDialog('password')}
              onCreateAdmin={() => setDialog('create')}
            />
          )}
        </div>
      </Modal>

      {dialog === 'pin' && <ChangePinModal open onClose={closeDialog} />}
      {dialog === 'password' && <ChangePasswordModal open onClose={closeDialog} />}
      {dialog === 'create' && <CreateAdminModal open onClose={closeDialog} />}

      <ConfirmModal
        open={dialog === 'cache'}
        title={t('settings.security.clearCache')}
        message={t('settings.security.clearCacheConfirm')}
        confirmText={t('settings.security.clearCacheAction')}
        confirmDanger
        onConfirm={clearCache}
        onCancel={closeDialog}
      />
      <ConfirmModal
        open={dialog === 'reset'}
        title={t('settings.reset.button')}
        message={t('settings.reset.confirm')}
        confirmText={t('settings.reset.action')}
        onConfirm={resetDefaults}
        onCancel={closeDialog}
      />
    </>
  );
};

export default SettingsModal;
