import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

/// Thẻ ảnh VietQR + nút *Lưu mã QR* của màn Chờ thanh toán (Stitch `95b2774f…`; spec G94 2026-10-18 mục 5.4). Ảnh do
/// server dựng (`qrUrl`) — nhúng sẵn số tài khoản, số tiền, nội dung, nên *Quét từ ảnh* ở app ngân hàng điền sẵn hết.
///
/// Nút Lưu hiện ngay khi có ảnh, KHÔNG chờ ảnh tải xong (lưu tải lại byte từ `qrUrl`, không đọc ảnh trên màn); chỉ ẩn
/// khi ảnh báo hỏng — khi ấy lưu cũng sẽ hỏng, và câu ngắn chỉ người dùng sang khối thông tin / trang PayOS.
class KhoiMaQr extends StatefulWidget {
  const KhoiMaQr({
    super.key,
    required this.anh,
    required this.dangLuu,
    required this.onLuu,
  });

  /// Ảnh dựng từ `qrUrl` qua khe `nguonAnhQr` của trang (mặc định `NetworkImage`; test tiêm ảnh giả — `flutter test`
  /// trả 400 cho mọi ảnh mạng).
  final ImageProvider anh;
  final bool dangLuu;
  final VoidCallback onLuu;

  @override
  State<KhoiMaQr> createState() => _KhoiMaQrState();
}

class _KhoiMaQrState extends State<KhoiMaQr> {
  bool _hong = false;

  void _baoHong() {
    if (_hong) return;
    // `errorBuilder` chạy giữa lượt dựng — đổi trạng thái sau khung hình.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hong) setState(() => _hong = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 240,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Image(
              key: const Key('cho-anh-qr'),
              image: widget.anh,
              width: 224,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                _baoHong();
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                  child: Text(
                    'Không tải được mã QR — dùng thông tin bên dưới hoặc mở trang PayOS',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
          if (!_hong) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('cho-luu-qr'),
              onPressed: widget.dangLuu ? null : widget.onLuu,
              icon: widget.dangLuu
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download, size: 19),
              label: const Text('Lưu mã QR'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
