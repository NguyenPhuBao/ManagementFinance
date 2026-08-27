import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { USER_STATUS_LABELS } from '../../utils/constants';
import adminApi from '../../api/admin.api';

const UserDetailPage = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchUser = async () => {
      try {
        const res = await adminApi.getUserById(id);
        setUser(res.data);
      } catch (err) {
        setError(err.response?.data?.message || 'Không tìm thấy người dùng');
      } finally {
        setLoading(false);
      }
    };
    fetchUser();
  }, [id]);

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: 48 }}>
        <span className="material-symbols-outlined animate-spin" style={{ fontSize: 48, color: 'var(--color-primary)' }}>progress_activity</span>
        <h3 style={{ fontSize: 20, fontWeight: 600, marginTop: 16 }}>Đang tải...</h3>
      </div>
    );
  }

  if (!user) {
    return (
      <div style={{ textAlign: 'center', padding: 48 }}>
        <span className="material-symbols-outlined" style={{ fontSize: 48, color: 'var(--color-outline)' }}>person_off</span>
        <h3 style={{ fontSize: 20, fontWeight: 600, marginTop: 16 }}>{error || 'Không tìm thấy người dùng'}</h3>
        <button onClick={() => navigate('/users')} style={{ marginTop: 16, padding: '8px 16px', backgroundColor: 'var(--color-primary)', color: '#ffffff', border: 'none', borderRadius: 8, cursor: 'pointer' }}>
          Quay lại danh sách
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
        Quay lại danh sách
      </button>

      <div style={{ backgroundColor: '#ffffff', border: '1px solid var(--color-outline-variant)', borderRadius: 'var(--radius-xl)', padding: 32 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 32 }}>
          <h1 style={{ fontSize: 'var(--fs-headline-md)', color: 'var(--color-on-surface)' }}>Chi tiết người dùng</h1>
          <span style={{
            display: 'inline-flex',
            padding: '2px 12px',
            borderRadius: 9999,
            fontSize: 12,
            fontWeight: 600,
            backgroundColor: isActive ? '#dcfce7' : '#f1f5f9',
            color: isActive ? '#166534' : '#475569',
          }}>
            {USER_STATUS_LABELS[user.status?.toLowerCase()] || user.status}
          </span>
        </div>

        {/* Personal Info */}
        <div style={{ marginBottom: 32 }}>
          <h3 style={{ fontSize: 'var(--fs-label-md)', color: 'var(--color-outline)', textTransform: 'uppercase', marginBottom: 16 }}>
            Thông tin cá nhân
          </h3>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
            <DetailItem label="ID User" value={user.id} />
            <DetailItem label="Họ tên" value={user.fullname} />
            <DetailItem label="Email" value={user.email} />
            <DetailItem label="Số điện thoại" value={user.phone || '—'} />
            <DetailItem label="Địa chỉ" value={user.address || '—'} />
            <DetailItem label="Mã vùng" value={user.country_code || '—'} />
          </div>
        </div>

        <hr style={{ border: 'none', borderTop: '1px solid var(--color-outline-variant)', opacity: 0.5, marginBottom: 32 }} />

        {/* Account Info */}
        <div>
          <h3 style={{ fontSize: 'var(--fs-label-md)', color: 'var(--color-outline)', textTransform: 'uppercase', marginBottom: 16 }}>
            Thông tin tài khoản
          </h3>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
            <DetailItem label="ID Account" value={user.id} />
            <DetailItem label="Username" value={user.username} />
            <DetailItem label="Trạng thái" value={USER_STATUS_LABELS[user.status?.toLowerCase()] || user.status} />
            <DetailItem label="Vai trò" value={user.rolename} />
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
