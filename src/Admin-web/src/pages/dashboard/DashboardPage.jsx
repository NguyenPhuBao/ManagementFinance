import React, { useState, useEffect } from 'react';
import { io } from 'socket.io-client';
import { TIME_FILTERS, TIME_FILTER_LABELS } from '../../utils/constants';
import adminApi from '../../api/admin.api';

const STATUS_CONFIG = {
  Pass: {
    label: 'Thành công',
    bg: 'bg-[#dcfce7]',
    text: 'text-[#166534]',
    border: 'border-[#86efac]',
    icon: 'check_circle',
  },
  Processing: {
    label: 'Đang xử lý',
    bg: 'bg-[#dbeafe]',
    text: 'text-[#1e40af]',
    border: 'border-[#93c5fd]',
    icon: 'sync',
  },
  Pending: {
    label: 'Chờ xử lý',
    bg: 'bg-[#f3e8ff]',
    text: 'text-[#6b21a8]',
    border: 'border-[#d8b4fe]',
    icon: 'hourglass_empty',
  },
  Accepted: {
    label: 'Đã tiếp nhận',
    bg: 'bg-[#ccfbf1]',
    text: 'text-[#115e59]',
    border: 'border-[#99f6e4]',
    icon: 'done',
  },
  Rejected: {
    label: 'Bị từ chối',
    bg: 'bg-[#fee2e2]',
    text: 'text-[#991b1b]',
    border: 'border-[#fca5a5]',
    icon: 'block',
  },
  Fail: {
    label: 'Thất bại',
    bg: 'bg-[#fef2f2]',
    text: 'text-[#b91c1c]',
    border: 'border-[#fecaca]',
    icon: 'cancel',
  },
  Interrupted: {
    label: 'Ngắt quãng',
    bg: 'bg-[#fef3c7]',
    text: 'text-[#92400e]',
    border: 'border-[#fde68a]',
    icon: 'warning',
  },
};

const getStatusBadge = (status) => {
  const cfg = STATUS_CONFIG[status] || STATUS_CONFIG.Pass;
  return (
    <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full font-label-md text-[11px] font-semibold border ${cfg.bg} ${cfg.text} ${cfg.border}`}>
      <span className="material-symbols-outlined text-[13px]">{cfg.icon}</span>
      {cfg.label}
    </span>
  );
};

const InteractiveLineChart = ({
  data = [],
  gradientId = 'chartGrad',
  strokeColor = '#2563eb',
  gradientFrom = '#3b82f6',
  gradientTo = '#1d4ed8',
  unit = 'lượt',
  loading = false,
  height = 180,
}) => {
  const [hoverIndex, setHoverIndex] = useState(null);

  if (loading) {
    return (
      <div className="w-full flex items-center justify-center" style={{ height: `${height}px` }}>
        <span className="material-symbols-outlined animate-spin text-primary text-2xl">progress_activity</span>
      </div>
    );
  }

  if (!data || data.length === 0) {
    return (
      <div className="w-full flex items-center justify-center text-on-surface-variant font-body-sm" style={{ height: `${height}px` }}>
        Chưa có dữ liệu thống kê
      </div>
    );
  }

  const counts = data.map((d) => d.count);
  const maxVal = Math.max(...counts, 5);
  const minVal = 0;
  const paddingX = 40;
  const paddingY = 25;
  const width = 1000;
  const svgHeight = 300;
  const drawWidth = width - paddingX * 2;
  const drawHeight = svgHeight - paddingY * 2;

  const points = data.map((item, index) => {
    const x = data.length === 1 ? width / 2 : paddingX + (index / (data.length - 1)) * drawWidth;
    const y = paddingY + drawHeight - ((item.count - minVal) / (maxVal - minVal)) * drawHeight;
    return { x, y, label: item.label, count: item.count };
  });

  // Generate smooth cubic bezier SVG path
  let pathD = `M ${points[0].x} ${points[0].y}`;
  for (let i = 0; i < points.length - 1; i++) {
    const p0 = points[i];
    const p1 = points[i + 1];
    const cp1x = p0.x + (p1.x - p0.x) / 2;
    const cp1y = p0.y;
    const cp2x = p0.x + (p1.x - p0.x) / 2;
    const cp2y = p1.y;
    pathD += ` C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${p1.x} ${p1.y}`;
  }

  const areaD = `${pathD} L ${points[points.length - 1].x} ${svgHeight - paddingY} L ${points[0].x} ${svgHeight - paddingY} Z`;

  // Select 5-6 evenly spaced labels to display on X-axis
  const labelStep = Math.max(1, Math.floor(data.length / 6));
  const displayLabels = data.filter((_, idx) => idx % labelStep === 0 || idx === data.length - 1);

  const hoveredPoint = hoverIndex !== null && points[hoverIndex] ? points[hoverIndex] : null;

  return (
    <div className="w-full relative select-none">
      <div className="w-full relative" style={{ height: `${height}px` }}>
        <svg
          width="100%"
          height="100%"
          viewBox={`0 0 ${width} ${svgHeight}`}
          preserveAspectRatio="none"
          className="overflow-visible"
          onMouseLeave={() => setHoverIndex(null)}
        >
          <defs>
            <linearGradient id={`${gradientId}-area`} x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stopColor={strokeColor} stopOpacity="0.25" />
              <stop offset="100%" stopColor={strokeColor} stopOpacity="0.0" />
            </linearGradient>
            <linearGradient id={`${gradientId}-line`} x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stopColor={gradientFrom} />
              <stop offset="100%" stopColor={gradientTo} />
            </linearGradient>
          </defs>

          {/* Grid lines */}
          <line x1={paddingX} y1={paddingY} x2={width - paddingX} y2={paddingY} stroke="currentColor" className="text-outline-variant/30" strokeWidth="1" strokeDasharray="4 4" vectorEffect="non-scaling-stroke" />
          <line x1={paddingX} y1={paddingY + drawHeight / 2} x2={width - paddingX} y2={paddingY + drawHeight / 2} stroke="currentColor" className="text-outline-variant/30" strokeWidth="1" strokeDasharray="4 4" vectorEffect="non-scaling-stroke" />
          <line x1={paddingX} y1={svgHeight - paddingY} x2={width - paddingX} y2={svgHeight - paddingY} stroke="currentColor" className="text-outline-variant/40" strokeWidth="1" vectorEffect="non-scaling-stroke" />

          {/* Area fill */}
          <path d={areaD} fill={`url(#${gradientId}-area)`} />

          {/* Line stroke */}
          <path d={pathD} fill="none" stroke={`url(#${gradientId}-line)`} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" vectorEffect="non-scaling-stroke" />

          {/* Data points */}
          {points.map((pt, idx) => {
            const isHovered = hoverIndex === idx;
            return (
              <g key={idx}>
                <circle
                  cx={pt.x}
                  cy={pt.y}
                  r="14"
                  fill="transparent"
                  className="cursor-pointer"
                  onMouseEnter={() => setHoverIndex(idx)}
                />
                <circle
                  cx={pt.x}
                  cy={pt.y}
                  r={isHovered ? 6 : (data.length <= 12 ? 4 : 2.5)}
                  fill="white"
                  stroke={strokeColor}
                  strokeWidth={isHovered ? 3 : 2}
                  className="transition-all duration-150 pointer-events-none"
                  vectorEffect="non-scaling-stroke"
                />
              </g>
            );
          })}

          {/* Active Tooltip on SVG */}
          {hoveredPoint && (
            <g transform={`translate(${Math.min(Math.max(hoveredPoint.x, 60), width - 60)}, ${Math.max(hoveredPoint.y - 45, 10)})`}>
              <rect x="-45" y="0" width="90" height="34" rx="6" fill="#1e293b" opacity="0.95" />
              <text x="0" y="14" fill="#94a3b8" fontSize="10" fontFamily="Inter, sans-serif" textAnchor="middle">{hoveredPoint.label}</text>
              <text x="0" y="27" fill="#ffffff" fontSize="11" fontWeight="bold" fontFamily="Inter, sans-serif" textAnchor="middle">
                {hoveredPoint.count.toLocaleString('vi-VN')} {unit}
              </text>
            </g>
          )}
        </svg>

        {/* Y Axis min/max labels */}
        <div className="absolute left-0 top-0 bottom-4 flex flex-col justify-between text-[10px] text-on-surface-variant font-medium pointer-events-none pr-1">
          <span>{maxVal.toLocaleString('vi-VN')}</span>
          <span>{Math.round(maxVal / 2).toLocaleString('vi-VN')}</span>
          <span>0</span>
        </div>
      </div>

      {/* X Axis labels */}
      <div className="flex justify-between mt-2 px-6 text-[11px] text-on-surface-variant font-medium">
        {displayLabels.map((item, idx) => (
          <span key={idx}>{item.label}</span>
        ))}
      </div>
    </div>
  );
};

const StatCard = ({ icon, title, value, badge, badgeColor }) => (
  <div className="bg-white rounded-xl p-5 shadow-sm border border-outline-variant hover:shadow-md transition-shadow relative overflow-hidden group">
    <div className="absolute top-0 right-0 w-20 h-20 bg-primary/5 rounded-bl-full -mr-10 -mt-10 group-hover:scale-150 transition-transform duration-500"></div>
    <div className="flex items-center justify-between mb-4">
      <div className="w-12 h-12 rounded-lg bg-surface-container-low flex items-center justify-center">
        <span className="material-symbols-outlined text-primary text-[24px]">{icon}</span>
      </div>
      {badge && (
        <span className={`px-2.5 py-1 rounded-full text-xs font-semibold flex items-center gap-1 ${badgeColor === 'green' ? 'bg-[#dcfce7] text-[#166534]' : 'bg-surface-container-high text-secondary'}`}>
          {badgeColor === 'green' && <span className="material-symbols-outlined text-[14px]">trending_up</span>}
          {badge}
        </span>
      )}
    </div>
    <div>
      <p className="text-on-surface-variant font-label-md mb-1">{title}</p>
      <h3 className="font-display-sm font-bold text-on-surface m-0 tracking-tight">{value}</h3>
    </div>
  </div>
);

const DashboardPage = () => {
  const [loading, setLoading] = useState(true);
  const now = new Date();

  // 1. Global Filter State: 'today' (Mặc định) | '7days' | '1month' | '1year' | 'custom'
  const [timeFilter, setTimeFilter] = useState('today');
  const [customFilter, setCustomFilter] = useState({
    mode: 'day', // 'day' | 'month' | 'year'
    date: `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}-${now.getDate().toString().padStart(2, '0')}`,
    month: now.getMonth() + 1,
    year: now.getFullYear(),
    label: `${now.getDate().toString().padStart(2, '0')}/${(now.getMonth() + 1).toString().padStart(2, '0')}/${now.getFullYear()}`,
  });

  // Date Picker Modal View State
  const [showDatePicker, setShowDatePicker] = useState(false);
  const [pickerTab, setPickerTab] = useState('day'); // 'day' | 'month' | 'year'
  const [viewYear, setViewYear] = useState(now.getFullYear());
  const [viewMonth, setViewMonth] = useState(now.getMonth() + 1);

  const MONTH_NAMES = ['Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
                       'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'];

  const isFutureDate = (d, m, y) => {
    const target = new Date(y, m - 1, d, 23, 59, 59);
    return target.getTime() > now.getTime();
  };

  const isFutureMonth = (m, y) => {
    return y > now.getFullYear() || (y === now.getFullYear() && m > now.getMonth() + 1);
  };

  const isFutureYear = (y) => {
    return y > now.getFullYear();
  };

  // 2. Data State
  const [totalUsers, setTotalUsers] = useState(null);
  const [totalCategories, setTotalCategories] = useState(null);
  const [newUsers, setNewUsers] = useState({ current: 0, previous: 0, growth: 0 });

  // Thống kê Biểu đồ (Ăn theo Global Filter)
  const [loginStats, setLoginStats] = useState({
    summary: { total: 0, max: 0, avg: 0 },
    timeline: [],
  });
  const [loadingLogin, setLoadingLogin] = useState(false);

  const [requestStats, setRequestStats] = useState({
    summary: { total: 0, max: 0, avg: 0 },
    timeline: [],
  });
  const [loadingRequest, setLoadingRequest] = useState(false);

  // 3. Table Hoạt động người dùng (Phân trang ngược: 1 là cũ nhất, N là mới nhất, mặc định mở N với 5/page)
  const [recentActivities, setRecentActivities] = useState([]);
  const [activityPage, setActivityPage] = useState(null); // null ban đầu để chờ totalPages từ backend
  const [activityLimit, setActivityLimit] = useState(5);
  const [activityPagination, setActivityPagination] = useState({
    total: 0,
    page: 1,
    limit: 5,
    totalPages: 1,
  });
  const [loadingActivities, setLoadingActivities] = useState(false);

  // Static stats (Tổng user & Tổng category) — fetch 1 lần
  useEffect(() => {
    const fetchStaticStats = async () => {
      try {
        const [usersRes, catRes] = await Promise.all([
          adminApi.getTotalUsers(),
          adminApi.getTotalCategories(),
        ]);
        setTotalUsers(usersRes.data.total);
        setTotalCategories(catRes.data.total);
      } catch (err) {
        console.error('Lỗi tải thống kê tổng:', err);
      }
    };
    fetchStaticStats();
  }, []);

  // Fetch Dashboard Stats khi Global Filter thay đổi
  useEffect(() => {
    let filterParams = {};
    if (timeFilter === 'custom') {
      if (customFilter.mode === 'day') {
        filterParams = { customType: 'date', date: customFilter.date };
      } else if (customFilter.mode === 'month') {
        filterParams = { customType: 'month', month: customFilter.month, year: customFilter.year };
      } else if (customFilter.mode === 'year') {
        filterParams = { customType: 'year', year: customFilter.year };
      }
    } else {
      filterParams = { period: timeFilter };
    }

    const fetchAllDashboardData = async () => {
      setLoadingLogin(true);
      setLoadingRequest(true);
      try {
        const [usersTimeRes, loginRes, reqRes] = await Promise.all([
          adminApi.getUserToTime(filterParams),
          adminApi.getLoginStats(filterParams),
          adminApi.getRequestStats(filterParams),
        ]);
        if (usersTimeRes.data) setNewUsers(usersTimeRes.data);
        if (loginRes.data) setLoginStats(loginRes.data);
        if (reqRes.data) setRequestStats(reqRes.data);
      } catch (err) {
        console.error('Lỗi tải dữ liệu dashboard theo bộ lọc:', err);
      } finally {
        setLoadingLogin(false);
        setLoadingRequest(false);
        setLoading(false);
      }
    };

    fetchAllDashboardData();
  }, [timeFilter, customFilter]);

  // Fetch Hoạt động người dùng theo phân trang
  const fetchActivities = async (targetPage, limit) => {
    setLoadingActivities(true);
    try {
      const res = await adminApi.getRecentActivities({
        page: targetPage || undefined,
        limit: limit || activityLimit,
        sort: 'asc', // Trang 1 = cũ nhất, Trang N = mới nhất
      });

      if (res.data) {
        const { items, pagination } = res.data;
        // Đảo ngược danh sách trong trang hiện tại để bản ghi mới hơn nằm ở hàng trên
        setRecentActivities((items || []).slice().reverse().map(item => ({
          key: item.id ? String(item.id) : Math.random().toString(),
          id: item.id,
          user: item.user || 'Người dùng',
          action: item.action || 'Yêu cầu hệ thống',
          status: item.status || 'Pass',
          time: item.time || 'Vừa xong',
          isNew: false,
        })));

        setActivityPagination(pagination);
        if (activityPage === null || targetPage === undefined) {
          setActivityPage(pagination.totalPages);
        }
      }
    } catch (err) {
      console.error('Lỗi tải lịch sử hoạt động:', err);
    } finally {
      setLoadingActivities(false);
    }
  };

  useEffect(() => {
    fetchActivities(activityPage, activityLimit);
  }, [activityPage, activityLimit]);

  // Lắng nghe Real-time Socket.io
  useEffect(() => {
    const socketUrl = import.meta.env.VITE_SOCKET_URL || (window.location.hostname === 'localhost' ? 'http://localhost:3000' : window.location.origin);
    const socket = io(socketUrl, {
      path: '/socket.io',
      transports: ['websocket', 'polling'],
      reconnectionAttempts: 5,
    });

    socket.on('audit_activity', (data) => {
      const newActivity = {
        key: data.id ? String(data.id) : Date.now().toString(),
        id: data.id,
        user: data.user || 'Người dùng',
        action: data.action || 'Yêu cầu hệ thống',
        status: data.status || 'Pass',
        time: data.time || 'Vừa xong',
        isNew: true,
      };

      // Nếu người dùng đang ở trang mới nhất (totalPages), thêm bản ghi vào đầu bảng
      setActivityPagination((prev) => {
        const newTotal = prev.total + 1;
        const newTotalPages = Math.max(1, Math.ceil(newTotal / prev.limit));
        return {
          ...prev,
          total: newTotal,
          totalPages: newTotalPages,
        };
      });

      setActivityPage((currentPage) => {
        setRecentActivities((prevList) => {
          const filtered = prevList.filter(item => item.id !== newActivity.id);
          return [newActivity, ...filtered].slice(0, activityLimit);
        });
        return currentPage;
      });

      // Cập nhật real-time vào biểu đồ lưu lượng request
      setRequestStats((prev) => {
        if (!prev.timeline || prev.timeline.length === 0) return prev;
        const updated = [...prev.timeline];
        const lastIdx = updated.length - 1;
        updated[lastIdx] = { ...updated[lastIdx], count: updated[lastIdx].count + 1 };
        const counts = updated.map(u => u.count);
        const total = counts.reduce((a, b) => a + b, 0);
        const max = Math.max(...counts);
        const avg = Math.round(total / counts.length);
        return {
          ...prev,
          summary: { total, max, avg },
          timeline: updated,
        };
      });

      // Nếu là hành động đăng nhập, cập nhật real-time vào biểu đồ đăng nhập
      if (data.action && data.action.includes('Đăng nhập')) {
        setLoginStats((prev) => {
          if (!prev.timeline || prev.timeline.length === 0) return prev;
          const updated = [...prev.timeline];
          const lastIdx = updated.length - 1;
          updated[lastIdx] = { ...updated[lastIdx], count: updated[lastIdx].count + 1 };
          const counts = updated.map(u => u.count);
          const total = counts.reduce((a, b) => a + b, 0);
          const max = Math.max(...counts);
          const avg = Math.round(total / counts.length);
          return {
            ...prev,
            summary: { total, max, avg },
            timeline: updated,
          };
        });
      }
    });

    return () => {
      socket.disconnect();
    };
  }, [activityLimit]);

  // Handlers chọn Date Picker
  const handleSelectDay = (day) => {
    if (isFutureDate(day, viewMonth, viewYear)) return;
    const dayStr = day.toString().padStart(2, '0');
    const monthStr = viewMonth.toString().padStart(2, '0');
    setCustomFilter({
      mode: 'day',
      date: `${viewYear}-${monthStr}-${dayStr}`,
      month: viewMonth,
      year: viewYear,
      label: `${dayStr}/${monthStr}/${viewYear}`,
    });
    setTimeFilter('custom');
    setShowDatePicker(false);
  };

  const handleSelectMonth = (month) => {
    if (isFutureMonth(month, viewYear)) return;
    const monthStr = month.toString().padStart(2, '0');
    setCustomFilter({
      mode: 'month',
      date: `${viewYear}-${monthStr}-01`,
      month: month,
      year: viewYear,
      label: `Tháng ${month}/${viewYear}`,
    });
    setTimeFilter('custom');
    setShowDatePicker(false);
  };

  const handleSelectYear = (year) => {
    if (isFutureYear(year)) return;
    setCustomFilter({
      mode: 'year',
      date: `${year}-01-01`,
      month: 1,
      year: year,
      label: `Năm ${year}`,
    });
    setTimeFilter('custom');
    setShowDatePicker(false);
  };

  // Calendar calculations for Tab Ngày
  const daysInViewMonth = new Date(viewYear, viewMonth, 0).getDate();
  const firstDayOffset = (() => {
    const d = new Date(viewYear, viewMonth - 1, 1).getDay();
    return d === 0 ? 6 : d - 1; // 0 = Thứ 2, 6 = CN
  })();

  // Data hiển thị Card
  const totalUsersDisplay = totalUsers !== null ? totalUsers.toLocaleString('vi-VN') : '—';
  const totalCategoriesDisplay = totalCategories !== null ? totalCategories.toLocaleString('vi-VN') : '—';
  const growthSign = newUsers.growth >= 0 ? '+' : '';
  const growthBadge = `${growthSign}${newUsers.growth}%`;
  const growthColor = newUsers.growth >= 0 ? 'green' : 'red';

  // Pagination display values
  const currPage = activityPagination.page || 1;
  const startItem = activityPagination.total > 0 ? (currPage - 1) * activityPagination.limit + 1 : 0;
  const endItem = Math.min(currPage * activityPagination.limit, activityPagination.total);

  // Filter Button Label
  const customButtonLabel = timeFilter === 'custom' ? customFilter.label : `${MONTH_NAMES[now.getMonth()]}/${now.getFullYear()}`;

  return (
    <div className="max-w-[1440px] mx-auto w-full p-4 md:p-6 space-y-6 bg-surface-bright min-h-full relative overflow-hidden">
      
      {/* Abstract Background Elements */}
      <div className="absolute top-0 right-0 w-96 h-96 bg-primary/5 rounded-full blur-3xl -z-10 translate-x-1/3 -translate-y-1/3"></div>
      <div className="absolute bottom-0 left-0 w-96 h-96 bg-secondary/5 rounded-full blur-3xl -z-10 -translate-x-1/3 translate-y-1/3"></div>
      
      {/* Header section & Global Filter */}
      <div className="flex flex-col lg:flex-row lg:items-end justify-between gap-4">
          <div className="relative">
              <h1 className="font-display-md text-display-md font-bold text-on-surface m-0 tracking-tight">Tổng quan hệ thống</h1>
              <p className="font-body-lg text-on-surface-variant mt-2 max-w-xl">Dữ liệu tài chính và hoạt động được cập nhật liên tục để cung cấp cái nhìn toàn diện về hiệu suất.</p>
          </div>
          
          <div className="flex flex-wrap items-center gap-3 self-start lg:self-auto">
              {/* Bộ lọc nhanh: Hôm nay, 7 Ngày, 1 Tháng, 1 Năm */}
              <div className="flex bg-white p-1 rounded-lg border border-outline-variant shadow-sm">
                  {Object.entries(TIME_FILTER_LABELS).map(([key, label]) => (
                    <button
                        key={key}
                        onClick={() => setTimeFilter(key)}
                        className={`px-3 py-1.5 rounded-md font-label-md text-[13px] transition-all duration-200 cursor-pointer ${
                          timeFilter === key ? 'bg-primary text-white font-semibold shadow-sm' : 'text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface'
                        }`}
                    >
                        {label}
                    </button>
                  ))}
              </div>

              {/* Bộ lọc chi tiết: Ngày (dd/mm/yyyy), Tháng (mm/yyyy), Năm (yyyy) */}
              <div className="relative">
                <button
                  onClick={() => setShowDatePicker(!showDatePicker)}
                  className={`flex items-center gap-2 px-3.5 py-2 rounded-lg border shadow-sm transition-colors cursor-pointer font-label-md text-[13px] ${
                    timeFilter === 'custom'
                      ? 'bg-primary/10 border-primary text-primary font-semibold'
                      : 'bg-white border-outline-variant text-on-surface hover:border-primary'
                  }`}
                >
                  <span className="material-symbols-outlined text-primary text-[18px]">calendar_month</span>
                  {customButtonLabel}
                  <span className="material-symbols-outlined text-on-surface-variant text-[16px]">arrow_drop_down</span>
                </button>

                {/* Custom Date Picker Modal */}
                {showDatePicker && (
                  <>
                    <div className="fixed inset-0 z-40" onClick={() => setShowDatePicker(false)} />
                    <div className="absolute right-0 top-full mt-2 bg-white rounded-xl border border-outline-variant shadow-xl z-50 p-4 w-[310px] animate-in fade-in zoom-in-95 duration-150">
                      
                      {/* Mode Selector Tabs: Ngày | Tháng | Năm */}
                      <div className="flex bg-surface-container-low p-1 rounded-lg mb-3">
                        <button
                          onClick={() => setPickerTab('day')}
                          className={`flex-1 py-1 text-xs font-semibold rounded-md transition-all cursor-pointer ${
                            pickerTab === 'day' ? 'bg-white text-primary shadow-xs' : 'text-on-surface-variant hover:text-on-surface'
                          }`}
                        >
                          Theo Ngày
                        </button>
                        <button
                          onClick={() => setPickerTab('month')}
                          className={`flex-1 py-1 text-xs font-semibold rounded-md transition-all cursor-pointer ${
                            pickerTab === 'month' ? 'bg-white text-primary shadow-xs' : 'text-on-surface-variant hover:text-on-surface'
                          }`}
                        >
                          Theo Tháng
                        </button>
                        <button
                          onClick={() => setPickerTab('year')}
                          className={`flex-1 py-1 text-xs font-semibold rounded-md transition-all cursor-pointer ${
                            pickerTab === 'year' ? 'bg-white text-primary shadow-xs' : 'text-on-surface-variant hover:text-on-surface'
                          }`}
                        >
                          Theo Năm
                        </button>
                      </div>

                      {/* --- TAB 1: THEO NGÀY --- */}
                      {pickerTab === 'day' && (
                        <div>
                          {/* Navigation Tháng / Năm */}
                          <div className="flex items-center justify-between mb-2">
                            <button
                              onClick={() => {
                                if (viewMonth === 1) {
                                  setViewMonth(12);
                                  setViewYear(v => v - 1);
                                } else {
                                  setViewMonth(v => v - 1);
                                }
                              }}
                              className="p-1 rounded hover:bg-surface-container-low text-on-surface-variant cursor-pointer"
                            >
                              <span className="material-symbols-outlined text-[18px]">chevron_left</span>
                            </button>
                            <span className="font-semibold text-[13px] text-on-surface">
                              Tháng {viewMonth}/{viewYear}
                            </span>
                            <button
                              onClick={() => {
                                if (!isFutureMonth(viewMonth === 12 ? 1 : viewMonth + 1, viewMonth === 12 ? viewYear + 1 : viewYear)) {
                                  if (viewMonth === 12) {
                                    setViewMonth(1);
                                    setViewYear(v => v + 1);
                                  } else {
                                    setViewMonth(v => v + 1);
                                  }
                                }
                              }}
                              disabled={isFutureMonth(viewMonth === 12 ? 1 : viewMonth + 1, viewMonth === 12 ? viewYear + 1 : viewYear)}
                              className={`p-1 rounded text-on-surface-variant cursor-pointer ${
                                isFutureMonth(viewMonth === 12 ? 1 : viewMonth + 1, viewMonth === 12 ? viewYear + 1 : viewYear)
                                  ? 'opacity-30 pointer-events-none'
                                  : 'hover:bg-surface-container-low'
                              }`}
                            >
                              <span className="material-symbols-outlined text-[18px]">chevron_right</span>
                            </button>
                          </div>

                          {/* Thứ trong tuần */}
                          <div className="grid grid-cols-7 gap-1 text-center text-[10px] font-semibold text-on-surface-variant mb-1">
                            <span>T2</span><span>T3</span><span>T4</span><span>T5</span><span>T6</span><span>T7</span><span className="text-error">CN</span>
                          </div>

                          {/* Grid Ngày */}
                          <div className="grid grid-cols-7 gap-1">
                            {Array.from({ length: firstDayOffset }).map((_, i) => (
                              <div key={`empty-${i}`} className="w-8 h-8" />
                            ))}
                            {Array.from({ length: daysInViewMonth }).map((_, i) => {
                              const day = i + 1;
                              const isSelected = timeFilter === 'custom' && customFilter.mode === 'day' && customFilter.date === `${viewYear}-${viewMonth.toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}`;
                              const isToday = day === now.getDate() && viewMonth === (now.getMonth() + 1) && viewYear === now.getFullYear();
                              const disabled = isFutureDate(day, viewMonth, viewYear);

                              return (
                                <button
                                  key={day}
                                  onClick={() => handleSelectDay(day)}
                                  disabled={disabled}
                                  className={`w-8 h-8 text-[12px] font-medium rounded-lg flex items-center justify-center transition-colors cursor-pointer ${
                                    isSelected
                                      ? 'bg-primary text-white shadow-xs font-bold'
                                      : isToday
                                      ? 'border border-primary text-primary font-bold hover:bg-primary/10'
                                      : 'hover:bg-surface-container-low text-on-surface'
                                  } ${disabled ? 'opacity-25 pointer-events-none' : ''}`}
                                >
                                  {day}
                                </button>
                              );
                            })}
                          </div>
                        </div>
                      )}

                      {/* --- TAB 2: THEO THÁNG --- */}
                      {pickerTab === 'month' && (
                        <div>
                          <div className="flex items-center justify-between mb-3">
                            <button
                              onClick={() => setViewYear(v => v - 1)}
                              className="p-1 rounded hover:bg-surface-container-low text-on-surface-variant cursor-pointer"
                            >
                              <span className="material-symbols-outlined text-[18px]">chevron_left</span>
                            </button>
                            <span className="font-semibold text-on-surface text-[14px]">Năm {viewYear}</span>
                            <button
                              onClick={() => {
                                if (viewYear < now.getFullYear()) setViewYear(v => v + 1);
                              }}
                              disabled={viewYear >= now.getFullYear()}
                              className={`p-1 rounded text-on-surface-variant cursor-pointer ${viewYear >= now.getFullYear() ? 'opacity-30 pointer-events-none' : 'hover:bg-surface-container-low'}`}
                            >
                              <span className="material-symbols-outlined text-[18px]">chevron_right</span>
                            </button>
                          </div>

                          <div className="grid grid-cols-3 gap-2">
                            {MONTH_NAMES.map((name, idx) => {
                              const monthNum = idx + 1;
                              const isSelected = timeFilter === 'custom' && customFilter.mode === 'month' && customFilter.month === monthNum && customFilter.year === viewYear;
                              const disabled = isFutureMonth(monthNum, viewYear);
                              return (
                                <button
                                  key={monthNum}
                                  onClick={() => handleSelectMonth(monthNum)}
                                  disabled={disabled}
                                  className={`py-2 rounded-lg text-[12px] font-medium transition-colors cursor-pointer ${
                                    isSelected
                                      ? 'bg-primary text-white shadow-xs font-bold'
                                      : 'hover:bg-surface-container-low text-on-surface'
                                  } ${disabled ? 'opacity-25 pointer-events-none' : ''}`}
                                >
                                  {name.replace('Tháng ', 'T')}
                                </button>
                              );
                            })}
                          </div>
                        </div>
                      )}

                      {/* --- TAB 3: THEO NĂM --- */}
                      {pickerTab === 'year' && (
                        <div>
                          <div className="text-center font-semibold text-on-surface text-[13px] mb-3">
                            Chọn năm cần thống kê
                          </div>
                          <div className="grid grid-cols-3 gap-2">
                            {[now.getFullYear() - 4, now.getFullYear() - 3, now.getFullYear() - 2, now.getFullYear() - 1, now.getFullYear()].map((year) => {
                              const isSelected = timeFilter === 'custom' && customFilter.mode === 'year' && customFilter.year === year;
                              return (
                                <button
                                  key={year}
                                  onClick={() => handleSelectYear(year)}
                                  className={`py-2.5 rounded-lg text-[13px] font-medium transition-colors cursor-pointer ${
                                    isSelected
                                      ? 'bg-primary text-white shadow-xs font-bold'
                                      : 'hover:bg-surface-container-low text-on-surface'
                                  }`}
                                >
                                  {year}
                                </button>
                              );
                            })}
                          </div>
                        </div>
                      )}

                    </div>
                  </>
                )}
              </div>
          </div>
      </div>

      {/* Stats Grid — Hoàn toàn ăn theo Global Filter */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6 relative">
          {loading && (
            <div className="absolute inset-0 bg-white/50 backdrop-blur-[2px] z-10 flex items-center justify-center rounded-xl">
              <span className="material-symbols-outlined animate-spin text-primary text-3xl">progress_activity</span>
            </div>
          )}
          <StatCard icon="group" title="Tổng người dùng" value={totalUsersDisplay} />
          <StatCard icon="category" title="Tổng danh mục" value={totalCategoriesDisplay} />
          <StatCard icon="dns" title="Uptime Hệ thống" value="99.9%" badge="Ổn định" />
          <StatCard icon="person_add" title="Người dùng mới" value={newUsers.current.toLocaleString('vi-VN')} badge={growthBadge} badgeColor={growthColor} />
      </div>

      {/* Main Content Grid: Recent Activities (with Pagination) & Charts */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6 relative">
          {/* Table: Hoạt động gần đây (có Phân trang ngược) */}
          <div className="xl:col-span-2 bg-white rounded-xl border border-outline-variant shadow-sm overflow-hidden flex flex-col h-full">
              <div className="p-5 border-b border-outline-variant flex items-center justify-between bg-surface-container-lowest">
                  <h2 className="font-title-lg text-title-lg font-bold text-on-surface m-0 flex items-center gap-2">
                      <span className="material-symbols-outlined text-primary text-[22px]">history</span>
                      Hoạt động gần đây
                  </h2>
                  <div className="flex items-center gap-2">
                      <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-[#dcfce7] text-[#166534] font-label-md text-[11px] font-semibold border border-[#86efac]">
                          <span className="relative flex h-2 w-2">
                              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#166534] opacity-75"></span>
                              <span className="relative inline-flex rounded-full h-2 w-2 bg-[#166534]"></span>
                          </span>
                          Real-time
                      </span>
                  </div>
              </div>
              
              <div className="flex-1 overflow-x-auto relative min-h-[220px]">
                  {loadingActivities && (
                    <div className="absolute inset-0 bg-white/60 backdrop-blur-[1px] z-10 flex items-center justify-center">
                      <span className="material-symbols-outlined animate-spin text-primary text-2xl">progress_activity</span>
                    </div>
                  )}
                  <table className="w-full text-left border-collapse min-w-[560px]">
                      <thead>
                          <tr className="bg-surface-container-low/50">
                              <th className="py-3 px-5 font-label-sm text-[11px] text-on-surface-variant uppercase tracking-wider font-semibold">Người dùng</th>
                              <th className="py-3 px-5 font-label-sm text-[11px] text-on-surface-variant uppercase tracking-wider font-semibold">Hành động</th>
                              <th className="py-3 px-5 font-label-sm text-[11px] text-on-surface-variant uppercase tracking-wider font-semibold">Trạng thái</th>
                              <th className="py-3 px-5 font-label-sm text-[11px] text-on-surface-variant uppercase tracking-wider font-semibold text-right">Thời gian</th>
                          </tr>
                      </thead>
                      <tbody className="divide-y divide-outline-variant/50">
                          {recentActivities.length > 0 ? (
                            recentActivities.map(activity => (
                                <tr key={activity.key} className={`hover:bg-surface-container-lowest transition-colors group ${activity.isNew ? 'bg-primary/5 animate-pulse duration-1000' : ''}`}>
                                    <td className="py-3 px-5">
                                        <div className="flex items-center gap-3">
                                            <div className="w-8 h-8 rounded-full bg-secondary/10 text-secondary flex items-center justify-center font-bold text-sm shadow-sm group-hover:scale-105 transition-transform">
                                                {(activity.user || 'U').split(' ').pop().charAt(0)}
                                            </div>
                                            <span className="font-body-md font-semibold text-on-surface">{activity.user}</span>
                                        </div>
                                    </td>
                                    <td className="py-3 px-5 text-on-surface-variant font-body-md">
                                        <span className="inline-flex items-center gap-2">
                                            <span className="w-1.5 h-1.5 rounded-full bg-primary flex-shrink-0"></span>
                                            {activity.action}
                                        </span>
                                    </td>
                                    <td className="py-3 px-5 whitespace-nowrap">
                                        {getStatusBadge(activity.status)}
                                    </td>
                                    <td className="py-3 px-5 text-on-surface-variant font-body-sm text-right whitespace-nowrap">{activity.time}</td>
                                </tr>
                            ))
                          ) : (
                            <tr>
                                <td colSpan="4" className="py-8 text-center text-on-surface-variant font-body-md">
                                    Chưa có hoạt động nào được ghi nhận.
                                </td>
                            </tr>
                          )}
                      </tbody>
                  </table>
              </div>

              {/* Table Pagination Toolbar */}
              <div className="p-3.5 px-5 border-t border-outline-variant flex flex-col sm:flex-row items-center justify-between gap-3 bg-surface-container-lowest text-[12px] text-on-surface-variant">
                  {/* Left: Item Range */}
                  <div>
                    <span>{startItem} - {endItem} of {activityPagination.total} items</span>
                  </div>

                  {/* Right: Page Size & Pagination Buttons */}
                  <div className="flex items-center gap-3">
                    <div className="flex items-center gap-1.5">
                      <select
                        value={activityLimit}
                        onChange={(e) => {
                          const newLimit = parseInt(e.target.value, 10);
                          setActivityLimit(newLimit);
                          // Khi đổi limit, reset sang trang mới nhất
                          setActivityPage(null);
                        }}
                        className="bg-white border border-outline-variant rounded-md px-2.5 py-1 text-[12px] text-on-surface font-medium cursor-pointer focus:outline-none focus:border-primary"
                      >
                        <option value={5}>5 / page</option>
                        <option value={10}>10 / page</option>
                        <option value={20}>20 / page</option>
                      </select>
                    </div>

                    <div className="flex items-center gap-1">
                      {/* Prev Button */}
                      <button
                        onClick={() => setActivityPage(prev => Math.max(1, (prev || 1) - 1))}
                        disabled={currPage <= 1}
                        className={`w-7 h-7 flex items-center justify-center rounded border border-outline-variant/60 text-on-surface transition-colors cursor-pointer ${
                          currPage <= 1 ? 'opacity-30 pointer-events-none' : 'hover:bg-surface-container-low'
                        }`}
                      >
                        <span className="material-symbols-outlined text-[16px]">chevron_left</span>
                      </button>

                      {/* Page numbers: 1 is oldest, N is newest */}
                      {Array.from({ length: activityPagination.totalPages }).map((_, idx) => {
                        const pageNum = idx + 1;
                        const isActive = pageNum === currPage;
                        return (
                          <button
                            key={pageNum}
                            onClick={() => setActivityPage(pageNum)}
                            className={`w-7 h-7 flex items-center justify-center rounded text-[12px] font-medium transition-colors cursor-pointer ${
                              isActive
                                ? 'border border-primary text-primary font-bold bg-primary/5'
                                : 'border border-transparent text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface'
                            }`}
                          >
                            {pageNum}
                          </button>
                        );
                      })}

                      {/* Next Button */}
                      <button
                        onClick={() => setActivityPage(prev => Math.min(activityPagination.totalPages, (prev || 1) + 1))}
                        disabled={currPage >= activityPagination.totalPages}
                        className={`w-7 h-7 flex items-center justify-center rounded border border-outline-variant/60 text-on-surface transition-colors cursor-pointer ${
                          currPage >= activityPagination.totalPages ? 'opacity-30 pointer-events-none' : 'hover:bg-surface-container-low'
                        }`}
                      >
                        <span className="material-symbols-outlined text-[16px]">chevron_right</span>
                      </button>
                    </div>
                  </div>
              </div>
          </div>
          
          {/* Biểu đồ 1: Tần suất Đăng nhập (Ăn theo Global Filter, đã gỡ bộ lọc con) */}
          <div className="bg-white rounded-xl border border-outline-variant shadow-sm p-5 flex flex-col h-full relative overflow-hidden group">
              <div className="absolute -bottom-10 -right-10 w-40 h-40 bg-primary/5 rounded-full blur-2xl group-hover:bg-primary/10 transition-colors duration-500"></div>
              
              <div className="flex justify-between items-start mb-5">
                  <div>
                      <h2 className="font-title-lg text-title-lg font-bold text-on-surface m-0 flex items-center gap-2">
                          <span className="material-symbols-outlined text-primary text-[22px]">bar_chart</span>
                          Đăng nhập
                      </h2>
                      <p className="font-body-sm text-on-surface-variant mt-0.5">Tần suất người dùng đăng nhập</p>
                  </div>
              </div>
              
              <div className="flex-1 flex flex-col justify-center min-h-[190px] mb-5 relative">
                  <InteractiveLineChart
                    data={loginStats.timeline}
                    gradientId="loginChartGrad"
                    strokeColor="#2563eb"
                    gradientFrom="#3b82f6"
                    gradientTo="#1d4ed8"
                    unit="lượt"
                    loading={loadingLogin}
                    height={190}
                  />
              </div>
              
              <div className="grid grid-cols-2 gap-3 pt-4 border-t border-outline-variant relative z-10">
                  <div className="bg-surface-container-lowest p-3 rounded-lg text-center border border-outline-variant/30">
                      <p className="font-label-sm text-on-surface-variant mb-1 uppercase tracking-wider text-[11px]">Trung bình</p>
                      <p className="font-title-lg font-bold text-primary m-0">
                        {(loginStats.summary?.avg || 0).toLocaleString('vi-VN')} <span className="text-[12px] font-normal text-on-surface-variant">lượt</span>
                      </p>
                  </div>
                  <div className="bg-surface-container-lowest p-3 rounded-lg text-center border border-outline-variant/30">
                      <p className="font-label-sm text-on-surface-variant mb-1 uppercase tracking-wider text-[11px]">Đỉnh điểm</p>
                      <p className="font-title-lg font-bold text-on-surface m-0">
                        {(loginStats.summary?.max || 0).toLocaleString('vi-VN')} <span className="text-[12px] font-normal text-on-surface-variant">lượt</span>
                      </p>
                  </div>
              </div>
          </div>
      </div>

      {/* Biểu đồ 2: Lưu lượng Request (Ăn theo Global Filter, đã gỡ bộ lọc con) */}
      <div className="bg-white rounded-xl border border-outline-variant shadow-sm p-5 md:p-6 overflow-hidden relative">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-5 relative z-10">
              <div>
                  <h2 className="font-title-lg text-title-lg font-bold text-on-surface m-0 flex items-center gap-2">
                      <span className="material-symbols-outlined text-primary text-[22px]">ssid_chart</span>
                      Lưu lượng Request
                  </h2>
                  <p className="font-body-sm text-on-surface-variant mt-0.5">Giám sát tải hệ thống và lưu lượng yêu cầu</p>
              </div>
              <div className="flex items-center gap-3">
                  <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-[#dcfce7] text-[#166534] font-label-md text-[11px] font-semibold border border-[#86efac]">
                      <span className="relative flex h-2 w-2">
                          <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#166534] opacity-75"></span>
                          <span className="relative inline-flex rounded-full h-2 w-2 bg-[#166534]"></span>
                      </span>
                      Live Mode
                  </span>
              </div>
          </div>
          
          <div className="w-full relative mt-2 bg-surface-container-lowest rounded-lg p-4 border border-outline-variant/30">
              <InteractiveLineChart
                data={requestStats.timeline}
                gradientId="reqChartGrad"
                strokeColor="#0284c7"
                gradientFrom="#38bdf8"
                gradientTo="#0284c7"
                unit="req"
                loading={loadingRequest}
                height={220}
              />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 pt-5 mt-4 border-t border-outline-variant relative z-10">
              <div className="bg-surface-container-lowest p-3 rounded-lg text-center border border-outline-variant/30">
                  <p className="font-label-sm text-on-surface-variant mb-1 uppercase tracking-wider text-[11px]">Trung bình lưu lượng</p>
                  <p className="font-title-lg font-bold text-primary m-0">
                    {(requestStats.summary?.avg || 0).toLocaleString('vi-VN')} <span className="text-[12px] font-normal text-on-surface-variant">req</span>
                  </p>
              </div>
              <div className="bg-surface-container-lowest p-3 rounded-lg text-center border border-outline-variant/30">
                  <p className="font-label-sm text-on-surface-variant mb-1 uppercase tracking-wider text-[11px]">Lưu lượng lớn nhất</p>
                  <p className="font-title-lg font-bold text-on-surface m-0">
                    {(requestStats.summary?.max || 0).toLocaleString('vi-VN')} <span className="text-[12px] font-normal text-on-surface-variant">req</span>
                  </p>
              </div>
              <div className="bg-surface-container-lowest p-3 rounded-lg text-center border border-outline-variant/30">
                  <p className="font-label-sm text-on-surface-variant mb-1 uppercase tracking-wider text-[11px]">Tổng số Request</p>
                  <p className="font-title-lg font-bold text-secondary m-0">
                    {(requestStats.summary?.total || 0).toLocaleString('vi-VN')} <span className="text-[12px] font-normal text-on-surface-variant">req</span>
                  </p>
              </div>
          </div>
      </div>
    </div>
  );
};

export default DashboardPage;
