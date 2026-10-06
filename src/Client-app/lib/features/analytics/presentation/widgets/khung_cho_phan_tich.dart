/// Khung chờ của trang Phân tích (E1 lượt UX, 2026-10-06).
///
/// Lúc đang tải, trang từng vẽ một vòng xoay giữa khoảng trống — thứ người dùng
/// thấy mỗi lần mở tab. Nay là hình dạng ba khối đầu của thứ tự MẶC ĐỊNH (Dòng
/// tiền → hai thẻ Tổng thu / Tổng chi → một biểu đồ) bằng thanh xám, để mắt
/// biết sắp có gì và trang không "nhảy" từ trống sang đầy.
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

class _TheDongTien extends StatelessWidget {
  const _TheDongTien();

  @override
  Widget build(BuildContext context) => _The(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Thanh(tiLe: 0.4, cao: 16),
            for (var i = 0; i < 3; i++) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: _Thanh(tiLe: 0.6)),
                  SizedBox(width: 24),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _Thanh(tiLe: 0.7),
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
            _Thanh(tiLe: 0.5, cao: 10),
            SizedBox(height: 12),
            _Thanh(tiLe: 0.9, cao: 20),
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
            const _Thanh(tiLe: 0.45, cao: 16),
            const SizedBox(height: 16),
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < 6; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  const Expanded(child: _Thanh(cao: 8)),
                ],
              ],
            ),
          ],
        ),
      );
}
