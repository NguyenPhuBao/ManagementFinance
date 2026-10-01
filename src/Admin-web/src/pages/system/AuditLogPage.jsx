import React, { useState, useEffect, useCallback } from 'react';
import adminApi from '../../api/admin.api';
import Pagination from '../../components/common/Pagination';
import useSocket from '../../hooks/useSocket';

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
  const [logs, setLogs] = useState([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(50);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');

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
      // Chỉ tự chèn vào đầu bảng nếu đang ở Trang 1 và không có bộ lọc tìm kiếm
      if (page === 1 && !search.trim() && !statusFilter && !dateFrom && !dateTo) {
        const newLog = {
          idlog: data.id || Date.now(),
          idaccount: data.idaccount,
          request: data.action || 'Yêu cầu hệ thống',
          req_status: data.status || 'Pass',
          reason: data.reason || null,
          time_req: data.time_req || new Date().toISOString(),
          time_res: data.time_res || new Date().toISOString(),
          account: {
            username: data.user || 'Người dùng',
            User: { fullname: data.user || null },
          },
        };
        setLogs((prev) => {
          const filtered = prev.filter((item) => item.idlog !== newLog.idlog);
          return [newLog, ...filtered].slice(0, pageSize);
        });
        setTotal((prev) => prev + 1);
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
  }, [socket, page, pageSize, search, statusFilter, dateFrom, dateTo]);

  const fmt = (dt) => {
    if (!dt) return '—';
    return new Date(dt).toLocaleString('vi-VN', {
      timeZone: 'Asia/Ho_Chi_Minh',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
  };

  const handleResetFilters = () => {
    setSearch('');
    setStatusFilter('');
    setDateFrom('');
    setDateTo('');
    setPage(1);
  };

  return (
    <div className="max-w-[1440px] mx-auto w-full p-4 md:p-6 space-y-6 bg-surface-bright min-h-full">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="font-display-md text-display-md font-bold text-on-surface m-0 tracking-tight flex items-center gap-2">
            <span className="material-symbols-outlined text-primary text-[28px]">fact_check</span>
            Nhật Ký Hoạt Động
          </h1>
          <p className="font-body-md text-on-surface-variant mt-1">
            Audit Log — Lưu vết toàn bộ thao tác và request gửi về hệ thống (Append-only)
          </p>
        </div>
        <div className="flex items-center gap-2">
          {socketConnected ? (
            <span className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg bg-[#dcfce7] text-[#166534] font-label-md text-xs font-semibold border border-[#86efac]">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#166534] opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-[#166534]"></span>
              </span>
              Real-time
            </span>
          ) : (
            <span className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg bg-amber-50 text-amber-700 font-label-md text-xs font-medium border border-amber-200" title="Đang kết nối lại socket...">
              <span className="relative inline-flex rounded-full h-2 w-2 bg-amber-500"></span>
              Đang kết nối...
            </span>
          )}
          <button
            onClick={handleResetFilters}
            className="flex items-center gap-1.5 text-xs text-on-surface-variant hover:text-on-surface border border-outline-variant bg-white rounded-lg px-3 py-2 transition-colors cursor-pointer"
            title="Xóa bộ lọc"
          >
            <span className="material-symbols-outlined text-[16px]">filter_alt_off</span>
            Đặt lại
          </button>
          <button
            id="btn-refresh-audit"
            onClick={loadLogs}
            className="flex items-center gap-1.5 text-xs text-white bg-primary hover:bg-primary/90 rounded-lg px-3.5 py-2 font-medium transition-colors cursor-pointer shadow-sm"
          >
            <span className="material-symbols-outlined text-[16px]">refresh</span>
            Làm mới
          </button>
        </div>
      </div>

      {/* Filter Toolbar */}
      <div className="bg-white rounded-xl border border-outline-variant shadow-sm p-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
        <div className="relative">
          <span className="material-symbols-outlined absolute left-3 top-2.5 text-on-surface-variant text-[18px]">search</span>
          <input
            type="text"
            placeholder="Tìm thao tác hoặc username..."
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
                {s ? `Trạng thái: ${s}` : 'Tất cả trạng thái'}
              </option>
            ))}
          </select>
        </div>

        <div className="flex items-center gap-1 border border-outline-variant rounded-lg px-2.5 py-1.5 text-xs text-on-surface-variant">
          <span className="text-[11px] whitespace-nowrap">Từ:</span>
          <input
            type="date"
            value={dateFrom}
            onChange={(e) => setDateFrom(e.target.value)}
            className="w-full bg-transparent text-xs focus:outline-none text-on-surface cursor-pointer"
          />
        </div>

        <div className="flex items-center gap-1 border border-outline-variant rounded-lg px-2.5 py-1.5 text-xs text-on-surface-variant">
          <span className="text-[11px] whitespace-nowrap">Đến:</span>
          <input
            type="date"
            value={dateTo}
            onChange={(e) => setDateTo(e.target.value)}
            className="w-full bg-transparent text-xs focus:outline-none text-on-surface cursor-pointer"
          />
        </div>
      </div>

      {/* Table Card */}
      <div className="w-full bg-white rounded-xl border border-outline-variant shadow-sm overflow-hidden flex flex-col relative">
        <div className="overflow-x-auto min-h-[300px]">
          <table className="w-full text-left border-collapse min-w-[760px] text-xs">
            <thead>
              <tr className="bg-surface-container-low/60 border-b border-outline-variant">
                <th className="py-3 px-4 font-semibold text-on-surface-variant uppercase tracking-wider text-[11px] w-16">ID</th>
                <th className="py-3 px-4 font-semibold text-on-surface-variant uppercase tracking-wider text-[11px]">Tài khoản</th>
                <th className="py-3 px-4 font-semibold text-on-surface-variant uppercase tracking-wider text-[11px]">Thao tác (Request)</th>
                <th className="py-3 px-4 font-semibold text-on-surface-variant uppercase tracking-wider text-[11px] text-center w-28">Trạng thái</th>
                <th className="py-3 px-4 font-semibold text-on-surface-variant uppercase tracking-wider text-[11px]">Lý do</th>
                <th className="py-3 px-4 font-semibold text-on-surface-variant uppercase tracking-wider text-[11px] whitespace-nowrap">Thời gian gửi</th>
                <th className="py-3 px-4 font-semibold text-on-surface-variant uppercase tracking-wider text-[11px] whitespace-nowrap">Thời gian phản hồi</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-outline-variant/40">
              {loading ? (
                <tr>
                  <td colSpan={7} className="py-16 text-center text-on-surface-variant">
                    <span className="material-symbols-outlined animate-spin text-primary text-3xl block mx-auto mb-2">progress_activity</span>
                    Đang tải nhật ký...
                  </td>
                </tr>
              ) : logs.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-16 text-center text-on-surface-variant">
                    <span className="material-symbols-outlined text-4xl text-gray-300 block mx-auto mb-2">content_paste_off</span>
                    Không tìm thấy bản ghi nhật ký phù hợp.
                  </td>
                </tr>
              ) : (
                logs.map((log) => {
                  const cfg = STATUS_CONFIG[log.req_status] || { bg: 'bg-gray-100', text: 'text-gray-700', border: 'border-gray-300' };
                  return (
                    <tr key={log.id} className="hover:bg-surface-container-lowest transition-colors">
                      <td className="py-3 px-4 text-on-surface-variant font-mono font-medium">#{log.id}</td>
                      <td className="py-3 px-4">
                        <div className="font-semibold text-on-surface">{log.username || '—'}</div>
                        <div className="text-[11px] text-on-surface-variant">UID: {log.idaccount}</div>
                      </td>
                      <td className="py-3 px-4 text-on-surface max-w-[240px] truncate font-medium" title={log.request}>
                        {log.request}
                      </td>
                      <td className="py-3 px-4 text-center">
                        <span className={`inline-block text-[11px] font-semibold px-2 py-0.5 rounded-full border ${cfg.bg} ${cfg.text} ${cfg.border}`}>
                          {log.req_status}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-on-surface-variant max-w-[180px] truncate" title={log.reason || ''}>
                        {log.reason || '—'}
                      </td>
                      <td className="py-3 px-4 text-on-surface-variant whitespace-nowrap font-mono text-[11px]">
                        {fmt(log.timeReq)}
                      </td>
                      <td className="py-3 px-4 text-on-surface-variant whitespace-nowrap font-mono text-[11px]">
                        {fmt(log.timeRes)}
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
          pageSizeOptions={[20, 50, 100, 200]}
          onPageChange={(p) => setPage(p)}
          onPageSizeChange={(newSize) => {
            setPageSize(newSize);
            setPage(1);
          }}
          itemLabel="bản ghi"
        />
      </div>
    </div>
  );
};

export default AuditLogPage;
