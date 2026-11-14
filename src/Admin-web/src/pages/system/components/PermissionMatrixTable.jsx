import React, { useState } from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { Badge, Button, Card, Icon } from '../../../components/ui';
import { POLICIES, defaultPermission, isChanged, scopeSummary } from './permissionFormat';

const COLS = ['w-[26%]', 'w-[9%]', 'w-[10%]', 'w-[15%]', 'w-[17%]', 'w-[17%]', 'w-[6%]'];

const fieldClass =
  'h-9 rounded-lg border border-line bg-card px-2 text-sm text-ink focus:border-brand focus:outline-none disabled:cursor-not-allowed disabled:bg-muted disabled:text-ink-faint';

const PermissionMatrixTable = ({ groupName, features, plans, draft, original, onPatch, onOpenScope, onUndo }) => {
  const { t } = useLanguageSafe();
  const [open, setOpen] = useState(true);

  const cells = (f, plan) => {
    const value = draft[plan]?.[f.id] || defaultPermission(f, plan);
    const changed = isChanged(value, original[plan]?.[f.id] || value);
    const isLimit = f.type === 'LIMIT';
    const unlimited = isLimit && value.limit_value === null;
    const names = { name: f.name, plan };
    return {
      changed,
      tds: (
        <>
          <td className="px-4 py-2.5">
            <Badge tone={plan === 'Premium' ? 'success' : 'neutral'}>{plan}</Badge>
          </td>
          <td className="px-4 py-2.5">
            <label className="inline-flex cursor-pointer items-center gap-2 whitespace-nowrap">
              <input
                type="checkbox"
                aria-label={t('permissions.aria.access', names)}
                checked={Boolean(value.is_enabled)}
                onChange={(e) => onPatch(plan, f.id, { is_enabled: e.target.checked })}
                className="h-4 w-4 cursor-pointer accent-brand"
              />
              <span className={value.is_enabled ? 'font-medium text-success' : 'text-ink-faint'}>
                {value.is_enabled ? t('permissions.table.on') : t('permissions.table.off')}
              </span>
            </label>
          </td>
          <td className="px-4 py-2.5">
            {isLimit ? (
              <div className="flex items-center gap-2 whitespace-nowrap">
                <input
                  type="number"
                  min="0"
                  max="999"
                  aria-label={t('permissions.aria.limit', names)}
                  disabled={!value.is_enabled || unlimited}
                  value={value.limit_value ?? ''}
                  placeholder={unlimited ? '∞' : '0'}
                  onChange={(e) => {
                    const raw = e.target.value;
                    onPatch(plan, f.id, { limit_value: raw === '' ? null : Math.max(0, parseInt(raw, 10) || 0) });
                  }}
                  className={`${fieldClass} w-20 text-center tabular-nums`}
                />
                <label className="inline-flex cursor-pointer items-center gap-1.5 text-ink-muted">
                  <input
                    type="checkbox"
                    aria-label={t('permissions.aria.unlimited', names)}
                    disabled={!value.is_enabled}
                    checked={unlimited}
                    onChange={(e) => onPatch(plan, f.id, { limit_value: e.target.checked ? null : 0 })}
                    className="h-4 w-4 cursor-pointer accent-brand"
                  />
                  <span aria-hidden="true">∞</span>
                </label>
              </div>
            ) : (
              <span className="text-ink-faint">—</span>
            )}
          </td>
          <td className="px-4 py-2.5">
            <div className="flex min-w-0 items-center gap-1">
              <span className="max-w-40 truncate rounded bg-muted px-2 py-0.5 font-mono text-xs text-ink-muted" title={JSON.stringify(value.scope_config || {})}>
                {scopeSummary(value.scope_config, t)}
              </span>
              <Button
                variant="ghost"
                size="sm"
                icon="edit"
                data-testid={`btn-config-scope-${f.id}-${plan}`}
                aria-label={t('permissions.aria.scope', names)}
                onClick={() => onOpenScope(f, plan)}
              />
            </div>
          </td>
          <td className="px-4 py-2.5">
            <select
              aria-label={t('permissions.aria.policy', names)}
              value={value.downgrade_policy || 'BLOCK_CREATE'}
              disabled={!value.is_enabled}
              onChange={(e) => onPatch(plan, f.id, { downgrade_policy: e.target.value })}
              className={`${fieldClass} w-full cursor-pointer pr-8`}
            >
              {POLICIES.map((p) => (
                <option key={p} value={p}>
                  {t(`permissions.policies.${p}`)}
                </option>
              ))}
            </select>
          </td>
          <td className="px-2 py-2.5 text-right">
            {changed && <Button variant="ghost" size="sm" icon="undo" aria-label={t('permissions.aria.undo', names)} onClick={() => onUndo(f.id, plan)} />}
          </td>
        </>
      ),
    };
  };

  return (
    <Card>
      <button
        type="button"
        aria-expanded={open}
        onClick={() => setOpen((v) => !v)}
        className="flex w-full cursor-pointer items-center justify-between gap-3 px-5 py-3 text-left hover:bg-muted/60"
      >
        <span className="text-base font-semibold text-ink">
          {groupName} <span className="font-normal text-ink-faint">({features.length})</span>
        </span>
        <Icon name={open ? 'expand_less' : 'expand_more'} className="text-ink-faint" />
      </button>

      {open && (
        <div className="relative overflow-x-auto border-t border-line">
          <table className="w-full min-w-[960px] table-fixed border-collapse text-sm">
            <colgroup>
              {COLS.map((w, i) => (
                <col key={i} className={w} />
              ))}
            </colgroup>
            <thead>
              <tr className="bg-muted/60 text-left text-xs font-semibold uppercase tracking-wide text-ink-muted">
                <th scope="col" className="px-4 py-3">{t('permissions.table.feature')}</th>
                <th scope="col" className="px-4 py-3">{t('permissions.table.plan')}</th>
                <th scope="col" className="px-4 py-3">{t('permissions.table.access')}</th>
                <th scope="col" className="px-4 py-3">{t('permissions.table.limit')}</th>
                <th scope="col" className="px-4 py-3">{t('permissions.table.scope')}</th>
                <th scope="col" className="px-4 py-3">{t('permissions.table.policy')}</th>
                <th scope="col" className="px-2 py-3">
                  <span className="sr-only">{t('permissions.table.actions')}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {features.map((f) =>
                plans.map((plan, i) => {
                  const row = cells(f, plan);
                  return (
                    <tr key={`${f.id}-${plan}`} className={`${i === 0 ? 'border-t border-line' : ''} ${row.changed ? 'bg-warning-soft' : ''}`}>
                      {i === 0 && (
                        <td rowSpan={plans.length} className="px-4 py-2.5 align-middle">
                          <div className="flex flex-col items-start gap-1">
                            <span className="font-medium text-ink">{f.name}</span>
                            <div className="flex items-center gap-1.5">
                              <Badge tone={f.type === 'LIMIT' ? 'info' : 'neutral'}>
                                {f.type === 'LIMIT' ? t('permissions.table.typeLimit') : t('permissions.table.typeToggle')}
                              </Badge>
                              <span className="font-mono text-xs text-ink-faint">{f.id}</span>
                            </div>
                          </div>
                        </td>
                      )}
                      {row.tds}
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
};

export default PermissionMatrixTable;
