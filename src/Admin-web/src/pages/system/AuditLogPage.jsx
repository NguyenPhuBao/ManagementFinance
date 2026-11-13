import React, { useState, useEffect, useCallback, useId } from 'react';
import adminApi from '../../api/admin.api';
import useSocket from '../../hooks/useSocket';
import TruncateCell from '../../components/common/TruncateCell';
import RequestCell from '../../components/common/RequestCell';
import { useLanguageSafe } from '../../store/language.context';
import { AUDIT_STATUS_TONE as STATUS_TONE, classifyAuditAction } from '../../utils/audit-tags.util';
import { exportToCsv } from '../../utils/csv-exporter.util';
import { formatFullDateTime } from '../../utils/format';
import { Badge, Button, Card, DataTable, PageHeader, Pagination, SearchInput } from '../../components/ui';

const STATUSES = Object.keys(STATUS_TONE);
const EMPTY_FILTERS = { search: '', status: '', dateFrom: '', dateTo: '' };

const fieldClass =
  'h-10 rounded-lg border border-line bg-card px-3 text-sm text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';

const buildParams = (f) => ({
  ...(f.search.trim() && { search: f.search.trim() }),
  ...(f.status && { status: f.status }),
  ...(f.dateFrom && { startDate: f.dateFrom }),
  ...(f.dateTo && { endDate: `${f.dateTo}T23:59:59` }),
});

const AuditLogPage = () => {
  const { t, currentLang } = useLanguageSafe();
  const socket = useSocket();
  const ids = useId();

  const [logs, setLogs] = useState([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);
  const [filters, setFilters] = useState(EMPTY_FILTERS);
  const [newLogsCount, setNewLogsCount] = useState(0);
  const [exporting, setExporting] = useState(false);

  const loadLogs = useCallback(async () => {
    setLoading(true);
    try {
      const res = await adminApi.getAuditLogs({ page, limit: pageSize, ...buildParams(filters) });
      const d = res.data?.data || res.data;
      setLogs(d.items || []);
      setTotal(d.total || 0);
    } catch (err) {
      console.error('Failed to load audit logs:', err);
    } finally {
      setLoading(false);
    }
  }, [page, pageSize, filters]);

  useEffect(() => {
    loadLogs();
  }, [loadLogs]);

  useEffect(() => {
    if (!socket) return undefined;
    const handleRealtimeLog = (data) => {
      const id = data.id || data.idlog || Date.now();
      const status = data.status || data.req_status || 'Pass';
      const action = data.action || data.request || t('auditLogs.defaultAction');
      const request = data.request || data.action || '';
      const username = data.username || data.user || t('auditLogs.defaultUser');
      const now = new Date().toISOString();
      const q = filters.search.trim().toLowerCase();
      const matches =
        (!filters.status || status === filters.status) &&
        (!q || [action, request, username].some((v) => v.toLowerCase().includes(q)));

      if (page === 1 && matches && !filters.dateFrom && !filters.dateTo) {
        const entry = {
          id,
          idaccount: data.idaccount,
          username,
          account: { username, User: { fullname: data.user || null } },
          action,
          request,
          req_status: status,
          reason: data.reason || null,
          time_req: data.timeReq || data.time_req || now,
          time_res: data.timeRes || data.time_res || now,
          ip: data.ip || '',
        };
        setLogs((prev) => [entry, ...prev.filter((item) => (item.id || item.idlog) !== id)].slice(0, pageSize));
        setTotal((prev) => prev + 1);
      } else {
        setNewLogsCount((prev) => prev + 1);
      }
    };
    socket.on('audit_activity', handleRealtimeLog);
    return () => socket.off('audit_activity', handleRealtimeLog);
  }, [socket, page, pageSize, filters, t]);

  const setFilter = (key, value) => {
    setFilters((prev) => ({ ...prev, [key]: value }));
    setPage(1);
  };

  const fmt = (dt) =>
    dt
      ? new Date(dt).toLocaleString(currentLang === 'en' ? 'en-US' : 'vi-VN', {
          timeZone: 'Asia/Ho_Chi_Minh',
          year: 'numeric',
          month: '2-digit',
          day: '2-digit',
          hour: '2-digit',
          minute: '2-digit',
          second: '2-digit',
        })
      : '—';

  const showNewLogs = () => {
    setNewLogsCount(0);
    if (page === 1) loadLogs();
    else setPage(1);
  };

  const handleExportCsv = async () => {
    setExporting(true);
    try {
      const res = await adminApi.getAuditLogs({ page: 1, limit: Math.min(total || 500, 1000), ...buildParams(filters) });
      const d = res.data?.data || res.data;
      const items = d.items?.length ? d.items : logs;
      exportToCsv({
        filename: `audit_logs_${new Date().toISOString().slice(0, 10)}.csv`,
        headers: ['Mã Log', 'Thời gian gửi', 'Tài khoản Quản trị', 'Họ và tên', 'Phân loại', 'Hành động', 'Yêu cầu API', 'Trạng thái', 'Địa chỉ IP', 'Lý do / Phản hồi'],
        rows: items.map((log) => {
          const { tagInfo, cleanAction } = classifyAuditAction(log.action || log.request || '', log.request);
          return [
            log.id || log.idlog || '',
            formatFullDateTime(log.time_req || log.timeReq),
            log.account?.username || log.username || 'System',
            log.account?.User?.fullname || '',
            tagInfo.label,
            cleanAction,
            log.request || '',
            log.req_status || '',
            log.ip || '',
            log.reason || '',
          ];
        }),
      });
    } catch (err) {
      console.error('Export CSV audit logs failed:', err);
    } finally {
      setExporting(false);
    }
  };

  const columns = [
    { key: 'id', title: t('auditLogs.colId'), render: (log) => <span className="font-mono text-ink-muted">{log.id || log.idlog}</span> },
    {
      key: 'account',
      title: t('auditLogs.colAccount'),
      render: (log) => (
        <div className="min-w-0">
          <TruncateCell text={log.username || log.account?.username || '—'} className="font-medium text-ink" />
          <div className="flex items-center gap-2 whitespace-nowrap text-xs text-ink-faint">
            {log.idaccount && <span>UID {log.idaccount}</span>}
            {(log.ip || log.ip_address) && <span className="font-mono">{log.ip || log.ip_address}</span>}
          </div>
        </div>
      ),
    },
    {
      key: 'action',
      title: t('auditLogs.colAction'),
      width: '22%',
      render: (log) => {
        const { tagInfo, cleanAction } = classifyAuditAction(log.action || log.request, log.request);
        return (
          <div className="flex min-w-0 flex-col items-start gap-1">
            <Badge tone={tagInfo.tone}>{tagInfo.label}</Badge>
            <TruncateCell text={cleanAction} className="text-ink" />
          </div>
        );
      },
    },
    { key: 'request', title: t('auditLogs.colRequest'), width: '20%', render: (log) => <RequestCell value={log.request} /> },
    {
      key: 'status',
      title: t('auditLogs.colStatus'),
      render: (log) => <Badge tone={STATUS_TONE[log.req_status] || 'neutral'}>{t(`auditLogs.statuses.${log.req_status}`, log.req_status)}</Badge>,
    },
    { key: 'reason', title: t('auditLogs.colReason'), width: '14%', render: (log) => <TruncateCell text={log.reason || '—'} className="text-ink-muted" /> },
    {
      key: 'time',
      title: t('auditLogs.colTime'),
      render: (log) => (
        <div className="whitespace-nowrap">
          <div className="text-ink">{fmt(log.time_req || log.timeReq)}</div>
          <div className="text-xs text-ink-faint">{t('auditLogs.respondedAt', { time: fmt(log.time_res || log.timeRes) })}</div>
        </div>
      ),
    },
  ];

  const filtersActive = JSON.stringify(filters) !== JSON.stringify(EMPTY_FILTERS);

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t('auditLogs.title')}
        description={t('auditLogs.subtitle')}
        actions={
          <>
            <Button icon="download" loading={exporting} onClick={handleExportCsv}>
              {t('auditLogs.exportCsvBtn')}
            </Button>
            <Button icon="refresh" onClick={loadLogs}>
              {t('auditLogs.refreshBtn')}
            </Button>
          </>
        }
      />

      {newLogsCount > 0 && (
        <div role="status" className="flex flex-wrap items-center justify-between gap-3 rounded-xl bg-info-soft px-4 py-3 text-sm text-info">
          <span>{t('auditLogs.newLogsBanner', { count: newLogsCount })}</span>
          <Button size="sm" variant="ghost" onClick={showNewLogs}>
            {t('auditLogs.viewNewLogs')}
          </Button>
        </div>
      )}

      <Card>
        <div className="flex flex-wrap items-center gap-3 border-b border-line px-4 py-3 text-sm">
          <SearchInput
            label={t('auditLogs.searchLabel')}
            placeholder={t('auditLogs.searchPlaceholder')}
            value={filters.search}
            onChange={(v) => setFilter('search', v)}
            className="w-full sm:w-72"
          />
          <label htmlFor={`${ids}-status`} className="sr-only">
            {t('auditLogs.statusLabel')}
          </label>
          <select id={`${ids}-status`} value={filters.status} onChange={(e) => setFilter('status', e.target.value)} className={`${fieldClass} cursor-pointer pr-9`}>
            <option value="">{t('auditLogs.allStatuses')}</option>
            {STATUSES.map((s) => (
              <option key={s} value={s}>
                {t(`auditLogs.statuses.${s}`)}
              </option>
            ))}
          </select>
          <label className="flex items-center gap-2 text-ink-muted">
            {t('auditLogs.dateFrom')}
            <input type="date" value={filters.dateFrom} onChange={(e) => setFilter('dateFrom', e.target.value)} className={fieldClass} />
          </label>
          <label className="flex items-center gap-2 text-ink-muted">
            {t('auditLogs.dateTo')}
            <input type="date" value={filters.dateTo} onChange={(e) => setFilter('dateTo', e.target.value)} className={fieldClass} />
          </label>
          <Button variant="ghost" size="sm" icon="filter_alt_off" disabled={!filtersActive} onClick={() => { setFilters(EMPTY_FILTERS); setPage(1); }}>
            {t('auditLogs.resetBtn')}
          </Button>
        </div>
        <DataTable columns={columns} rows={logs} rowKey={(log) => log.id || log.idlog} loading={loading && logs.length === 0} emptyTitle={t('auditLogs.emptyTitle')} minWidth={980} />
        <Pagination
          currentPage={page}
          pageSize={pageSize}
          total={total}
          onPageChange={setPage}
          onPageSizeChange={(size) => {
            setPageSize(size);
            setPage(1);
          }}
          itemLabel={t('auditLogs.itemLabel')}
        />
      </Card>
    </div>
  );
};

export default AuditLogPage;
