import React from 'react';
import { useLanguageSafe } from '../../../store/language.context';

const PermissionFilterToolbar = ({
  search,
  onSearchChange,
  groups = [],
  selectedGroup = 'ALL',
  onSelectGroup,
  viewMode = 'ALL', // 'ALL' | 'Basic' | 'Premium'
  onViewModeChange,
  onlyDirty = false,
  onToggleDirty,
  dirtyCount = 0,
  totalFeatures = 0,
  limitCount = 0,
  onRefresh,
  onResetDefault,
  onSave,
  loading = false,
  saving = false,
}) => {
  const { t } = useLanguageSafe();

  return (
    <div className="bg-white border border-slate-200 rounded-lg p-3.5 space-y-3 shadow-2xs mb-4">
      {/* Hàng 1: Tiêu đề trang, Segmented Control chọn gói & Nút hành động */}
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-3 border-b border-slate-100 pb-3">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-md bg-slate-100 border border-slate-200 text-slate-700 flex items-center justify-center flex-shrink-0">
            <span className="material-symbols-outlined text-[18px]">admin_panel_settings</span>
          </div>
          <div>
            <h1 className="text-sm font-bold text-slate-900 m-0 leading-tight">
              {t('permissions.title', 'Quản Lý Phân Quyền Tính Năng')}
            </h1>
            <p className="text-[11px] text-slate-500 m-0 mt-0.5">
              {t('permissions.subtitle', 'Ma trận 4 Trụ Cột: Truy cập · Định mức · Phạm vi · Chính sách hạ cấp')}
            </p>
          </div>
        </div>

        {/* Segmented Control Chọn Chế Độ Xem Gói Cước */}
        <div className="inline-flex items-center p-0.5 bg-slate-100 border border-slate-200 rounded-lg self-start lg:self-center">
          <button
            type="button"
            data-testid="tab-viewmode-all"
            onClick={() => onViewModeChange('ALL')}
            className={`px-2.5 py-1 text-xs font-semibold rounded-md transition cursor-pointer flex items-center gap-1 ${
              viewMode === 'ALL'
                ? 'bg-white text-slate-900 shadow-2xs border border-slate-200/80 font-bold'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <span className="material-symbols-outlined text-[14px]">view_column</span>
            <span>{t('permissions.toolbar.viewAll', 'Đối Chiếu 2 Gói')}</span>
          </button>
          <button
            type="button"
            data-testid="tab-viewmode-basic"
            onClick={() => onViewModeChange('Basic')}
            className={`px-2.5 py-1 text-xs font-semibold rounded-md transition cursor-pointer flex items-center gap-1 ${
              viewMode === 'Basic'
                ? 'bg-white text-slate-900 shadow-2xs border border-slate-200/80 font-bold'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <span className="material-symbols-outlined text-[14px]">tag</span>
            <span>{t('permissions.toolbar.viewBasic', 'Gói Basic')}</span>
          </button>
          <button
            type="button"
            data-testid="tab-viewmode-premium"
            onClick={() => onViewModeChange('Premium')}
            className={`px-2.5 py-1 text-xs font-semibold rounded-md transition cursor-pointer flex items-center gap-1 ${
              viewMode === 'Premium'
                ? 'bg-white text-slate-900 shadow-2xs border border-slate-200/80 font-bold'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <span className="material-symbols-outlined text-[14px]">verified</span>
            <span>{t('permissions.toolbar.viewPremium', 'Gói Premium')}</span>
          </button>
        </div>

        {/* Nút Hành Động */}
        <div className="flex items-center gap-2 flex-wrap">
          <button
            type="button"
            data-testid="btn-refresh"
            onClick={onRefresh}
            disabled={loading || saving}
            className="px-2.5 py-1 bg-white hover:bg-slate-50 border border-slate-300 text-slate-700 text-xs font-semibold rounded-md transition cursor-pointer flex items-center gap-1 disabled:opacity-50"
            title={t('permissions.refreshTitle', 'Tải lại dữ liệu từ máy chủ')}
          >
            <span className={`material-symbols-outlined text-[14px] ${loading ? 'animate-spin' : ''}`}>
              refresh
            </span>
            <span>{t('permissions.refreshBtn', 'Làm mới')}</span>
          </button>

          <button
            type="button"
            data-testid="btn-reset-default"
            onClick={onResetDefault}
            disabled={loading || saving}
            className="px-2.5 py-1 bg-white hover:bg-red-50 border border-slate-300 hover:border-red-300 text-slate-700 hover:text-red-700 text-xs font-semibold rounded-md transition cursor-pointer flex items-center gap-1 disabled:opacity-50"
            title={t('permissions.resetDefaultTitle', 'Khôi phục về phân quyền chuẩn')}
          >
            <span className="material-symbols-outlined text-[14px]">restart_alt</span>
            <span>{t('permissions.resetDefaultBtn', 'Đặt Lại Mặc Định')}</span>
          </button>

          <button
            type="button"
            data-testid="btn-save-permissions"
            onClick={onSave}
            disabled={dirtyCount === 0 || saving || loading}
            className={`px-3 py-1 text-xs font-bold rounded-md shadow-2xs transition flex items-center gap-1.5 ${
              dirtyCount > 0
                ? 'bg-primary hover:bg-primary/90 text-white cursor-pointer'
                : 'bg-slate-100 text-slate-400 cursor-not-allowed border border-slate-200'
            }`}
            title={t('permissions.saveTitle', 'Lưu các thay đổi đã thực hiện')}
          >
            <span className="material-symbols-outlined text-[15px]">save</span>
            <span>
              {saving
                ? t('permissions.saving', 'Đang lưu...')
                : t('permissions.saveBtn', { count: dirtyCount }) || `Lưu Thay Đổi (${dirtyCount})`}
            </span>
          </button>
        </div>
      </div>

      {/* Hàng 2: Bộ lọc tìm kiếm, Phân hệ, Lọc đã sửa và Thống kê */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-2.5">
        <div className="flex items-center gap-2 flex-1 max-w-lg">
          <div className="relative flex-1">
            <span className="material-symbols-outlined absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400 text-[16px]">
              search
            </span>
            <input
              type="text"
              data-testid="input-search-features"
              value={search}
              onChange={(e) => onSearchChange(e.target.value)}
              placeholder={t('permissions.searchPlaceholder', 'Tìm tên hoặc mã tính năng...')}
              className="w-full pl-8 pr-7 py-1 bg-slate-50 border border-slate-200 rounded-md text-xs font-medium text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-1 focus:ring-primary focus:bg-white transition"
            />
            {search && (
              <button
                type="button"
                onClick={() => onSearchChange('')}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
              >
                <span className="material-symbols-outlined text-[13px]">cancel</span>
              </button>
            )}
          </div>

          <select
            data-testid="select-group-filter"
            value={selectedGroup}
            onChange={(e) => onSelectGroup(e.target.value)}
            className="text-xs font-medium text-slate-700 bg-slate-50 border border-slate-200 rounded-md px-2.5 py-1 focus:outline-none focus:ring-1 focus:ring-primary focus:bg-white transition"
          >
            <option value="ALL">Phân hệ: Tất cả ({groups.length})</option>
            {groups.map((grp) => (
              <option key={grp} value={grp}>
                Phân hệ: {grp}
              </option>
            ))}
          </select>
        </div>

        <div className="flex items-center gap-3">
          {dirtyCount > 0 && (
            <label className="flex items-center gap-1.5 text-xs font-semibold text-amber-800 bg-amber-50 px-2.5 py-0.5 rounded border border-amber-200 cursor-pointer">
              <input
                type="checkbox"
                data-testid="checkbox-only-dirty"
                checked={onlyDirty}
                onChange={(e) => onToggleDirty(e.target.checked)}
                className="w-3.5 h-3.5 rounded text-amber-600 focus:ring-amber-500 cursor-pointer"
              />
              <span>{t('permissions.filterDirty', 'Chỉ xem dòng đã sửa')}</span>
            </label>
          )}

          <div className="text-[11px] font-medium text-slate-500 flex items-center gap-2">
            <span>{totalFeatures} tính năng</span>
            <span>·</span>
            <span>{limitCount} có trần</span>
          </div>
        </div>
      </div>
    </div>
  );
};

export default PermissionFilterToolbar;
