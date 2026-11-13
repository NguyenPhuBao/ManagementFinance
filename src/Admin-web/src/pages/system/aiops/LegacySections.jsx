import React from 'react';
import ConfirmModal from '../../../components/common/ConfirmModal';
import Pagination from '../../../components/common/Pagination';
import TruncateCell from '../../../components/common/TruncateCell';
import { formatDateTime } from '../../../utils/format';

const LegacySections = ({ ops }) => {
  const {
    myCurrentIp,
    quarantineList,
    loading,
    unblockingHash,
    vectorConfig,
    vectorToggleModal,
    setVectorToggleModal,
    incidentsList,
    incidentPage,
    setIncidentPage,
    incidentPageSize,
    setIncidentPageSize,
    incidentTotal,
    incidentVectorFilter,
    setIncidentVectorFilter,
    incidentStatusFilter,
    setIncidentStatusFilter,
    incidentSearch,
    setIncidentSearch,
    showClearIncidentsModal,
    setShowClearIncidentsModal,
    clearingIncidents,
    quarantineModalTarget,
    setQuarantineModalTarget,
    quarantiningActor,
    forensicsModal,
    setForensicsModal,
    quarantinePage,
    setQuarantinePage,
    quarantinePageSize,
    setQuarantinePageSize,
    quarantineIpFilter,
    setQuarantineIpFilter,
    quarantineAccountFilter,
    setQuarantineAccountFilter,
    showManualQuarantineModal,
    setShowManualQuarantineModal,
    manualQuarantineForm,
    setManualQuarantineForm,
    manualQuarantineLoading,
    currentClientTime,
    formatMaskedIp,
    formatRemainingTime,
    filteredQuarantineList,
    paginatedQuarantineList,
    handleOpenToggleVectorModal,
    handleConfirmToggleVector,
    fetchIncidents,
    handleSearchSubmit,
    handleClearIncidents,
    handleOpenQuarantineModal,
    handleConfirmQuarantine,
    handleOpenManualQuarantine,
    handleSubmitManualQuarantine,
    quarantineActionLoading,
    handleTemporaryBlockIp,
    handleUnblockIp,
    handlePermanentBanIp,
    handleTemporaryBlockAccount,
    handleUnblockAccount,
    handlePermanentBanAccount,
    handleUnblock,
    fetchForensicsLogs,
    handleOpenForensics,
    targetConcurrency,
    vectorScores,
    sample,
    isEmergencyResourceRisk,
    getVectorTheme,
    t,
  } = ops;

  return (
    <>
      <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-outline-variant pb-3">
          <div>
            <h2 className="text-sm font-bold text-on-surface m-0 flex items-center gap-2">
              {t('aiops.multiVector.title', '4 Vectơ Rủi Ro')}
            </h2>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {(() => {
            const vScore = vectorScores.auth || 0;
            const vTheme = getVectorTheme(vScore);
            const isQuarantining = quarantineList.length > 0 || vScore >= 70;
            const isEnabled = vectorConfig.auth !== false;
            return (
              <div className={`p-4 rounded-xl border flex flex-col justify-between space-y-3 transition-all ${
                isEnabled ? 'border-outline-variant/70 bg-surface-container-lowest' : 'border-slate-300 bg-slate-50/70 opacity-90'
              }`}>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-amber-600">badge</span>
                      {t('aiops.vectors.auth', '1. Xác Thực & Danh Tính')}
                    </span>
                    <button
                      type="button"
                      role="switch"
                      aria-checked={isEnabled}
                      data-testid="toggle-vector-auth"
                      onClick={() => handleOpenToggleVectorModal('auth')}
                      className={`relative inline-flex h-5 w-9 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                        isEnabled ? 'bg-emerald-600' : 'bg-slate-300'
                      }`}
                      title={isEnabled ? t('aiops.toggleVector.titleDisable', 'Xác nhận TẮT Vector') : t('aiops.toggleVector.titleEnable', 'Xác nhận BẬT Vector')}
                    >
                      <span
                        className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                          isEnabled ? 'translate-x-4' : 'translate-x-0'
                        }`}
                      />
                    </button>
                  </div>

                  {!isEnabled && (
                    <div className="px-2 py-1 rounded bg-amber-50 border border-amber-200 text-amber-900 text-[10px] font-semibold flex items-center gap-1">
                      <span className="material-symbols-outlined text-[13px] text-amber-600">visibility</span>
                      <span>{t('aiops.multiVector.measureOnlyNotice', 'Bỏ qua khỏi Threat Score')}</span>
                    </div>
                  )}

                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">{t('aiops.multiVector.pointsMax', '/ 100 điểm')}</span>
                  </div>
                  <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                    <div
                      className={`h-full ${isEnabled ? vTheme.bg : 'bg-slate-400'} transition-all duration-500`}
                      style={{ width: `${Math.min(100, Math.max(0, vScore))}%` }}
                    />
                  </div>
                </div>

                <div className="space-y-1.5 pt-2 border-t border-slate-100 text-[11px]">
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.authFailures', 'Đăng nhập lỗi:')}</span>
                    <strong className="font-mono">{sample.failedLogins ?? 0} {t('aiops.signals.times', 'lần')}</strong>
                  </div>
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.tokenReuse', 'Tái dùng token hủy:')}</span>
                    <strong className="font-mono">{sample.tokenReuseAttacks ?? 0} {t('aiops.signals.times', 'lần')}</strong>
                  </div>
                  <div className="pt-1">
                    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold border ${
                      !isEnabled
                        ? 'bg-slate-100 text-slate-600 border-slate-200'
                        : isQuarantining
                        ? 'bg-red-50 text-red-700 border-red-200'
                        : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                    }`}>
                      <span className="material-symbols-outlined text-[12px]">
                        {!isEnabled ? 'visibility' : isQuarantining ? 'lock' : 'check_circle'}
                      </span>
                      <span>
                        {!isEnabled
                          ? t('aiops.multiVector.defenseDisabled', 'Đã tắt phòng vệ — Chỉ đo lường')
                          : quarantineList.length > 0
                          ? t('aiops.multiVector.isolatingIps', `Đang cô lập ${quarantineList.length} IP vi phạm`, { count: quarantineList.length })
                          : vScore >= 70
                          ? t('aiops.multiVector.isolationActivated', 'Đã kích hoạt cô lập IP vi phạm')
                          : t('aiops.multiVector.isolationReady', 'Sẵn sàng cô lập IP vi phạm')}
                      </span>
                    </span>
                  </div>
                </div>
              </div>
            );
          })()}

          {(() => {
            const vScore = vectorScores.traffic || 0;
            const vTheme = getVectorTheme(vScore);
            const isThrottling = vScore >= 70;
            const isEnabled = vectorConfig.traffic !== false;
            return (
              <div className={`p-4 rounded-xl border flex flex-col justify-between space-y-3 transition-all ${
                isEnabled ? 'border-outline-variant/70 bg-surface-container-lowest' : 'border-slate-300 bg-slate-50/70 opacity-90'
              }`}>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-blue-600">waves</span>
                      {t('aiops.vectors.traffic', '2. Lưu Lượng & DoS')}
                    </span>
                    <button
                      type="button"
                      role="switch"
                      aria-checked={isEnabled}
                      data-testid="toggle-vector-traffic"
                      onClick={() => handleOpenToggleVectorModal('traffic')}
                      className={`relative inline-flex h-5 w-9 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                        isEnabled ? 'bg-emerald-600' : 'bg-slate-300'
                      }`}
                      title={isEnabled ? t('aiops.toggleVector.titleDisable', 'Xác nhận TẮT Vector') : t('aiops.toggleVector.titleEnable', 'Xác nhận BẬT Vector')}
                    >
                      <span
                        className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                          isEnabled ? 'translate-x-4' : 'translate-x-0'
                        }`}
                      />
                    </button>
                  </div>

                  {!isEnabled && (
                    <div className="px-2 py-1 rounded bg-amber-50 border border-amber-200 text-amber-900 text-[10px] font-semibold flex items-center gap-1">
                      <span className="material-symbols-outlined text-[13px] text-amber-600">visibility</span>
                      <span>{t('aiops.multiVector.measureOnlyNotice', 'Bỏ qua khỏi Threat Score')}</span>
                    </div>
                  )}

                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">{t('aiops.multiVector.pointsMax', '/ 100 điểm')}</span>
                  </div>
                  <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                    <div
                      className={`h-full ${isEnabled ? vTheme.bg : 'bg-slate-400'} transition-all duration-500`}
                      style={{ width: `${Math.min(100, Math.max(0, vScore))}%` }}
                    />
                  </div>
                </div>

                <div className="space-y-1.5 pt-2 border-t border-slate-100 text-[11px]">
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.currentTraffic', 'Lưu lượng hiện tại:')}</span>
                    <strong className="font-mono">{sample.requestsPerMin ?? 0} RPM</strong>
                  </div>
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.distinctIps', 'Độ phân tán IP:')}</span>
                    <strong className="font-mono">{sample.distinctIpsCount ?? 0} {t('aiops.signals.ips', 'IPs')}</strong>
                  </div>
                  <div className="pt-1">
                    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold border ${
                      !isEnabled
                        ? 'bg-slate-100 text-slate-600 border-slate-200'
                        : isThrottling
                        ? 'bg-blue-100 text-blue-800 border-blue-300'
                        : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                    }`}>
                      <span className="material-symbols-outlined text-[12px]">
                        {!isEnabled ? 'visibility' : isThrottling ? 'speed' : 'check_circle'}
                      </span>
                      <span>
                        {!isEnabled
                          ? t('aiops.multiVector.defenseDisabled', 'Đã tắt phòng vệ — Chỉ đo lường')
                          : isThrottling
                          ? t('aiops.multiVector.adaptiveThrottling', 'Đang điều tiết Adaptive Rate-Limit')
                          : t('aiops.multiVector.trafficSafe', `Lưu lượng an toàn theo chuẩn ${targetConcurrency} CCU`, { count: targetConcurrency })}
                      </span>
                    </span>
                  </div>
                </div>
              </div>
            );
          })()}

          {(() => {
            const vScore = vectorScores.exploit || 0;
            const vTheme = getVectorTheme(vScore);
            const isExploitActive = vScore >= 70;
            const isEnabled = vectorConfig.exploit !== false;
            return (
              <div className={`p-4 rounded-xl border flex flex-col justify-between space-y-3 transition-all ${
                isEnabled ? 'border-outline-variant/70 bg-surface-container-lowest' : 'border-slate-300 bg-slate-50/70 opacity-90'
              }`}>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-rose-600">bug_report</span>
                      {t('aiops.vectors.exploit', '3. Khai Thác Lỗ Hổng')}
                    </span>
                    <button
                      type="button"
                      role="switch"
                      aria-checked={isEnabled}
                      data-testid="toggle-vector-exploit"
                      onClick={() => handleOpenToggleVectorModal('exploit')}
                      className={`relative inline-flex h-5 w-9 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                        isEnabled ? 'bg-emerald-600' : 'bg-slate-300'
                      }`}
                      title={isEnabled ? t('aiops.toggleVector.titleDisable', 'Xác nhận TẮT Vector') : t('aiops.toggleVector.titleEnable', 'Xác nhận BẬT Vector')}
                    >
                      <span
                        className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                          isEnabled ? 'translate-x-4' : 'translate-x-0'
                        }`}
                      />
                    </button>
                  </div>

                  {!isEnabled && (
                    <div className="px-2 py-1 rounded bg-amber-50 border border-amber-200 text-amber-900 text-[10px] font-semibold flex items-center gap-1">
                      <span className="material-symbols-outlined text-[13px] text-amber-600">visibility</span>
                      <span>{t('aiops.multiVector.measureOnlyNotice', 'Bỏ qua khỏi Threat Score')}</span>
                    </div>
                  )}

                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">{t('aiops.multiVector.pointsMax', '/ 100 điểm')}</span>
                  </div>
                  <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                    <div
                      className={`h-full ${isEnabled ? vTheme.bg : 'bg-slate-400'} transition-all duration-500`}
                      style={{ width: `${Math.min(100, Math.max(0, vScore))}%` }}
                    />
                  </div>
                </div>

                <div className="space-y-1.5 pt-2 border-t border-slate-100 text-[11px]">
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.injectionSamples', 'Mẫu tiêm nhiễm (SQLi):')}</span>
                    <strong className="font-mono">{sample.malformedRequests ?? 0} {t('aiops.signals.samples', 'mẫu')}</strong>
                  </div>
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.traversal', 'Đường dẫn cấm/Traversal:')}</span>
                    <strong className="font-mono">{t('aiops.multiVector.autoDetected', 'Tự động phát hiện')}</strong>
                  </div>
                  <div className="pt-1">
                    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold border ${
                      !isEnabled
                        ? 'bg-slate-100 text-slate-600 border-slate-200'
                        : isExploitActive
                        ? 'bg-rose-100 text-rose-800 border-rose-300'
                        : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                    }`}>
                      <span className="material-symbols-outlined text-[12px]">
                        {!isEnabled ? 'visibility' : isExploitActive ? 'security' : 'check_circle'}
                      </span>
                      <span>
                        {!isEnabled
                          ? t('aiops.multiVector.defenseDisabled', 'Đã tắt phòng vệ — Chỉ đo lường')
                          : isExploitActive
                          ? t('aiops.multiVector.blacklisted30m', 'Đã ngắt HTTP 403 & Blacklist 30p')
                          : t('aiops.multiVector.sqliReady', 'Sẵn sàng chặn SQLi/Payload')}
                      </span>
                    </span>
                  </div>
                </div>
              </div>
            );
          })()}

          {(() => {
            const vScore = vectorScores.resource || 0;
            const vTheme = getVectorTheme(vScore);
            const isEnabled = vectorConfig.resource !== false;
            return (
              <div className={`p-4 rounded-xl border flex flex-col justify-between space-y-3 transition-all ${
                isEnabled ? 'border-outline-variant/70 bg-surface-container-lowest' : 'border-slate-300 bg-slate-50/70 opacity-90'
              }`}>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-on-surface flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-[17px] text-teal-600">memory</span>
                      {t('aiops.vectors.resource', '4. Sức Khỏe Tài Nguyên')}
                    </span>
                    <button
                      type="button"
                      role="switch"
                      aria-checked={isEnabled}
                      data-testid="toggle-vector-resource"
                      onClick={() => handleOpenToggleVectorModal('resource')}
                      className={`relative inline-flex h-5 w-9 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                        isEnabled ? 'bg-emerald-600' : 'bg-slate-300'
                      }`}
                      title={isEnabled ? t('aiops.toggleVector.titleDisable', 'Xác nhận TẮT Vector') : t('aiops.toggleVector.titleEnable', 'Xác nhận BẬT Vector')}
                    >
                      <span
                        className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                          isEnabled ? 'translate-x-4' : 'translate-x-0'
                        }`}
                      />
                    </button>
                  </div>

                  {!isEnabled && (
                    <div className="px-2 py-1 rounded bg-amber-50 border border-amber-200 text-amber-900 text-[10px] font-semibold flex items-center gap-1">
                      <span className="material-symbols-outlined text-[13px] text-amber-600">visibility</span>
                      <span>{t('aiops.multiVector.measureOnlyNotice', 'Bỏ qua khỏi Threat Score')}</span>
                    </div>
                  )}

                  <div className="flex items-baseline justify-between">
                    <span className="text-2xl font-bold font-mono text-on-surface">{vScore}</span>
                    <span className="text-[11px] text-slate-400">{t('aiops.multiVector.pointsMax', '/ 100 điểm')}</span>
                  </div>
                  <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                    <div
                      className={`h-full ${isEnabled ? vTheme.bg : 'bg-slate-400'} transition-all duration-500`}
                      style={{ width: `${Math.min(100, Math.max(0, vScore))}%` }}
                    />
                  </div>
                </div>

                <div className="space-y-1.5 pt-2 border-t border-slate-100 text-[11px]">
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.lag', 'Event Loop Lag:')}</span>
                    <strong className="font-mono">{sample.eventLoopLagMs ?? 0} {t('aiops.signals.unitMs', 'ms')}</strong>
                  </div>
                  <div className="flex justify-between text-slate-600">
                    <span>{t('aiops.multiVector.cpuRam', 'CPU / RAM:')}</span>
                    <strong className="font-mono">{sample.cpuPercent ?? 0}% / {sample.ramPercent ?? 0}%</strong>
                  </div>
                  <div className="pt-1">
                    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[10px] font-semibold border ${
                      !isEnabled
                        ? 'bg-slate-100 text-slate-600 border-slate-200'
                        : isEmergencyResourceRisk
                        ? 'bg-red-100 text-red-800 border-red-300'
                        : vScore >= 60
                        ? 'bg-amber-100 text-amber-800 border-amber-300'
                        : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                    }`}>
                      <span className="material-symbols-outlined text-[12px]">
                        {!isEnabled ? 'visibility' : isEmergencyResourceRisk ? 'crisis_alert' : vScore >= 60 ? 'tune' : 'check_circle'}
                      </span>
                      <span>
                        {!isEnabled
                          ? t('aiops.multiVector.defenseDisabled', 'Đã tắt phòng vệ — Chỉ đo lường')
                          : isEmergencyResourceRisk
                          ? t('aiops.multiVector.emergencyRecommend', '🚨 Đề xuất Bảo Trì Khẩn Cấp')
                          : vScore >= 60
                          ? t('aiops.multiVector.loadSheddingActive', 'Đang kích hoạt Load Shedding')
                          : t('aiops.multiVector.hardwareStable', 'Tài nguyên phần cứng ổn định')}
                      </span>
                    </span>
                  </div>
                </div>
              </div>
            );
          })()}
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-outline-variant p-5 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between border-b border-outline-variant pb-3 gap-3">
          <div>
            <h2 className="text-sm font-bold text-on-surface m-0 flex items-center gap-2">
              <span>{t('aiops.rca.title', 'Tổng quan nguyên nhân bất thường')}</span>
            </h2>
          </div>

          <div className="flex items-center gap-2.5">
            <span className="text-xs font-semibold px-2.5 py-1 rounded-lg bg-surface-container-low border border-outline-variant/60 flex items-center gap-1.5">
              <span className="material-symbols-outlined text-[15px] text-primary">database</span>
              <span>{t('aiops.rca.incidentsInDb', `${incidentTotal} sự cố`, { count: incidentTotal })}</span>
            </span>
          </div>
        </div>

        <div className="flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-3 pt-1">
          <div className="flex flex-wrap items-center gap-2">
            <div className="inline-flex rounded-lg border border-outline-variant/60 p-0.5 bg-surface-container-lowest text-xs">
              {[
                { key: 'all', label: t('aiops.rca.vectorAll', 'Tất cả Vector') },
                { key: 'auth', label: t('aiops.rca.vectorAuth', 'Xác thực'), icon: 'badge', color: 'text-amber-600' },
                { key: 'traffic', label: t('aiops.rca.vectorTraffic', 'Lưu lượng'), icon: 'waves', color: 'text-blue-600' },
                { key: 'exploit', label: t('aiops.rca.vectorExploit', 'Khai thác'), icon: 'bug_report', color: 'text-rose-600' },
                { key: 'resource', label: t('aiops.rca.vectorResource', 'Tài nguyên'), icon: 'memory', color: 'text-teal-600' },
              ].map((v) => (
                <button
                  key={v.key}
                  type="button"
                  onClick={() => {
                    setIncidentVectorFilter(v.key);
                    setIncidentPage(1);
                  }}
                  className={`px-2.5 py-1 rounded-md text-[11px] font-semibold transition-all cursor-pointer flex items-center gap-1 ${
                    incidentVectorFilter === v.key
                      ? 'bg-primary text-white shadow-2xs'
                      : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
                  }`}
                >
                  {v.icon && (
                    <span className={`material-symbols-outlined text-[13px] ${incidentVectorFilter === v.key ? 'text-white' : v.color}`}>
                      {v.icon}
                    </span>
                  )}
                  <span>{v.label}</span>
                </button>
              ))}
            </div>

            <div className="inline-flex rounded-lg border border-outline-variant/60 p-0.5 bg-surface-container-lowest text-xs">
              {[
                { key: 'all', label: t('aiops.rca.statusAll', 'Mọi trạng thái') },
                { key: 'ACTIVE', label: t('aiops.rca.statusActive', '🔴 Đang diễn ra') },
                { key: 'MITIGATED', label: t('aiops.rca.statusMitigated', '🟢 Đã giảm thiểu') },
              ].map((s) => (
                <button
                  key={s.key}
                  type="button"
                  onClick={() => {
                    setIncidentStatusFilter(s.key);
                    setIncidentPage(1);
                  }}
                  className={`px-2.5 py-1 rounded-md text-[11px] font-semibold transition-all cursor-pointer ${
                    incidentStatusFilter === s.key
                      ? 'bg-slate-800 text-white shadow-2xs'
                      : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
                  }`}
                >
                  {s.label}
                </button>
              ))}
            </div>
          </div>

          <form onSubmit={handleSearchSubmit} className="flex items-center gap-1.5">
            <div className="relative flex-1 sm:w-64">
              <span className="material-symbols-outlined text-[16px] text-slate-400 absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none">
                search
              </span>
              <input
                type="text"
                value={incidentSearch}
                onChange={(e) => setIncidentSearch(e.target.value)}
                placeholder={t('aiops.rca.searchPlaceholder', 'Tìm IP, Hash, User, Mã...')}
                className="w-full pl-8 pr-7 py-1 text-xs border border-outline-variant/80 rounded-lg focus:outline-none focus:border-primary bg-white text-slate-800 placeholder:text-slate-400"
              />
              {incidentSearch && (
                <button
                  type="button"
                  onClick={() => {
                    setIncidentSearch('');
                    setIncidentPage(1);
                    fetchIncidents(1, incidentPageSize, incidentVectorFilter, incidentStatusFilter, '');
                  }}
                  className="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 cursor-pointer"
                >
                  <span className="material-symbols-outlined text-[14px]">close</span>
                </button>
              )}
            </div>
            <button
              type="submit"
              className="px-3 py-1 bg-slate-100 hover:bg-slate-200 border border-outline-variant/80 rounded-lg text-xs font-semibold text-slate-700 cursor-pointer transition-colors"
            >
              {t('common.filter', 'Lọc')}
            </button>
          </form>
        </div>

        {incidentsList.length > 0 ? (
          <div className="overflow-x-auto rounded-xl border border-outline-variant/70">
            <table className="w-full text-left text-xs border-collapse min-w-[950px]">
              <thead>
                <tr className="border-b border-outline-variant/80 bg-surface-container-low/60 text-slate-600 font-bold uppercase text-[10px] tracking-wider">
                  <th className="w-[12%] min-w-[100px] py-2.5 px-3 whitespace-nowrap">
                    {t('aiops.rca.colStatus', 'Tình trạng')}
                  </th>
                  <th className="w-[18%] min-w-[140px] py-2.5 px-3 whitespace-nowrap">
                    {t('aiops.rca.colActor', 'Đối tượng')}
                  </th>
                  <th className="w-[11%] min-w-[90px] py-2.5 px-3 whitespace-nowrap">
                    {t('aiops.rca.colVector', 'Vector')}
                  </th>
                  <th className="w-[12%] min-w-[100px] py-2.5 px-3 whitespace-nowrap">
                    {t('aiops.rca.colMetric', 'Chỉ số')}
                  </th>
                  <th className="w-[23%] min-w-[170px] py-2.5 px-3">
                    {t('aiops.rca.colRootCause', 'Nguyên nhân')}
                  </th>
                  <th className="w-[14%] min-w-[120px] py-2.5 px-3">
                    {t('aiops.rca.colMitigation', 'Xử lý')}
                  </th>
                  <th className="w-[10%] min-w-[90px] py-2.5 px-3 whitespace-nowrap text-center">
                    {t('aiops.rca.colDefense', 'Phòng vệ')}
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-outline-variant/40 bg-white">
                {incidentsList.map((item) => {
                  const firstTime = item.first_detected_at || item.firstDetectedAt;
                  const lastTime = item.last_seen_at || item.lastSeenAt;
                  const status = item.status || 'ACTIVE';
                  const hits = item.hits || 1;
                  const actorIdentity = item.actor?.identity || item.actor_identity || item.actorIdentity || '192.168.xxx.xxx';
                  const actorHash = item.actor?.ipHash || item.actor_hash || item.actorHash || '';
                  const actorType = item.actor?.type || item.actor_type || 'IP_SOURCE';
                  const userId = item.actor?.userId || item.user_id || item.userId;
                  const targetAccount = item.actor?.username || item.username || item.actor?.targetAccount || item.targetAccount;
                  const username = (targetAccount && targetAccount !== 'all' && targetAccount !== 'Khách vãng lai / Ẩn danh') ? targetAccount : null;
                  const actorTargetIp = item.actor?.maskedIp || item.actor?.rawIp || actorIdentity;
                  const vector = item.vector || 'traffic';
                  const metricCurrent = item.metric_current ?? item.metricCurrent ?? item.current ?? 0;
                  const metricBaseline = item.metric_baseline ?? item.metricBaseline ?? item.baseline ?? 0;
                  const metricUnit = item.metric_unit || item.metricUnit || item.unit || '';
                  const message = item.message || '';
                  const mitigation = item.mitigation_taken || item.mitigationTaken;

                  const clientIpClean = String(myCurrentIp || '').replace(/^::ffff:/, '').trim();
                  const clientIpPrefix = clientIpClean ? clientIpClean.split('.').slice(0, 2).join('.') : '';
                  const isMyCurrentIp = Boolean(
                    clientIpClean && (
                      actorIdentity === clientIpClean ||
                      actorIdentity.replace(/^::ffff:/, '').trim() === clientIpClean ||
                      (clientIpPrefix && actorIdentity.startsWith(`${clientIpPrefix}.`)) ||
                      actorIdentity.includes(clientIpClean)
                    )
                  );

                  const isProtectedActor =
                    actorType === 'SYSTEM_INTERNAL' ||
                    vector === 'resource' ||
                    actorHash === 'system_core' ||
                    actorHash === 'system_host' ||
                    isMyCurrentIp ||
                    actorIdentity === '127.0.0.1' ||
                    actorIdentity.includes('127.0.0.1') ||
                    actorIdentity.includes('::1') ||
                    actorIdentity.includes('localhost') ||
                    actorIdentity.includes('Internal') ||
                    actorIdentity.includes('Loopback');

                  const ratio = metricBaseline > 0 ? (Number(metricCurrent) / Number(metricBaseline)).toFixed(1) : null;

                  const isQuarantined = quarantineList.some(
                    (q) => q.hash === actorHash || q.maskedIp === actorIdentity
                  );

                  return (
                    <tr key={item.id} className="hover:bg-slate-50/80 transition-colors">
                      <td className="py-3 px-3 align-top whitespace-nowrap space-y-1">
                        <div className="font-semibold text-slate-800 text-[11px]">
                          {formatDateTime(firstTime)}
                        </div>
                        <div>
                          {status === 'ACTIVE' ? (
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-50 text-rose-700 border border-rose-200/70">
                              <span className="w-1.5 h-1.5 rounded-full bg-rose-500 animate-pulse"></span>
                              {t('aiops.rca.badgeActive', 'ĐANG DIỄN RA')}
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200/70">
                              <span className="material-symbols-outlined text-[12px]">check_circle</span>
                              {t('aiops.rca.badgeMitigated', 'ĐÃ GIẢM THIỂU')}
                            </span>
                          )}
                        </div>
                        <div className="text-[10px] text-slate-500 font-medium">
                          {hits > 1 ? t('aiops.rca.repeatedTimes', `Lặp lại ${hits} lần`, { count: hits }) : t('aiops.rca.firstDetected', 'Phát hiện lần 1')}
                        </div>
                      </td>

                      <td className="py-3 px-3 align-top whitespace-nowrap space-y-1">
                        {vector === 'resource' ? (
                          <>
                            <div className="font-semibold text-slate-800 text-xs">
                              <span className="text-primary font-bold">
                                {t('aiops.rca.internalSystemLabel', 'Hệ thống')}
                              </span>
                            </div>
                            <div className="text-[11px] text-slate-600">
                              <span>{t('aiops.rca.internalSystem', 'Nội bộ hệ thống')}</span>
                            </div>
                          </>
                        ) : (
                          <>
                            <div className="font-semibold text-slate-800 text-xs">
                              <span className="text-slate-500 font-normal mr-1">TK:</span>
                              <span className="text-primary font-bold">
                                {username || (userId ? `UID #${userId}` : t('aiops.rca.anonymousUser', 'Khách vãng lai / Ẩn danh'))}
                              </span>
                            </div>
                            <div className="font-mono text-[11px] text-slate-600">
                              <span className="text-slate-400 font-normal mr-1">IP:</span>
                              <span>
                                {isMyCurrentIp
                                  ? `${formatMaskedIp(actorTargetIp)} (${t('aiops.rca.protectedMyIpLabel', 'Máy bạn')})`
                                  : (formatMaskedIp(actorTargetIp) || t('common.unknown', 'Chưa xác định'))}
                              </span>
                            </div>
                          </>
                        )}
                      </td>

                      <td className="py-3 px-3 align-top whitespace-nowrap">
                        <span
                          className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${
                            vector === 'auth'
                              ? 'bg-amber-50 text-amber-700 border border-amber-200/60'
                              : vector === 'traffic'
                              ? 'bg-blue-50 text-blue-700 border border-blue-200/60'
                              : vector === 'exploit'
                              ? 'bg-rose-50 text-rose-700 border border-rose-200/60'
                              : 'bg-teal-50 text-teal-700 border border-teal-200/60'
                          }`}
                        >
                          <span className="material-symbols-outlined text-[13px]">
                            {vector === 'auth' ? 'badge' : vector === 'traffic' ? 'waves' : vector === 'exploit' ? 'bug_report' : 'memory'}
                          </span>
                          <span>{vector}</span>
                        </span>
                      </td>

                      <td className="py-3 px-3 align-top whitespace-nowrap space-y-1">
                        <div className="font-bold text-rose-600 text-xs">
                          {metricCurrent} {metricUnit}
                        </div>
                        <div className="text-[11px] text-slate-500">
                          {t('aiops.rca.threshold', 'Ngưỡng:')} {metricBaseline} {metricUnit}
                        </div>
                        {ratio && Number(ratio) > 1 && (
                          <span className="inline-block text-[10px] font-bold px-1.5 py-0.2 rounded bg-rose-50 text-rose-700 border border-rose-200/60">
                            {t('aiops.rca.exceededRatio', `Vượt ${ratio}x`, { ratio })}
                          </span>
                        )}
                      </td>

                      <td className="py-3 px-3 align-top overflow-hidden">
                        <TruncateCell text={message} className="text-slate-800 font-medium text-xs leading-relaxed" />
                      </td>

                      <td className="py-3 px-3 align-top overflow-hidden">
                        {mitigation ? (
                          <TruncateCell text={mitigation} className="text-slate-700 text-xs font-medium leading-relaxed bg-emerald-50/70 border border-emerald-200/80 p-2 rounded-lg" />
                        ) : (
                          <span className="text-slate-400 text-xs italic">
                            {t('aiops.rca.noMitigation', 'Hệ thống đang theo dõi')}
                          </span>
                        )}
                      </td>

                      <td className="py-3 px-3 align-top text-center whitespace-nowrap">
                        {isQuarantined ? (
                          <div className="space-y-1">
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-lg text-[10px] font-bold bg-rose-50 text-rose-700 border border-rose-200/70">
                              <span className="material-symbols-outlined text-[13px]">block</span>
                              {t('aiops.rca.quarantinedShield', 'Đã cách ly Shield')}
                            </span>
                            <div>
                              <button
                                type="button"
                                onClick={() => handleUnblock(actorHash)}
                                disabled={unblockingHash === actorHash}
                                className="text-[10px] font-semibold text-slate-500 hover:text-slate-800 underline transition-colors cursor-pointer"
                                title={t('aiops.unblockTooltip', 'Mở khóa và gỡ bỏ địa chỉ IP khỏi danh sách cô lập')}
                              >
                                {unblockingHash === actorHash ? t('common.processing', 'Đang xử lý...') : t('aiops.unblockBtn', 'Gỡ chặn')}
                              </button>
                            </div>
                          </div>
                        ) : isProtectedActor ? (
                          <span className="text-[11px] font-semibold text-emerald-700">
                            {actorType === 'SYSTEM_INTERNAL' || vector === 'resource'
                              ? t('aiops.rca.internalSystem', 'Nội bộ hệ thống')
                              : isMyCurrentIp
                              ? t('aiops.rca.protectedMyIp', 'IP Máy bạn (Đang đăng nhập)')
                              : t('aiops.rca.protectedIp', 'IP Được bảo vệ')}
                          </span>
                        ) : (
                          <div>
                            <button
                              type="button"
                              onClick={() => handleOpenQuarantineModal(item)}
                              className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[10px] font-semibold bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-200/70 transition-all shadow-2xs active:scale-95 cursor-pointer"
                              title={`${t('aiops.rca.btnQuarantine', 'Phong Tỏa IP')} ${formatMaskedIp(actorTargetIp)}`}
                            >
                              <span className="material-symbols-outlined text-[13px]">shield</span>
                              <span>{t('aiops.rca.btnQuarantine', 'Phong Tỏa IP')}</span>
                            </button>
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>

            <Pagination
              currentPage={incidentPage}
              pageSize={incidentPageSize}
              total={incidentTotal}
              pageSizeOptions={[5, 10, 20, 50]}
              onPageChange={(p) => setIncidentPage(p)}
              onPageSizeChange={(s) => {
                setIncidentPageSize(s);
                setIncidentPage(1);
              }}
              itemLabel={t('aiops.rca.itemLabel', 'sự cố ghi nhận')}
            />
          </div>
        ) : (
          <div className="p-8 text-center rounded-xl bg-surface-container-low/40 border border-outline-variant/60">
            <p className="text-xs font-semibold text-slate-500 m-0">
              {t('aiops.rca.emptyCompact', 'Không tìm thấy sự cố')}
            </p>
          </div>
        )}
      </div>

      <div className="bg-white rounded-2xl border border-slate-200/80 p-5 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-100 pb-3">
          <div>
            <h2 className="text-sm font-bold text-slate-800 m-0">
              {t('aiops.quarantine.title', 'Nguồn theo dõi đặc biệt')}
            </h2>
          </div>

          <div className="flex items-center gap-2 flex-wrap">
            <button
              id="btn-open-manual-quarantine"
              type="button"
              onClick={handleOpenManualQuarantine}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-rose-600 hover:bg-rose-700 text-white rounded-lg text-xs font-bold transition-all shadow-2xs cursor-pointer active:scale-95"
              title={t('aiops.quarantine.manualBtnTitle', 'Tạm khóa thủ công địa chỉ IP hoặc tài khoản người dùng')}
            >
              <span className="material-symbols-outlined text-[16px]">lock_clock</span>
              <span>{t('aiops.quarantine.btnManualLock', 'Tạm khóa thủ công')}</span>
            </button>
          </div>
        </div>

        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-slate-50/70 p-3 rounded-xl border border-slate-200/60">
          <div className="flex flex-wrap items-center gap-2 flex-1">
            <div className="relative min-w-[170px] flex-1 sm:max-w-xs">
              <span className="material-symbols-outlined absolute left-2.5 top-2 text-slate-400 text-[16px]">search</span>
              <input
                type="text"
                data-testid="quarantine-ip-filter-input"
                placeholder={t('aiops.quarantine.filterIpPlaceholder', 'Lọc theo IP...')}
                value={quarantineIpFilter}
                onChange={(e) => {
                  setQuarantineIpFilter(e.target.value);
                  setQuarantinePage(1);
                }}
                className="w-full bg-white border border-slate-300 rounded-lg pl-8 pr-3 py-1.5 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-primary"
              />
            </div>

            <div className="relative min-w-[170px] flex-1 sm:max-w-xs">
              <span className="material-symbols-outlined absolute left-2.5 top-2 text-slate-400 text-[16px]">person_search</span>
              <input
                type="text"
                data-testid="quarantine-account-filter-input"
                placeholder={t('aiops.quarantine.filterAccountPlaceholder', 'Lọc theo Tài khoản...')}
                value={quarantineAccountFilter}
                onChange={(e) => {
                  setQuarantineAccountFilter(e.target.value);
                  setQuarantinePage(1);
                }}
                className="w-full bg-white border border-slate-300 rounded-lg pl-8 pr-3 py-1.5 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-primary"
              />
            </div>

            {(quarantineIpFilter || quarantineAccountFilter) && (
              <button
                type="button"
                data-testid="clear-quarantine-filter-btn"
                onClick={() => {
                  setQuarantineIpFilter('');
                  setQuarantineAccountFilter('');
                  setQuarantinePage(1);
                }}
                className="inline-flex items-center gap-1 px-2.5 py-1.5 bg-white hover:bg-slate-100 text-slate-700 border border-slate-300 rounded-lg text-xs font-medium transition-all cursor-pointer shadow-2xs"
              >
                <span className="material-symbols-outlined text-[14px]">close</span>
                <span>{t('common.clearFilter', 'Xóa lọc')}</span>
              </button>
            )}
          </div>
        </div>

        {quarantineList.length > 0 ? (
          filteredQuarantineList.length > 0 ? (
          <div className="rounded-xl border border-slate-200/80 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs border-collapse">
                <thead>
                  <tr className="border-b border-slate-200 bg-slate-50/70 text-slate-600 font-bold uppercase text-[10px] tracking-wider">
                    <th className="py-2.5 px-3 whitespace-nowrap">{t('aiops.quarantine.colIp', 'Địa chỉ IP')}</th>
                    <th className="py-2.5 px-3 whitespace-nowrap">{t('aiops.quarantine.colAccount', 'Tài khoản')}</th>
                    <th className="py-2.5 px-3 whitespace-nowrap">Vector</th>
                    <th className="py-2.5 px-3">{t('aiops.quarantine.colReason', 'Nguyên nhân phong tỏa')}</th>
                    <th className="py-2.5 px-3 whitespace-nowrap">{t('aiops.quarantine.colTime', 'Thời điểm chặn')}</th>
                    <th className="py-2.5 px-3 whitespace-nowrap">{t('aiops.quarantine.colRemaining', 'Thời gian còn lại')}</th>
                    <th className="py-2.5 px-3 text-center whitespace-nowrap">{t('aiops.quarantine.colIpActions', 'Thao tác IP')}</th>
                    <th className="py-2.5 px-3 text-center whitespace-nowrap">{t('aiops.quarantine.colAccountActions', 'Thao tác Tài khoản')}</th>
                    <th className="py-2.5 px-3 text-center whitespace-nowrap">Thao tác</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 bg-white">
                  {paginatedQuarantineList.map((item, idx) => {
                    const targetIpHash = item.ipHash || item.hash;
                    const targetAccount = item.username || item.idaccount;
                    const currentClientTime = Date.now();

                    const isIpTemp = item.ipStatus === 'temporary' || item.ipStatus === 'temp';
                    const isAccountTemp = item.accountStatus === 'temporary' || item.accountStatus === 'temp';

                    let isIpExpired = false;
                    let effectiveIpMin = null;
                    if (isIpTemp) {
                      if (item.ipExpiresAt) {
                        const diffMs = new Date(item.ipExpiresAt).getTime() - currentClientTime;
                        effectiveIpMin = Math.ceil(diffMs / 60000);
                        if (effectiveIpMin <= 0) {
                          isIpExpired = true;
                          effectiveIpMin = null;
                        }
                      } else if (item.ipRemainingMinutes !== undefined && item.ipRemainingMinutes !== null) {
                        effectiveIpMin = item.ipRemainingMinutes;
                        if (effectiveIpMin <= 0) {
                          isIpExpired = true;
                          effectiveIpMin = null;
                        }
                      } else if (item.remainingMinutes !== undefined && item.remainingMinutes !== null) {
                        effectiveIpMin = item.remainingMinutes;
                        if (effectiveIpMin <= 0) {
                          isIpExpired = true;
                          effectiveIpMin = null;
                        }
                      } else {
                        isIpExpired = true;
                      }
                    }

                    let isAccountExpired = false;
                    let effectiveAccountMin = null;
                    if (isAccountTemp) {
                      if (item.accountExpiresAt) {
                        const diffMs = new Date(item.accountExpiresAt).getTime() - currentClientTime;
                        effectiveAccountMin = Math.ceil(diffMs / 60000);
                        if (effectiveAccountMin <= 0) {
                          isAccountExpired = true;
                          effectiveAccountMin = null;
                        }
                      } else if (item.accountRemainingMinutes !== undefined && item.accountRemainingMinutes !== null) {
                        effectiveAccountMin = item.accountRemainingMinutes;
                        if (effectiveAccountMin <= 0) {
                          isAccountExpired = true;
                          effectiveAccountMin = null;
                        }
                      } else if (item.remainingMinutes !== undefined && item.remainingMinutes !== null) {
                        effectiveAccountMin = item.remainingMinutes;
                        if (effectiveAccountMin <= 0) {
                          isAccountExpired = true;
                          effectiveAccountMin = null;
                        }
                      } else {
                        isAccountExpired = true;
                      }
                    }

                    const isIpPermanent = item.ipStatus === 'permanent';
                    const isIpUnlocked = item.ipStatus === 'unlocked' || isIpExpired;

                    const isAccountPermanent = item.accountStatus === 'permanent';
                    const isAccountUnlocked = item.accountStatus === 'unlocked' || isAccountExpired;
                    const vector = item.vector || 'auth';
                    const rowKey = `quarantine-${item.id || item.ipHash || item.hash || 'row'}-${item.username || 'acc'}-${item.bannedAt || ''}-${idx}`;

                    return (
                      <tr key={rowKey} className="hover:bg-slate-50/60 transition-colors">
                        <td className="py-3 px-3 font-mono font-medium text-slate-700 whitespace-nowrap">
                          {formatMaskedIp(item.maskedIp || item.ip || item.raw_ip) || '192.168.xxx.xxx'}
                        </td>

                        <td className="py-3 px-3 font-mono font-medium text-slate-700 whitespace-nowrap">
                          {targetAccount || '--'}
                        </td>

                        <td className="py-3 px-3 whitespace-nowrap">
                          <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${
                            vector === 'auth'
                              ? 'bg-purple-50 text-purple-700 border border-purple-200/60'
                              : vector === 'exploit'
                              ? 'bg-rose-50 text-rose-700 border border-rose-200/60'
                              : 'bg-blue-50 text-blue-700 border border-blue-200/60'
                          }`}>
                            {vector === 'auth' ? 'Xác thực' : vector === 'exploit' ? 'Khai thác' : 'Lưu lượng'}
                          </span>
                        </td>

                        <td className="py-3 px-3 text-slate-700 max-w-xs font-normal" title={item.reason}>
                          <span className="truncate block max-w-[200px]">
                            {item.reason || '--'}
                          </span>
                        </td>

                        <td className="py-3 px-3 text-slate-500 whitespace-nowrap">
                          {item.bannedAt ? formatDateTime(item.bannedAt) : t('common.justNow', 'Vừa xong')}
                        </td>

                        <td className="py-2.5 px-3 whitespace-nowrap">
                          <div className="flex flex-col gap-1 items-start text-[10px]">
                            {!isIpPermanent && !isIpUnlocked && effectiveIpMin && effectiveIpMin > 0 ? (
                              <span className="px-1.5 py-0.5 rounded font-bold bg-amber-50 text-amber-700 border border-amber-200/60 inline-flex items-center gap-1">
                                <span className="font-semibold text-slate-500">IP:</span>
                                <span>{formatRemainingTime(effectiveIpMin)}</span>
                              </span>
                            ) : (
                              <span className="text-slate-400 font-medium px-1">
                                IP: --
                              </span>
                            )}

                            {targetAccount && targetAccount !== '--' ? (
                              !isAccountPermanent && !isAccountUnlocked && effectiveAccountMin && effectiveAccountMin > 0 ? (
                                <span className="px-1.5 py-0.5 rounded font-bold bg-amber-50 text-amber-700 border border-amber-200/60 inline-flex items-center gap-1">
                                  <span className="font-semibold text-slate-500">TK:</span>
                                  <span>{formatRemainingTime(effectiveAccountMin)}</span>
                                </span>
                              ) : (
                                <span className="text-slate-400 font-medium px-1">
                                  TK: --
                                </span>
                              )
                            ) : (
                              <span className="text-slate-400 font-medium px-1">
                                TK: --
                              </span>
                            )}
                          </div>
                        </td>

                        <td className="py-3 px-3 text-center whitespace-nowrap">
                          {isIpPermanent ? (
                            <span className="px-2.5 py-1 rounded-md text-[11px] font-semibold bg-rose-50 text-rose-700 border border-rose-200/60 inline-block">
                              IP đã bị phong tỏa
                            </span>
                          ) : isIpUnlocked ? (
                            <button
                              type="button"
                              onClick={() => handleTemporaryBlockIp(targetIpHash, item.maskedIp)}
                              disabled={quarantineActionLoading === `temp_ip_${targetIpHash}`}
                              className="px-2.5 py-1 bg-amber-50 hover:bg-amber-100 text-amber-700 border border-amber-200/70 rounded-lg text-[11px] font-semibold transition-all cursor-pointer shadow-2xs disabled:opacity-50"
                            >
                              Tạm khóa IP
                            </button>
                          ) : (
                            <div className="inline-flex items-center gap-1.5">
                              <button
                                type="button"
                                onClick={() => handlePermanentBanIp(targetIpHash, item.maskedIp)}
                                disabled={quarantineActionLoading === `ban_ip_${targetIpHash}`}
                                className="px-2.5 py-1 bg-amber-50 hover:bg-amber-100 text-amber-700 border border-amber-200/70 rounded-lg text-[11px] font-semibold transition-all cursor-pointer shadow-2xs disabled:opacity-50"
                              >
                                Tạm khóa IP (4h)
                              </button>
                              <button
                                type="button"
                                onClick={() => handleUnblockIp(targetIpHash, item.maskedIp)}
                                disabled={quarantineActionLoading === `unblock_ip_${targetIpHash}`}
                                className="px-2.5 py-1 bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200/70 rounded-lg text-[11px] font-semibold transition-all cursor-pointer shadow-2xs disabled:opacity-50"
                              >
                                Mở khóa IP
                              </button>
                            </div>
                          )}
                        </td>

                        <td className="py-3 px-3 text-center whitespace-nowrap">
                          {targetAccount ? (
                            isAccountPermanent ? (
                              <span className="px-2.5 py-1 rounded-md text-[11px] font-semibold bg-rose-50 text-rose-700 border border-rose-200/60 inline-block">
                                Tài khoản đã bị phong tỏa
                              </span>
                            ) : isAccountUnlocked ? (
                              <button
                                type="button"
                                onClick={() => handleTemporaryBlockAccount(item.username, item.idaccount)}
                                disabled={quarantineActionLoading === `temp_acc_${targetAccount}`}
                                className="px-2.5 py-1 bg-amber-50 hover:bg-amber-100 text-amber-700 border border-amber-200/70 rounded-lg text-[11px] font-semibold transition-all cursor-pointer shadow-2xs disabled:opacity-50"
                              >
                                Tạm khóa TK
                              </button>
                            ) : (
                              <div className="inline-flex items-center gap-1.5">
                                <button
                                  type="button"
                                  onClick={() => handlePermanentBanAccount(item.username, item.idaccount)}
                                  disabled={quarantineActionLoading === `ban_acc_${targetAccount}`}
                                  className="px-2.5 py-1 bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-200/70 rounded-lg text-[11px] font-semibold transition-all cursor-pointer shadow-2xs disabled:opacity-50"
                                >
                                  Phong tỏa TK
                                </button>
                                <button
                                  type="button"
                                  onClick={() => handleUnblockAccount(item.username, item.idaccount)}
                                  disabled={quarantineActionLoading === `unblock_acc_${targetAccount}`}
                                  className="px-2.5 py-1 bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200/70 rounded-lg text-[11px] font-semibold transition-all cursor-pointer shadow-2xs disabled:opacity-50"
                                >
                                  Mở khóa TK
                                </button>
                              </div>
                            )
                          ) : (
                            <span className="text-slate-400 font-normal italic">--</span>
                          )}
                        </td>

                        <td className="py-3 px-3 text-center whitespace-nowrap">
                          <button
                            type="button"
                            onClick={() => handleOpenForensics(targetIpHash, item.maskedIp, targetAccount)}
                            className="w-7 h-7 rounded-lg bg-blue-50 hover:bg-blue-100 text-blue-600 border border-blue-200 flex items-center justify-center transition-all cursor-pointer mx-auto shadow-2xs"
                            title={t('aiops.quarantine.viewForensicsTitle', 'Mở hồ sơ điều tra an ninh')}
                            data-testid={`forensics-action-btn-${targetIpHash || idx}`}
                          >
                            <span className="material-symbols-outlined text-[16px]">visibility</span>
                          </button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            <Pagination
              currentPage={quarantinePage}
              pageSize={quarantinePageSize}
              total={filteredQuarantineList.length}
              pageSizeOptions={[5, 10, 20]}
              onPageChange={(p) => setQuarantinePage(p)}
              onPageSizeChange={(s) => {
                setQuarantinePageSize(s);
                setQuarantinePage(1);
              }}
              itemLabel={t('aiops.quarantine.itemLabel', 'nguồn theo dõi')}
            />
          </div>
          ) : (
            <div className="p-8 text-center rounded-xl bg-slate-50/80 border border-slate-200/60 space-y-2">
              <span className="material-symbols-outlined text-[32px] text-slate-400">filter_alt_off</span>
              <p className="font-bold text-xs text-slate-700 m-0">
                {t('aiops.quarantine.noFilteredResults', 'Không tìm thấy nguồn nào khớp với bộ lọc IP / Tài khoản')}
              </p>
              <p className="text-[11px] text-slate-500 m-0">
                {t('aiops.quarantine.noFilteredResultsDesc', 'Hãy thử điều chỉnh từ khóa tìm kiếm hoặc bấm Xóa lọc để xem toàn bộ danh sách.')}
              </p>
            </div>
          )
        ) : (
          <div className="p-6 text-center rounded-xl bg-slate-50/80 border border-slate-200/60 space-y-2">
            <span className="material-symbols-outlined text-[36px] text-emerald-600">gpp_good</span>
            <p className="font-bold text-xs text-slate-800">{t('aiops.quarantine.emptyTitle', 'Không có nguồn nào trong danh sách theo dõi đặc biệt')}</p>
            <p className="text-[11px] text-slate-500 max-w-md mx-auto">
              {t('aiops.quarantine.emptyDesc', 'AIOps Sentinel liên tục theo dõi và sẵn sàng kích hoạt tường lửa tức thì nếu phát hiện nguồn bất thường.')}
            </p>
          </div>
        )}
      </div>

      
      <ConfirmModal
        open={showClearIncidentsModal}
        onConfirm={handleClearIncidents}
        onCancel={() => setShowClearIncidentsModal(false)}
        title={t('aiops.confirmCleanDbTitle', 'Làm sạch Toàn bộ Nhật ký Sự cố CSDL')}
        message={t('aiops.confirmCleanDbMsg', 'Bạn có chắc chắn muốn xóa toàn bộ lịch sử sự cố AIOps trong CSDL PostgreSQL? Thao tác này chỉ dùng khi hoàn tất nghiệm thu kiểm thử hoặc bảo trì hệ thống. Hành động này không thể hoàn tác.')}
        confirmDanger={true}
        confirmText={t('aiops.confirmCleanDbBtn', 'Xác nhận Xóa CSDL')}
        cancelText={t('common.cancel', 'Hủy bỏ')}
        loading={clearingIncidents}
      />

      <ConfirmModal
        open={quarantineModalTarget !== null}
        onConfirm={handleConfirmQuarantine}
        onCancel={() => setQuarantineModalTarget(null)}
        title={t('aiops.confirmQuarantineTitle', 'Xác nhận Phong Tỏa Nguồn IP (Active Quarantine)')}
        message={
          quarantineModalTarget
            ? t('aiops.confirmQuarantineMsg', `Bạn có chắc chắn muốn kích hoạt Khiên Chắn Active Quarantine cô lập kết nối từ nguồn IP [${
                formatMaskedIp(quarantineModalTarget.actor?.maskedIp || quarantineModalTarget.actor?.rawIp || quarantineModalTarget.actor_identity || quarantineModalTarget.actorIdentity || '192.168.xxx.xxx')
              }]${
                quarantineModalTarget.actor_hash || quarantineModalTarget.actorHash
                  ? ` (Hash: #${(quarantineModalTarget.actor_hash || quarantineModalTarget.actorHash).slice(0, 8)})`
                  : ''
              } trong vòng 4 giờ? Mọi request từ IP này sẽ bị ngắt kết nối với mã lỗi HTTP 403.`, {
                ip: formatMaskedIp(quarantineModalTarget.actor?.maskedIp || quarantineModalTarget.actor?.rawIp || quarantineModalTarget.actor_identity || quarantineModalTarget.actorIdentity || '192.168.xxx.xxx'),
                hash: quarantineModalTarget.actor_hash || quarantineModalTarget.actorHash
                  ? ` (Hash: #${(quarantineModalTarget.actor_hash || quarantineModalTarget.actorHash).slice(0, 8)})`
                  : ''
              })
            : ''
        }
        confirmDanger={true}
        confirmText={quarantiningActor ? t('common.processing', 'Đang xử lý...') : t('aiops.confirmQuarantineBtn', 'Xác Nhận Phong Tỏa')}
        cancelText={t('common.cancel', 'Hủy bỏ')}
        loading={quarantiningActor}
      />

      <ConfirmModal
        open={vectorToggleModal.open}
        onConfirm={handleConfirmToggleVector}
        onCancel={() => setVectorToggleModal({ open: false, vector: null, targetState: false, vectorName: '', loading: false })}
        title={vectorToggleModal.targetState ? t('aiops.toggleVector.titleEnable', 'Xác nhận BẬT Vector') : t('aiops.toggleVector.titleDisable', 'Xác nhận TẮT Vector')}
        message={
          vectorToggleModal.targetState
            ? t('aiops.toggleVector.messageEnable', `Bạn có chắc chắn muốn BẬT lại "${vectorToggleModal.vectorName}"? Vector này sẽ được tính vào Threat Score tổng hợp và kích hoạt các phản ứng phòng vệ tự động khi vượt ngưỡng an toàn.`, { name: vectorToggleModal.vectorName })
            : t('aiops.toggleVector.messageDisable', `Bạn có chắc chắn muốn TẮT "${vectorToggleModal.vectorName}"? Hệ thống VẪN TIẾP TỤC ĐO LƯỜNG thông số để bạn quan sát, nhưng HOÀN TOÀN KHÔNG TÍNH vào Threat Score chung và KHÔNG kích hoạt phản ứng phòng vệ cho vector này.`, { name: vectorToggleModal.vectorName })
        }
        confirmDanger={!vectorToggleModal.targetState}
        confirmText={
          vectorToggleModal.loading
            ? t('common.processing', 'Đang xử lý...')
            : vectorToggleModal.targetState
            ? t('aiops.toggleVector.confirmEnable', 'Xác nhận BẬT')
            : t('aiops.toggleVector.confirmDisable', 'Xác nhận TẮT')
        }
        cancelText={t('common.cancel', 'Hủy bỏ')}
        loading={vectorToggleModal.loading}
      />

      {forensicsModal.open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-xs p-4" data-testid="forensics-modal">
          <div className="bg-white rounded-2xl max-w-3xl w-full p-6 shadow-xl border border-slate-200 space-y-4 animate-in fade-in zoom-in-95 duration-150 flex flex-col max-h-[90vh]">
            <div className="flex items-start justify-between border-b border-slate-100 pb-3">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-blue-100 text-blue-700 flex items-center justify-center flex-shrink-0">
                  <span className="material-symbols-outlined text-[24px]">policy</span>
                </div>
                <div>
                  <h3 className="text-base font-bold text-slate-900 m-0">
                    {t('aiops.forensics.modalTitle', 'Hồ Sơ Điều Tra An Ninh (AIOps Security Forensics)')}
                  </h3>
                  <p className="text-xs text-slate-500 mt-0.5 m-0">
                    {t('aiops.forensics.modalDesc', 'Truy vết liên kết vi phạm N-N giữa Địa chỉ IP và Danh tính Tài khoản đã được lưu trữ bền vững')}
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setForensicsModal(prev => ({ ...prev, open: false }))}
                className="text-slate-400 hover:text-slate-600 p-1 rounded-lg hover:bg-slate-100 transition-colors cursor-pointer"
              >
                <span className="material-symbols-outlined text-[20px]">close</span>
              </button>
            </div>

            <div className="flex flex-wrap items-center justify-between gap-3 bg-slate-50 p-3 rounded-xl border border-slate-200/70">
              <div className="flex items-center gap-3 text-xs">
                <div className="flex items-center gap-1 font-mono">
                  <span className="text-slate-500">IP:</span>
                  <span className="font-bold text-slate-800 bg-white px-2 py-0.5 rounded border border-slate-200">
                    {forensicsModal.maskedIp || 'N/A'}
                  </span>
                </div>
                {forensicsModal.username && forensicsModal.username !== 'N/A' && forensicsModal.username !== 'all' && (
                  <div className="flex items-center gap-1 font-mono">
                    <span className="text-slate-500">Tài khoản:</span>
                    <span className="font-bold text-blue-700 bg-white px-2 py-0.5 rounded border border-blue-200">
                      {forensicsModal.username}
                    </span>
                  </div>
                )}
              </div>

              <div className="flex items-center gap-1.5 text-xs">
                <button
                  type="button"
                  onClick={() => fetchForensicsLogs(forensicsModal.ipHash, forensicsModal.username, 1, 'all')}
                  className={`px-2.5 py-1 rounded-lg font-semibold transition-all cursor-pointer ${
                    forensicsModal.activeFilter === 'all'
                      ? 'bg-blue-600 text-white shadow-xs'
                      : 'bg-white text-slate-700 hover:bg-slate-100 border border-slate-200'
                  }`}
                >
                  {t('aiops.forensics.filterAll', 'Tất cả liên kết')}
                </button>
                {forensicsModal.ipHash && (
                  <button
                    type="button"
                    onClick={() => fetchForensicsLogs(forensicsModal.ipHash, forensicsModal.username, 1, 'ip')}
                    className={`px-2.5 py-1 rounded-lg font-semibold transition-all cursor-pointer ${
                      forensicsModal.activeFilter === 'ip'
                        ? 'bg-blue-600 text-white shadow-xs'
                        : 'bg-white text-slate-700 hover:bg-slate-100 border border-slate-200'
                    }`}
                  >
                    {t('aiops.forensics.filterIpOnly', 'Theo IP này')}
                  </button>
                )}
                {forensicsModal.username && forensicsModal.username !== 'N/A' && forensicsModal.username !== 'all' && (
                  <button
                    type="button"
                    onClick={() => fetchForensicsLogs(forensicsModal.ipHash, forensicsModal.username, 1, 'username')}
                    className={`px-2.5 py-1 rounded-lg font-semibold transition-all cursor-pointer ${
                      forensicsModal.activeFilter === 'username'
                        ? 'bg-blue-600 text-white shadow-xs'
                        : 'bg-white text-slate-700 hover:bg-slate-100 border border-slate-200'
                    }`}
                  >
                    {t('aiops.forensics.filterUserOnly', 'Theo TK này')}
                  </button>
                )}
              </div>
            </div>

            <div className="overflow-y-auto flex-1 min-h-[200px]">
              {forensicsModal.loading ? (
                <div className="flex flex-col items-center justify-center h-48 space-y-2 text-slate-500">
                  <span className="material-symbols-outlined text-[32px] animate-spin text-blue-600">sync</span>
                  <span className="text-xs">{t('common.loading', 'Đang nạp hồ sơ điều tra an ninh...')}</span>
                </div>
              ) : forensicsModal.incidents.length > 0 ? (
                <table className="w-full text-left text-xs border-collapse">
                  <thead>
                    <tr className="border-b border-slate-200 bg-slate-100/70 text-slate-700 font-bold uppercase text-[10px] tracking-wider sticky top-0">
                      <th className="py-2.5 px-3">Mã sự cố</th>
                      <th className="py-2.5 px-3">Thời điểm phát hiện</th>
                      <th className="py-2.5 px-3">IP Hash</th>
                      <th className="py-2.5 px-3">Tài khoản vi phạm</th>
                      <th className="py-2.5 px-3">Lý do & Hành vi</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 font-mono">
                    {forensicsModal.incidents.map((incident, idx) => (
                      <tr key={incident.id || idx} className="hover:bg-slate-50 transition-colors">
                        <td className="py-2.5 px-3 font-bold text-slate-800">
                          {incident.incident_code || `#INC-${incident.id}`}
                        </td>
                        <td className="py-2.5 px-3 text-slate-500 font-sans">
                          {incident.detected_at ? formatDateTime(incident.detected_at) : '--'}
                        </td>
                        <td className="py-2.5 px-3 text-slate-700">
                          {incident.ip_hash ? `${incident.ip_hash.slice(0, 10)}...` : '--'}
                        </td>
                        <td className="py-2.5 px-3 font-bold text-blue-700">
                          {incident.username || 'N/A'}
                        </td>
                        <td className="py-2.5 px-3 font-sans font-medium text-slate-800">
                          {incident.reason || '--'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <div className="p-8 text-center rounded-xl bg-slate-50 border border-slate-200/60 space-y-2">
                  <span className="material-symbols-outlined text-[36px] text-slate-400">inventory_2</span>
                  <p className="font-bold text-xs text-slate-700 m-0">
                    {t('aiops.forensics.emptyTitle', 'Chưa có nhật ký sự cố liên đới nào trong CSDL')}
                  </p>
                  <p className="text-[11px] text-slate-500 m-0">
                    {t('aiops.forensics.emptyDesc', 'Hệ thống tự động ghi nhận dữ liệu liên kết N-N khi có hành vi bất thường phát sinh.')}
                  </p>
                </div>
              )}
            </div>

            <div className="flex items-center justify-between pt-3 border-t border-slate-100 text-xs">
              <span className="text-slate-500 font-medium">
                {t('aiops.forensics.totalCount', `Tổng số: ${forensicsModal.total} sự cố liên đới`, { count: forensicsModal.total })}
              </span>
              <button
                type="button"
                onClick={() => setForensicsModal(prev => ({ ...prev, open: false }))}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl font-bold transition-all cursor-pointer"
              >
                {t('common.close', 'Đóng')}
              </button>
            </div>
          </div>
        </div>
      )}

      {showManualQuarantineModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs animate-fadeIn">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-200 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div className="flex items-center gap-2 text-rose-600 font-bold text-base">
                <span className="material-symbols-outlined text-[24px]">lock_clock</span>
                <h3>{t('aiops.quarantine.manualModalTitle', 'Tạm Khóa An Ninh Thủ Công')}</h3>
              </div>
              <button
                type="button"
                onClick={() => setShowManualQuarantineModal(false)}
                className="text-slate-400 hover:text-slate-600 cursor-pointer"
              >
                <span className="material-symbols-outlined text-[20px]">close</span>
              </button>
            </div>

            <form onSubmit={handleSubmitManualQuarantine} className="space-y-4 text-xs">
              <div>
                <label className="block font-bold text-slate-700 mb-1.5">
                  {t('aiops.quarantine.targetTypeLabel', 'Chọn loại đối tượng cần tạm khóa:')}
                </label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setManualQuarantineForm(prev => ({ ...prev, targetType: 'ip' }))}
                    className={`py-2 px-3 rounded-xl border text-center font-bold flex items-center justify-center gap-1.5 cursor-pointer transition-all ${
                      manualQuarantineForm.targetType === 'ip'
                        ? 'bg-rose-50 border-rose-300 text-rose-700 shadow-2xs'
                        : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    <span className="material-symbols-outlined text-[16px]">public</span>
                    <span>Địa chỉ IP</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setManualQuarantineForm(prev => ({ ...prev, targetType: 'account' }))}
                    className={`py-2 px-3 rounded-xl border text-center font-bold flex items-center justify-center gap-1.5 cursor-pointer transition-all ${
                      manualQuarantineForm.targetType === 'account'
                        ? 'bg-rose-50 border-rose-300 text-rose-700 shadow-2xs'
                        : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    <span className="material-symbols-outlined text-[16px]">person</span>
                    <span>Tài khoản</span>
                  </button>
                </div>
              </div>

              {manualQuarantineForm.targetType === 'ip' ? (
                <div>
                  <label className="block font-bold text-slate-700 mb-1">
                    {t('aiops.quarantine.ipInputLabel', 'Địa chỉ IP (IPv4 / IPv6):')}
                  </label>
                  <input
                    type="text"
                    data-testid="manual-quarantine-ip-input"
                    placeholder="VD: 192.168.1.100 hoặc 203.113.152.12"
                    value={manualQuarantineForm.ipValue}
                    onChange={(e) => setManualQuarantineForm(prev => ({ ...prev, ipValue: e.target.value }))}
                    className="w-full bg-slate-50 border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-800 font-mono focus:bg-white focus:outline-none focus:ring-1 focus:ring-rose-500"
                    autoFocus
                  />
                  <p className="text-[10px] text-slate-500 mt-1">
                    * IP sẽ bị chặn ngay tại tầng mạng và đưa vào danh sách cô lập an ninh.
                  </p>
                </div>
              ) : (
                <div>
                  <label className="block font-bold text-slate-700 mb-1">
                    {t('aiops.quarantine.accountInputLabel', 'Tên đăng nhập (Username) hoặc ID Tài khoản:')}
                  </label>
                  <input
                    type="text"
                    data-testid="manual-quarantine-account-input"
                    placeholder="VD: user_test hoặc id 123"
                    value={manualQuarantineForm.accountValue}
                    onChange={(e) => setManualQuarantineForm(prev => ({ ...prev, accountValue: e.target.value }))}
                    className="w-full bg-slate-50 border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-800 focus:bg-white focus:outline-none focus:ring-1 focus:ring-rose-500"
                    autoFocus
                  />
                  <p className="text-[10px] text-slate-500 mt-1">
                    * Tài khoản sẽ bị khóa tạm thời trong CSDL (status = Locked) ngăn đăng nhập.
                  </p>
                </div>
              )}

              <div>
                <label className="block font-bold text-slate-700 mb-1">
                  {t('aiops.quarantine.durationLabel', 'Thời hạn tạm khóa:')}
                </label>
                <select
                  data-testid="manual-quarantine-duration-select"
                  value={manualQuarantineForm.durationMinutes}
                  onChange={(e) => setManualQuarantineForm(prev => ({ ...prev, durationMinutes: Number(e.target.value) }))}
                  className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-rose-500 cursor-pointer"
                >
                  <option value={60}>1 giờ (60 phút)</option>
                  <option value={240}>4 giờ (240 phút - Chuẩn an ninh)</option>
                  <option value={720}>12 giờ (720 phút)</option>
                  <option value={1440}>24 giờ (1 ngày)</option>
                </select>
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">
                  {t('aiops.quarantine.reasonLabel', 'Lý do tạm khóa an ninh:')}
                </label>
                <textarea
                  rows={2}
                  data-testid="manual-quarantine-reason-input"
                  placeholder="Ghi chú lý do..."
                  value={manualQuarantineForm.reason}
                  onChange={(e) => setManualQuarantineForm(prev => ({ ...prev, reason: e.target.value }))}
                  className="w-full bg-slate-50 border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-800 focus:bg-white focus:outline-none focus:ring-1 focus:ring-rose-500"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setShowManualQuarantineModal(false)}
                  className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl font-bold cursor-pointer transition-colors"
                >
                  {t('common.cancel', 'Hủy')}
                </button>
                <button
                  type="submit"
                  data-testid="submit-manual-quarantine-btn"
                  disabled={manualQuarantineLoading}
                  className="px-4 py-2 bg-rose-600 hover:bg-rose-700 text-white rounded-xl font-bold shadow-xs cursor-pointer transition-all disabled:opacity-50 inline-flex items-center gap-1.5"
                >
                  {manualQuarantineLoading && <span className="material-symbols-outlined text-[16px] animate-spin">sync</span>}
                  <span>{manualQuarantineLoading ? t('common.processing', 'Đang xử lý...') : t('aiops.quarantine.btnConfirmLock', 'Xác nhận Tạm khóa')}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
};

export default LegacySections;
