import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/trang_thai_may_chu.dart';

/// Dòng nhắc máy chủ ở Trang chủ (spec G89 2026-10-20 mục 4.1; Stitch `006c5a2eafc9461ab630163d1ff85de9`
/// *"Trang chủ - Dòng nhắc máy chủ (3 biến thể)"*). Đứng ĐẦU chồng dòng nhắc — nó giải thích vì sao mọi thứ khác chưa đồng
/// bộ. Không nút, không ✕: tự ẩn khi request mang phiên kế tiếp thành công.
///
/// Khuôn `DongNhacHetHan`: khoảng 24 phía trên nằm TRONG widget, bình thường thì không dựng gì; chưa đăng ký
/// [TrangThaiMayChu] (test cũ của Trang chủ) cũng không dựng gì. Màu theo hex của Stitch (tiền lệ trang Hoá đơn): dòng phụ
/// `#454743`, viền `#c5c7bf` 30 % — không phải `AppColors.outlineVariant` (`#E3E3DF`). Không hiện lý do admin gõ (thông báo
/// tối giản), không hứa giờ kết thúc bảo trì (client không biết).
class DongNhacMayChu extends StatelessWidget {
  const DongNhacMayChu({super.key, this.trangThai, this.clock});

  /// `null` → `sl<TrangThaiMayChu>()` nếu đã đăng ký.
  final ValueListenable<TinhTrangMayChu>? trangThai;
  final DateTime Function()? clock;

  static const _vien = Color(0x4DC5C7BF);
  static const _bong = Color(0x081A1A19);
  static const _chuChinh = Color(0xFF1A1A19);
  static const _chuPhu = Color(0xFF454743);
  static const _nenBaoTri = Color(0xFFFEF3C7); // amber-100
  static const _iconBaoTri = Color(0xFFB45309); // amber-700
  static const _nenChan = Color(0xFFFFDAD6);
  static const _iconChan = Color(0xFFBA1A1A);

  ValueListenable<TinhTrangMayChu>? get _nguon =>
      trangThai ?? (sl.isRegistered<TrangThaiMayChu>() ? sl<TrangThaiMayChu>() : null);

  @override
  Widget build(BuildContext context) {
    final nguon = _nguon;
    if (nguon == null) return const SizedBox.shrink();
    return ValueListenableBuilder<TinhTrangMayChu>(
      valueListenable: nguon,
      builder: (context, t, _) {
        final nd = _noiDung(t, (clock ?? DateTime.now)());
        if (nd == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Container(
            key: const ValueKey('dong-nhac-may-chu'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _vien),
              boxShadow: const [BoxShadow(color: _bong, blurRadius: 3, offset: Offset(0, 1))],
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: nd.nen, borderRadius: BorderRadius.circular(6)),
                  child: Icon(nd.icon, size: 16, color: nd.mauIcon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nd.tieuDe,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _chuChinh, height: 1.25),
                      ),
                      const SizedBox(height: 2),
                      Text(nd.phu, style: const TextStyle(fontSize: 11, color: _chuPhu, height: 1.375)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static ({IconData icon, Color nen, Color mauIcon, String tieuDe, String phu})? _noiDung(
      TinhTrangMayChu t, DateTime bayGio) {
    switch (t) {
      case MayChuBinhThuong():
        return null;
      case MayChuBaoTri():
        return (
          icon: Icons.construction,
          nen: _nenBaoTri,
          mauIcon: _iconBaoTri,
          tieuDe: 'Máy chủ đang bảo trì',
          phu: 'Dữ liệu trên máy vẫn dùng được, tự đồng bộ khi xong',
        );
      case MayChuPhongToa(:final hetHanLuc):
        // Giờ đã qua mà dòng nhắc còn (chưa có request nào thành công) → đừng hứa một giờ đã trôi.
        final conGio = hetHanLuc != null && hetHanLuc.isAfter(bayGio);
        return (
          icon: Icons.shield,
          nen: _nenChan,
          mauIcon: _iconChan,
          tieuDe: 'Mạng này đang bị tạm chặn',
          phu: conGio
              ? 'Tới ${chuGioHetHan(hetHanLuc, bayGio)} · dữ liệu trên máy vẫn dùng được'
              : 'Dữ liệu trên máy vẫn dùng được',
        );
    }
  }
}
