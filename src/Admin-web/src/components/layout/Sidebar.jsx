import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuthContext } from '../../store/auth.context';
import { useLanguageSafe } from '../../store/language.context';
import { Icon } from '../ui';

const NAV_ITEMS = [
  { to: '/dashboard', icon: 'dashboard', key: 'nav.dashboard' },
  { to: '/aiops', icon: 'security', key: 'nav.aiops' },
  { to: '/users', icon: 'group', key: 'nav.users' },
  { to: '/permissions', icon: 'admin_panel_settings', key: 'nav.permissions' },
  { to: '/payments', icon: 'receipt_long', key: 'nav.payments' },
  { to: '/categories', icon: 'category', key: 'nav.categories' },
  { to: '/audit-logs', icon: 'fact_check', key: 'nav.auditLogs' },
  { to: '/broadcast', icon: 'campaign', key: 'nav.broadcast' },
];

const itemBase = 'flex h-10 items-center gap-3 rounded-lg px-3 text-sm transition-colors';

const Sidebar = ({ collapsed, mobileOpen = false, onToggle, onCloseMobile }) => {
  const navigate = useNavigate();
  const { logout } = useAuthContext();
  const { t } = useLanguageSafe();

  const handleLogout = async () => {
    onCloseMobile?.();
    await logout();
    navigate('/login');
  };

  const label = (text) => <span className={`truncate ${collapsed ? 'md:sr-only' : ''}`}>{text}</span>;

  return (
    <>
      {mobileOpen && <div aria-hidden="true" onClick={onCloseMobile} className="fixed inset-0 z-30 bg-overlay md:hidden" />}
      <aside
        data-mobile-open={mobileOpen}
        className={`fixed inset-y-0 left-0 z-40 flex w-60 flex-col border-r border-line bg-card transition-all duration-200 md:translate-x-0 ${
          mobileOpen ? 'translate-x-0 shadow-xl' : '-translate-x-full'
        } ${collapsed ? 'md:w-[72px]' : 'md:w-60'}`}
      >
        <div className={`flex h-14 shrink-0 items-center gap-2.5 px-4 ${collapsed ? 'md:justify-center md:px-0' : ''}`}>
          <span aria-hidden="true" className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-brand text-sm font-bold text-brand-on">
            F
          </span>
          <span className={`truncate text-base font-bold text-ink ${collapsed ? 'md:hidden' : ''}`}>{t('nav.brandTitle', 'FlowMoney Admin')}</span>
        </div>

        <nav aria-label={t('nav.mainMenu', 'Menu chính')} className="flex-1 space-y-1 overflow-y-auto px-3 py-2">
          {NAV_ITEMS.map((item) => {
            const text = t(item.key);
            return (
              <NavLink
                key={item.to}
                to={item.to}
                onClick={onCloseMobile}
                title={collapsed ? text : undefined}
                className={({ isActive }) =>
                  `${itemBase} ${collapsed ? 'md:justify-center md:px-0' : ''} ${
                    isActive ? 'bg-brand-soft font-semibold text-brand' : 'font-medium text-ink-muted hover:bg-muted hover:text-ink'
                  }`
                }
              >
                <Icon name={item.icon} className="shrink-0" />
                {label(text)}
              </NavLink>
            );
          })}
        </nav>

        <div className="space-y-1 border-t border-line px-3 py-3">
          <button
            type="button"
            onClick={onToggle}
            title={collapsed ? t('nav.expand', 'Mở rộng menu') : undefined}
            className={`${itemBase} hidden w-full cursor-pointer font-medium text-ink-muted hover:bg-muted hover:text-ink md:flex ${
              collapsed ? 'md:justify-center md:px-0' : ''
            }`}
          >
            <Icon name={collapsed ? 'chevron_right' : 'chevron_left'} className="shrink-0" />
            {label(collapsed ? t('nav.expand', 'Mở rộng menu') : t('nav.collapse', 'Thu gọn menu'))}
          </button>
          <button
            type="button"
            onClick={handleLogout}
            title={collapsed ? t('nav.logout') : undefined}
            className={`${itemBase} w-full cursor-pointer font-medium text-danger hover:bg-danger-soft ${collapsed ? 'md:justify-center md:px-0' : ''}`}
          >
            <Icon name="logout" className="shrink-0" />
            {label(t('nav.logout'))}
          </button>
        </div>
      </aside>
    </>
  );
};

export default Sidebar;
