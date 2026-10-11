import React, { useState, useEffect } from 'react';
import { TRANSACTION_TYPE_LABELS } from '../../utils/constants';
import { normalizeCategoryName, normalizeVietnameseUnaccent } from '../../utils/string';
import adminApi from '../../api/admin.api';
import Pagination from '../../components/common/Pagination';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';

const CLASSIFY_MAP = { Thu: 'income', Chi: 'expense', 'Vay/no': 'debt', 'Vay/nợ': 'debt' };
const TYPE_TO_CLASSIFY = { income: 'Thu', expense: 'Chi', debt: 'Vay/no' };

const CategoryPage = () => {
  const alert = useAlertSafe();
  const { t } = useLanguageSafe();
  const [loading, setLoading] = useState(true);
  const [categories, setCategories] = useState([]);
  const [search, setSearch] = useState('');
  const [syncToast, setSyncToast] = useState(null);

  const [modals, setModals] = useState({
    add: false,
    edit: false,
    filter: false,
    deleteAlert: false,
    syncAlert: false,
  });
  const [editingCategory, setEditingCategory] = useState(null);
  const [categoryToDelete, setCategoryToDelete] = useState(null);
  const [processing, setProcessing] = useState({ isProcessing: false, text: '' });
  const [form, setForm] = useState({ name: '', isDefault: 'yes', type: 'expense', keyword: '' });
  const [filter, setFilter] = useState({ type: 'all', keyword: '' });

  // Pagination states
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  const searchNorm = normalizeVietnameseUnaccent(search);
  const filtered = categories.filter((c) => {
    const matchSearch =
      !searchNorm ||
      normalizeVietnameseUnaccent(c.name).includes(searchNorm) ||
      c.name.toLowerCase().includes(search.toLowerCase());
    const matchType = filter.type === 'all' || c.type === filter.type;
    const matchKeyword =
      !filter.keyword ||
      !filter.keyword.trim() ||
      (c.keyword && c.keyword.toLowerCase().includes(filter.keyword.trim().toLowerCase()));
    return matchSearch && matchType && matchKeyword;
  });

  const totalPages = Math.ceil(filtered.length / pageSize) || 1;
  const start = (currentPage - 1) * pageSize;
  const end = Math.min(start + pageSize, filtered.length);
  const pageData = filtered.slice(start, end);

  // Thống kê đếm cho Bento cards
  const stats = {
    total: categories.length,
    expense: categories.filter((c) => c.type === 'expense').length,
    income: categories.filter((c) => c.type === 'income').length,
    debt: categories.filter((c) => c.type === 'debt').length,
  };

  useEffect(() => {
    setCurrentPage(1);
  }, [search, filter]);

  const fetchCategories = async (filterOverride = filter) => {
    try {
      setLoading(true);
      // Luôn ép cứng is_default = true để bảo vệ dữ liệu người dùng
      const params = { is_default: true };
      if (filterOverride.type && filterOverride.type !== 'all') {
        params.classify = TYPE_TO_CLASSIFY[filterOverride.type];
      }
      if (filterOverride.keyword && filterOverride.keyword.trim()) {
        params.keyword = filterOverride.keyword.trim();
      }

      const res = await adminApi.getCategories(params);
      const mapped = (res.data || []).map((c) => {
        const isUserCat = c.is_user_category || c.is_default === false;
        return {
          id: c.id,
          name: isUserCat ? '***' : c.name,
          type: CLASSIFY_MAP[c.classify] || 'expense',
          classify: c.classify,
          isDefault: !isUserCat,
          isUserCategory: isUserCat,
          keyword: isUserCat ? '***' : c.keyword || '',
          created_by: isUserCat ? '***' : 'system',
          created_at: c.create_at,
        };
      });
      setCategories(mapped);
    } catch (err) {
      console.error('Lỗi tải danh mục:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCategories();
  }, []);

  const toggleModal = (modalName, isOpen) => {
    setModals((prev) => ({ ...prev, [modalName]: isOpen }));
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (processing.isProcessing) return;

    const trimmedName = form.name.trim();
    const normName = normalizeCategoryName(trimmedName);
    if (!normName) {
      const msg = t('categories.alerts.nameRequired');
      if (alert) alert.warning(msg);
      window.alert(msg);
      return;
    }

    // Chặn sửa danh mục người dùng (Bảo vệ quyền riêng tư người dùng)
    if (editingCategory && (editingCategory.isUserCategory || !editingCategory.isDefault)) {
      const msg = t('categories.alerts.privacyViolationEdit');
      if (alert) alert.error(msg);
      window.alert(msg);
      return;
    }

    // Pre-validation: Kiểm tra trùng tên danh mục hệ thống
    const dupDefault = categories.find(
      (c) =>
        c.isDefault &&
        c.name &&
        normalizeCategoryName(c.name) === normName &&
        (!editingCategory || c.id !== editingCategory.id)
    );
    if (dupDefault) {
      const msg = t('categories.alerts.duplicateName', { name: dupDefault.name });
      if (alert) alert.warning(msg, t('categories.alerts.duplicateTitle'));
      window.alert(msg);
      return;
    }

    const actionText = editingCategory ? t('categories.loading.updating') : t('categories.loading.creating');
    setProcessing({ isProcessing: true, text: actionText });

    try {
      const payload = {
        name: trimmedName,
        classify: TYPE_TO_CLASSIFY[form.type] || 'Chi',
        is_default: true,
        keyword: form.keyword ? form.keyword.trim() : null,
      };
      if (editingCategory) {
        await adminApi.updateCategory(editingCategory.id, payload);
        toggleModal('edit', false);
        setEditingCategory(null);
        if (alert) alert.success(t('categories.alerts.updateSuccess', { name: trimmedName }));
      } else {
        await adminApi.createCategory(payload);
        toggleModal('add', false);
        if (alert) alert.success(t('categories.alerts.createSuccess', { name: trimmedName }));
      }
      setForm({ name: '', isDefault: 'yes', type: 'expense', keyword: '' });
      await fetchCategories();
    } catch (err) {
      console.error('Lỗi lưu danh mục:', err);
      const errMsg = err.response?.data?.message || err.message || 'Lỗi lưu danh mục';
      if (alert) alert.error(errMsg, t('categories.alerts.saveErrorTitle'));
      window.alert(errMsg);
    } finally {
      setProcessing({ isProcessing: false, text: '' });
    }
  };

  const openDeleteModal = (cat) => {
    if (cat.isUserCategory || !cat.isDefault) {
      const msg = t('categories.alerts.privacyViolationDelete');
      if (alert) alert.error(msg, t('categories.alerts.privacyTitle'));
      window.alert(msg);
      return;
    }
    setCategoryToDelete(cat);
    toggleModal('deleteAlert', true);
  };

  const confirmDelete = async () => {
    if (!categoryToDelete || processing.isProcessing) return;
    if (categoryToDelete.isUserCategory || !categoryToDelete.isDefault) {
      const msg = t('categories.alerts.privacyViolationDelete');
      if (alert) alert.error(msg, t('categories.alerts.privacyTitle'));
      window.alert(msg);
      toggleModal('deleteAlert', false);
      setCategoryToDelete(null);
      return;
    }

    setProcessing({ isProcessing: true, text: t('categories.loading.deleting') });
    try {
      await adminApi.deleteCategory(categoryToDelete.id);
      const deletedName = categoryToDelete.name;
      toggleModal('deleteAlert', false);
      setCategoryToDelete(null);
      await fetchCategories();
      if (alert) alert.success(t('categories.alerts.deleteSuccess', { name: deletedName }));
    } catch (err) {
      console.error('Lỗi xóa danh mục:', err);
      const errMsg = err.response?.data?.message || err.message || 'Lỗi khi xóa danh mục hệ thống';
      if (alert) alert.error(errMsg, t('categories.alerts.deleteErrorTitle'));
      window.alert(errMsg);
    } finally {
      setProcessing({ isProcessing: false, text: '' });
    }
  };

  const openEditModal = (cat) => {
    if (cat.isUserCategory || !cat.isDefault) {
      const msg = t('categories.alerts.privacyViolationEdit');
      if (alert) alert.error(msg, t('categories.alerts.privacyTitle'));
      window.alert(msg);
      return;
    }
    setEditingCategory(cat);
    setForm({
      name: cat.name,
      isDefault: 'yes',
      type: cat.type,
      keyword: cat.keyword || '',
    });
    toggleModal('edit', true);
  };

  const startAdd = () => {
    setEditingCategory(null);
    setForm({ name: '', isDefault: 'yes', type: 'expense', keyword: '' });
    toggleModal('add', true);
  };

  const handleSyncConfirm = async () => {
    if (processing.isProcessing) return;
    toggleModal('syncAlert', false);
    setProcessing({ isProcessing: true, text: t('categories.loading.syncing') });
    try {
      await fetchCategories();
      const syncMsg = t('categories.alerts.syncSuccess');
      setSyncToast(syncMsg);
      if (alert) alert.success(syncMsg);
      setTimeout(() => setSyncToast(null), 3500);
    } catch (err) {
      console.error('Lỗi đồng bộ danh mục:', err);
      if (alert) alert.error(t('categories.alerts.syncError'), t('categories.alerts.syncErrorTitle'));
    } finally {
      setProcessing({ isProcessing: false, text: '' });
    }
  };

  const getTypeBadgeClass = (type) => {
    if (type === 'income') return 'bg-emerald-50 text-emerald-700 border border-emerald-200/80 shadow-xs';
    if (type === 'expense') return 'bg-rose-50 text-rose-700 border border-rose-200/80 shadow-xs';
    return 'bg-blue-50 text-blue-700 border border-blue-200/80 shadow-xs';
  };

  return (
    <>
      {/* Full-screen Loading Overlay */}
      {processing.isProcessing && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-xs z-[9999] flex flex-col items-center justify-center pointer-events-auto select-none animate-in fade-in duration-200">
          <div className="bg-white/95 backdrop-blur-md px-8 py-6 rounded-2xl shadow-2xl border border-outline-variant flex flex-col items-center gap-4 text-center max-w-xs mx-4">
            <span className="material-symbols-outlined animate-spin text-primary text-5xl">
              progress_activity
            </span>
            <div className="space-y-1">
              <h4 className="font-title-md font-bold text-on-surface text-base">
                {processing.text || t('common.processing')}
              </h4>
              <p className="font-body-sm text-on-surface-variant text-xs">{t('dashboard.loadingOverlay.wait')}</p>
            </div>
          </div>
        </div>
      )}

      <div className="bg-surface-bright relative p-4 md:p-6 min-h-full space-y-6">
        {/* Sync Toast Notification */}
        {syncToast && (
          <div className="bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-2xl p-4 flex items-center justify-between gap-4 animate-in fade-in duration-200 shadow-xs">
            <div className="flex items-center gap-3">
              <span className="material-symbols-outlined text-emerald-600">check_circle</span>
              <p className="text-xs font-semibold">{syncToast}</p>
            </div>
            <button
              className="text-emerald-700 hover:opacity-75 cursor-pointer text-xs"
              onClick={() => setSyncToast(null)}
            >
              ✕
            </button>
          </div>
        )}

        {/* Sync Confirmation Banner */}
        {modals.syncAlert && (
          <div className="bg-blue-50 border border-blue-200 rounded-2xl p-5 flex flex-col md:flex-row items-center justify-between gap-4 animate-in fade-in shadow-xs">
            <div className="flex items-center gap-3.5 text-on-surface">
              <div className="w-10 h-10 rounded-xl bg-blue-100 text-blue-700 flex items-center justify-center shrink-0">
                <span className="material-symbols-outlined text-2xl">sync</span>
              </div>
              <p className="text-xs md:text-sm font-semibold text-blue-900">
                {t('categories.syncModal.confirmText')}
              </p>
            </div>
            <div className="flex items-center gap-2.5 shrink-0">
              <button
                disabled={processing.isProcessing}
                className="px-4 py-2 bg-primary text-white rounded-xl text-xs font-semibold hover:bg-primary-tint transition-colors cursor-pointer disabled:opacity-50 flex items-center gap-1.5 shadow-xs"
                onClick={handleSyncConfirm}
              >
                {processing.isProcessing && (
                  <span className="material-symbols-outlined animate-spin text-sm">
                    progress_activity
                  </span>
                )}
                {t('categories.syncModal.confirmBtn')}
              </button>
              <button
                disabled={processing.isProcessing}
                className="px-4 py-2 bg-white border border-outline-variant text-on-surface rounded-xl text-xs font-semibold hover:bg-surface-container-low transition-colors cursor-pointer disabled:opacity-50"
                onClick={() => toggleModal('syncAlert', false)}
              >
                {t('categories.syncModal.cancelBtn')}
              </button>
            </div>
          </div>
        )}

        {/* Delete Confirmation Alert Banner */}
        {modals.deleteAlert && !categoryToDelete && (
          <div className="bg-rose-50 border border-rose-200 rounded-2xl p-4 flex flex-col md:flex-row items-center justify-between gap-4">
            <div className="flex items-center gap-3 text-on-surface">
              <span className="material-symbols-outlined text-rose-600">warning</span>
              <p className="font-body-lg text-sm text-rose-800">{t('categories.deleteModal.confirmText')}?</p>
            </div>
            <div className="flex items-center gap-2.5">
              <button
                disabled={processing.isProcessing}
                className="px-4 py-1.5 bg-rose-600 text-white rounded-xl text-xs font-semibold hover:bg-rose-700 transition-colors cursor-pointer disabled:opacity-50 flex items-center gap-1.5"
                onClick={confirmDelete}
              >
                {processing.isProcessing && (
                  <span className="material-symbols-outlined animate-spin text-sm">
                    progress_activity
                  </span>
                )}
                {t('categories.deleteModal.confirmBtn')}
              </button>
              <button
                disabled={processing.isProcessing}
                className="px-4 py-1.5 bg-white border border-outline-variant text-on-surface rounded-xl text-xs font-semibold hover:bg-surface-container-low transition-colors cursor-pointer disabled:opacity-50"
                onClick={() => {
                  setCategoryToDelete(null);
                  toggleModal('deleteAlert', false);
                }}
              >
                {t('categories.deleteModal.cancelBtn')}
              </button>
            </div>
          </div>
        )}

        {/* 1. Header Hero Bar chuẩn Enterprise */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-2">
          <div className="flex items-center gap-3.5">
            <div className="w-12 h-12 rounded-2xl bg-primary/10 border border-primary/20 flex items-center justify-center text-primary shadow-xs">
              <span className="material-symbols-outlined text-[28px]">category</span>
            </div>
            <div>
              <div className="flex items-center gap-2.5">
                <h2 className="font-headline-md text-xl md:text-2xl font-bold text-on-surface m-0 tracking-tight">
                  {t('categories.title')}
                </h2>
                <span className="px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-blue-100 text-blue-800 border border-blue-200 flex items-center gap-1">
                  <span className="w-1.5 h-1.5 rounded-full bg-blue-600"></span>
                  {t('categories.nlpBadge')}
                </span>
              </div>
              <p className="text-xs text-on-surface-variant mt-0.5">
                {t('categories.subtitle')}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2.5">
            <button
              className="px-3.5 py-2 bg-white border border-outline-variant rounded-xl text-xs font-semibold text-on-surface hover:bg-surface-container-low transition-all shadow-xs flex items-center gap-1.5 cursor-pointer"
              onClick={() => fetchCategories()}
              disabled={loading}
              title={t('categories.refreshTitle')}
            >
              <span className={`material-symbols-outlined text-[18px] ${loading ? 'animate-spin' : ''}`}>
                refresh
              </span>
              {t('categories.refresh')}
            </button>
            <button
              className="px-4 py-2 bg-primary hover:bg-primary-tint text-white rounded-xl text-xs font-semibold transition-all shadow-xs flex items-center gap-1.5 cursor-pointer"
              onClick={startAdd}
            >
              <span className="material-symbols-outlined text-[18px]">add</span>
              {t('categories.addCategory')}
            </button>
          </div>
        </div>

        {/* 2. Bento Stats KPI Cards */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div
            onClick={() => setFilter({ ...filter, type: 'all' })}
            className={`p-4 rounded-2xl border transition-all cursor-pointer ${
              filter.type === 'all'
                ? 'bg-primary/5 border-primary/40 ring-1 ring-primary/30 shadow-xs'
                : 'bg-white border-outline-variant hover:border-primary/30 hover:bg-surface-container-lowest'
            }`}
          >
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-semibold text-on-surface-variant">{t('categories.stats.total')}</span>
              <div className="w-8 h-8 rounded-xl bg-primary/10 text-primary flex items-center justify-center">
                <span className="material-symbols-outlined text-[18px]">category</span>
              </div>
            </div>
            <div className="text-2xl font-black text-on-surface tracking-tight font-tabular-nums">
              {stats.total}
            </div>
            <div className="text-[11px] text-on-surface-variant mt-1">{t('categories.stats.totalDesc')}</div>
          </div>

          <div
            onClick={() => setFilter({ ...filter, type: 'expense' })}
            className={`p-4 rounded-2xl border transition-all cursor-pointer ${
              filter.type === 'expense'
                ? 'bg-rose-50/70 border-rose-300 ring-1 ring-rose-300 shadow-xs'
                : 'bg-white border-outline-variant hover:border-rose-300 hover:bg-surface-container-lowest'
            }`}
          >
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-semibold text-rose-800">{t('categories.stats.expense')}</span>
              <div className="w-8 h-8 rounded-xl bg-rose-50 text-rose-600 flex items-center justify-center">
                <span className="material-symbols-outlined text-[18px]">trending_down</span>
              </div>
            </div>
            <div className="text-2xl font-black text-rose-900 tracking-tight font-tabular-nums">
              {stats.expense}
            </div>
            <div className="text-[11px] text-rose-700 mt-1">{t('categories.stats.expenseDesc')}</div>
          </div>

          <div
            onClick={() => setFilter({ ...filter, type: 'income' })}
            className={`p-4 rounded-2xl border transition-all cursor-pointer ${
              filter.type === 'income'
                ? 'bg-emerald-50/70 border-emerald-300 ring-1 ring-emerald-300 shadow-xs'
                : 'bg-white border-outline-variant hover:border-emerald-300 hover:bg-surface-container-lowest'
            }`}
          >
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-semibold text-emerald-800">{t('categories.stats.income')}</span>
              <div className="w-8 h-8 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center">
                <span className="material-symbols-outlined text-[18px]">trending_up</span>
              </div>
            </div>
            <div className="text-2xl font-black text-emerald-900 tracking-tight font-tabular-nums">
              {stats.income}
            </div>
            <div className="text-[11px] text-emerald-700 mt-1">{t('categories.stats.incomeDesc')}</div>
          </div>

          <div
            onClick={() => setFilter({ ...filter, type: 'debt' })}
            className={`p-4 rounded-2xl border transition-all cursor-pointer ${
              filter.type === 'debt'
                ? 'bg-blue-50/70 border-blue-300 ring-1 ring-blue-300 shadow-xs'
                : 'bg-white border-outline-variant hover:border-blue-300 hover:bg-surface-container-lowest'
            }`}
          >
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-semibold text-blue-800">{t('categories.stats.debt')}</span>
              <div className="w-8 h-8 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
                <span className="material-symbols-outlined text-[18px]">account_balance_wallet</span>
              </div>
            </div>
            <div className="text-2xl font-black text-blue-900 tracking-tight font-tabular-nums">
              {stats.debt}
            </div>
            <div className="text-[11px] text-blue-700 mt-1">{t('categories.stats.debtDesc')}</div>
          </div>
        </div>

        {/* 3. Filter Pill Tabs & Search Controls */}
        <div className="bg-white p-3.5 rounded-2xl border border-outline-variant shadow-xs flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3">
          {/* Quick Pill Tabs */}
          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 md:pb-0 scrollbar-none">
            {[
              { id: 'all', label: t('categories.tabs.all'), icon: 'list_alt', count: stats.total },
              { id: 'expense', label: t('categories.tabs.expense'), icon: 'trending_down', count: stats.expense },
              { id: 'income', label: t('categories.tabs.income'), icon: 'trending_up', count: stats.income },
              { id: 'debt', label: t('categories.tabs.debt'), icon: 'account_balance_wallet', count: stats.debt },
            ].map((tab) => {
              const isActive = filter.type === tab.id;
              return (
                <button
                  key={tab.id}
                  onClick={() => setFilter({ ...filter, type: tab.id })}
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
                placeholder={t('categories.searchPlaceholder')}
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
                filter.type !== 'all' || (filter.keyword && filter.keyword.trim())
                  ? 'border-primary bg-primary/10 text-primary'
                  : 'border-outline-variant bg-white text-on-surface hover:bg-surface-container-low'
              }`}
              onClick={() => toggleModal('filter', true)}
            >
              <span className="material-symbols-outlined text-[16px]">filter_alt</span>
              {t('categories.filterBtn')}
            </button>
          </div>
        </div>

        {/* 4. Main Category Table */}
        <div className="bg-white border border-outline-variant rounded-2xl overflow-hidden shadow-xs relative">
          {loading && (
            <div className="absolute inset-0 bg-white/70 backdrop-blur-2xs z-10 flex flex-col items-center justify-center gap-2">
              <span className="material-symbols-outlined animate-spin text-primary text-3xl">
                progress_activity
              </span>
              <span className="text-xs font-medium text-secondary">{t('categories.table.loading')}</span>
            </div>
          )}

          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse min-w-[750px]">
              <thead>
                <tr className="bg-surface-container-low/80 border-b border-outline-variant text-[11px] font-bold text-on-surface-variant uppercase tracking-wider">
                  <th className="px-5 py-3.5">{t('categories.table.colName')}</th>
                  <th className="px-5 py-3.5">{t('categories.table.colType')}</th>
                  <th className="px-5 py-3.5">{t('categories.table.colKeyword')}</th>
                  <th className="px-5 py-3.5 text-right">{t('categories.table.colActions')}</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-outline-variant/60 font-body-md text-xs text-on-surface">
                {pageData.length > 0 ? (
                  pageData.map((item) => {
                    return (
                      <tr
                        key={item.id}
                        className="hover:bg-surface-container-lowest/80 transition-colors group"
                      >
                        <td className="px-5 py-3.5">
                          <div className="flex items-center gap-3">
                            <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-primary/10 to-primary/20 text-primary flex items-center justify-center border border-primary/20 shadow-2xs shrink-0">
                              <span className="material-symbols-outlined text-[18px]">
                                {item.type === 'income'
                                  ? 'savings'
                                  : item.type === 'expense'
                                  ? 'shopping_bag'
                                  : 'credit_card'}
                              </span>
                            </div>
                            <div className="min-w-0">
                              {item.isUserCategory ? (
                                <div className="flex flex-col">
                                  <span className="font-bold text-rose-700 text-xs">***</span>
                                  <span className="text-[10px] text-rose-600 font-medium italic">
                                    {t('categories.table.anonymousUserCat')}
                                  </span>
                                </div>
                              ) : (
                                <>
                                  <span className="font-bold text-on-surface block text-xs">
                                    {item.name}
                                  </span>
                                  <span className="text-[10px] text-secondary">
                                    {t('categories.table.createdBySystem', { creator: (item.created_by === 'system' || item.created_by === 'Hệ thống') ? t('categories.createdBySystem') : item.created_by })}
                                  </span>
                                </>
                              )}
                            </div>
                          </div>
                        </td>
                        <td className="px-5 py-3.5">
                          <span
                            className={`inline-flex items-center px-2.5 py-1 rounded-full text-[11px] font-semibold ${getTypeBadgeClass(
                              item.type
                            )}`}
                          >
                            {t(`categories.tabs.${item.type}`) || TRANSACTION_TYPE_LABELS[item.type] || item.type}
                          </span>
                        </td>
                        <td className="px-5 py-3.5 max-w-[380px]">
                          {item.isUserCategory ? (
                            <span className="text-secondary italic text-xs font-mono">***</span>
                          ) : item.keyword ? (
                            <div
                              className="w-full bg-slate-50 border border-slate-200/80 rounded-xl px-2.5 py-1 text-[11px] text-slate-800 font-mono whitespace-nowrap overflow-x-auto keyword-scrollbar select-all shadow-2xs"
                              title={item.keyword}
                            >
                              {item.keyword}
                            </div>
                          ) : (
                            <span className="text-secondary/60 italic text-xs">{t('categories.table.noKeyword')}</span>
                          )}
                        </td>
                        <td className="px-5 py-3.5 text-right">
                          {item.isUserCategory ? (
                            <span className="text-xs text-rose-700 font-semibold italic bg-rose-50 border border-rose-200 px-2.5 py-1 rounded-xl">
                              {t('categories.table.forbiddenEditDelete')}
                            </span>
                          ) : (
                            <div className="flex items-center justify-end gap-1">
                              <button
                                className="w-7 h-7 rounded-lg text-secondary hover:text-primary hover:bg-primary/10 transition-colors flex items-center justify-center cursor-pointer"
                                onClick={() => openEditModal(item)}
                                title={t('categories.table.editTitle')}
                              >
                                <span className="material-symbols-outlined text-[18px]">edit</span>
                              </button>
                              <button
                                className="w-7 h-7 rounded-lg text-secondary hover:text-rose-600 hover:bg-rose-50 transition-colors flex items-center justify-center cursor-pointer"
                                onClick={() => openDeleteModal(item)}
                                title={t('categories.table.deleteTitle')}
                              >
                                <span className="material-symbols-outlined text-[18px]">delete</span>
                              </button>
                            </div>
                          )}
                        </td>
                      </tr>
                    );
                  })
                ) : (
                  <tr>
                    <td colSpan="4" className="px-6 py-12 text-center text-on-surface-variant">
                      <div className="flex flex-col items-center justify-center gap-2">
                        <span className="material-symbols-outlined text-4xl text-secondary/60">
                          folder_off
                        </span>
                        <p className="font-semibold text-sm text-on-surface">
                          {t('categories.table.emptyTitle')}
                        </p>
                        <p className="text-xs text-secondary">
                          {t('categories.table.emptySubtitle')}
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
            total={filtered.length}
            pageSizeOptions={[5, 10, 20, 50]}
            onPageChange={(page) => setCurrentPage(page)}
            onPageSizeChange={(newSize) => {
              setPageSize(newSize);
              setCurrentPage(1);
            }}
            itemLabel={t('categories.table.itemLabel')}
          />

          <div className="px-6 py-3.5 flex justify-end border-t border-outline-variant bg-surface-container-lowest">
            <button
              className="px-4 py-2 bg-primary text-white rounded-xl text-xs font-semibold hover:bg-primary-tint transition-colors flex items-center gap-1.5 shadow-xs cursor-pointer"
              onClick={() => toggleModal('syncAlert', true)}
            >
              <span className="material-symbols-outlined text-[18px]">sync</span>
              {t('categories.table.syncBtn')}
            </button>
          </div>
        </div>
      </div>

      {/* Add / Edit Modal */}
      {(modals.add || modals.edit) && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-2xs flex items-center justify-center z-50 p-4 animate-in fade-in duration-200">
          <div className="bg-white rounded-2xl w-full max-w-lg shadow-2xl overflow-hidden border border-outline-variant animate-in zoom-in-95 duration-200">
            <div className="px-6 py-4 border-b border-outline-variant flex items-center justify-between bg-surface-container-lowest">
              <div className="flex items-center gap-2 text-primary">
                <span className="material-symbols-outlined text-2xl">
                  {modals.edit ? 'edit_note' : 'add_circle'}
                </span>
                <h3 className="font-bold text-on-surface text-base m-0">
                  {modals.edit ? t('categories.modal.editTitle') : t('categories.modal.addTitle')}
                </h3>
              </div>
              <button
                disabled={processing.isProcessing}
                className="text-secondary hover:text-on-surface cursor-pointer p-1 rounded-full hover:bg-surface-container-low transition-colors disabled:opacity-50"
                onClick={() => toggleModal(modals.edit ? 'edit' : 'add', false)}
              >
                <span className="material-symbols-outlined text-[20px]">close</span>
              </button>
            </div>
            <form onSubmit={handleSave}>
              <div className="p-6 space-y-4">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-on-surface mb-1.5">
                    {t('categories.modal.nameLabel')} <span className="text-rose-600">*</span>
                  </label>
                  <input
                    required
                    disabled={processing.isProcessing}
                    value={form.name}
                    onChange={(e) => setForm({ ...form, name: e.target.value })}
                    className="w-full px-3.5 py-2 border border-outline-variant rounded-xl focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/20 text-xs font-medium text-on-surface h-[42px] disabled:bg-surface-container-low disabled:cursor-not-allowed"
                    placeholder={t('categories.modal.namePlaceholder')}
                    type="text"
                    autoFocus
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-on-surface mb-1.5">
                    {t('categories.modal.keywordLabel')}
                    <span className="text-[11px] text-secondary font-normal ml-1">{t('categories.modal.keywordOptional')}</span>
                  </label>
                  <textarea
                    disabled={processing.isProcessing}
                    value={form.keyword}
                    onChange={(e) => setForm({ ...form, keyword: e.target.value })}
                    className="w-full px-3.5 py-2.5 border border-outline-variant rounded-xl focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/20 text-xs font-mono text-on-surface min-h-[72px] resize-none disabled:bg-surface-container-low disabled:cursor-not-allowed"
                    placeholder={t('categories.modal.keywordPlaceholder')}
                    rows={2}
                  />
                  <p className="text-[11px] text-secondary mt-1">
                    {t('categories.modal.keywordHint')}
                  </p>
                </div>
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-on-surface mb-1.5">
                    {t('categories.modal.typeLabel')}
                  </label>
                  <select
                    disabled={processing.isProcessing}
                    value={form.type}
                    onChange={(e) => setForm({ ...form, type: e.target.value })}
                    className="w-full px-3.5 py-2 border border-outline-variant rounded-xl focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/20 text-xs font-medium bg-white h-[42px] cursor-pointer disabled:bg-surface-container-low disabled:cursor-not-allowed"
                  >
                    {Object.keys(TRANSACTION_TYPE_LABELS).map((key) => (
                      <option key={key} value={key}>
                        {t(`categories.tabs.${key}`) || TRANSACTION_TYPE_LABELS[key]}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
              <div className="px-6 py-4 bg-surface-container-lowest border-t border-outline-variant flex justify-end gap-2.5">
                <button
                  type="button"
                  disabled={processing.isProcessing}
                  className="px-4 py-2 border border-outline-variant rounded-xl text-on-surface text-xs font-semibold hover:bg-surface-container-low transition-colors cursor-pointer disabled:opacity-50"
                  onClick={() => toggleModal(modals.edit ? 'edit' : 'add', false)}
                >
                  {t('categories.modal.cancelBtn')}
                </button>
                <button
                  type="submit"
                  disabled={processing.isProcessing}
                  className="px-5 py-2 bg-primary text-white rounded-xl text-xs font-semibold hover:bg-primary-tint transition-colors cursor-pointer disabled:opacity-50 flex items-center gap-2 shadow-xs"
                >
                  {processing.isProcessing && (
                    <span className="material-symbols-outlined animate-spin text-sm">
                      progress_activity
                    </span>
                  )}
                  {t('categories.modal.saveBtn')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Filter Modal */}
      {modals.filter && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-2xs flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-md shadow-xl overflow-hidden border border-outline-variant animate-in fade-in zoom-in-95 duration-200">
            <div className="px-6 py-4 border-b border-outline-variant flex items-center justify-between bg-surface-container-lowest">
              <h3 className="font-bold text-base text-on-surface m-0">{t('categories.filterModal.title')}</h3>
              <button
                className="text-secondary hover:text-on-surface cursor-pointer p-1 rounded-full hover:bg-surface-container-low transition-colors"
                onClick={() => toggleModal('filter', false)}
              >
                <span className="material-symbols-outlined text-[20px]">close</span>
              </button>
            </div>
            <div className="p-6 space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-on-surface mb-1.5">
                  {t('categories.filterModal.typeLabel')}
                </label>
                <select
                  value={filter.type}
                  onChange={(e) => setFilter((prev) => ({ ...prev, type: e.target.value }))}
                  className="w-full px-3 py-2 border border-outline-variant rounded-xl focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/20 text-xs font-medium bg-white h-[42px] cursor-pointer"
                >
                  <option value="all">{t('categories.filterModal.allTypes')}</option>
                  {Object.keys(TRANSACTION_TYPE_LABELS).map((key) => (
                    <option key={key} value={key}>
                      {t(`categories.tabs.${key}`) || TRANSACTION_TYPE_LABELS[key]}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-on-surface mb-1.5">
                  {t('categories.filterModal.keywordLabel')}
                </label>
                <input
                  type="text"
                  placeholder={t('categories.filterModal.keywordPlaceholder')}
                  value={filter.keyword}
                  onChange={(e) => setFilter((prev) => ({ ...prev, keyword: e.target.value }))}
                  className="w-full px-3.5 py-2 border border-outline-variant rounded-xl focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/20 text-xs font-medium text-on-surface h-[42px]"
                />
              </div>
            </div>
            <div className="px-6 py-4 bg-surface-container-lowest border-t border-outline-variant flex justify-end gap-2.5">
              <button
                className="px-4 py-2 border border-outline-variant rounded-xl text-on-surface text-xs font-semibold hover:bg-surface-container-low transition-colors cursor-pointer"
                onClick={() => {
                  const reset = { type: 'all', keyword: '' };
                  setFilter(reset);
                  toggleModal('filter', false);
                  fetchCategories(reset);
                }}
              >
                {t('categories.filterModal.resetBtn')}
              </button>
              <button
                className="px-4 py-2 bg-primary text-white rounded-xl text-xs font-semibold hover:bg-primary-tint transition-colors cursor-pointer shadow-xs"
                onClick={() => {
                  toggleModal('filter', false);
                  fetchCategories(filter);
                }}
              >
                {t('categories.filterModal.applyBtn')}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {modals.deleteAlert && categoryToDelete && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-2xs flex items-center justify-center z-50 p-4 animate-in fade-in duration-200">
          <div className="bg-white rounded-2xl w-full max-w-md shadow-2xl overflow-hidden border border-outline-variant animate-in zoom-in-95 duration-200">
            <div className="px-6 py-4 border-b border-outline-variant flex items-center justify-between bg-surface-container-lowest">
              <div className="flex items-center gap-2 text-rose-600">
                <span className="material-symbols-outlined text-2xl">warning</span>
                <h3 className="font-bold text-on-surface text-base m-0">{t('categories.deleteModal.title')}</h3>
              </div>
              <button
                disabled={processing.isProcessing}
                className="text-secondary hover:text-on-surface cursor-pointer p-1 rounded-full hover:bg-surface-container-low transition-colors disabled:opacity-50"
                onClick={() => {
                  toggleModal('deleteAlert', false);
                  setCategoryToDelete(null);
                }}
              >
                <span className="material-symbols-outlined text-[20px]">close</span>
              </button>
            </div>
            <div className="p-6 space-y-4">
              <p className="text-xs text-on-surface m-0 leading-relaxed">
                {t('categories.deleteModal.confirmText')}{' '}
                <strong className="text-primary font-bold">"{categoryToDelete.name}"</strong>?
              </p>
              <div className="bg-surface-container-low p-3.5 rounded-xl border border-outline-variant text-xs text-secondary space-y-1.5">
                <div className="flex items-start gap-1.5 text-rose-600 font-semibold">
                  <span className="material-symbols-outlined text-[16px] shrink-0 mt-0.5">info</span>
                  <span>{t('categories.deleteModal.softDeleteWarning')}</span>
                </div>
                <ul className="list-disc pl-5 space-y-1 text-secondary text-[11px]">
                  <li>
                    {t('categories.deleteModal.point1')}
                  </li>
                  <li>
                    {t('categories.deleteModal.point2')}
                  </li>
                  <li>{t('categories.deleteModal.point3')}</li>
                </ul>
              </div>
            </div>
            <div className="px-6 py-4 bg-surface-container-lowest border-t border-outline-variant flex justify-end gap-2.5">
              <button
                type="button"
                disabled={processing.isProcessing}
                className="px-4 py-2 border border-outline-variant rounded-xl text-on-surface text-xs font-semibold hover:bg-surface-container-low transition-colors cursor-pointer disabled:opacity-50"
                onClick={() => {
                  toggleModal('deleteAlert', false);
                  setCategoryToDelete(null);
                }}
              >
                {t('categories.deleteModal.cancelBtn')}
              </button>
              <button
                type="button"
                disabled={processing.isProcessing}
                className="px-4 py-2 bg-rose-600 text-white rounded-xl text-xs font-semibold hover:bg-rose-700 transition-colors cursor-pointer disabled:opacity-50 flex items-center gap-2 shadow-xs"
                onClick={confirmDelete}
              >
                {processing.isProcessing && (
                  <span className="material-symbols-outlined animate-spin text-sm">
                    progress_activity
                  </span>
                )}
                {t('categories.deleteModal.confirmBtn')}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
};

export default CategoryPage;
