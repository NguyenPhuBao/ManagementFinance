import React, { useState } from 'react';
import notificationApi from '../../api/notification.api';

const LEVELS = [
  { value: 'info', label: 'INFO — Thông báo thường', color: 'text-blue-500', icon: 'info' },
  { value: 'warning', label: 'WARNING — Cảnh báo', color: 'text-amber-500', icon: 'warning' },
  { value: 'critical', label: 'CRITICAL — Khẩn cấp', color: 'text-red-500', icon: 'error' },
];

const BroadcastPage = () => {
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [level, setLevel] = useState('info');
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState(null);

  const handleSend = async (e) => {
    e.preventDefault();
    if (!title.trim() || !message.trim()) return;
    setSending(true);
    setResult(null);
    try {
      await notificationApi.broadcastToAll({ title: title.trim(), message: message.trim(), level });
      setResult({ ok: true, msg: 'Đã phát thông báo tới toàn bộ người dùng đang online!' });
      setTitle('');
      setMessage('');
      setLevel('info');
    } catch (e) {
      setResult({ ok: false, msg: e.response?.data?.message || 'Gửi thất bại. Thử lại sau.' });
    } finally {
      setSending(false);
    }
  };

  const selected = LEVELS.find((l) => l.value === level);

  return (
    <div className="max-w-[1440px] mx-auto w-full p-4 md:p-6 space-y-6 bg-surface-bright min-h-full">
      <div className="max-w-2xl mx-auto space-y-6">
        <div>
          <h1 className="font-display-md text-display-md font-bold text-on-surface m-0 tracking-tight flex items-center gap-2">
            <span className="material-symbols-outlined text-primary text-[28px]">campaign</span>
            Phát Thông Báo Hệ Thống
          </h1>
          <p className="font-body-md text-on-surface-variant mt-1">
            Gửi thông báo realtime tới toàn bộ người dùng đang kết nối qua Socket.io
          </p>
        </div>

        <form onSubmit={handleSend} className="bg-white rounded-xl border border-outline-variant shadow-sm p-6 space-y-5">
          <div>
            <label className="block text-xs font-bold text-on-surface uppercase tracking-wider mb-2">
              Mức độ ưu tiên
            </label>
            <div className="grid grid-cols-3 gap-3">
              {LEVELS.map((l) => (
                <button
                  key={l.value}
                  type="button"
                  onClick={() => setLevel(l.value)}
                  className={`flex items-center justify-center gap-2 p-3 rounded-lg border-2 transition-all cursor-pointer font-medium text-xs ${
                    level === l.value
                      ? 'border-primary bg-primary/5 text-primary shadow-xs font-bold'
                      : 'border-outline-variant hover:border-gray-300 text-on-surface-variant'
                  }`}
                >
                  <span className={`material-symbols-outlined text-[18px] ${l.color}`}>{l.icon}</span>
                  <span>{l.value.toUpperCase()}</span>
                </button>
              ))}
            </div>
            <p className="text-xs text-on-surface-variant mt-1.5">{selected?.label}</p>
          </div>

          <div>
            <label className="block text-xs font-bold text-on-surface uppercase tracking-wider mb-1.5">
              Tiêu đề <span className="text-red-500">*</span>
            </label>
            <input
              id="broadcast-title"
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              maxLength={120}
              placeholder="Ví dụ: Lịch bảo trì nâng cấp hệ thống tối nay..."
              className="w-full border border-outline-variant rounded-lg px-3.5 py-2.5 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
              required
            />
            <p className="text-[11px] text-on-surface-variant text-right mt-1">{title.length}/120 ký tự</p>
          </div>

          <div>
            <label className="block text-xs font-bold text-on-surface uppercase tracking-wider mb-1.5">
              Nội dung thông báo <span className="text-red-500">*</span>
            </label>
            <textarea
              id="broadcast-message"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              rows={4}
              maxLength={500}
              placeholder="Mô tả chi tiết nội dung cần thông báo tới người dùng..."
              className="w-full border border-outline-variant rounded-lg px-3.5 py-2.5 text-xs text-on-surface focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary resize-none"
              required
            />
            <p className="text-[11px] text-on-surface-variant text-right mt-1">{message.length}/500 ký tự</p>
          </div>

          {/* Live Preview Box */}
          {(title || message) && (
            <div
              className={`rounded-lg border p-4 transition-colors ${
                level === 'critical'
                  ? 'border-red-300 bg-red-50 text-red-900'
                  : level === 'warning'
                  ? 'border-amber-300 bg-amber-50 text-amber-900'
                  : 'border-blue-300 bg-blue-50 text-blue-900'
              }`}
            >
              <div className="flex items-center gap-1.5 text-[11px] font-bold uppercase tracking-wider mb-1.5 opacity-75">
                <span className="material-symbols-outlined text-[15px]">{selected?.icon}</span>
                Xem trước giao diện người dùng
              </div>
              <p className="font-bold text-sm mb-1">{title || 'Tiêu đề thông báo...'}</p>
              <p className="text-xs whitespace-pre-wrap opacity-90">{message || 'Nội dung thông báo...'}</p>
            </div>
          )}

          {result && (
            <div
              className={`rounded-lg px-4 py-3 text-xs flex items-center gap-2 border font-medium ${
                result.ok ? 'bg-emerald-50 text-emerald-800 border-emerald-300' : 'bg-red-50 text-red-800 border-red-300'
              }`}
            >
              <span className="material-symbols-outlined text-[18px]">
                {result.ok ? 'check_circle' : 'cancel'}
              </span>
              <span>{result.msg}</span>
            </div>
          )}

          <button
            id="btn-send-broadcast"
            type="submit"
            disabled={sending || !title.trim() || !message.trim()}
            className="w-full bg-primary hover:bg-primary/90 disabled:bg-gray-300 disabled:cursor-not-allowed text-white font-semibold py-2.5 rounded-lg transition-colors cursor-pointer flex items-center justify-center gap-2 text-xs shadow-sm"
          >
            {sending ? (
              <>
                <span className="material-symbols-outlined animate-spin text-[16px]">progress_activity</span>
                Đang phát sóng thông báo...
              </>
            ) : (
              <>
                <span className="material-symbols-outlined text-[16px]">send</span>
                Phát Sóng Thông Báo Ngay
              </>
            )}
          </button>
        </form>

        <div className="bg-surface-container-low border border-outline-variant/60 rounded-xl p-4 text-xs text-on-surface-variant space-y-1.5">
          <p className="font-semibold text-on-surface flex items-center gap-1">
            <span className="material-symbols-outlined text-[15px] text-amber-600">info</span>
            Quy tắc vận hành phát thanh (System Broadcast)
          </p>
          <p>• Thông báo được gửi realtime tới các socket đang kết nối qua room chung.</p>
          <p>• Người dùng offline sẽ nhìn thấy thông báo khi tải lại trang hoặc đăng nhập sau.</p>
          <p>• Thông báo phát sóng sẽ được ghi vào hộp thư cảnh báo của quản trị viên.</p>
        </div>
      </div>
    </div>
  );
};

export default BroadcastPage;
