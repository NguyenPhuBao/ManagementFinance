import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { USER_STATUS_LABELS } from '../../utils/constants';
import adminApi from '../../api/admin.api';
import { useLanguageSafe } from '../../store/language.context';

const UserDetailPage = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const { t } = useLanguageSafe();
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchUser = async () => {
      try {
        const res = await adminApi.getUserById(id);
        setUser(res.data);
      } catch (err) {
        setError(err.response?.data?.message || t('users.detail.notFound'));
      } finally {
        setLoading(false);
      }
    };
    fetchUser();
  }, [id, t]);

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: 48 }}>
        <span className="material-symbols-outlined animate-spin" style={{ fontSize: 48, color: 'var(--color-primary)' }}>progress_activity</span>
        <h3 style={{ fontSize: 20, fontWeight: 600, marginTop: 16 }}>{t('common.loadingData')}</h3>
      </div>
    );
  }

  if (!user) {
    return (
      <div style={{ textAlign: 'center', padding: 48 }}>
        <span className="material-symbols-outlined" style={{ fontSize: 48, color: 'var(--color-outline)' }}>person_off</span>
        <h3 style={{ fontSize: 20, fontWeight: 600, marginTop: 16 }}>{error || t('users.detail.notFound')}</h3>
        <button onClick={() => navigate('/users')} style={{ marginTop: 16, padding: '8px 16px', backgroundColor: 'var(--color-primary)', color: '#ffffff', border: 'none', borderRadius: 8, cursor: 'pointer' }}>
          {t('users.detail.backToList')}
        </button>
      </div>
    );
  }

  const isActive = user.status?.toLowerCase() === 'active';

  return (
    <div>
      {/* Back button */}
      <button
        onClick={() => navigate('/users')}
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          background: 'none',
          border: 'none',
          color: 'var(--color-primary)',
          fontSize: 'var(--fs-body-md)',
          fontWeight: 600,
          cursor: 'pointer',
          marginBottom: 24,
        }}
      >
        <span className="material-symbols-outlined" style={{ fontSize: 20 }}>arrow_back</span>
        {t('users.detail.backToList')}
      </button>

      <div style={{ backgroundColor: '#ffffff', border: '1px solid var(--color-outline-variant)', borderRadius: 'var(--radius-xl)', padding: 32 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 32 }}>
          <h1 style={{ fontSize: 'var(--fs-headline-md)', color: 'var(--color-on-surface)' }}>{t('users.detail.title')}</h1>
          <span style={{
            display: 'inline-flex',
            padding: '2px 12px',
            borderRadius: 9999,
            fontSize: 12,
            fontWeight: 600,
            backgroundColor: isActive ? '#dcfce7' : '#f1f5f9',
            color: isActive ? '#166534' : '#475569',
          }}>
            {t(`commonStatus.${user.status}`) || USER_STATUS_LABELS[user.status?.toLowerCase()] || user.status}
          </span>
        </div>

        {/* Personal Info */}
        <div style={{ marginBottom: 32 }}>
          <h3 style={{ fontSize: 'var(--fs-label-md)', color: 'var(--color-outline)', textTransform: 'uppercase', marginBottom: 16 }}>
            {t('users.detail.personalInfo')}
          </h3>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
            <DetailItem label={t('users.detail.idUser')} value={user.id} />
            <DetailItem label={t('users.detail.fullname')} value={user.fullname} />
            <DetailItem label={t('users.detail.email')} value={user.email} />
            <DetailItem label={t('users.detail.phone')} value={user.phone || '—'} />
            <DetailItem label={t('users.detail.address')} value={user.address || '—'} />
            <DetailItem label={t('users.detail.countryCode')} value={user.country_code || '—'} />
          </div>
        </div>

        <hr style={{ border: 'none', borderTop: '1px solid var(--color-outline-variant)', opacity: 0.5, marginBottom: 32 }} />

        {/* Account Info */}
        <div>
          <h3 style={{ fontSize: 'var(--fs-label-md)', color: 'var(--color-outline)', textTransform: 'uppercase', marginBottom: 16 }}>
            {t('users.detail.accountInfo')}
          </h3>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
            <DetailItem label={t('users.detail.idAccount')} value={user.id} />
            <DetailItem label={t('users.detail.username')} value={user.username} />
            <DetailItem label={t('users.filterModal.statusLabel')} value={t(`commonStatus.${user.status}`) || USER_STATUS_LABELS[user.status?.toLowerCase()] || user.status} />
            <DetailItem label={t('users.detail.role')} value={user.rolename} />
          </div>
        </div>
      </div>
    </div>
  );
};

const DetailItem = ({ label, value }) => (
  <div>
    <p style={{ fontSize: 'var(--fs-label-md)', fontWeight: 600, color: 'var(--color-outline)', textTransform: 'uppercase', marginBottom: 4 }}>
      {label}
    </p>
    <p style={{ fontSize: 'var(--fs-body-md)', color: 'var(--color-on-surface)' }}>
      {value || '—'}
    </p>
  </div>
);

export default UserDetailPage;
