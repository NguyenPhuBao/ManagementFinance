import React, { useState, useEffect, useCallback, useId } from 'react';
import paymentApi from '../../api/payment.api';
import useSocket from '../../hooks/useSocket';
import TruncateCell from '../../components/common/TruncateCell';
import { useLanguageSafe } from '../../store/language.context';
import { useAlertSafe } from '../../store/alert.context';
import { exportToCsv } from '../../utils/csv-exporter.util';
import { Badge, Button, Card, DataTable, PageHeader, Pagination, SearchInput, StatCard } from '../../components/ui';
import OrderDetailModal from './components/OrderDetailModal';
import RefundModal from './components/RefundModal';
import SampleOrderModal from './components/SampleOrderModal';
import { STATUSES, STATUS_TONE, effectiveStatus, formatDate, formatVnd, packageLabel } from './paymentFormat';

const EMPTY_FILTERS = { search: '', status: 'ALL', packageType: 'ALL', fromDate: '', toDate: '', excludeTemplate: false };

const fieldClass =
  'h-10 rounded-lg border border-line bg-card px-3 text-sm text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';

const buildParams = (f) => ({
  ...(f.search.trim() && { search: f.search.trim() }),
  ...(f.status !== 'ALL' && { status: f.status }),
  ...(f.packageType !== 'ALL' && { packageType: f.packageType }),
  ...(f.fromDate && { fromDate: f.fromDate }),
  ...(f.toDate && { toDate: f.toDate }),
  ...(f.excludeTemplate && { excludeTemplate: 'true' }),
});

const unwrap = (res) => res?.data?.data || res?.data || res;
const isOk = (res) => Boolean(res?.success || res?.data?.success);

const timestamp = () => {
  const n = new Date();
  const p = (v) => String(v).padStart(2, '0');
  return `${n.getFullYear()}${p(n.getMonth() + 1)}${p(n.getDate())}_${p(n.getHours())}${p(n.getMinutes())}`;
};

const PaymentHistoryPage = () => {
  const { t } = useLanguageSafe();
  const notify = useAlertSafe();
  const socket = useSocket();
  const ids = useId();

  const [orders, setOrders] = useState([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState(null);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);
  const [filters, setFilters] = useState(EMPTY_FILTERS);
  const [packageTypes, setPackageTypes] = useState(['Basic', 'Premium']);

  const [selectedOrder, setSelectedOrder] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [refundOrder, setRefundOrder] = useState(null);
  const [sampleOpen, setSampleOpen] = useState(false);
  const [sampleOrder, setSampleOrder] = useState(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [exporting, setExporting] = useState(false);

  const info = (message) => notify && notify.info(message);

  const loadStats = useCallback(async () => {
    try {
      const data = unwrap(
        await paymentApi.getStats({
          ...(filters.fromDate && { fromDate: filters.fromDate }),
          ...(filters.toDate && { toDate: filters.toDate }),
          excludeTemplate: 'true',
        })
      );
      if (data && data.totalOrders !== undefined) setStats(data);
    } catch (err) {
      console.error('[PAYMENT_PAGE] Lỗi khi tải thống kê:', err);
    }
  }, [filters.fromDate, filters.toDate]);

  const loadOrders = useCallback(async () => {
    setLoading(true);
    try {
      const data = unwrap(await paymentApi.getOrders({ page, limit: pageSize, ...buildParams(filters) }));
      setOrders(data.items || []);
      setTotal(data.total || 0);
    } catch (err) {
      console.error('[PAYMENT_PAGE] Lỗi khi tải danh sách đơn hàng:', err);
      setOrders([]);
      setTotal(0);
    } finally {
      setLoading(false);
    }
  }, [page, pageSize, filters]);

  const reload = useCallback(() => Promise.all([loadStats(), loadOrders()]), [loadStats, loadOrders]);

  useEffect(() => {
    paymentApi
      .getPackageTypes()
      .then((res) => {
        const raw = unwrap(res);
        const types = Array.isArray(raw) ? raw : Array.isArray(raw?.data) ? raw.data : [];
        if (types.length) setPackageTypes(types);
      })
      .catch((err) => console.error('[PAYMENT_PAGE] Lỗi khi tải danh sách gói cước:', err));
  }, []);

  useEffect(() => {
    loadStats();
  }, [loadStats]);

  useEffect(() => {
    loadOrders();
  }, [loadOrders]);

  useEffect(() => {
    if (!socket) return undefined;
    const code = (d) => d?.orderCode || d?.order_code || '';

    const onPaymentSuccess = (data) => {
      reload();
      info(t('payments.alerts.paid', { code: code(data) }));
      const incoming = String(code(data));
      setSelectedOrder((prev) =>
        prev && (String(prev.order_code) === incoming || prev.id === data.orderId)
          ? { ...prev, status: 'PAID', paid_at: new Date().toISOString(), qr_url: null, checkout_url: null }
          : prev
      );
      setSampleOrder((prev) => (prev && String(prev.orderCode) === incoming ? null : prev));
    };
    const events = {
      'payment.order_created': (data) => {
        reload();
        info(t('payments.alerts.newOrder', { code: code(data) }));
      },
      'payment.success': onPaymentSuccess,
      'payment.overpaid_confirmation': (data) => {
        reload();
        if (code(data)) info(t('payments.alerts.overpaid', { code: code(data) }));
      },
      'payment.underpaid_warning': (data) => {
        reload();
        if (code(data)) info(t('payments.alerts.underpaid', { code: code(data) }));
      },
      'payment.refunded': () => reload(),
      'payment.order_expired': () => reload(),
    };
    Object.entries(events).forEach(([name, fn]) => socket.on(name, fn));
    return () => Object.entries(events).forEach(([name, fn]) => socket.off(name, fn));
  }, [socket, reload, t]);

  const setFilter = (key, value) => {
    setFilters((prev) => ({ ...prev, [key]: value }));
    setPage(1);
  };

  const handleViewDetail = async (orderId) => {
    setDetailLoading(true);
    try {
      const data = unwrap(await paymentApi.getOrderDetail(orderId));
      if (data && (data.id || data.order_code)) setSelectedOrder(data);
    } catch (err) {
      console.error('[PAYMENT_PAGE] Lỗi khi tải chi tiết đơn hàng:', err);
    } finally {
      setDetailLoading(false);
    }
  };

  const handleOrderExpired = () => {
    setSelectedOrder((prev) => (prev ? { ...prev, status: 'EXPIRED', qr_url: null, checkout_url: null } : prev));
    reload();
  };

  const handleConfirmUpgrade = async (orderCode, accept) => {
    setActionLoading(true);
    try {
      const res = await paymentApi.confirmUpgrade({ orderCode, accept });
      if (isOk(res)) {
        if (notify) notify.success(accept ? t('payments.detail.acceptSuccess') : t('payments.detail.rejectSuccess'));
        setSelectedOrder((prev) => (prev && prev.order_code === orderCode ? { ...prev, status: accept ? 'PAID' : 'REFUND_PENDING' } : prev));
        await reload();
      }
    } catch (err) {
      if (notify) notify.error(err?.response?.data?.message || err.message, t('payments.alerts.actionFailed'));
    } finally {
      setActionLoading(false);
    }
  };

  const handleRefund = async (order, formData) => {
    const res = await paymentApi.processRefund(order.id, formData);
    if (!isOk(res)) return;
    setRefundOrder(null);
    if (notify) notify.success(t('payments.refund.success'));
    if (selectedOrder?.id === order.id) handleViewDetail(order.id);
    await reload();
  };

  const handleCreateSample = async (amount) => {
    setActionLoading(true);
    try {
      const res = await paymentApi.createSampleOrder({ simulateWebhook: false, status: 'PENDING', packageType: 'Premium', amount });
      const data = unwrap(res);
      if (isOk(res) || data?.order_code) {
        setSampleOrder({
          orderCode: data.order_code,
          qrUrl: data.qr_url,
          recognitionCode: data.recognition_code,
          description: data.transfer_content || data.recognition_code,
          amount: data.amount,
          bankName: data.bank_info?.bankName || '',
          accountNumber: data.bank_info?.accountNumber || '',
          accountName: data.bank_info?.accountName || '',
          checkoutUrl: data.checkout_url || data.bank_info?.checkoutUrl,
        });
        if (notify) notify.success(t('payments.sample.created'));
        await reload();
      }
    } catch (err) {
      if (notify) notify.error(err?.response?.data?.message || err.message, t('payments.alerts.actionFailed'));
    } finally {
      setActionLoading(false);
    }
  };

  const handleCopy = (value) => {
    if (value) navigator.clipboard?.writeText(value);
  };

  const handleExportCsv = async () => {
    setExporting(true);
    try {
      const data = unwrap(await paymentApi.getOrders({ page: 1, limit: Math.min(total || 500, 1000), ...buildParams(filters) }));
      const items = data.items?.length ? data.items : data.orders?.length ? data.orders : orders;
      exportToCsv({
        filename: `payment_history_${timestamp()}.csv`,
        headers: ['Mã Đơn hàng', 'Mã GD Cổng', 'Khách hàng', 'Gói cước', 'Số tiền (VNĐ)', 'Cổng TT', 'Trạng thái', 'Ngày tạo', 'Ngày thanh toán', 'Ghi chú / Hoàn tiền'],
        rows: items.map((o) => [
          o.order_code || o.idorder || '',
          o.transaction_id || '',
          o.user?.fullname || o.user?.name || o.account?.username || 'Khách vãng lai',
          o.package_name || o.package_type || 'Gói dịch vụ',
          o.amount || 0,
          o.payment_gateway || 'PayOS',
          o.status || '',
          formatDate(o.created_at),
          formatDate(o.paid_at),
          o.refund_reason || o.notes || '',
        ]),
      });
    } catch (err) {
      console.error('Export CSV payments failed:', err);
    } finally {
      setExporting(false);
    }
  };

  const columns = [
    {
      key: 'order',
      title: t('payments.table.orderCode'),
      render: (o) => (
        <div className="min-w-0">
          <div className="flex items-center gap-1.5">
            <span className="font-mono font-semibold text-ink">#{o.order_code}</span>
            {o.is_template && <Badge tone="warning">{t('payments.table.sample')}</Badge>}
          </div>
          {o.recognition_code && <div className="font-mono text-xs text-ink-faint">{t('payments.table.recognition', { code: o.recognition_code })}</div>}
        </div>
      ),
    },
    {
      key: 'user',
      title: t('payments.table.user'),
      render: (o) => (
        <div className="min-w-0">
          <TruncateCell text={o.account?.username || '—'} className="font-medium text-ink" />
          <TruncateCell text={o.account?.User?.fullname || o.account?.email || ''} className="text-xs text-ink-faint" />
        </div>
      ),
    },
    { key: 'package', title: t('payments.table.package'), render: (o) => <Badge tone={o.package_type === 'Basic' ? 'neutral' : 'info'}>{packageLabel(o.package_type, t)}</Badge> },
    {
      key: 'amount',
      title: t('payments.table.amount'),
      render: (o) => (
        <div className="tabular-nums">
          <div className="font-medium text-ink">{formatVnd(o.amount)}</div>
          {o.amount_received && o.amount_received !== o.amount && (
            <div className="text-xs text-ink-faint">{t('payments.table.received', { amount: formatVnd(o.amount_received) })}</div>
          )}
        </div>
      ),
    },
    {
      key: 'status',
      title: t('payments.table.status'),
      render: (o) => {
        const status = effectiveStatus(o);
        return <Badge tone={STATUS_TONE[status] || 'neutral'}>{t(`payments.status.${status}`, status)}</Badge>;
      },
    },
    { key: 'created', title: t('payments.table.createdAt'), render: (o) => <span className="whitespace-nowrap text-ink-muted">{formatDate(o.created_at)}</span> },
    { key: 'paid', title: t('payments.table.paidAt'), render: (o) => <span className="whitespace-nowrap text-ink-muted">{formatDate(o.paid_at)}</span> },
    {
      key: 'actions',
      title: t('payments.table.actions'),
      align: 'right',
      render: (o) => (
        <div className="flex items-center justify-end gap-1">
          {o.status === 'REFUND_PENDING' && (
            <Button size="sm" variant="secondary" icon="currency_exchange" onClick={() => setRefundOrder(o)}>
              {t('payments.table.refundBtn')}
            </Button>
          )}
          <Button variant="ghost" size="sm" icon="visibility" aria-label={t('payments.table.viewDetail')} title={t('payments.table.viewDetail')} onClick={() => handleViewDetail(o.id)} />
        </div>
      ),
    },
  ];

  const filtersActive = JSON.stringify(filters) !== JSON.stringify(EMPTY_FILTERS);

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t('payments.title')}
        description={t('payments.subtitle')}
        actions={
          <>
            <Button icon="download" loading={exporting} onClick={handleExportCsv}>
              {t('payments.exportCsv')}
            </Button>
            <Button
              variant="primary"
              icon="qr_code_2"
              onClick={() => {
                setSampleOrder(null);
                setSampleOpen(true);
              }}
            >
              {t('payments.sampleBtn')}
            </Button>
          </>
        }
      />

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label={t('payments.stats.totalRevenue')} value={stats ? formatVnd(stats.totalRevenue) : '—'} hint={t('payments.stats.excludesSamples')} />
        <StatCard label={t('payments.stats.totalOrders')} value={stats ? Number(stats.totalOrders).toLocaleString('vi-VN') : '—'} />
        <StatCard label={t('payments.stats.paidOrders')} value={stats ? Number(stats.paidOrders).toLocaleString('vi-VN') : '—'} />
        <StatCard label={t('payments.stats.successRate')} value={stats ? `${stats.successRate}%` : '—'} />
      </div>

      <Card>
        <div className="flex flex-col gap-3 border-b border-line px-4 py-3">
          <div className="flex flex-wrap items-center gap-2">
            <SearchInput
              label={t('payments.filter.searchLabel')}
              placeholder={t('payments.filter.searchPlaceholder')}
              value={filters.search}
              onChange={(v) => setFilter('search', v)}
              className="w-full sm:w-72"
            />
            <label htmlFor={`${ids}-status`} className="sr-only">
              {t('payments.filter.statusLabel')}
            </label>
            <select id={`${ids}-status`} value={filters.status} onChange={(e) => setFilter('status', e.target.value)} className={`${fieldClass} cursor-pointer pr-9`}>
              <option value="ALL">{t('payments.filter.statusAll')}</option>
              {STATUSES.map((s) => (
                <option key={s} value={s}>
                  {t(`payments.status.${s}`)}
                </option>
              ))}
            </select>
            <label htmlFor={`${ids}-package`} className="sr-only">
              {t('payments.filter.packageLabel')}
            </label>
            <select id={`${ids}-package`} value={filters.packageType} onChange={(e) => setFilter('packageType', e.target.value)} className={`${fieldClass} cursor-pointer pr-9`}>
              <option value="ALL">{t('payments.filter.packageAll')}</option>
              {packageTypes.map((pkg) => {
                const id = typeof pkg === 'object' && pkg ? pkg.id : pkg;
                const name = typeof pkg === 'object' && pkg ? pkg.name || pkg.id : pkg;
                return (
                  <option key={id} value={id}>
                    {id === 'Basic' || id === 'Premium' ? packageLabel(id, t) : name}
                  </option>
                );
              })}
            </select>
          </div>
          <div className="flex flex-wrap items-center gap-3 text-sm">
            <label className="flex items-center gap-2 text-ink-muted">
              {t('payments.filter.fromDate')}
              <input type="date" value={filters.fromDate} onChange={(e) => setFilter('fromDate', e.target.value)} className={fieldClass} />
            </label>
            <label className="flex items-center gap-2 text-ink-muted">
              {t('payments.filter.toDate')}
              <input type="date" value={filters.toDate} onChange={(e) => setFilter('toDate', e.target.value)} className={fieldClass} />
            </label>
            <label className="flex cursor-pointer items-center gap-2 text-ink">
              <input
                type="checkbox"
                checked={filters.excludeTemplate}
                onChange={(e) => setFilter('excludeTemplate', e.target.checked)}
                className="h-4 w-4 cursor-pointer accent-brand"
              />
              {t('payments.filter.excludeTemplate')}
            </label>
            <Button
              variant="ghost"
              size="sm"
              icon="filter_alt_off"
              disabled={!filtersActive}
              onClick={() => {
                setFilters(EMPTY_FILTERS);
                setPage(1);
              }}
            >
              {t('payments.filter.reset')}
            </Button>
          </div>
        </div>
        <DataTable columns={columns} rows={orders} rowKey="id" loading={loading && orders.length === 0} emptyTitle={t('payments.table.emptyTitle')} minWidth={960} />
        <Pagination
          currentPage={page}
          pageSize={pageSize}
          total={total}
          pageSizeOptions={[10, 20, 50, 100]}
          onPageChange={setPage}
          onPageSizeChange={(size) => {
            setPageSize(size);
            setPage(1);
          }}
          itemLabel={t('payments.table.itemLabel')}
        />
      </Card>

      <OrderDetailModal
        open={detailLoading || Boolean(selectedOrder)}
        loading={detailLoading}
        order={selectedOrder}
        onClose={() => setSelectedOrder(null)}
        onExpired={handleOrderExpired}
        onConfirmUpgrade={handleConfirmUpgrade}
        onRefund={setRefundOrder}
        actionLoading={actionLoading}
        onCopy={handleCopy}
      />

      <RefundModal order={refundOrder} onClose={() => setRefundOrder(null)} onSubmit={handleRefund} />

      <SampleOrderModal
        open={sampleOpen}
        onClose={() => setSampleOpen(false)}
        onCreate={handleCreateSample}
        creating={actionLoading}
        order={sampleOrder}
        onCopy={handleCopy}
      />
    </div>
  );
};

export default PaymentHistoryPage;
