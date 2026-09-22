import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/tai_phan_bo.dart';

/// Thẻ "Đề xuất cân đối" trên trang Ngân sách — màn Stitch `f02861d9…`, khối 1
/// (đủ nguồn bù) và khối 3 (thiếu nguồn bù, viền đỏ).
///
/// Câu trên thẻ là `keHoach.cauTomTat` — **cùng** câu nối vào đuôi khối Nhận
/// xét, để hai khối cạnh nhau không nói hai chuyện. Không có nút "Tăng hạn mức
/// ngân sách" dù Stitch vẽ: ngoài phạm vi P2, và một nút không đi đâu là nút
/// chết (`khong_co_nut_chet_test`).
///
/// [onXem] mở sheet kế hoạch; chỉ hiện nút khi kế hoạch **có** dòng nguồn bù
/// (sheet rỗng là ngõ cụt). [onXemPhanTich] để `null` thì link không hiện —
/// cùng lối `onOpenAnalytics` của `BudgetTabsView`.
class TheKeHoach extends StatelessWidget {
  final KeHoachTaiPhanBo keHoach;
  final VoidCallback? onXem;
  final VoidCallback? onXemPhanTich;

  const TheKeHoach({
    super.key,
    required this.keHoach,
    required this.onXem,
    this.onXemPhanTich,
  });

  bool get _thieu => keHoach.trangThai == TrangThaiKeHoach.thieuNguonBu;

  @override
  Widget build(BuildContext context) {
    final kh = keHoach;
    final coNut = kh.dong.isNotEmpty && onXem != null;
    return Container(
      key: const ValueKey('the-ke-hoach'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _thieu ? AppColors.error : AppColors.outlineVariant,
          width: _thieu ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _thieu ? Icons.warning_amber_rounded : Icons.auto_awesome,
                size: 16,
                color: AppColors.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _thieu
                      ? 'ĐỀ XUẤT CÂN ĐỐI · KHÔNG ĐỦ DƯ ĐỊA'
                      : 'ĐỀ XUẤT CÂN ĐỐI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: _thieu ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _chip(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            kh.cauTomTat,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          if (_thieu) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFFD8D3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 15, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kh.dong.isEmpty
                          ? 'Không ngân sách nào còn dư địa để san sẻ. Cần nạp '
                              'thêm tiền hoặc cắt giảm chi tiêu.'
                          : 'Đã tính tối đa dư địa có thể san sẻ từ các ngân '
                              'sách còn lại (tối đa gom được '
                              '${CurrencyFormatter.format(kh.tongCat)}). Cần '
                              'nạp thêm tiền hoặc cắt giảm chi tiêu.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFF4A4443),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.surfaceContainerLow),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _thieu
                    ? (onXemPhanTich == null
                        ? const SizedBox.shrink()
                        : TextButton(
                            onPressed: onXemPhanTich,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              alignment: Alignment.centerLeft,
                            ),
                            child: const Text(
                              'Xem phân tích chi tiêu',
                              style: TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ))
                    : Text(
                        'Nguồn bù: ${kh.dong.map((d) => d.nguon.displayName).join(', ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
              if (coNut) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  key: const ValueKey('the-ke-hoach-xem'),
                  onPressed: onXem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Xem kế hoạch',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip() {
    if (_thieu) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '-${CurrencyFormatter.format(keHoach.soThieu)}',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Dự kiến vượt',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.error,
        ),
      ),
    );
  }
}
