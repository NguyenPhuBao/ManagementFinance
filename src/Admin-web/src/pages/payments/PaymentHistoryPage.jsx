import React, { useState, useEffect, useCallback } from 'react';
import paymentApi from '../../api/payment.api';
import Pagination from '../../components/common/Pagination';
import { useLanguageSafe } from '../../store/language.context';

const STATUS_CONFIG = {
  PAID: { bg: 'bg-emerald-50', text: 'text-emerald-700', border: 'border-emerald-200', icon: 'check_circle' },
  PENDING: { bg: 'bg-amber-50', text: 'text-amber-700', border: 'border-amber-200', icon: 'schedule' },
  CANCELLED: { bg: 'bg-slate-100', text: 'text-slate-600', border: 'border-slate-300', icon: 'cancel' },
  EXPIRED: { bg: 'bg-rose-50', text: 'text-rose-700', border: 'border-rose-200', icon: 'timer_off' },
};

const formatVnd = (amount) => {
  if (amount === undefined || amount === null) return '0 ₫';
  return Number(amount).toLocaleString('vi-VN') + ' ₫';
};

const formatDate = (dateStr) => {
  if (!dateStr) return '—';
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return '—';
  return d.toLocaleString('vi-VN', {
    hour: '2-digit',
    minute: '2-digit',
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
};

const PaymentHistoryPage = () => {
  const { t } = useLanguageSafe();

  // State
  const [orders, setOrders] = useState([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [statsLoading, setStatsLoading] = useState(true);
  const [stats, setStats] = useState({
    totalRevenue: 0,
    totalOrders: 0,
    paidOrders: 0,
    successRate: 0,
  });

  // Filters & Pagination
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [packageFilter, setPackageFilter] = useState('ALL');
  const [fromDate, setFromDate] = useState('');
  const [toDate, setToDate] = useState('');

  // Detail Modal
  const [selectedOrder, setSelectedOrder] = useState(null);
  const [modalLoading, setModalLoading] = useState(false);
  const [feedbackMsg, setFeedbackMsg] = useState(null);

  // Sample QR Modal & Live PayOS Channel State
  const [showSampleModal, setShowSampleModal] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [payosData, setPayosData] = useState(null);
  const [payosLoading, setPayosLoading] = useState(false);
  const [selectedSampleAmount, setSelectedSampleAmount] = useState(49000);
  const [selectedSamplePackage, setSelectedSamplePackage] = useState('PREMIUM_1_MONTH');

  // Load live PayOS QR data
  const loadPayosQr = useCallback(async (amount = selectedSampleAmount, packageType = selectedSamplePackage) => {
    setPayosLoading(true);
    try {
      const res = await paymentApi.getPayosQr({ amount, packageType });
      if (res.data?.success && res.data?.data) {
        setPayosData(res.data.data);
      }
    } catch (err) {
      console.error('[PAYMENT_PAGE] Lỗi khi tải mã QR PayOS:', err);
    } finally {
      setPayosLoading(false);
    }
  }, [selectedSampleAmount, selectedSamplePackage]);

  useEffect(() => {
    if (showSampleModal) {
      loadPayosQr(selectedSampleAmount, selectedSamplePackage);
    }
  }, [showSampleModal, selectedSampleAmount, selectedSamplePackage, loadPayosQr]);

  // Fetch KPI Stats
  const loadStats = useCallback(async () => {
    setStatsLoading(true);
    try {
      const res = await paymentApi.getStats({
        ...(fromDate && { fromDate }),
        ...(toDate && { toDate }),
      });
      if (res.data?.success && res.data?.data) {
        setStats(res.data.data);
      }
    } catch (err) {
      console.error('[PAYMENT_PAGE] Lỗi khi tải thống kê:', err);
    } finally {
      setStatsLoading(false);
    }
  }, [fromDate, toDate]);

  // Fetch Orders List
  const loadOrders = useCallback(async () => {
    setLoading(true);
    try {
      const params = {
        page,
        limit: pageSize,
        ...(search.trim() && { search: search.trim() }),
        ...(statusFilter !== 'ALL' && { status: statusFilter }),
        ...(packageFilter !== 'ALL' && { packageType: packageFilter }),
        ...(fromDate && { fromDate }),
        ...(toDate && { toDate }),
      };
      const res = await paymentApi.getOrders(params);
      const data = res.data?.data || res.data;
      setOrders(data.items || []);
      setTotal(data.total || 0);
    } catch (err) {
      console.error('[PAYMENT_PAGE] Lỗi khi tải danh sách đơn hàng:', err);
      setOrders([]);
      setTotal(0);
    } finally {
      setLoading(false);
    }
  }, [page, pageSize, search, statusFilter, packageFilter, fromDate, toDate]);

  useEffect(() => {
    loadStats();
  }, [loadStats]);

  useEffect(() => {
    loadOrders();
  }, [loadOrders]);

  const handleRefresh = async () => {
    await Promise.all([loadStats(), loadOrders()]);
    setFeedbackMsg(t('payments.refreshSuccess'));
    setTimeout(() => setFeedbackMsg(null), 3000);
  };

  const handleResetFilters = () => {
    setSearch('');
    setStatusFilter('ALL');
    setPackageFilter('ALL');
    setFromDate('');
    setToDate('');
    setPage(1);
  };

  const handleViewDetail = async (orderId) => {
    setModalLoading(true);
    try {
      const res = await paymentApi.getOrderDetail(orderId);
      if (res.data?.success && res.data?.data) {
        setSelectedOrder(res.data.data);
      }
    } catch (err) {
      console.error('[PAYMENT_PAGE] Lỗi khi tải chi tiết đơn hàng:', err);
    } finally {
      setModalLoading(false);
    }
  };

  const handleCreateSampleOrder = async (simulateWebhook = false) => {
    setActionLoading(true);
    try {
      const res = await paymentApi.createSampleOrder({
        simulateWebhook,
        status: simulateWebhook ? 'PAID' : 'PENDING',
        packageType: selectedSamplePackage,
        amount: selectedSampleAmount,
      });
      if (res.data?.success) {
        setFeedbackMsg(t('payments.createSampleSuccess'));
        await Promise.all([loadStats(), loadOrders()]);
        setTimeout(() => setFeedbackMsg(null), 3500);
      }
    } catch (err) {
      console.error('[PAYMENT_PAGE] Lỗi khi tạo đơn hàng mẫu:', err);
    } finally {
      setActionLoading(false);
    }
  };

  const handleCleanSampleOrders = async () => {
    setActionLoading(true);
    try {
      const res = await paymentApi.deleteSampleOrders();
      if (res.data?.success) {
        setFeedbackMsg(t('payments.cleanSampleSuccess'));
        await Promise.all([loadStats(), loadOrders()]);
        setTimeout(() => setFeedbackMsg(null), 3500);
      }
    } catch (err) {
      console.error('[PAYMENT_PAGE] Lỗi khi dọn dẹp đơn mẫu:', err);
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      {/* Header & Page Title */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-on-surface flex items-center gap-2">
            <span className="material-symbols-outlined text-primary text-3xl">receipt_long</span>
            {t('payments.title')}
          </h1>
          <p className="text-sm text-on-surface-variant mt-1">
            {t('payments.subtitle')}
          </p>
        </div>
        <div className="flex items-center gap-3">
          {feedbackMsg && (
            <span className="text-sm font-medium text-emerald-600 bg-emerald-50 px-3 py-1.5 rounded-lg border border-emerald-200 animate-fadeIn">
              {feedbackMsg}
            </span>
          )}
          <button
            onClick={() => setShowSampleModal(true)}
            className="flex items-center gap-2 px-4 py-2 bg-primary hover:bg-primary/90 text-white rounded-lg shadow-sm transition-all duration-200 cursor-pointer font-semibold text-sm active:scale-95"
            title={t('payments.sampleQrBtn')}
          >
            <span className="material-symbols-outlined text-lg">qr_code_2</span>
            <span>{t('payments.sampleQrBtn')}</span>
          </button>
          <button
            onClick={handleRefresh}
            disabled={loading || statsLoading}
            className="flex items-center gap-2 px-4 py-2 bg-surface-container-high hover:bg-surface-container-highest text-on-surface rounded-lg border border-outline-variant transition-colors cursor-pointer disabled:opacity-50"
            title={t('payments.refresh')}
          >
            <span className={`material-symbols-outlined text-lg ${(loading || statsLoading) ? 'animate-spin' : ''}`}>
              refresh
            </span>
            <span className="text-sm font-semibold">{t('payments.refresh')}</span>
          </button>
        </div>
      </div>

      {/* KPI Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Doanh thu */}
        <div className="bg-surface-container rounded-xl p-4 border border-outline-variant shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
              {t('payments.stats.totalRevenue')}
            </p>
            <h3 className="text-xl font-bold text-emerald-600 mt-1">
              {statsLoading ? '...' : formatVnd(stats.totalRevenue)}
            </h3>
          </div>
          <div className="w-11 h-11 rounded-full bg-emerald-50 flex items-center justify-center text-emerald-600">
            <span className="material-symbols-outlined text-2xl">payments</span>
          </div>
        </div>

        {/* Tổng đơn hàng */}
        <div className="bg-surface-container rounded-xl p-4 border border-outline-variant shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
              {t('payments.stats.totalOrders')}
            </p>
            <h3 className="text-xl font-bold text-on-surface mt-1">
              {statsLoading ? '...' : stats.totalOrders?.toLocaleString()}
            </h3>
          </div>
          <div className="w-11 h-11 rounded-full bg-blue-50 flex items-center justify-center text-blue-600">
            <span className="material-symbols-outlined text-2xl">receipt</span>
          </div>
        </div>

        {/* Đơn thành công */}
        <div className="bg-surface-container rounded-xl p-4 border border-outline-variant shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
              {t('payments.stats.paidOrders')}
            </p>
            <h3 className="text-xl font-bold text-emerald-600 mt-1">
              {statsLoading ? '...' : stats.paidOrders?.toLocaleString()}
            </h3>
          </div>
          <div className="w-11 h-11 rounded-full bg-emerald-50 flex items-center justify-center text-emerald-600">
            <span className="material-symbols-outlined text-2xl">check_circle</span>
          </div>
        </div>

        {/* Tỷ lệ thành công */}
        <div className="bg-surface-container rounded-xl p-4 border border-outline-variant shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold text-on-surface-variant uppercase tracking-wider">
              {t('payments.stats.successRate')}
            </p>
            <h3 className="text-xl font-bold text-indigo-600 mt-1">
              {statsLoading ? '...' : `${stats.successRate}%`}
            </h3>
          </div>
          <div className="w-11 h-11 rounded-full bg-indigo-50 flex items-center justify-center text-indigo-600">
            <span className="material-symbols-outlined text-2xl">trending_up</span>
          </div>
        </div>
      </div>

      {/* Filter Toolbar */}
      <div className="bg-surface-container rounded-xl p-4 border border-outline-variant shadow-sm space-y-4">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3">
          {/* Search Input */}
          <div className="relative lg:col-span-2">
            <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant text-lg">
              search
            </span>
            <input
              type="text"
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
              placeholder={t('payments.filter.searchPlaceholder')}
              className="w-full pl-9 pr-8 py-2 bg-surface-container-lowest border border-outline-variant rounded-lg text-sm text-on-surface placeholder:text-on-surface-variant/60 focus:outline-none focus:border-primary transition-colors"
            />
            {search && (
              <button
                onClick={() => {
                  setSearch('');
                  setPage(1);
                }}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-on-surface-variant hover:text-on-surface"
              >
                <span className="material-symbols-outlined text-base">close</span>
              </button>
            )}
          </div>

          {/* Status Dropdown */}
          <div>
            <select
              value={statusFilter}
              onChange={(e) => {
                setStatusFilter(e.target.value);
                setPage(1);
              }}
              className="w-full px-3 py-2 bg-surface-container-lowest border border-outline-variant rounded-lg text-sm text-on-surface focus:outline-none focus:border-primary transition-colors cursor-pointer"
            >
              <option value="ALL">{t('payments.filter.statusAll')}</option>
              <option value="PAID">{t('payments.filter.statusPaid')}</option>
              <option value="PENDING">{t('payments.filter.statusPending')}</option>
              <option value="CANCELLED">{t('payments.filter.statusCancelled')}</option>
              <option value="EXPIRED">{t('payments.filter.statusExpired')}</option>
            </select>
          </div>

          {/* Package Dropdown */}
          <div>
            <select
              value={packageFilter}
              onChange={(e) => {
                setPackageFilter(e.target.value);
                setPage(1);
              }}
              className="w-full px-3 py-2 bg-surface-container-lowest border border-outline-variant rounded-lg text-sm text-on-surface focus:outline-none focus:border-primary transition-colors cursor-pointer"
            >
              <option value="ALL">{t('payments.filter.packageAll')}</option>
              <option value="PREMIUM_1_MONTH">{t('payments.filter.packageMonth')}</option>
              <option value="PREMIUM_6_MONTHS">{t('payments.filter.package6Months')}</option>
              <option value="PREMIUM_1_YEAR">{t('payments.filter.packageYear')}</option>
            </select>
          </div>

          {/* Reset Button */}
          <div className="flex items-center">
            <button
              onClick={handleResetFilters}
              className="w-full flex items-center justify-center gap-1.5 px-3 py-2 text-sm font-semibold text-on-surface-variant hover:text-on-surface bg-surface-container-high hover:bg-surface-container-highest rounded-lg border border-outline-variant transition-colors cursor-pointer"
            >
              <span className="material-symbols-outlined text-base">filter_alt_off</span>
              {t('payments.filter.reset')}
            </button>
          </div>
        </div>

        {/* Date Filters Row */}
        <div className="flex flex-wrap items-center gap-3 pt-2 border-t border-outline-variant/40 text-sm">
          <div className="flex items-center gap-2">
            <span className="text-xs font-semibold text-on-surface-variant">{t('payments.filter.fromDate')}:</span>
            <input
              type="date"
              value={fromDate}
              onChange={(e) => {
                setFromDate(e.target.value);
                setPage(1);
              }}
              className="px-2.5 py-1.5 bg-surface-container-lowest border border-outline-variant rounded-lg text-sm text-on-surface focus:outline-none focus:border-primary"
            />
          </div>
          <div className="flex items-center gap-2">
            <span className="text-xs font-semibold text-on-surface-variant">{t('payments.filter.toDate')}:</span>
            <input
              type="date"
              value={toDate}
              onChange={(e) => {
                setToDate(e.target.value);
                setPage(1);
              }}
              className="px-2.5 py-1.5 bg-surface-container-lowest border border-outline-variant rounded-lg text-sm text-on-surface focus:outline-none focus:border-primary"
            />
          </div>
        </div>
      </div>

      {/* Orders Data Table */}
      <div className="bg-surface-container rounded-xl border border-outline-variant shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm border-collapse">
            <thead>
              <tr className="bg-surface-container-high/60 border-b border-outline-variant text-on-surface-variant font-semibold text-xs uppercase tracking-wider">
                <th className="py-3.5 px-4">{t('payments.table.orderCode')}</th>
                <th className="py-3.5 px-4">{t('payments.table.user')}</th>
                <th className="py-3.5 px-4">{t('payments.table.package')}</th>
                <th className="py-3.5 px-4">{t('payments.table.amount')}</th>
                <th className="py-3.5 px-4 text-center">{t('payments.table.status')}</th>
                <th className="py-3.5 px-4">{t('payments.table.createdAt')}</th>
                <th className="py-3.5 px-4">{t('payments.table.paidAt')}</th>
                <th className="py-3.5 px-4 text-center">{t('payments.table.actions')}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-outline-variant/40">
              {loading ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-on-surface-variant">
                    <span className="material-symbols-outlined text-3xl animate-spin text-primary block mx-auto mb-2">
                      progress_activity
                    </span>
                    {t('common.loading')}
                  </td>
                </tr>
              ) : orders.length === 0 ? (
                <tr>
                  <td colSpan={8} className="py-12 text-center text-on-surface-variant">
                    <span className="material-symbols-outlined text-4xl text-outline-variant block mx-auto mb-2">
                      receipt_long
                    </span>
                    {t('payments.table.empty')}
                  </td>
                </tr>
              ) : (
                orders.map((order) => {
                  const cfg = STATUS_CONFIG[order.status] || {
                    bg: 'bg-slate-100',
                    text: 'text-slate-600',
                    border: 'border-slate-300',
                    icon: 'help',
                  };
                  return (
                    <tr
                      key={order.id}
                      className="hover:bg-surface-container-lowest/60 transition-colors"
                    >
                      <td className="py-3.5 px-4 font-mono font-bold text-on-surface">
                        #{order.order_code}
                      </td>
                      <td className="py-3.5 px-4">
                        <div className="font-semibold text-on-surface flex items-center gap-1.5">
                          <span className="material-symbols-outlined text-base text-on-surface-variant">
                            account_circle
                          </span>
                          <span>{order.account?.username || '—'}</span>
                        </div>
                        <div className="text-xs text-on-surface-variant mt-0.5">
                          {order.account?.User?.fullname || order.account?.email || ''}
                        </div>
                      </td>
                      <td className="py-3.5 px-4">
                        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-primary/10 text-primary border border-primary/20">
                          <span className="material-symbols-outlined text-[13px]">workspace_premium</span>
                          {order.package_type === 'PREMIUM_1_MONTH'
                            ? t('payments.filter.packageMonth')
                            : order.package_type}
                        </span>
                      </td>
                      <td className="py-3.5 px-4 font-semibold text-emerald-600 font-mono">
                        {formatVnd(order.amount)}
                      </td>
                      <td className="py-3.5 px-4 text-center">
                        <span
                          className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold border ${cfg.bg} ${cfg.text} ${cfg.border}`}
                        >
                          <span className="material-symbols-outlined text-[13px]">{cfg.icon}</span>
                          {order.status === 'PAID'
                            ? t('payments.filter.statusPaid')
                            : order.status === 'PENDING'
                            ? t('payments.filter.statusPending')
                            : order.status === 'CANCELLED'
                            ? t('payments.filter.statusCancelled')
                            : order.status === 'EXPIRED'
                            ? t('payments.filter.statusExpired')
                            : order.status}
                        </span>
                      </td>
                      <td className="py-3.5 px-4 text-on-surface-variant font-mono text-xs whitespace-nowrap">
                        {formatDate(order.created_at)}
                      </td>
                      <td className="py-3.5 px-4 text-on-surface-variant font-mono text-xs whitespace-nowrap">
                        {formatDate(order.paid_at)}
                      </td>
                      <td className="py-3.5 px-4 text-center">
                        <button
                          onClick={() => handleViewDetail(order.id)}
                          className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-semibold text-primary hover:text-white bg-primary/10 hover:bg-primary rounded-lg transition-colors cursor-pointer"
                          title={t('payments.table.viewDetail')}
                        >
                          <span className="material-symbols-outlined text-sm">visibility</span>
                          {t('common.details')}
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        <div className="p-4 border-t border-outline-variant/60">
          <Pagination
            currentPage={page}
            pageSize={pageSize}
            total={total}
            pageSizeOptions={[10, 20, 50, 100]}
            onPageChange={(p) => setPage(p)}
            onPageSizeChange={(sz) => {
              setPageSize(sz);
              setPage(1);
            }}
          />
        </div>
      </div>

      {/* Transaction Detail Modal */}
      {(selectedOrder || modalLoading) && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 animate-fadeIn">
          <div className="bg-surface-container rounded-2xl border border-outline-variant shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            {modalLoading ? (
              <div className="p-12 text-center text-on-surface-variant">
                <span className="material-symbols-outlined text-4xl animate-spin text-primary block mx-auto mb-2">
                  progress_activity
                </span>
                {t('common.loading')}
              </div>
            ) : selectedOrder ? (
              <div className="p-6 space-y-6">
                {/* Modal Header */}
                <div className="flex items-center justify-between pb-4 border-b border-outline-variant">
                  <div className="flex items-center gap-2">
                    <span className="material-symbols-outlined text-primary text-2xl">receipt_long</span>
                    <h3 className="text-lg font-bold text-on-surface">
                      {t('payments.detailModal.title')}
                    </h3>
                  </div>
                  <button
                    onClick={() => setSelectedOrder(null)}
                    className="text-on-surface-variant hover:text-on-surface p-1 rounded-lg hover:bg-surface-container-highest cursor-pointer"
                  >
                    <span className="material-symbols-outlined text-xl">close</span>
                  </button>
                </div>

                {/* Section 1: Order Information */}
                <div>
                  <h4 className="text-xs font-bold text-on-surface-variant uppercase tracking-wider mb-3">
                    {t('payments.detailModal.orderInfo')}
                  </h4>
                  <div className="grid grid-cols-2 gap-3 text-sm bg-surface-container-lowest p-4 rounded-xl border border-outline-variant">
                    <div>
                      <span className="text-on-surface-variant text-xs">{t('payments.detailModal.orderCode')}:</span>
                      <p className="font-mono font-bold text-on-surface">#{selectedOrder.order_code}</p>
                    </div>
                    <div>
                      <span className="text-on-surface-variant text-xs">{t('payments.detailModal.status')}:</span>
                      <p className="font-semibold text-on-surface">{selectedOrder.status}</p>
                    </div>
                    <div>
                      <span className="text-on-surface-variant text-xs">{t('payments.detailModal.amount')}:</span>
                      <p className="font-mono font-bold text-emerald-600">{formatVnd(selectedOrder.amount)}</p>
                    </div>
                    <div>
                      <span className="text-on-surface-variant text-xs">{t('payments.detailModal.packageType')}:</span>
                      <p className="font-semibold text-on-surface">{selectedOrder.package_type}</p>
                    </div>
                    <div>
                      <span className="text-on-surface-variant text-xs">{t('payments.detailModal.createdAt')}:</span>
                      <p className="font-mono text-xs text-on-surface">{formatDate(selectedOrder.created_at)}</p>
                    </div>
                    <div>
                      <span className="text-on-surface-variant text-xs">{t('payments.detailModal.paidAt')}:</span>
                      <p className="font-mono text-xs text-on-surface">{formatDate(selectedOrder.paid_at)}</p>
                    </div>
                    {selectedOrder.payment_link_id && (
                      <div className="col-span-2">
                        <span className="text-on-surface-variant text-xs">{t('payments.detailModal.payosLinkId')}:</span>
                        <p className="font-mono text-xs text-on-surface-variant break-all">{selectedOrder.payment_link_id}</p>
                      </div>
                    )}
                  </div>
                </div>

                {/* Section 2: Customer Information */}
                <div>
                  <h4 className="text-xs font-bold text-on-surface-variant uppercase tracking-wider mb-3">
                    {t('payments.detailModal.customerInfo')}
                  </h4>
                  <div className="grid grid-cols-2 gap-3 text-sm bg-surface-container-lowest p-4 rounded-xl border border-outline-variant">
                    <div>
                      <span className="text-on-surface-variant text-xs">{t('payments.detailModal.username')}:</span>
                      <p className="font-bold text-on-surface">{selectedOrder.account?.username || '—'}</p>
                    </div>
                    <div>
                      <span className="text-on-surface-variant text-xs">{t('payments.detailModal.fullname')}:</span>
                      <p className="font-semibold text-on-surface">{selectedOrder.account?.User?.fullname || '—'}</p>
                    </div>
                    <div>
                      <span className="text-on-surface-variant text-xs">{t('payments.detailModal.email')}:</span>
                      <p className="text-on-surface">{selectedOrder.account?.email || '—'}</p>
                    </div>
                    <div>
                      <span className="text-on-surface-variant text-xs">{t('payments.detailModal.accountType')}:</span>
                      <p className="font-semibold text-primary">{selectedOrder.account?.type || '—'}</p>
                    </div>
                  </div>
                </div>

                {/* Section 3: Webhook Settlements */}
                <div>
                  <h4 className="text-xs font-bold text-on-surface-variant uppercase tracking-wider mb-3">
                    {t('payments.detailModal.transactions')}
                  </h4>
                  {(!selectedOrder.payment_transaction || selectedOrder.payment_transaction.length === 0) ? (
                    <div className="p-4 bg-surface-container-lowest rounded-xl border border-outline-variant text-center text-sm text-on-surface-variant">
                      {t('payments.detailModal.noTransactions')}
                    </div>
                  ) : (
                    <div className="space-y-2">
                      {selectedOrder.payment_transaction.map((tx) => (
                        <div
                          key={tx.id}
                          className="bg-surface-container-lowest p-3 rounded-xl border border-outline-variant space-y-2 text-xs"
                        >
                          <div className="flex items-center justify-between">
                            <span className="font-semibold text-on-surface flex items-center gap-1">
                              <span className="material-symbols-outlined text-sm text-primary">account_balance</span>
                              {tx.bank_code || 'VietQR'}
                            </span>
                            <span className="font-mono font-bold text-emerald-600">
                              {formatVnd(tx.amount)}
                            </span>
                          </div>
                          <div className="grid grid-cols-2 gap-2 text-on-surface-variant">
                            <div>
                              <span>{t('payments.detailModal.txId')}:</span>{' '}
                              <span className="font-mono font-bold text-on-surface">{tx.payos_transaction_id || '—'}</span>
                            </div>
                            <div>
                              <span>{t('payments.detailModal.txTime')}:</span>{' '}
                              <span className="font-mono">{formatDate(tx.transaction_time)}</span>
                            </div>
                            <div className="col-span-2 flex items-center gap-1.5">
                              <span>{t('payments.detailModal.signature')}:</span>{' '}
                              <span className={`inline-flex items-center gap-0.5 px-2 py-0.5 rounded text-[11px] font-semibold ${
                                tx.signature_verified
                                  ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                  : 'bg-rose-50 text-rose-700 border border-rose-200'
                              }`}>
                                <span className="material-symbols-outlined text-xs">
                                  {tx.signature_verified ? 'verified' : 'gpp_bad'}
                                </span>
                                {tx.signature_verified
                                  ? t('payments.detailModal.sigVerified')
                                  : t('payments.detailModal.sigUnverified')}
                              </span>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {/* Modal Footer */}
                <div className="flex justify-end pt-4 border-t border-outline-variant">
                  <button
                    onClick={() => setSelectedOrder(null)}
                    className="px-4 py-2 bg-surface-container-high hover:bg-surface-container-highest text-on-surface rounded-lg font-semibold text-sm transition-colors cursor-pointer"
                  >
                    {t('payments.detailModal.close')}
                  </button>
                </div>
              </div>
            ) : null}
          </div>
        </div>
      )}

      {/* Sample Test QR Code Modal */}
      {showSampleModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-xs animate-fadeIn">
          <div className="bg-surface-container rounded-2xl border border-outline-variant shadow-2xl max-w-3xl w-full max-h-[92vh] overflow-y-auto">
            {/* Header */}
            <div className="flex items-center justify-between p-6 pb-4 border-b border-outline-variant">
              <div className="flex items-center gap-2.5">
                <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center text-primary">
                  <span className="material-symbols-outlined text-2xl">qr_code_2</span>
                </div>
                <div>
                  <h3 className="text-lg font-bold text-on-surface">
                    {t('payments.sampleModal.title')}
                  </h3>
                  <p className="text-xs text-on-surface-variant">
                    {t('payments.sampleModal.subtitle')}
                  </p>
                </div>
              </div>
              <button
                onClick={() => setShowSampleModal(false)}
                className="text-on-surface-variant hover:text-on-surface p-1.5 rounded-lg hover:bg-surface-container-highest transition-colors cursor-pointer"
              >
                <span className="material-symbols-outlined text-xl">close</span>
              </button>
            </div>

            <div className="p-6 space-y-5">
              {/* Banner Warning / Badge */}
              <div className="bg-emerald-500/10 border border-emerald-500/30 rounded-xl p-3.5 flex items-start gap-3 text-emerald-900 dark:text-emerald-100">
                <span className="material-symbols-outlined text-emerald-600 text-xl flex-shrink-0 mt-0.5">
                  verified
                </span>
                <div className="text-xs space-y-1">
                  <div className="font-bold uppercase tracking-wider text-emerald-700 dark:text-emerald-300 flex items-center gap-1.5">
                    <span>{t('payments.sampleModal.warningBadge')}</span>
                    <span className="px-1.5 py-0.2 bg-emerald-600 text-white rounded text-[10px] lowercase font-normal">
                      live gateway
                    </span>
                  </div>
                  <p className="leading-relaxed opacity-90">
                    {t('payments.sampleModal.warningDesc')}
                  </p>
                </div>
              </div>

              {/* Amount Quick Selector */}
              <div className="bg-surface-container-lowest p-3.5 rounded-xl border border-outline-variant space-y-2">
                <span className="text-xs font-bold text-on-surface uppercase tracking-wider block">
                  {t('payments.sampleModal.selectAmountLabel')}
                </span>
                <div className="flex flex-wrap gap-2">
                  <button
                    type="button"
                    onClick={() => {
                      setSelectedSampleAmount(2000);
                      setSelectedSamplePackage('PREMIUM_1_MONTH');
                    }}
                    className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
                      selectedSampleAmount === 2000
                        ? 'bg-primary text-white shadow-sm'
                        : 'bg-surface-container-high hover:bg-surface-container-highest text-on-surface border border-outline-variant'
                    }`}
                  >
                    {t('payments.sampleModal.amount2k')}
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setSelectedSampleAmount(49000);
                      setSelectedSamplePackage('PREMIUM_1_MONTH');
                    }}
                    className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
                      selectedSampleAmount === 49000
                        ? 'bg-primary text-white shadow-sm'
                        : 'bg-surface-container-high hover:bg-surface-container-highest text-on-surface border border-outline-variant'
                    }`}
                  >
                    {t('payments.sampleModal.amountMonth')}
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setSelectedSampleAmount(270000);
                      setSelectedSamplePackage('PREMIUM_6_MONTHS');
                    }}
                    className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all cursor-pointer ${
                      selectedSampleAmount === 270000
                        ? 'bg-primary text-white shadow-sm'
                        : 'bg-surface-container-high hover:bg-surface-container-highest text-on-surface border border-outline-variant'
                    }`}
                  >
                    {t('payments.sampleModal.amount6Months')}
                  </button>
                </div>
              </div>

              {/* 2 Columns: Left = QR Code with live image, Right = Transfer Info & Test Actions */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6 items-start">
                {/* Left Column: QR Code */}
                <div className="flex flex-col items-center bg-surface-container-lowest p-5 rounded-2xl border border-outline-variant text-center relative group min-h-[340px] justify-center">
                  {/* Badge on QR */}
                  <div className="absolute top-3 left-3 bg-emerald-600 text-white text-[10px] font-extrabold uppercase px-2 py-0.5 rounded shadow tracking-wider flex items-center gap-1">
                    <span className="material-symbols-outlined text-[12px]">verified</span>
                    {t('payments.sampleModal.payosTag')}
                  </div>

                  {payosLoading ? (
                    <div className="py-20 text-center text-on-surface-variant space-y-2">
                      <span className="material-symbols-outlined text-3xl animate-spin text-primary block mx-auto">
                        progress_activity
                      </span>
                      <p className="text-xs">{t('common.loading')}</p>
                    </div>
                  ) : (
                    <>
                      <div className="p-2 bg-white rounded-xl shadow-md border border-slate-200 my-2">
                        <img
                          src={payosData?.qrUrl || `https://img.vietqr.io/image/970422-2512070399999-compact2.png?amount=${selectedSampleAmount}&addInfo=PFM%20TEST&accountName=NGUYEN%20PHU%20BAO`}
                          alt="Mã QR Kênh Thanh Toán PayOS MB Bank"
                          className="w-56 h-auto object-contain mx-auto rounded"
                          loading="lazy"
                        />
                      </div>
                      <div className="flex items-center gap-1.5 text-xs text-on-surface-variant mt-2 font-medium">
                        <span className="material-symbols-outlined text-sm text-primary">smartphone</span>
                        <span>{t('payments.sampleModal.scanNotice')}</span>
                      </div>
                      <div className="mt-1 text-[11px] text-on-surface-variant/70 font-mono">
                        {payosData?.bankName || 'MB Bank (Quân Đội)'} • STK: {payosData?.accountNumber || '2512070399999'}
                      </div>

                      {payosData?.checkoutUrl && (
                        <a
                          href={payosData.checkoutUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="mt-3 inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold shadow-xs transition-all active:scale-95 cursor-pointer"
                        >
                          <span className="material-symbols-outlined text-sm">open_in_new</span>
                          <span>{t('payments.sampleModal.openPayosCheckout')}</span>
                        </a>
                      )}
                    </>
                  )}
                </div>

                {/* Right Column: Transfer Info & Actions */}
                <div className="space-y-4">
                  <div className="bg-surface-container-lowest p-4 rounded-xl border border-outline-variant space-y-2.5 text-xs">
                    <h4 className="font-bold text-on-surface uppercase tracking-wider text-[11px] flex items-center justify-between pb-2 border-b border-outline-variant/60">
                      <span className="flex items-center gap-1.5">
                        <span className="material-symbols-outlined text-sm text-primary">account_balance</span>
                        {t('payments.sampleModal.bankInfo')}
                      </span>
                      {payosData?.orderCode && (
                        <span className="font-mono text-[11px] text-primary font-bold">
                          #{payosData.orderCode}
                        </span>
                      )}
                    </h4>
                    <div className="flex justify-between py-1 border-b border-outline-variant/30">
                      <span className="text-on-surface-variant">{t('payments.sampleModal.bankName')}:</span>
                      <span className="font-semibold text-on-surface">
                        {payosData?.bankName || t('payments.sampleModal.bankValue')}
                      </span>
                    </div>
                    <div className="flex justify-between py-1 border-b border-outline-variant/30">
                      <span className="text-on-surface-variant">{t('payments.sampleModal.accountNo')}:</span>
                      <span className="font-mono font-bold text-on-surface">
                        {payosData?.accountNumber || '2512070399999'}
                      </span>
                    </div>
                    <div className="flex justify-between py-1 border-b border-outline-variant/30">
                      <span className="text-on-surface-variant">{t('payments.sampleModal.accountName')}:</span>
                      <span className="font-bold text-on-surface">
                        {payosData?.accountName || 'NGUYEN PHU BAO'}
                      </span>
                    </div>
                    <div className="flex justify-between py-1 border-b border-outline-variant/30">
                      <span className="text-on-surface-variant">{t('payments.sampleModal.package')}:</span>
                      <span className="font-semibold text-primary">
                        {selectedSamplePackage === 'PREMIUM_6_MONTHS'
                          ? t('payments.filter.package6Months')
                          : t('payments.filter.packageMonth')}
                      </span>
                    </div>
                    <div className="flex justify-between py-1 border-b border-outline-variant/30">
                      <span className="text-on-surface-variant">{t('payments.sampleModal.amount')}:</span>
                      <span className="font-mono font-bold text-emerald-600 text-sm">
                        {formatVnd(payosData?.amount || selectedSampleAmount)}
                      </span>
                    </div>
                    <div className="flex justify-between py-1">
                      <span className="text-on-surface-variant">{t('payments.sampleModal.transferContent')}:</span>
                      <span className="font-mono font-bold text-on-surface bg-surface-container-high px-2 py-0.5 rounded break-all">
                        {payosData?.description || 'PFM PREMIUM TEST'}
                      </span>
                    </div>
                  </div>

                  {/* Test Actions */}
                  <div className="space-y-2 pt-1">
                    <p className="text-xs font-bold text-on-surface-variant uppercase tracking-wider">
                      {t('payments.sampleModal.testActions')}:
                    </p>
                    
                    <button
                      onClick={() => handleCreateSampleOrder(false)}
                      disabled={actionLoading}
                      className="w-full flex items-center justify-center gap-2 py-2.5 px-3 bg-amber-50 hover:bg-amber-100 text-amber-800 border border-amber-300 rounded-xl text-xs font-bold transition-all duration-150 cursor-pointer disabled:opacity-50"
                    >
                      <span className="material-symbols-outlined text-base">add_circle</span>
                      <span>{t('payments.sampleModal.createPendingBtn')}</span>
                    </button>

                    <button
                      onClick={() => handleCreateSampleOrder(true)}
                      disabled={actionLoading}
                      className="w-full flex items-center justify-center gap-2 py-2.5 px-3 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold shadow-sm transition-all duration-150 cursor-pointer disabled:opacity-50"
                    >
                      <span className="material-symbols-outlined text-base">task_alt</span>
                      <span>{t('payments.sampleModal.createPaidBtn')}</span>
                    </button>

                    <button
                      onClick={handleCleanSampleOrders}
                      disabled={actionLoading}
                      className="w-full flex items-center justify-center gap-1.5 py-2 px-3 text-on-surface-variant hover:text-rose-600 bg-surface-container-high hover:bg-rose-50 border border-outline-variant rounded-xl text-xs font-medium transition-all duration-150 cursor-pointer disabled:opacity-50"
                    >
                      <span className="material-symbols-outlined text-sm">delete_sweep</span>
                      <span>{t('payments.sampleModal.cleanBtn')}</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>

            {/* Footer */}
            <div className="p-4 px-6 border-t border-outline-variant flex justify-end">
              <button
                onClick={() => setShowSampleModal(false)}
                className="px-4 py-2 bg-surface-container-high hover:bg-surface-container-highest text-on-surface rounded-lg font-semibold text-sm transition-colors cursor-pointer"
              >
                {t('payments.sampleModal.close')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default PaymentHistoryPage;
