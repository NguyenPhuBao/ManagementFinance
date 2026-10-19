import React, { useState, useEffect, useMemo, useCallback } from 'react';
import adminApi from '../../api/admin.api';
import useSocket from '../../hooks/useSocket';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import PermissionFilterToolbar from './components/PermissionFilterToolbar';
import PermissionMatrixTable from './components/PermissionMatrixTable';
import PermissionScopeDrawer from './components/PermissionScopeDrawer';

const GROUP_I18N_KEYS = {
  'Tài nguyên': 'resources',
  'Trí tuệ nhân tạo': 'ai',
  'Trí tuệ nhân tạo & Edge AI': 'ai',
  'Báo cáo & Phân tích': 'reporting',
  'Tự động hóa & Tiện ích': 'automation',
  'Xác thực & Bảo mật': 'auth',
  'Trang chủ & Điều hướng': 'home',
  'Quản lý Ví & Tài sản': 'wallet',
  'Sổ giao dịch Thu Chi': 'transactions',
  'Hệ thống Danh mục': 'categories',
  'Ngân sách Chi tiêu': 'budget',
  'Hóa đơn định kỳ': 'bills',
  'Mục tiêu Tích lũy': 'goals',
  'Thông báo & Giám sát': 'notifications',
  'Gói cước & Thanh toán': 'payment',
  'Đồng bộ Ngoại tuyến': 'sync',
};

const getTranslatedGroupName = (groupName, t) => {
  const key = GROUP_I18N_KEYS[groupName];
  if (key && t) {
    const translated = t(`permissions.groups.${key}`);
    if (translated && translated !== `permissions.groups.${key}`) return translated;
  }
  return groupName;
};

const PermissionManagementPage = () => {
  const alert = useAlertSafe();
  const socket = useSocket();
  const { t } = useLanguageSafe();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [resetting, setResetting] = useState(false);
  const [features, setFeatures] = useState([]);
  const [originalPermissions, setOriginalPermissions] = useState({ Basic: {}, Premium: {} });
  const [draftPermissions, setDraftPermissions] = useState({ Basic: {}, Premium: {} });
  const [search, setSearch] = useState('');
  const [selectedGroup, setSelectedGroup] = useState('ALL');
  const [viewMode, setViewMode] = useState('ALL'); // 'ALL' | 'Basic' | 'Premium'
  const [onlyDirty, setOnlyDirty] = useState(false);

  // Modals xác nhận
  const [showConfirmModal, setShowConfirmModal] = useState(false);
  const [showResetModal, setShowResetModal] = useState(false);

  // State cho Drawer Inspector (Trụ 3 Scope JSON & Policy)
  const [activeDrawer, setActiveDrawer] = useState({
    isOpen: false,
    feature: null,
    accountType: 'Basic',
  });

  // Tải dữ liệu ma trận phân quyền từ Backend
  const fetchPermissions = async () => {
    try {
      setLoading(true);
      const res = await adminApi.getPermissions();
      const payload = res?.data || res;
      const data = payload?.data || payload;

      const featList = data?.features || [];
      const perms = data?.permissions || { Basic: {}, Premium: {} };

      setFeatures(featList);
      setOriginalPermissions(JSON.parse(JSON.stringify(perms)));
      setDraftPermissions(JSON.parse(JSON.stringify(perms)));
    } catch (err) {
      console.error('Lỗi tải danh mục phân quyền:', err);
      const msg = err?.response?.data?.message || err?.message || t('permissions.feedback.loadError');
      alert?.error?.(msg, t('permissions.feedback.loadErrorTitle'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPermissions();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Lắng nghe socket realtime
  useEffect(() => {
    if (!socket) return;
    const handlePermissionsUpdated = () => {
      fetchPermissions();
    };
    socket.on('account.permissions_updated', handlePermissionsUpdated);
    return () => {
      socket.off('account.permissions_updated', handlePermissionsUpdated);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [socket]);

  // Danh sách các nhóm phân hệ độc nhất
  const uniqueGroups = useMemo(() => {
    const set = new Set();
    features.forEach((f) => {
      if (f.category_group) set.add(f.category_group);
    });
    return Array.from(set);
  }, [features]);

  // Kiểm tra số lượng thay đổi chưa lưu (Dirty items count)
  const dirtyItems = useMemo(() => {
    const list = [];
    ['Basic', 'Premium'].forEach((type) => {
      const origMap = originalPermissions[type] || {};
      const draftMap = draftPermissions[type] || {};

      features.forEach((f) => {
        const o = origMap[f.id];
        const d = draftMap[f.id];
        if (!o || !d) return;

        const isChanged =
          d.is_enabled !== o.is_enabled ||
          d.limit_value !== o.limit_value ||
          d.downgrade_policy !== o.downgrade_policy ||
          JSON.stringify(d.scope_config || {}) !== JSON.stringify(o.scope_config || {});

        if (isChanged) {
          list.push({
            account_type: type,
            feature_id: f.id,
            feature_name: f.name,
            is_enabled: d.is_enabled,
            limit_value: d.limit_value,
            downgrade_policy: d.downgrade_policy,
            scope_config: d.scope_config,
          });
        }
      });
    });
    return list;
  }, [features, originalPermissions, draftPermissions]);

  // Bộ lọc tính năng
  const filteredFeaturesByGroup = useMemo(() => {
    const searchLower = search.trim().toLowerCase();
    const map = {};

    features.forEach((f) => {
      const matchSearch =
        !searchLower ||
        f.name.toLowerCase().includes(searchLower) ||
        f.id.toLowerCase().includes(searchLower) ||
        (f.description && f.description.toLowerCase().includes(searchLower));

      const matchGroup = selectedGroup === 'ALL' || f.category_group === selectedGroup;

      if (!matchSearch || !matchGroup) return;

      if (onlyDirty) {
        const isDirty = dirtyItems.some((d) => d.feature_id === f.id);
        if (!isDirty) return;
      }

      const grp = f.category_group || 'Chung';
      if (!map[grp]) map[grp] = [];
      map[grp].push(f);
    });

    return map;
  }, [features, search, selectedGroup, onlyDirty, dirtyItems]);

  // Handler: Bật/Tắt quyền truy cập (Trụ 1)
  const handleToggleEnable = useCallback((accountType, featureId, isEnabled) => {
    setDraftPermissions((prev) => ({
      ...prev,
      [accountType]: {
        ...prev[accountType],
        [featureId]: {
          ...prev[accountType]?.[featureId],
          is_enabled: isEnabled,
        },
      },
    }));
  }, []);

  // Handler: Thay đổi hạn mức Quota (Trụ 2)
  const handleLimitChange = useCallback((accountType, featureId, value) => {
    const num = value === '' ? null : Math.max(0, parseInt(value, 10) || 0);
    setDraftPermissions((prev) => ({
      ...prev,
      [accountType]: {
        ...prev[accountType],
        [featureId]: {
          ...prev[accountType]?.[featureId],
          limit_value: num,
        },
      },
    }));
  }, []);

  // Handler: Chuyển đổi trạng thái Vô hạn (Trụ 2)
  const handleUnlimitedToggle = useCallback((accountType, featureId, isUnlimited) => {
    setDraftPermissions((prev) => ({
      ...prev,
      [accountType]: {
        ...prev[accountType],
        [featureId]: {
          ...prev[accountType]?.[featureId],
          limit_value: isUnlimited ? null : 0,
        },
      },
    }));
  }, []);

  // Handler: Thay đổi Chính sách Hạ cấp trực tiếp (Trụ 4)
  const handlePolicyChange = useCallback((accountType, featureId, policy) => {
    setDraftPermissions((prev) => ({
      ...prev,
      [accountType]: {
        ...prev[accountType],
        [featureId]: {
          ...prev[accountType]?.[featureId],
          downgrade_policy: policy,
        },
      },
    }));
  }, []);

  // Handler: Mở Drawer Inspector chỉnh sửa Scope JSON & Policy
  const handleOpenScopeDrawer = useCallback(
    (feature, accountType) => {
      setActiveDrawer({
        isOpen: true,
        feature,
        accountType,
      });
    },
    []
  );

  // Handler: Áp dụng Scope & Policy từ Drawer
  const handleApplyScopeAndPolicy = useCallback(
    ({ featureId, accountType, scope_config, downgrade_policy }) => {
      setDraftPermissions((prev) => ({
        ...prev,
        [accountType]: {
          ...prev[accountType],
          [featureId]: {
            ...prev[accountType]?.[featureId],
            scope_config,
            downgrade_policy,
          },
        },
      }));
    },
    []
  );

  // Handler: Hoàn tác đúng 1 dòng (Undo) theo featureId và accountType
  const handleUndoRow = useCallback((featureId, accountType) => {
    setDraftPermissions((prev) => {
      if (accountType) {
        return {
          ...prev,
          [accountType]: {
            ...prev[accountType],
            [featureId]: JSON.parse(JSON.stringify(originalPermissions[accountType]?.[featureId] || {})),
          },
        };
      }
      return {
        Basic: {
          ...prev.Basic,
          [featureId]: JSON.parse(JSON.stringify(originalPermissions.Basic?.[featureId] || {})),
        },
        Premium: {
          ...prev.Premium,
          [featureId]: JSON.parse(JSON.stringify(originalPermissions.Premium?.[featureId] || {})),
        },
      };
    });
  }, [originalPermissions]);

  // Handler: Lưu thay đổi hàng loạt (Batch Save)
  const handleSave = async () => {
    if (dirtyItems.length === 0) return;
    try {
      setSaving(true);
      const updates = dirtyItems.map((item) => ({
        account_type: item.account_type,
        feature_id: item.feature_id,
        is_enabled: item.is_enabled,
        limit_value: item.limit_value,
        scope_config: item.scope_config,
        downgrade_policy: item.downgrade_policy,
      }));

      await adminApi.updatePermissions(updates);
      setShowConfirmModal(false);
      alert?.success?.(
        t('permissions.feedback.saveSuccess', { count: updates.length }) || `Đã cập nhật thành công ${updates.length} thiết lập phân quyền!`,
        t('permissions.feedback.saveSuccessTitle', 'Phân Quyền Gói Cước')
      );
      await fetchPermissions();
    } catch (err) {
      console.error('Lỗi lưu phân quyền:', err);
      const msg = err?.response?.data?.message || err?.message || t('permissions.feedback.saveError');
      alert?.error?.(msg, t('permissions.feedback.saveErrorTitle'));
    } finally {
      setSaving(false);
    }
  };

  // Handler: Khôi phục cấu hình mặc định (Reset to Default)
  const handleResetDefault = async () => {
    try {
      setResetting(true);
      await adminApi.resetPermissionsDefault();
      setShowResetModal(false);
      alert?.success?.(
        t('permissions.feedback.resetSuccess', 'Đã khôi phục toàn bộ phân quyền về chuẩn mặc định!'),
        t('permissions.feedback.resetSuccessTitle', 'Khôi Phục Mặc Định')
      );
      await fetchPermissions();
    } catch (err) {
      console.error('Lỗi khôi phục phân quyền:', err);
      const msg = err?.response?.data?.message || err?.message || t('permissions.feedback.resetError');
      alert?.error?.(msg, t('permissions.feedback.resetErrorTitle'));
    } finally {
      setResetting(false);
    }
  };

  return (
    <div className="p-4 md:p-6 bg-slate-50/50 min-h-screen">
      {/* Thanh công cụ Toolbar tối giản */}
      <PermissionFilterToolbar
        search={search}
        onSearchChange={setSearch}
        groups={uniqueGroups}
        selectedGroup={selectedGroup}
        onSelectGroup={setSelectedGroup}
        viewMode={viewMode}
        onViewModeChange={setViewMode}
        onlyDirty={onlyDirty}
        onToggleDirty={setOnlyDirty}
        dirtyCount={dirtyItems.length}
        totalFeatures={features.length}
        limitCount={features.filter((f) => f.type === 'LIMIT').length}
        onRefresh={fetchPermissions}
        onResetDefault={() => setShowResetModal(true)}
        onSave={() => setShowConfirmModal(true)}
        loading={loading}
        saving={saving}
      />

      {/* Loading State */}
      {loading ? (
        <div className="bg-white border border-slate-200 rounded-lg p-12 text-center shadow-2xs">
          <span className="material-symbols-outlined animate-spin text-primary text-3xl">
            progress_activity
          </span>
          <p className="text-xs text-slate-500 font-medium mt-2">
            {t('permissions.loading', 'Đang tải ma trận phân quyền...')}
          </p>
        </div>
      ) : Object.keys(filteredFeaturesByGroup).length === 0 ? (
        <div className="bg-white border border-slate-200 rounded-lg p-12 text-center shadow-2xs">
          <span className="material-symbols-outlined text-slate-400 text-4xl">search_off</span>
          <p className="text-sm font-semibold text-slate-800 mt-2">
            {t('permissions.emptySearchTitle', 'Không tìm thấy tính năng nào')}
          </p>
          <p className="text-xs text-slate-500 mt-0.5">
            {t('permissions.emptySearchDesc', 'Thử đổi từ khóa tìm kiếm hoặc chọn phân hệ khác.')}
          </p>
        </div>
      ) : (
        /* Danh sách các nhóm phân hệ hiển thị dưới dạng bảng phẳng ma trận */
        Object.entries(filteredFeaturesByGroup).map(([grp, feats]) => (
          <PermissionMatrixTable
            key={grp}
            groupName={getTranslatedGroupName(grp, t)}
            features={feats}
            viewMode={viewMode}
            draftPermissions={draftPermissions}
            originalPermissions={originalPermissions}
            onToggleEnable={handleToggleEnable}
            onLimitChange={handleLimitChange}
            onUnlimitedToggle={handleUnlimitedToggle}
            onPolicyChange={handlePolicyChange}
            onOpenScopeDrawer={handleOpenScopeDrawer}
            onUndoRow={handleUndoRow}
          />
        ))
      )}

      {/* Drawer Inspector cấu hình Scope & Downgrade Policy */}
      {activeDrawer.isOpen && (
        <PermissionScopeDrawer
          isOpen={activeDrawer.isOpen}
          onClose={() => setActiveDrawer((prev) => ({ ...prev, isOpen: false }))}
          feature={activeDrawer.feature}
          accountType={activeDrawer.accountType}
          initialScope={draftPermissions[activeDrawer.accountType]?.[activeDrawer.feature?.id]?.scope_config || {}}
          initialPolicy={draftPermissions[activeDrawer.accountType]?.[activeDrawer.feature?.id]?.downgrade_policy || 'BLOCK_CREATE'}
          onApply={handleApplyScopeAndPolicy}
        />
      )}

      {/* Modal Xác nhận Lưu */}
      {showConfirmModal && (
        <div
          data-testid="modal-confirm-save"
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-xs"
        >
          <div className="bg-white rounded-lg border border-slate-200 max-w-md w-full p-5 shadow-xl">
            <div className="flex items-center gap-2.5 mb-2">
              <span className="material-symbols-outlined text-primary text-[22px]">save</span>
              <h3 className="text-sm font-bold text-slate-900">
                {t('permissions.confirmModal.title', 'Xác Nhận Lưu Thay Đổi')}
              </h3>
            </div>
            <p className="text-xs text-slate-600 mb-3">
              {t('permissions.confirmModal.desc', { count: dirtyItems.length }) || `Bạn có chắc chắn muốn lưu ${dirtyItems.length} thay đổi phân quyền này không?`}
            </p>
            <div className="flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setShowConfirmModal(false)}
                className="px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded border border-slate-300"
              >
                {t('common.cancel', 'Hủy')}
              </button>
              <button
                type="button"
                data-testid="btn-confirm-save"
                disabled={saving}
                onClick={handleSave}
                className="px-3.5 py-1.5 text-xs font-bold text-white bg-primary hover:bg-primary/90 rounded shadow-xs flex items-center gap-1"
              >
                {saving && <span className="material-symbols-outlined animate-spin text-[14px]">progress_activity</span>}
                {t('common.confirm', 'Xác Nhận Lưu')}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal Xác nhận Đặt Lại Mặc Định */}
      {showResetModal && (
        <div
          data-testid="modal-confirm-reset"
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-xs"
        >
          <div className="bg-white rounded-lg border border-slate-200 max-w-md w-full p-5 shadow-xl">
            <div className="flex items-center gap-2.5 mb-2 text-red-600">
              <span className="material-symbols-outlined text-[22px]">warning</span>
              <h3 className="text-sm font-bold text-slate-900">
                {t('permissions.resetModal.title', 'Khôi Phục Phân Quyền Mặc Định')}
              </h3>
            </div>
            <p className="text-xs text-slate-600 mb-3">
              {t('permissions.resetModal.desc', 'Thao tác này sẽ đặt lại toàn bộ 36 tính năng của cả 2 gói Basic và Premium về chuẩn thiết lập ban đầu.')}
            </p>
            <div className="flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setShowResetModal(false)}
                className="px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-100 rounded border border-slate-300"
              >
                {t('common.cancel', 'Hủy')}
              </button>
              <button
                type="button"
                data-testid="btn-confirm-reset"
                disabled={resetting}
                onClick={handleResetDefault}
                className="px-3.5 py-1.5 text-xs font-bold text-white bg-red-600 hover:bg-red-700 rounded shadow-xs flex items-center gap-1"
              >
                {resetting && <span className="material-symbols-outlined animate-spin text-[14px]">progress_activity</span>}
                {t('permissions.resetModal.confirmBtn', 'Đặt Lại Mặc Định')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default PermissionManagementPage;
