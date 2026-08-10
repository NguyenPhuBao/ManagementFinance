import React, { useState, useEffect } from 'react';
import adminApi from '../../api/admin.api';
import { USER_STATUS_LABELS } from '../../utils/constants';

const UserDetailModal = ({ userId, onClose }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!userId) return;
    setLoading(true);
    setError('');
    const fetchUser = async () => {
      try {
        const res = await adminApi.getUserById(userId);
        setUser(res.data);
      } catch (err) {
        setError(err.response?.data?.message || 'Không tìm thấy người dùng');
      } finally {
        setLoading(false);
      }
    };
    fetchUser();
  }, [userId]);

  return (
    <div className="fixed inset-0 bg-on-background/50 flex items-center justify-center z-50 p-4 backdrop-blur-sm" onClick={onClose}>
      <div className="bg-white rounded-xl w-full max-w-lg shadow-xl overflow-hidden animate-in fade-in zoom-in-95 duration-200" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="px-6 py-4 border-b border-outline-variant flex justify-between items-center bg-surface-container-lowest">
          <h3 className="font-title-lg font-bold m-0 text-on-surface flex items-center gap-2">
            <span className="material-symbols-outlined text-primary">person</span>
            Chi tiết người dùng
          </h3>
          <button onClick={onClose} className="text-on-surface-variant hover:text-on-surface hover:bg-surface-container-low p-1 rounded-full transition-colors cursor-pointer">
            <span className="material-symbols-outlined">close</span>
          </button>
        </div>

        {/* Body */}
        <div className="p-6 max-h-[70vh] overflow-y-auto">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <span className="material-symbols-outlined animate-spin text-primary text-3xl">progress_activity</span>
            </div>
          ) : error ? (
            <div className="text-center py-8">
              <span className="material-symbols-outlined text-5xl text-outline mb-3">person_off</span>
              <p className="text-on-surface-variant">{error}</p>
            </div>
          ) : user && (
            <div className="space-y-0">
              {/* Status badge */}
              <div className="flex justify-between items-center pb-4 border-b border-outline-variant/50">
                <span className="font-label-sm text-on-surface-variant uppercase">Trạng thái</span>
                <span className={`inline-flex px-3 py-1 rounded-full text-xs font-semibold ${user.status === 'Active' ? 'bg-[#dcfce7] text-[#166534]' : 'bg-surface-container-high text-secondary'}`}>
                  {USER_STATUS_LABELS[user.status?.toLowerCase()] || user.status}
                </span>
              </div>

              {/* Personal Info */}
              <div className="pt-4 pb-2">
                <p className="text-xs font-bold uppercase tracking-wider text-outline mb-3">Thông tin cá nhân</p>
                <div className="space-y-0">
                  <RowItem label="ID User" value={user.id} />
                  <RowItem label="Họ tên" value={user.fullname} />
                  <RowItem label="Email" value={user.email} />
                  <RowItem label="Số điện thoại" value={user.phone || '—'} />
                  <RowItem label="Địa chỉ" value={user.address || '—'} />
                  <RowItem label="Khu vực" value={user.location || '—'} />
                </div>
              </div>

              {/* Account Info */}
              <div className="pt-4 pb-2">
                <p className="text-xs font-bold uppercase tracking-wider text-outline mb-3">Thông tin tài khoản</p>
                <div className="space-y-0">
                  <RowItem label="Username" value={user.username} />
                  <RowItem label="Vai trò" value={user.rolename} />
                  <RowItem label="Ngày tạo" value={user.created_at ? new Date(user.created_at).toLocaleString('vi-VN') : '—'} isLast />
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

const RowItem = ({ label, value, isLast }) => (
  <div className={`flex justify-between items-center py-3 ${isLast ? '' : 'border-b border-outline-variant/30'}`}>
    <span className="text-sm text-on-surface-variant">{label}</span>
    <span className="text-sm font-semibold text-on-surface text-right max-w-[60%]">{value}</span>
  </div>
);

export default UserDetailModal;
