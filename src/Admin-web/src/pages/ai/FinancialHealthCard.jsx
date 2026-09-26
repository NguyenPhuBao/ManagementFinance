import React from 'react';

/**
 * Thẻ hiển thị Điểm Sức khỏe Tài chính FHS và Phân bổ 50/30/20
 * @param {Object} props
 * @param {Object} props.fhs - Dữ liệu FHS từ snapshot
 * @param {boolean} [props.loading] - Trạng thái đang tải
 */
const FinancialHealthCard = ({ fhs, loading }) => {
  if (loading) {
    return (
      <div className="bg-white rounded-2xl p-5 shadow-sm border border-outline-variant animate-pulse">
        <div className="h-6 bg-gray-200 rounded w-1/2 mb-4"></div>
        <div className="h-16 bg-gray-200 rounded-xl mb-4"></div>
        <div className="h-4 bg-gray-200 rounded w-3/4"></div>
      </div>
    );
  }

  if (!fhs) {
    return (
      <div className="bg-white rounded-2xl p-5 shadow-sm border border-outline-variant text-center">
        <span className="material-symbols-outlined text-4xl text-gray-400 mb-2">vital_signs</span>
        <h4 className="font-semibold text-gray-700">Chưa có chỉ số FHS</h4>
        <p className="text-xs text-gray-500 mt-1">
          Hỏi chatbot để hệ thống quét dữ liệu và chấm điểm sức khỏe tài chính.
        </p>
      </div>
    );
  }

  const { score = 0, classification = 'Chưa xác định', metrics = {} } = fhs;
  const ratio50_30_20 = metrics.ratio50_30_20 || { needs: 0, wants: 0, savings: 0 };
  const emergencyMonths = metrics.emergencyFundMonths || 0;
  const debtRatio = metrics.debtToIncomeRatio || 0;

  // Màu sắc theo thang điểm FHS
  let badgeColor = 'bg-blue-100 text-blue-800 border-blue-200';
  let scoreColor = 'text-blue-600';
  let gaugeGradient = 'from-blue-500 to-indigo-600';

  if (score >= 80) {
    badgeColor = 'bg-emerald-100 text-emerald-800 border-emerald-200';
    scoreColor = 'text-emerald-600';
    gaugeGradient = 'from-emerald-500 to-teal-600';
  } else if (score >= 60) {
    badgeColor = 'bg-amber-100 text-amber-800 border-amber-200';
    scoreColor = 'text-amber-600';
    gaugeGradient = 'from-amber-500 to-orange-500';
  } else {
    badgeColor = 'bg-rose-100 text-rose-800 border-rose-200';
    scoreColor = 'text-rose-600';
    gaugeGradient = 'from-rose-500 to-red-600';
  }

  return (
    <div className="bg-white rounded-2xl p-5 shadow-sm border border-outline-variant hover:shadow-md transition-shadow">
      {/* Tiêu đề & Badge */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <span className="material-symbols-outlined text-primary text-xl">favorite</span>
          <h3 className="font-bold text-gray-800 text-sm uppercase tracking-wide">
            Sức Khỏe Tài Chính (FHS)
          </h3>
        </div>
        <span className={`px-2.5 py-0.5 rounded-full text-xs font-semibold border ${badgeColor}`}>
          {classification}
        </span>
      </div>

      {/* Điểm số vĩ mô */}
      <div className="flex items-baseline gap-2 mb-4 bg-gray-50 p-3 rounded-xl">
        <span className={`text-4xl font-black ${scoreColor}`}>{score}</span>
        <span className="text-gray-400 font-medium text-sm">/ 100 điểm</span>
      </div>

      {/* Cơ cấu phân bổ 50/30/20 */}
      <div className="space-y-2 mb-4">
        <div className="flex justify-between text-xs font-medium text-gray-600">
          <span>Quy tắc 50/30/20</span>
          <span>{ratio50_30_20.needs}% / {ratio50_30_20.wants}% / {ratio50_30_20.savings}%</span>
        </div>
        <div className="w-full h-3 rounded-full bg-gray-100 overflow-hidden flex">
          <div
            style={{ width: `${Math.min(ratio50_30_20.needs, 100)}%` }}
            className="bg-indigo-500 h-full transition-all"
            title={`Thiết yếu: ${ratio50_30_20.needs}% (Chuẩn: 50%)`}
          />
          <div
            style={{ width: `${Math.min(ratio50_30_20.wants, 100)}%` }}
            className="bg-amber-400 h-full transition-all"
            title={`Linh hoạt: ${ratio50_30_20.wants}% (Chuẩn: 30%)`}
          />
          <div
            style={{ width: `${Math.min(ratio50_30_20.savings, 100)}%` }}
            className="bg-emerald-500 h-full transition-all"
            title={`Tiết kiệm: ${ratio50_30_20.savings}% (Chuẩn: 20%)`}
          />
        </div>
        <div className="flex justify-between text-[10px] text-gray-400 pt-0.5">
          <span className="flex items-center gap-1">
            <span className="w-2 h-2 rounded-full bg-indigo-500 inline-block" /> Thiết yếu
          </span>
          <span className="flex items-center gap-1">
            <span className="w-2 h-2 rounded-full bg-amber-400 inline-block" /> Linh hoạt
          </span>
          <span className="flex items-center gap-1">
            <span className="w-2 h-2 rounded-full bg-emerald-500 inline-block" /> Tích lũy
          </span>
        </div>
      </div>

      {/* Chỉ số phụ */}
      <div className="grid grid-cols-2 gap-2 pt-2 border-t border-gray-100 text-xs">
        <div className="bg-gray-50 p-2.5 rounded-lg">
          <div className="text-gray-400 text-[11px] mb-0.5">Quỹ khẩn cấp</div>
          <div className="font-bold text-gray-700 flex items-center gap-1">
            <span className="material-symbols-outlined text-sm text-primary">shield</span>
            {emergencyMonths} tháng
          </div>
        </div>
        <div className="bg-gray-50 p-2.5 rounded-lg">
          <div className="text-gray-400 text-[11px] mb-0.5">Tỷ lệ Nợ/Thu nhập</div>
          <div className="font-bold text-gray-700 flex items-center gap-1">
            <span className="material-symbols-outlined text-sm text-rose-500">credit_card</span>
            {debtRatio}%
          </div>
        </div>
      </div>
    </div>
  );
};

export default FinancialHealthCard;
