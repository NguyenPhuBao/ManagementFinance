import React, { useState } from 'react';
import { Outlet } from 'react-router-dom';
import AppSidebar from './Sidebar';
import AppHeader from './Header';

const AppLayout = () => {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(true);

  const toggleSidebar = () => setSidebarCollapsed(prev => !prev);

  return (
    <div className="min-h-screen relative">
      <AppSidebar collapsed={sidebarCollapsed} />
      <AppHeader onMenuToggle={toggleSidebar} />
      
      {/* Main Content Canvas */}
      <main className="pt-[88px] md:pl-[304px] px-page-padding pb-page-padding min-h-screen">
        <div className="max-w-[1440px] mx-auto">
          <Outlet />
        </div>
      </main>
    </div>
  );
};

export default AppLayout;
