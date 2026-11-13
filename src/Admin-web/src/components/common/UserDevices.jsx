import React, { useEffect, useId, useState } from 'react';
import adminApi from '../../api/admin.api';
import { formatDateTime } from '../../utils/format';
import { deviceLabel } from '../../utils/device-label.util';
import { useLanguageSafe } from '../../store/language.context';
import { Button, SecurityConfirmModal, Spinner } from '../ui';

const UserDevices = ({ userId, onPinOpenChange }) => {
  const { t } = useLanguageSafe();
  const headingId = useId();
  const [devices, setDevices] = useState(null);
  const [error, setError] = useState('');
  const [revealed, setRevealed] = useState({});
  const [target, setTarget] = useState(null);

  useEffect(() => {
    if (!userId) return;
    setDevices(null);
    setError('');
    setRevealed({});
    adminApi
      .getUserDevices(userId)
      .then((res) => setDevices(Array.isArray(res?.data) ? res.data : []))
      .catch((err) => {
        setDevices([]);
        setError(err.response?.data?.message || t('users.detail.devices.loadFailed'));
      });
  }, [userId]);

  const openPin = (device) => {
    setTarget(device);
    if (onPinOpenChange) onPinOpenChange(true);
  };

  const closePin = () => {
    setTarget(null);
    if (onPinOpenChange) onPinOpenChange(false);
  };

  const reveal = async (credentials) => {
    const res = await adminApi.revealDeviceIp(userId, target.id, credentials);
    const ip = res?.data?.ip;
    if (ip) setRevealed((prev) => ({ ...prev, [target.id]: ip }));
  };

  return (
    <section aria-labelledby={headingId} className="pt-4">
      <h3 id={headingId} className="m-0 mb-1 text-xs font-semibold uppercase tracking-wide text-ink-faint">
        {t('users.detail.devices.title')}
      </h3>
      {devices === null ? (
        <div className="flex justify-center py-4 text-brand">
          <Spinner />
        </div>
      ) : error ? (
        <p className="m-0 py-2 text-sm text-danger">{error}</p>
      ) : devices.length === 0 ? (
        <p className="m-0 py-2 text-sm text-ink-muted">{t('users.detail.devices.empty')}</p>
      ) : (
        <ul className="m-0 list-none divide-y divide-line p-0">
          {devices.map((d) => (
            <li key={d.id} className="flex items-center justify-between gap-3 py-2.5">
              <div className="min-w-0">
                <p className="m-0 truncate text-sm font-medium text-ink" title={d.device_name}>
                  {deviceLabel(d.device_name, t)}
                </p>
                <p className="m-0 text-sm text-ink-muted">
                  <span className="font-mono tabular-nums">{revealed[d.id] || d.ip_address}</span>
                  {' · '}
                  {t('users.detail.devices.lastActive', { time: formatDateTime(d.last_active_at) })}
                </p>
              </div>
              {revealed[d.id] ? null : d.canRevealIp ? (
                <Button variant="ghost" size="sm" icon="visibility" aria-label={t('users.detail.devices.reveal')} onClick={() => openPin(d)} />
              ) : (
                <span className="shrink-0 text-xs text-ink-faint">{t('users.detail.devices.expired')}</span>
              )}
            </li>
          ))}
        </ul>
      )}
      {target && (
        <SecurityConfirmModal
          isOpen
          onClose={closePin}
          onVerify={reveal}
          title={t('users.detail.devices.reveal')}
          description={t('users.detail.devices.revealDesc')}
          confirmText={t('users.detail.devices.revealBtn')}
          dangerLevel="primary"
        />
      )}
    </section>
  );
};

export default UserDevices;
