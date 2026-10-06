/// Khung chờ của trang Phân tích (E1 lượt UX, 2026-10-06).
///
/// Lúc đang tải, trang từng vẽ một vòng xoay giữa khoảng trống — thứ người dùng
/// thấy mỗi lần mở tab. Nay là hình dạng ba khối đầu của thứ tự MẶC ĐỊNH (Dòng
/// tiền → hai thẻ Tổng thu / Tổng chi → một biểu đồ) bằng thanh xám, để mắt
/// biết sắp có gì và trang không "nhảy" từ trống sang đầy.
///
/// Hình dạng chép Stitch `6408b0bd4da845d59092c1760c7725e8` *"Phân tích - Đang tải (khung chờ)"*,
/// hai chỗ lệch có chủ ý: bo góc 16 như thẻ thật (Stitch 8) và **không** lấp lánh (Stitch
/// có — người dùng chọn đứng yên, 2026-10-06).
///
/// Ba chốt:
/// - **Không chữ, không số** — một con số giả trên màn tải là một con số người
///   dùng có thể đọc nhầm là thật.
/// - **Đứng yên**, không hoạt ảnh lặp: trang tải xong trong vài trăm mili giây,
///   hiệu ứng lấp lánh chỉ kịp nháy; và hoạt ảnh vô hạn làm `pumpAndSettle` của
///   mọi widget test chạm trạng thái tải treo.
/// - Không theo thứ tự cụm RIÊNG của người dùng (mục 3.36): lúc tải chưa đọc
///   xong thứ tự ấy — khung chờ là hình dạng chung, không phải bản xem trước.
library;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class KhungChoPhanTich extends StatelessWidget {
  const KhungChoPhanTich({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Đang tải số liệu',
      child: const ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TheDongTien(),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _TheTong()),
                SizedBox(width: 12),
                Expanded(child: _TheTong()),
              ],
            ),
            SizedBox(height: 24),
            _TheBieuDo(),
          ],
        ),
      ),
    );
  }
}

/// Cùng kiểu thẻ với `_theTrang` của trang (bo 16, bóng rất nhẹ).
class _The extends StatelessWidget {
  const _The({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}

/// Một thanh giữ chỗ: [tiLe] là phần bề rộng của khung chứa nó.
class _Thanh extends StatelessWidget {
  const _Thanh({this.tiLe = 1, this.cao = 12});
  final double tiLe;
  final double cao;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: tiLe,
        child: Container(
          height: cao,
          decoration: BoxDecoration(
            color: AppColors.outlineVariant,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );
}

/// Tiêu đề thẻ: thanh bên trái, chấm giữ chỗ biểu tượng bên phải (Stitch).
class _HangTieuDe extends StatelessWidget {
  const _HangTieuDe({required this.tieuDe, required this.cham});
  final Widget tieuDe;
  final Widget cham;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: tieuDe),
          const SizedBox(width: 12),
          cham,
        ],
      );
}

class _Cham extends StatelessWidget {
  const _Cham({this.rong = 16, this.cao = 16});
  final double rong;
  final double cao;

  @override
  Widget build(BuildContext context) => Container(
        width: rong,
        height: cao,
        decoration: BoxDecoration(
          color: AppColors.outlineVariant,
          borderRadius: BorderRadius.circular(cao / 2),
        ),
      );
}

class _TheDongTien extends StatelessWidget {
  const _TheDongTien();

  /// Bề rộng (phần của nửa thẻ) nhãn trái · số phải từng hàng — dài ngắn khác
  /// nhau như Stitch `6408b0bd…` (1/4 · 1/3 · 1/5 và 1/3 · 2/5 · 1/4 của thẻ).
  static const _hang = [(0.5, 0.67), (0.67, 0.8), (0.4, 0.5)];

  @override
  Widget build(BuildContext context) => _The(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _HangTieuDe(
              tieuDe: _Thanh(tiLe: 0.45, cao: 18),
              cham: _Cham(),
            ),
            for (final (trai, phai) in _hang) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _Thanh(tiLe: trai, cao: 14)),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _Thanh(tiLe: phai, cao: 16),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
}

class _TheTong extends StatelessWidget {
  const _TheTong();

  @override
  Widget build(BuildContext context) => const _The(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HangTieuDe(
              tieuDe: _Thanh(tiLe: 0.5, cao: 12),
              cham: _Cham(rong: 14, cao: 14),
            ),
            SizedBox(height: 18),
            _Thanh(tiLe: 0.8, cao: 24),
          ],
        ),
      );
}

class _TheBieuDo extends StatelessWidget {
  const _TheBieuDo();

  @override
  Widget build(BuildContext context) => _The(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _HangTieuDe(
              tieuDe: _Thanh(tiLe: 0.55, cao: 18),
              cham: _Cham(rong: 32),
            ),
            const SizedBox(height: 14),
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                child: CustomPaint(painter: _LuoiNetDut(), size: Size.infinite),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 6; i++)
                    Container(
                      width: 20,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Ba vạch kẻ ngang nét đứt mờ trong vùng biểu đồ — gợi ý lưới, không số.
class _LuoiNetDut extends CustomPainter {
  const _LuoiNetDut();

  @override
  void paint(Canvas canvas, Size size) {
    final but = Paint()
      ..color = const Color(0xFFB8B8B0).withValues(alpha: 0.3)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = size.height * i / 2;
      for (var x = 0.0; x < size.width; x += 7) {
        canvas.drawLine(Offset(x, y), Offset((x + 4).clamp(0, size.width), y), but);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LuoiNetDut oldDelegate) => false;
}
