import 'package:flutter/material.dart';

import '../../../../core/ui/do_chu.dart';

/// Hàng đầu của thẻ hoá đơn: tên + hạn trả bên trái, chip trạng thái bên phải.
///
/// Tách khỏi `bill_page.dart` để **test được ở nhiều bề rộng màn hình**. Nó
/// từng tràn khi tên hoá đơn dài: một `Text` không co được đặt cạnh chip bề
/// rộng cố định thì chữ dài bao nhiêu cũng chiếm bấy nhiêu, và chip bị đẩy ra
/// ngoài. Chrome 1280px không bao giờ thấy — chỉ lộ ra ở màn điện thoại thật.
class BillStatusHeader extends StatelessWidget {
  const BillStatusHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.statusBg,
    required this.titleColor,
    this.isPaid = false,
    this.icon,
    this.iconColor,
    this.meta,
  });

  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final Color statusBg;
  final Color titleColor;
  final bool isPaid;

  /// Biểu tượng của **danh mục** hoá đơn, cùng quy ước với dòng sổ giao dịch.
  ///
  /// Cố ý không dùng hai cột `bills.icon`/`bills.colour`: chúng có mặc định,
  /// được kế thừa sang kỳ sau, nhưng **không UI nào đặt** — nên mọi hoá đơn
  /// đều mang đúng một giá trị và biểu tượng sẽ không phân biệt được gì.
  final IconData? icon;
  final Color? iconColor;

  /// Dòng thứ ba: "Danh mục • Ví". Tách khỏi [subtitle] chứ không nối vào,
  /// vì gộp một dòng thì ở 411dp phần ví bị `ellipsis` nuốt mất — đúng thứ
  /// người dùng cần biết trước khi bấm Thanh toán. Chip cùng hàng thì dòng
  /// này trải rộng dưới cả chip (G52); [_vuaMotHang] vì thế không đo nó.
  final String? meta;

  static const _kieuTen = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
  static const _kieuHan = TextStyle(fontSize: 14, color: Color(0xFF46464C));
  static const _kieuChip =
      TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2);

  /// Bề rộng cố định quanh cột chữ: ô biểu tượng 36 + khe 12, khe 8 trước chip,
  /// lề trong chip 8 × 2, và dấu ✓ 14 + khe 4 của chip "đã trả".
  double get _rongBieuTuong => icon != null ? 36 + 12 : 0;
  double get _phanCoDinhChip => 8 + 16 + (isPaid ? 14 + 4 : 0);

  /// Một hàng có đủ chỗ cho cột chữ **và** chip không — đo bề rộng thật ở cỡ
  /// chữ đang dùng (G74, 2026-10-07). Cột chữ cần chỗ cho dòng **dài nhất**
  /// của tên và hạn trả; dòng "danh mục • ví" trải rộng dưới chip (G52) nên không tính.
  bool _vuaMotHang(BuildContext context, double rong) {
    var cot = doRongChu(context, title, _kieuTen);
    for (final dong in subtitle.split('\n')) {
      final r = doRongChu(context, dong, _kieuHan);
      if (r > cot) cot = r;
    }
    final chip = doRongChu(context, status, _kieuChip) + _phanCoDinhChip;
    // Nửa điểm ảnh dung sai cho phép làm tròn của TextPainter.
    return _rongBieuTuong + cot + chip <= rong + 0.5;
  }

  @override
  Widget build(BuildContext context) {
    // G74 (2026-10-07): ở màn hẹp (Realme để cỡ hiển thị lớn — mật độ 540,
    // 320 dp) chip "CHƯA THANH TOÁN" chiếm 110 dp, cột chữ còn 68 dp trong khi
    // "Hạn 25/09/2026" cần 107: ngày gãy hai dòng, tên cụt. Khi ĐO thấy không
    // vừa, chip xuống dưới cột chữ (người dùng chọn); màn đủ chỗ giữ dáng cũ.
    return LayoutBuilder(builder: (context, rang) {
      final motHang = _vuaMotHang(context, rang.maxWidth);
      final coMeta = meta != null && meta!.isNotEmpty;
      final hang = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? titleColor).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor ?? titleColor),
            ),
            const SizedBox(width: 12),
          ],
          // `Expanded` là thứ chặn tràn: phần chữ nhận đúng chỗ còn lại sau khi
          // chip lấy phần của nó, và `ellipsis` cắt gọn thay vì đẩy chip ra rìa.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _kieuTen.copyWith(color: titleColor),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  // Dòng đã trả mang hai dòng "Hạn…" / "Trả…" (xem bill_page).
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _kieuHan,
                ),
                if (coMeta && !motHang) ...[
                  const SizedBox(height: 2),
                  _dongMeta(),
                ],
                if (!motHang) ...[
                  const SizedBox(height: 8),
                  _chip(),
                ],
              ],
            ),
          ),
          if (motHang) ...[
            const SizedBox(width: 8),
            _chip(),
          ],
        ],
      );
      if (!motHang || !coMeta) return hang;
      // G52 (2026-10-09): chip cùng hàng thì dòng "danh mục • ví • Tự trả" RA
      // KHỎI cột chữ và trải hết bề ngang dưới cả tên lẫn chip (người dùng
      // chọn). Ở 360 dp tên + hạn vừa cạnh chip nhưng dòng này chỉ còn 108 dp
      // trong khi cần ~150 — "Nhà cửa • Tiền…" mất tên ví và chữ "Tự trả". Chip
      // thấp hơn hai dòng tên + hạn nên dòng này không đè chip, thẻ không cao
      // thêm. Khi chip đã xếp chồng (G74) dòng này ở lại trong cột chữ, trên chip.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          hang,
          const SizedBox(height: 2),
          Padding(
            padding: EdgeInsets.only(left: _rongBieuTuong),
            child: _dongMeta(),
          ),
        ],
      );
    });
  }

  Widget _dongMeta() {
    return Text(
      meta!,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B72)),
    );
  }

  Widget _chip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        // Chip chỉ rộng bằng nội dung của nó; không có dòng này thì trong
        // một Row cha đã chật, chip lại đòi chiếm hết chỗ còn lại.
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPaid) ...[
            Icon(Icons.check_circle, color: statusColor, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            status,
            maxLines: 1,
            style: _kieuChip.copyWith(color: statusColor),
          ),
        ],
      ),
    );
  }
}
