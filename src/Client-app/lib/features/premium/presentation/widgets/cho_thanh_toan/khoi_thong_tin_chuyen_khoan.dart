import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';

/// Khối *THÔNG TIN CHUYỂN KHOẢN* của màn Chờ thanh toán (Stitch `95b2774f…`; spec G94 2026-10-18 mục 5.4) — cho người
/// chuyển tay khi không quét được ảnh. Dòng nào server không gửi thì không dựng (không hiện ô trống, không đoán).
class KhoiThongTinChuyenKhoan extends StatelessWidget {
  const KhoiThongTinChuyenKhoan({
    super.key,
    required this.soTien,
    this.soTaiKhoan,
    this.chuTaiKhoan,
    this.noiDung,
  });

  final int soTien;
  final String? soTaiKhoan;
  final String? chuTaiKhoan;
  final String? noiDung;

  void _chep(String chu, String cau) {
    Clipboard.setData(ClipboardData(text: chu));
    baoNhanh(cau, loai: LoaiThongBao.xong);
  }

  @override
  Widget build(BuildContext context) {
    final stk = soTaiKhoan;
    final chu = chuTaiKhoan;
    final nd = noiDung;
    final dong = <Widget>[
      if (stk != null)
        _dong(
          'Số tài khoản',
          Text(stk, textAlign: TextAlign.end, style: _giaTri),
          nutChep: IconButton(
            key: const Key('cho-chep-stk'),
            tooltip: 'Chép số tài khoản',
            onPressed: () => _chep(stk, 'Đã chép số tài khoản'),
            icon: const Icon(Icons.content_copy, size: 17, color: AppColors.textSecondary),
            visualDensity: VisualDensity.compact,
          ),
        ),
      if (chu != null) _dong('Chủ tài khoản', Text(chu, textAlign: TextAlign.end, style: _giaTri)),
      _dong(
        'Số tiền',
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(CurrencyFormatter.format(soTien.toDouble()),
              maxLines: 1, style: _giaTri.copyWith(fontWeight: FontWeight.bold)),
        ),
      ),
      if (nd != null)
        _dong(
          'Nội dung',
          Text(nd, textAlign: TextAlign.end, style: _giaTri.copyWith(fontSize: 13, letterSpacing: 0.3)),
          nutChep: IconButton(
            key: const Key('cho-chep-noi-dung'),
            tooltip: 'Chép nội dung',
            onPressed: () => _chep(nd, 'Đã chép nội dung chuyển khoản'),
            icon: const Icon(Icons.content_copy, size: 17, color: AppColors.textSecondary),
            visualDensity: VisualDensity.compact,
          ),
        ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('THÔNG TIN CHUYỂN KHOẢN',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          for (var i = 0; i < dong.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.outlineVariant),
            dong[i],
          ],
        ],
      ),
    );
  }

  static const _giaTri = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

  /// Nhãn trái, giá trị phải (`Flexible` — tên chủ tài khoản / nội dung dài xuống dòng canh phải, không tràn ở 320 dp).
  Widget _dong(String nhan, Widget giaTri, {Widget? nutChep}) => Padding(
        padding: EdgeInsets.symmetric(vertical: nutChep == null ? 10 : 2),
        child: Row(
          children: [
            Text(nhan, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 12),
            Expanded(child: Align(alignment: Alignment.centerRight, child: giaTri)),
            if (nutChep != null) nutChep,
          ],
        ),
      );
}
