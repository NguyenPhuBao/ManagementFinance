import React, { useState } from 'react';
import { useLanguageSafe } from '../../../store/language.context';

const POLICY_OPTIONS = [
  { value: 'BLOCK_CREATE', labelVi: 'Chặn tạo mới', labelEn: 'Block Create' },
  { value: 'LOCK_FEATURE', labelVi: 'Khóa tính năng', labelEn: 'Lock Feature' },
  { value: 'READ_ONLY', labelVi: 'Chỉ xem dữ liệu', labelEn: 'Read-only' },
  { value: 'GRACE_PERIOD_3D', labelVi: 'Ân hạn 3 ngày', labelEn: '3-Day Grace' },
  { value: 'FALLBACK_DEFAULT', labelVi: 'Về mặc định', labelEn: 'Fallback' },
];

const formatScopeSummary = (scopeConfig, t) => {
  if (!scopeConfig || typeof scopeConfig !== 'object' || Object.keys(scopeConfig).length === 0) {
    return t ? t('permissions.scope.defaultShort', 'Mặc định') : 'Mặc định';
  }
  const parts = [];
  if (scopeConfig.allowed_formats) {
    parts.push(
      Array.isArray(scopeConfig.allowed_formats)
        ? scopeConfig.allowed_formats.join(', ').toUpperCase()
        : String(scopeConfig.allowed_formats).toUpperCase()
    );
  }
  if (scopeConfig.forecast_days) parts.push(`${scopeConfig.forecast_days}d`);
  if (scopeConfig.max_image_size_mb) parts.push(`${scopeConfig.max_image_size_mb}MB`);
  if (scopeConfig.daily_scans) parts.push(`${scopeConfig.daily_scans}/d`);
  if (scopeConfig.model_type) parts.push(String(scopeConfig.model_type));
  if (scopeConfig.rule) parts.push(String(scopeConfig.rule));

  if (parts.length > 0) return parts.join(' · ');
  const vals = Object.values(scopeConfig).map((v) => (typeof v === 'object' ? '...' : String(v)));
  return vals.slice(0, 2).join(' · ') || (t ? t('permissions.scope.customShort', 'Tùy chỉnh') : 'Tùy chỉnh');
};

const PermissionMatrixTable = ({
  groupName,
  features = [],
  viewMode = 'ALL', // 'ALL' | 'Basic' | 'Premium'
  draftPermissions = { Basic: {}, Premium: {} },
  originalPermissions = { Basic: {}, Premium: {} },
  onToggleEnable,
  onLimitChange,
  onUnlimitedToggle,
  onPolicyChange,
  onOpenScopeDrawer,
  onUndoRow,
}) => {
  const { t, currentLang } = useLanguageSafe();
  const [collapsed, setCollapsed] = useState(false);

  if (!features || features.length === 0) return null;

  const renderPillarsRow = (f, accountType, isSubRow = false) => {
    const isLimitType = f.type === 'LIMIT';
    const draft = draftPermissions[accountType]?.[f.id] || {
      is_enabled: true,
      limit_value: isLimitType ? (accountType === 'Basic' ? 3 : null) : null,
      downgrade_policy: f.default_downgrade_policy || 'BLOCK_CREATE',
      scope_config: {},
    };
    const orig = originalPermissions[accountType]?.[f.id] || draft;
    const isUnlimited = isLimitType && draft.limit_value === null;

    const isDirty =
      draft.is_enabled !== orig.is_enabled ||
      draft.limit_value !== orig.limit_value ||
      draft.downgrade_policy !== orig.downgrade_policy ||
      JSON.stringify(draft.scope_config || {}) !== JSON.stringify(orig.scope_config || {});

    const isBasic = accountType === 'Basic';

    return (
      <tr
        key={`${f.id}-${accountType}`}
        className={`text-xs transition-colors border-b border-slate-100 ${
          isDirty
            ? 'bg-amber-50/40 hover:bg-amber-50/70'
            : isSubRow
            ? isBasic
              ? 'bg-slate-50/30 hover:bg-slate-100/50'
              : 'bg-white hover:bg-slate-50/60'
            : 'hover:bg-slate-50/60'
        }`}
      >
        {/* Nếu không phải subRow (tức là chế độ xem đơn gói), hiển thị cột Feature */}
        {!isSubRow && (
          <td className="py-2.5 px-3.5 align-middle">
            <div className="flex items-center gap-1.5 flex-wrap">
              <span className="font-semibold text-slate-900">{f.name}</span>
              <span
                className={`text-[9px] font-bold px-1.5 py-0.2 rounded ${
                  isLimitType
                    ? 'bg-blue-50 text-blue-700 border border-blue-200'
                    : 'bg-purple-50 text-purple-700 border border-purple-200'
                }`}
              >
                {isLimitType ? 'LIMIT' : 'TOGGLE'}
              </span>
            </div>
          </td>
        )}

        {/* Cột Gói Cước */}
        <td className="py-2.5 px-3 align-middle whitespace-nowrap">
          <span
            className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[11px] font-bold border ${
              isBasic
                ? 'bg-slate-100 text-slate-700 border-slate-300'
                : 'bg-emerald-50 text-emerald-800 border-emerald-300'
            }`}
          >
            <span className="material-symbols-outlined text-[13px]">
              {isBasic ? 'tag' : 'verified'}
            </span>
            {isBasic ? 'BASIC' : 'PREMIUM'}
          </span>
        </td>

        {/* Trụ 1: Quyền Truy Cập (Access) */}
        <td className="py-2.5 px-3 align-middle whitespace-nowrap">
          <div className="flex items-center gap-2">
            <label className="relative inline-flex items-center cursor-pointer flex-shrink-0">
              <input
                type="checkbox"
                aria-label={`Toggle ${f.id} ${accountType}`}
                checked={Boolean(draft.is_enabled)}
                onChange={(e) => onToggleEnable(accountType, f.id, e.target.checked)}
                className="sr-only peer"
              />
              <div className="w-8 h-4.5 bg-slate-300 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-3.5 after:w-3.5 after:transition-all peer-checked:bg-emerald-600" />
            </label>
            <span
              className={`text-[11px] font-medium ${
                draft.is_enabled ? 'text-emerald-700 font-semibold' : 'text-slate-400'
              }`}
            >
              {draft.is_enabled
                ? t('permissions.statusEnabled', 'Mở')
                : t('permissions.statusDisabled', 'Khóa')}
            </span>
          </div>
        </td>

        {/* Trụ 2: Định Mức (Quota / Limit) */}
        <td className="py-2.5 px-3 align-middle whitespace-nowrap">
          {isLimitType ? (
            <div className="flex items-center gap-1.5">
              <input
                type="number"
                min="0"
                max="999"
                aria-label={`Quota ${f.id} ${accountType}`}
                disabled={!draft.is_enabled || isUnlimited}
                value={draft.limit_value ?? ''}
                onChange={(e) => onLimitChange(accountType, f.id, e.target.value)}
                placeholder={isUnlimited ? '∞' : '0'}
                className="w-14 px-1.5 py-0.5 text-xs font-semibold text-center rounded border border-slate-300 bg-white disabled:bg-slate-100 disabled:text-slate-400 focus:outline-none focus:ring-1 focus:ring-primary"
              />
              <label className="flex items-center gap-1 text-[11px] font-medium text-slate-600 cursor-pointer select-none">
                <input
                  type="checkbox"
                  aria-label={`Unlimited ${f.id} ${accountType}`}
                  disabled={!draft.is_enabled}
                  checked={isUnlimited}
                  onChange={(e) => onUnlimitedToggle(accountType, f.id, e.target.checked)}
                  className="w-3.5 h-3.5 rounded text-primary focus:ring-primary cursor-pointer"
                />
                <span>∞ Vô hạn</span>
              </label>
            </div>
          ) : (
            <span className="text-[11px] text-slate-400 italic">
              {t('permissions.table.notApplicable', 'Theo Access')}
            </span>
          )}
        </td>

        {/* Trụ 3: Phạm Vi (Scope) */}
        <td className="py-2.5 px-3 align-middle">
          <div className="flex items-center gap-1.5 flex-wrap">
            <span
              className="text-[11px] font-mono px-2 py-0.5 rounded bg-slate-100 text-slate-700 border border-slate-200 max-w-[160px] truncate"
              title={JSON.stringify(draft.scope_config || {})}
            >
              {formatScopeSummary(draft.scope_config, t)}
            </span>
            <button
              type="button"
              data-testid={`btn-config-scope-${f.id}-${accountType}`}
              aria-label={`Config Scope ${f.id} ${accountType}`}
              onClick={() => onOpenScopeDrawer(f, accountType)}
              className="p-1 text-slate-500 hover:text-primary hover:bg-slate-100 rounded border border-slate-200 transition cursor-pointer"
              title="Cấu hình Trụ 3 (Scope JSON)"
            >
              <span className="material-symbols-outlined text-[13px]">edit</span>
            </button>
          </div>
        </td>

        {/* Trụ 4: Chính Sách Hạ Cấp (Downgrade Policy) */}
        <td className="py-2.5 px-3 align-middle whitespace-nowrap">
          <select
            value={draft.downgrade_policy || 'BLOCK_CREATE'}
            aria-label={`Policy ${f.id} ${accountType}`}
            onChange={(e) => onPolicyChange(accountType, f.id, e.target.value)}
            disabled={!draft.is_enabled}
            className="text-[11px] font-medium text-slate-700 bg-white border border-slate-300 rounded px-2 py-1 focus:outline-none focus:ring-1 focus:ring-primary disabled:bg-slate-100 disabled:text-slate-400 transition"
          >
            {POLICY_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {currentLang === 'en' ? opt.labelEn : opt.labelVi} ({opt.value})
              </option>
            ))}
          </select>
        </td>

        {/* Cột Hoàn tác (Undo) */}
        <td className="py-2.5 px-2 align-middle text-center whitespace-nowrap">
          {isDirty ? (
            <button
              type="button"
              aria-label={`Undo ${f.id} ${accountType}`}
              onClick={() => onUndoRow(f.id, accountType)}
              className="p-1 text-amber-600 hover:text-amber-800 hover:bg-amber-100/60 rounded cursor-pointer transition"
              title={t('permissions.table.undoRow', 'Hoàn tác dòng này')}
            >
              <span className="material-symbols-outlined text-[15px]">undo</span>
            </button>
          ) : (
            <span className="text-[11px] text-slate-300 select-none">-</span>
          )}
        </td>
      </tr>
    );
  };

  return (
    <div className="bg-white border border-slate-200 rounded-lg overflow-hidden shadow-2xs mb-3">
      {/* Group Header (Collapsible) */}
      <div
        onClick={() => setCollapsed(!collapsed)}
        className="px-3.5 py-2 bg-slate-100/80 border-b border-slate-200 flex items-center justify-between cursor-pointer hover:bg-slate-200/60 transition select-none"
      >
        <div className="flex items-center gap-2">
          <span className="material-symbols-outlined text-slate-500 text-[17px]">
            {collapsed ? 'folder' : 'folder_open'}
          </span>
          <span className="text-xs font-bold text-slate-800 uppercase tracking-wide">
            {groupName} ({features.length})
          </span>
        </div>
        <span className="material-symbols-outlined text-slate-400 text-[18px]">
          {collapsed ? 'expand_more' : 'expand_less'}
        </span>
      </div>

      {/* Main Table */}
      {!collapsed && (
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50 border-b border-slate-200 text-[11px] font-bold text-slate-600 uppercase tracking-wider">
                <th className="py-2.5 px-3.5 w-[24%]">{t('permissions.table.featureCol', 'Tính Năng & Mã Định Danh')}</th>
                <th className="py-2.5 px-3 w-[8%]">{t('permissions.table.planCol', 'Gói')}</th>
                <th className="py-2.5 px-3 w-[14%]">{t('permissions.table.pillar1Col', 'Trụ 1: Truy Cập')}</th>
                <th className="py-2.5 px-3 w-[15%]">{t('permissions.table.pillar2Col', 'Trụ 2: Định Mức')}</th>
                <th className="py-2.5 px-3 w-[15%]">{t('permissions.table.pillar3Col', 'Trụ 3: Phạm Vi')}</th>
                <th className="py-2.5 px-3 w-[16%]">{t('permissions.table.pillar4Col', 'Trụ 4: Chính Sách Hạ Cấp')}</th>
                <th className="py-2.5 px-2 w-[8%] text-center">{t('permissions.table.actionsCol', 'Thao tác')}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {features.map((f) => {
                const isLimitType = f.type === 'LIMIT';

                if (viewMode === 'Basic') {
                  return renderPillarsRow(f, 'Basic', false);
                }
                if (viewMode === 'Premium') {
                  return renderPillarsRow(f, 'Premium', false);
                }

                // View Mode === 'ALL' (Chế độ đối chiếu cả 2 gói)
                const isBasicDirty =
                  JSON.stringify(draftPermissions.Basic?.[f.id] || {}) !==
                  JSON.stringify(originalPermissions.Basic?.[f.id] || {});
                const isPremDirty =
                  JSON.stringify(draftPermissions.Premium?.[f.id] || {}) !==
                  JSON.stringify(originalPermissions.Premium?.[f.id] || {});
                const isRowDirty = isBasicDirty || isPremDirty;

                return (
                  <React.Fragment key={f.id}>
                    {/* Dòng 1: Gói Basic (Cột tính năng gộp rowSpan=2) */}
                    <tr
                      className={`text-xs transition-colors border-t border-slate-200 ${
                        isRowDirty ? 'bg-amber-50/20' : 'bg-white'
                      }`}
                    >
                      {/* Cột 1: Thông tin tính năng gộp 2 hàng */}
                      <td rowSpan={2} className="py-2.5 px-3.5 align-middle border-r border-slate-100 bg-white">
                        <div className="flex items-center gap-1.5 flex-wrap">
                          <span className="font-semibold text-slate-900 text-xs">{f.name}</span>
                          <span
                            className={`text-[9px] font-bold px-1.5 py-0.2 rounded ${
                              isLimitType
                                ? 'bg-blue-50 text-blue-700 border border-blue-200'
                                : 'bg-purple-50 text-purple-700 border border-purple-200'
                            }`}
                          >
                            {isLimitType ? 'LIMIT' : 'TOGGLE'}
                          </span>
                        </div>
                      </td>

                      {/* Các cột cho Gói Basic */}
                      {(() => {
                        const basicDraft = draftPermissions.Basic?.[f.id] || {
                          is_enabled: true,
                          limit_value: isLimitType ? 3 : null,
                          downgrade_policy: f.default_downgrade_policy || 'BLOCK_CREATE',
                          scope_config: {},
                        };
                        const basicIsUnlimited = isLimitType && basicDraft.limit_value === null;

                        return (
                          <>
                            {/* Gói */}
                            <td className="py-2 px-3 align-middle whitespace-nowrap bg-slate-50/40">
                              <span className="inline-flex items-center gap-1 px-1.5 py-0.2 rounded text-[10px] font-bold bg-slate-200 text-slate-700 border border-slate-300">
                                BASIC
                              </span>
                            </td>

                            {/* Trụ 1 */}
                            <td className="py-2 px-3 align-middle whitespace-nowrap bg-slate-50/40">
                              <div className="flex items-center gap-2">
                                <label className="relative inline-flex items-center cursor-pointer flex-shrink-0">
                                  <input
                                    type="checkbox"
                                    aria-label={`Toggle ${f.id} Basic`}
                                    checked={Boolean(basicDraft.is_enabled)}
                                    onChange={(e) => onToggleEnable('Basic', f.id, e.target.checked)}
                                    className="sr-only peer"
                                  />
                                  <div className="w-7 h-4 bg-slate-300 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-3 after:w-3 after:transition-all peer-checked:bg-emerald-600" />
                                </label>
                                <span className={`text-[11px] ${basicDraft.is_enabled ? 'text-emerald-700 font-semibold' : 'text-slate-400'}`}>
                                  {basicDraft.is_enabled ? 'Mở' : 'Khóa'}
                                </span>
                              </div>
                            </td>

                            {/* Trụ 2 */}
                            <td className="py-2 px-3 align-middle whitespace-nowrap bg-slate-50/40">
                              {isLimitType ? (
                                <div className="flex items-center gap-1">
                                  <input
                                    type="number"
                                    min="0"
                                    max="999"
                                    aria-label={`Quota ${f.id} Basic`}
                                    disabled={!basicDraft.is_enabled || basicIsUnlimited}
                                    value={basicDraft.limit_value ?? ''}
                                    onChange={(e) => onLimitChange('Basic', f.id, e.target.value)}
                                    placeholder={basicIsUnlimited ? '∞' : '0'}
                                    className="w-13 px-1 py-0.5 text-xs font-semibold text-center rounded border border-slate-300 bg-white disabled:bg-slate-100 disabled:text-slate-400"
                                  />
                                  <label className="flex items-center gap-0.5 text-[10px] text-slate-500 cursor-pointer">
                                    <input
                                      type="checkbox"
                                      aria-label={`Unlimited ${f.id} Basic`}
                                      disabled={!basicDraft.is_enabled}
                                      checked={basicIsUnlimited}
                                      onChange={(e) => onUnlimitedToggle('Basic', f.id, e.target.checked)}
                                      className="w-3 h-3 rounded"
                                    />
                                    <span>∞</span>
                                  </label>
                                </div>
                              ) : (
                                <span className="text-[11px] text-slate-400 italic">Theo Access</span>
                              )}
                            </td>

                            {/* Trụ 3 Basic */}
                            <td className="py-2 px-3 align-middle bg-slate-50/40">
                              <div className="flex items-center gap-1">
                                <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-white text-slate-700 border border-slate-200 truncate max-w-[130px]">
                                  {formatScopeSummary(basicDraft.scope_config, t)}
                                </span>
                                <button
                                  type="button"
                                  data-testid={`btn-config-scope-${f.id}-Basic`}
                                  aria-label={`Config Scope ${f.id} Basic`}
                                  title="Cấu hình Trụ 3 (Scope JSON)"
                                  onClick={() => onOpenScopeDrawer(f, 'Basic')}
                                  className="p-0.5 text-slate-400 hover:text-primary rounded cursor-pointer"
                                >
                                  <span className="material-symbols-outlined text-[13px]">edit</span>
                                </button>
                              </div>
                            </td>

                            {/* Trụ 4 Basic */}
                            <td className="py-2 px-3 align-middle whitespace-nowrap bg-slate-50/40">
                              <select
                                value={basicDraft.downgrade_policy || 'BLOCK_CREATE'}
                                aria-label={`Policy ${f.id} Basic`}
                                onChange={(e) => onPolicyChange('Basic', f.id, e.target.value)}
                                disabled={!basicDraft.is_enabled}
                                className="text-[10px] font-medium text-slate-700 bg-white border border-slate-300 rounded px-1.5 py-0.5"
                              >
                                {POLICY_OPTIONS.map((opt) => (
                                  <option key={opt.value} value={opt.value}>
                                    {currentLang === 'en' ? opt.labelEn : opt.labelVi}
                                  </option>
                                ))}
                              </select>
                            </td>

                            {/* Undo */}
                            <td className="py-2 px-2 align-middle text-center bg-slate-50/40">
                              {isBasicDirty ? (
                                <button
                                  type="button"
                                  aria-label={`Undo ${f.id} Basic`}
                                  onClick={() => onUndoRow(f.id, 'Basic')}
                                  className="text-amber-600 hover:text-amber-800"
                                >
                                  <span className="material-symbols-outlined text-[14px]">undo</span>
                                </button>
                              ) : (
                                <span className="text-slate-300 text-[10px]">-</span>
                              )}
                            </td>
                          </>
                        );
                      })()}
                    </tr>

                    {/* Dòng 2: Gói Premium */}
                    <tr
                      className={`text-xs transition-colors border-b border-slate-200 ${
                        isRowDirty ? 'bg-amber-50/30' : 'bg-white'
                      }`}
                    >
                      {(() => {
                        const premDraft = draftPermissions.Premium?.[f.id] || {
                          is_enabled: true,
                          limit_value: null,
                          downgrade_policy: f.default_downgrade_policy || 'BLOCK_CREATE',
                          scope_config: {},
                        };
                        const premIsUnlimited = isLimitType && premDraft.limit_value === null;

                        return (
                          <>
                            {/* Gói */}
                            <td className="py-2 px-3 align-middle whitespace-nowrap">
                              <span className="inline-flex items-center gap-1 px-1.5 py-0.2 rounded text-[10px] font-bold bg-emerald-50 text-emerald-800 border border-emerald-200">
                                PREMIUM
                              </span>
                            </td>

                            {/* Trụ 1 */}
                            <td className="py-2 px-3 align-middle whitespace-nowrap">
                              <div className="flex items-center gap-2">
                                <label className="relative inline-flex items-center cursor-pointer flex-shrink-0">
                                  <input
                                    type="checkbox"
                                    aria-label={`Toggle ${f.id} Premium`}
                                    checked={Boolean(premDraft.is_enabled)}
                                    onChange={(e) => onToggleEnable('Premium', f.id, e.target.checked)}
                                    className="sr-only peer"
                                  />
                                  <div className="w-7 h-4 bg-slate-300 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-3 after:w-3 after:transition-all peer-checked:bg-emerald-600" />
                                </label>
                                <span className={`text-[11px] ${premDraft.is_enabled ? 'text-emerald-700 font-semibold' : 'text-slate-400'}`}>
                                  {premDraft.is_enabled ? 'Mở' : 'Khóa'}
                                </span>
                              </div>
                            </td>

                            {/* Trụ 2 */}
                            <td className="py-2 px-3 align-middle whitespace-nowrap">
                              {isLimitType ? (
                                <div className="flex items-center gap-1">
                                  <input
                                    type="number"
                                    min="0"
                                    max="999"
                                    aria-label={`Quota ${f.id} Premium`}
                                    disabled={!premDraft.is_enabled || premIsUnlimited}
                                    value={premDraft.limit_value ?? ''}
                                    onChange={(e) => onLimitChange('Premium', f.id, e.target.value)}
                                    placeholder={premIsUnlimited ? '∞' : '0'}
                                    className="w-13 px-1 py-0.5 text-xs font-semibold text-center rounded border border-slate-300 bg-white disabled:bg-slate-100 disabled:text-slate-400"
                                  />
                                  <label className="flex items-center gap-0.5 text-[10px] text-slate-500 cursor-pointer">
                                    <input
                                      type="checkbox"
                                      aria-label={`Unlimited ${f.id} Premium`}
                                      disabled={!premDraft.is_enabled}
                                      checked={premIsUnlimited}
                                      onChange={(e) => onUnlimitedToggle('Premium', f.id, e.target.checked)}
                                      className="w-3 h-3 rounded"
                                    />
                                    <span>∞</span>
                                  </label>
                                </div>
                              ) : (
                                <span className="text-[11px] text-slate-400 italic">Theo Access</span>
                              )}
                            </td>

                            {/* Trụ 3 */}
                            <td className="py-2 px-3 align-middle">
                              <div className="flex items-center gap-1">
                                <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-slate-100 text-slate-700 border border-slate-200 truncate max-w-[130px]">
                                  {formatScopeSummary(premDraft.scope_config, t)}
                                </span>
                                <button
                                  type="button"
                                  data-testid={`btn-config-scope-${f.id}-Premium`}
                                  aria-label={`Config Scope ${f.id} Premium`}
                                  title="Cấu hình Trụ 3 (Scope JSON)"
                                  onClick={() => onOpenScopeDrawer(f, 'Premium')}
                                  className="p-0.5 text-slate-400 hover:text-primary rounded cursor-pointer"
                                >
                                  <span className="material-symbols-outlined text-[13px]">edit</span>
                                </button>
                              </div>
                            </td>

                            {/* Trụ 4 */}
                            <td className="py-2 px-3 align-middle whitespace-nowrap">
                              <select
                                value={premDraft.downgrade_policy || 'BLOCK_CREATE'}
                                aria-label={`Policy ${f.id} Premium`}
                                onChange={(e) => onPolicyChange('Premium', f.id, e.target.value)}
                                disabled={!premDraft.is_enabled}
                                className="text-[10px] font-medium text-slate-700 bg-white border border-slate-300 rounded px-1.5 py-0.5"
                              >
                                {POLICY_OPTIONS.map((opt) => (
                                  <option key={opt.value} value={opt.value}>
                                    {currentLang === 'en' ? opt.labelEn : opt.labelVi}
                                  </option>
                                ))}
                              </select>
                            </td>

                            {/* Undo */}
                            <td className="py-2 px-2 align-middle text-center">
                              {isPremDirty ? (
                                <button
                                  type="button"
                                  aria-label={`Undo ${f.id} Premium`}
                                  onClick={() => onUndoRow(f.id, 'Premium')}
                                  className="text-amber-600 hover:text-amber-800"
                                >
                                  <span className="material-symbols-outlined text-[14px]">undo</span>
                                </button>
                              ) : (
                                <span className="text-slate-300 text-[10px]">-</span>
                              )}
                            </td>
                          </>
                        );
                      })()}
                    </tr>
                  </React.Fragment>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

export default PermissionMatrixTable;
