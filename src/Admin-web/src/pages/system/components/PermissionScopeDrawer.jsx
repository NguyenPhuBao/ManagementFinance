import React, { useState, useEffect } from 'react';
import { useLanguageSafe } from '../../../store/language.context';

const PermissionScopeDrawer = ({
  isOpen,
  onClose,
  feature,
  accountType = 'Basic',
  initialScope = {},
  initialPolicy = 'BLOCK_CREATE',
  onApply,
}) => {
  const { t } = useLanguageSafe();

  const [scopeJson, setScopeJson] = useState('{}');
  const [jsonError, setJsonError] = useState(null);

  // Đồng bộ khi mở drawer hoặc thay đổi feature/accountType
  useEffect(() => {
    if (isOpen && feature) {
      try {
        const jsonStr = JSON.stringify(initialScope || {}, null, 2);
        setScopeJson(jsonStr);
        setJsonError(null);
      } catch (err) {
        setScopeJson('{}');
      }
    }
  }, [isOpen, feature, accountType, initialScope]);

  if (!isOpen || !feature) return null;

  const handleApply = () => {
    try {
      const parsedScope = scopeJson.trim() ? JSON.parse(scopeJson) : {};
      setJsonError(null);
      onApply?.({
        featureId: feature.id,
        accountType,
        scope_config: parsedScope,
        downgrade_policy: initialPolicy,
      });
      onClose();
    } catch (err) {
      setJsonError(t('permissions.drawer.jsonInvalid'));
    }
  };

  return (
    <div className="fixed inset-0 z-50 overflow-hidden">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-slate-900/40 backdrop-blur-xs transition-opacity"
        onClick={onClose}
      />

      <div className="fixed inset-y-0 right-0 max-w-full flex pl-10">
        <div className="w-screen max-w-md bg-white shadow-2xl flex flex-col border-l border-slate-200">
          {/* Header */}
          <div className="p-5 border-b border-slate-200 bg-slate-50/70 flex items-start justify-between gap-3">
            <div>
              <div className="flex items-center gap-2 mb-1">
                <span className="material-symbols-outlined text-primary text-[20px]">tune</span>
                <h2 className="text-sm font-bold text-slate-800 m-0">
                  {t('permissions.drawer.title')}
                </h2>
                <span
                  className={`text-[10px] font-bold px-2 py-0.5 rounded-full border ${
                    accountType === 'Premium'
                      ? 'bg-amber-50 text-amber-700 border-amber-300'
                      : 'bg-blue-50 text-blue-700 border-blue-300'
                  }`}
                >
                  {accountType}
                </span>
              </div>
              <div className="text-xs font-semibold text-slate-700 flex items-center gap-1.5">
                <span>{feature.name}</span>
                <code className="text-[10px] font-mono px-1.5 py-0.2 bg-slate-200/80 rounded text-slate-600">
                  {feature.id}
                </code>
              </div>
            </div>

            <button
              type="button"
              data-testid="btn-close-drawer"
              onClick={onClose}
              className="text-slate-400 hover:text-slate-600 hover:bg-slate-200/60 p-1.5 rounded-lg transition"
              title={t('permissions.drawer.cancelBtn')}
            >
              <span className="material-symbols-outlined text-[18px]">close</span>
            </button>
          </div>

          {/* Body */}
          <div className="flex-1 overflow-y-auto p-5 space-y-6">
            {/* TRỤ 3: PHẠM VI HOẠT ĐỘNG (SCOPE CONFIG) */}
            <div className="space-y-2.5">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-1.5">
                  <span className="material-symbols-outlined text-indigo-600 text-[18px]">data_object</span>
                  <label className="text-xs font-bold text-slate-800 uppercase tracking-wider">
                    {t('permissions.drawer.scopeSectionTitle')}
                  </label>
                </div>
              </div>
              <p className="text-[11px] text-slate-500 m-0">
                {t('permissions.drawer.scopeSectionDesc')}
              </p>

              {/* Schema gốc (nếu có) */}
              {feature.scope_schema && Object.keys(feature.scope_schema).length > 0 && (
                <div className="p-2.5 bg-slate-50 border border-slate-200 rounded-lg space-y-1">
                  <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">
                    {t('permissions.drawer.scopeSchemaTitle')}
                  </div>
                  <pre className="text-[10px] font-mono text-slate-700 bg-white p-2 rounded border border-slate-200 overflow-x-auto m-0">
                    {JSON.stringify(feature.scope_schema, null, 2)}
                  </pre>
                </div>
              )}

              {/* JSON Editor */}
              <div className="space-y-1.5">
                <label className="text-[11px] font-semibold text-slate-700">
                  {t('permissions.drawer.jsonEditorTitle')}
                </label>
                <textarea
                  data-testid="textarea-scope-json"
                  rows={8}
                  value={scopeJson}
                  onChange={(e) => {
                    setScopeJson(e.target.value);
                    if (jsonError) setJsonError(null);
                  }}
                  className={`w-full font-mono text-[11px] p-3 rounded-lg border focus:outline-none focus:ring-2 focus:ring-primary transition ${
                    jsonError
                      ? 'border-red-500 bg-red-50/30'
                      : 'border-slate-300 bg-slate-50 focus:bg-white text-slate-800'
                  }`}
                  placeholder="{}"
                />
                {jsonError && (
                  <p className="text-[11px] font-semibold text-red-600 m-0 flex items-center gap-1">
                    <span className="material-symbols-outlined text-[14px]">error</span>
                    {jsonError}
                  </p>
                )}
              </div>
            </div>
          </div>

          {/* Footer */}
          <div className="p-4 border-t border-slate-200 bg-slate-50/70 flex items-center justify-end gap-2.5">
            <button
              type="button"
              onClick={onClose}
              className="px-3.5 py-2 text-xs font-semibold text-slate-600 hover:text-slate-800 hover:bg-slate-200/60 rounded-lg transition"
            >
              {t('permissions.drawer.cancelBtn')}
            </button>
            <button
              type="button"
              data-testid="btn-apply-drawer"
              onClick={handleApply}
              className="px-4 py-2 bg-primary hover:bg-primary/90 text-white text-xs font-bold rounded-lg shadow-xs transition flex items-center gap-1.5"
            >
              <span className="material-symbols-outlined text-[16px]">check</span>
              <span>{t('permissions.drawer.applyBtn')}</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default PermissionScopeDrawer;
