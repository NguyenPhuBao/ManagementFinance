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
  format = 'day',
  loading = false,
  height = 200,
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
  const paddingLeft = 40;
  const paddingRight = 45;
  const paddingTop = 20;
  const paddingBottom = 40;
  const width = 1000;
  const svgHeight = 280;
  const drawWidth = width - paddingLeft - paddingRight;
  const drawHeight = svgHeight - paddingTop - paddingBottom;

  const points = data.map((item, index) => {
    const x = data.length === 1 ? width / 2 : paddingLeft + (index / (data.length - 1)) * drawWidth;
    const y = paddingTop + drawHeight - ((item.count - minVal) / (maxVal - minVal)) * drawHeight;
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

  const areaD = `${pathD} L ${points[points.length - 1].x} ${paddingTop + drawHeight} L ${points[0].x} ${paddingTop + drawHeight} Z`;

  // Determine X-axis ticks and Unit label
  let xUnit = 'Ngày';
  let xTicks = [];

  const isMonthFormat = format === 'month' || (data.length === 12 && data[0]?.label?.startsWith('Thg'));
  const isHourFormat = format === 'hour' || (data.length === 24 && data[0]?.label?.includes(':'));

  if (isMonthFormat) {
    xUnit = 'Tháng';
    // Đánh số đầy đủ 01 -> 12 cho tất cả 12 tháng
    xTicks = points.map((pt, idx) => ({
      x: pt.x,
      text: (idx + 1).toString().padStart(2, '0'),
    }));
  } else if (isHourFormat) {
    xUnit = 'Giờ';
    // 24 giờ: hiển thị các mốc chẵn 00, 02, 04, ..., 22 và mốc cuối 23
    xTicks = points
      .filter((_, idx) => idx % 2 === 0 || idx === points.length - 1)
      .map((pt) => ({
        x: pt.x,
        text: pt.label.split(':')[0] || '',
      }));
  } else if (data.length <= 8) {
    xUnit = 'Ngày';
    // 7 ngày: hiển thị đủ cả 7 ngày
    xTicks = points.map((pt) => ({
      x: pt.x,
      text: pt.label,
    }));
  } else {
    xUnit = 'Ngày';
    // 30 / 31 ngày: hiển thị cách đều các ngày 01, 05, 10, 15, 20, 25, 30
    xTicks = points
      .filter((_, idx) => idx % 5 === 0 || idx === points.length - 1)
      .map((pt) => ({
        x: pt.x,
        text: pt.label.split('/')[0] || '',
      }));
  }

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
              <stop offset="0%" stopColor={strokeColor} stopOpacity="0.22" />
              <stop offset="100%" stopColor={strokeColor} stopOpacity="0.0" />
            </linearGradient>
            <linearGradient id={`${gradientId}-line`} x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stopColor={gradientFrom} />
              <stop offset="100%" stopColor={gradientTo} />
            </linearGradient>
          </defs>

          {/* Grid lines */}
          <line x1={paddingLeft} y1={paddingTop} x2={width - paddingRight} y2={paddingTop} stroke="currentColor" className="text-outline-variant/30" strokeWidth="1" strokeDasharray="4 4" vectorEffect="non-scaling-stroke" />
          <line x1={paddingLeft} y1={paddingTop + drawHeight / 2} x2={width - paddingRight} y2={paddingTop + drawHeight / 2} stroke="currentColor" className="text-outline-variant/30" strokeWidth="1" strokeDasharray="4 4" vectorEffect="non-scaling-stroke" />
          <line x1={paddingLeft} y1={paddingTop + drawHeight} x2={width - paddingRight} y2={paddingTop + drawHeight} stroke="currentColor" className="text-outline-variant/50" strokeWidth="1" vectorEffect="non-scaling-stroke" />

          {/* Y Axis min/max labels inside SVG */}
          <text x={paddingLeft - 8} y={paddingTop + 4} textAnchor="end" fill="#64748b" fontSize="11" fontWeight="600" fontFamily="Inter, sans-serif">{maxVal.toLocaleString('vi-VN')}</text>
          <text x={paddingLeft - 8} y={paddingTop + drawHeight / 2 + 4} textAnchor="end" fill="#64748b" fontSize="11" fontWeight="600" fontFamily="Inter, sans-serif">{Math.round(maxVal / 2).toLocaleString('vi-VN')}</text>
          <text x={paddingLeft - 8} y={paddingTop + drawHeight + 4} textAnchor="end" fill="#64748b" fontSize="11" fontWeight="600" fontFamily="Inter, sans-serif">0</text>

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

          {/* X Axis ticks (Aligned exactly with coordinates) */}
          {xTicks.map((tick, idx) => (
            <text
              key={idx}
              x={tick.x}
              y={paddingTop + drawHeight + 22}
              textAnchor="middle"
              fill="#64748b"
              fontSize={data.length > 20 ? 11 : 12}
              fontWeight="500"
              fontFamily="Inter, sans-serif"
            >
              {tick.text}
            </text>
          ))}

          {/* X Unit label placed on the right of the X axis */}
          <text
            x={width - 5}
            y={paddingTop + drawHeight + 22}
            textAnchor="end"
            fill="#64748b"
            fontSize="12"
            fontWeight="600"
            fontFamily="Inter, sans-serif"
          >
            ({xUnit})
          </text>

          {/* Active Tooltip on SVG */}
          {hoveredPoint && (
            <g transform={`translate(${Math.min(Math.max(hoveredPoint.x, 60), width - 60)}, ${Math.max(hoveredPoint.y - 45, 10)})`}>
              <rect x="-48" y="0" width="96" height="34" rx="6" fill="#0f172a" opacity="0.95" />
              <text x="0" y="14" fill="#94a3b8" fontSize="10" fontFamily="Inter, sans-serif" textAnchor="middle">{hoveredPoint.label}</text>
              <text x="0" y="27" fill="#ffffff" fontSize="11" fontWeight="bold" fontFamily="Inter, sans-serif" textAnchor="middle">
                {hoveredPoint.count.toLocaleString('vi-VN')} {unit}
              </text>
            </g>
          )}
        </svg>
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
    format: 'hour',
  });
  const [loadingLogin, setLoadingLogin] = useState(false);

  const [requestStats, setRequestStats] = useState({
    summary: { total: 0, max: 0, avg: 0 },
    timeline: [],
    format: 'hour',
  });
  const [loadingRequest, setLoadingRequest] = useState(false);

  // 3. Table Hoạt động người dùng (Trang 1 = mới nhất, phân trang 1 -> 2 -> 3...)
  const [recentActivities, setRecentActivities] = useState([]);
  const [activityPage, setActivityPage] = useState(1);
  const [activityLimit, setActivityLimit] = useState(5);
  const [activityPagination, setActivityPagination] = useState({
    total: 0,
    page: 1,
    limit: 5,
    totalPages: 1,
  });
  const [loadingActivities, setLoadingActivities] = useState(false);

  // Helper tính danh sách số trang thông minh (tối đa 3 trang quanh trang hiện tại + ...)
  const getPageNumbers = (curr, total) => {
    if (total <= 5) {
      return Array.from({ length: total }, (_, i) => i + 1);
    }
    if (curr <= 2) {
      return [1, 2, 3, '...', total];
    }
    if (curr >= total - 1) {
      return [1, '...', total - 2, total - 1, total];
    }
    return [1, '...', curr - 1, curr, curr + 1, '...', total];
  };

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

  // Fetch Hoạt động người dùng theo phân trang (Trang 1 = mới nhất, sort: 'desc')
  const fetchActivities = async (targetPage, limit) => {
    setLoadingActivities(true);
    try {
      const pageToFetch = targetPage || activityPage || 1;
      const res = await adminApi.getRecentActivities({
        page: pageToFetch,
        limit: limit || activityLimit,
        sort: 'desc',
      });

      if (res.data) {
        const { items, pagination } = res.data;
        setRecentActivities((items || []).map(item => ({
          key: item.id ? String(item.id) : Math.random().toString(),
          id: item.id,
          user: item.user || 'Người dùng',
          action: item.action || 'Yêu cầu hệ thống',
          status: item.status || 'Pass',
          time: item.time || 'Vừa xong',
          isNew: false,
        })));

        setActivityPagination(pagination);
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

      // Tăng tổng số lượng bản ghi
      setActivityPagination((prev) => {
        const newTotal = prev.total + 1;
        const newTotalPages = Math.max(1, Math.ceil(newTotal / prev.limit));
        return {
          ...prev,
          total: newTotal,
          totalPages: newTotalPages,
        };
      });

      // Nếu đang ở Trang 1 (mới nhất), chèn ngay bản ghi mới vào đầu bảng
      setActivityPage((currentPage) => {
        if (currentPage === 1) {
          setRecentActivities((prevList) => {
            const filtered = prevList.filter(item => item.id !== newActivity.id);
            return [newActivity, ...filtered].slice(0, activityLimit);
          });
        }
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

  // Pagination display values (Trang 1: 1 - 5 of 36 items)
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

      {/* 1. Table: Hoạt động gần đây (Full-width, Phân trang 1 -> 2 -> 3, Trang 1 = mới nhất) */}
      <div className="w-full bg-white rounded-xl border border-outline-variant shadow-sm overflow-hidden flex flex-col relative">
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
                {/* Custom Styled Select (hết bị đè mũi tên) */}
                <div className="relative inline-flex items-center">
                  <select
                    value={activityLimit}
                    onChange={(e) => {
                      const newLimit = parseInt(e.target.value, 10);
                      setActivityLimit(newLimit);
                      setActivityPage(1);
                    }}
                    className="appearance-none bg-white border border-outline-variant rounded-md pl-3 pr-8 py-1 text-[12px] text-on-surface font-medium cursor-pointer focus:outline-none focus:border-primary shadow-2xs"
                  >
                    <option value={5}>5 / page</option>
                    <option value={10}>10 / page</option>
                    <option value={20}>20 / page</option>
                  </select>
                  <span className="material-symbols-outlined text-[18px] text-on-surface-variant pointer-events-none absolute right-1.5">
                    arrow_drop_down
                  </span>
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

                  {/* Smart Page numbers (tối đa 3 trang quanh trang hiện tại + ...) */}
                  {getPageNumbers(currPage, activityPagination.totalPages).map((p, idx) => {
                    if (p === '...') {
                      return (
                        <span key={`ellipsis-${idx}`} className="w-7 h-7 flex items-center justify-center text-on-surface-variant font-medium text-[12px]">
                          ...
                        </span>
                      );
                    }
                    const isActive = p === currPage;
                    return (
                      <button
                        key={p}
                        onClick={() => setActivityPage(p)}
                        className={`w-7 h-7 flex items-center justify-center rounded text-[12px] font-medium transition-colors cursor-pointer ${
                          isActive
                            ? 'border border-primary text-primary font-bold bg-primary/10'
                            : 'border border-transparent text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface'
                        }`}
                      >
                        {p}
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

      {/* 2. Charts Grid: Luôn nằm DƯỚI Table Hoạt động gần đây */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Biểu đồ 1: Tần suất Đăng nhập */}
          <div className="bg-white rounded-xl border border-outline-variant shadow-sm p-5 md:p-6 flex flex-col h-full relative overflow-hidden group">
              <div className="absolute -bottom-10 -right-10 w-40 h-40 bg-primary/5 rounded-full blur-2xl group-hover:bg-primary/10 transition-colors duration-500"></div>
              
              <div className="flex justify-between items-start mb-4">
                  <div>
                      <h2 className="font-title-lg text-title-lg font-bold text-on-surface m-0 flex items-center gap-2">
                          <span className="material-symbols-outlined text-primary text-[22px]">bar_chart</span>
                          Đăng nhập
                      </h2>
                      <p className="font-body-sm text-on-surface-variant mt-0.5">Tần suất đăng nhập</p>
                  </div>
              </div>
              
              <div className="flex-1 flex flex-col justify-center min-h-[200px] mb-4 relative">
                  <InteractiveLineChart
                    data={loginStats.timeline}
                    gradientId="loginChartGrad"
                    strokeColor="#2563eb"
                    gradientFrom="#3b82f6"
                    gradientTo="#1d4ed8"
                    unit="lượt"
                    format={loginStats.format || 'day'}
                    loading={loadingLogin}
                    height={200}
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

          {/* Biểu đồ 2: Lưu lượng Request */}
          <div className="bg-white rounded-xl border border-outline-variant shadow-sm p-5 md:p-6 flex flex-col h-full relative overflow-hidden group">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-4 relative z-10">
                  <div>
                      <h2 className="font-title-lg text-title-lg font-bold text-on-surface m-0 flex items-center gap-2">
                          <span className="material-symbols-outlined text-primary text-[22px]">ssid_chart</span>
                          Lưu lượng Request
                      </h2>
                      <p className="font-body-sm text-on-surface-variant mt-0.5">Giám sát tải hệ thống và lưu lượng yêu cầu</p>
                  </div>
                  <div className="flex items-center gap-3 self-start sm:self-auto">
                      <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-[#dcfce7] text-[#166534] font-label-md text-[11px] font-semibold border border-[#86efac]">
                          <span className="relative flex h-2 w-2">
                              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#166534] opacity-75"></span>
                              <span className="relative inline-flex rounded-full h-2 w-2 bg-[#166534]"></span>
                          </span>
                          Live Mode
                      </span>
                  </div>
              </div>
              
              <div className="flex-1 flex flex-col justify-center min-h-[200px] mb-4 relative">
                  <InteractiveLineChart
                    data={requestStats.timeline}
                    gradientId="reqChartGrad"
                    strokeColor="#0284c7"
                    gradientFrom="#38bdf8"
                    gradientTo="#0284c7"
                    unit="req"
                    format={requestStats.format || 'day'}
                    loading={loadingRequest}
                    height={200}
                  />
              </div>

              <div className="grid grid-cols-3 gap-3 pt-4 border-t border-outline-variant relative z-10">
                  <div className="bg-surface-container-lowest p-3 rounded-lg text-center border border-outline-variant/30">
                      <p className="font-label-sm text-on-surface-variant mb-1 uppercase tracking-wider text-[11px]">Trung bình</p>
                      <p className="font-title-lg font-bold text-primary m-0">
                        {(requestStats.summary?.avg || 0).toLocaleString('vi-VN')} <span className="text-[12px] font-normal text-on-surface-variant">req</span>
                      </p>
                  </div>
                  <div className="bg-surface-container-lowest p-3 rounded-lg text-center border border-outline-variant/30">
                      <p className="font-label-sm text-on-surface-variant mb-1 uppercase tracking-wider text-[11px]">Đỉnh điểm</p>
                      <p className="font-title-lg font-bold text-on-surface m-0">
                        {(requestStats.summary?.max || 0).toLocaleString('vi-VN')} <span className="text-[12px] font-normal text-on-surface-variant">req</span>
                      </p>
                  </div>
                  <div className="bg-surface-container-lowest p-3 rounded-lg text-center border border-outline-variant/30">
                      <p className="font-label-sm text-on-surface-variant mb-1 uppercase tracking-wider text-[11px]">Tổng Request</p>
                      <p className="font-title-lg font-bold text-secondary m-0">
                        {(requestStats.summary?.total || 0).toLocaleString('vi-VN')} <span className="text-[12px] font-normal text-on-surface-variant">req</span>
                      </p>
                  </div>
              </div>
          </div>
      </div>
    </div>
  );
};

export default DashboardPage;
