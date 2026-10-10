import React, { useState, useEffect, useMemo } from 'react';
import adminApi from '../../api/admin.api';
import useSocket from '../../hooks/useSocket';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';

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

const getGroupConfig = (groupName, t) => {
  const configs = {
    'Tài nguyên': {
      icon: 'inventory_2',
      color: 'text-blue-600 bg-blue-50 border-blue-200',
      badgeColor: 'bg-blue-100 text-blue-800 border-blue-200',
      name: t ? t('permissions.groups.resources') : 'Tài nguyên',
      desc: t ? t('permissions.groups.resourcesDesc') : 'Các thực thể tài chính cốt lõi có hạn mức số lượng tối đa (LIMIT)',
    },
    'Trí tuệ nhân tạo': {
      icon: 'psychology',
      color: 'text-purple-600 bg-purple-50 border-purple-200',
      badgeColor: 'bg-purple-100 text-purple-800 border-purple-200',
      name: t ? t('permissions.groups.ai') : 'Trí tuệ nhân tạo',
      desc: t ? t('permissions.groups.aiDesc') : 'Các năng lực AI Gemini, SLM on-device và thị giác máy tính OCR',
    },
    'Báo cáo & Phân tích': {
      icon: 'analytics',
      color: 'text-emerald-600 bg-emerald-50 border-emerald-200',
      badgeColor: 'bg-emerald-100 text-emerald-800 border-emerald-200',
      name: t ? t('permissions.groups.reporting') : 'Báo cáo & Phân tích',
      desc: t ? t('permissions.groups.reportingDesc') : 'Chỉ số sức khỏe tài chính FHS, dự báo dòng tiền và xuất dữ liệu',
    },
    'Tự động hóa & Tiện ích': {
      icon: 'tune',
      color: 'text-amber-600 bg-amber-50 border-amber-200',
      badgeColor: 'bg-amber-100 text-amber-800 border-amber-200',
      name: t ? t('permissions.groups.automation') : 'Tự động hóa & Tiện ích',
      desc: t ? t('permissions.groups.automationDesc') : 'Xử lý tự động hóa chi trả, trích quỹ mục tiêu và phân tích biến động',
    },
  };

  if (configs[groupName]) {
    return configs[groupName];
  }
  return {
    icon: 'folder',
    color: 'text-slate-600 bg-slate-50 border-slate-200',
    badgeColor: 'bg-slate-100 text-slate-800 border-slate-200',
    name: groupName === 'Khác' && t ? t('permissions.groups.other') : groupName,
    desc: t ? t('permissions.groups.defaultGroupDesc', { name: groupName }) : `Các chức năng thuộc nhóm ${groupName}`,
  };
};

const DEFAULT_LIMIT_PRESETS = [1, 3, 5, 10];

const PermissionManagementPage = () => {
  const alert = useAlertSafe();
  const socket = useSocket();
  const { t } = useLanguageSafe();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [features, setFeatures] = useState([]);
  const [originalPermissions, setOriginalPermissions] = useState({ Basic: {}, Premium: {} });
  const [draftPermissions, setDraftPermissions] = useState({ Basic: {}, Premium: {} });
  const [search, setSearch] = useState('');
  const [selectedGroup, setSelectedGroup] = useState('ALL');
  const [showConfirmModal, setShowConfirmModal] = useState(false);
  const [feedback, setFeedback] = useState(null);

  // Lắng nghe sự kiện socket realtime từ hệ thống (nếu có cập nhật từ admin khác)
  useEffect(() => {
    if (!socket) return;
    const handlePermissionsUpdated = (data) => {
      console.log('[Socket] Nhận thông báo permissions_updated realtime:', data);
    };
    socket.on('account.permissions_updated', handlePermissionsUpdated);
    return () => {
      socket.off('account.permissions_updated', handlePermissionsUpdated);
    };
  }, [socket]);

  // Tải dữ liệu ma trận quyền từ Backend
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
      setFeedback({ ok: false, msg });
      alert?.error?.(msg, t('permissions.feedback.loadErrorTitle'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPermissions();
  }, []);

  // Danh sách các nhóm tính năng duy nhất
  const groups = useMemo(() => {
    const list = [];
    const set = new Set();
    features.forEach((f) => {
      const g = f.category_group || 'Khác';
      if (!set.has(g)) {
        set.add(g);
        list.push(g);
      }
    });
    return list;
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
            feature_name: feat.name,
            is_enabled: draft.is_enabled,
            limit_value: draft.limit_value,
            orig_is_enabled: orig.is_enabled,
            orig_limit_value: orig.limit_value,
            type: feat.type,
          });
        }
      }
    }
    return updates;
  }, [features, originalPermissions, draftPermissions]);

  // Thống kê tổng quan cho KPI cards
  const stats = useMemo(() => {
    const total = features.length;
    const limitCount = features.filter((f) => f.type === 'LIMIT').length;
    const toggleCount = features.filter((f) => f.type === 'TOGGLE').length;
    const basicEnabled = features.filter((f) => {
      const perm = draftPermissions.Basic?.[f.id];
      if (f.type === 'LIMIT') return perm?.limit_value !== 0;
      return perm?.is_enabled === true;
    }).length;
    const premiumEnabled = features.filter((f) => {
      const perm = draftPermissions.Premium?.[f.id];
      if (f.type === 'LIMIT') return perm?.limit_value !== 0;
      return perm?.is_enabled === true;
    }).length;

    return { total, limitCount, toggleCount, basicEnabled, premiumEnabled };
  }, [features, draftPermissions]);

  // Xử lý thay đổi hạn mức số lượng (LIMIT)
  const handleLimitChange = (accountType, featureId, rawValue) => {
    setDraftPermissions((prev) => {
      const copy = JSON.parse(JSON.stringify(prev));
      if (!copy[accountType]) copy[accountType] = {};
      if (!copy[accountType][featureId]) copy[accountType][featureId] = { is_enabled: true, limit_value: 3 };

      if (rawValue === '' || rawValue === null) {
        copy[accountType][featureId].limit_value = null; // Không giới hạn
      } else {
        const num = Math.max(0, parseInt(rawValue, 10) || 0);
        copy[accountType][featureId].limit_value = num;
      }
      return copy;
    });
  };

  // Toggle không giới hạn (LIMIT: null vs số)
  const handleUnlimitedToggle = (accountType, featureId, isUnlimitedChecked) => {
    setDraftPermissions((prev) => {
      const copy = JSON.parse(JSON.stringify(prev));
      if (!copy[accountType]) copy[accountType] = {};
      if (!copy[accountType][featureId]) copy[accountType][featureId] = { is_enabled: true, limit_value: null };

      copy[accountType][featureId].limit_value = isUnlimitedChecked ? null : 3;
      return copy;
    });
  };

  // Toggle Bật/Tắt tính năng logic (TOGGLE)
  const handleToggleChange = (accountType, featureId, isChecked) => {
    setDraftPermissions((prev) => {
      const copy = JSON.parse(JSON.stringify(prev));
      if (!copy[accountType]) copy[accountType] = {};
      if (!copy[accountType][featureId]) copy[accountType][featureId] = { is_enabled: false, limit_value: null };

      copy[accountType][featureId].is_enabled = Boolean(isChecked);
      return copy;
    });
  };

  // Áp dụng Preset nhanh: Mặc Định Chuẩn (Basic giới hạn 3/5, Premium không giới hạn)
  const handleApplyDefaultPreset = () => {
    const nextDraft = JSON.parse(JSON.stringify(draftPermissions));
    features.forEach((feat) => {
      if (!nextDraft.Basic) nextDraft.Basic = {};
      if (!nextDraft.Premium) nextDraft.Premium = {};

      if (feat.type === 'LIMIT') {
        const defaultBasicLimit = feat.id === 'custom_categories' ? 5 : 3;
        nextDraft.Basic[feat.id] = { is_enabled: true, limit_value: defaultBasicLimit };
        nextDraft.Premium[feat.id] = { is_enabled: true, limit_value: null }; // Không giới hạn
      } else {
        // Toggle: Mặc định Basic bật OCR, FHS, SMS; Premium bật hết
        const basicToggles = ['ocr_receipt', 'financial_health_fhs', 'bank_notification_parser'];
        nextDraft.Basic[feat.id] = {
          is_enabled: basicToggles.includes(feat.id),
          limit_value: null,
        };
        nextDraft.Premium[feat.id] = { is_enabled: true, limit_value: null };
      }
    });

    setDraftPermissions(nextDraft);
    setFeedback({
      ok: true,
      msg: t('permissions.feedback.presetLoaded'),
    });
  };

  // Áp dụng Preset nhanh: Mở toàn bộ quyền cho Premium
  const handleUnlockAllPremium = () => {
    const nextDraft = JSON.parse(JSON.stringify(draftPermissions));
    if (!nextDraft.Premium) nextDraft.Premium = {};

    features.forEach((feat) => {
      nextDraft.Premium[feat.id] = {
        is_enabled: true,
        limit_value: null, // Không giới hạn
      };
    });

    setDraftPermissions(nextDraft);
    setFeedback({
      ok: true,
      msg: t('permissions.feedback.unlockedAllPremium'),
    });
  };

  // Khôi phục nháp về dữ liệu gốc
  const handleReset = () => {
    setDraftPermissions(JSON.parse(JSON.stringify(originalPermissions)));
    setFeedback({ ok: true, msg: t('permissions.feedback.resetChanges') });
    alert?.info?.(t('permissions.feedback.resetChangesToast'), t('common.confirmModal.cancel'));
  };

  // Lưu tất cả thay đổi lên CSDL và phát sóng Real-time
  const handleSaveAll = async () => {
    if (pendingUpdates.length === 0) return;

    try {
      setSaving(true);
      setShowConfirmModal(false);

      const payloadToSend = pendingUpdates.map((u) => ({
        account_type: u.account_type,
        feature_id: u.feature_id,
        is_enabled: u.is_enabled,
        limit_value: u.limit_value,
      }));

      await adminApi.updatePermissions(payloadToSend);
      setOriginalPermissions(JSON.parse(JSON.stringify(draftPermissions)));

      const successMsg = t('permissions.feedback.saveSuccess', { count: pendingUpdates.length });
      setFeedback({ ok: true, msg: successMsg });
      alert?.success?.(successMsg, t('permissions.feedback.saveSuccessTitle'));
    } catch (err) {
      console.error('Lỗi lưu phân quyền:', err);
      const errMsg = err?.response?.data?.message || err?.message || t('permissions.feedback.saveError');
      setFeedback({ ok: false, msg: errMsg });
      alert?.error?.(errMsg, t('permissions.feedback.saveErrorTitle'));
    } finally {
      setSaving(false);
    }
  };

  // Lọc tính năng theo từ khóa tìm kiếm và nhóm
  const filteredFeatures = useMemo(() => {
    return features.filter((f) => {
      const q = search.trim().toLowerCase();
      const matchSearch =
        !q ||
        f.name?.toLowerCase().includes(q) ||
        f.id?.toLowerCase().includes(q) ||
        f.description?.toLowerCase().includes(q);

      const matchGroup = selectedGroup === 'ALL' || f.category_group === selectedGroup;
      return matchSearch && matchGroup;
    });
  }, [features, search, selectedGroup]);

  // Gom nhóm danh sách đã lọc
  const groupedFeatures = useMemo(() => {
    const map = {};
    for (const f of filteredFeatures) {
      const g = f.category_group || 'Khác';
      if (!map[g]) map[g] = [];
      map[g].push(f);
    }
    return map;
  }, [filteredFeatures]);

  return (
    <div className="max-w-[1440px] mx-auto w-full p-4 md:p-6 space-y-6 bg-surface-bright min-h-full">
      {/* ======================================================== */}
      {/* 1. PAGE HEADER & TOP TOOLBAR (CHUẨN AIOPS) */}
      {/* ======================================================== */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-outline-variant pb-4">
        <div>
          <h1 className="font-display-md text-display-md font-bold text-on-surface m-0 tracking-tight flex items-center gap-2.5">
            <span className="material-symbols-outlined text-primary text-[32px]">admin_panel_settings</span>
            {t('permissions.title')}
          </h1>
          <p className="font-body-md text-on-surface-variant mt-1">
            {t('permissions.subtitle')}
          </p>
        </div>

        {/* Action Buttons Toolbar */}
        <div className="flex items-center gap-2.5 flex-wrap">
          <button
            type="button"
            onClick={fetchPermissions}
            disabled={loading || saving}
            className="px-3.5 py-2 bg-white hover:bg-gray-50 border border-outline-variant text-on-surface text-xs font-semibold rounded-xl shadow-2xs transition-all cursor-pointer flex items-center gap-1.5 disabled:opacity-50"
            title={t('permissions.refreshTitle')}
          >
            <span className={`material-symbols-outlined text-[16px] ${loading ? 'animate-spin' : ''}`}>refresh</span>
            <span>{t('permissions.refreshBtn')}</span>
          </button>

          {pendingUpdates.length > 0 && (
            <button
              type="button"
              onClick={handleReset}
              disabled={saving}
              className="px-3.5 py-2 bg-white hover:bg-red-50 border border-red-200 text-red-600 text-xs font-semibold rounded-xl shadow-2xs transition-all cursor-pointer flex items-center gap-1.5 disabled:opacity-50"
              title={t('permissions.resetTitle')}
            >
              <span className="material-symbols-outlined text-[16px]">undo</span>
              <span>{t('permissions.resetBtn')} ({pendingUpdates.length})</span>
            </button>
          )}

          <button
            type="button"
            onClick={() => setShowConfirmModal(true)}
            disabled={pendingUpdates.length === 0 || saving}
            className={`px-4 py-2 text-xs font-bold rounded-xl shadow-xs transition-all cursor-pointer flex items-center gap-1.5 ${
              pendingUpdates.length > 0
                ? 'bg-primary hover:bg-primary/90 text-white animate-pulse'
                : 'bg-slate-200 text-slate-400 cursor-not-allowed opacity-60'
            }`}
            title={t('permissions.saveTitle')}
          >
            <span className={`material-symbols-outlined text-[16px] ${saving ? 'animate-spin' : ''}`}>
              {saving ? 'sync' : 'save'}
            </span>
            <span>{t('permissions.saveBtn')} {pendingUpdates.length > 0 ? `(${pendingUpdates.length})` : ''}</span>
          </button>
        </div>
      </div>

      {/* Thông báo phản hồi Toast Feedback (nếu có) */}
      {feedback && (
        <div
          className={`rounded-xl px-4 py-3 text-xs flex items-center justify-between gap-2 border font-medium transition-all ${
            feedback.ok
              ? 'bg-emerald-50 text-emerald-800 border-emerald-300'
              : 'bg-red-50 text-red-800 border-red-300'
          }`}
        >
          <div className="flex items-center gap-2">
            <span className="material-symbols-outlined text-[18px]">
              {feedback.ok ? 'verified' : 'error'}
            </span>
            <span>{feedback.msg}</span>
          </div>
          <button
            type="button"
            onClick={() => setFeedback(null)}
            className="text-gray-400 hover:text-gray-600 cursor-pointer"
          >
            <span className="material-symbols-outlined text-[16px]">close</span>
          </button>
        </div>
      )}

      {/* ======================================================== */}
      {/* 2. THẺ TÌNH TRẠNG HỆ THỐNG & REAL-TIME BANNER (CHUẨN AIOPS) */}
      {/* ======================================================== */}
      <div className="rounded-2xl border border-emerald-300 bg-emerald-50/80 text-emerald-950 p-4.5 transition-all shadow-xs">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-3.5">
          <div className="flex items-center gap-3.5">
            <div className="w-10 h-10 rounded-xl bg-emerald-600 text-white flex items-center justify-center flex-shrink-0 shadow-2xs">
              <span className="material-symbols-outlined text-[24px]">sync_alt</span>
            </div>

            <div>
              <div className="flex items-center gap-2 flex-wrap">
                <h2 className="text-sm font-bold m-0 tracking-tight">{t('permissions.banner.title')}</h2>
                <span className="px-3 py-1 rounded-full text-xs font-bold tracking-wide flex items-center gap-1.5 shadow-2xs border bg-emerald-100 text-emerald-800 border-emerald-300">
                  <span className="w-2 h-2 rounded-full bg-emerald-500 animate-ping" />
                  <span>{t('permissions.banner.status')}</span>
                </span>
              </div>
              <p className="text-xs opacity-90 mt-1 m-0">
                {t('permissions.banner.desc')}
              </p>
            </div>
          </div>

          {/* Quick Badges bên phải */}
          <div className="flex items-center gap-2 self-start md:self-center flex-wrap">
            <div className="flex items-center gap-1.5 px-3 py-1.5 bg-white/90 border border-outline-variant/60 rounded-xl text-[11px] font-medium text-slate-700 shadow-2xs">
              <span className="text-slate-400">{t('permissions.banner.scaleLabel')}</span>
              <b className="text-primary">{t('permissions.banner.scaleValue', { count: features.length })}</b>
            </div>
            <div className="flex items-center gap-1.5 px-3 py-1.5 bg-white/90 border border-outline-variant/60 rounded-xl text-[11px] font-medium text-slate-700 shadow-2xs">
              <span className="text-slate-400">{t('permissions.banner.tierLabel')}</span>
              <b className="text-purple-700">{t('permissions.banner.tierValue')}</b>
            </div>
            <div className="flex items-center gap-1.5 px-3 py-1.5 bg-white/90 border border-outline-variant/60 rounded-xl text-[11px] font-medium text-slate-700 shadow-2xs">
              <span className="text-slate-400">{t('permissions.banner.pendingLabel')}</span>
              <b className={pendingUpdates.length > 0 ? 'text-amber-600 font-bold' : 'text-emerald-700'}>
                {t('permissions.banner.pendingCount', { count: pendingUpdates.length })}
              </b>
            </div>
          </div>
        </div>
      </div>

      {/* ======================================================== */}
      {/* 3. KHỐI THỐNG KÊ TỔNG QUAN (4 METRIC BENTO CARDS CHUẨN AIOPS) */}
      {/* ======================================================== */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Thẻ 1: Tổng số tính năng */}
        <div className="bg-white rounded-2xl border border-outline-variant p-4.5 shadow-sm flex items-center justify-between">
          <div>
            <div className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">{t('permissions.stats.total')}</div>
            <div className="text-2xl font-bold text-on-surface font-mono mt-1">{stats.total}</div>
            <div className="text-[11px] text-slate-500 mt-1 flex items-center gap-1">
              <span className="text-blue-600 font-semibold">{t('permissions.stats.groupsCount', { count: groups.length })}</span>
            </div>
          </div>
          <div className="w-12 h-12 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
            <span className="material-symbols-outlined text-[28px]">featured_play_list</span>
          </div>
        </div>

        {/* Thẻ 2: Nhóm Hạn Mức (LIMIT) */}
        <div className="bg-white rounded-2xl border border-outline-variant p-4.5 shadow-sm flex items-center justify-between">
          <div>
            <div className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">{t('permissions.stats.limitCount')}</div>
            <div className="text-2xl font-bold text-purple-700 font-mono mt-1">{stats.limitCount}</div>
            <div className="text-[11px] text-slate-500 mt-1 flex items-center gap-1">
              {t('permissions.stats.limitDesc')}
            </div>
          </div>
          <div className="w-12 h-12 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center">
            <span className="material-symbols-outlined text-[28px]">tune</span>
          </div>
        </div>

        {/* Thẻ 3: Nhóm Bật/Tắt (TOGGLE) */}
        <div className="bg-white rounded-2xl border border-outline-variant p-4.5 shadow-sm flex items-center justify-between">
          <div>
            <div className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">{t('permissions.stats.toggleCount')}</div>
            <div className="text-2xl font-bold text-emerald-700 font-mono mt-1">{stats.toggleCount}</div>
            <div className="text-[11px] text-slate-500 mt-1 flex items-center gap-1">
              {t('permissions.stats.toggleDesc')}
            </div>
          </div>
          <div className="w-12 h-12 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
            <span className="material-symbols-outlined text-[28px]">toggle_on</span>
          </div>
        </div>

        {/* Thẻ 4: Trạng thái Thay Đổi Chưa Lưu */}
        <div
          className={`rounded-2xl border p-4.5 shadow-sm flex items-center justify-between transition-all ${
            pendingUpdates.length > 0 ? 'bg-amber-50/70 border-amber-300' : 'bg-white border-outline-variant'
          }`}
        >
          <div>
            <div className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">{t('permissions.stats.pendingCount')}</div>
            <div
              className={`text-2xl font-bold font-mono mt-1 ${
                pendingUpdates.length > 0 ? 'text-amber-700' : 'text-slate-700'
              }`}
            >
              {pendingUpdates.length}
            </div>
            <div className="text-[11px] text-slate-500 mt-1">
              {pendingUpdates.length > 0 ? t('permissions.stats.needSave') : t('permissions.stats.synced')}
            </div>
          </div>
          <div
            className={`w-12 h-12 rounded-xl flex items-center justify-center ${
              pendingUpdates.length > 0 ? 'bg-amber-200/80 text-amber-800' : 'bg-slate-100 text-slate-500'
            }`}
          >
            <span className="material-symbols-outlined text-[28px]">
              {pendingUpdates.length > 0 ? 'pending_actions' : 'check_circle'}
            </span>
          </div>
        </div>
      </div>

      {/* ======================================================== */}
      {/* 4. THANH ĐIỀU KHIỂN & BỘ LỌC TABS NHANH (CHUẨN AIOPS) */}
      {/* ======================================================== */}
      <div className="bg-white rounded-2xl border border-outline-variant p-4 shadow-sm space-y-3.5">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-3">
          {/* Tabs Pill Lọc theo Nhóm */}
          <div className="flex items-center gap-1.5 flex-wrap">
            <button
              type="button"
              onClick={() => setSelectedGroup('ALL')}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer border flex items-center gap-1.5 ${
                selectedGroup === 'ALL'
                  ? 'bg-primary text-white border-primary shadow-xs'
                  : 'bg-slate-50 text-slate-700 border-outline-variant hover:bg-slate-100'
              }`}
            >
              <span className="material-symbols-outlined text-[16px]">apps</span>
              <span>{t('permissions.tabs.all', { count: features.length })}</span>
            </button>

            {groups.map((grp) => {
              const cfg = getGroupConfig(grp, t);
              const countInGroup = features.filter((f) => f.category_group === grp).length;
              return (
                <button
                  key={grp}
                  type="button"
                  onClick={() => setSelectedGroup(grp)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer border flex items-center gap-1.5 ${
                    selectedGroup === grp
                      ? 'bg-primary text-white border-primary shadow-xs'
                      : 'bg-slate-50 text-slate-700 border-outline-variant hover:bg-slate-100'
                  }`}
                >
                  <span className="material-symbols-outlined text-[16px]">{cfg.icon}</span>
                  <span>
                    {cfg.name} ({countInGroup})
                  </span>
                </button>
              );
            })}
          </div>

          {/* Quick Presets mẫu */}
          <div className="flex items-center gap-2 self-start lg:self-center flex-wrap">
            <button
              type="button"
              onClick={handleApplyDefaultPreset}
              className="px-3 py-1.5 bg-blue-50 hover:bg-blue-100 border border-blue-200 text-blue-700 text-xs font-bold rounded-xl transition-all cursor-pointer flex items-center gap-1"
              title={t('permissions.presets.defaultTitle')}
            >
              <span className="material-symbols-outlined text-[15px]">electric_bolt</span>
              <span>{t('permissions.presets.default')}</span>
            </button>
            <button
              type="button"
              onClick={handleUnlockAllPremium}
              className="px-3 py-1.5 bg-amber-50 hover:bg-amber-100 border border-amber-200 text-amber-800 text-xs font-bold rounded-xl transition-all cursor-pointer flex items-center gap-1"
              title={t('permissions.presets.unlockPremiumTitle')}
            >
              <span className="material-symbols-outlined text-[15px]">stars</span>
              <span>{t('permissions.presets.unlockPremium')}</span>
            </button>
          </div>
        </div>

        {/* Ô Tìm Kiếm */}
        <div className="relative">
          <span className="material-symbols-outlined absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400 text-[18px]">
            search
          </span>
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t('permissions.searchPlaceholder')}
            className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-outline-variant rounded-xl text-xs font-medium text-on-surface placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-primary focus:bg-white transition"
          />
          {search && (
            <button
              type="button"
              onClick={() => setSearch('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 cursor-pointer"
            >
              <span className="material-symbols-outlined text-[16px]">cancel</span>
            </button>
          )}
        </div>
      </div>

      {/* ======================================================== */}
      {/* 5. DANH SÁCH MA TRẬN TÍNH NĂNG (FEATURE MATRIX CARDS) */}
      {/* ======================================================== */}
      {loading ? (
        <div className="bg-white rounded-2xl border border-outline-variant p-12 text-center shadow-sm">
          <div className="inline-block w-10 h-10 border-4 border-primary border-t-transparent rounded-full animate-spin mb-3" />
          <p className="text-xs font-medium text-slate-500">{t('permissions.matrix.loading')}</p>
        </div>
      ) : Object.keys(groupedFeatures).length === 0 ? (
        <div className="bg-white rounded-2xl border border-outline-variant p-12 text-center shadow-sm space-y-2">
          <span className="material-symbols-outlined text-5xl text-slate-300">search_off</span>
          <h3 className="text-sm font-bold text-on-surface">{t('permissions.matrix.emptyTitle')}</h3>
          <p className="text-xs text-slate-500">{t('permissions.matrix.emptySubtitle')}</p>
        </div>
      ) : (
        <div className="space-y-6">
          {Object.entries(groupedFeatures).map(([groupName, groupItems]) => {
            const grpCfg = getGroupConfig(groupName, t);

            return (
              <div
                key={groupName}
                className="bg-white rounded-2xl border border-outline-variant shadow-sm overflow-hidden"
              >
                {/* Header của Nhóm */}
                <div className="px-5 py-3.5 bg-slate-50/80 border-b border-outline-variant flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                  <div className="flex items-center gap-3">
                    <div className={`w-9 h-9 rounded-xl border flex items-center justify-center ${grpCfg.color}`}>
                      <span className="material-symbols-outlined text-[20px]">{grpCfg.icon}</span>
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <h2 className="text-sm font-bold text-on-surface uppercase tracking-wider">{grpCfg.name}</h2>
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${grpCfg.badgeColor}`}>
                          {groupItems.length} {t('permissions.banner.scaleValue', { count: groupItems.length })}
                        </span>
                      </div>
                      <p className="text-[11px] text-slate-500 mt-0.5">{grpCfg.desc}</p>
                    </div>
                  </div>

                  {/* Header cột (trên màn hình lớn) */}
                  <div className="hidden lg:flex items-center gap-6 text-[11px] font-bold text-slate-500 uppercase tracking-wider pr-4">
                    <span className="w-56 text-center">{t('permissions.matrix.colBasic')}</span>
                    <span className="w-56 text-center text-amber-700">{t('permissions.matrix.colPremium')}</span>
                    <span className="w-20 text-center">{t('permissions.matrix.colStatus')}</span>
                  </div>
                </div>

                {/* Danh sách các tính năng trong nhóm */}
                <div className="divide-y divide-outline-variant/60">
                  {groupItems.map((feature) => {
                    const icon = FEATURE_ICONS[feature.id] || 'tune';
                    const isLimitType = feature.type === 'LIMIT';

                    // Bản nháp Basic & Premium
                    const basicDraft = draftPermissions.Basic?.[feature.id] || {
                      is_enabled: true,
                      limit_value: isLimitType ? 3 : null,
                    };
                    const basicIsUnlimited = basicDraft.limit_value === null;

                    const premiumDraft = draftPermissions.Premium?.[feature.id] || {
                      is_enabled: true,
                      limit_value: null,
                    };
                    const premiumIsUnlimited = premiumDraft.limit_value === null;

                    // Kiểm tra trạng thái đã thay đổi
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

                    const isRowDirty = isBasicDirty || isPremiumDirty;

                    return (
                      <div
                        key={feature.id}
                        className={`p-4 lg:px-5 lg:py-4 transition-colors flex flex-col lg:flex-row lg:items-center justify-between gap-4 ${
                          isRowDirty ? 'bg-amber-50/40 hover:bg-amber-50/70' : 'hover:bg-slate-50/80'
                        }`}
                      >
                        {/* 1. Thông tin tính năng */}
                        <div className="flex items-start gap-3.5 flex-1 min-w-[280px]">
                          <div
                            className={`w-10 h-10 rounded-xl border flex items-center justify-center flex-shrink-0 mt-0.5 ${grpCfg.color}`}
                          >
                            <span className="material-symbols-outlined text-[22px]">{icon}</span>
                          </div>

                          <div className="space-y-1">
                            <div className="flex items-center gap-2 flex-wrap">
                              <span className="text-xs font-bold text-on-surface">{feature.name}</span>
                              <code className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 border border-slate-200">
                                {feature.id}
                              </code>
                              {isLimitType ? (
                                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-blue-50 text-blue-700 border border-blue-200">
                                  {t('permissions.matrix.limitBadge')}
                                </span>
                              ) : (
                                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-purple-50 text-purple-700 border border-purple-200">
                                  {t('permissions.matrix.toggleBadge')}
                                </span>
                              )}
                            </div>
                            <p className="text-[11px] text-slate-500 m-0 leading-relaxed">{feature.description}</p>
                          </div>
                        </div>

                        {/* 2. Cấu hình cho Gói Basic & Gói Premium */}
                        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-4 lg:gap-6">
                          {/* ── CỘT BASIC ── */}
                          <div className="w-full sm:w-56 bg-slate-50/80 p-3 rounded-xl border border-slate-200/80 flex flex-col justify-center">
                            <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1.5 flex items-center justify-between">
                              <span>{t('permissions.matrix.colBasic')}</span>
                              {isBasicDirty && (
                                <span className="text-amber-600 font-bold flex items-center gap-0.5">
                                  <span className="w-1.5 h-1.5 rounded-full bg-amber-500 animate-ping" />
                                  {t('permissions.matrix.dirty')}
                                </span>
                              )}
                            </div>

                            {isLimitType ? (
                              <div className="space-y-2">
                                <div className="flex items-center gap-2">
                                  <input
                                    type="number"
                                    min="0"
                                    max="999"
                                    disabled={basicIsUnlimited}
                                    value={basicDraft.limit_value ?? ''}
                                    onChange={(e) => handleLimitChange('Basic', feature.id, e.target.value)}
                                    placeholder={basicIsUnlimited ? t('permissions.matrix.unlimitedShort') : '0'}
                                    className={`w-20 px-2.5 py-1 text-xs font-bold rounded-lg border text-center transition ${
                                      basicIsUnlimited
                                        ? 'bg-slate-200 text-slate-400 border-slate-300 cursor-not-allowed'
                                        : 'bg-white border-outline-variant text-on-surface focus:ring-2 focus:ring-primary'
                                    }`}
                                  />
                                  <span className="text-[11px] text-slate-600 font-medium">{t('permissions.matrix.maxQuantity')}</span>
                                </div>

                                <div className="flex items-center justify-between pt-0.5">
                                  {/* Quick preset pills */}
                                  <div className="flex items-center gap-1">
                                    {DEFAULT_LIMIT_PRESETS.map((p) => (
                                      <button
                                        key={p}
                                        type="button"
                                        disabled={basicIsUnlimited}
                                        onClick={() => handleLimitChange('Basic', feature.id, p)}
                                        className={`px-1.5 py-0.5 text-[10px] font-bold rounded border cursor-pointer ${
                                          basicDraft.limit_value === p
                                            ? 'bg-blue-600 text-white border-blue-600'
                                            : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-100 disabled:opacity-40'
                                        }`}
                                      >
                                        {p}
                                      </button>
                                    ))}
                                  </div>

                                  <label className="flex items-center gap-1.5 cursor-pointer text-[11px] font-semibold text-slate-700">
                                    <input
                                      type="checkbox"
                                      checked={basicIsUnlimited}
                                      onChange={(e) => handleUnlimitedToggle('Basic', feature.id, e.target.checked)}
                                      className="w-3.5 h-3.5 rounded text-primary focus:ring-primary cursor-pointer"
                                    />
                                    <span>{t('permissions.matrix.unlimited')}</span>
                                  </label>
                                </div>
                              </div>
                            ) : (
                              <div className="flex items-center justify-between py-1">
                                <span
                                  className={`text-xs font-bold ${
                                    basicDraft.is_enabled ? 'text-emerald-700' : 'text-slate-400'
                                  }`}
                                >
                                  {basicDraft.is_enabled ? t('permissions.matrix.enabled') : t('permissions.matrix.locked')}
                                </span>

                                <label className="relative inline-flex items-center cursor-pointer">
                                  <input
                                    type="checkbox"
                                    checked={Boolean(basicDraft.is_enabled)}
                                    onChange={(e) => handleToggleChange('Basic', feature.id, e.target.checked)}
                                    className="sr-only peer"
                                  />
                                  <div className="w-11 h-6 bg-slate-300 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-600" />
                                </label>
                              </div>
                            )}
                          </div>

                          {/* ── CỘT PREMIUM ── */}
                          <div className="w-full sm:w-56 bg-amber-50/40 p-3 rounded-xl border border-amber-200/80 flex flex-col justify-center">
                            <div className="text-[10px] font-bold text-amber-800 uppercase tracking-wider mb-1.5 flex items-center justify-between">
                              <span className="flex items-center gap-1">
                                <span className="material-symbols-outlined text-[12px] text-amber-600">stars</span>
                                {t('permissions.matrix.colPremium')}
                              </span>
                              {isPremiumDirty && (
                                <span className="text-amber-700 font-bold flex items-center gap-0.5">
                                  <span className="w-1.5 h-1.5 rounded-full bg-amber-500 animate-ping" />
                                  {t('permissions.matrix.dirty')}
                                </span>
                              )}
                            </div>

                            {isLimitType ? (
                              <div className="space-y-2">
                                <div className="flex items-center gap-2">
                                  <input
                                    type="number"
                                    min="0"
                                    max="999"
                                    disabled={premiumIsUnlimited}
                                    value={premiumDraft.limit_value ?? ''}
                                    onChange={(e) => handleLimitChange('Premium', feature.id, e.target.value)}
                                    placeholder={premiumIsUnlimited ? t('permissions.matrix.unlimited') : '0'}
                                    className={`w-20 px-2.5 py-1 text-xs font-bold rounded-lg border text-center transition ${
                                      premiumIsUnlimited
                                        ? 'bg-amber-100/50 text-amber-800 border-amber-300 cursor-not-allowed'
                                        : 'bg-white border-amber-300 text-on-surface focus:ring-2 focus:ring-amber-500'
                                    }`}
                                  />
                                  <span className="text-[11px] text-amber-900 font-medium">{t('permissions.matrix.maxQuantity')}</span>
                                </div>

                                <div className="flex items-center justify-between pt-0.5">
                                  <div className="flex items-center gap-1">
                                    {DEFAULT_LIMIT_PRESETS.map((p) => (
                                      <button
                                        key={p}
                                        type="button"
                                        disabled={premiumIsUnlimited}
                                        onClick={() => handleLimitChange('Premium', feature.id, p)}
                                        className={`px-1.5 py-0.5 text-[10px] font-bold rounded border cursor-pointer ${
                                          premiumDraft.limit_value === p
                                            ? 'bg-amber-600 text-white border-amber-600'
                                            : 'bg-white text-slate-600 border-amber-200 hover:bg-amber-100 disabled:opacity-40'
                                        }`}
                                      >
                                        {p}
                                      </button>
                                    ))}
                                  </div>

                                  <label className="flex items-center gap-1.5 cursor-pointer text-[11px] font-semibold text-amber-950">
                                    <input
                                      type="checkbox"
                                      checked={premiumIsUnlimited}
                                      onChange={(e) => handleUnlimitedToggle('Premium', feature.id, e.target.checked)}
                                      className="w-3.5 h-3.5 rounded text-amber-600 focus:ring-amber-500 cursor-pointer"
                                    />
                                    <span>{t('permissions.matrix.unlimited')}</span>
                                  </label>
                                </div>
                              </div>
                            ) : (
                              <div className="flex items-center justify-between py-1">
                                <span
                                  className={`text-xs font-bold ${
                                    premiumDraft.is_enabled ? 'text-amber-800' : 'text-slate-400'
                                  }`}
                                >
                                  {premiumDraft.is_enabled ? t('permissions.matrix.enabled') : t('permissions.matrix.locked')}
                                </span>

                                <label className="relative inline-flex items-center cursor-pointer">
                                  <input
                                    type="checkbox"
                                    checked={Boolean(premiumDraft.is_enabled)}
                                    onChange={(e) => handleToggleChange('Premium', feature.id, e.target.checked)}
                                    className="sr-only peer"
                                  />
                                  <div className="w-11 h-6 bg-slate-300 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-amber-600" />
                                </label>
                              </div>
                            )}
                          </div>

                          {/* ── CỘT TRẠNG THÁI BADGE ── */}
                          <div className="w-20 text-center flex-shrink-0 self-center">
                            {isRowDirty ? (
                              <span className="px-2 py-1 rounded-full text-[10px] font-bold bg-amber-100 text-amber-800 border border-amber-300 shadow-2xs whitespace-nowrap animate-pulse">
                                {t('permissions.matrix.dirty')}
                              </span>
                            ) : (
                              <span className="px-2 py-1 rounded-full text-[10px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200 whitespace-nowrap">
                                {t('permissions.matrix.saved')}
                              </span>
                            )}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* ======================================================== */}
      {/* 6. CONFIRM MODAL (CHUẨN AIOPS XÁC NHẬN LƯU THAY ĐỔI) */}
      {/* ======================================================== */}
      {showConfirmModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs">
          <div className="bg-white rounded-2xl border border-outline-variant max-w-lg w-full p-6 shadow-xl space-y-4">
            <div className="flex items-center gap-3 border-b border-outline-variant pb-3">
              <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center flex-shrink-0">
                <span className="material-symbols-outlined text-[24px]">save</span>
              </div>
              <div>
                <h3 className="text-sm font-bold text-on-surface m-0">{t('permissions.modal.title')}</h3>
                <p className="text-xs text-slate-500 m-0">
                  {t('permissions.modal.subtitle', { count: pendingUpdates.length })}
                </p>
              </div>
            </div>

            {/* Danh sách tóm tắt các thay đổi */}
            <div className="max-h-60 overflow-y-auto space-y-2 pr-1 divide-y divide-slate-100">
              {pendingUpdates.map((u, idx) => (
                <div key={idx} className="pt-2 first:pt-0 flex items-center justify-between text-xs">
                  <div>
                    <span className="font-bold text-slate-800">{u.feature_name}</span>
                    <span className="text-slate-400 ml-1.5 font-mono text-[11px]">({u.account_type})</span>
                  </div>
                  <div className="font-mono font-semibold text-slate-700">
                    {u.type === 'LIMIT' ? (
                      <span>
                        {u.orig_limit_value ?? t('permissions.matrix.unlimitedShort')} ➔{' '}
                        <strong className="text-primary">{u.limit_value ?? t('permissions.matrix.unlimitedShort')}</strong>
                      </span>
                    ) : (
                      <span>
                        {u.orig_is_enabled ? t('permissions.matrix.enabled') : t('permissions.matrix.locked')} ➔{' '}
                        <strong className={u.is_enabled ? 'text-emerald-700' : 'text-red-600'}>
                          {u.is_enabled ? t('permissions.matrix.enabled') : t('permissions.matrix.locked')}
                        </strong>
                      </span>
                    )}
                  </div>
                </div>
              ))}
            </div>

            <div className="p-3 rounded-xl bg-blue-50 border border-blue-200 text-xs text-blue-900 flex items-start gap-2">
              <span className="material-symbols-outlined text-[16px] text-blue-600 mt-0.5">info</span>
              <span>
                {t('permissions.modal.notice')}
              </span>
            </div>

            <div className="flex items-center justify-end gap-2.5 pt-2 border-t border-outline-variant">
              <button
                type="button"
                onClick={() => setShowConfirmModal(false)}
                disabled={saving}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl transition cursor-pointer"
              >
                {t('permissions.modal.cancelBtn')}
              </button>
              <button
                type="button"
                onClick={handleSaveAll}
                disabled={saving}
                className="px-4 py-2 bg-primary hover:bg-primary/90 text-white text-xs font-bold rounded-xl transition shadow-xs flex items-center gap-1.5 cursor-pointer"
              >
                <span className={`material-symbols-outlined text-[16px] ${saving ? 'animate-spin' : ''}`}>
                  {saving ? 'sync' : 'check'}
                </span>
                <span>{saving ? t('permissions.modal.savingBtn') : t('permissions.modal.confirmBtn')}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default PermissionManagementPage;
