import React, { useState, useEffect } from 'react';
import { USER_STATUS_LABELS } from '../../utils/constants';
import adminApi from '../../api/admin.api';
import useSocket from '../../hooks/useSocket';
import UserDetailModal from '../../components/common/UserDetailModal';
import Pagination from '../../components/common/Pagination';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';

const ALL_STATUS_KEYS = ['active', 'inactive', 'pendingdelete', 'deleted'];

const UserListPage = () => {
  const alert = useAlertSafe();
  const socket = useSocket();
  const { t } = useLanguageSafe();
  const [loading, setLoading] = useState(true);
  const [users, setUsers] = useState([]);
  const [search, setSearch] = useState('');
  
  const [modals, setModals] = useState({
    filter: false,
    inactivateModal: false,
    activateModal: false,
    deleteAlert: false,
  });
  const [userToBlock, setUserToBlock] = useState(null);
  const [inactivateReason, setInactivateReason] = useState('');
  const [inactivateError, setInactivateError] = useState('');
  const [userToDelete, setUserToDelete] = useState(null);
  const [updatingStatus, setUpdatingStatus] = useState(false);
  const [deletingUser, setDeletingUser] = useState(false);
  const [detailUserId, setDetailUserId] = useState(null);

  const [filter, setFilter] = useState({
    location: 'all',
    statuses: [...ALL_STATUS_KEYS],
  });
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  const getStatusBadge = (status) => {
    switch (status?.toLowerCase()) {
      case 'active':
        return 'bg-emerald-50 text-emerald-700 border border-emerald-200/80 shadow-xs';
      case 'inactive':
        return 'bg-slate-100 text-slate-700 border border-slate-200 shadow-xs';
      case 'pendingdelete':
        return 'bg-amber-50 text-amber-800 border border-amber-200/80 shadow-xs';
      case 'deleted':
        return 'bg-rose-50 text-rose-700 border border-rose-200/80 shadow-xs';
      default:
        return 'bg-surface-container-high text-secondary border border-outline-variant';
    }
  };

  const filteredUsers = users.filter((u) => {
    const matchSearch =
      (u.name || '').toLowerCase().includes(search.toLowerCase()) ||
      (u.email || '').toLowerCase().includes(search.toLowerCase()) ||
      (u.phone || '').includes(search) ||
      (u.username || '').toLowerCase().includes(search.toLowerCase());
    const userStatus = (u.status || '').toLowerCase();
    const currentStatuses = filter.statuses || [];
    const matchStatus = currentStatuses.includes(userStatus);
    const matchLocation =
      filter.location === 'all' ||
      (filter.location === 'hcm' && (u.address || '').toLowerCase().includes('hồ chí minh')) ||
      (filter.location === 'hn' && (u.address || '').toLowerCase().includes('hà nội')) ||
      (filter.location === 'dn' && (u.address || '').toLowerCase().includes('đà nẵng')) ||
      (filter.location === 'ct' && (u.address || '').toLowerCase().includes('cần thơ'));
    return matchSearch && matchStatus && matchLocation;
  });

  const totalPages = Math.ceil(filteredUsers.length / pageSize) || 1;
  const start = (currentPage - 1) * pageSize;
  const end = Math.min(start + pageSize, filteredUsers.length);
  const pageData = filteredUsers.slice(start, end);

  // Thống kê đếm nhanh cho Bento cards
  const stats = {
    total: users.length,
    active: users.filter((u) => u.status === 'active').length,
    inactive: users.filter((u) => u.status === 'inactive').length,
    pendingDelete: users.filter((u) => u.status === 'pendingdelete').length,
  };

  useEffect(() => {
    setCurrentPage(1);
  }, [search, filter]);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const res = await adminApi.getUsers();
      const mapped = res.data.map((u) => ({
        id: u.id,
        idaccount: u.idaccount,
        name: u.fullname || u.username,
        email: u.email,
        phone: u.phone || '—',
        status: u.status ? u.status.toLowerCase() : 'active',
        address: u.address || '',
        username: u.username,
        reason_inactive: u.reason_inactive || null,
        countdown: u.countdown ?? null,
        delete_at: u.delete_at || null,
        created_at: u.created_at,
      }));
      setUsers(mapped);
    } catch (err) {
      console.error('Lỗi tải danh sách người dùng:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  // Lắng nghe sự kiện Realtime Socket.io cho User Management
  useEffect(() => {
    if (!socket) return;

    const handleUserRegistered = (newUser) => {
      if (!newUser) return;
      setUsers((prevList) => {
        if (prevList.some((u) => u.username === newUser.username || (newUser.id && u.id === newUser.id))) {
          return prevList;
        }
        const mapped = {
          id: newUser.id || Date.now(),
          idaccount: newUser.idaccount,
          name: newUser.fullname || newUser.username,
          email: newUser.email || '—',
          phone: newUser.phone || '—',
          status: (newUser.status || 'active').toLowerCase(),
          address: '',
          username: newUser.username,
          reason_inactive: null,
          countdown: null,
          delete_at: null,
          created_at: newUser.created_at || new Date().toISOString(),
          isRealtimeAdded: true,
        };
        return [mapped, ...prevList];
      });
      if (alert) alert.info(t('users.alerts.newUserRegistered', { username: newUser.username }), t('users.alerts.newAccountTitle'));
    };

    const handleUserStatusChanged = (statusData) => {
      if (!statusData) return;
      setUsers((prevList) =>
        prevList.map((u) => {
          const isTarget =
            (statusData.iduser && u.id === statusData.iduser) ||
            (statusData.idaccount && u.idaccount === statusData.idaccount) ||
            (statusData.username && u.username === statusData.username);
          if (isTarget) {
            return {
              ...u,
              status: (statusData.status || u.status).toLowerCase(),
              reason_inactive: statusData.reason_inactive !== undefined ? statusData.reason_inactive : u.reason_inactive,
              countdown: statusData.countdown !== undefined ? statusData.countdown : u.countdown,
            };
          }
          return u;
        })
      );
    };

    socket.on('admin.user_registered', handleUserRegistered);
    socket.on('admin.user_status_changed', handleUserStatusChanged);

    return () => {
      socket.off('admin.user_registered', handleUserRegistered);
      socket.off('admin.user_status_changed', handleUserStatusChanged);
    };
  }, [socket]);

  const toggleModal = (modalName, isOpen) => {
    setModals((prev) => ({ ...prev, [modalName]: isOpen }));
  };

  const handleInactivateClick = (user) => {
    setUserToBlock(user);
    setInactivateReason('');
    setInactivateError('');
    toggleModal('inactivateModal', true);
  };

  const confirmInactivate = async (e) => {
    if (e) e.preventDefault();
    if (!inactivateReason.trim()) {
      setInactivateError(t('users.alerts.reasonRequired'));
      return;
    }
    if (!userToBlock || updatingStatus) return;
    setUpdatingStatus(true);
    try {
      await adminApi.updateUserStatus(userToBlock.id, {
        status: 'Inactive',
        reason_inactive: inactivateReason.trim(),
      });
      const userName = userToBlock.name || userToBlock.email || t('dashboard.recentActivities.defaultUser');
      setUsers((prev) =>
        prev.map((u) =>
          u.id === userToBlock.id
            ? { ...u, status: 'inactive', reason_inactive: inactivateReason.trim() }
            : u
        )
      );
      setUserToBlock(null);
      setInactivateReason('');
      toggleModal('inactivateModal', false);
      if (alert) alert.success(t('users.alerts.inactivatedSuccess', { name: userName }));
    } catch (err) {
      console.error('Lỗi vô hiệu hóa tài khoản:', err);
      const errMsg = err.response?.data?.message || err.message || 'Lỗi khi vô hiệu hóa tài khoản';
      setInactivateError(errMsg);
      if (alert) alert.error(errMsg, t('users.alerts.inactivatedFailed'));
    } finally {
      setUpdatingStatus(false);
    }
  };

  const handleActivateClick = (user) => {
    setUserToBlock(user);
    toggleModal('activateModal', true);
  };

  const confirmActivate = async () => {
    if (!userToBlock || updatingStatus) return;
    setUpdatingStatus(true);
    try {
      await adminApi.updateUserStatus(userToBlock.id, { status: 'Active' });
      const userName = userToBlock.name || userToBlock.email || t('dashboard.recentActivities.defaultUser');
      setUsers((prev) =>
        prev.map((u) =>
          u.id === userToBlock.id ? { ...u, status: 'active', reason_inactive: null } : u
        )
      );
      setUserToBlock(null);
      toggleModal('activateModal', false);
      if (alert) alert.success(t('users.alerts.activatedSuccess', { name: userName }));
    } catch (err) {
      console.error('Lỗi kích hoạt tài khoản:', err);
      const errMsg = err.response?.data?.message || err.message || 'Lỗi khi kích hoạt tài khoản';
      if (alert) alert.error(errMsg, t('users.alerts.activatedFailed'));
    } finally {
      setUpdatingStatus(false);
    }
  };

  const handleDeleteClick = (user) => {
    setUserToDelete(user);
    toggleModal('deleteAlert', true);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const confirmDelete = async () => {
    if (!userToDelete || deletingUser) return;
    setDeletingUser(true);
    try {
      await adminApi.deleteUser(userToDelete.id);
      const userName = userToDelete.name || userToDelete.email || t('dashboard.recentActivities.defaultUser');
      setUsers((prev) => prev.filter((u) => u.id !== userToDelete.id));
      setUserToDelete(null);
      toggleModal('deleteAlert', false);
      if (alert) alert.success(t('users.alerts.deletedSuccess', { name: userName }));
    } catch (err) {
      console.error('Lỗi xóa người dùng:', err);
      const errMsg = err.response?.data?.message || err.message || 'Lỗi khi xóa người dùng';
      if (alert) alert.error(errMsg, t('users.alerts.deletedFailed'));
    } finally {
      setDeletingUser(false);
    }
  };

  return (
    <>
      {/* Loading Overlay */}
      {(updatingStatus || deletingUser) && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-xs z-[9999] flex flex-col items-center justify-center pointer-events-auto select-none animate-in fade-in duration-200">
          <div className="bg-white/95 backdrop-blur-md px-8 py-6 rounded-2xl shadow-2xl border border-outline-variant flex flex-col items-center gap-4 text-center max-w-xs mx-4">
            <span
              className={`material-symbols-outlined animate-spin ${
                deletingUser ? 'text-error' : 'text-primary'
              } text-5xl`}
            >
              progress_activity
            </span>
            <div className="space-y-1">
              <h4 className="font-title-md font-bold text-on-surface text-base">
                {deletingUser
                  ? t('users.loadingOverlay.deleting')
                  : userToBlock?.status === 'active'
                  ? t('users.loadingOverlay.inactivating')
                  : t('users.loadingOverlay.activating')}
              </h4>
              <p className="font-body-sm text-on-surface-variant text-xs">
                {deletingUser
                  ? t('users.loadingOverlay.processingWallet')
                  : t('users.loadingOverlay.wait')}
              </p>
            </div>
          </div>
        </div>
      )}

      <div className="bg-surface-bright relative p-4 md:p-6 min-h-full space-y-6">
        {/* Banner Xóa mềm Cảnh báo */}
        {modals.deleteAlert && (
          <div className="bg-rose-50 border border-rose-200/90 rounded-2xl p-5 flex flex-col md:flex-row items-start md:items-center justify-between gap-4 animate-in fade-in zoom-in-95 duration-200 shadow-sm">
            <div className="flex items-start gap-3.5 text-on-surface">
              <div className="w-10 h-10 rounded-xl bg-rose-100 text-rose-700 flex items-center justify-center shrink-0 border border-rose-200">
                <span className="material-symbols-outlined text-2xl">delete_forever</span>
              </div>
              <div className="space-y-1">
                <p className="font-body-lg font-bold text-rose-800 text-sm md:text-base">
                  {t('users.deleteModal.title')} {userToDelete?.name} (@{userToDelete?.username})?
                </p>
                <p className="font-body-sm text-rose-700 text-xs leading-relaxed">
                  {t('users.deleteModal.warning')}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2.5 self-end md:self-center shrink-0">
              <button
                disabled={deletingUser}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-700 text-white rounded-xl text-xs font-semibold transition-colors cursor-pointer shadow-sm disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-1.5"
                onClick={confirmDelete}
              >
                {deletingUser && <span className="material-symbols-outlined animate-spin text-sm">progress_activity</span>}
                {t('users.deleteModal.confirmBtn')}
              </button>
              <button
                disabled={deletingUser}
                className="px-4 py-2 bg-white border border-outline-variant hover:bg-surface-container-low text-on-surface rounded-xl text-xs font-semibold transition-colors cursor-pointer"
                onClick={() => {
                  setUserToDelete(null);
                  toggleModal('deleteAlert', false);
                }}
              >
                {t('users.deleteModal.cancelBtn')}
              </button>
            </div>
          </div>
        )}

        {/* 1. Header Hero Bar chuẩn Enterprise */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-2">
          <div className="flex items-center gap-3.5">
            <div className="w-12 h-12 rounded-2xl bg-primary/10 border border-primary/20 flex items-center justify-center text-primary shadow-xs">
              <span className="material-symbols-outlined text-[28px]">manage_accounts</span>
            </div>
            <div>
              <div className="flex items-center gap-2.5">
                <h2 className="font-headline-md text-xl md:text-2xl font-bold text-on-surface m-0 tracking-tight">
                  {t('users.title')}
                </h2>
                <span className="px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-emerald-100 text-emerald-800 border border-emerald-200 flex items-center gap-1">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-600 animate-pulse"></span>
                  {t('users.realtimeSync')}
                </span>
              </div>
              <p className="text-xs text-on-surface-variant mt-0.5">
                {t('users.subtitle')}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2.5">
            <button
              onClick={fetchUsers}
              className="px-3.5 py-2 bg-white border border-outline-variant rounded-xl text-xs font-semibold text-on-surface hover:bg-surface-container-low transition-all shadow-xs flex items-center gap-1.5 cursor-pointer"
              title={t('users.refreshTitle')}
            >
              <span className="material-symbols-outlined text-[18px]">refresh</span>
              {t('users.refresh')}
            </button>
          </div>
        </div>

        {/* 2. Bento Stats KPI Cards */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div
            onClick={() => setFilter((prev) => ({ ...prev, statuses: [...ALL_STATUS_KEYS] }))}
            className={`p-4 rounded-2xl border transition-all cursor-pointer ${
              (filter.statuses || []).length === ALL_STATUS_KEYS.length
                ? 'bg-primary/5 border-primary/40 ring-1 ring-primary/30 shadow-xs'
                : 'bg-white border-outline-variant hover:border-primary/30 hover:bg-surface-container-lowest'
            }`}
          >
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-semibold text-on-surface-variant">{t('users.stats.totalUsers')}</span>
              <div className="w-8 h-8 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
                <span className="material-symbols-outlined text-[18px]">group</span>
              </div>
            </div>
            <div className="text-2xl font-black text-on-surface tracking-tight font-tabular-nums">
              {stats.total}
            </div>
            <div className="text-[11px] text-on-surface-variant mt-1 flex items-center gap-1">
              <span>{t('users.stats.allAccounts')}</span>
            </div>
          </div>

          <div
            onClick={() => setFilter((prev) => ({ ...prev, statuses: ['active'] }))}
            className={`p-4 rounded-2xl border transition-all cursor-pointer ${
              (filter.statuses || []).length === 1 && filter.statuses.includes('active')
                ? 'bg-emerald-50/70 border-emerald-300 ring-1 ring-emerald-300 shadow-xs'
                : 'bg-white border-outline-variant hover:border-emerald-300 hover:bg-surface-container-lowest'
            }`}
          >
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-semibold text-emerald-800">{t('users.stats.activeUsers')}</span>
              <div className="w-8 h-8 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
                <span className="material-symbols-outlined text-[18px]">verified_user</span>
              </div>
            </div>
            <div className="text-2xl font-black text-emerald-900 tracking-tight font-tabular-nums">
              {stats.active}
            </div>
            <div className="text-[11px] text-emerald-700 mt-1">{t('users.stats.canLogin')}</div>
          </div>

          <div
            onClick={() => setFilter((prev) => ({ ...prev, statuses: ['inactive'] }))}
            className={`p-4 rounded-2xl border transition-all cursor-pointer ${
              (filter.statuses || []).length === 1 && filter.statuses.includes('inactive')
                ? 'bg-slate-100 border-slate-300 ring-1 ring-slate-300 shadow-xs'
                : 'bg-white border-outline-variant hover:border-slate-300 hover:bg-surface-container-lowest'
            }`}
          >
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-semibold text-slate-700">{t('users.stats.inactiveUsers')}</span>
              <div className="w-8 h-8 rounded-xl bg-slate-100 text-slate-600 flex items-center justify-center">
                <span className="material-symbols-outlined text-[18px]">block</span>
              </div>
            </div>
            <div className="text-2xl font-black text-slate-900 tracking-tight font-tabular-nums">
              {stats.inactive}
            </div>
            <div className="text-[11px] text-slate-600 mt-1">{t('users.stats.temporarilyLocked')}</div>
          </div>

          <div
            onClick={() => setFilter((prev) => ({ ...prev, statuses: ['pendingdelete'] }))}
            className={`p-4 rounded-2xl border transition-all cursor-pointer ${
              (filter.statuses || []).length === 1 && filter.statuses.includes('pendingdelete')
                ? 'bg-amber-50/70 border-amber-300 ring-1 ring-amber-300 shadow-xs'
                : 'bg-white border-outline-variant hover:border-amber-300 hover:bg-surface-container-lowest'
            }`}
          >
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-semibold text-amber-800">{t('users.stats.pendingDelete')}</span>
              <div className="w-8 h-8 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center">
                <span className="material-symbols-outlined text-[18px]">auto_delete</span>
              </div>
            </div>
            <div className="text-2xl font-black text-amber-900 tracking-tight font-tabular-nums">
              {stats.pendingDelete}
            </div>
            <div className="text-[11px] text-amber-700 mt-1">{t('users.stats.gracePeriod')}</div>
          </div>
        </div>

        {/* 3. Filter Pill Tabs & Search Controls */}
        <div className="bg-white p-3.5 rounded-2xl border border-outline-variant shadow-xs flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3">
          {/* Quick Pill Tabs */}
          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 md:pb-0 scrollbar-none">
            {[
              { id: 'all', label: t('users.tabs.all'), icon: 'list_alt', count: stats.total },
              { id: 'active', label: t('users.tabs.active'), icon: 'check_circle', count: stats.active },
              { id: 'inactive', label: t('users.tabs.inactive'), icon: 'block', count: stats.inactive },
              { id: 'pendingdelete', label: t('users.tabs.pendingDelete'), icon: 'schedule', count: stats.pendingDelete },
            ].map((tab) => {
              const currentStatuses = filter.statuses || [];
              const isActive =
                tab.id === 'all'
                  ? currentStatuses.length === ALL_STATUS_KEYS.length
                  : currentStatuses.length === 1 && currentStatuses.includes(tab.id);
              return (
                <button
                  key={tab.id}
                  onClick={() => {
                    if (tab.id === 'all') {
                      setFilter((prev) => ({ ...prev, statuses: [...ALL_STATUS_KEYS] }));
                    } else {
                      setFilter((prev) => ({ ...prev, statuses: [tab.id] }));
                    }
                  }}
                  className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all flex items-center gap-1.5 whitespace-nowrap cursor-pointer ${
                    isActive
                      ? 'bg-primary text-white shadow-xs'
                      : 'bg-surface-container-lowest text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface'
                  }`}
                >
                  <span className="material-symbols-outlined text-[16px]">{tab.icon}</span>
                  <span>{tab.label}</span>
                  <span
                    className={`px-1.5 py-0.2 rounded-full text-[10px] font-bold ${
                      isActive ? 'bg-white/20 text-white' : 'bg-surface-container text-secondary'
                    }`}
                  >
                    {tab.count}
                  </span>
                </button>
              );
            })}
          </div>

          {/* Search bar & Filter Trigger */}
          <div className="flex items-center gap-2.5">
            <div className="relative flex-1 md:w-72">
              <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-outline text-[18px]">
                search
              </span>
              <input
                className="w-full pl-9 pr-3.5 py-1.5 border border-outline-variant rounded-xl bg-surface-container-lowest focus:bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary text-xs font-medium text-on-surface transition-all placeholder:text-secondary"
                placeholder={t('users.searchPlaceholder')}
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
              {search && (
                <button
                  onClick={() => setSearch('')}
                  className="absolute right-2.5 top-1/2 -translate-y-1/2 text-secondary hover:text-on-surface text-xs"
                >
                  ✕
                </button>
              )}
            </div>

            <button
              className={`px-3 py-1.5 border rounded-xl font-label-md text-xs font-semibold transition-all flex items-center gap-1.5 cursor-pointer shadow-xs ${
                filter.location !== 'all' || (filter.statuses || []).length !== ALL_STATUS_KEYS.length
                  ? 'border-primary bg-primary/10 text-primary'
                  : 'border-outline-variant bg-white text-on-surface hover:bg-surface-container-low'
              }`}
              onClick={() => toggleModal('filter', true)}
            >
              <span className="material-symbols-outlined text-[16px]">filter_alt</span>
              {t('users.filterBtn')}
            </button>
          </div>
        </div>

        {/* 4. Main User Table */}
        <div className="bg-white border border-outline-variant rounded-2xl overflow-hidden shadow-xs relative">
          {loading && (
            <div className="absolute inset-0 bg-white/70 backdrop-blur-2xs z-10 flex flex-col items-center justify-center gap-2">
              <span className="material-symbols-outlined animate-spin text-primary text-3xl">
                progress_activity
              </span>
              <span className="text-xs font-medium text-secondary">{t('users.table.syncing')}</span>
            </div>
          )}

          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse min-w-[850px]">
              <thead>
                <tr className="bg-surface-container-low/80 border-b border-outline-variant text-[11px] font-bold text-on-surface-variant uppercase tracking-wider">
                  <th className="px-5 py-3.5 w-12 text-center">
                    <input
                      type="checkbox"
                      className="w-4 h-4 rounded border-outline-variant text-primary focus:ring-primary cursor-pointer"
                    />
                  </th>
                  <th className="px-5 py-3.5">{t('users.table.colName')}</th>
                  <th className="px-5 py-3.5">{t('users.table.colEmail')}</th>
                  <th className="px-5 py-3.5">{t('users.table.colPhone')}</th>
                  <th className="px-5 py-3.5 text-center">{t('users.table.colStatus')}</th>
                  <th className="px-5 py-3.5 text-right">{t('users.table.colActions')}</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-outline-variant/60 font-body-md text-xs text-on-surface">
                {pageData.length > 0 ? (
                  pageData.map((item) => {
                    const statusText =
                      item.status === 'pendingdelete' && item.countdown !== null && item.countdown !== undefined
                        ? t('users.table.pendingDeleteCountdown', { days: item.countdown })
                        : (t(`commonStatus.${item.status}`) || USER_STATUS_LABELS[item.status] || item.status);

                    return (
                      <tr
                        key={item.id}
                        className="hover:bg-surface-container-lowest/80 transition-colors group"
                      >
                        <td className="px-5 py-3.5 text-center">
                          <input
                            type="checkbox"
                            className="w-4 h-4 rounded border-outline-variant text-primary focus:ring-primary cursor-pointer"
                          />
                        </td>
                        <td className="px-5 py-3.5">
                          <div className="flex items-center gap-3">
                            <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-primary/10 to-primary/20 text-primary flex items-center justify-center font-bold text-sm border border-primary/20 shadow-2xs shrink-0">
                              {(item.name || item.username || 'U').charAt(0).toUpperCase()}
                            </div>
                            <div className="min-w-0">
                              <span className="font-bold text-on-surface block truncate text-xs hover:text-primary transition-colors">
                                {item.name}
                              </span>
                              <span className="text-[11px] text-secondary font-mono">
                                @{item.username}
                              </span>
                            </div>
                          </div>
                        </td>
                        <td className="px-5 py-3.5 text-on-surface-variant font-medium">
                          {item.email}
                        </td>
                        <td className="px-5 py-3.5 text-on-surface-variant font-mono">
                          {item.phone}
                        </td>
                        <td className="px-5 py-3.5 text-center">
                          <span
                            className={`inline-flex items-center px-2.5 py-1 rounded-full text-[11px] font-semibold ${getStatusBadge(
                              item.status
                            )}`}
                          >
                            {statusText}
                          </span>
                        </td>
                        <td className="px-5 py-3.5 text-right">
                          <div className="flex items-center justify-end gap-1.5">
                            {item.status === 'active' && (
                              <button
                                className="px-3 py-1.5 rounded-xl text-xs font-semibold transition-all shadow-2xs cursor-pointer border border-rose-200 bg-rose-50 text-rose-700 hover:bg-rose-100 hover:border-rose-300"
                                onClick={() => handleInactivateClick(item)}
                              >
                                {t('users.table.inactivateBtn')}
                              </button>
                            )}
                            {item.status === 'inactive' && (
                              <>
                                <button
                                  className="px-3 py-1.5 rounded-xl text-xs font-semibold transition-all shadow-2xs cursor-pointer border border-primary/30 bg-primary text-white hover:bg-primary-tint"
                                  onClick={() => handleActivateClick(item)}
                                >
                                  {t('users.table.activateBtn')}
                                </button>
                                <button
                                  className="px-2.5 py-1.5 rounded-xl text-xs font-semibold transition-all shadow-2xs cursor-pointer border border-rose-200 bg-white text-rose-700 hover:bg-rose-50 flex items-center gap-1"
                                  onClick={() => handleDeleteClick(item)}
                                  title={t('users.table.deleteUserTitle')}
                                >
                                  <span className="material-symbols-outlined text-[15px]">delete</span>
                                  {t('users.table.deleteBtn')}
                                </button>
                              </>
                            )}
                            {item.status === 'pendingdelete' && (
                              <span className="text-xs text-amber-800 font-medium px-2 italic">
                                {t('users.table.viewOnly')}
                              </span>
                            )}
                            {item.status === 'deleted' && (
                              <span className="text-xs text-rose-700 font-medium px-2 italic">
                                {t('users.table.deleted')}
                              </span>
                            )}
                            <button
                              className="w-7 h-7 rounded-lg text-secondary hover:text-primary hover:bg-primary/10 transition-colors flex items-center justify-center cursor-pointer ml-1"
                              onClick={() => setDetailUserId(item.id)}
                              title={t('users.table.viewDetailTitle')}
                            >
                              <span className="material-symbols-outlined text-[18px]">visibility</span>
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })
                ) : (
                  <tr>
                    <td colSpan="6" className="px-6 py-12 text-center text-on-surface-variant">
                      <div className="flex flex-col items-center justify-center gap-2">
                        <span className="material-symbols-outlined text-4xl text-secondary/60">
                          person_search
                        </span>
                        <p className="font-semibold text-sm text-on-surface">
                          {t('users.table.emptyTitle')}
                        </p>
                        <p className="text-xs text-secondary">
                          {t('users.table.emptySubtitle')}
                        </p>
                      </div>
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          <Pagination
            currentPage={currentPage}
            pageSize={pageSize}
            total={filteredUsers.length}
            pageSizeOptions={[5, 10, 20, 50]}
            onPageChange={(page) => setCurrentPage(page)}
            onPageSizeChange={(newSize) => {
              setPageSize(newSize);
              setCurrentPage(1);
            }}
            itemLabel={t('users.table.itemLabel')}
          />
        </div>
      </div>

      {/* Filter Modal */}
      {modals.filter && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-2xs flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-sm shadow-xl overflow-hidden border border-outline-variant animate-in fade-in zoom-in-95 duration-200">
            <div className="px-6 py-4 border-b border-outline-variant flex items-center justify-between bg-surface-container-lowest">
              <h3 className="font-bold text-base text-on-surface m-0">{t('users.filterModal.title')}</h3>
              <button
                className="text-secondary hover:text-on-surface cursor-pointer p-1 rounded-full hover:bg-surface-container-low transition-colors"
                onClick={() => toggleModal('filter', false)}
              >
                <span className="material-symbols-outlined text-[20px]">close</span>
              </button>
            </div>
            <div className="p-6 space-y-5">
              <div>
                <label className="block text-[11px] font-bold uppercase tracking-wider text-on-surface mb-2">
                  {t('users.filterModal.locationLabel')}
                </label>
                <select
                  value={filter.location}
                  onChange={(e) => setFilter({ ...filter, location: e.target.value })}
                  className="w-full px-3 py-2 border border-outline-variant rounded-xl focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/20 text-xs font-medium bg-white h-[42px] cursor-pointer"
                >
                  <option value="all">{t('users.filterModal.allLocations')}</option>
                  <option value="hcm">{t('users.locations.hcm')}</option>
                  <option value="hn">{t('users.locations.hn')}</option>
                  <option value="dn">{t('users.locations.dn')}</option>
                  <option value="ct">{t('users.locations.ct')}</option>
                </select>
              </div>
              <div>
                <label className="block text-[11px] font-bold uppercase tracking-wider text-on-surface mb-3">
                  {t('users.filterModal.statusLabel')}
                </label>
                <div className="space-y-2.5">
                  {/* Checkbox Tất cả */}
                  <label className="flex items-center gap-3 cursor-pointer group">
                    <input
                      type="checkbox"
                      data-testid="filter-status-all"
                      name="status_all"
                      checked={ALL_STATUS_KEYS.every((s) => (filter.statuses || []).includes(s))}
                      onChange={(e) => {
                        const checked = e.target.checked;
                        setFilter((prev) => ({
                          ...prev,
                          statuses: checked ? [...ALL_STATUS_KEYS] : [],
                        }));
                      }}
                      className="w-4 h-4 rounded border-outline-variant text-primary focus:ring-primary cursor-pointer accent-primary"
                    />
                    <span className="text-on-surface text-xs font-medium group-hover:text-primary transition-colors">
                      {t('users.filterModal.allStatus')}
                    </span>
                  </label>

                  {/* 4 Checkbox trạng thái con */}
                  {[
                    { id: 'active', label: t('commonStatus.active') },
                    { id: 'inactive', label: t('commonStatus.inactive') },
                    { id: 'pendingdelete', label: t('commonStatus.pendingdelete') },
                    { id: 'deleted', label: t('commonStatus.deleted') },
                  ].map((item) => (
                    <label key={item.id} className="flex items-center gap-3 cursor-pointer group">
                      <input
                        type="checkbox"
                        data-testid={`filter-status-${item.id}`}
                        name={`status_${item.id}`}
                        checked={(filter.statuses || []).includes(item.id)}
                        onChange={() => {
                          setFilter((prev) => {
                            const current = prev.statuses || [];
                            const next = current.includes(item.id)
                              ? current.filter((s) => s !== item.id)
                              : [...current, item.id];
                            return { ...prev, statuses: next };
                          });
                        }}
                        className="w-4 h-4 rounded border-outline-variant text-primary focus:ring-primary cursor-pointer accent-primary"
                      />
                      <span className="text-on-surface text-xs font-medium group-hover:text-primary transition-colors">
                        {item.label}
                      </span>
                    </label>
                  ))}
                </div>
              </div>
            </div>
            <div className="px-6 py-4 bg-surface-container-lowest border-t border-outline-variant flex justify-end gap-2.5">
              <button
                className="px-4 py-2 border border-outline-variant rounded-xl text-on-surface text-xs font-semibold hover:bg-surface-container-low transition-colors cursor-pointer"
                onClick={() => {
                  setFilter({ location: 'all', statuses: [...ALL_STATUS_KEYS] });
                  toggleModal('filter', false);
                }}
              >
                {t('users.filterModal.resetBtn')}
              </button>
              <button
                className="px-4 py-2 bg-primary text-white rounded-xl text-xs font-semibold hover:bg-primary-tint transition-colors cursor-pointer shadow-xs"
                onClick={() => toggleModal('filter', false)}
              >
                {t('users.filterModal.applyBtn')}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Inactivate User Modal */}
      {modals.inactivateModal && userToBlock && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-2xs flex items-center justify-center z-50 p-4 animate-in fade-in duration-200">
          <div className="bg-white rounded-2xl w-full max-w-md shadow-2xl overflow-hidden border border-outline-variant animate-in zoom-in-95 duration-200">
            {/* Header */}
            <div className="px-6 py-4 border-b border-outline-variant flex items-center justify-between bg-surface-container-lowest">
              <div className="flex items-center gap-2.5 text-rose-600">
                <span className="material-symbols-outlined text-2xl">block</span>
                <h3 className="font-bold text-on-surface text-base m-0">{t('users.inactivateModal.title')}</h3>
              </div>
              <button
                className="text-secondary hover:text-on-surface cursor-pointer p-1 rounded-full hover:bg-surface-container-low transition-colors"
                onClick={() => {
                  toggleModal('inactivateModal', false);
                  setUserToBlock(null);
                }}
              >
                <span className="material-symbols-outlined text-[20px]">close</span>
              </button>
            </div>

            {/* Body */}
            <form onSubmit={confirmInactivate}>
              <div className="p-6 space-y-4">
                <div className="bg-surface-container-low p-3.5 rounded-xl border border-outline-variant/60 space-y-1">
                  <p className="text-xs text-on-surface-variant font-medium">{t('users.inactivateModal.accountLabel')}</p>
                  <p className="font-bold text-on-surface text-sm">
                    {userToBlock.name}{' '}
                    <span className="font-normal text-secondary">(@{userToBlock.username})</span>
                  </p>
                  <p className="text-xs text-secondary">{userToBlock.email}</p>
                </div>

                <div className="space-y-1.5">
                  <label className="block text-xs font-bold uppercase tracking-wider text-on-surface">
                    {t('users.inactivateModal.reasonLabel')} <span className="text-rose-600">*</span>
                  </label>
                  <textarea
                    rows={3}
                    value={inactivateReason}
                    onChange={(e) => {
                      setInactivateReason(e.target.value);
                      if (inactivateError) setInactivateError('');
                    }}
                    placeholder={t('users.inactivateModal.reasonPlaceholder')}
                    className={`w-full px-3.5 py-2.5 border rounded-xl text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all resize-none ${
                      inactivateError
                        ? 'border-rose-500 ring-1 ring-rose-500'
                        : 'border-outline-variant focus:border-primary'
                    }`}
                    autoFocus
                  />
                  {inactivateError && (
                    <p className="text-xs text-rose-600 font-medium flex items-center gap-1 mt-1">
                      <span className="material-symbols-outlined text-sm">error</span>
                      {inactivateError}
                    </p>
                  )}
                  <p className="text-[11px] text-secondary">
                    {t('users.inactivateModal.warning')}
                  </p>
                </div>
              </div>

              {/* Footer */}
              <div className="px-6 py-4 bg-surface-container-lowest border-t border-outline-variant flex justify-end items-center gap-2.5">
                <button
                  type="button"
                  disabled={updatingStatus}
                  className="px-4 py-2 border border-outline-variant rounded-xl text-on-surface text-xs font-semibold hover:bg-surface-container-low transition-colors cursor-pointer disabled:opacity-50"
                  onClick={() => {
                    toggleModal('inactivateModal', false);
                    setUserToBlock(null);
                  }}
                >
                  {t('users.inactivateModal.cancelBtn')}
                </button>
                <button
                  type="submit"
                  disabled={updatingStatus || !inactivateReason.trim()}
                  className="px-5 py-2 bg-rose-600 text-white rounded-xl text-xs font-semibold hover:bg-rose-700 transition-all cursor-pointer shadow-xs flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {updatingStatus && (
                    <span className="material-symbols-outlined animate-spin text-sm">
                      progress_activity
                    </span>
                  )}
                  {t('users.inactivateModal.submitBtn')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Activate User Modal */}
      {modals.activateModal && userToBlock && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-2xs flex items-center justify-center z-50 p-4 animate-in fade-in duration-200">
          <div className="bg-white rounded-2xl w-full max-w-sm shadow-2xl overflow-hidden border border-outline-variant animate-in zoom-in-95 duration-200">
            <div className="px-6 py-4 border-b border-outline-variant flex items-center justify-between bg-surface-container-lowest">
              <div className="flex items-center gap-2 text-emerald-600">
                <span className="material-symbols-outlined text-2xl">check_circle</span>
                <h3 className="font-bold text-on-surface text-base m-0">{t('users.activateModal.title')}</h3>
              </div>
              <button
                className="text-secondary hover:text-on-surface cursor-pointer p-1 rounded-full hover:bg-surface-container-low transition-colors"
                onClick={() => {
                  toggleModal('activateModal', false);
                  setUserToBlock(null);
                }}
              >
                <span className="material-symbols-outlined text-[20px]">close</span>
              </button>
            </div>
            <div className="p-6 space-y-3">
              <p className="text-xs text-on-surface leading-relaxed">
                {t('users.activateModal.confirmText')} <strong>{userToBlock.name}</strong> (@{userToBlock.username})?
              </p>
              <p className="text-[11px] text-secondary">
                {t('users.activateModal.hint')}
              </p>
            </div>
            <div className="px-6 py-4 bg-surface-container-lowest border-t border-outline-variant flex justify-end items-center gap-2.5">
              <button
                disabled={updatingStatus}
                className="px-4 py-2 border border-outline-variant rounded-xl text-on-surface text-xs font-semibold hover:bg-surface-container-low transition-colors cursor-pointer disabled:opacity-50"
                onClick={() => {
                  toggleModal('activateModal', false);
                  setUserToBlock(null);
                }}
              >
                {t('users.activateModal.cancelBtn')}
              </button>
              <button
                disabled={updatingStatus}
                className="px-5 py-2 bg-primary text-white rounded-xl text-xs font-semibold hover:bg-primary-tint transition-all cursor-pointer shadow-xs flex items-center gap-2 disabled:opacity-50"
                onClick={confirmActivate}
              >
                {updatingStatus && (
                  <span className="material-symbols-outlined animate-spin text-sm">
                    progress_activity
                  </span>
                )}
                {t('users.activateModal.submitBtn')}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* User Detail Modal */}
      {detailUserId && (
        <UserDetailModal userId={detailUserId} onClose={() => setDetailUserId(null)} />
      )}
    </>
  );
};

export default UserListPage;
