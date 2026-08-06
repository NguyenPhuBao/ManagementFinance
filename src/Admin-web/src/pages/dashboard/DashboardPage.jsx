import React, { useState, useEffect } from 'react';
import { TIME_FILTERS, TIME_FILTER_LABELS } from '../../utils/constants';

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
  const [timeFilter, setTimeFilter] = useState(TIME_FILTERS.MONTH);
  const [showFilterModal, setShowFilterModal] = useState(false);

  // Simulated data
  const stats = {
    totalUsers: { value: '12,205', badge: '12%', badgeColor: 'green' },
    totalCategories: { value: '48', badge: null },
    systemUptime: { value: '99.9%', badge: 'Ổn định' },
    newUsersToday: { value: '331', badge: '5%', badgeColor: 'green' },
    loginAvg: '91',
    loginPeak: '113',
  };

  const recentActivities = [
    { key: '1', user: 'Nguyễn Văn A', action: 'Tạo giao dịch mới', time: '10:45 AM' },
    { key: '2', user: 'Trần Thị B', action: 'Cập nhật hồ sơ', time: '09:12 AM' },
    { key: '3', user: 'Lê Văn C', action: 'Xóa danh mục', time: 'Hôm qua' },
  ];

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 500);
    return () => clearTimeout(timer);
  }, [timeFilter]);

  return (
    <div className="max-w-[1440px] mx-auto w-full p-4 md:p-6 space-y-6 bg-surface-bright min-h-full relative overflow-hidden">
      
      {/* Abstract Background Elements */}
      <div className="absolute top-0 right-0 w-96 h-96 bg-primary/5 rounded-full blur-3xl -z-10 translate-x-1/3 -translate-y-1/3"></div>
      <div className="absolute bottom-0 left-0 w-96 h-96 bg-secondary/5 rounded-full blur-3xl -z-10 -translate-x-1/3 translate-y-1/3"></div>
      
      {/* Header section */}
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-4">
          <div className="relative">
              <h1 className="font-display-md text-display-md font-bold text-on-surface m-0 tracking-tight">Tổng quan hệ thống</h1>
              <p className="font-body-lg text-on-surface-variant mt-2 max-w-xl">Dữ liệu tài chính và hoạt động được cập nhật liên tục để cung cấp cái nhìn toàn diện về hiệu suất.</p>
          </div>
          
          <div className="flex bg-white p-1 rounded-lg border border-outline-variant shadow-sm self-start md:self-auto">
              {Object.entries(TIME_FILTER_LABELS).map(([key, label]) => (
                <button
                    key={key}
                    onClick={() => setTimeFilter(key)}
                    className={`px-4 py-1.5 rounded-md font-label-md text-[13px] transition-all duration-200 cursor-pointer ${
                      timeFilter === key ? 'bg-primary text-white font-semibold shadow-sm' : 'text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface'
                    }`}
                >
                    {label}
                </button>
              ))}
          </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6 relative">
          {loading && (
            <div className="absolute inset-0 bg-white/50 backdrop-blur-[2px] z-10 flex items-center justify-center rounded-xl">
              <span className="material-symbols-outlined animate-spin text-primary text-3xl">progress_activity</span>
            </div>
          )}
          <StatCard icon="group" title="Tổng người dùng" value={stats.totalUsers.value} badge={stats.totalUsers.badge} badgeColor={stats.totalUsers.badgeColor} />
          <StatCard icon="category" title="Tổng danh mục" value={stats.totalCategories.value} badge={stats.totalCategories.badge} />
          <StatCard icon="dns" title="Uptime Hệ thống" value={stats.systemUptime.value} badge={stats.systemUptime.badge} />
          <StatCard icon="person_add" title="Người dùng mới" value={stats.newUsersToday.value} badge={stats.newUsersToday.badge} badgeColor={stats.newUsersToday.badgeColor} />
      </div>

      {/* Main Content Grid */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6 relative">
          {loading && (
            <div className="absolute inset-0 bg-white/50 backdrop-blur-[2px] z-10 flex items-center justify-center rounded-xl">
              <span className="material-symbols-outlined animate-spin text-primary text-3xl">progress_activity</span>
            </div>
          )}
          
          {/* Recent Activity */}
          <div className="xl:col-span-2 bg-white rounded-xl border border-outline-variant shadow-sm overflow-hidden flex flex-col h-full">
              <div className="p-5 border-b border-outline-variant flex items-center justify-between bg-surface-container-lowest">
                  <h2 className="font-title-lg text-title-lg font-bold text-on-surface m-0 flex items-center gap-2">
                      <span className="material-symbols-outlined text-primary text-[22px]">history</span>
                      Hoạt động gần đây
                  </h2>
                  <div className="flex items-center gap-2">
                      <button onClick={() => setShowFilterModal(true)} className="p-1.5 text-on-surface-variant hover:text-primary hover:bg-primary/10 rounded transition-colors cursor-pointer" title="Lọc hoạt động">
                          <span className="material-symbols-outlined text-[20px]">filter_list</span>
                      </button>
                      <button className="text-primary font-label-md text-[13px] font-semibold hover:underline cursor-pointer px-2">Xem tất cả</button>
                  </div>
              </div>
              
              <div className="flex-1 overflow-x-auto">
                  <table className="w-full text-left border-collapse min-w-[500px]">
                      <thead>
                          <tr className="bg-surface-container-low/50">
                              <th className="py-3 px-5 font-label-sm text-[11px] text-on-surface-variant uppercase tracking-wider font-semibold">Người dùng</th>
                              <th className="py-3 px-5 font-label-sm text-[11px] text-on-surface-variant uppercase tracking-wider font-semibold">Hành động</th>
                              <th className="py-3 px-5 font-label-sm text-[11px] text-on-surface-variant uppercase tracking-wider font-semibold text-right">Thời gian</th>
                          </tr>
                      </thead>
                      <tbody className="divide-y divide-outline-variant/50">
                          {recentActivities.map(activity => (
                              <tr key={activity.key} className="hover:bg-surface-container-lowest transition-colors group">
                                  <td className="py-3 px-5">
                                      <div className="flex items-center gap-3">
                                          <div className="w-8 h-8 rounded-full bg-secondary/10 text-secondary flex items-center justify-center font-bold text-sm shadow-sm group-hover:scale-105 transition-transform">
                                              {activity.user.split(' ').pop().charAt(0)}
                                          </div>
                                          <span className="font-body-md font-semibold text-on-surface">{activity.user}</span>
                                      </div>
                                  </td>
                                  <td className="py-3 px-5 text-on-surface-variant font-body-md">{activity.action}</td>
                                  <td className="py-3 px-5 text-on-surface-variant font-body-sm text-right whitespace-nowrap">{activity.time}</td>
                              </tr>
                          ))}
                      </tbody>
                  </table>
              </div>
          </div>
          
          {/* Login Stats */}
          <div className="bg-white rounded-xl border border-outline-variant shadow-sm p-5 flex flex-col h-full relative overflow-hidden group">
              <div className="absolute -bottom-10 -right-10 w-40 h-40 bg-primary/5 rounded-full blur-2xl group-hover:bg-primary/10 transition-colors duration-500"></div>
              
              <div className="flex justify-between items-start mb-6">
                  <div>
                      <h2 className="font-title-lg text-title-lg font-bold text-on-surface m-0 flex items-center gap-2">
                          <span className="material-symbols-outlined text-primary text-[22px]">bar_chart</span>
                          Đăng nhập
                      </h2>
                      <p className="font-body-sm text-on-surface-variant mt-1">Tần suất đăng nhập theo giờ</p>
                  </div>
              </div>
              
              <div className="flex-1 flex flex-col justify-center min-h-[180px] mb-6 relative">
                  {/* Decorative chart representation */}
                  <svg width="100%" height="100%" viewBox="0 0 100 100" preserveAspectRatio="none" className="absolute inset-0 drop-shadow-md">
                      <path d="M 0 60 Q 20 40 40 50 T 80 30 T 100 40" fill="none" stroke="currentColor" className="text-primary" strokeWidth="2.5" vectorEffect="non-scaling-stroke" strokeLinecap="round" />
                      <circle cx="20" cy="50" r="3" fill="white" stroke="currentColor" className="text-primary" strokeWidth="1.5" />
                      <circle cx="40" cy="50" r="3" fill="white" stroke="currentColor" className="text-primary" strokeWidth="1.5" />
                      <circle cx="80" cy="30" r="3" fill="currentColor" className="text-primary" />
                  </svg>
                  <div className="absolute inset-0 bg-gradient-to-t from-white via-transparent to-transparent z-0"></div>
                  
                  <div className="absolute bottom-0 left-0 right-0 flex justify-between text-[10px] text-on-surface-variant font-medium">
                      <span>00:00</span>
                      <span>08:00</span>
                      <span>16:00</span>
                      <span>24:00</span>
                  </div>
              </div>
              
              <div className="grid grid-cols-2 gap-4 pt-5 border-t border-outline-variant relative z-10">
                  <div className="bg-surface-container-lowest p-3 rounded-lg text-center">
                      <p className="font-label-sm text-on-surface-variant mb-1 uppercase tracking-wider">Trung bình</p>
                      <p className="font-display-sm font-bold text-primary m-0">{stats.loginAvg}/h</p>
                  </div>
                  <div className="bg-surface-container-lowest p-3 rounded-lg text-center">
                      <p className="font-label-sm text-on-surface-variant mb-1 uppercase tracking-wider">Đỉnh điểm</p>
                      <p className="font-display-sm font-bold text-on-surface m-0">{stats.loginPeak}/h</p>
                  </div>
              </div>
          </div>
      </div>

      {/* Real-time Requests Area Chart */}
      <div className="bg-white rounded-xl border border-outline-variant shadow-sm p-5 md:p-6 overflow-hidden relative">
          {loading && (
            <div className="absolute inset-0 bg-white/50 backdrop-blur-[2px] z-10 flex items-center justify-center">
              <span className="material-symbols-outlined animate-spin text-primary text-3xl">progress_activity</span>
            </div>
          )}
          
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6 relative z-10">
              <div>
                  <h2 className="font-title-lg text-title-lg font-bold text-on-surface m-0 flex items-center gap-2">
                      <span className="material-symbols-outlined text-primary text-[22px]">ssid_chart</span>
                      Lưu lượng Request
                  </h2>
                  <p className="font-body-sm text-on-surface-variant mt-1">Giám sát tải hệ thống thời gian thực</p>
              </div>
              <div className="flex items-center gap-3">
                  <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-error/10 text-error font-label-md text-[12px] font-semibold border border-error/20">
                      <span className="relative flex h-2 w-2">
                          <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-error opacity-75"></span>
                          <span className="relative inline-flex rounded-full h-2 w-2 bg-error"></span>
                      </span>
                      Live Mode
                  </span>
              </div>
          </div>
          
          <div className="w-full h-[220px] md:h-[260px] relative mt-4 bg-surface-container-lowest rounded-lg p-4 border border-outline-variant/30">
              <svg width="100%" height="100%" viewBox="0 0 1000 400" preserveAspectRatio="none" className="overflow-visible drop-shadow-sm">
                  <defs>
                      <linearGradient id="areaGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                          <stop offset="0%" stopColor="#2563eb" stopOpacity="0.25" />
                          <stop offset="100%" stopColor="#2563eb" stopOpacity="0" />
                      </linearGradient>
                      <linearGradient id="lineGradient" x1="0%" y1="0%" x2="100%" y2="0%">
                          <stop offset="0%" stopColor="#3b82f6" />
                          <stop offset="50%" stopColor="#2563eb" />
                          <stop offset="100%" stopColor="#1d4ed8" />
                      </linearGradient>
                  </defs>
                  
                  {/* Grid lines */}
                  <line x1="0" y1="100" x2="1000" y2="100" stroke="currentColor" className="text-outline-variant/30" strokeWidth="1" strokeDasharray="4 4" vectorEffect="non-scaling-stroke" />
                  <line x1="0" y1="200" x2="1000" y2="200" stroke="currentColor" className="text-outline-variant/30" strokeWidth="1" strokeDasharray="4 4" vectorEffect="non-scaling-stroke" />
                  <line x1="0" y1="300" x2="1000" y2="300" stroke="currentColor" className="text-outline-variant/30" strokeWidth="1" strokeDasharray="4 4" vectorEffect="non-scaling-stroke" />
                  
                  {/* Area path */}
                  <path d="M 0 250 Q 150 120 300 200 T 500 150 T 750 280 T 1000 120 L 1000 400 L 0 400 Z" fill="url(#areaGradient)" />
                  {/* Stroke path */}
                  <path d="M 0 250 Q 150 120 300 200 T 500 150 T 750 280 T 1000 120" fill="none" stroke="url(#lineGradient)" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round" vectorEffect="non-scaling-stroke" />
                  
                  {/* Data points */}
                  <circle cx="300" cy="200" r="4" fill="white" stroke="#2563eb" strokeWidth="2" vectorEffect="non-scaling-stroke" />
                  <circle cx="500" cy="150" r="4" fill="white" stroke="#2563eb" strokeWidth="2" vectorEffect="non-scaling-stroke" />
                  <circle cx="750" cy="280" r="4" fill="white" stroke="#2563eb" strokeWidth="2" vectorEffect="non-scaling-stroke" />
                  
                  {/* Tooltip mockup */}
                  <g transform="translate(450, 90)">
                      <rect x="0" y="0" width="100" height="40" rx="4" fill="white" stroke="#e5e7eb" strokeWidth="1" filter="drop-shadow(0 4px 6px rgba(0,0,0,0.05))" />
                      <text x="50" y="16" fontFamily="Inter, sans-serif" fontSize="10" fill="#6b7280" textAnchor="middle">14:45</text>
                      <text x="50" y="32" fontFamily="Inter, sans-serif" fontSize="12" fontWeight="bold" fill="#111827" textAnchor="middle">2,451 req</text>
                      <path d="M 50 40 L 45 45 L 55 45 Z" fill="white" stroke="#e5e7eb" strokeWidth="1" />
                      <path d="M 46 41 L 54 41" fill="white" stroke="white" strokeWidth="2" />
                  </g>
              </svg>
              
              <div className="absolute left-2 top-0 bottom-6 flex flex-col justify-between py-2 text-[10px] text-on-surface-variant font-medium pointer-events-none">
                  <span>3k</span>
                  <span>2k</span>
                  <span>1k</span>
                  <span>0</span>
              </div>
              
              <div className="flex justify-between mt-4 pl-6 text-[10px] text-on-surface-variant font-medium uppercase tracking-widest">
                  <span>14:00</span>
                  <span>14:15</span>
                  <span>14:30</span>
                  <span>14:45</span>
                  <span>15:00</span>
                  <span>15:15</span>
                  <span>15:30</span>
              </div>
          </div>
      </div>
      
      {/* Filter Modal */}
      {showFilterModal && (
        <div className="fixed inset-0 bg-on-background/50 flex items-center justify-center z-50 p-4 backdrop-blur-sm">
          <div className="bg-white rounded-xl w-full max-w-md shadow-xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div className="px-6 py-4 border-b border-outline-variant flex justify-between items-center bg-surface-container-lowest">
              <h3 className="font-title-lg font-bold m-0 text-on-surface flex items-center gap-2">
                <span className="material-symbols-outlined text-primary">filter_list</span>
                Lọc hoạt động
              </h3>
              <button onClick={() => setShowFilterModal(false)} className="text-on-surface-variant hover:text-on-surface hover:bg-surface-container-low p-1 rounded-full transition-colors cursor-pointer">
                <span className="material-symbols-outlined">close</span>
              </button>
            </div>
            
            <div className="p-6 flex flex-col gap-5">
              <div>
                <label className="block font-label-md text-on-surface mb-1">Hành động</label>
                <input type="text" placeholder="Nhập hành động..." className="w-full px-4 py-2 border border-outline-variant rounded-lg focus:ring-2 focus:ring-primary focus:border-primary outline-none transition-all font-body-md" />
              </div>
              
              <div>
                <label className="block font-label-md text-on-surface mb-1">Người dùng</label>
                <div className="relative">
                  <select className="w-full px-4 py-2 border border-outline-variant rounded-lg focus:ring-2 focus:ring-primary focus:border-primary outline-none transition-all appearance-none cursor-pointer font-body-md bg-white">
                    <option value="">Tất cả người dùng</option>
                    <option value="1">Nguyễn Văn A</option>
                    <option value="2">Trần Thị B</option>
                    <option value="3">Lê Văn C</option>
                  </select>
                  <span className="material-symbols-outlined absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none text-on-surface-variant">expand_more</span>
                </div>
              </div>
            </div>
            
            <div className="px-6 py-4 border-t border-outline-variant flex justify-end gap-3 bg-surface-container-lowest">
              <button onClick={() => setShowFilterModal(false)} className="px-5 py-2 rounded-lg font-label-md text-on-surface border border-outline-variant hover:bg-surface-container-low transition-colors cursor-pointer">
                Hủy
              </button>
              <button onClick={() => setShowFilterModal(false)} className="px-5 py-2 rounded-lg font-label-md bg-primary text-white hover:bg-surface-tint shadow-sm transition-colors cursor-pointer">
                Áp dụng
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default DashboardPage;
