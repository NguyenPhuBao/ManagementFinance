import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuthContext } from '../../store/auth.context';

const NAV_ITEMS = [
  { key: '/dashboard', icon: 'dashboard', label: 'Dashboard' },
  { key: '/users', icon: 'group', label: 'User Management' },
  { key: '/categories', icon: 'category', label: 'Category Management' },
];

const Sidebar = ({ collapsed }) => {
  const navigate = useNavigate();
  const { logout } = useAuthContext();

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  return (
    <nav className={`fixed left-0 top-0 h-full w-[280px] bg-on-background border-r border-outline-variant flex-col py-page-padding transition-transform duration-300 z-40 ${collapsed ? '-translate-x-full md:translate-x-0 hidden' : 'translate-x-0 flex'} md:flex`}>
      <div className="px-gutter mb-8">
        <div className="flex items-center gap-3 mb-2">
          <div className="w-10 h-10 rounded-full bg-primary flex items-center justify-center text-white flex-shrink-0">
            <span className="material-symbols-outlined">account_balance</span>
          </div>
          <div>
            <h1 className="font-headline-md text-headline-md font-bold text-white whitespace-nowrap">Management</h1>
          </div>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-4 space-y-1">
        {NAV_ITEMS.map((item) => (
          <NavLink
            key={item.key}
            to={item.key}
            className={({ isActive }) =>
              `flex items-center gap-3 px-4 py-3 rounded-lg border-l-4 cursor-pointer transition-colors duration-200 ${
                isActive
                  ? 'border-primary-fixed-dim bg-on-secondary-fixed-variant text-white font-bold'
                  : 'border-transparent text-secondary-fixed-dim hover:text-white hover:bg-on-secondary-fixed-variant'
              }`
            }
          >
            <span className="material-symbols-outlined">{item.icon}</span>
            <span className="font-body-md text-body-md whitespace-nowrap">{item.label}</span>
          </NavLink>
        ))}
      </div>

      <div className="px-4 mt-auto pt-4 border-t border-secondary-fixed-dim border-opacity-20">
        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-3 px-4 py-3 rounded-lg text-secondary-fixed-dim hover:text-white hover:bg-on-secondary-fixed-variant transition-colors duration-200 cursor-pointer active:scale-95"
        >
          <span className="material-symbols-outlined">logout</span>
          <span className="font-body-md text-body-md">Logout</span>
        </button>
      </div>
    </nav>
  );
};

export default Sidebar;
