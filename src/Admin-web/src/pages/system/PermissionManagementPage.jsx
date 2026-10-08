import React, { useState, useEffect, useMemo } from 'react';
import adminApi from '../../api/admin.api';
import { useAlertSafe } from '../../store/alert.context';

const FEATURE_ICONS = {
  wallets: 'account_balance_wallet',
  budgets: 'pie_chart',
  goals: 'flag',
  bills: 'receipt_long',
  custom_categories: 'category',
  ai_assistant: 'smart_toy',
  ai_quick_input: 'bolt',
  ocr_receipt: 'document_scanner',
  ai_edge_model: 'memory',
  smart_budget_rebalancing: 'balance',
  financial_health_fhs: 'health_and_safety',
  export_reports: 'file_download',
  cashflow_forecast: 'trending_up',
  anomaly_spending_insights: 'warning_amber',
  bill_auto_pay: 'autorenew',
  goal_auto_deposit: 'savings',
  bank_notification_parser: 'notifications_active',
};

const GROUP_ICONS = {
  'Tài nguyên': 'inventory_2',
  'Trí tuệ nhân tạo': 'psychology',
  'Báo cáo & Phân tích': 'analytics',
  'Tự động hóa & Tiện ích': 'tune',
  core: 'inventory_2',
  ai: 'psychology',
};

const PermissionManagementPage = () => {
  const alert = useAlertSafe();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [features, setFeatures] = useState([]);
  const [originalPermissions, setOriginalPermissions] = useState({ Basic: {}, Premium: {} });
  const [draftPermissions, setDraftPermissions] = useState({ Basic: {}, Premium: {} });
  const [search, setSearch] = useState('');
  const [selectedGroup, setSelectedGroup] = useState('ALL');

  // Tải dữ liệu từ Backend
  const fetchPermissions = async () => {
    try {
      setLoading(true);
      const res = await adminApi.getPermissions();
      const payload = res.data || res;
      const data = payload.data || payload;

      const featList = data.features || [];
      const perms = data.permissions || { Basic: {}, Premium: {} };

      setFeatures(featList);
      setOriginalPermissions(JSON.parse(JSON.stringify(perms)));
      setDraftPermissions(JSON.parse(JSON.stringify(perms)));
    } catch (err) {
      console.error('Lỗi tải danh mục phân quyền:', err);
      alert?.error?.(err.message || 'Không thể tải cấu hình phân quyền', 'Lỗi kết nối');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPermissions();
  }, []);

  // Danh sách các nhóm tính năng
  const groups = useMemo(() => {
    const set = new Set();
    features.forEach((f) => {
      if (f.category_group) set.add(f.category_group);
    });
    return Array.from(set);
  }, [features]);

  // Danh sách các thay đổi chưa lưu (dirty items)
  const pendingUpdates = useMemo(() => {
    const updates = [];
    const types = ['Basic', 'Premium'];

    for (const accType of types) {
      for (const feat of features) {
        const orig = originalPermissions[accType]?.[feat.id] || { is_enabled: true, limit_value: null };
        const draft = draftPermissions[accType]?.[feat.id] || { is_enabled: true, limit_value: null };

        const isLimitDiff = draft.limit_value !== orig.limit_value;
        const isToggleDiff = draft.is_enabled !== orig.is_enabled;

        if (isLimitDiff || isToggleDiff) {
          updates.push({
            account_type: accType,
            feature_id: feat.id,
            is_enabled: draft.is_enabled,
            limit_value: draft.limit_value,
          });
        }
      }
    }
    return updates;
  }, [features, originalPermissions, draftPermissions]);

  // Cập nhật giá trị ô nhập số (LIMIT)
  const handleLimitChange = (accountType, featureId, rawValue) => {
    setDraftPermissions((prev) => {
      const copy = JSON.parse(JSON.stringify(prev));
      if (!copy[accountType]) copy[accountType] = {};
      if (!copy[accountType][featureId]) copy[accountType][featureId] = { is_enabled: true, limit_value: 3 };

      if (rawValue === '' || rawValue === null) {
        copy[accountType][featureId].limit_value = null;
      } else {
        const num = Math.max(0, parseInt(rawValue, 10) || 0);
        copy[accountType][featureId].limit_value = num;
      }
      return copy;
    });
  };

  // Cập nhật checkbox Không Giới Hạn cho LIMIT
  const handleUnlimitedToggle = (accountType, featureId, isUnlimitedChecked) => {
    setDraftPermissions((prev) => {
      const copy = JSON.parse(JSON.stringify(prev));
      if (!copy[accountType]) copy[accountType] = {};
      if (!copy[accountType][featureId]) copy[accountType][featureId] = { is_enabled: true, limit_value: null };

      if (isUnlimitedChecked) {
        copy[accountType][featureId].limit_value = null; // Không giới hạn
      } else {
        copy[accountType][featureId].limit_value = 3; // Mặc định số lượng cụ thể
      }
      return copy;
    });
  };

  // Cập nhật checkbox Bật/Tắt cho TOGGLE (Check = bật, notcheck = tắt)
  const handleToggleChange = (accountType, featureId, isChecked) => {
    setDraftPermissions((prev) => {
      const copy = JSON.parse(JSON.stringify(prev));
      if (!copy[accountType]) copy[accountType] = {};
      if (!copy[accountType][featureId]) copy[accountType][featureId] = { is_enabled: false, limit_value: null };

      copy[accountType][featureId].is_enabled = Boolean(isChecked);
      return copy;
    });
  };

  // Lưu tất cả thay đổi
  const handleSaveAll = async () => {
    if (pendingUpdates.length === 0) return;

    try {
      setSaving(true);
      await adminApi.updatePermissions(pendingUpdates);
      alert?.success?.(`Đã lưu thành công ${pendingUpdates.length} thay đổi phân quyền!`, 'Cập nhật hoàn tất');
      // Đồng bộ lại bản gốc
      setOriginalPermissions(JSON.parse(JSON.stringify(draftPermissions)));
    } catch (err) {
      console.error('Lỗi lưu phân quyền:', err);
      alert?.error?.(err.message || 'Không thể lưu phân quyền', 'Lỗi cập nhật');
    } finally {
      setSaving(false);
    }
  };

  // Khôi phục bản nháp về dữ liệu gốc
  const handleReset = () => {
    setDraftPermissions(JSON.parse(JSON.stringify(originalPermissions)));
    alert?.info?.('Đã khôi phục các thay đổi chưa lưu', 'Hủy bỏ');
  };

  // Lọc tính năng theo từ khóa tìm kiếm và nhóm
  const filteredFeatures = useMemo(() => {
    return features.filter((f) => {
      const matchSearch =
        !search.trim() ||
        f.name.toLowerCase().includes(search.toLowerCase()) ||
        f.id.toLowerCase().includes(search.toLowerCase()) ||
        (f.description && f.description.toLowerCase().includes(search.toLowerCase()));

      const matchGroup = selectedGroup === 'ALL' || f.category_group === selectedGroup;

      return matchSearch && matchGroup;
    });
  }, [features, search, selectedGroup]);

  // Gom nhóm danh sách đã lọc
  const groupedFeatures = useMemo(() => {
    const map = {};
    for (const f of filteredFeatures) {
      const g = f.category_group || 'Chung';
      if (!map[g]) map[g] = [];
      map[g].push(f);
    }
    return map;
  }, [filteredFeatures]);

  return (
    <div className="space-y-6 max-w-7xl mx-auto pb-12">
      {/* ─── PAGE HEADER ─── */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-surface p-6 rounded-2xl border border-outline-variant shadow-sm">
        <div>
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-xl bg-primary/10 text-primary flex items-center justify-center">
              <span className="material-symbols-outlined text-3xl">admin_panel_settings</span>
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white tracking-tight">
                Phân Quyền Tính Năng Động Theo Gói Cước
              </h1>
              <p className="text-secondary-fixed-dim text-sm mt-0.5">
                Thiết lập hạn mức tài nguyên (LIMIT) và bật/tắt chức năng (TOGGLE) theo từng loại tài khoản
              </p>
            </div>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex items-center gap-3">
          <button
            onClick={fetchPermissions}
            disabled={loading || saving}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl border border-outline-variant bg-surface-variant hover:bg-on-secondary-fixed-variant text-white text-sm font-medium transition cursor-pointer disabled:opacity-50"
            title="Tải lại từ máy chủ"
          >
            <span className={`material-symbols-outlined text-lg ${loading ? 'animate-spin' : ''}`}>
              refresh
            </span>
            <span>Làm mới</span>
          </button>

          {pendingUpdates.length > 0 && (
            <button
              onClick={handleReset}
              disabled={saving}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl border border-red-500/30 text-red-400 hover:bg-red-500/10 text-sm font-medium transition cursor-pointer disabled:opacity-50"
            >
              <span className="material-symbols-outlined text-lg">undo</span>
              <span>Khôi phục</span>
            </button>
          )}

          <button
            onClick={handleSaveAll}
            disabled={pendingUpdates.length === 0 || saving}
            className={`flex items-center gap-2 px-5 py-2.5 rounded-xl font-semibold text-sm transition shadow-lg cursor-pointer ${
              pendingUpdates.length > 0
                ? 'bg-primary hover:bg-primary/90 text-white shadow-primary/20 animate-pulse'
                : 'bg-outline-variant/30 text-secondary-fixed-dim cursor-not-allowed opacity-60'
            }`}
          >
            <span className="material-symbols-outlined text-lg">
              {saving ? 'sync' : 'save'}
            </span>
            <span>Lưu tất cả ({pendingUpdates.length})</span>
          </button>
        </div>
      </div>

      {/* ─── FILTER & STATS BAR ─── */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* Tìm kiếm */}
        <div className="relative md:col-span-2">
          <span className="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-secondary-fixed-dim">
            search
          </span>
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Tìm theo tên tính năng hoặc mã slug (wallets, ai_assistant...)..."
            className="w-full pl-11 pr-4 py-3 rounded-xl bg-surface border border-outline-variant text-white placeholder-secondary-fixed-dim/60 focus:outline-none focus:border-primary text-sm"
          />
        </div>

        {/* Lọc theo Nhóm */}
        <div>
          <select
            value={selectedGroup}
            onChange={(e) => setSelectedGroup(e.target.value)}
            className="w-full px-4 py-3 rounded-xl bg-surface border border-outline-variant text-white focus:outline-none focus:border-primary text-sm cursor-pointer"
          >
            <option value="ALL">Tất cả nhóm chức năng ({features.length})</option>
            {groups.map((g) => (
              <option key={g} value={g}>
                Nhóm: {g}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* ─── LOADING STATE ─── */}
      {loading ? (
        <div className="bg-surface rounded-2xl border border-outline-variant p-12 text-center">
          <div className="inline-block w-10 h-10 border-4 border-primary border-t-transparent rounded-full animate-spin mb-4" />
          <p className="text-secondary-fixed-dim text-sm">Đang nạp cấu hình phân quyền từ hệ thống CSDL...</p>
        </div>
      ) : Object.keys(groupedFeatures).length === 0 ? (
        <div className="bg-surface rounded-2xl border border-outline-variant p-12 text-center">
          <span className="material-symbols-outlined text-5xl text-secondary-fixed-dim mb-3">
            search_off
          </span>
          <h3 className="text-lg font-bold text-white mb-1">Không tìm thấy tính năng nào</h3>
          <p className="text-secondary-fixed-dim text-sm">Vui lòng thử lại với từ khóa tìm kiếm khác</p>
        </div>
      ) : (
        /* ─── GROUPED FEATURE MATRIX ─── */
        <div className="space-y-8">
          {Object.entries(groupedFeatures).map(([groupName, groupItems]) => (
            <div
              key={groupName}
              className="bg-surface rounded-2xl border border-outline-variant overflow-hidden shadow-sm"
            >
              {/* Group Header */}
              <div className="px-6 py-4 bg-surface-variant/40 border-b border-outline-variant flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-lg bg-primary/20 text-primary flex items-center justify-center">
                    <span className="material-symbols-outlined text-xl">
                      {GROUP_ICONS[groupName] || 'folder_open'}
                    </span>
                  </div>
                  <div>
                    <h2 className="text-base font-bold text-white uppercase tracking-wider">
                      Nhóm: {groupName}
                    </h2>
                    <span className="text-xs text-secondary-fixed-dim">
                      {groupItems.length} tính năng trong nhóm
                    </span>
                  </div>
                </div>
              </div>

              {/* Matrix Table */}
              <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="border-b border-outline-variant text-xs font-semibold text-secondary-fixed-dim bg-on-background/20">
                      <th className="py-4 px-6 w-5/12">TÍNH NĂNG & MÔ TẢ</th>
                      <th className="py-4 px-6 w-3/12">
                        <div className="flex items-center gap-2">
                          <span className="w-2.5 h-2.5 rounded-full bg-slate-400" />
                          <span className="text-slate-200">GÓI BASIC (CƠ BẢN)</span>
                        </div>
                      </th>
                      <th className="py-4 px-6 w-4/12">
                        <div className="flex items-center gap-2">
                          <span className="w-2.5 h-2.5 rounded-full bg-amber-400" />
                          <span className="text-amber-300">GÓI PREMIUM (TRẢ PHÍ)</span>
                        </div>
                      </th>
                    </tr>
                  </thead>

                  <tbody className="divide-y divide-outline-variant/60 text-sm">
                    {groupItems.map((feature) => {
                      const icon = FEATURE_ICONS[feature.id] || 'tune';
                      const isLimitType = feature.type === 'LIMIT';

                      // Trạng thái nháp của Basic
                      const basicDraft = draftPermissions.Basic?.[feature.id] || {
                        is_enabled: true,
                        limit_value: isLimitType ? 3 : null,
                      };
                      const basicIsUnlimited = basicDraft.limit_value === null;

                      // Trạng thái nháp của Premium
                      const premiumDraft = draftPermissions.Premium?.[feature.id] || {
                        is_enabled: true,
                        limit_value: null,
                      };
                      const premiumIsUnlimited = premiumDraft.limit_value === null;

                      // Kiểm tra xem hàng này có đang sửa đổi không
                      const isBasicDirty =
                        draftPermissions.Basic?.[feature.id]?.limit_value !==
                          originalPermissions.Basic?.[feature.id]?.limit_value ||
                        draftPermissions.Basic?.[feature.id]?.is_enabled !==
                          originalPermissions.Basic?.[feature.id]?.is_enabled;

                      const isPremiumDirty =
                        draftPermissions.Premium?.[feature.id]?.limit_value !==
                          originalPermissions.Premium?.[feature.id]?.limit_value ||
                        draftPermissions.Premium?.[feature.id]?.is_enabled !==
                          originalPermissions.Premium?.[feature.id]?.is_enabled;

                      return (
                        <tr
                          key={feature.id}
                          className={`hover:bg-on-background/10 transition-colors ${
                            isBasicDirty || isPremiumDirty ? 'bg-primary/5' : ''
                          }`}
                        >
                          {/* Cột 1: Thông tin tính năng */}
                          <td className="py-4 px-6">
                            <div className="flex items-start gap-3">
                              <div className="w-10 h-10 rounded-xl bg-on-background flex items-center justify-center text-primary-fixed-dim mt-0.5 flex-shrink-0 border border-outline-variant">
                                <span className="material-symbols-outlined text-2xl">{icon}</span>
                              </div>
                              <div>
                                <div className="flex items-center gap-2">
                                  <span className="font-semibold text-white text-base">
                                    {feature.name}
                                  </span>
                                  <span
                                    className={`px-2 py-0.5 rounded text-[10px] font-bold tracking-wider uppercase ${
                                      isLimitType
                                        ? 'bg-purple-500/20 text-purple-300 border border-purple-500/30'
                                        : 'bg-cyan-500/20 text-cyan-300 border border-cyan-500/30'
                                    }`}
                                  >
                                    {isLimitType ? 'Hạn mức số lượng' : 'Bật / Tắt'}
                                  </span>
                                </div>
                                <p className="text-secondary-fixed-dim text-xs mt-1 leading-relaxed">
                                  {feature.description}
                                </p>
                                <div className="text-[11px] text-secondary-fixed-dim/70 mt-1 font-mono">
                                  slug: <span className="text-slate-300">{feature.id}</span>
                                </div>
                              </div>
                            </div>
                          </td>

                          {/* Cột 2: Gói Basic */}
                          <td className="py-4 px-6 align-middle">
                            {isLimitType ? (
                              /* LIMIT: Cho phép nhập số + Checkbox không giới hạn */
                              <div className="space-y-2">
                                <div className="flex items-center gap-2">
                                  <input
                                    type="number"
                                    min="0"
                                    max="1000"
                                    disabled={basicIsUnlimited}
                                    value={basicIsUnlimited ? '' : (basicDraft.limit_value ?? 0)}
                                    onChange={(e) =>
                                      handleLimitChange('Basic', feature.id, e.target.value)
                                    }
                                    className={`w-28 px-3 py-1.5 rounded-lg border text-sm font-semibold transition text-center focus:outline-none focus:border-primary ${
                                      basicIsUnlimited
                                        ? 'bg-on-background/40 border-outline-variant text-secondary-fixed-dim cursor-not-allowed'
                                        : 'bg-surface border-outline-variant text-white'
                                    }`}
                                    placeholder="Vô hạn"
                                  />
                                  <span className="text-xs text-secondary-fixed-dim">mục</span>
                                </div>

                                <label className="flex items-center gap-2 text-xs text-secondary-fixed-dim cursor-pointer hover:text-white select-none">
                                  <input
                                    type="checkbox"
                                    checked={basicIsUnlimited}
                                    onChange={(e) =>
                                      handleUnlimitedToggle('Basic', feature.id, e.target.checked)
                                    }
                                    className="w-4 h-4 rounded accent-primary cursor-pointer"
                                  />
                                  <span>Không giới hạn (∞)</span>
                                </label>
                              </div>
                            ) : (
                              /* TOGGLE: Checkbox Bật / Tắt (Check = bật, notcheck = tắt) */
                              <div className="flex items-center gap-3">
                                <label className="relative inline-flex items-center cursor-pointer">
                                  <input
                                    type="checkbox"
                                    checked={Boolean(basicDraft.is_enabled)}
                                    onChange={(e) =>
                                      handleToggleChange('Basic', feature.id, e.target.checked)
                                    }
                                    className="sr-only peer"
                                  />
                                  <div className="w-11 h-6 bg-outline-variant peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-500"></div>
                                </label>
                                <span
                                  className={`text-xs font-semibold px-2.5 py-1 rounded-md ${
                                    basicDraft.is_enabled
                                      ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                                      : 'bg-gray-500/20 text-gray-400 border border-gray-500/30'
                                  }`}
                                >
                                  {basicDraft.is_enabled ? 'Bật (Cho phép)' : 'Tắt (Khóa)'}
                                </span>
                              </div>
                            )}
                          </td>

                          {/* Cột 3: Gói Premium */}
                          <td className="py-4 px-6 align-middle">
                            {isLimitType ? (
                              /* LIMIT: Cho phép nhập số + Checkbox không giới hạn */
                              <div className="space-y-2">
                                <div className="flex items-center gap-2">
                                  <input
                                    type="number"
                                    min="0"
                                    max="1000"
                                    disabled={premiumIsUnlimited}
                                    value={premiumIsUnlimited ? '' : (premiumDraft.limit_value ?? 0)}
                                    onChange={(e) =>
                                      handleLimitChange('Premium', feature.id, e.target.value)
                                    }
                                    className={`w-28 px-3 py-1.5 rounded-lg border text-sm font-semibold transition text-center focus:outline-none focus:border-amber-400 ${
                                      premiumIsUnlimited
                                        ? 'bg-on-background/40 border-outline-variant text-amber-300/60 cursor-not-allowed'
                                        : 'bg-surface border-amber-500/40 text-amber-300'
                                    }`}
                                    placeholder="Vô hạn"
                                  />
                                  <span className="text-xs text-amber-300/80">mục</span>
                                </div>

                                <label className="flex items-center gap-2 text-xs text-amber-300/90 cursor-pointer hover:text-amber-200 select-none">
                                  <input
                                    type="checkbox"
                                    checked={premiumIsUnlimited}
                                    onChange={(e) =>
                                      handleUnlimitedToggle('Premium', feature.id, e.target.checked)
                                    }
                                    className="w-4 h-4 rounded accent-amber-500 cursor-pointer"
                                  />
                                  <span>Không giới hạn (Khuyên dùng cho Premium)</span>
                                </label>
                              </div>
                            ) : (
                              /* TOGGLE: Checkbox Bật / Tắt (Check = bật, notcheck = tắt) */
                              <div className="flex items-center gap-3">
                                <label className="relative inline-flex items-center cursor-pointer">
                                  <input
                                    type="checkbox"
                                    checked={Boolean(premiumDraft.is_enabled)}
                                    onChange={(e) =>
                                      handleToggleChange('Premium', feature.id, e.target.checked)
                                    }
                                    className="sr-only peer"
                                  />
                                  <div className="w-11 h-6 bg-outline-variant peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-500"></div>
                                </label>
                                <span
                                  className={`text-xs font-semibold px-2.5 py-1 rounded-md ${
                                    premiumDraft.is_enabled
                                      ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                                      : 'bg-gray-500/20 text-gray-400 border border-gray-500/30'
                                  }`}
                                >
                                  {premiumDraft.is_enabled ? 'Bật (Mặc định)' : 'Tắt (Khóa)'}
                                </span>
                              </div>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default PermissionManagementPage;
