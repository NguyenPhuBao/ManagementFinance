import React, { useState, useEffect, useCallback } from 'react';
import paymentApi from '../../api/payment.api';
import Pagination from '../../components/common/Pagination';
import SecurityConfirmModal from '../../components/common/SecurityConfirmModal';
import { useLanguageSafe } from '../../store/language.context';
import useSocket from '../../hooks/useSocket';

const STATUS_CONFIG = {
  PAID: { bg: 'bg-emerald-50', text: 'text-emerald-700', border: 'border-emerald-200', icon: 'check_circle' },
  PENDING: { bg: 'bg-amber-50', text: 'text-amber-700', border: 'border-amber-200', icon: 'schedule' },
  WAITING_CONFIRMATION: { bg: 'bg-purple-50', text: 'text-purple-700', border: 'border-purple-200', icon: 'rule' },
  REFUND_PENDING: { bg: 'bg-orange-50', text: 'text-orange-700', border: 'border-orange-200', icon: 'currency_exchange' },
  REFUNDED: { bg: 'bg-teal-50', text: 'text-teal-700', border: 'border-teal-200', icon: 'assignment_return' },
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

const getStatusLabel = (status, t) => {
  switch (status) {
    case 'PAID':
      return t('payments.filter.statusPaid');
    case 'PENDING':
      return t('payments.filter.statusPending');
    case 'WAITING_CONFIRMATION':
      return t('payments.filter.statusWaitingConfirmation');
    case 'REFUND_PENDING':
      return t('payments.filter.statusRefundPending');
    case 'REFUNDED':
      return t('payments.filter.statusRefunded');
    case 'CANCELLED':
      return t('payments.filter.statusCancelled');
    case 'EXPIRED':
      return t('payments.filter.statusExpired');
    default:
      return status;
  }
};

const PaymentHistoryPage = () => {
  const { t } = useLanguageSafe();
  const socket = useSocket();

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
  const [packageTypes, setPackageTypes] = useState(['Basic', 'Premium']);
  const [excludeTemplate, setExcludeTemplate] = useState(false);
  const [fromDate, setFromDate] = useState('');
  const [toDate, setToDate] = useState('');

  // Detail Modal
  const [selectedOrder, setSelectedOrder] = useState(null);
  const [modalLoading, setModalLoading] = useState(false);
  const [feedbackMsg, setFeedbackMsg] = useState(null);
  const [detailCountdown, setDetailCountdown] = useState(null);

  // Sample QR Modal & Live PayOS Channel State (Client-app Sandbox Roleplay)
  const [showSampleModal, setShowSampleModal] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [payosData, setPayosData] = useState(null);
  const [payosLoading, setPayosLoading] = useState(false);
  const [selectedSampleAmount, setSelectedSampleAmount] = useState(49000);
  const [selectedSamplePackage, setSelectedSamplePackage] = useState('PREMIUM_1_MONTH');
  const [countdownSeconds, setCountdownSeconds] = useState(600);
  const [copiedCode, setCopiedCode] = useState(false);

  // Refund Processing Modal State
  const [refundTargetOrder, setRefundTargetOrder] = useState(null);
  const [refundProofFile, setRefundProofFile] = useState(null);
  const [refundProofPreview, setRefundProofPreview] = useState(null);
  const [refundForm, setRefundForm] = useState({
    refunded_amount: '',
    refund_reason: 'Chuyển thiếu tiền, hoàn trả khách hàng',
    refund_proof: '',
  });
  const [refundSubmitting, setRefundSubmitting] = useState(false);
  const [showRefundSecurityModal, setShowRefundSecurityModal] = useState(false);

  // Fetch package types from DB on mount
  useEffect(() => {
    const fetchPackageTypes = async () => {
      try {
        const res = await paymentApi.getPackageTypes();
        const raw = res?.data?.data || res?.data || res;
        const types = Array.isArray(raw) ? raw : (Array.isArray(raw?.data) ? raw.data : []);
        if (types.length > 0) {
          setPackageTypes(types);
        }
      } catch (err) {
        console.error('[PAYMENT_PAGE] Lỗi khi tải danh sách gói cước:', err);
      }
    };
    fetchPackageTypes();
  }, []);

  // Countdown Timer for Sandbox Modal (10 mins)
  useEffect(() => {
    if (!showSampleModal) {
      setCountdownSeconds(600);
      return;
    }
    const timer = setInterval(() => {
      setCountdownSeconds((prev) => (prev > 0 ? prev - 1 : 0));
    }, 1000);
    return () => clearInterval(timer);
  }, [showSampleModal]);

  const formatCountdown = (secs) => {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  // Fetch KPI Stats
  // Fetch Summary Stats (Luôn luôn loại trừ đơn mẫu khỏi doanh thu và thông số kinh doanh)
  const loadStats = useCallback(async () => {
    setStatsLoading(true);
    try {
      const res = await paymentApi.getStats({
        ...(fromDate && { fromDate }),
        ...(toDate && { toDate }),
        excludeTemplate: 'true',
      });
      const data = res?.data?.data || res?.data || res;
      if (data && data.totalOrders !== undefined) {
        setStats(data);
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
        ...(excludeTemplate && { excludeTemplate: 'true' }),
      };
      const res = await paymentApi.getOrders(params);
      const data = res?.data?.data || res?.data || res;
      setOrders(data.items || []);
      setTotal(data.total || 0);
    } catch (err) {
      console.error('[PAYMENT_PAGE] Lỗi khi tải danh sách đơn hàng:', err);
      setOrders([]);
      setTotal(0);
    } finally {
      setLoading(false);
    }
  }, [page, pageSize, search, statusFilter, packageFilter, fromDate, toDate, excludeTemplate]);

  // Socket.IO Real-time Events
  useEffect(() => {
    if (!socket) return;

    const onPaymentSuccess = (data) => {
      loadStats();
      loadOrders();
      setFeedbackMsg(`🎉 ${t('payments.sandbox.successTitle')} (#${data.orderCode || data.order_code})`);
      setTimeout(() => setFeedbackMsg(null), 4000);

      const incomingCode = String(data.orderCode || data.order_code || '');
      setSelectedOrder((prev) => {
        if (!prev) return prev;
        if (String(prev.order_code) === incomingCode || prev.id === data.orderId) {
          return {
            ...prev,
            status: 'PAID',
            paid_at: new Date().toISOString(),
            qr_url: null,
            checkout_url: null,
          };
        }
        return prev;
      });

      setPayosData((prev) => {
        if (!prev) return prev;
        if (String(prev.orderCode) === incomingCode) {
          return null;
        }
        return prev;
      });
    };

    const onOverpaidConfirmation = (data) => {
      loadStats();
      loadOrders();
      setSandboxConfirmation({
        orderCode: data.orderCode,
        amountReceived: data.amountReceived,
        expectedAmount: data.expectedAmount,
        difference: data.difference,
      });
    };

    const onUnderpaidWarning = (data) => {
      loadStats();
      loadOrders();
      setSandboxUnderpaid({
        orderCode: data.orderCode,
        amountReceived: data.amountReceived,
        expectedAmount: data.expectedAmount,
      });
    };

    const onRefunded = () => {
      loadStats();
      loadOrders();
    };

    const onOrderCreated = (data) => {
      loadStats();
      loadOrders();
      setFeedbackMsg(`🆕 Đơn hàng mới: #${data.orderCode || data.order_code || ''}`);
      setTimeout(() => setFeedbackMsg(null), 3500);
    };

    const onOrderExpired = () => {
      loadStats();
      loadOrders();
    };

    socket.on('payment.order_created', onOrderCreated);
    socket.on('payment.success', onPaymentSuccess);
    socket.on('payment.overpaid_confirmation', onOverpaidConfirmation);
    socket.on('payment.underpaid_warning', onUnderpaidWarning);
    socket.on('payment.refunded', onRefunded);
    socket.on('payment.order_expired', onOrderExpired);

    return () => {
      socket.off('payment.order_created', onOrderCreated);
      socket.off('payment.success', onPaymentSuccess);
      socket.off('payment.overpaid_confirmation', onOverpaidConfirmation);
      socket.off('payment.underpaid_warning', onUnderpaidWarning);
      socket.off('payment.refunded', onRefunded);
      socket.off('payment.order_expired', onOrderExpired);
    };
  }, [socket, loadStats, loadOrders, t]);

  // Countdown Timer for Selected Order in Detail Modal
  useEffect(() => {
    if (!selectedOrder) {
      setDetailCountdown(null);
      return;
    }

    const calcRemaining = () => {
      if (selectedOrder.status !== 'PENDING') return null;
      const targetTime = selectedOrder.expired_at
        ? new Date(selectedOrder.expired_at).getTime()
        : (selectedOrder.created_at ? new Date(selectedOrder.created_at).getTime() + 10 * 60 * 1000 : null);
      if (!targetTime) return null;
      return Math.max(0, Math.floor((targetTime - Date.now()) / 1000));
    };

    const initialRemaining = calcRemaining();
    setDetailCountdown(initialRemaining);
    if (initialRemaining === 0 && selectedOrder.status === 'PENDING') {
      setSelectedOrder((prev) => (prev ? { ...prev, status: 'EXPIRED', qr_url: null, checkout_url: null } : null));
      loadOrders();
      loadStats();
    }

    const interval = setInterval(() => {
      const remaining = calcRemaining();
      setDetailCountdown(remaining);
      if (remaining === 0 && selectedOrder.status === 'PENDING') {
        setSelectedOrder((prev) => (prev ? { ...prev, status: 'EXPIRED', qr_url: null, checkout_url: null } : null));
        loadOrders();
        loadStats();
      }
    }, 1000);

    return () => clearInterval(interval);
  }, [selectedOrder, loadOrders, loadStats]);

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
    setExcludeTemplate(false);
    setPage(1);
  };

  const handleViewDetail = async (orderId) => {
    setModalLoading(true);
    try {
      const res = await paymentApi.getOrderDetail(orderId);
      const data = res?.data?.data || res?.data || res;
      if (data && (data.id || data.order_code)) {
        setSelectedOrder(data);
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
      const data = res?.data?.data || res?.data || res;
      if (res?.success || res?.data?.success || data?.order_code) {
        setPayosData({
          orderCode: data.order_code,
          qrUrl: data.qr_url,
          recognitionCode: data.recognition_code,
          description: data.transfer_content || data.recognition_code,
          amount: data.amount,
          bankName: data.bank_info?.bankName || 'MB Bank (Quân Đội)',
          accountNumber: data.bank_info?.accountNumber || '2512070399999',
          accountName: data.bank_info?.accountName || 'NGUYEN PHU BAO',
          checkoutUrl: data.checkout_url || data.bank_info?.checkoutUrl,
        });
        setCountdownSeconds(600);
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
      if (res?.success || res?.data?.success) {
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

  // Open Refund Modal
  const handleOpenRefundModal = (order) => {
    setRefundTargetOrder(order);
    setRefundProofFile(null);
    setRefundProofPreview(null);
    setRefundForm({
      refunded_amount: order.amount_received || order.amount || '',
      refund_reason: order.refund_reason || 'Chuyển thiếu tiền, hoàn trả khách hàng',
      refund_proof: order.refund_proof || '',
    });
  };

  // Initiate Refund Form (mở Security Confirm Modal yêu cầu xác thực PIN)
  const handleInitiateRefund = (e) => {
    e.preventDefault();
    if (!refundTargetOrder) return;
    if (!refundForm.refunded_amount || Number(refundForm.refunded_amount) <= 0) return;
    setShowRefundSecurityModal(true);
  };

  // Execute Refund sau khi đã xác thực PIN / Mật khẩu thành công
  const handleExecuteRefund = async () => {
    if (!refundTargetOrder) return;
    setRefundSubmitting(true);
    try {
      const formData = new FormData();
      formData.append('refunded_amount', Number(refundForm.refunded_amount));
      formData.append('refund_reason', refundForm.refund_reason);
      formData.append('refunded_at', new Date().toISOString());
      if (refundProofFile) {
        formData.append('proofFile', refundProofFile);
      } else if (refundForm.refund_proof) {
        formData.append('refund_proof', refundForm.refund_proof);
      }

      const res = await paymentApi.processRefund(refundTargetOrder.id, formData);
      if (res?.success || res?.data?.success) {
        setRefundTargetOrder(null);
        setFeedbackMsg(t('payments.refundModal.successMsg'));
        if (selectedOrder && selectedOrder.id === refundTargetOrder.id) {
          handleViewDetail(selectedOrder.id);
        }
        await Promise.all([loadStats(), loadOrders()]);
        setTimeout(() => setFeedbackMsg(null), 3500);
      }
    } catch (err) {
      console.error('[PAYMENT_PAGE] Lỗi khi xử lý hoàn tiền:', err);
    } finally {
      setRefundSubmitting(false);
    }
  };

  const handleCopyRecognitionCode = (code) => {
    if (!code) return;
    navigator.clipboard?.writeText(code);
    setCopiedCode(true);
    setTimeout(() => setCopiedCode(false), 2000);
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
        </div>
        <div className="flex items-center gap-3">
          {feedbackMsg && (
            <span className="text-sm font-medium text-emerald-600 bg-emerald-50 px-3 py-1.5 rounded-lg border border-emerald-200 animate-fadeIn">
              {feedbackMsg}
            </span>
          )}
          <button
            onClick={() => {
              setPayosData(null);
              setShowSampleModal(true);
            }}
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
            <p className="text-[10px] text-on-surface-variant/70 mt-0.5">
              *{t('payments.stats.realRevenueNote')}
            </p>
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
              <option value="WAITING_CONFIRMATION">{t('payments.filter.statusWaitingConfirmation')}</option>
              <option value="REFUND_PENDING">{t('payments.filter.statusRefundPending')}</option>
              <option value="REFUNDED">{t('payments.filter.statusRefunded')}</option>
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
              {packageTypes.map((pkg) => {
                const pkgId = typeof pkg === 'object' && pkg !== null ? pkg.id : pkg;
                const pkgName = typeof pkg === 'object' && pkg !== null ? (pkg.name || pkg.id) : pkg;
                const isDefault = (typeof pkg === 'object' && pkg !== null && pkg.isDefault) || pkgId === 'Basic';
                const pkgLabel = isDefault
                  ? (pkgName.includes('Mặc định') ? pkgName : `${pkgName} (Mặc định)`)
                  : (pkgId === 'PREMIUM_1_MONTH' ? t('payments.filter.packageMonth') : pkgName);
                return (
                  <option key={pkgId} value={pkgId}>
                    {pkgLabel}
                  </option>
                );
              })}
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
        <div className="flex flex-wrap items-center justify-between gap-3 pt-2 border-t border-outline-variant/40 text-sm">
          <div className="flex flex-wrap items-center gap-3">
            <div className="flex items-center gap-2">
              <span className="text-xs font-semibold text-on-surface-variant">Từ ngày (Ngày tạo):</span>
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
              <span className="text-xs font-semibold text-on-surface-variant">Đến ngày (Ngày tạo):</span>
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
          <label className="flex items-center gap-2 cursor-pointer text-xs font-bold text-on-surface select-none bg-surface-container-high px-3 py-1.5 rounded-lg border border-outline-variant hover:bg-surface-container-highest transition-colors">
            <input
              type="checkbox"
              id="excludeTemplateCheckbox"
              checked={excludeTemplate}
              onChange={(e) => {
                setExcludeTemplate(e.target.checked);
                setPage(1);
              }}
              className="w-4 h-4 text-primary rounded border-outline-variant focus:ring-primary cursor-pointer accent-primary"
            />
            <span>Loại bỏ mẫu</span>
          </label>
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
                  const isExpiredOrder = order.status === 'EXPIRED' || (order.status === 'PENDING' && order.expired_at && new Date(order.expired_at) <= new Date());
                  const effectiveStatus = isExpiredOrder ? 'EXPIRED' : order.status;
                  const cfg = STATUS_CONFIG[effectiveStatus] || {
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
                        <div className="flex flex-col">
                          <div className="flex items-center gap-1.5">
                            <span>#{order.order_code}</span>
                            {order.is_template && (
                              <span className="px-1.5 py-0.2 rounded text-[10px] font-bold bg-amber-100 text-amber-800 border border-amber-300">
                                Mẫu
                              </span>
                            )}
                          </div>
                          {order.recognition_code && (
                            <span className="text-[11px] font-mono text-primary font-normal">
                              Mã: {order.recognition_code}
                            </span>
                          )}
                        </div>
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
                        <div>{formatVnd(order.amount)}</div>
                        {order.amount_received && order.amount_received !== order.amount && (
                          <div className="text-[11px] text-on-surface-variant">
                            Thực nhận: {formatVnd(order.amount_received)}
                          </div>
                        )}
                      </td>
                      <td className="py-3.5 px-4 text-center">
                        <span
                          className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold border ${cfg.bg} ${cfg.text} ${cfg.border}`}
                        >
                          <span className="material-symbols-outlined text-[13px]">{cfg.icon}</span>
                          {getStatusLabel(effectiveStatus, t)}
                        </span>
                      </td>
                      <td className="py-3.5 px-4 text-on-surface-variant font-mono text-xs whitespace-nowrap">
                        {formatDate(order.created_at)}
                      </td>
                      <td className="py-3.5 px-4 text-on-surface-variant font-mono text-xs whitespace-nowrap">
                        {formatDate(order.paid_at)}
                      </td>
                      <td className="py-3.5 px-4 text-center">
                        <div className="flex items-center justify-center gap-1.5">
                          <button
                            onClick={() => handleViewDetail(order.id)}
                            className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-semibold text-primary hover:text-white bg-primary/10 hover:bg-primary rounded-lg transition-colors cursor-pointer"
                            title={t('payments.table.viewDetail')}
                          >
                            <span className="material-symbols-outlined text-sm">visibility</span>
                            {t('common.details')}
                          </button>
                          {order.status === 'REFUND_PENDING' ? (
                            <button
                              onClick={() => handleOpenRefundModal(order)}
                              className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-semibold text-orange-700 hover:text-white bg-orange-100 hover:bg-orange-600 rounded-lg transition-colors cursor-pointer border border-orange-300"
                              title={t('payments.table.refundBtn')}
                            >
                              <span className="material-symbols-outlined text-sm">currency_exchange</span>
                              {t('payments.table.refundBtn')}
                            </button>
                          ) : (
                            <button
                              disabled
                              className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-semibold text-slate-400 bg-slate-100/70 rounded-lg cursor-not-allowed border border-slate-200 opacity-40"
                              title="Chỉ khả dụng khi đơn hàng cần hoàn trả (REFUND_PENDING)"
                            >
                              <span className="material-symbols-outlined text-sm">currency_exchange</span>
                              {t('payments.table.refundBtn')}
                            </button>
                          )}
                        </div>
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

                {/* QR Code & Payment Countdown for Order */}
                {selectedOrder && (
                  (() => {
                    const isPendingActive = selectedOrder.status === 'PENDING' &&
                      (!selectedOrder.expired_at || new Date(selectedOrder.expired_at) > new Date()) &&
                      Boolean(selectedOrder.qr_url);

                    if (isPendingActive) {
                      return (
                        <div className="bg-surface-container-lowest p-4 rounded-xl border border-outline-variant space-y-3">
                          <div className="flex flex-wrap items-center justify-between gap-2 pb-2 border-b border-outline-variant/60">
                            <span className="text-xs font-bold text-on-surface uppercase tracking-wider flex items-center gap-1.5">
                              <span className="material-symbols-outlined text-primary text-base">qr_code_2</span>
                              Mã QR Thanh toán VietQR (MB Bank)
                            </span>
                            <div className={`px-2.5 py-1 rounded-lg text-xs font-mono font-bold flex items-center gap-1.5 ${
                              detailCountdown !== null && detailCountdown > 0
                                ? 'bg-amber-100 text-amber-900 border border-amber-300 dark:bg-amber-950/50 dark:text-amber-200 dark:border-amber-700'
                                : 'bg-red-100 text-red-900 border border-red-300 dark:bg-red-950/50 dark:text-red-200 dark:border-red-700'
                            }`}>
                              <span className="material-symbols-outlined text-sm">
                                {detailCountdown !== null && detailCountdown > 0 ? 'timer' : 'error'}
                              </span>
                              <span>
                                {detailCountdown !== null && detailCountdown > 0
                                  ? `Thời gian còn lại: ${formatCountdown(detailCountdown)}`
                                  : 'Đã hết hạn thanh toán'}
                              </span>
                            </div>
                          </div>

                          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 items-center">
                            {/* QR Image */}
                            <div className="flex flex-col items-center justify-center p-2 bg-white rounded-xl border border-slate-200 text-center">
                              <img
                                src={selectedOrder.qr_url}
                                alt="VietQR MB Bank"
                                className="w-40 h-auto object-contain rounded"
                                loading="lazy"
                              />
                              <span className="text-[10px] text-slate-500 font-medium mt-1">Quét bằng App Ngân hàng / MoMo</span>
                            </div>

                            {/* Bank & Transfer Info */}
                            <div className="md:col-span-2 space-y-2 text-xs">
                              <div className="flex justify-between py-1 border-b border-outline-variant/30">
                                <span className="text-on-surface-variant">Ngân hàng:</span>
                                <span className="font-semibold text-on-surface">MB Bank (Quân Đội)</span>
                              </div>
                              <div className="flex justify-between items-center py-1 border-b border-outline-variant/30">
                                <span className="text-on-surface-variant">Số tài khoản:</span>
                                <div className="flex items-center gap-1">
                                  <span className="font-mono font-bold text-on-surface">2512070399999</span>
                                  <button
                                    type="button"
                                    onClick={() => handleCopyRecognitionCode('2512070399999')}
                                    className="text-on-surface-variant hover:text-primary p-0.5 cursor-pointer"
                                    title="Sao chép STK"
                                  >
                                    <span className="material-symbols-outlined text-sm">content_copy</span>
                                  </button>
                                </div>
                              </div>
                              <div className="flex justify-between py-1 border-b border-outline-variant/30">
                                <span className="text-on-surface-variant">Chủ tài khoản:</span>
                                <span className="font-bold text-on-surface">NGUYEN PHU BAO</span>
                              </div>
                              <div className="flex justify-between items-center py-1 border-b border-outline-variant/30">
                                <span className="text-on-surface-variant">Nội dung CK:</span>
                                <div className="flex items-center gap-1">
                                  <span className="font-mono font-bold text-primary bg-surface-container px-2 py-0.5 rounded break-all">
                                    {selectedOrder.transfer_content || selectedOrder.recognition_code || '—'}
                                  </span>
                                  {(selectedOrder.transfer_content || selectedOrder.recognition_code) && (
                                    <button
                                      type="button"
                                      onClick={() => handleCopyRecognitionCode(selectedOrder.transfer_content || selectedOrder.recognition_code)}
                                      className="text-on-surface-variant hover:text-primary p-0.5 cursor-pointer"
                                      title="Sao chép nội dung CK"
                                    >
                                      <span className="material-symbols-outlined text-sm">content_copy</span>
                                    </button>
                                  )}
                                </div>
                              </div>
                              {selectedOrder.checkout_url && (
                                <div className="pt-1">
                                  <a
                                    href={selectedOrder.checkout_url}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold shadow-xs transition-all active:scale-95 cursor-pointer"
                                  >
                                    <span className="material-symbols-outlined text-sm">open_in_new</span>
                                    <span>Mở Cổng Thanh Toán PayOS</span>
                                  </a>
                                </div>
                              )}
                            </div>
                          </div>
                        </div>
                      );
                    }

                    if (selectedOrder.status === 'PAID') {
                      return (
                        <div className="p-4 rounded-xl border border-emerald-300 bg-emerald-50/80 dark:bg-emerald-950/30 dark:border-emerald-800 flex items-center gap-3.5">
                          <div className="w-10 h-10 rounded-full bg-emerald-100 dark:bg-emerald-900/50 flex items-center justify-center text-emerald-700 dark:text-emerald-300 shrink-0">
                            <span className="material-symbols-outlined text-2xl">verified</span>
                          </div>
                          <div>
                            <h4 className="text-sm font-bold text-emerald-900 dark:text-emerald-100">
                              Đã thanh toán thành công
                            </h4>
                            <p className="text-xs text-emerald-700 dark:text-emerald-300 mt-0.5">
                              Đơn hàng đã được đối soát hoàn tất. Mã QR và liên kết thanh toán đã được đóng vĩnh viễn trên hệ thống nhằm bảo vệ an toàn giao dịch và ngăn chặn chuyển khoản trùng lặp.
                            </p>
                          </div>
                        </div>
                      );
                    }

                    if (selectedOrder.status === 'EXPIRED' || (selectedOrder.status === 'PENDING' && detailCountdown === 0)) {
                      return (
                        <div className="p-4 rounded-xl border border-rose-300 bg-rose-50/80 dark:bg-rose-950/30 dark:border-rose-800 flex items-center gap-3.5">
                          <div className="w-10 h-10 rounded-full bg-rose-100 dark:bg-rose-900/50 flex items-center justify-center text-rose-700 dark:text-rose-300 shrink-0">
                            <span className="material-symbols-outlined text-2xl">timer_off</span>
                          </div>
                          <div>
                            <h4 className="text-sm font-bold text-rose-900 dark:text-rose-100">
                              Đơn hàng đã hết hạn thanh toán
                            </h4>
                            <p className="text-xs text-rose-700 dark:text-rose-300 mt-0.5">
                              Thời hạn 10 phút của đơn hàng đã kết thúc. Mã QR thanh toán đã bị vô hiệu hóa và xóa khỏi hệ thống để tránh người dùng chuyển khoản nhầm lẫn.
                            </p>
                          </div>
                        </div>
                      );
                    }

                    if (selectedOrder.status === 'REFUNDED') {
                      return (
                        <div className="p-4 rounded-xl border border-purple-300 bg-purple-50/80 dark:bg-purple-950/30 dark:border-purple-800 flex items-center gap-3.5">
                          <div className="w-10 h-10 rounded-full bg-purple-100 dark:bg-purple-900/50 flex items-center justify-center text-purple-700 dark:text-purple-300 shrink-0">
                            <span className="material-symbols-outlined text-2xl">history</span>
                          </div>
                          <div>
                            <h4 className="text-sm font-bold text-purple-900 dark:text-purple-100">
                              Đơn hàng đã hoàn tiền thành công
                            </h4>
                            <p className="text-xs text-purple-700 dark:text-purple-300 mt-0.5">
                              Khoản tiền giao dịch đã được hoàn trả theo quy định tài chính. Kênh thanh toán QR đã đóng.
                            </p>
                          </div>
                        </div>
                      );
                    }

                    if (selectedOrder.status === 'CANCELLED') {
                      return (
                        <div className="p-4 rounded-xl border border-slate-300 bg-slate-100 dark:bg-slate-800/40 dark:border-slate-700 flex items-center gap-3.5">
                          <div className="w-10 h-10 rounded-full bg-slate-200 dark:bg-slate-700 flex items-center justify-center text-slate-700 dark:text-slate-300 shrink-0">
                            <span className="material-symbols-outlined text-2xl">cancel</span>
                          </div>
                          <div>
                            <h4 className="text-sm font-bold text-slate-800 dark:text-slate-200">
                              Đơn hàng đã bị hủy
                            </h4>
                            <p className="text-xs text-slate-600 dark:text-slate-400 mt-0.5">
                              Đơn hàng này không còn hiệu lực. Mã QR thanh toán đã được vô hiệu hóa.
                            </p>
                          </div>
                        </div>
                      );
                    }

                    return null;
                  })()
                )}

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
                      <div className="mt-1">
                        {(() => {
                          const isExp = selectedOrder.status === 'EXPIRED' ||
                            (selectedOrder.status === 'PENDING' && selectedOrder.expired_at && new Date(selectedOrder.expired_at) <= new Date());
                          const effStatus = isExp ? 'EXPIRED' : selectedOrder.status;
                          const scfg = STATUS_CONFIG[effStatus] || {
                            bg: 'bg-slate-100',
                            text: 'text-slate-600',
                            border: 'border-slate-300',
                            icon: 'help',
                          };
                          return (
                            <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold border ${scfg.bg} ${scfg.text} ${scfg.border}`}>
                              <span className="material-symbols-outlined text-[13px]">{scfg.icon}</span>
                              {getStatusLabel(effStatus, t)}
                            </span>
                          );
                        })()}
                      </div>
                    </div>
                    <div>
                      <span className="text-on-surface-variant text-xs">{t('payments.detailModal.amount')}:</span>
                      <p className="font-mono font-bold text-emerald-600">{formatVnd(selectedOrder.amount)}</p>
                    </div>
                    <div>
                      <span className="text-on-surface-variant text-xs">{t('payments.detailModal.amountReceived')}:</span>
                      <p className="font-mono font-bold text-on-surface">{formatVnd(selectedOrder.amount_received || selectedOrder.amount)}</p>
                    </div>
                    <div>
                      <span className="text-on-surface-variant text-xs">{t('payments.detailModal.recognitionCode')}:</span>
                      <p className="font-mono font-bold text-primary">{selectedOrder.recognition_code || '—'}</p>
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
                    {selectedOrder.transfer_content && (
                      <div className="col-span-2">
                        <span className="text-on-surface-variant text-xs">{t('payments.detailModal.transferContent')}:</span>
                        <p className="font-mono text-xs text-on-surface bg-surface-container p-1.5 rounded">{selectedOrder.transfer_content}</p>
                      </div>
                    )}
                    {selectedOrder.payment_link_id && (
                      <div className="col-span-2">
                        <span className="text-on-surface-variant text-xs">{t('payments.detailModal.payosLinkId')}:</span>
                        <p className="font-mono text-xs text-on-surface-variant break-all">{selectedOrder.payment_link_id}</p>
                      </div>
                    )}
                  </div>
                </div>

                {/* Refund Information (if applicable) */}
                {(selectedOrder.status === 'REFUND_PENDING' || selectedOrder.status === 'REFUNDED' || selectedOrder.refunded_at) && (
                  <div>
                    <h4 className="text-xs font-bold text-orange-700 dark:text-orange-400 uppercase tracking-wider mb-3 flex items-center gap-1.5">
                      <span className="material-symbols-outlined text-sm">currency_exchange</span>
                      Thông tin hoàn tiền
                    </h4>
                    <div className="grid grid-cols-2 gap-3 text-sm bg-orange-50/50 dark:bg-orange-950/20 p-4 rounded-xl border border-orange-200 dark:border-orange-900/40">
                      <div>
                        <span className="text-on-surface-variant text-xs">{t('payments.detailModal.refundedAmount')}:</span>
                        <p className="font-mono font-bold text-orange-700">{formatVnd(selectedOrder.refunded_amount || selectedOrder.amount_received)}</p>
                      </div>
                      <div>
                        <span className="text-on-surface-variant text-xs">{t('payments.detailModal.refundedAt')}:</span>
                        <p className="font-mono text-xs text-on-surface">{formatDate(selectedOrder.refunded_at)}</p>
                      </div>
                      <div className="col-span-2">
                        <span className="text-on-surface-variant text-xs">{t('payments.detailModal.refundReason')}:</span>
                        <p className="text-xs text-on-surface">{selectedOrder.refund_reason || '—'}</p>
                      </div>
                      {selectedOrder.refund_proof && (
                        <div className="col-span-2">
                          <span className="text-on-surface-variant text-xs">{t('payments.detailModal.refundProof')}:</span>
                          <div className="mt-1 flex items-center gap-3">
                            {(selectedOrder.refund_proof.match(/\.(jpg|jpeg|png|webp|gif)$/i) || selectedOrder.refund_proof.startsWith('/assets/Refunds/')) && (
                              <a
                                href={selectedOrder.refund_proof.startsWith('http') ? selectedOrder.refund_proof : `http://localhost:5000${selectedOrder.refund_proof}`}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="group block"
                              >
                                <img
                                  src={selectedOrder.refund_proof.startsWith('http') ? selectedOrder.refund_proof : `http://localhost:5000${selectedOrder.refund_proof}`}
                                  alt="Minh chứng hoàn tiền"
                                  className="w-24 h-16 object-cover rounded-lg border border-outline-variant group-hover:scale-105 transition-transform"
                                />
                              </a>
                            )}
                            <a
                              href={selectedOrder.refund_proof.startsWith('http') ? selectedOrder.refund_proof : `http://localhost:5000${selectedOrder.refund_proof}`}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="font-mono text-xs text-primary underline break-all flex items-center gap-1"
                            >
                              <span className="material-symbols-outlined text-sm">open_in_new</span>
                              {selectedOrder.refund_proof}
                            </a>
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                )}

                {/* Actions for WAITING_CONFIRMATION */}
                {selectedOrder.status === 'WAITING_CONFIRMATION' && (
                  <div className="p-4 bg-purple-50 border border-purple-200 rounded-xl space-y-3">
                    <div className="flex items-start gap-2 text-purple-900">
                      <span className="material-symbols-outlined text-purple-700">warning</span>
                      <div className="text-xs">
                        <span className="font-bold">Đơn hàng chuyển thừa tiền:</span> Khách hàng đã chuyển {formatVnd(selectedOrder.amount_received)} thay vì {formatVnd(selectedOrder.amount)}.
                      </div>
                    </div>
                    <div className="flex gap-2">
                      <button
                        onClick={() => handleConfirmUpgrade(selectedOrder.order_code, true)}
                        disabled={actionLoading}
                        className="flex-1 py-2 px-3 bg-purple-700 hover:bg-purple-800 text-white rounded-lg text-xs font-bold transition-colors cursor-pointer"
                      >
                        {t('payments.sandbox.confirmAcceptBtn')}
                      </button>
                      <button
                        onClick={() => handleConfirmUpgrade(selectedOrder.order_code, false)}
                        disabled={actionLoading}
                        className="flex-1 py-2 px-3 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg text-xs font-bold transition-colors cursor-pointer"
                      >
                        {t('payments.sandbox.confirmRejectBtn')}
                      </button>
                    </div>
                  </div>
                )}

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
                <div className="flex items-center justify-between pt-4 border-t border-outline-variant">
                  {selectedOrder.status === 'REFUND_PENDING' ? (
                    <button
                      onClick={() => {
                        handleOpenRefundModal(selectedOrder);
                      }}
                      className="px-4 py-2 bg-orange-600 hover:bg-orange-700 text-white rounded-lg font-semibold text-sm transition-colors cursor-pointer flex items-center gap-1.5"
                    >
                      <span className="material-symbols-outlined text-base">currency_exchange</span>
                      {t('payments.table.refundBtn')}
                    </button>
                  ) : <div />}
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

      {/* Refund Processing Modal */}
      {refundTargetOrder && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-xs animate-fadeIn">
          <div className="bg-surface-container rounded-2xl border border-outline-variant shadow-2xl max-w-lg w-full">
            <div className="p-6 border-b border-outline-variant flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="w-10 h-10 rounded-xl bg-orange-100 text-orange-700 flex items-center justify-center">
                  <span className="material-symbols-outlined text-2xl">currency_exchange</span>
                </div>
                <div>
                  <h3 className="text-lg font-bold text-on-surface">
                    {t('payments.refundModal.title')}
                  </h3>
                  <p className="text-xs text-on-surface-variant">
                    {t('payments.refundModal.subtitle')}
                  </p>
                </div>
              </div>
              <button
                onClick={() => setRefundTargetOrder(null)}
                className="text-on-surface-variant hover:text-on-surface p-1 rounded-lg hover:bg-surface-container-highest cursor-pointer"
              >
                <span className="material-symbols-outlined text-xl">close</span>
              </button>
            </div>

            <form onSubmit={handleInitiateRefund} className="p-6 space-y-4">
              <div className="bg-surface-container-lowest p-3 rounded-xl border border-outline-variant text-xs space-y-1.5">
                <div className="flex justify-between">
                  <span className="text-on-surface-variant">{t('payments.refundModal.orderCode')}:</span>
                  <span className="font-mono font-bold text-on-surface">#{refundTargetOrder.order_code}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-on-surface-variant">{t('payments.refundModal.customer')}:</span>
                  <span className="font-semibold text-on-surface">{refundTargetOrder.account?.username}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-on-surface-variant">{t('payments.refundModal.expectedAmount')}:</span>
                  <span className="font-mono font-semibold">{formatVnd(refundTargetOrder.amount)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-on-surface-variant">{t('payments.refundModal.receivedAmount')}:</span>
                  <span className="font-mono font-bold text-orange-600">{formatVnd(refundTargetOrder.amount_received || refundTargetOrder.amount)}</span>
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-on-surface uppercase mb-1">
                  {t('payments.refundModal.refundAmountLabel')}
                </label>
                <input
                  type="number"
                  required
                  value={refundForm.refunded_amount}
                  onChange={(e) => setRefundForm({ ...refundForm, refunded_amount: e.target.value })}
                  className="w-full px-3 py-2 bg-surface-container-lowest border border-outline-variant rounded-lg text-sm text-on-surface focus:outline-none focus:border-primary font-mono"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-on-surface uppercase mb-1">
                  {t('payments.refundModal.refundReasonLabel')}
                </label>
                <textarea
                  required
                  rows={2}
                  value={refundForm.refund_reason}
                  onChange={(e) => setRefundForm({ ...refundForm, refund_reason: e.target.value })}
                  className="w-full px-3 py-2 bg-surface-container-lowest border border-outline-variant rounded-lg text-sm text-on-surface focus:outline-none focus:border-primary"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-on-surface uppercase mb-1">
                  Tải lên ảnh minh chứng / Ủy nhiệm chi
                </label>
                <input
                  type="file"
                  accept="image/*,.pdf"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      setRefundProofFile(file);
                      setRefundProofPreview(URL.createObjectURL(file));
                    }
                  }}
                  className="w-full text-xs text-on-surface-variant file:mr-3 file:py-1.5 file:px-3 file:rounded-lg file:border-0 file:text-xs file:font-semibold file:bg-primary/10 file:text-primary hover:file:bg-primary/20 cursor-pointer"
                />
                {refundProofPreview && (
                  <div className="mt-2 relative w-32 h-20 rounded-lg overflow-hidden border border-outline-variant">
                    <img src={refundProofPreview} alt="Xem trước minh chứng" className="w-full h-full object-cover" />
                  </div>
                )}
                {!refundProofFile && (
                  <div className="mt-2">
                    <label className="block text-[11px] text-on-surface-variant mb-1">
                      Hoặc nhập đường dẫn ảnh (URL):
                    </label>
                    <input
                      type="text"
                      placeholder={t('payments.refundModal.proofPlaceholder')}
                      value={refundForm.refund_proof}
                      onChange={(e) => setRefundForm({ ...refundForm, refund_proof: e.target.value })}
                      className="w-full px-3 py-1.5 bg-surface-container-lowest border border-outline-variant rounded-lg text-xs text-on-surface focus:outline-none focus:border-primary"
                    />
                  </div>
                )}
              </div>

              <div className="flex items-center justify-end gap-2 pt-4 border-t border-outline-variant">
                <button
                  type="button"
                  onClick={() => setRefundTargetOrder(null)}
                  className="px-4 py-2 bg-surface-container-high hover:bg-surface-container-highest text-on-surface rounded-lg font-semibold text-xs cursor-pointer"
                >
                  {t('payments.refundModal.cancelBtn')}
                </button>
                <button
                  type="submit"
                  disabled={refundSubmitting}
                  className="px-4 py-2 bg-orange-600 hover:bg-orange-700 text-white rounded-lg font-semibold text-xs transition-colors cursor-pointer disabled:opacity-50"
                >
                  {refundSubmitting ? t('common.loading') : t('payments.refundModal.submitBtn')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Sample Test QR Code Modal (Client-App Sandbox Roleplay) */}
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
                    {t('payments.sandbox.title')}
                  </h3>
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

              {/* Amount Quick Selector & Create Pending Button */}
              <div className="bg-surface-container-lowest p-3.5 rounded-xl border border-outline-variant space-y-3">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <span className="text-xs font-bold text-on-surface uppercase tracking-wider block mb-1.5">
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

                  {/* Button Create Pending Order & Get QR */}
                  <div className="self-end">
                    <button
                      type="button"
                      onClick={() => handleCreateSampleOrder(false)}
                      disabled={actionLoading}
                      className="flex items-center gap-2 px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold shadow-sm transition-all active:scale-95 cursor-pointer disabled:opacity-50"
                    >
                      {actionLoading ? (
                        <span className="material-symbols-outlined text-base animate-spin">progress_activity</span>
                      ) : (
                        <span className="material-symbols-outlined text-base">qr_code_2</span>
                      )}
                      <span>+ Tạo đơn Pending & Sinh mã QR</span>
                    </button>
                  </div>
                </div>
              </div>

              {/* Sandbox Content Area */}
              {!payosData ? (
                <div className="bg-surface-container-lowest p-8 rounded-2xl border border-outline-variant text-center space-y-3">
                  <div className="w-14 h-14 mx-auto rounded-full bg-surface-container-high flex items-center justify-center text-primary">
                    <span className="material-symbols-outlined text-3xl">qr_code_scanner</span>
                  </div>
                  <h4 className="text-base font-bold text-on-surface">Chưa kích hoạt đơn kiểm thử nào</h4>
                  <p className="text-xs text-on-surface-variant max-w-lg mx-auto leading-relaxed">
                    Vui lòng chọn mức tiền kiểm thử phía trên và nhấn <strong className="text-primary font-semibold">"Tạo đơn Pending & Sinh mã QR"</strong>. Hệ thống sẽ lưu đơn hàng vào CSDL ở trạng thái <strong className="font-semibold text-amber-600">PENDING</strong>, kết nối kênh PayOS thật để cấp mã QR và tự động cập nhật danh sách ngoài bảng quản trị.
                  </p>
                </div>
              ) : (
                /* 2 Columns when payosData exists */
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6 items-start">
                  {/* Left Column: QR Code & Countdown */}
                  <div className="flex flex-col items-center bg-surface-container-lowest p-5 rounded-2xl border border-outline-variant text-center relative group min-h-[340px] justify-center">
                    {/* Badge on QR */}
                    <div className="absolute top-3 left-3 bg-emerald-600 text-white text-[10px] font-extrabold uppercase px-2 py-0.5 rounded shadow tracking-wider flex items-center gap-1">
                      <span className="material-symbols-outlined text-[12px]">verified</span>
                      {t('payments.sampleModal.payosTag')}
                    </div>

                    {/* 10-Minute Countdown Timer */}
                    <div className="absolute top-3 right-3 bg-slate-800 text-white text-[11px] font-mono px-2 py-0.5 rounded shadow flex items-center gap-1">
                      <span className="material-symbols-outlined text-[12px] text-amber-400">timer</span>
                      <span>{formatCountdown(countdownSeconds)}</span>
                    </div>

                    {payosLoading ? (
                      <div className="py-20 text-center text-on-surface-variant space-y-2">
                        <span className="material-symbols-outlined text-3xl animate-spin text-primary block mx-auto">
                          progress_activity
                        </span>
                        <p className="text-xs">{t('common.loading')}</p>
                      </div>
                    ) : countdownSeconds === 0 ? (
                      <div className="py-12 px-4 text-center space-y-2">
                        <span className="material-symbols-outlined text-4xl text-rose-500 block mx-auto">
                          timer_off
                        </span>
                        <h5 className="text-sm font-bold text-rose-700 dark:text-rose-300">
                          Đơn hàng mẫu đã hết hạn
                        </h5>
                        <p className="text-xs text-on-surface-variant max-w-xs mx-auto leading-relaxed">
                          Mã QR đã bị vô hiệu hóa để bảo vệ an toàn giao dịch. Vui lòng nhấn nút <strong className="font-semibold text-primary">"Tạo đơn Pending & Sinh mã QR"</strong> phía trên để tiếp tục thử nghiệm.
                        </p>
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

                        {/* 6-Character Recognition Code */}
                        {payosData?.recognitionCode && (
                          <div className="mt-2 w-full bg-surface-container p-2 rounded-lg border border-outline-variant flex items-center justify-between text-xs">
                            <span className="text-on-surface-variant">{t('payments.sandbox.recognitionCodeLabel')}</span>
                            <div className="flex items-center gap-1">
                              <span className="font-mono font-bold text-primary text-sm tracking-wider">
                                {payosData.recognitionCode}
                              </span>
                              <button
                                type="button"
                                onClick={() => handleCopyRecognitionCode(payosData.recognitionCode)}
                                className="text-on-surface-variant hover:text-primary p-1 cursor-pointer"
                                title="Sao chép"
                              >
                                <span className="material-symbols-outlined text-sm">
                                  {copiedCode ? 'check' : 'content_copy'}
                                </span>
                              </button>
                            </div>
                          </div>
                        )}

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

                  {/* Right Column: Transfer Info & Realtime Instructions */}
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
                      <div className="flex justify-between items-center py-1 border-b border-outline-variant/30">
                        <span className="text-on-surface-variant">{t('payments.sampleModal.accountNo')}:</span>
                        <div className="flex items-center gap-1">
                          <span className="font-mono font-bold text-on-surface">
                            {payosData?.accountNumber || '2512070399999'}
                          </span>
                          <button
                            type="button"
                            onClick={() => handleCopyRecognitionCode(payosData?.accountNumber || '2512070399999')}
                            className="text-on-surface-variant hover:text-primary p-0.5 cursor-pointer"
                            title="Sao chép STK"
                          >
                            <span className="material-symbols-outlined text-sm">content_copy</span>
                          </button>
                        </div>
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
                      <div className="flex justify-between items-center py-1 border-b border-outline-variant/30">
                        <span className="text-on-surface-variant">{t('payments.sampleModal.transferContent')}:</span>
                        <div className="flex items-center gap-1">
                          <span className="font-mono font-bold text-primary bg-surface-container px-2 py-0.5 rounded break-all">
                            {payosData?.description || 'PFM PREMIUM TEST'}
                          </span>
                          {payosData?.description && (
                            <button
                              type="button"
                              onClick={() => handleCopyRecognitionCode(payosData.description)}
                              className="text-on-surface-variant hover:text-primary p-0.5 cursor-pointer"
                              title="Sao chép nội dung CK"
                            >
                              <span className="material-symbols-outlined text-sm">content_copy</span>
                            </button>
                          )}
                        </div>
                      </div>
                      <div className="flex justify-between py-1">
                        <span className="text-on-surface-variant">Trạng thái đơn:</span>
                        <span className="font-semibold text-amber-600 flex items-center gap-1">
                          <span className="material-symbols-outlined text-xs animate-spin">sync</span>
                          PENDING (Chờ thanh toán)
                        </span>
                      </div>
                    </div>

                    {/* Notice for Real Bank Transfer & Auto-update */}
                    <div className="p-3 bg-surface-container rounded-xl border border-outline-variant/60 text-xs text-on-surface-variant space-y-1.5">
                      <p className="font-semibold text-on-surface flex items-center gap-1">
                        <span className="material-symbols-outlined text-sm text-primary">lightbulb</span>
                        Quét QR hoặc Chuyển khoản thật:
                      </p>
                      <p className="text-[11px] leading-relaxed">
                        Dùng App Ngân hàng bất kỳ hoặc MoMo quét mã QR bên cạnh. Sau khi chuyển khoản thành công, PayOS sẽ gửi Webhook về máy chủ và bảng quản trị sẽ tự động cập nhật trạng thái đơn hàng thời gian thực.
                      </p>
                    </div>

                    {/* Button Create Another Pending Sample */}
                    <div className="pt-1">
                      <button
                        type="button"
                        onClick={() => handleCreateSampleOrder(false)}
                        disabled={actionLoading}
                        className="w-full py-2 px-3 bg-surface-container-high hover:bg-surface-container-highest text-on-surface rounded-xl text-xs font-bold border border-outline-variant cursor-pointer disabled:opacity-50 flex items-center justify-center gap-1.5"
                      >
                        <span className="material-symbols-outlined text-sm">add_circle</span>
                        <span>+ Tạo đơn Pending khác</span>
                      </button>
                    </div>
                  </div>
                </div>
              )}
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
      {/* Security Re-Authentication Modal for Refund Action */}
      <SecurityConfirmModal
        isOpen={showRefundSecurityModal}
        onClose={() => setShowRefundSecurityModal(false)}
        actionType="REFUND_ORDER"
        actionDescription={
          refundTargetOrder
            ? `Xác nhận hoàn tiền ${formatVnd(refundForm.refunded_amount)} cho đơn hàng #${refundTargetOrder.order_code}`
            : 'Xác nhận hoàn tiền'
        }
        onSuccess={() => {
          setShowRefundSecurityModal(false);
          handleExecuteRefund();
        }}
      />
    </div>
  );
};

export default PaymentHistoryPage;
