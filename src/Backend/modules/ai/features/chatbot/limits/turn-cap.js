/**
 * Trần chi phí một lượt hỏi, tính theo ngân sách tháng còn lại:
 *   trần = min(ceiling, max(floor, factor × còn lại ÷ (số ngày còn lại × số lượt mỗi ngày)))
 *
 * Lượt phức tạp ăn vào ngân sách nên các lượt sau có trần thấp dần và ngân sách tháng hết sớm hơn, tức số lượt tự thu
 * hẹp. `floor` giữ cho lượt thường không bị cắt: phần chia đều ×1,5 của ngân sách mặc định chỉ khoảng 1.000 µ$, thấp
 * hơn chi phí đo được của một lượt thường. Trần chỉ chặn việc mở thêm vòng công cụ, câu trả lời vẫn được sinh.
 */
function computeTurnCapMicroUsd({
  spentMicroUsd,
  monthlyBudgetMicroUsd,
  daysLeft,
  dailyPrompts,
  factor = 1.5,
  floor = 2000,
  ceiling = 12000,
}) {
  const remaining = Math.max(0, Number(monthlyBudgetMicroUsd) - Number(spentMicroUsd));
  const turnsLeft = Number(daysLeft) * Number(dailyPrompts);
  const share = turnsLeft > 0 ? (factor * remaining) / turnsLeft : 0;
  return Math.min(ceiling, Math.max(floor, Math.round(share)));
}

module.exports = { computeTurnCapMicroUsd };
