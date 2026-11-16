import React, { useState, useEffect, useMemo, useId } from 'react';
import adminApi from '../../api/admin.api';
import useSocket from '../../hooks/useSocket';
import UserDetailModal from '../../components/common/UserDetailModal';
import TruncateCell from '../../components/common/TruncateCell';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import { maskPhone } from '../../utils/format';
import {
  Badge,
  Button,
  Card,
  ConfirmModal,
  DataTable,
  Modal,
  PageHeader,
  Pagination,
  SearchInput,
  SecurityConfirmModal,
  StatCard,
  Tabs,
} from '../../components/ui';

const ALL_STATUSES = ['active', 'inactive', 'pendingdelete', 'deleted'];
const DEFAULT_FILTER = { packageType: 'all', statuses: ['active', 'inactive', 'pendingdelete'] };
const STATUS_TONE = { active: 'success', inactive: 'neutral', pendingdelete: 'warning', deleted: 'danger' };

const toRow = (u) => ({
  id: u.id,
  idaccount: u.idaccount,
  name: u.fullname || u.username,
  email: u.email || '—',
  phone: u.phone || '—',
  status: (u.status || 'active').toLowerCase(),
  type: u.type || u.package || 'Basic',
  username: u.username,
  reason_inactive: u.reason_inactive || null,
  countdown: u.countdown ?? null,
  delete_at: u.delete_at || null,
  created_at: u.created_at || null,
});

const initials = (name) =>
  String(name || 'U')
    .trim()
    .split(/\s+/)
    .slice(-2)
    .map((w) => w[0])
    .join('')
    .toUpperCase();

const UserListPage = () => {
  const notify = useAlertSafe();
  const socket = useSocket();
  const { t } = useLanguageSafe();
  const reasonId = useId();

  const [loading, setLoading] = useState(true);
  const [users, setUsers] = useState([]);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState(DEFAULT_FILTER);
  const [draftFilter, setDraftFilter] = useState(DEFAULT_FILTER);
  const [filterOpen, setFilterOpen] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  const [inactivateTarget, setInactivateTarget] = useState(null);
  const [inactivateReason, setInactivateReason] = useState('');
  const [inactivateError, setInactivateError] = useState('');
  const [activateTarget, setActivateTarget] = useState(null);
  const [deleteTarget, setDeleteTarget] = useState(null);
  const [updatingStatus, setUpdatingStatus] = useState(false);
  const [detailUserId, setDetailUserId] = useState(null);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const res = await adminApi.getUsers();
      setUsers((res.data || []).map(toRow));
    } catch (err) {
      console.error('Lỗi tải danh sách người dùng:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  useEffect(() => {
    setCurrentPage(1);
  }, [search, filter]);

  useEffect(() => {
    if (!socket) return undefined;

    const handleUserRegistered = (newUser) => {
      if (!newUser) return;
      setUsers((prev) => {
        if (prev.some((u) => u.username === newUser.username || (newUser.id && u.id === newUser.id))) return prev;
        return [{ ...toRow(newUser), id: newUser.id || Date.now() }, ...prev];
      });
      if (notify) notify.info(t('users.alerts.newUserRegistered', { username: newUser.username }), t('users.alerts.newAccountTitle'));
    };

    const handleUserStatusChanged = (data) => {
      if (!data) return;
      setUsers((prev) =>
        prev.map((u) => {
          const isTarget =
            (data.iduser && u.id === data.iduser) ||
            (data.idaccount && u.idaccount === data.idaccount) ||
            (data.username && u.username === data.username);
          if (!isTarget) return u;
          return {
            ...u,
            status: (data.status || u.status).toLowerCase(),
            reason_inactive: data.reason_inactive !== undefined ? data.reason_inactive : u.reason_inactive,
            countdown: data.countdown !== undefined ? data.countdown : u.countdown,
          };
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

  const stats = useMemo(() => {
    const count = (s) => users.filter((u) => u.status === s).length;
    return {
      all: users.length,
      active: count('active'),
      inactive: count('inactive'),
      pendingdelete: count('pendingdelete'),
      deleted: count('deleted'),
    };
  }, [users]);

  const filteredUsers = useMemo(() => {
    const q = search.trim().toLowerCase();
    return users.filter((u) => {
      const matchSearch =
        !q ||
        (u.name || '').toLowerCase().includes(q) ||
        (u.email || '').toLowerCase().includes(q) ||
        (u.phone || '').includes(q) ||
        (u.username || '').toLowerCase().includes(q);
      const matchStatus = filter.statuses.includes(u.status);
      const matchPackage = filter.packageType === 'all' || u.type.toLowerCase() === filter.packageType.toLowerCase();
      return matchSearch && matchStatus && matchPackage;
    });
  }, [users, search, filter]);

  const pageData = filteredUsers.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  const tabValue =
    filter.statuses.length === ALL_STATUSES.length ? 'all' : filter.statuses.length === 1 ? filter.statuses[0] : null;
  const filterIsCustom =
    filter.packageType !== 'all' || filter.statuses.length !== DEFAULT_FILTER.statuses.length || filter.statuses.some((s) => !DEFAULT_FILTER.statuses.includes(s));

  const selectTab = (key) => setFilter((prev) => ({ ...prev, statuses: key === 'all' ? [...ALL_STATUSES] : [key] }));

  const statusLabel = (u) =>
    u.status === 'pendingdelete' && u.countdown !== null
      ? t('users.table.pendingDeleteCountdown', { days: u.countdown })
      : t(`commonStatus.${u.status}`);

  const displayName = (u) => u.name || u.email;

  const openInactivate = (user) => {
    setInactivateTarget(user);
    setInactivateReason('');
    setInactivateError('');
  };

  const confirmInactivate = async (e) => {
    e.preventDefault();
    const reason = inactivateReason.trim();
    if (!reason) {
      setInactivateError(t('users.inactivateModal.reasonRequired'));
      return;
    }
    if (!inactivateTarget || updatingStatus) return;
    setUpdatingStatus(true);
    try {
      await adminApi.updateUserStatus(inactivateTarget.id, { status: 'Inactive', reason_inactive: reason });
      setUsers((prev) => prev.map((u) => (u.id === inactivateTarget.id ? { ...u, status: 'inactive', reason_inactive: reason } : u)));
      if (notify) notify.success(t('users.alerts.inactivatedSuccess', { name: displayName(inactivateTarget) }));
      setInactivateTarget(null);
    } catch (err) {
      const message = err.response?.data?.message || err.message;
      setInactivateError(message);
      if (notify) notify.error(message, t('users.alerts.inactivatedFailed'));
    } finally {
      setUpdatingStatus(false);
    }
  };

  const confirmActivate = async () => {
    if (!activateTarget || updatingStatus) return;
    setUpdatingStatus(true);
    try {
      await adminApi.updateUserStatus(activateTarget.id, { status: 'Active' });
      setUsers((prev) => prev.map((u) => (u.id === activateTarget.id ? { ...u, status: 'active', reason_inactive: null } : u)));
      if (notify) notify.success(t('users.alerts.activatedSuccess', { name: displayName(activateTarget) }));
      setActivateTarget(null);
    } catch (err) {
      if (notify) notify.error(err.response?.data?.message || err.message, t('users.alerts.activatedFailed'));
    } finally {
      setUpdatingStatus(false);
    }
  };

  const confirmDelete = async () => {
    const target = deleteTarget;
    if (!target) return;
    try {
      await adminApi.deleteUser(target.id);
      setUsers((prev) => prev.map((u) => (u.id === target.id ? { ...u, status: 'deleted', delete_at: new Date().toISOString() } : u)));
      setFilter((prev) => (prev.statuses.includes('deleted') ? prev : { ...prev, statuses: [...ALL_STATUSES] }));
      if (notify) notify.success(t('users.alerts.deletedSuccess', { name: displayName(target) }));
    } catch (err) {
      if (notify) notify.error(err.response?.data?.message || err.message, t('users.alerts.deletedFailed'));
    }
  };

  const columns = [
    {
      key: 'name',
      title: t('users.table.colName'),
      width: '30%',
      render: (u) => (
        <div className="flex min-w-0 items-center gap-3">
          <span aria-hidden="true" className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-brand-soft text-xs font-semibold text-brand">
            {initials(u.name)}
          </span>
          <div className="min-w-0">
            <TruncateCell text={u.name} className="font-medium text-ink" />
            <TruncateCell text={`@${u.username}`} className="text-xs text-ink-faint" />
          </div>
        </div>
      ),
    },
    { key: 'email', title: t('users.table.colEmail'), render: (u) => <TruncateCell text={u.email} className="text-ink-muted" /> },
    { key: 'phone', title: t('users.table.colPhone'), render: (u) => <span className="tabular-nums text-ink-muted">{maskPhone(u.phone)}</span> },
    { key: 'status', title: t('users.table.colStatus'), render: (u) => <Badge tone={STATUS_TONE[u.status] || 'neutral'}>{statusLabel(u)}</Badge> },
    {
      key: 'actions',
      title: t('users.table.colActions'),
      align: 'right',
      render: (u) => (
        <div className="flex items-center justify-end gap-1">
          {u.status === 'active' && (
            <Button variant="danger-ghost" size="sm" icon="block" aria-label={t('users.table.inactivateBtn')} title={t('users.table.inactivateBtn')} onClick={() => openInactivate(u)} />
          )}
          {u.status === 'inactive' && (
            <>
              <Button variant="ghost" size="sm" icon="check_circle" aria-label={t('users.table.activateBtn')} title={t('users.table.activateBtn')} onClick={() => setActivateTarget(u)} />
              <Button variant="danger-ghost" size="sm" icon="delete" aria-label={t('users.table.deleteBtn')} title={t('users.table.deleteBtn')} onClick={() => setDeleteTarget(u)} />
            </>
          )}
          <Button variant="ghost" size="sm" icon="visibility" aria-label={t('users.table.viewDetail')} title={t('users.table.viewDetail')} onClick={() => setDetailUserId(u.id)} />
        </div>
      ),
    },
  ];

  const tabs = [
    { key: 'all', label: t('users.tabs.all'), count: stats.all },
    { key: 'active', label: t('users.tabs.active'), count: stats.active },
    { key: 'inactive', label: t('users.tabs.inactive'), count: stats.inactive },
    { key: 'pendingdelete', label: t('users.tabs.pendingDelete'), count: stats.pendingdelete },
    { key: 'deleted', label: t('users.tabs.deleted'), count: stats.deleted },
  ];

  const toggleDraftStatus = (status) =>
    setDraftFilter((prev) => ({
      ...prev,
      statuses: prev.statuses.includes(status) ? prev.statuses.filter((s) => s !== status) : [...prev.statuses, status],
    }));

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t('users.title')}
        description={t('users.subtitle')}
        actions={
          <Button icon="refresh" onClick={fetchUsers} loading={loading}>
            {t('users.refresh')}
          </Button>
        }
      />

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label={t('users.stats.total')} value={stats.all} />
        <StatCard label={t('users.stats.active')} value={stats.active} />
        <StatCard label={t('users.stats.inactive')} value={stats.inactive} />
        <StatCard label={t('users.stats.pendingDelete')} value={stats.pendingdelete} />
      </div>

      <Card>
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line px-4 py-3">
          <Tabs items={tabs} value={tabValue} onChange={selectTab} ariaLabel={t('users.tabs.ariaLabel')} />
          <div className="flex flex-wrap items-center gap-2">
            <SearchInput
              label={t('users.searchLabel')}
              placeholder={t('users.searchPlaceholder')}
              value={search}
              onChange={setSearch}
              className="w-full sm:w-72"
            />
            <Button
              icon="filter_alt"
              className={filterIsCustom ? 'border-brand text-brand' : ''}
              onClick={() => {
                setDraftFilter(filter);
                setFilterOpen(true);
              }}
            >
              {t('users.filterBtn')}
            </Button>
          </div>
        </div>
        <DataTable
          columns={columns}
          rows={pageData}
          rowKey="id"
          loading={loading && users.length === 0}
          emptyTitle={t('users.table.emptyTitle')}
          emptyDescription={t('users.table.emptySubtitle')}
          minWidth={780}
        />
        <Pagination
          currentPage={currentPage}
          pageSize={pageSize}
          total={filteredUsers.length}
          onPageChange={setCurrentPage}
          onPageSizeChange={(size) => {
            setPageSize(size);
            setCurrentPage(1);
          }}
          itemLabel={t('users.table.itemLabel')}
        />
      </Card>

      <Modal
        open={filterOpen}
        onClose={() => setFilterOpen(false)}
        size="sm"
        title={t('users.filterModal.title')}
        footer={
          <>
            <Button
              onClick={() => {
                setFilter(DEFAULT_FILTER);
                setFilterOpen(false);
              }}
            >
              {t('users.filterModal.resetBtn')}
            </Button>
            <Button
              variant="primary"
              onClick={() => {
                setFilter(draftFilter);
                setFilterOpen(false);
              }}
            >
              {t('users.filterModal.applyBtn')}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-5">
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-ink">{t('users.filterModal.packageLabel')}</span>
            <select
              data-testid="filter-package"
              value={draftFilter.packageType}
              onChange={(e) => setDraftFilter((prev) => ({ ...prev, packageType: e.target.value }))}
              className="h-10 cursor-pointer rounded-lg border border-line bg-card px-3 pr-9 text-sm text-ink focus:border-brand focus:outline-none"
            >
              <option value="all">{t('users.filterModal.allPackages')}</option>
              <option value="Basic">{t('users.filterModal.basicPackage')}</option>
              <option value="Premium">{t('users.filterModal.premiumPackage')}</option>
            </select>
          </label>
          <fieldset className="m-0 flex flex-col gap-2.5 border-0 p-0">
            <legend className="mb-2 text-sm font-medium text-ink">{t('users.filterModal.statusLabel')}</legend>
            <label className="flex cursor-pointer items-center gap-2.5 text-sm text-ink">
              <input
                type="checkbox"
                data-testid="filter-status-all"
                checked={ALL_STATUSES.every((s) => draftFilter.statuses.includes(s))}
                onChange={(e) => setDraftFilter((prev) => ({ ...prev, statuses: e.target.checked ? [...ALL_STATUSES] : [] }))}
                className="h-4 w-4 cursor-pointer accent-brand"
              />
              {t('users.filterModal.allStatus')}
            </label>
            {ALL_STATUSES.map((status) => (
              <label key={status} className="flex cursor-pointer items-center gap-2.5 text-sm text-ink">
                <input
                  type="checkbox"
                  data-testid={`filter-status-${status}`}
                  checked={draftFilter.statuses.includes(status)}
                  onChange={() => toggleDraftStatus(status)}
                  className="h-4 w-4 cursor-pointer accent-brand"
                />
                {t(`commonStatus.${status}`)}
              </label>
            ))}
          </fieldset>
        </div>
      </Modal>

      <Modal
        open={Boolean(inactivateTarget)}
        onClose={() => setInactivateTarget(null)}
        size="sm"
        closeDisabled={updatingStatus}
        title={t('users.inactivateModal.title')}
        description={inactivateTarget ? `${inactivateTarget.name} (@${inactivateTarget.username})` : undefined}
        footer={
          <>
            <Button onClick={() => setInactivateTarget(null)} disabled={updatingStatus}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" form={`${reasonId}-form`} variant="danger" loading={updatingStatus} disabled={!inactivateReason.trim()}>
              {t('users.inactivateModal.submitBtn')}
            </Button>
          </>
        }
      >
        <form id={`${reasonId}-form`} onSubmit={confirmInactivate} className="flex flex-col gap-1.5">
          <label htmlFor={reasonId} className="text-sm font-medium text-ink">
            {t('users.inactivateModal.reasonLabel')}
          </label>
          <textarea
            id={reasonId}
            rows={3}
            autoFocus
            value={inactivateReason}
            placeholder={t('users.inactivateModal.reasonPlaceholder')}
            onChange={(e) => {
              setInactivateReason(e.target.value);
              if (inactivateError) setInactivateError('');
            }}
            className={`w-full resize-none rounded-lg border bg-card px-3 py-2 text-sm text-ink focus:outline-none focus:ring-2 focus:ring-brand/20 ${
              inactivateError ? 'border-danger' : 'border-line focus:border-brand'
            }`}
          />
          {inactivateError ? (
            <p role="alert" className="m-0 text-sm text-danger">
              {inactivateError}
            </p>
          ) : (
            <p className="m-0 text-xs text-ink-faint">{t('users.inactivateModal.warning')}</p>
          )}
        </form>
      </Modal>

      <ConfirmModal
        open={Boolean(activateTarget)}
        title={t('users.activateModal.title')}
        message={activateTarget ? t('users.activateModal.message', { name: displayName(activateTarget) }) : ''}
        confirmText={t('users.activateModal.submitBtn')}
        loading={updatingStatus}
        onConfirm={confirmActivate}
        onCancel={() => setActivateTarget(null)}
      />

      <SecurityConfirmModal
        isOpen={Boolean(deleteTarget)}
        onClose={() => setDeleteTarget(null)}
        title={t('users.deleteModal.title')}
        description={t('users.deleteModal.warning')}
        confirmText={t('users.deleteModal.confirmBtn')}
        actionType="DELETE_USER"
        targetLabel={deleteTarget ? `@${deleteTarget.username}` : ''}
        dangerLevel="critical"
        onConfirm={confirmDelete}
      />

      {detailUserId && <UserDetailModal userId={detailUserId} onClose={() => setDetailUserId(null)} />}
    </div>
  );
};

export default UserListPage;
