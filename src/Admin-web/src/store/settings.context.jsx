import React, { createContext, useContext, useState, useEffect, useCallback, useRef } from 'react';
import { STORAGE_KEYS } from '../utils/constants';
import authApi from '../api/auth.api';

export const DEFAULT_SETTINGS = {
  theme: 'light', // 'light' | 'dark'
  tableDensity: 'comfortable', // 'comfortable' | 'compact'
  soundEnabled: true,
  toastDuration: 4500, // ms: 3000 | 4500 | 7000 | 10000
  showUnreadBadge: true,
  metricsInterval: 3, // seconds: 1 | 3 | 5 | 10
  autoLockMinutes: 30, // minutes: 15 | 30 | 60 | 0
};

const SETTINGS_STORAGE_KEY = 'admin_system_settings';

const SettingsContext = createContext(null);

export const SettingsProvider = ({ children }) => {
  const [settings, setSettings] = useState(() => {
    try {
      const saved = localStorage.getItem(SETTINGS_STORAGE_KEY);
      return saved ? { ...DEFAULT_SETTINGS, ...JSON.parse(saved) } : DEFAULT_SETTINGS;
    } catch (_) {
      return DEFAULT_SETTINGS;
    }
  });

  const [isLocked, setIsLocked] = useState(() => {
    try {
      if (typeof localStorage === 'undefined') return false;
      // 1. Nếu đã bị khóa từ trước (persist)
      if (localStorage.getItem(STORAGE_KEYS.IS_LOCKED) === 'true') {
        return true;
      }
      // 2. Kiểm tra nếu thời gian offline/nhàn rỗi vượt quá ngưỡng autoLockMinutes
      const savedSettingsRaw = localStorage.getItem(SETTINGS_STORAGE_KEY);
      const currentAutoLock = savedSettingsRaw ? JSON.parse(savedSettingsRaw).autoLockMinutes : DEFAULT_SETTINGS.autoLockMinutes;
      const lastActive = Number(localStorage.getItem(STORAGE_KEYS.LAST_ACTIVE_AT) || 0);
      const hasTokens = Boolean(localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN) || localStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN));

      if (hasTokens && currentAutoLock > 0 && lastActive > 0) {
        const awayMs = Date.now() - lastActive;
        if (awayMs >= currentAutoLock * 60 * 1000) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  });

  const [lockedAt, setLockedAt] = useState(() => {
    try {
      if (typeof localStorage === 'undefined') return null;
      return localStorage.getItem(STORAGE_KEYS.LOCKED_AT) || null;
    } catch (_) {
      return null;
    }
  });

  const [pingLatency, setPingLatency] = useState(null); // ms
  const [isPinging, setIsPinging] = useState(false);
  const leftAtRef = useRef(null);

  // Đảm bảo token bị tiêu hủy khi isLocked được kích hoạt
  useEffect(() => {
    if (isLocked) {
      try {
        if (!localStorage.getItem(STORAGE_KEYS.LOCKED_USER)) {
          const rawUser = localStorage.getItem(STORAGE_KEYS.USER);
          if (rawUser) {
            const u = JSON.parse(rawUser);
            localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify({
              fullname: u.fullname,
              username: u.username,
              email: u.email,
              idrole: u.idrole,
              rolename: u.rolename,
            }));
          }
        }
        // XÓA SẠCH TOKEN XÁC THỰC
        localStorage.removeItem(STORAGE_KEYS.ACCESS_TOKEN);
        localStorage.removeItem(STORAGE_KEYS.REFRESH_TOKEN);
        localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
        if (!localStorage.getItem(STORAGE_KEYS.LOCKED_AT)) {
          const timeStr = new Date().toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' });
          localStorage.setItem(STORAGE_KEYS.LOCKED_AT, timeStr);
          setLockedAt(timeStr);
        }
      } catch (_) {}
    }
  }, [isLocked]);

  // 1. Cập nhật một cấu hình cài đặt đơn lẻ
  const updateSetting = useCallback((key, value) => {
    setSettings((prev) => {
      const updated = { ...prev, [key]: value };
      try {
        localStorage.setItem(SETTINGS_STORAGE_KEY, JSON.stringify(updated));
      } catch (_) {}
      return updated;
    });
  }, []);

  // 2. Khôi phục toàn bộ cài đặt về mặc định chuẩn
  const resetSettings = useCallback(() => {
    setSettings(DEFAULT_SETTINGS);
    try {
      localStorage.setItem(SETTINGS_STORAGE_KEY, JSON.stringify(DEFAULT_SETTINGS));
    } catch (_) {}
  }, []);

  // 3. Side-effect: Áp dụng Theme Mode (Sáng / Tối)
  useEffect(() => {
    if (typeof document === 'undefined') return;
    const root = document.documentElement;

    const applyThemeClasses = (isDark) => {
      if (isDark) {
        root.classList.add('dark');
        root.setAttribute('data-theme', 'dark');
      } else {
        root.classList.remove('dark');
        root.setAttribute('data-theme', 'light');
      }
    };

    applyThemeClasses(settings.theme === 'dark');
  }, [settings.theme]);

  // 4. Side-effect: Áp dụng Table Density lên body
  useEffect(() => {
    if (typeof document === 'undefined') return;
    document.body.setAttribute('data-density', settings.tableDensity);
  }, [settings.tableDensity]);

  // 5. Inactivity Watcher: Tự động khóa màn hình an toàn khi không mở website (rời khỏi trang / chuyển tab / nhàn rỗi)
  const lockScreen = useCallback(() => {
    try {
      const timeStr = new Date().toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' });

      // 1. Snapshot thông tin hiển thị an toàn cho LockScreenModal (nếu có user)
      const rawUser = localStorage.getItem(STORAGE_KEYS.USER);
      if (rawUser) {
        try {
          const u = JSON.parse(rawUser);
          localStorage.setItem(STORAGE_KEYS.LOCKED_USER, JSON.stringify({
            fullname: u.fullname,
            username: u.username,
            email: u.email,
            idrole: u.idrole,
            rolename: u.rolename,
          }));
        } catch (_) {}
      }

      // 2. TIÊU HỦY SẠCH 100% JWT TOKENS KHỎI TRÌNH DUYỆT
      localStorage.removeItem(STORAGE_KEYS.ACCESS_TOKEN);
      localStorage.removeItem(STORAGE_KEYS.REFRESH_TOKEN);

      // 3. Đánh dấu trạng thái khóa bền vững vào localStorage
      localStorage.setItem(STORAGE_KEYS.IS_LOCKED, 'true');
      localStorage.setItem(STORAGE_KEYS.LOCKED_AT, timeStr);

      setIsLocked(true);
      setLockedAt(timeStr);
    } catch (_) {}
  }, []);

  const unlockScreen = useCallback(async (password) => {
    const rawUser = localStorage.getItem(STORAGE_KEYS.LOCKED_USER) || localStorage.getItem(STORAGE_KEYS.USER);
    if (!rawUser) {
      setIsLocked(false);
      localStorage.removeItem(STORAGE_KEYS.IS_LOCKED);
      localStorage.removeItem(STORAGE_KEYS.LOCKED_AT);
      return true;
    }
    const user = JSON.parse(rawUser);
    const username = user.username || user.email;

    // 1. Xác thực lại với backend bằng mật khẩu thực tế
    const res = await authApi.login({ username, password });
    const data = res?.data?.data || res?.data || res;
    const { accessToken, refreshToken, user: userData } = data;

    if (!accessToken) {
      throw new Error('Không nhận được mã xác thực sau khi đăng nhập');
    }

    // 2. Lưu lại bộ Token mới vào localStorage
    localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, accessToken);
    if (refreshToken) {
      localStorage.setItem(STORAGE_KEYS.REFRESH_TOKEN, refreshToken);
    }
    if (userData) {
      localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(userData));
    }

    // 3. Xóa sạch cờ khóa và phục hồi trạng thái bình thường
    localStorage.removeItem(STORAGE_KEYS.IS_LOCKED);
    localStorage.removeItem(STORAGE_KEYS.LOCKED_AT);
    localStorage.removeItem(STORAGE_KEYS.LOCKED_USER);
    localStorage.setItem(STORAGE_KEYS.LAST_ACTIVE_AT, String(Date.now()));

    setIsLocked(false);
    setLockedAt(null);
    leftAtRef.current = null;
    return true;
  }, []);

  useEffect(() => {
    if (typeof window === 'undefined' || typeof document === 'undefined') return;

    // Cập nhật timestamp hoạt động liên tục (Throttled 5s)
    let lastRecorded = 0;
    const recordUserActivity = () => {
      const now = Date.now();
      if (now - lastRecorded > 5000) {
        lastRecorded = now;
        try {
          localStorage.setItem(STORAGE_KEYS.LAST_ACTIVE_AT, String(now));
        } catch (_) {}
      }
    };

    // Khởi tạo mốc hoạt động đầu tiên nếu chưa có
    if (!localStorage.getItem(STORAGE_KEYS.LAST_ACTIVE_AT)) {
      localStorage.setItem(STORAGE_KEYS.LAST_ACTIVE_AT, String(Date.now()));
    }

    const activityEvents = ['pointerdown', 'keydown', 'scroll', 'touchstart'];
    activityEvents.forEach((evt) => window.addEventListener(evt, recordUserActivity, { passive: true }));

    if (settings.autoLockMinutes <= 0) {
      return () => {
        activityEvents.forEach((evt) => window.removeEventListener(evt, recordUserActivity));
      };
    }

    const lockThresholdMs = settings.autoLockMinutes * 60 * 1000;

    const handleVisibilityChange = () => {
      const now = Date.now();
      if (document.hidden) {
        // Người dùng đã rời khỏi website (chuyển sang tab khác, ẩn trình duyệt)
        leftAtRef.current = now;
        try {
          localStorage.setItem(STORAGE_KEYS.LAST_ACTIVE_AT, String(now));
        } catch (_) {}
      } else {
        // Người dùng quay lại website: kiểm tra xem đã rời đi bao lâu
        const lastActive = Number(localStorage.getItem(STORAGE_KEYS.LAST_ACTIVE_AT) || leftAtRef.current || now);
        const awayDuration = now - lastActive;
        leftAtRef.current = null;
        if (awayDuration >= lockThresholdMs && !isLocked) {
          lockScreen();
        } else {
          recordUserActivity();
        }
      }
    };

    // Định kỳ kiểm tra trong trường hợp tab đang ở background hoặc nhàn rỗi quá ngưỡng
    const checkInterval = setInterval(() => {
      if (isLocked) return;
      const lastActive = Number(localStorage.getItem(STORAGE_KEYS.LAST_ACTIVE_AT) || Date.now());
      const awayDuration = Date.now() - lastActive;
      if (awayDuration >= lockThresholdMs) {
        lockScreen();
      }
    }, 5000);

    document.addEventListener('visibilitychange', handleVisibilityChange);

    return () => {
      activityEvents.forEach((evt) => window.removeEventListener(evt, recordUserActivity));
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      clearInterval(checkInterval);
    };
  }, [settings.autoLockMinutes, isLocked, lockScreen]);

  // 6. Tính năng đo độ trễ Socket (Ping Latency Test)
  const testPingLatency = useCallback(async (socket) => {
    if (!socket || !socket.connected) {
      setPingLatency(-1);
      return -1;
    }

    setIsPinging(true);
    const start = performance.now();

    return new Promise((resolve) => {
      // Backend core/socket.js đã hỗ trợ event 'admin_ping'
      socket.timeout(5000).emit('admin_ping', (err) => {
        setIsPinging(false);
        if (err) {
          setPingLatency(-1);
          resolve(-1);
        } else {
          const latency = Math.max(1, Math.round(performance.now() - start));
          setPingLatency(latency);
          resolve(latency);
        }
      });
    });
  }, []);

  // 7. Dọn dẹp an toàn bộ nhớ đệm (Safe Cache Clear)
  const safeClearCache = useCallback(() => {
    try {
      if (typeof sessionStorage !== 'undefined') {
        sessionStorage.clear();
      }
      if (typeof window !== 'undefined' && 'caches' in window) {
        window.caches.keys().then((names) => {
          names.forEach((name) => window.caches.delete(name));
        }).catch(() => {});
      }
    } catch (_) {}

    const protectedKeys = [
      STORAGE_KEYS.ACCESS_TOKEN,
      STORAGE_KEYS.REFRESH_TOKEN,
      STORAGE_KEYS.USER,
      STORAGE_KEYS.IS_LOCKED,
      STORAGE_KEYS.LOCKED_AT,
      STORAGE_KEYS.LOCKED_USER,
      STORAGE_KEYS.LAST_ACTIVE_AT,
      'access_token',
      'refresh_token',
      'user',
      SETTINGS_STORAGE_KEY,
      'theme',
    ];
    const backup = {};
    protectedKeys.forEach((key) => {
      const val = localStorage.getItem(key);
      if (val !== null) backup[key] = val;
    });

    localStorage.clear();

    Object.entries(backup).forEach(([key, val]) => {
      localStorage.setItem(key, val);
    });

    return true;
  }, []);

  // 8. Tính toán dung lượng lưu trữ cục bộ
  const getStorageUsageKb = useCallback(() => {
    try {
      let total = 0;
      for (let x in localStorage) {
        if (localStorage.hasOwnProperty(x)) {
          total += (localStorage[x].length + x.length) * 2;
        }
      }
      return (total / 1024).toFixed(1);
    } catch (_) {
      return '0.0';
    }
  }, []);

  const value = {
    settings,
    updateSetting,
    resetSettings,
    isLocked,
    lockedAt,
    lockScreen,
    unlockScreen,
    pingLatency,
    isPinging,
    testPingLatency,
    safeClearCache,
    getStorageUsageKb,
  };

  return <SettingsContext.Provider value={value}>{children}</SettingsContext.Provider>;
};

export const useSettings = () => {
  const ctx = useContext(SettingsContext);
  if (!ctx) {
    return {
      settings: DEFAULT_SETTINGS,
      updateSetting: () => {},
      resetSettings: () => {},
      isLocked: false,
      lockedAt: null,
      lockScreen: () => {},
      unlockScreen: async () => true,
      pingLatency: null,
      isPinging: false,
      testPingLatency: async () => 0,
      safeClearCache: () => {},
      getStorageUsageKb: () => '0.0',
    };
  }
  return ctx;
};

export const useSettingsSafe = () => {
  return useSettings();
};

export default SettingsContext;
