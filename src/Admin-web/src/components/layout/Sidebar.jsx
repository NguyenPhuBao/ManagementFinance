import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuthContext } from '../../store/auth.context';
import { useLanguageSafe } from '../../store/language.context';

const Sidebar = ({ collapsed, onToggle }) => {
  const navigate = useNavigate();
  const { logout } = useAuthContext();
  const { t } = useLanguageSafe();

  const navItems = [
    { key: '/dashboard', icon: 'dashboard', label: t('nav.dashboard') },
    { key: '/aiops', icon: 'security', label: t('nav.aiops') },
    { key: '/users', icon: 'group', label: t('nav.users') },
    { key: '/permissions', icon: 'admin_panel_settings', label: t('nav.permissions') },
    { key: '/payments', icon: 'receipt_long', label: t('nav.payments') },
    { key: '/categories', icon: 'category', label: t('nav.categories') },
    { key: '/audit-logs', icon: 'fact_check', label: t('nav.auditLogs') },
    { key: '/broadcast', icon: 'campaign', label: t('nav.broadcast') },
  ];

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  return (
    <>
      {/* Mobile Backdrop Overlay khi Sidebar mở */}
      {!collapsed && (
        <div
          onClick={onToggle}
          className="fixed inset-0 bg-slate-900/50 backdrop-blur-xs z-35 md:hidden animate-in fade-in duration-150"
        />
      )}

      <aside
        className={`fixed left-0 top-0 h-full bg-on-background border-r border-outline-variant flex flex-col py-page-padding transition-all duration-300 z-40 overflow-x-hidden ${
          collapsed
            ? '-translate-x-full md:translate-x-0 md:w-[76px]'
            : 'translate-x-0 w-[260px] shadow-2xl md:shadow-none'
        }`}
      >
        {/* Brand Header */}
        <div className="px-4 mb-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-primary flex items-center justify-center text-white shrink-0 overflow-hidden shadow-2xs">
              <span className="material-symbols-outlined text-[24px]">account_balance</span>
            </div>
            {!collapsed && (
              <div className="min-w-0 transition-opacity duration-200">
                <h1 className="font-headline-md text-headline-md font-bold text-white whitespace-nowrap truncate">
                  {t('nav.brandSubtitle')}
                </h1>
                <p className="text-[10px] text-primary-fixed-dim uppercase tracking-wider font-semibold">
                  Admin Portal
                </p>
              </div>
            )}
          </div>
        </div>

        {/* Navigation Items */}
        <div className="flex-1 overflow-y-auto overflow-x-hidden px-2 space-y-1">
          {navItems.map((item) => (
            <NavLink
              key={item.key}
              to={item.key}
              title={collapsed ? item.label : undefined}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-xl border-l-4 cursor-pointer transition-all duration-200 ${
                  collapsed ? 'justify-center px-0' : ''
                } ${
                  isActive
                    ? 'border-primary-fixed-dim bg-on-secondary-fixed-variant text-white font-bold shadow-2xs'
                    : 'border-transparent text-secondary-fixed-dim hover:text-white hover:bg-on-secondary-fixed-variant/70'
                }`
              }
            >
              <span className="material-symbols-outlined shrink-0 text-[22px]">{item.icon}</span>
              {!collapsed && (
                <span className="font-body-md text-body-md whitespace-nowrap truncate">{item.label}</span>
              )}
            </NavLink>
          ))}
        </div>

        {/* Footer: Thu gọn & Đăng xuất */}
        <div className="px-2 mt-auto pt-4 border-t border-secondary-fixed-dim/20 space-y-1">
          {/* Nút Toggle Mini Mode trên Desktop */}
          <button
            type="button"
            onClick={onToggle}
            title={collapsed ? 'Mở rộng menu' : 'Thu nhỏ menu'}
            className={`w-full hidden md:flex items-center gap-3 px-3 py-2 rounded-xl text-secondary-fixed-dim hover:text-white hover:bg-on-secondary-fixed-variant/70 transition cursor-pointer ${
              collapsed ? 'justify-center px-0' : ''
            }`}
          >
            <span className="material-symbols-outlined shrink-0 text-[20px]">
              {collapsed ? 'chevron_right' : 'chevron_left'}
            </span>
            {!collapsed && (
              <span className="text-xs font-semibold whitespace-nowrap">
                Thu gọn thanh bên
              </span>
            )}
          </button>

          {/* Đăng xuất */}
          <button
            onClick={handleLogout}
            title={collapsed ? t('nav.logout') : undefined}
            className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-rose-300 hover:text-rose-100 hover:bg-rose-950/40 transition-colors duration-200 cursor-pointer active:scale-95 ${
              collapsed ? 'justify-center px-0' : ''
            }`}
          >
            <span className="material-symbols-outlined shrink-0 text-[22px]">logout</span>
            {!collapsed && (
              <span className="font-body-md text-body-md">{t('nav.logout')}</span>
            )}
          </button>
        </div>
      </aside>
    </>
  );
};

export default Sidebar;
