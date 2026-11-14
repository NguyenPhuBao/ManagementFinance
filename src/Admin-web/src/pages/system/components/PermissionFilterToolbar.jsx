import React, { useId } from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { Card, SearchInput, Tabs } from '../../../components/ui';
import { groupLabel } from './permissionFormat';

const PermissionFilterToolbar = ({
  search,
  onSearchChange,
  groups,
  selectedGroup,
  onSelectGroup,
  viewMode,
  onViewModeChange,
  onlyDirty,
  onToggleDirty,
  dirtyCount,
  totalFeatures,
  limitCount,
}) => {
  const { t } = useLanguageSafe();
  const ids = useId();

  return (
    <Card>
      <div className="flex flex-wrap items-center gap-3 px-4 py-3">
        <Tabs
          ariaLabel={t('permissions.toolbar.viewLabel')}
          value={viewMode}
          onChange={onViewModeChange}
          items={[
            { key: 'ALL', label: t('permissions.toolbar.viewAll') },
            { key: 'Basic', label: t('permissions.toolbar.viewBasic') },
            { key: 'Premium', label: t('permissions.toolbar.viewPremium') },
          ]}
        />
        <SearchInput
          label={t('permissions.toolbar.searchLabel')}
          placeholder={t('permissions.toolbar.searchPlaceholder')}
          value={search}
          onChange={onSearchChange}
          className="w-full sm:w-64"
          data-testid="input-search-features"
        />
        <label htmlFor={`${ids}-group`} className="sr-only">
          {t('permissions.toolbar.groupLabel')}
        </label>
        <select
          id={`${ids}-group`}
          data-testid="select-group-filter"
          value={selectedGroup}
          onChange={(e) => onSelectGroup(e.target.value)}
          className="h-10 cursor-pointer rounded-lg border border-line bg-card px-3 pr-9 text-sm text-ink focus:border-brand focus:outline-none"
        >
          <option value="ALL">{t('permissions.toolbar.groupAll')}</option>
          {groups.map((g) => (
            <option key={g} value={g}>
              {groupLabel(g, t)}
            </option>
          ))}
        </select>
        {dirtyCount > 0 && (
          <label className="inline-flex cursor-pointer items-center gap-2 text-sm text-ink">
            <input
              type="checkbox"
              data-testid="checkbox-only-dirty"
              checked={onlyDirty}
              onChange={(e) => onToggleDirty(e.target.checked)}
              className="h-4 w-4 cursor-pointer accent-brand"
            />
            {t('permissions.toolbar.onlyDirty')}
          </label>
        )}
        <span className="ml-auto text-sm text-ink-muted">{t('permissions.toolbar.stats', { total: totalFeatures, limits: limitCount })}</span>
      </div>
    </Card>
  );
};

export default PermissionFilterToolbar;
