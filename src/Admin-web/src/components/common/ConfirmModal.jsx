import React, { useEffect } from 'react';

/**
 * ConfirmModal — Hộp thoại xác nhận hành động chuyên nghiệp & thân thiện
 * Hỗ trợ các hành động Cảnh báo / Nguy hiểm (Đỏ) và Xác nhận / Kích hoạt (Xanh Emerald)
 * Sử dụng 100% Tailwind CSS classes chuẩn, khắc phục triệt để lỗi CSS variables bị rỗng.
 */
const ConfirmModal = ({
  open,
  onConfirm,
  onCancel,
  title = 'Xác nhận',
  message = 'Bạn có chắc chắn muốn thực hiện hành động này?',
  confirmText = 'Xác nhận',
  cancelText = 'Hủy bỏ',
  confirmDanger = false,
  icon,
  loading = false,
}) => {
  // Đóng modal khi nhấn phím Escape
  useEffect(() => {
    if (!open) return;
    const handleKeyDown = (e) => {
      if (e.key === 'Escape' && !loading) {
        onCancel();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [open, loading, onCancel]);

  if (!open) return null;

  // Icon mặc định theo ngữ nghĩa
  const displayIcon = icon || (confirmDanger ? 'warning' : 'check_circle');

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="confirm-modal-title"
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs transition-opacity"
      onClick={loading ? undefined : onCancel}
    >
      <div
        className="bg-white rounded-2xl border border-slate-200/80 shadow-2xl max-w-md w-full p-6 space-y-4 transition-transform transform scale-100"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header với Icon và Nút Đóng */}
        <div className="flex items-start justify-between gap-3">
          <div className="flex items-center gap-3">
            <div
              className={`w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0 border ${
                confirmDanger
                  ? 'bg-red-50 text-red-600 border-red-200'
                  : 'bg-emerald-50 text-emerald-600 border-emerald-200'
              }`}
            >
              <span className="material-symbols-outlined text-[24px]">{displayIcon}</span>
            </div>
            <div>
              <h3
                id="confirm-modal-title"
                className="text-base font-bold text-slate-900 leading-snug m-0"
              >
                {title}
              </h3>
              <p className="text-[11px] font-medium text-slate-500 m-0 mt-0.5">
                Vui lòng xem kỹ thông tin trước khi tiếp tục
              </p>
            </div>
          </div>

          <button
            type="button"
            onClick={onCancel}
            disabled={loading}
            aria-label="Đóng popup"
            className="text-slate-400 hover:text-slate-600 p-1 rounded-lg hover:bg-slate-100 transition-colors cursor-pointer disabled:opacity-50"
          >
            <span className="material-symbols-outlined text-[20px]">close</span>
          </button>
        </div>

        {/* Nội dung thông điệp chi tiết */}
        <div className="bg-slate-50/80 border border-slate-200/60 rounded-xl p-3.5 text-xs text-slate-700 leading-relaxed">
          {message}
        </div>

        {/* Footer Actions: Hủy bỏ & Xác nhận rõ ràng */}
        <div className="flex items-center justify-end gap-2.5 pt-2 border-t border-slate-100">
          <button
            type="button"
            onClick={onCancel}
            disabled={loading}
            className="px-4 py-2 text-xs font-semibold text-slate-700 bg-white hover:bg-slate-100 active:bg-slate-200 border border-slate-300 rounded-xl transition-all shadow-2xs cursor-pointer disabled:opacity-50"
          >
            {cancelText}
          </button>

          <button
            type="button"
            onClick={onConfirm}
            disabled={loading}
            className={`px-4 py-2 text-xs font-semibold text-white rounded-xl transition-all shadow-xs cursor-pointer flex items-center gap-1.5 disabled:opacity-70 ${
              confirmDanger
                ? 'bg-red-600 hover:bg-red-700 active:bg-red-800'
                : 'bg-emerald-600 hover:bg-emerald-700 active:bg-emerald-800'
            }`}
          >
            {loading ? (
              <>
                <span className="material-symbols-outlined text-[15px] animate-spin">progress_activity</span>
                <span>Đang xử lý...</span>
              </>
            ) : (
              <>
                <span className="material-symbols-outlined text-[15px]">
                  {confirmDanger ? 'check' : 'verified'}
                </span>
                <span>{confirmText}</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
};

export default ConfirmModal;
