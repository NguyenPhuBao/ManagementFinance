import React, { useState, useEffect } from 'react';
import { Outlet, useNavigate } from 'react-router-dom';
import AppSidebar from './Sidebar';
import AppHeader from './Header';
import useSocket from '../../hooks/useSocket';
import aiopsApi from '../../api/aiops.api';
import adminApi from '../../api/admin.api';

const AppLayout = () => {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(true);
  const [threatAlert, setThreatAlert] = useState(null);
  const [dismissed, setDismissed] = useState(false);
  const [mitigating, setMitigating] = useState(false);
  const [mitigatedSuccess, setMitigatedSuccess] = useState(false);

  const navigate = useNavigate();
  const socket = useSocket();

  const toggleSidebar = () => setSidebarCollapsed(prev => !prev);

  // Kiểm tra trạng thái AIOps ban đầu và định kỳ
  const checkThreatStatus = async () => {
    try {
      const res = await aiopsApi.getStatus();
      const data = res?.data || res;
      if (data && data.threatScore >= 85) {
        setThreatAlert(data);
      } else {
        setThreatAlert(null);
        setDismissed(false);
      }
    } catch (_) {}
  };

  useEffect(() => {
    checkThreatStatus();
    const interval = setInterval(checkThreatStatus, 15000);
    return () => clearInterval(interval);
  }, []);

  const [blockedToast, setBlockedToast] = useState(null);

  // Lắng nghe sự kiện Socket.io thời gian thực
  useEffect(() => {
    if (!socket) return;

    const handleSocketAlert = (data) => {
      if (data && data.threatScore >= 85) {
        setThreatAlert(data);
        setDismissed(false);
      } else if (data && data.threatScore < 70) {
        setThreatAlert(null);
      }
    };

    const handleSecurityBlocked = (data) => {
      setBlockedToast(data);
      setTimeout(() => setBlockedToast(null), 7000);
    };

    socket.on('admin.security_alert', handleSocketAlert);
    socket.on('admin.security_blocked', handleSecurityBlocked);
    return () => {
      socket.off('admin.security_alert', handleSocketAlert);
      socket.off('admin.security_blocked', handleSecurityBlocked);
    };
  }, [socket]);

  // Xử lý 1-click bảo trì khẩn cấp từ Banner
  const handleQuickMitigation = async () => {
    if (!window.confirm('Bật BẢO TRÌ KHẨN CẤP ngay lập tức để ngắt kết nối khách và bảo vệ hệ thống?')) return;
    try {
      setMitigating(true);
      await adminApi.setMaintenanceStatus({
        active: true,
        reason: 'Phòng vệ khẩn cấp AIOps Sentinel do phát hiện xâm nhập/quá tải',
        isEmergency: true,
      });
      setMitigatedSuccess(true);
      setTimeout(() => setDismissed(true), 3000);
    } catch (err) {
      alert('Kích hoạt bảo trì thất bại: ' + (err.response?.data?.message || err.message));
    } finally {
      setMitigating(false);
    }
  };

  const isAlertVisible = threatAlert && threatAlert.threatScore >= 85 && !dismissed;

  return (
    <div className="min-h-screen relative">
      {/* ─── GLOBAL AIOPS CRITICAL THREAT BANNER ─── */}
      {isAlertVisible && (
        <div className="fixed top-0 left-0 right-0 z-50 bg-red-600 text-white px-4 py-2.5 shadow-md flex items-center justify-between gap-3 border-b-2 border-red-800 text-xs">
          <div className="flex items-center gap-2.5">
            <span className="material-symbols-outlined text-[20px] animate-pulse text-amber-300">
              crisis_alert
            </span>
            <div>
              <span className="font-extrabold uppercase tracking-wide mr-1.5">
                🚨 BÁO ĐỘNG ĐỎ AIOPS SENTINEL:
              </span>
              <span>
                Phát hiện nguy cơ an ninh / sự cố nghiêm trọng! Threat Score: <b>{threatAlert.threatScore}/100</b>
                {threatAlert.anomalies?.length > 0 && ` (${threatAlert.anomalies[0].code})`}
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2 flex-shrink-0">
            {mitigatedSuccess ? (
              <span className="bg-white/20 text-white px-3 py-1 rounded-lg font-bold">
                ✓ ĐÃ KHÓA BẢO TRÌ KHẨN CẤP
              </span>
            ) : (
              <button
                onClick={handleQuickMitigation}
                disabled={mitigating}
                className="bg-white text-red-700 hover:bg-red-50 px-3 py-1 rounded-lg font-bold shadow-xs transition-colors cursor-pointer flex items-center gap-1"
              >
                <span className="material-symbols-outlined text-[15px]">lock</span>
                <span>{mitigating ? 'Đang khóa...' : '1-Click Khóa Bảo Trì'}</span>
              </button>
            )}

            <button
              onClick={() => navigate('/aiops')}
              className="bg-red-700 hover:bg-red-800 text-white px-3 py-1 rounded-lg font-semibold transition-colors cursor-pointer flex items-center gap-1 border border-red-500"
            >
              <span className="material-symbols-outlined text-[15px]">troubleshoot</span>
              <span>Xem Phân Tích</span>
            </button>

            <button
              onClick={() => setDismissed(true)}
              className="text-white/80 hover:text-white p-1 cursor-pointer"
              title="Tạm ẩn cảnh báo"
            >
              <span className="material-symbols-outlined text-[16px]">close</span>
            </button>
          </div>
        </div>
      )}

      <AppSidebar collapsed={sidebarCollapsed} />
      <AppHeader onMenuToggle={toggleSidebar} />
      
      {/* Main Content Canvas */}
      <main className={`${isAlertVisible ? 'pt-[130px]' : 'pt-[88px]'} md:pl-[304px] px-page-padding pb-page-padding min-h-screen transition-all duration-200`}>
        <div className="max-w-[1440px] mx-auto">
          <Outlet />
        </div>
      </main>

      {/* ─── REALTIME AUTO-QUARANTINE TOAST ─── */}
      {blockedToast && (
        <div className="fixed bottom-6 right-6 z-50 bg-slate-900 text-white rounded-2xl p-4 shadow-2xl border border-red-500/80 flex items-start gap-3 max-w-md animate-in slide-in-from-bottom-5 duration-200">
          <div className="w-9 h-9 rounded-xl bg-red-600/30 text-red-400 flex items-center justify-center flex-shrink-0 border border-red-500/40">
            <span className="material-symbols-outlined text-[20px]">shield</span>
          </div>
          <div className="flex-1 text-xs">
            <div className="flex items-center justify-between mb-1">
              <span className="font-bold text-red-400 uppercase tracking-wider">AIOps Đã Chặn Đứng Nguồn Tấn Công</span>
              <button onClick={() => setBlockedToast(null)} className="text-slate-400 hover:text-white cursor-pointer">
                <span className="material-symbols-outlined text-[14px]">close</span>
              </button>
            </div>
            <p className="text-slate-300 font-medium">
              IP: <b className="text-white font-mono">{blockedToast.maskedIp}</b> đã bị cắt kết nối.
            </p>
            <p className="text-slate-400 text-[11px] mt-0.5 line-clamp-2">
              Lý do: {blockedToast.reason}
            </p>
            <div className="mt-2.5 flex items-center gap-2">
              <button
                onClick={() => { setBlockedToast(null); navigate('/aiops'); }}
                className="text-red-400 hover:text-red-300 font-semibold underline text-[11px] cursor-pointer"
              >
                Xem danh sách cô lập &rarr;
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AppLayout;
