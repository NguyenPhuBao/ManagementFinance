/// Thanh chọn chiều và khối số tiền lớn của màn Thêm giao dịch — tách từ `_buildSegmentControl` / `_buildSegmentButton` /
/// `_buildAmountDisplay` ngày 2026-10-10 (spec bịt điểm rò mục 5.2). Trạng thái ở lại trang.
library;

import 'package:flutter/material.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/ban_phim_so_tien.dart';
import '../so_tien_lon.dart';

class ThanhChonChieu extends StatelessWidget {
  const ThanhChonChieu({super.key, required this.huong, required this.onChon});

  final String huong;
  final ValueChanged<String> onChon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _nut('chi', 'Chi tiêu', AppColors.expense)),
          Expanded(child: _nut('thu', 'Thu nhập', AppColors.income)),
          Expanded(child: _nut('transfer', 'Chuyển khoản', AppColors.primary)),
        ],
      ),
    );
  }

  /// Màu đoạn đang chọn theo màn Stitch: Chi tiêu đỏ, Thu nhập xanh, Chuyển
  /// khoản đen.
  Widget _nut(String huong, String title, Color mau) {
    final isSelected = this.huong == huong;
    final bgColor = isSelected ? mau : Colors.transparent;
    final textColor = isSelected ? Colors.white : AppColors.textSecondary;

    return GestureDetector(
      key: Key('transaction-type-$huong'),
      onTap: () => onChon(huong),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class KhoiSoTien extends StatelessWidget {
  const KhoiSoTien({
    super.key,
    required this.chuoiSoTien,
    required this.chuHienThi,
    required this.mau,
    required this.hienBanPhimSo,
    required this.onCham,
  });

  final String chuoiSoTien;
  final String chuHienThi;
  final Color mau;
  final bool hienBanPhimSo;
  final VoidCallback onCham;

  @override
  Widget build(BuildContext context) {
    final coPhepToan = coPhepToanDangCho(chuoiSoTien);
    // Gợi ý chỉ khi 16 phím ẩn THEO CỜ (Stitch `b52c0651…` — "Bàn phím ẩn khi đã có số tiền"); biểu thức gõ dở thì dòng
    // `= tổng` quan trọng hơn — đó là chỗ duy nhất tổng hiện ra trước khi lưu.
    final goiYCham = !hienBanPhimSo && !coPhepToan;
    return GestureDetector(
      key: const Key('so-tien-cham'),
      behavior: HitTestBehavior.opaque,
      onTap: onCham,
      child: Column(
        children: [
          // ⚠️ Không dựng `Text` trần ở đây. Ở cỡ 48 trên 411dp, con số dài nhất
          // mà bàn phím cho gõ (`9.999.999.999.999đ`) NGẮT THÀNH HAI DÒNG và đẩy
          // cả màn xuống — không sọc vàng, không exception, chỉ là bố cục xấu
          // mà widget test dựng-ở-1280px không thấy. Xem `SoTienLon`.
          SoTienLon(chu: chuHienThi, mau: mau),
          const SizedBox(height: 8),
          // ⚠️ Lưới Stitch KHÔNG có phím `=`, nên ✓ vừa rút gọn vừa lưu trong
          // một nhịp. Dòng này là chỗ DUY NHẤT tổng hiện ra được trước khi giao
          // dịch được ghi — thiếu nó là người dùng bấm lưu một con số chưa từng
          // nhìn thấy. Toán tử lẻ ở cuối thì chưa có gì để rút gọn, giữ nhãn cũ.
          if (goiYCham)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, size: 14, color: AppColors.outline),
                SizedBox(width: 4),
                Text(
                  'Chạm để sửa số tiền',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.outline),
                ),
              ],
            )
          else
            Text(
              coPhepToan ? '= ${CurrencyFormatter.format(ketQuaBieuThuc(chuoiSoTien))}' : 'VNĐ - VIỆT NAM ĐỒNG',
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.outline,
              ),
            ),
        ],
      ),
    );
  }
}
