/**
 * Chuẩn hoá chiều dòng tiền của một giao dịch trước khi đưa lên LLM.
 *
 * Quy ước dự án: `amount` ở PostgreSQL mang dấu (+ nhận tiền, − chi tiền). Ở đây:
 *   - `Type = Transfer` (chuyển giữa các ví của chính người dùng) → `transfer`, không tính thu chi.
 *   - `Classify = Vay/no` (cột bị CHECK 3 giá trị Thu | Chi | Vay/no, nên mọi danh mục vay nợ người dùng
 *     thêm sau này đều mang giá trị này) → `debt_in` (nhận tiền: đi vay, thu nợ) / `debt_out` (chuyển tiền:
 *     cho vay, trả nợ). Tên danh mục được gửi kèm để LLM đọc sắc thái.
 *   - còn lại: dấu + → `income`, dấu − → `expense`.
 * `amount` trả ra luôn dương (giá trị tuyệt đối).
 */

function normalizeFlow({ amount, type, classify }) {
  const raw = Number(amount) || 0;
  const abs = Math.abs(raw);

  if (type === 'Transfer') return { direction: 'transfer', amount: abs };
  if (classify === 'Vay/no') return { direction: raw >= 0 ? 'debt_in' : 'debt_out', amount: abs };
  return { direction: raw > 0 ? 'income' : 'expense', amount: abs };
}

module.exports = { normalizeFlow };
