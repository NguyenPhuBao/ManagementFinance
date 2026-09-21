/// Bottom sheet "Lọc theo số tiền" của sổ giao dịch (2026-09-21).
///
/// ## Vì sao hai ô, không phải dropdown toán tử
///
/// Để trống ô "Đến" là *lớn hơn*, để trống ô "Từ" là *nhỏ hơn*, điền cả hai là
/// *khoảng giữa*. Ba dạng ấy phủ trọn bốn toán tử mà Monarch Money bày thành một
/// dropdown riêng, nên thêm dropdown là dạy người dùng một khái niệm mà hình
/// dạng của ô đã nói rồi.
///
/// ## Vì sao KHÔNG có chip gợi ý nhanh
///
/// Đã cân nhắc hàng chip *"trên 100k · trên 500k · trên 1 triệu"* và bỏ: ba con
/// số ấy là **hằng cứng**, mà người thu nhập 5 triệu và người 50 triệu không có
/// cùng ngưỡng "khoản lớn" — đúng thứ mục 11.5 `AI_EDGE_FEATURE.md` vừa đi sửa ở
/// chỗ khác. Bản neo theo thu nhập thì đúng, nhưng giá là mở thêm một
/// nguồn dữ liệu cho trang chỉ để vẽ ba cái chip.
///
/// ## Ba nghĩa của giá trị trả về
///
/// - `null` — đóng sheet, không chọn gì. Bộ lọc **giữ nguyên**.
/// - [KhoangTien] rỗng — bấm **Xoá**. Bộ lọc **bỏ** điều kiện tiền.
/// - [KhoangTien] có giá trị — bấm **Áp dụng**.
///
/// Gộp hai cái đầu làm một là bấm ra ngoài sheet cũng xoá mất bộ lọc đang có.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/gioi_han_do_dai.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/khoang_tien.dart';

/// Mở sheet và trả về lựa chọn. Xem ba nghĩa ở đầu tệp.
Future<KhoangTien?> moChonKhoangTien(
  BuildContext context, {
  required KhoangTien? hienTai,
}) =>
    showModalBottomSheet<KhoangTien>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => ChonKhoangTienSheet(hienTai: hienTai),
    );

class ChonKhoangTienSheet extends StatefulWidget {
  const ChonKhoangTienSheet({super.key, required this.hienTai});

  /// Khoảng đang lọc, để hai ô mở ra đã mang sẵn giá trị.
  final KhoangTien? hienTai;

  @override
  State<ChonKhoangTienSheet> createState() => _ChonKhoangTienSheetState();
}

class _ChonKhoangTienSheetState extends State<ChonKhoangTienSheet> {
  late final TextEditingController _soTienTuController =
      TextEditingController(text: _chu(widget.hienTai?.tu));
  late final TextEditingController _soTienDenController =
      TextEditingController(text: _chu(widget.hienTai?.den));

  /// Số về chuỗi chữ số trần. `null` cho chuỗi rỗng — ô trống nghĩa là *mọi
  /// mức*, không phải 0.
  static String _chu(double? v) => v == null ? '' : v.toStringAsFixed(0);

  static double? _so(String chu) {
    final sach = chu.replaceAll(RegExp(r'[^0-9]'), '');
    if (sach.isEmpty) return null;
    return double.tryParse(sach);
  }

  KhoangTien get _khoang => KhoangTien(
        tu: _so(_soTienTuController.text),
        den: _so(_soTienDenController.text),
      );

  @override
  void dispose() {
    _soTienTuController.dispose();
    _soTienDenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final khoang = _khoang;
    final hopLe = khoang.hopLe;

    return SafeArea(
      child: Padding(
        // Chừa chỗ cho bàn phím: sheet này chỉ có ô nhập, nên bàn phím che mất
        // hai nút là ngõ cụt.
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lọc theo số tiền',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            _hang(
              nhan: 'Từ',
              khoa: const Key('khoang-tien-tu'),
              controller: _soTienTuController,
              goiY: '0',
            ),
            const SizedBox(height: 12),
            _hang(
              nhan: 'Đến',
              khoa: const Key('khoang-tien-den'),
              controller: _soTienDenController,
              goiY: '(mọi mức)',
            ),
            if (!hopLe) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Số tiền "từ" phải nhỏ hơn hoặc bằng "đến"',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  key: const Key('khoang-tien-xoa'),
                  // Khoảng RỖNG, không phải `null`: xem ba nghĩa ở đầu tệp.
                  onPressed: () =>
                      Navigator.of(context).pop(const KhoangTien()),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Xoá'),
                ),
                const SizedBox(width: 8),
                // ⚠️ `Expanded` bắt buộc: theme của app ép mọi `ElevatedButton`
                // rộng vô hạn, nên một nút trần trong `Row` làm trắng cả trang
                // mà không một dòng log nào (bẫy 4.11).
                Expanded(
                  child: ElevatedButton(
                    key: const Key('khoang-tien-ap-dung'),
                    onPressed: hopLe
                        ? () => Navigator.of(context).pop(khoang)
                        : null,
                    child: const Text('Áp dụng'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hang({
    required String nhan,
    required Key khoa,
    required TextEditingController controller,
    required String goiY,
  }) =>
      Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              nhan,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              key: khoa,
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              // ⚠️ Trần số chữ số BẮT BUỘC — test quét thứ tám canh việc này
              // theo **tên controller**. Tám cột tiền trên PostgreSQL đều là
              // `numeric(15,2)`, và dù sheet này không ghi gì xuống CSDL thì một
              // chuỗi 20 chữ số vẫn cho `double` vô nghĩa và ô phình khỏi sheet.
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                const GioiHanSoChuSo(kSoChuSoToiDaSoTien),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: goiY,
                hintStyle: const TextStyle(color: AppColors.outline),
                suffixText: 'đ',
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
}
