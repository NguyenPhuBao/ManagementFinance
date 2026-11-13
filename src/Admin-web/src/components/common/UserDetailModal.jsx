import React, { useState, useEffect } from 'react';
import adminApi from '../../api/admin.api';
import { formatDateTime, maskPhone } from '../../utils/format';
import { useLanguageSafe } from '../../store/language.context';
import { Badge, EmptyState, Modal, Spinner } from '../ui';
import UserDevices from './UserDevices';

const STATUS_TONE = { active: 'success', inactive: 'neutral', pendingdelete: 'warning', deleted: 'danger' };

const Row = ({ label, children }) => (
  <div className="flex items-start justify-between gap-4 py-2.5">
    <dt className="text-sm text-ink-muted">{label}</dt>
    <dd className="m-0 max-w-[60%] text-right text-sm font-medium text-ink">{children}</dd>
  </div>
);

const Section = ({ title, children }) => (
  <section className="pt-4">
    <h3 className="m-0 mb-1 text-xs font-semibold uppercase tracking-wide text-ink-faint">{title}</h3>
    <dl className="m-0 divide-y divide-line">{children}</dl>
  </section>
);

const UserDetailModal = ({ userId, onClose }) => {
  const { t } = useLanguageSafe();
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [pinOpen, setPinOpen] = useState(false);

  useEffect(() => {
    if (!userId) return;
    setLoading(true);
    setError('');
    adminApi
      .getUserById(userId)
      .then((res) => setUser(res.data))
      .catch((err) => setError(err.response?.data?.message || t('users.detail.notFound')))
      .finally(() => setLoading(false));
  }, [userId]);

  const status = user?.status?.toLowerCase();
  const statusText =
    status === 'pendingdelete' && user?.countdown != null
      ? t('users.table.pendingDeleteCountdown', { days: user.countdown })
      : t(`commonStatus.${status}`, user?.status);

  return (
    <Modal open onClose={onClose} closeDisabled={pinOpen} title={t('users.detail.title')} size="md">
      {loading ? (
        <div className="flex justify-center py-10 text-brand">
          <Spinner size="lg" />
        </div>
      ) : error ? (
        <EmptyState icon="person_off" title={error} />
      ) : (
        user && (
          <div>
            <div className="flex items-center justify-between border-b border-line pb-3">
              <span className="text-sm text-ink-muted">{t('users.detail.status')}</span>
              <Badge tone={STATUS_TONE[status] || 'neutral'}>{statusText}</Badge>
            </div>
            <Section title={t('users.detail.personalInfo')}>
              <Row label={t('users.detail.idUser')}>{user.id}</Row>
              <Row label={t('users.detail.fullname')}>{user.fullname || '—'}</Row>
              <Row label={t('users.detail.email')}>{user.email || '—'}</Row>
              <Row label={t('users.detail.phone')}>{maskPhone(user.phone)}</Row>
              <Row label={t('users.detail.address')}>{user.address || '—'}</Row>
              <Row label={t('users.detail.countryCode')}>{user.country_code || '—'}</Row>
            </Section>
            <Section title={t('users.detail.accountInfo')}>
              <Row label={t('users.detail.username')}>{user.username}</Row>
              <Row label={t('users.detail.role')}>{user.rolename || '—'}</Row>
              <Row label={t('users.detail.package')}>
                <Badge tone={(user.type || '').toLowerCase() === 'premium' ? 'warning' : 'neutral'}>{user.type || 'Basic'}</Badge>
              </Row>
              {status === 'pendingdelete' && (
                <Row label={t('users.detail.pendingDays')}>{t('users.detail.pendingDaysValue', { days: user.countdown ?? 30 })}</Row>
              )}
              {user.reason_inactive && <Row label={t('users.detail.reasonInactive')}>{user.reason_inactive}</Row>}
              {user.delete_at && (
                <Row label={status === 'pendingdelete' ? t('users.detail.scheduledDelete') : t('users.detail.deletedAt')}>
                  {formatDateTime(user.delete_at)}
                </Row>
              )}
              <Row label={t('users.detail.createdAt')}>{user.created_at ? formatDateTime(user.created_at) : '—'}</Row>
            </Section>
            <UserDevices userId={userId} onPinOpenChange={setPinOpen} />
          </div>
        )
      )}
    </Modal>
  );
};

export default UserDetailModal;
