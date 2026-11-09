import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/gioi_han_do_dai.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../khung_the_nha.dart';

const _chuPhu = Color(0xFF454743);

/// Khối *Đặt mục tiêu* của form ví chung (Stitch `74ebe178…`). Không giữ trạng thái: trang cha cầm công tắc, ô tiền, hạn.
///
/// - Công tắc tắt thì chỉ còn hàng đầu (không đường kẻ, không ô).
/// - Ô tiền chèn chấm ngăn nghìn như `OSoDuVi` và có trần số chữ số (quét 8 nhận diện theo tên controller).
/// - [onDoiSoTien] gọi khi NGƯỜI DÙNG gõ: trang cha dùng nó để biết ô bị đụng, nên không nghe controller (gán `text` lúc nạp
///   cũng kích hoạt listener và biến mọi lần lưu thành đẩy `goal` vô cớ).
class KhoiMucTieuVi extends StatelessWidget {
  const KhoiMucTieuVi({
    super.key,
    required this.bat,
    required this.onDoi,
    required this.soTienMuc,
    required this.onDoiSoTien,
    required this.han,
    required this.onChonHan,
  });

  final bool bat;

  /// `null` = khoá (đang lưu).
  final ValueChanged<bool>? onDoi;
  final TextEditingController soTienMuc;
  final VoidCallback onDoiSoTien;
  final DateTime? han;
  final VoidCallback? onChonHan;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return KhungTheNha(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.sports_score, size: 20, color: AppColors.onSurface),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đặt mục tiêu', style: chu.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text('Tiến độ tính theo số dư của ví, góp vào ví là góp vào mục tiêu.',
                        style: chu.bodySmall?.copyWith(color: _chuPhu)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                key: const Key('cong-tac-muc-tieu'),
                value: bat,
                onChanged: onDoi,
                activeTrackColor: AppColors.primary,
                activeThumbColor: Colors.white,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFDADAD6),
              ),
            ],
          ),
          if (bat) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, thickness: 1, color: AppColors.surfaceContainerHigh),
            ),
            _nhan(context, 'SỐ TIỀN MỤC TIÊU'),
            _oTien(context),
            const SizedBox(height: 14),
            _nhan(context, 'HẠN'),
            _oHan(context),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Mọi thành viên thấy tiến độ. Chỉ Chủ nhà đổi được.',
                      style: chu.bodySmall?.copyWith(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _nhan(BuildContext context, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      );

  Widget _oTien(BuildContext context) => TextField(
        key: const Key('o-so-tien-muc-tieu'),
        controller: soTienMuc,
        enabled: onDoi != null,
        keyboardType: TextInputType.number,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          // numeric(15,2): 14 chữ số làm `goal` kẹt hàng đợi đẩy vĩnh viễn, im lặng.
          const GioiHanSoChuSo(kSoChuSoToiDaSoTien),
        ],
        onChanged: (value) {
          onDoiSoTien();
          // `digitsOnly` đã lọc, nhưng sau khi ghi lại chuỗi đã chèn chấm thì lần gọi sau mang cả dấu chấm.
          final chuSo = value.replaceAll('.', '');
          if (chuSo.isEmpty) return;
          final daCham = CurrencyFormatter.formatSoThoi(int.tryParse(chuSo) ?? 0);
          if (soTienMuc.text != daCham) {
            soTienMuc.value = TextEditingValue(text: daCham, selection: TextSelection.collapsed(offset: daCham.length));
          }
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          suffixIcon: const Padding(
            padding: EdgeInsets.only(right: 14),
            child: Align(widthFactor: 1, child: Text('đ', style: TextStyle(fontSize: 14, color: _chuPhu))),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          // Theme của app vẽ viền ở các trạng thái có tiêu điểm / bật; Stitch `74ebe178…` và ô HẠN bên dưới không viền.
          border: _vienKhong,
          enabledBorder: _vienKhong,
          focusedBorder: _vienKhong,
          disabledBorder: _vienKhong,
        ),
      );

  static final _vienKhong = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none);

  Widget _oHan(BuildContext context) => Semantics(
        button: true,
        label: 'Chọn hạn',
        child: Material(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: const Key('o-han-muc-tieu'),
            borderRadius: BorderRadius.circular(12),
            onTap: onChonHan,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(han == null ? 'Chọn hạn' : DateFormatter.formatDate(han!),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500, color: han == null ? AppColors.textSecondary : AppColors.onSurface)),
                  ),
                  const Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      );
}
