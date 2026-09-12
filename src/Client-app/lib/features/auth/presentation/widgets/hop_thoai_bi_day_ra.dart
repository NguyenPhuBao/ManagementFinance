import 'package:flutter/material.dart';

import '../../../../core/auth/buoc_dang_xuat.dart';
import '../../../../shared/theme/app_colors.dart';

/// Hộp thoại "bạn đã bị đăng xuất, và đây là lý do" — spec cưỡng chế đăng xuất
/// §5.1.
///
/// Hình theo màn Stitch `97dd48e7154446168767cf80480bff85` *"Đăng nhập - Tài
/// khoản bị vô hiệu hoá - FlowMoney"*; tên lớp Tailwind ghi cạnh từng chỗ để
/// lần sau đối chiếu. ⚠️ Stitch dựng màn ấy ở khung **máy tính** dù yêu cầu là
/// mobile — chỉ lấy **hộp thoại** làm chuẩn, nó là lớp nổi nên không phụ thuộc
/// khung; chiều rộng thật trên máy là `Dialog` mặc định trong 411dp.
///
/// Người dùng chọn hình thức này thay cho thẻ cảnh báo trên form (mục 2, Q3):
/// lý do bị đẩy ra là thứ phải đọc, nên phải bấm "Đã hiểu" mới đóng được.
class HopThoaiBiDayRa extends StatelessWidget {
  const HopThoaiBiDayRa({super.key, required this.thongBao});

  final ThongBaoBuocDangXuat thongBao;

  /// Stitch `text-[#454743]` cho thân. **Không** dùng `AppColors.onSurfaceVariant`
  /// — hằng ấy là bí danh của `textSecondary` (#767872), nhạt hơn hẳn và không
  /// đủ tương phản cho một đoạn văn 14px.
  static const _mauThan = Color(0xFF454743);

  bool get _daXoa => thongBao.lyDo == LyDoBuocDangXuat.daXoa;

  String get _tieuDe =>
      _daXoa ? 'Tài khoản đã bị xoá' : 'Tài khoản đã bị vô hiệu hoá';

  IconData get _bieuTuong => _daXoa ? Icons.delete_forever : Icons.block;

  /// Câu server gửi; rỗng thì câu mặc định theo lý do (§3.1 cố ý không đặt câu
  /// mặc định trong kiểu dữ liệu — nó phụ thuộc lý do và thuộc về giao diện).
  String get _than => thongBao.loiNhan.trim().isNotEmpty
      ? thongBao.loiNhan.trim()
      : (_daXoa
          ? 'Tài khoản của bạn đã bị xoá khỏi hệ thống.'
          : 'Tài khoản của bạn đã bị vô hiệu hoá.');

  @override
  Widget build(BuildContext context) {
    return Dialog(
      // Stitch: nền trắng, `rounded-[16px]`, `max-w-[360px]`, viền #f0f0eb.
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF0F0EB)),
      ),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          // Stitch `p-6`.
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stitch: vòng tròn 56px nền #FFDAD6, icon 28px màu #BA1A1A.
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_bieuTuong, size: 28, color: AppColors.error),
                ),
              ),
              const SizedBox(height: 16), // Stitch `mb-4`
              // ⚠️ Cuộn được, và nút "Đã hiểu" nằm NGOÀI vùng cuộn.
              //
              // `loiNhan` là câu admin tự gõ (`admin.service.js:140` nối thẳng
              // `reason_inactive` vào), client không kiểm được độ dài. Một lý do
              // dài làm tràn hộp thoại 158px — đo được bằng chính ca test dưới,
              // ở màn 411dp. Tràn thì Flutter chỉ vẽ sọc vàng và ghi log, còn
              // nút bấm thì nằm ngoài màn hình: người dùng không đóng nổi hộp
              // thoại, mà `barrierDismissible` lại là `false`.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _tieuDe,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12), // Stitch `mb-3`
                      Text(
                        _than,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 22 / 14, // Stitch `leading-[22px]`
                          color: _mauThan,
                        ),
                      ),
                      const SizedBox(height: 8), // Stitch `mb-2`
                      const Text(
                        'Bạn đã được đăng xuất khỏi thiết bị này. Liên hệ hỗ '
                        'trợ nếu bạn cho rằng đây là nhầm lẫn.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24), // Stitch `mb-6`
              // Stitch: một nút duy nhất rộng hết hộp thoại, cao 48, nền
              // #1A1A19, bo 8px.
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Đã hiểu',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mở [HopThoaiBiDayRa]. `barrierDismissible: false` là có chủ ý — xem chú
/// thích của lớp.
Future<void> hienHopThoaiBiDayRa(
  BuildContext context,
  ThongBaoBuocDangXuat thongBao,
) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HopThoaiBiDayRa(thongBao: thongBao),
    );
