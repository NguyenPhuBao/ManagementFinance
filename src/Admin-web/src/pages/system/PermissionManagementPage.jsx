import React, { useCallback, useEffect, useMemo, useState } from 'react';
import adminApi from '../../api/admin.api';
import useSocket from '../../hooks/useSocket';
import { useAlertSafe } from '../../store/alert.context';
import { useLanguageSafe } from '../../store/language.context';
import { Button, Card, ConfirmModal, EmptyState, PageHeader, Spinner } from '../../components/ui';
import PermissionFilterToolbar from './components/PermissionFilterToolbar';
import PermissionMatrixTable from './components/PermissionMatrixTable';
import PermissionScopeDrawer from './components/PermissionScopeDrawer';
import { PLANS, groupLabel, isChanged } from './components/permissionFormat';

const EMPTY = { Basic: {}, Premium: {} };
const clone = (v) => JSON.parse(JSON.stringify(v));
const errorMessage = (err, fallback) => err?.response?.data?.message || err?.message || fallback;

const PermissionManagementPage = () => {
  const notify = useAlertSafe();
  const socket = useSocket();
  const { t } = useLanguageSafe();

  const [loading, setLoading] = useState(true);
  const [features, setFeatures] = useState([]);
  const [original, setOriginal] = useState(EMPTY);
  const [draft, setDraft] = useState(EMPTY);
  const [search, setSearch] = useState('');
  const [selectedGroup, setSelectedGroup] = useState('ALL');
  const [viewMode, setViewMode] = useState('ALL');
  const [onlyDirty, setOnlyDirty] = useState(false);
  const [scopeTarget, setScopeTarget] = useState(null);
  const [confirmSave, setConfirmSave] = useState(false);
  const [confirmReset, setConfirmReset] = useState(false);
  const [saving, setSaving] = useState(false);
  const [resetting, setResetting] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await adminApi.getPermissions();
      const payload = res?.data || res;
      const data = payload?.data || payload;
      const perms = data?.permissions || EMPTY;
      setFeatures(data?.features || []);
      setOriginal(clone(perms));
      setDraft(clone(perms));
    } catch (err) {
      if (notify) notify.error(errorMessage(err, t('permissions.feedback.loadError')), t('permissions.feedback.errorTitle'));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (!socket) return undefined;
    socket.on('account.permissions_updated', load);
    return () => socket.off('account.permissions_updated', load);
  }, [socket, load]);

  const groups = useMemo(() => [...new Set(features.map((f) => f.category_group).filter(Boolean))], [features]);

  const dirtyItems = useMemo(
    () =>
      PLANS.flatMap((plan) =>
        features
          .filter((f) => isChanged(draft[plan]?.[f.id], original[plan]?.[f.id]))
          .map((f) => {
            const d = draft[plan][f.id];
            return {
              account_type: plan,
              feature_id: f.id,
              is_enabled: d.is_enabled,
              limit_value: d.limit_value,
              scope_config: d.scope_config,
              downgrade_policy: d.downgrade_policy,
            };
          })
      ),
    [features, draft, original]
  );

  const visibleGroups = useMemo(() => {
    const q = search.trim().toLowerCase();
    const dirtyIds = new Set(dirtyItems.map((d) => d.feature_id));
    const map = new Map();
    features.forEach((f) => {
      if (q && ![f.name, f.id, f.description].some((v) => v && v.toLowerCase().includes(q))) return;
      if (selectedGroup !== 'ALL' && f.category_group !== selectedGroup) return;
      if (onlyDirty && !dirtyIds.has(f.id)) return;
      const group = f.category_group || t('permissions.groups.other');
      if (!map.has(group)) map.set(group, []);
      map.get(group).push(f);
    });
    return [...map.entries()];
  }, [features, search, selectedGroup, onlyDirty, dirtyItems, t]);

  const patch = useCallback((plan, featureId, changes) => {
    setDraft((prev) => ({
      ...prev,
      [plan]: { ...prev[plan], [featureId]: { ...prev[plan]?.[featureId], ...changes } },
    }));
  }, []);

  const undo = useCallback(
    (featureId, plan) => {
      setDraft((prev) => ({ ...prev, [plan]: { ...prev[plan], [featureId]: clone(original[plan]?.[featureId] || {}) } }));
    },
    [original]
  );

  const save = async () => {
    if (dirtyItems.length === 0) return;
    setSaving(true);
    try {
      await adminApi.updatePermissions(dirtyItems);
      setConfirmSave(false);
      if (notify) notify.success(t('permissions.feedback.saved', { count: dirtyItems.length }));
      await load();
    } catch (err) {
      if (notify) notify.error(errorMessage(err, t('permissions.feedback.saveError')), t('permissions.feedback.errorTitle'));
    } finally {
      setSaving(false);
    }
  };

  const resetDefault = async () => {
    setResetting(true);
    try {
      await adminApi.resetPermissionsDefault();
      setConfirmReset(false);
      if (notify) notify.success(t('permissions.feedback.reset'));
      await load();
    } catch (err) {
      if (notify) notify.error(errorMessage(err, t('permissions.feedback.resetError')), t('permissions.feedback.errorTitle'));
    } finally {
      setResetting(false);
    }
  };

  const plans = viewMode === 'ALL' ? PLANS : [viewMode];

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t('permissions.title')}
        description={t('permissions.subtitle')}
        actions={
          <>
            <Button icon="restart_alt" data-testid="btn-reset-default" disabled={loading || saving} onClick={() => setConfirmReset(true)}>
              {t('permissions.resetBtn')}
            </Button>
            <Button
              variant="primary"
              icon="save"
              data-testid="btn-save-permissions"
              disabled={dirtyItems.length === 0 || loading}
              loading={saving}
              onClick={() => setConfirmSave(true)}
            >
              {dirtyItems.length > 0 ? t('permissions.saveBtnCount', { count: dirtyItems.length }) : t('permissions.saveBtn')}
            </Button>
          </>
        }
      />

      <PermissionFilterToolbar
        search={search}
        onSearchChange={setSearch}
        groups={groups}
        selectedGroup={selectedGroup}
        onSelectGroup={setSelectedGroup}
        viewMode={viewMode}
        onViewModeChange={setViewMode}
        onlyDirty={onlyDirty}
        onToggleDirty={setOnlyDirty}
        dirtyCount={dirtyItems.length}
        totalFeatures={features.length}
        limitCount={features.filter((f) => f.type === 'LIMIT').length}
      />

      {loading && features.length === 0 ? (
        <Card>
          <div className="flex justify-center py-12 text-brand">
            <Spinner size="lg" label={t('common.loading', 'Đang tải')} />
          </div>
        </Card>
      ) : visibleGroups.length === 0 ? (
        <Card>
          <EmptyState icon="search_off" title={t('permissions.emptyTitle')} description={t('permissions.emptyDesc')} />
        </Card>
      ) : (
        visibleGroups.map(([group, feats]) => (
          <PermissionMatrixTable
            key={group}
            groupName={groupLabel(group, t)}
            features={feats}
            plans={plans}
            draft={draft}
            original={original}
            onPatch={patch}
            onOpenScope={(feature, plan) => setScopeTarget({ feature, plan })}
            onUndo={undo}
          />
        ))
      )}

      <PermissionScopeDrawer
        feature={scopeTarget?.feature || null}
        plan={scopeTarget?.plan}
        initialScope={scopeTarget ? draft[scopeTarget.plan]?.[scopeTarget.feature.id]?.scope_config : undefined}
        onApply={(scope) => patch(scopeTarget.plan, scopeTarget.feature.id, { scope_config: scope })}
        onClose={() => setScopeTarget(null)}
      />

      <ConfirmModal
        open={confirmSave}
        testId="modal-confirm-save"
        confirmTestId="btn-confirm-save"
        title={t('permissions.saveModal.title')}
        message={t('permissions.saveModal.message', { count: dirtyItems.length })}
        confirmText={t('permissions.saveModal.confirm')}
        loading={saving}
        onConfirm={save}
        onCancel={() => setConfirmSave(false)}
      />

      <ConfirmModal
        open={confirmReset}
        testId="modal-confirm-reset"
        confirmTestId="btn-confirm-reset"
        title={t('permissions.resetModal.title')}
        message={t('permissions.resetModal.message')}
        confirmText={t('permissions.resetModal.confirm')}
        confirmDanger
        loading={resetting}
        onConfirm={resetDefault}
        onCancel={() => setConfirmReset(false)}
      />
    </div>
  );
};

export default PermissionManagementPage;
