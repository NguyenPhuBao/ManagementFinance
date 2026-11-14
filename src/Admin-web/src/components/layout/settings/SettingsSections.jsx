import React, { useEffect, useId, useState } from 'react';
import soundService from '../../../services/sound.service';
import { useLanguageSafe } from '../../../store/language.context';
import { useAlertSafe } from '../../../store/alert.context';
import { API_BASE_URL } from '../../../utils/constants';
import { Badge, Button } from '../../ui';
import { ChoiceGroup, SettingRow, Switch, selectClass } from './settingsUi';

export const GeneralSection = ({ settings, updateSetting }) => {
  const { t, language, changeLanguage } = useLanguageSafe();
  const langButton = (code, label) => (
    <Button size="sm" variant={language === code ? 'primary' : 'secondary'} aria-pressed={language === code} data-testid={`settings-lang-${code}`} onClick={() => changeLanguage(code)}>
      {label}
    </Button>
  );
  return (
    <div className="flex flex-col gap-3">
      <SettingRow testId="settings-language-section" label={t('settings.general.language')} hint={t('settings.general.languageHint')}>
        {langButton('vi', 'Tiếng Việt')}
        {langButton('en', 'English')}
      </SettingRow>
      <SettingRow label={t('settings.general.theme')}>
        <ChoiceGroup
          label={t('settings.general.theme')}
          value={settings.theme}
          onChange={(v) => updateSetting('theme', v)}
          options={[
            { value: 'light', label: t('settings.general.light') },
            { value: 'dark', label: t('settings.general.dark') },
          ]}
        />
      </SettingRow>
      <SettingRow label={t('settings.general.density')} hint={t('settings.general.densityHint')}>
        <ChoiceGroup
          label={t('settings.general.density')}
          value={settings.tableDensity}
          onChange={(v) => updateSetting('tableDensity', v)}
          options={[
            { value: 'comfortable', label: t('settings.general.comfortable') },
            { value: 'compact', label: t('settings.general.compact') },
          ]}
        />
      </SettingRow>
    </div>
  );
};

export const NotificationSection = ({ settings, updateSetting }) => {
  const { t } = useLanguageSafe();
  const ids = useId();
  return (
    <div className="flex flex-col gap-3">
      <SettingRow label={t('settings.alerts.sound')} hint={t('settings.alerts.soundHint')}>
        <Button size="sm" icon="volume_up" onClick={() => soundService.playCriticalAlarm()}>
          {t('settings.alerts.test')}
        </Button>
        <Switch label={t('settings.alerts.sound')} checked={Boolean(settings.soundEnabled)} onChange={(v) => updateSetting('soundEnabled', v)} />
      </SettingRow>
      <SettingRow htmlFor={`${ids}-toast`} label={t('settings.alerts.toast')} hint={t('settings.alerts.toastHint')}>
        <select id={`${ids}-toast`} value={settings.toastDuration} onChange={(e) => updateSetting('toastDuration', Number(e.target.value))} className={selectClass}>
          {[3000, 4500, 7000, 10000].map((ms) => (
            <option key={ms} value={ms}>
              {t('settings.alerts.seconds', { n: (ms / 1000).toLocaleString('vi-VN') })}
            </option>
          ))}
        </select>
      </SettingRow>
      <SettingRow label={t('settings.alerts.badge')} hint={t('settings.alerts.badgeHint')}>
        <Switch label={t('settings.alerts.badge')} checked={Boolean(settings.showUnreadBadge)} onChange={(v) => updateSetting('showUnreadBadge', v)} />
      </SettingRow>
    </div>
  );
};

export const ConnectionSection = ({ socket, settings, updateSetting, pingLatency, isPinging, testPingLatency }) => {
  const { t } = useLanguageSafe();
  const notify = useAlertSafe();
  const ids = useId();
  const [live, setLive] = useState(Boolean(socket?.connected));

  useEffect(() => {
    if (!socket || typeof socket.on !== 'function') return undefined;
    setLive(Boolean(socket.connected));
    const onConnect = () => setLive(true);
    const onDisconnect = () => setLive(false);
    socket.on('connect', onConnect);
    socket.on('disconnect', onDisconnect);
    return () => {
      socket.off('connect', onConnect);
      socket.off('disconnect', onDisconnect);
    };
  }, [socket]);

  useEffect(() => {
    if (!socket || !live) return undefined;
    testPingLatency(socket);
    const timer = setInterval(() => socket.connected && testPingLatency(socket), 5000);
    return () => clearInterval(timer);
  }, [socket, live, testPingLatency]);

  const pingNow = async () => {
    const latency = await testPingLatency(socket);
    if (!notify) return;
    if (latency === -1) notify.error(t('settings.connection.pingFailed'));
    else notify.success(t('settings.connection.pingResult', { ms: latency }));
  };

  const hasLatency = pingLatency !== null && pingLatency !== -1;

  return (
    <div className="flex flex-col gap-3">
      <SettingRow label={t('settings.connection.status')} hint={live && socket?.id ? t('settings.connection.sessionId', { id: socket.id.slice(0, 8) }) : t('settings.connection.statusHint')}>
        <Badge tone={live ? 'success' : 'danger'}>{live ? t('settings.connection.online') : t('settings.connection.offline')}</Badge>
        <Button size="sm" icon="speed" loading={isPinging} disabled={!live} onClick={pingNow}>
          {hasLatency ? `${pingLatency} ms` : t('settings.connection.ping')}
        </Button>
      </SettingRow>
      <SettingRow htmlFor={`${ids}-metrics`} label={t('settings.connection.metrics')} hint={t('settings.connection.metricsHint')}>
        <select id={`${ids}-metrics`} value={settings.metricsInterval} onChange={(e) => updateSetting('metricsInterval', Number(e.target.value))} className={selectClass}>
          {[1, 3, 5, 10].map((s) => (
            <option key={s} value={s}>
              {t('settings.alerts.seconds', { n: s })}
            </option>
          ))}
        </select>
      </SettingRow>
    </div>
  );
};

export const SecuritySection = ({ settings, updateSetting, usageKb, onChangePin, onLockNow, onClearCache }) => {
  const { t } = useLanguageSafe();
  const ids = useId();
  const info = [
    [t('settings.security.environment'), import.meta.env.MODE || 'development'],
    [t('settings.security.server'), API_BASE_URL],
    [t('settings.security.timezone'), 'Asia/Ho_Chi_Minh (GMT+7)'],
  ];
  return (
    <div className="flex flex-col gap-3">
      <SettingRow testId="settings-pin-section" label={t('settings.security.pin')} hint={t('settings.security.pinHint')}>
        <Button size="sm" icon="pin" onClick={onChangePin}>
          {t('settings.pin.title')}
        </Button>
      </SettingRow>
      <SettingRow htmlFor={`${ids}-lock`} label={t('settings.security.autoLock')} hint={t('settings.security.autoLockHint')}>
        <select id={`${ids}-lock`} value={settings.autoLockMinutes} onChange={(e) => updateSetting('autoLockMinutes', Number(e.target.value))} className={selectClass}>
          {[15, 30, 60].map((m) => (
            <option key={m} value={m}>
              {t('settings.security.minutes', { n: m })}
            </option>
          ))}
          <option value={0}>{t('settings.security.never')}</option>
        </select>
        <Button size="sm" icon="lock" onClick={onLockNow}>
          {t('settings.security.lockNow')}
        </Button>
      </SettingRow>
      <SettingRow label={t('settings.security.cache')} hint={t('settings.security.cacheHint', { kb: usageKb })}>
        <Button size="sm" variant="danger-ghost" icon="delete_sweep" onClick={onClearCache}>
          {t('settings.security.clearCache')}
        </Button>
      </SettingRow>
      <div className="rounded-lg border border-line px-4 py-3 text-sm">
        <div className="mb-1 font-medium text-ink">{t('settings.security.platform')}</div>
        {info.map(([label, value]) => (
          <div key={label} className="flex justify-between gap-3 py-0.5">
            <span className="text-ink-muted">{label}</span>
            <span className="break-all text-right font-mono text-xs text-ink">{value}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

export const AdminSection = ({ user, onChangePin, onChangePassword, onCreateAdmin }) => {
  const { t } = useLanguageSafe();
  const name = user?.Username || user?.username || 'Admin';
  const actions = [
    { key: 'pin', icon: 'pin', title: t('settings.pin.title'), hint: t('settings.admin.pinHint'), testId: 'open-change-pin-btn', onClick: onChangePin },
    { key: 'password', icon: 'key', title: t('settings.password.title'), hint: t('settings.admin.passwordHint'), testId: 'open-change-password-btn', onClick: onChangePassword },
    { key: 'create', icon: 'person_add', title: t('settings.createAdmin.title'), hint: t('settings.admin.createHint'), testId: 'open-create-admin-btn', onClick: onCreateAdmin },
  ];
  return (
    <div className="flex flex-col gap-3" data-testid="settings-admin-mgmt-section">
      <div className="flex items-center gap-3 rounded-lg border border-line px-4 py-3">
        <span className="flex h-10 w-10 items-center justify-center rounded-full bg-brand-soft font-semibold text-brand">{name[0]?.toUpperCase()}</span>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <span className="font-medium text-ink">{name}</span>
            <Badge tone="info">{user?.Role || user?.rolename || 'Admin'}</Badge>
          </div>
          <div className="text-sm text-ink-muted">{user?.Email || user?.email || '—'}</div>
        </div>
      </div>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        {actions.map((a) => (
          <div key={a.key} className="flex flex-col justify-between gap-3 rounded-lg border border-line p-4">
            <div>
              <div className="font-medium text-ink">{a.title}</div>
              <p className="m-0 mt-1 text-sm text-ink-muted">{a.hint}</p>
            </div>
            <Button size="sm" icon={a.icon} data-testid={a.testId} onClick={a.onClick}>
              {a.title}
            </Button>
          </div>
        ))}
      </div>
    </div>
  );
};
