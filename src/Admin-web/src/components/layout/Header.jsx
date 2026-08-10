import React, { useState } from 'react';

const Header = ({ onMenuToggle }) => {
  const [showNotifications, setShowNotifications] = useState(false);

  return (
    <header className="fixed top-0 right-0 left-0 md:left-[280px] h-16 bg-surface border-b border-outline-variant flex items-center justify-between px-page-padding z-30">
      <div className="flex items-center gap-4">
        <button onClick={onMenuToggle} className="md:hidden text-on-surface hover:text-primary transition-colors">
          <span className="material-symbols-outlined">menu</span>
        </button>
        <div className="font-headline-sm text-headline-sm font-semibold text-on-surface md:hidden">Personal Finance Admin</div>
      </div>

      <div className="flex items-center gap-2 relative">
        <button 
          className="p-2 rounded-full text-on-surface-variant hover:bg-surface-container-low transition-all cursor-pointer active:opacity-80 relative"
          onClick={() => setShowNotifications(!showNotifications)}
        >
          <span className="material-symbols-outlined">notifications</span>
          <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-error rounded-full"></span>
        </button>
        
        {showNotifications && (
          <div className="absolute right-0 top-full mt-2 w-64 bg-white rounded-xl shadow-[0_12px_24px_rgba(11,28,48,0.1)] border border-outline-variant z-50">
            <div className="p-6 flex flex-col items-center justify-center gap-3 text-center">
              <span className="material-symbols-outlined text-secondary text-[32px] opacity-50">notifications_off</span>
              <p className="text-secondary font-body-md">Danh sách thông báo trống</p>
            </div>
          </div>
        )}
        
        <div className="ml-2 w-8 h-8 rounded-full bg-secondary-container overflow-hidden border border-outline-variant flex-shrink-0">
          <img alt="Admin User Profile" className="w-full h-full object-cover" src="https://lh3.googleusercontent.com/aida-public/AB6AXuDoaRQFFasB3oo7h6BMWvwP3TbbgITuwpZ5a9CKkAOFy7XG6SLVrhi-Kdtks5RVbuhEkU1Ix7b1vbRyLZ-UQ14RqwpL32T2JmZYHhQTEueyBj-xnQyFXwiqKUdjdf-z-Fn3kvJuvGRbOiEQh6k8_tB4urRNnGPfDielXNVcw3DaKa6bgObMYp5KsZVt29Af3EGHiU-Qzv4WsBRvJk6d47l9PqDJ3QWHRVm6Ga-Za6MuHnjNHcBRa9mH" />
        </div>
      </div>
    </header>
  );
};

export default Header;
