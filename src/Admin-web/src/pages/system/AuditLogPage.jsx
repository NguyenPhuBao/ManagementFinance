import React, { useState, useEffect, useCallback } from 'react';
import adminApi from '../../api/admin.api';
import Pagination from '../../components/common/Pagination';
import useSocket from '../../hooks/useSocket';
import { useLanguageSafe } from '../../store/language.context';
import { classifyAuditAction } from '../../utils/audit-tags.util';
import { exportToCsv } from '../../utils/csv-exporter.util';
import { formatFullDateTime } from '../../utils/format';
import useResizableColumns from '../../hooks/useResizableColumns';
import ResizableTh from '../../components/common/ResizableTh';
import TruncateCell from '../../components/common/TruncateCell';

const DEFAULT_AUDIT_COL_WIDTHS = {
  id: 80,
  account: 200,
  request: 260,
  status: 120,
  reason: 200,
  timeReq: 150,
  timeRes: 150,
};

const STATUS_CONFIG = {
  Pass: { bg: 'bg-[#dcfce7]', text: 'text-[#166534]', border: 'border-[#86efac]' },
  Fail: { bg: 'bg-[#fef2f2]', text: 'text-[#b91c1c]', border: 'border-[#fecaca]' },
  Rejected: { bg: 'bg-[#fee2e2]', text: 'text-[#991b1b]', border: 'border-[#fca5a5]' },
  Interrupted: { bg: 'bg-[#fef9c3]', text: 'text-[#854d0e]', border: 'border-[#fef08a]' },
  Accepted: { bg: 'bg-[#ccfbf1]', text: 'text-[#115e59]', border: 'border-[#99f6e4]' },
  Processing: { bg: 'bg-[#dbeafe]', text: 'text-[#1e40af]', border: 'border-[#93c5fd]' },
  Pending: { bg: 'bg-[#f3e8ff]', text: 'text-[#6b21a8]', border: 'border-[#d8b4fe]' },
};

const STATUSES = ['', 'Pass', 'Fail', 'Rejected', 'Interrupted', 'Accepted', 'Processing', 'Pending'];

const AuditLogPage = () => {
  const { t, currentLang } = useLanguageSafe();
  const [logs, setLogs] = useState([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);
  const [search, setSearch] = useState('');

  const { widths: colWidths, startResizing, resetColumn } = useResizableColumns({
    tableKey: 'audit_logs',
    defaultWidths: DEFAULT_AUDIT_COL_WIDTHS,
    minWidth: 50,
  });
  const [statusFilter, setStatusFilter] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [newLogsCount, setNewLogsCount] = useState(0);

  const socket = useSocket();
  const [socketConnected, setSocketConnected] = useState(false);

  const loadLogs = useCallback(async () => {
    setLoading(true);
    try {
      const params = {
        page,
        limit: pageSize,
        ...(search.trim() && { search: search.trim() }),
        ...(statusFilter && { status: statusFilter }),
        ...(dateFrom && { startDate: dateFrom }),
        ...(dateTo && { endDate: dateTo + 'T23:59:59' }),
      };
      const res = await adminApi.getAuditLogs(params);
      const d = res.data?.data || res.data;
      setLogs(d.items || []);
      setTotal(d.total || 0);
    } catch (e) {
      console.error('Failed to load audit logs:', e);
    } finally {
      setLoading(false);
    }
  }, [page, pageSize, search, statusFilter, dateFrom, dateTo]);

  useEffect(() => {
    loadLogs();
  }, [loadLogs]);

  useEffect(() => {
    setPage(1);
  }, [search, statusFilter, dateFrom, dateTo]);

  // Lắng nghe Real-time Socket.io cho Audit Log Page
  useEffect(() => {
    if (!socket) {
      setSocketConnected(false);
      return;
    }

    setSocketConnected(socket.connected);

    const onConnect = () => setSocketConnected(true);
    const onDisconnect = () => setSocketConnected(false);

    const handleRealtimeLog = (data) => {
      const incomingId = data.id || data.idlog || Date.now();
      const timeReq = data.timeReq || data.time_req || new Date().toISOString();
      const timeRes = data.timeRes || data.time_res || new Date().toISOString();
      const reqStatus = data.status || data.req_status || 'Pass';
      const actionName = data.action || data.request || t('auditLogs.defaultAction');
      const uname = data.username || data.user || t('auditLogs.defaultUser');

      const newLog = {
        id: incomingId,
        idlog: incomingId,
        idaccount: data.idaccount,
        username: uname,
        account: {
          username: uname,
          User: { fullname: data.user || null },
        },
        request: actionName,
        req_status: reqStatus,
        reason: data.reason || null,
        timeReq,
        timeRes,
        time_req: timeReq,
        time_res: timeRes,
        ip: data.ip || '127.0.0.1',
      };

      // Kiểm tra xem log mới có khớp với bộ lọc hiện tại hay không
      const matchesStatus = !statusFilter || reqStatus === statusFilter;
      const matchesSearch =
        !search.trim() ||
        actionName.toLowerCase().includes(search.trim().toLowerCase()) ||
        uname.toLowerCase().includes(search.trim().toLowerCase());

      const canPrepend = page === 1 && matchesStatus && matchesSearch && !dateFrom && !dateTo;

      if (canPrepend) {
        setLogs((prev) => {
          const filtered = prev.filter((item) => (item.id || item.idlog) !== incomingId);
          return [newLog, ...filtered].slice(0, pageSize);
        });
        setTotal((prev) => prev + 1);
      } else {
        setNewLogsCount((prev) => prev + 1);
      }
    };

    socket.on('connect', onConnect);
    socket.on('disconnect', onDisconnect);
    socket.on('audit_activity', handleRealtimeLog);

    return () => {
      socket.off('connect', onConnect);
      socket.off('disconnect', onDisconnect);
      socket.off('audit_activity', handleRealtimeLog);
    };
  }, [socket, page, pageSize, search, statusFilter, dateFrom, dateTo, t]);

  const fmt = (dt) => {
    if (!dt) return '—';
    return new Date(dt).toLocaleString(currentLang === 'en' ? 'en-US' : 'vi-VN', {
      timeZone: 'Asia/Ho_Chi_Minh',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
  };

  const [exporting, setExporting] = useState(false);

  const handleExportCsv = async () => {
    try {
      setExporting(true);
      const params = {
        page: 1,
        limit: Math.min(total || 500, 1000),
        ...(search.trim() && { search: search.trim() }),
        ...(statusFilter && { status: statusFilter }),
        ...(dateFrom && { startDate: dateFrom }),
        ...(dateTo && { endDate: dateTo + 'T23:59:59' }),
      };
      const res = await adminApi.getAuditLogs(params);
      const d = res.data?.data || res.data;
      const exportItems = d.items && d.items.length > 0 ? d.items : logs;

      const headers = [
        'Mã Log',
        'Thời gian',
        'Tài khoản Quản trị',
        'Họ và tên',
        'Phân loại',
        'Hành động / Yêu cầu',
        'Trạng thái',
        'Địa chỉ IP',
        'Lý do / Phản hồi',
      ];

      const rows = exportItems.map((log) => {
        const tag = classifyAuditAction(log.request);
        const logId = log.id || log.idlog || '';
        const time = formatFullDateTime(log.time_req || log.timeReq);
        const username = log.account?.username || log.username || 'System';
        const fullname = log.account?.User?.fullname || '';
        const tagLabel = tag?.code ? `[${tag.code}] ${tag.labelVi}` : '[API]';
        const request = log.request || '';
        const status = log.req_status || '';
        const ip = log.ip || '';
        const reason = log.reason || '';

        return [logId, time, username, fullname, tagLabel, request, status, ip, reason];
      });

      const now = new Date();
      const dateStr = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}_${String(now.getHours()).padStart(2, '0')}${String(now.getMinutes()).padStart(2, '0')}`;
      exportToCsv({
        filename: `audit_logs_${dateStr}.csv`,
        headers,
        rows,
      });
    } catch (err) {
      console.error('Export CSV audit logs failed:', err);
    } finally {
      setExporting(false);
    }
  };

  const handleResetFilters = () => {
    setSearch('');
    setStatusFilter('');
    setDateFrom('');
    setDateTo('');
    setPage(1);
    setNewLogsCount(0);
  };

  return (
    <div className="max-w-[1440px] mx-auto w-full p-4 md:p-6 space-y-6 bg-surface-bright min-h-full">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="font-display-md text-display-md font-bold text-on-surface m-0 tracking-tight flex items-center gap-2">
            <span className="material-symbols-outlined text-primary text-[28px]">fact_check</span>
            {t('auditLogs.title')}
          </h1>
          <p className="font-body-md text-on-surface-variant mt-1">
            {t('auditLogs.subtitle')}
          </p>
        </div>
        <div className="flex items-center gap-2">
          {socketConnected ? (
            <span className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg bg-[#dcfce7] text-[#166534] font-label-md text-xs font-semibold border border-[#86efac]">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#166534] opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-[#166534]"></span>
              </span>
              {t('auditLogs.realtime')}
            </span>
          ) : (
            <span className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg bg-amber-50 text-amber-700 font-label-md text-xs font-medium border border-amber-200" title={t('auditLogs.connectingTitle')}>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-amber-500"></span>
              {t('auditLogs.connecting')}
            </span>
          )}
          <button
            id="btn-export-audit-csv"
            type="button"
            onClick={handleExportCsv}
            disabled={exporting}
            className="flex items-center gap-1.5 text-xs text-slate-700 hover:text-slate-900 border border-outline-variant bg-white hover:bg-slate-50 rounded-lg px-3 py-2 transition-colors cursor-pointer shadow-xs disabled:opacity-50"
            title={t('auditLogs.exportCsvTitle', 'Xuất toàn bộ nhật ký ra định dạng CSV phục vụ kiểm toán')}
          >
            <span className={`material-symbols-outlined text-[16px] text-emerald-600 ${exporting ? 'animate-spin' : ''}`}>
              {exporting ? 'sync' : 'download'}
            </span>
            <span>{exporting ? t('common.exporting', 'Đang xuất...') : t('auditLogs.exportCsvBtn', 'Xuất CSV')}</span>
          </button>
          <button
            onClick={handleResetFilters}
            className="flex items-center gap-1.5 text-xs text-on-surface-variant hover:text-on-surface border border-outline-variant bg-white rounded-lg px-3 py-2 transition-colors cursor-pointer"
            title={t('auditLogs.resetTitle')}
          >
            <span className="material-symbols-outlined text-[16px]">filter_alt_off</span>
            {t('auditLogs.resetBtn')}
          </button>
          <button
            id="btn-refresh-audit"
            onClick={loadLogs}
            className="flex items-center gap-1.5 text-xs text-white bg-primary hover:bg-primary/90 rounded-lg px-3.5 py-2 font-medium transition-colors cursor-pointer shadow-sm"
          >
            <span className="material-symbols-outlined text-[16px]">refresh</span>
            {t('auditLogs.refreshBtn')}
          </button>
        </div>
      </div>

      {/* Filter Toolbar */}
      <div className="bg-white rounded-xl border border-outline-variant shadow-sm p-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
        <div className="relative">
          <span className="material-symbols-outlined absolute left-3 top-2.5 text-on-surface-variant text-[18px]">search</span>
          <input
            type="text"
            placeholder={t('auditLogs.searchPlaceholder')}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full border border-outline-variant rounded-lg pl-9 pr-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary text-on-surface"
          />
        </div>

        <div>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="w-full border border-outline-variant rounded-lg px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary text-on-surface bg-white cursor-pointer"
          >
            {STATUSES.map((s) => (
              <option key={s} value={s}>
                {s ? t('auditLogs.statusPrefix', { status: t('auditLogs.statuses.' + s) || s }) : t('auditLogs.allStatuses')}
              </option>
            ))}
          </select>
        </div>

        <div className="flex items-center gap-1 border border-outline-variant rounded-lg px-2.5 py-1.5 text-xs text-on-surface-variant">
          <span className="text-[11px] whitespace-nowrap">{t('auditLogs.dateFrom')}</span>
          <input
            type="date"
            value={dateFrom}
            onChange={(e) => setDateFrom(e.target.value)}
            className="w-full bg-transparent text-xs focus:outline-none text-on-surface cursor-pointer"
          />
        </div>

        <div className="flex items-center gap-1 border border-outline-variant rounded-lg px-2.5 py-1.5 text-xs text-on-surface-variant">
          <span className="text-[11px] whitespace-nowrap">{t('auditLogs.dateTo')}</span>
          <input
            type="date"
            value={dateTo}
            onChange={(e) => setDateTo(e.target.value)}
            className="w-full bg-transparent text-xs focus:outline-none text-on-surface cursor-pointer"
          />
        </div>
      </div>

      {/* Real-time New Logs Alert Banner */}
      {newLogsCount > 0 && (
        <div
          data-testid="new-logs-banner"
          className="bg-primary/10 border border-primary/30 text-primary rounded-xl p-3 px-4 flex items-center justify-between shadow-2xs animate-fadeIn transition-all"
        >
          <div className="flex items-center gap-2.5 text-xs font-semibold">
            <span className="material-symbols-outlined text-[20px] animate-pulse">notifications_active</span>
            <span>{t('auditLogs.newLogsBanner', { count: newLogsCount })}</span>
          </div>
          <button
            data-testid="btn-view-new-logs"
            onClick={() => {
              setNewLogsCount(0);
              handleResetFilters();
              loadLogs();
            }}
            className="text-xs bg-primary text-white font-medium px-3.5 py-1.5 rounded-lg hover:bg-primary/90 transition-colors shadow-sm cursor-pointer flex items-center gap-1"
          >
            <span className="material-symbols-outlined text-[15px]">autorenew</span>
            {t('auditLogs.viewNewLogs')}
          </button>
        </div>
      )}

      {/* Table Card */}
      <div className="w-full bg-white rounded-xl border border-outline-variant shadow-sm overflow-hidden flex flex-col relative">
        <div className="overflow-x-auto min-h-[300px]">
          <table className="w-full text-left border-collapse min-w-[760px] text-xs table-fixed">
            <thead>
              <tr className="bg-surface-container-low/60 border-b border-outline-variant">
                <ResizableTh
                  colKey="id"
                  width={colWidths.id}
                  minWidth={60}
                  onResize={startResizing}
                  onReset={resetColumn}
                  className="py-3 px-4 font-semibold text-on-surface-variant uppercase tracking-wider text-[11px]"
                >
                  {t('auditLogs.colId')}
                </ResizableTh>
                <ResizableTh
                  colKey="account"
                  width={colWidths.account}
                  minWidth={120}
                  onResize={startResizing}
                  onReset={resetColumn}
                  className="py-3 px-4 font-semibold text-on-surface-variant uppercase tracking-wider text-[11px]"
                >
                  {t('auditLogs.colAccount')}
                </ResizableTh>
                <ResizableTh
                  colKey="request"
                  width={colWidths.request}
                  minWidth={150}
                  onResize={startResizing}
                  onReset={resetColumn}
                  className="py-3 px-4 font-semibold text-on-surface-variant uppercase tracking-wider text-[11px]"
                >
                  {t('auditLogs.colRequest')}
                </ResizableTh>
                <ResizableTh
                  colKey="status"
                  width={colWidths.status}
                  minWidth={90}
                  onResize={startResizing}
                  onReset={resetColumn}
                  className="py-3 px-4 font-semibold text-on-surface-variant uppercase tracking-wider text-[11px] text-center"
                >
                  {t('auditLogs.colStatus')}
                </ResizableTh>
                <ResizableTh
                  colKey="reason"
                  width={colWidths.reason}
                  minWidth={100}
                  onResize={startResizing}
                  onReset={resetColumn}
                  className="py-3 px-4 font-semibold text-on-surface-variant uppercase tracking-wider text-[11px]"
                >
                  {t('auditLogs.colReason')}
                </ResizableTh>
                <ResizableTh
                  colKey="timeReq"
                  width={colWidths.timeReq}
                  minWidth={110}
                  onResize={startResizing}
                  onReset={resetColumn}
                  className="py-3 px-4 font-semibold text-on-surface-variant uppercase tracking-wider text-[11px] whitespace-nowrap"
                >
                  {t('auditLogs.colTimeReq')}
                </ResizableTh>
                <ResizableTh
                  colKey="timeRes"
                  width={colWidths.timeRes}
                  minWidth={110}
                  onResize={startResizing}
                  onReset={resetColumn}
                  className="py-3 px-4 font-semibold text-on-surface-variant uppercase tracking-wider text-[11px] whitespace-nowrap"
                >
                  {t('auditLogs.colTimeRes')}
                </ResizableTh>
              </tr>
            </thead>
            <tbody className="divide-y divide-outline-variant/40">
              {loading ? (
                <tr>
                  <td colSpan={7} className="py-16 text-center text-on-surface-variant">
                    <span className="material-symbols-outlined animate-spin text-primary text-3xl block mx-auto mb-2">progress_activity</span>
                    {t('auditLogs.loading')}
                  </td>
                </tr>
              ) : logs.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-16 text-center text-on-surface-variant">
                    <span className="material-symbols-outlined text-4xl text-gray-300 block mx-auto mb-2">content_paste_off</span>
                    {t('auditLogs.empty')}
                  </td>
                </tr>
              ) : (
                logs.map((log) => {
                  const cfg = STATUS_CONFIG[log.req_status] || { bg: 'bg-gray-100', text: 'text-gray-700', border: 'border-gray-300' };
                  const displayId = log.id || log.idlog;
                  return (
                    <tr key={displayId} className="hover:bg-surface-container-lowest transition-colors">
                      <td className="py-3 px-4 text-on-surface-variant font-mono font-medium">#{displayId}</td>
                      <td className="py-3 px-4 overflow-hidden">
                        <div className="font-semibold text-on-surface flex items-center gap-1.5 min-w-0">
                          <span className="material-symbols-outlined text-[15px] text-slate-400 shrink-0">account_circle</span>
                          <TruncateCell text={log.username || log.account?.username || '—'} className="min-w-0" />
                        </div>
                        <div className="text-[11px] text-on-surface-variant flex items-center gap-1.5 mt-0.5 font-mono">
                          <span>UID: {log.idaccount}</span>
                          <span className="text-slate-300">•</span>
                          <span className="inline-flex items-center gap-0.5 bg-slate-100 text-slate-700 px-1.5 py-0.2 rounded border border-slate-200" title={t('auditLogs.ipTitle')}>
                            <span className="material-symbols-outlined text-[11px] text-slate-400">router</span>
                            <span>{log.ip || log.ip_address || '127.0.0.1'}</span>
                          </span>
                        </div>
                      </td>
                      <td className="py-3 px-4 text-on-surface overflow-hidden">
                        {(() => {
                          const { tagInfo, cleanAction } = classifyAuditAction(log.request);
                          return (
                            <div className="flex items-center gap-2 min-w-0">
                              <span
                                className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-mono font-bold uppercase border ${tagInfo.bg} ${tagInfo.text} ${tagInfo.border} shrink-0`}
                                title={tagInfo.label}
                              >
                                <span className="material-symbols-outlined text-[11px]">{tagInfo.icon}</span>
                                <span>{tagInfo.tag}</span>
                              </span>
                              <TruncateCell text={cleanAction} className="font-medium text-xs text-on-surface min-w-0" />
                            </div>
                          );
                        })()}
                      </td>
                      <td className="py-3 px-4 text-center">
                        <span className={`inline-block text-[11px] font-semibold px-2 py-0.5 rounded-full border ${cfg.bg} ${cfg.text} ${cfg.border}`}>
                          {t('auditLogs.statuses.' + log.req_status) || log.req_status}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-on-surface-variant overflow-hidden">
                        <TruncateCell text={log.reason || '—'} />
                      </td>
                      <td className="py-3 px-4 text-on-surface-variant whitespace-nowrap font-mono text-[11px]">
                        {fmt(log.timeReq || log.time_req)}
                      </td>
                      <td className="py-3 px-4 text-on-surface-variant whitespace-nowrap font-mono text-[11px]">
                        {fmt(log.timeRes || log.time_res)}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Toolbar */}
        <Pagination
          currentPage={page}
          pageSize={pageSize}
          total={total}
          pageSizeOptions={[10, 20, 50, 100, 200]}
          onPageChange={(p) => setPage(p)}
          onPageSizeChange={(newSize) => {
            setPageSize(newSize);
            setPage(1);
          }}
          itemLabel={t('auditLogs.itemLabel')}
        />
      </div>
    </div>
  );
};

export default AuditLogPage;
