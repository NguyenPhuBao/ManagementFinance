import React, { useState, useEffect, useMemo, useId } from 'react';
import { normalizeCategoryName, normalizeVietnameseUnaccent } from '../../utils/string';
import adminApi from '../../api/admin.api';
import TruncateCell from '../../components/common/TruncateCell';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import {
  Badge,
  Button,
  Card,
  ConfirmModal,
  DataTable,
  Icon,
  Modal,
  PageHeader,
  Pagination,
  SearchInput,
  SecurityConfirmModal,
  StatCard,
  Tabs,
} from '../../components/ui';

const CLASSIFY_MAP = { Thu: 'income', Chi: 'expense', 'Vay/no': 'debt', 'Vay/nợ': 'debt' };
const TYPE_TO_CLASSIFY = { income: 'Thu', expense: 'Chi', debt: 'Vay/no' };
const TYPES = ['expense', 'income', 'debt'];
const TYPE_TONE = { income: 'success', expense: 'danger', debt: 'info' };
const EMPTY_DRAFT = { added: [], updated: [], deleted: [], restored: [] };
const EMPTY_FORM = { name: '', type: 'expense', keyword: '' };
const EMPTY_FILTER = { type: 'all', keyword: '' };

const inputClass =
  'h-10 w-full rounded-lg border border-line bg-card px-3 text-sm text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';

const toRow = (c) => {
  const isUser = Boolean(c.is_user_category) || c.is_default === false;
  return {
    id: c.id,
    name: isUser ? '***' : c.name,
    type: CLASSIFY_MAP[c.classify] || 'expense',
    classify: c.classify,
    isUserCategory: isUser,
    keyword: isUser ? '' : c.keyword || '',
    deleted: Boolean(c.delete_at) || c.status === 'deleted',
  };
};

const isDeleted = (c) => c.deleted;

const CategoryPage = () => {
  const notify = useAlertSafe();
  const { t } = useLanguageSafe();
  const formId = useId();

  const [loading, setLoading] = useState(true);
  const [categories, setCategories] = useState([]);
  const [original, setOriginal] = useState([]);
  const [draft, setDraft] = useState(EMPTY_DRAFT);
  const [search, setSearch] = useState('');
  const [typeTab, setTypeTab] = useState('all');
  const [serverFilter, setServerFilter] = useState(EMPTY_FILTER);
  const [draftFilter, setDraftFilter] = useState(EMPTY_FILTER);
  const [filterOpen, setFilterOpen] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  const [editor, setEditor] = useState(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [formError, setFormError] = useState('');
  const [deleteTarget, setDeleteTarget] = useState(null);
  const [resetOpen, setResetOpen] = useState(false);
  const [syncOpen, setSyncOpen] = useState(false);

  const draftCount = draft.added.length + draft.updated.length + draft.deleted.length + draft.restored.length;

  const fetchCategories = async (f = serverFilter) => {
    try {
      setLoading(true);
      const params = { is_default: true };
      if (f.type !== 'all') params.classify = TYPE_TO_CLASSIFY[f.type];
      if (f.keyword.trim()) params.keyword = f.keyword.trim();
      const res = await adminApi.getCategories(params);
      const rows = (res.data || []).map(toRow);
      setCategories(rows);
      setOriginal(rows);
      setDraft(EMPTY_DRAFT);
    } catch (err) {
      console.error('Lỗi tải danh mục:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCategories();
  }, []);

  useEffect(() => {
    setCurrentPage(1);
  }, [search, typeTab, serverFilter]);

  const stats = useMemo(() => {
    const count = (type) => categories.filter((c) => c.type === type).length;
    return { all: categories.length, expense: count('expense'), income: count('income'), debt: count('debt') };
  }, [categories]);

  const filtered = useMemo(() => {
    const q = normalizeVietnameseUnaccent(search);
    return categories.filter((c) => {
      const matchSearch = !q || normalizeVietnameseUnaccent(c.name).includes(q) || c.name.toLowerCase().includes(search.toLowerCase());
      return matchSearch && (typeTab === 'all' || c.type === typeTab);
    });
  }, [categories, search, typeTab]);

  const pageData = filtered.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  const openAdd = () => {
    setEditor({ mode: 'add' });
    setForm(EMPTY_FORM);
    setFormError('');
  };

  const openEdit = (cat) => {
    if (cat.isUserCategory) return;
    setEditor({ mode: 'edit', target: cat });
    setForm({ name: cat.name, type: cat.type, keyword: cat.keyword || '' });
    setFormError('');
  };

  const handleSave = (e) => {
    e.preventDefault();
    const name = form.name.trim();
    const norm = normalizeCategoryName(name);
    if (!norm) {
      setFormError(t('categories.alerts.nameRequired'));
      return;
    }
    const classify = TYPE_TO_CLASSIFY[form.type];
    const keyword = form.keyword.trim();
    const target = editor.mode === 'edit' ? editor.target : null;

    const duplicate = categories.find(
      (c) => !c.isUserCategory && !isDeleted(c) && normalizeCategoryName(c.name) === norm && c.classify === classify && (!target || c.id !== target.id)
    );
    if (duplicate) {
      setFormError(t('categories.alerts.duplicateName', { name: duplicate.name }));
      return;
    }

    if (target) {
      const changes = { name, type: form.type, classify, keyword };
      setCategories((prev) => prev.map((c) => (c.id === target.id ? { ...c, ...changes, isDraftModified: !c.isDraftNew } : c)));
      setDraft((prev) =>
        target.isDraftNew
          ? { ...prev, added: prev.added.map((item) => (item.id === target.id ? { ...item, ...changes } : item)) }
          : { ...prev, updated: [...prev.updated.filter((u) => u.id !== target.id), { id: target.id, ...changes }] }
      );
      if (notify) notify.info(t('categories.draftAlerts.updated'));
    } else {
      let finalKeyword = keyword;
      if (!finalKeyword) {
        const inherited = categories.find((c) => isDeleted(c) && !c.isUserCategory && normalizeCategoryName(c.name) === norm && c.classify === classify && c.keyword);
        if (inherited) finalKeyword = inherited.keyword;
      }
      const item = {
        id: `draft_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
        name,
        type: form.type,
        classify,
        keyword: finalKeyword,
        isUserCategory: false,
        deleted: false,
        isDraftNew: true,
      };
      setCategories((prev) => [item, ...prev]);
      setDraft((prev) => ({ ...prev, added: [item, ...prev.added] }));
      if (notify) notify.info(t('categories.draftAlerts.added'));
    }
    setEditor(null);
  };

  const confirmDelete = () => {
    const target = deleteTarget;
    if (!target || target.isUserCategory) return;
    if (target.isDraftNew) {
      setCategories((prev) => prev.filter((c) => c.id !== target.id));
      setDraft((prev) => ({ ...prev, added: prev.added.filter((item) => item.id !== target.id) }));
    } else {
      setCategories((prev) => prev.map((c) => (c.id === target.id ? { ...c, deleted: true, isDraftDeleted: true } : c)));
      setDraft((prev) => ({
        ...prev,
        updated: prev.updated.filter((u) => u.id !== target.id),
        deleted: [...prev.deleted.filter((id) => id !== target.id), target.id],
      }));
    }
    setDeleteTarget(null);
    if (notify) notify.info(t('categories.draftAlerts.deleted'));
  };

  const handleRestore = (cat) => {
    if (cat.isDraftDeleted) {
      setCategories((prev) => prev.map((c) => (c.id === cat.id ? { ...c, deleted: false, isDraftDeleted: false } : c)));
      setDraft((prev) => ({ ...prev, deleted: prev.deleted.filter((id) => id !== cat.id) }));
    } else {
      setCategories((prev) => prev.map((c) => (c.id === cat.id ? { ...c, deleted: false, isDraftRestored: true } : c)));
      setDraft((prev) => ({ ...prev, restored: [...prev.restored.filter((item) => item.id !== cat.id), cat] }));
    }
    if (notify) notify.info(t('categories.draftAlerts.restored'));
  };

  const handleReset = () => {
    setCategories(original);
    setDraft(EMPTY_DRAFT);
    setResetOpen(false);
    if (notify) notify.success(t('categories.draftAlerts.resetSuccess'));
  };

  const saveDraft = async () => {
    const payload = (item) => ({ name: item.name, classify: item.classify, is_default: true, keyword: item.keyword || null });
    for (const item of draft.added) await adminApi.createCategory(payload(item));
    for (const item of draft.updated) await adminApi.updateCategory(item.id, payload(item));
    for (const item of draft.restored) await adminApi.restoreCategory(item.id);
    for (const id of draft.deleted) await adminApi.deleteCategory(id);
    await fetchCategories();
    if (notify) notify.success(t('categories.syncModal.syncSuccess'));
  };

  const applyServerFilter = (f) => {
    setServerFilter(f);
    setFilterOpen(false);
    fetchCategories(f);
  };

  const draftBadge = (c) => {
    if (c.deleted) return <Badge tone="danger">{t('categories.draft.deleted')}</Badge>;
    if (c.isDraftNew) return <Badge tone="info">{t('categories.draft.new')}</Badge>;
    if (c.isDraftRestored) return <Badge tone="success">{t('categories.draft.restored')}</Badge>;
    if (c.isDraftModified) return <Badge tone="warning">{t('categories.draft.modified')}</Badge>;
    return null;
  };

  const columns = [
    {
      key: 'name',
      title: t('categories.table.colName'),
      width: '32%',
      render: (c) =>
        c.isUserCategory ? (
          <div>
            <div className="font-medium text-ink">***</div>
            <div className="text-xs text-ink-faint">{t('categories.table.userCategory')}</div>
          </div>
        ) : (
          <div className="flex min-w-0 items-center gap-2">
            <TruncateCell text={c.name} className={`font-medium ${c.deleted ? 'text-ink-faint line-through' : 'text-ink'}`} />
            {draftBadge(c)}
          </div>
        ),
    },
    { key: 'type', title: t('categories.table.colType'), render: (c) => <Badge tone={TYPE_TONE[c.type]}>{t(`categories.tabs.${c.type}`)}</Badge> },
    {
      key: 'keyword',
      title: t('categories.table.colKeyword'),
      width: '34%',
      render: (c) =>
        c.isUserCategory ? (
          <span className="text-ink-faint">***</span>
        ) : c.keyword ? (
          <TruncateCell text={c.keyword} className="text-ink-muted" />
        ) : (
          <span className="text-ink-faint">{t('categories.table.noKeyword')}</span>
        ),
    },
    {
      key: 'actions',
      title: t('categories.table.colActions'),
      align: 'right',
      render: (c) => {
        if (c.isUserCategory) {
          return (
            <span title={t('categories.table.userCategoryLocked')} className="inline-flex text-ink-faint">
              <Icon name="lock" size="sm" />
            </span>
          );
        }
        if (c.deleted) {
          return (
            <Button variant="ghost" size="sm" icon="restore" onClick={() => handleRestore(c)}>
              {t('categories.table.restore')}
            </Button>
          );
        }
        return (
          <div className="flex items-center justify-end gap-1">
            <Button variant="ghost" size="sm" icon="edit" aria-label={t('categories.table.edit')} title={t('categories.table.edit')} onClick={() => openEdit(c)} />
            <Button variant="danger-ghost" size="sm" icon="delete" aria-label={t('categories.table.delete')} title={t('categories.table.delete')} onClick={() => setDeleteTarget(c)} />
          </div>
        );
      },
    },
  ];

  const tabs = [
    { key: 'all', label: t('categories.tabs.all'), count: stats.all },
    ...TYPES.map((type) => ({ key: type, label: t(`categories.tabs.${type}`), count: stats[type] })),
  ];

  const filterIsCustom = serverFilter.type !== 'all' || serverFilter.keyword.trim() !== '';

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t('categories.title')}
        description={t('categories.subtitle')}
        actions={
          <>
            <Button icon="refresh" onClick={() => fetchCategories()} loading={loading}>
              {t('categories.refresh')}
            </Button>
            <Button variant="primary" icon="add" onClick={openAdd}>
              {t('categories.addCategory')}
            </Button>
          </>
        }
      />

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label={t('categories.stats.total')} value={stats.all} />
        <StatCard label={t('categories.stats.expense')} value={stats.expense} />
        <StatCard label={t('categories.stats.income')} value={stats.income} />
        <StatCard label={t('categories.stats.debt')} value={stats.debt} />
      </div>

      <Card>
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line px-4 py-3">
          <Tabs items={tabs} value={typeTab} onChange={setTypeTab} ariaLabel={t('categories.tabs.ariaLabel')} />
          <div className="flex flex-wrap items-center gap-2">
            <SearchInput
              label={t('categories.searchLabel')}
              placeholder={t('categories.searchPlaceholder')}
              value={search}
              onChange={setSearch}
              className="w-full sm:w-72"
            />
            <Button
              icon="filter_alt"
              className={filterIsCustom ? 'border-brand text-brand' : ''}
              onClick={() => {
                setDraftFilter(serverFilter);
                setFilterOpen(true);
              }}
            >
              {t('categories.filterBtn')}
            </Button>
          </div>
        </div>
        <DataTable
          columns={columns}
          rows={pageData}
          rowKey="id"
          loading={loading && categories.length === 0}
          emptyTitle={t('categories.table.emptyTitle')}
          emptyDescription={t('categories.table.emptySubtitle')}
        />
        <Pagination
          currentPage={currentPage}
          pageSize={pageSize}
          total={filtered.length}
          onPageChange={setCurrentPage}
          onPageSizeChange={(size) => {
            setPageSize(size);
            setCurrentPage(1);
          }}
          itemLabel={t('categories.table.itemLabel')}
        />
        <div className="flex flex-wrap items-center justify-between gap-3 border-t border-line bg-muted/40 px-4 py-3">
          <span className={`text-sm ${draftCount ? 'font-medium text-warning' : 'text-ink-faint'}`}>
            {draftCount ? t('categories.draft.pending', { count: draftCount }) : t('categories.draft.none')}
          </span>
          <div className="flex gap-2">
            <Button icon="undo" disabled={!draftCount} onClick={() => setResetOpen(true)}>
              {t('categories.draft.discardBtn')}
            </Button>
            <Button variant="primary" icon="save" disabled={!draftCount} onClick={() => setSyncOpen(true)}>
              {t('categories.draft.saveBtn')}
            </Button>
          </div>
        </div>
      </Card>

      <Modal
        open={Boolean(editor)}
        onClose={() => setEditor(null)}
        size="sm"
        title={editor?.mode === 'edit' ? t('categories.modal.editTitle') : t('categories.modal.addTitle')}
        footer={
          <>
            <Button onClick={() => setEditor(null)}>{t('common.cancel')}</Button>
            <Button type="submit" form={formId} variant="primary">
              {editor?.mode === 'edit' ? t('categories.modal.updateBtn') : t('categories.modal.addBtn')}
            </Button>
          </>
        }
      >
        <form id={formId} onSubmit={handleSave} className="flex flex-col gap-4">
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-ink">{t('categories.modal.nameLabel')}</span>
            <input
              autoFocus
              value={form.name}
              placeholder={t('categories.modal.namePlaceholder')}
              onChange={(e) => {
                setForm({ ...form, name: e.target.value });
                if (formError) setFormError('');
              }}
              className={inputClass}
            />
          </label>
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-ink">{t('categories.modal.typeLabel')}</span>
            <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })} className={`${inputClass} cursor-pointer pr-9`}>
              {TYPES.map((type) => (
                <option key={type} value={type}>
                  {t(`categories.tabs.${type}`)}
                </option>
              ))}
            </select>
          </label>
          <div className="flex flex-col gap-1.5">
            <label htmlFor={`${formId}-keyword`} className="text-sm font-medium text-ink">
              {t('categories.modal.keywordLabel')}
            </label>
            <input
              id={`${formId}-keyword`}
              value={form.keyword}
              placeholder={t('categories.modal.keywordPlaceholder')}
              aria-describedby={`${formId}-keyword-hint`}
              onChange={(e) => setForm({ ...form, keyword: e.target.value })}
              className={inputClass}
            />
            <span id={`${formId}-keyword-hint`} className="text-xs text-ink-faint">
              {t('categories.modal.keywordHint')}
            </span>
          </div>
          {formError && (
            <p role="alert" className="m-0 rounded-lg bg-danger-soft px-3 py-2 text-sm text-danger">
              {formError}
            </p>
          )}
        </form>
      </Modal>

      <Modal
        open={filterOpen}
        onClose={() => setFilterOpen(false)}
        size="sm"
        title={t('categories.filterModal.title')}
        footer={
          <>
            <Button onClick={() => applyServerFilter(EMPTY_FILTER)}>{t('categories.filterModal.resetBtn')}</Button>
            <Button variant="primary" onClick={() => applyServerFilter(draftFilter)}>
              {t('categories.filterModal.applyBtn')}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-ink">{t('categories.filterModal.typeLabel')}</span>
            <select
              value={draftFilter.type}
              onChange={(e) => setDraftFilter((prev) => ({ ...prev, type: e.target.value }))}
              className={`${inputClass} cursor-pointer pr-9`}
            >
              <option value="all">{t('categories.filterModal.allTypes')}</option>
              {TYPES.map((type) => (
                <option key={type} value={type}>
                  {t(`categories.tabs.${type}`)}
                </option>
              ))}
            </select>
          </label>
          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-medium text-ink">{t('categories.filterModal.keywordLabel')}</span>
            <input
              value={draftFilter.keyword}
              placeholder={t('categories.filterModal.keywordPlaceholder')}
              onChange={(e) => setDraftFilter((prev) => ({ ...prev, keyword: e.target.value }))}
              className={inputClass}
            />
          </label>
        </div>
      </Modal>

      <ConfirmModal
        open={Boolean(deleteTarget)}
        title={t('categories.deleteModal.title')}
        message={deleteTarget ? t('categories.deleteModal.message', { name: deleteTarget.name }) : ''}
        confirmText={t('categories.deleteModal.confirmBtn')}
        confirmDanger
        onConfirm={confirmDelete}
        onCancel={() => setDeleteTarget(null)}
      />

      <ConfirmModal
        open={resetOpen}
        title={t('categories.resetModal.title')}
        message={t('categories.resetModal.message')}
        confirmText={t('categories.resetModal.confirmBtn')}
        confirmDanger
        onConfirm={handleReset}
        onCancel={() => setResetOpen(false)}
      />

      <SecurityConfirmModal
        isOpen={syncOpen}
        onClose={() => setSyncOpen(false)}
        title={t('categories.syncModal.title')}
        description={t('categories.syncModal.description')}
        confirmText={t('categories.syncModal.confirmBtn')}
        actionType="SYNC_CATEGORIES"
        targetLabel="SYSTEM_CATEGORIES"
        onConfirm={saveDraft}
      />
    </div>
  );
};

export default CategoryPage;
