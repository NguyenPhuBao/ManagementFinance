import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/sync/sync_engine.dart';

/// Dòng nhắc *"Chưa nhận được dữ liệu mới"* ở Trang chủ (2026-10-26, đơn 53 vế C; biến thể 4 của màn Stitch
/// `006c5a2eafc9461ab630163d1ff85de9` *"Trang chủ - Dòng nhắc máy chủ"*): lượt kéo về gần nhất bị máy chủ trả lời bằng lỗi
/// (`SyncEngine.keoVeBiTuChoi`) — trước đó lỗi bị nuốt và dữ liệu máy khác đứng im, không ai biết.
///
/// Cùng khuôn `DongNhacMayChu` (đứng ngay sau nó): khoảng 24 phía trên nằm TRONG widget, bình thường không dựng gì, không
/// nút, không ✕ — tự ẩn khi lượt kéo sau thành công; chưa đăng ký [SyncEngine] (test cũ của Trang chủ) cũng không dựng gì.
/// Không nêu mã lỗi (thông báo tối giản). Câu phụ nói đúng việc lượt đẩy vẫn chạy — người dùng không cần ngừng ghi chép.
/// Trạng thái gắn PHIÊN chứ không gắn máy chủ, nên không đi qua `TrangThaiMayChu` (interceptor đặt lại nó ở mọi phản hồi
/// thành công — lượt đẩy thành công sẽ xoá dòng nhắc dù lượt kéo vẫn hỏng).
class DongNhacKeoVe extends StatelessWidget {
  const DongNhacKeoVe({super.key, this.nguon});

  /// `null` → `sl<SyncEngine>().keoVeBiTuChoi` nếu đã đăng ký.
  final ValueListenable<bool>? nguon;

  static const _vien = Color(0x4DC5C7BF);
  static const _bong = Color(0x081A1A19);
  static const _chuChinh = Color(0xFF1A1A19);
  static const _chuPhu = Color(0xFF454743);
  static const _nen = Color(0xFFFEF3C7); // amber-100
  static const _mauIcon = Color(0xFFB45309); // amber-700

  ValueListenable<bool>? get _nguon =>
      nguon ?? (sl.isRegistered<SyncEngine>() ? sl<SyncEngine>().keoVeBiTuChoi : null);

  @override
  Widget build(BuildContext context) {
    final n = _nguon;
    if (n == null) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: n,
      builder: (context, hong, _) {
        if (!hong) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Container(
            key: const ValueKey('dong-nhac-keo-ve'),
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
                  decoration: BoxDecoration(color: _nen, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.sync_problem, size: 16, color: _mauIcon),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Chưa nhận được dữ liệu mới',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _chuChinh, height: 1.25),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Thay đổi từ máy khác chưa về, thay đổi trên máy này vẫn được gửi lên',
                        style: TextStyle(fontSize: 11, color: _chuPhu, height: 1.375),
                      ),
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
}
