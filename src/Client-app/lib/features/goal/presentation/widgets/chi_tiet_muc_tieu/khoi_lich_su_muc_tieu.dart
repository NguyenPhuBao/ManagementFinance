/// Khối lịch sử tích lũy của trang Chi tiết mục tiêu (`goal_detail_page.dart`) — dời nguyên văn phần dựng bên trong
/// `StreamBuilder` của `_buildHistorySection` và `_danhSachLichSu` (đợt tách bốn trang lớn, spec 2026-10-13 mục 5.2): biểu
/// đồ, thẻ thống kê, hàng tiêu đề kèm *Xem tất cả* và danh sách. Dòng dữ liệu vẫn do trang mở và truyền vào.
library;

import 'package:flutter/material.dart';
import '../../../../../core/utils/date_formatter.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../transaction/data/models/transaction_entity.dart';
import '../../../data/models/goal_entity.dart';
import '../../../domain/goal_history_direction.dart';
import '../../../domain/goal_history_filter.dart';
import '../goal_progress_chart.dart';
import '../goal_stats_card.dart';
import '../nhan_tu_dong.dart';

/// Số dòng lịch sử dựng ngay trên trang. Phần còn lại nằm ở bảng đầy đủ.
///
/// Năm là con số vừa đủ để thấy *nhịp gần đây* mà không kéo trang dài thêm
/// một màn hình. Bỏ trần đi thì trang tăng tuyến tính không giới hạn, và
/// danh sách ở đây **không ảo hoá** (`shrinkWrap` + `NeverScrollable`) nên
/// mọi dòng được dựng cùng lúc, mỗi lượt đồng bộ.
const int _soDongLichSuToiDa = 5;

class KhoiLichSuMucTieu extends StatelessWidget {
  const KhoiLichSuMucTieu({
    super.key,
    required this.goal,
    required this.dangTai,
    required this.txs,
    required this.khoan,
    required this.onXemTatCa,
  });

  final GoalEntity goal;
  final bool dangTai;
  final List<TransactionEntity> txs;
  final List<KhoanTichLuy> khoan;
  final VoidCallback onXemTatCa;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Biểu đồ đứng NGAY TRÊN lịch sử vì hai khối đọc cùng một dữ
        // liệu: một cái vẽ hình dáng của cả quãng đường, một cái liệt kê
        // từng khoản. Khối tự biến mất khi chưa có khoản nào.
        if (!dangTai) ...[
          GoalProgressChart(goal: goal, khoan: khoan),
          if (khoan.isNotEmpty) const SizedBox(height: 12),
          // Thẻ ba con số tóm tắt đúng chuỗi mà biểu đồ vừa vẽ ra, nên nó
          // đứng ngay dưới chứ không phải một chỗ khác trên trang.
          GoalStatsCard(goal: goal, khoan: khoan),
          if (khoan.isNotEmpty) const SizedBox(height: 32),
        ],
        // Nút "Xem tất cả" từng bị GỠ ngày 2026-09-06 vì nó có
        // `onPressed: () {}` trong khi danh sách bên dưới đã hiện toàn bộ
        // — vừa không làm gì vừa ngụ ý sai rằng có phần bị giấu.
        //
        // Nay nó **quay lại và làm thật** (2026-09-08). Lý lẽ cũ nói về
        // một nút rỗng, không nói rằng danh sách phải hiện hết mãi mãi:
        // danh sách không có trần, và một mục tiêu trích hàng ngày chạy
        // hai năm là 730 dòng dựng cùng lúc trên một trang nay vẽ lại mỗi
        // lượt đồng bộ.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'LỊCH SỬ TÍCH LŨY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            if (khoan.length > _soDongLichSuToiDa)
              TextButton(
                onPressed: onXemTatCa,
                child: const Text('Xem tất cả'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (dangTai)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (txs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Chưa có khoản tích lũy nào.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          )
        else
          _DanhSachLichSu(goal: goal, txs: txs),
      ],
    );
  }
}

/// Năm dòng lịch sử gần nhất.
///
/// Chỉ dựng tối đa [_soDongLichSuToiDa] dòng ở đây. Phần còn lại nằm trong
/// bảng đầy đủ, nơi có vùng cuộn RIÊNG nên `ListView` ảo hoá thật sự.
class _DanhSachLichSu extends StatelessWidget {
  const _DanhSachLichSu({required this.goal, required this.txs});

  final GoalEntity goal;
  final List<TransactionEntity> txs;

  @override
  Widget build(BuildContext context) {
    final hienThi = txs.take(_soDongLichSuToiDa).toList();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: hienThi.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final tx = hienThi[index];
        final dateStr =
            DateFormatter.formatDateTime(tx.date);
        final amount = tx.amount;
        // Chiều tiền đọc từ tiền tố ghi chú do chính app sinh ra, KHÔNG
        // từ vị trí ví — so ví là diễn giải hàng cũ bằng cấu hình hiện
        // tại của mục tiêu, nên đổi ví một lần là lịch sử đọc sai hết.
        // Xem `goal_history_direction.dart`.
        final ghiChu = tx.note;
        final laKhoanRut = laKhoanRutKhoiMucTieu(
          ghiChu: ghiChu,
          viCuaHang: tx.walletId,
          viTichLuy: goal.walletId,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: laKhoanRut
                    ? const Color(0xFFFBEDEC)
                    : const Color(0xFFF0F5EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.savings_outlined,
                color: Color(0xFF2E6B27),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          // Cắt hậu tố: chip ngay bên cạnh đã nói
                          // "Tự động" rồi, để nguyên là dòng mang
                          // đúng ba chữ ấy hai lần.
                          ghiChuKhongHauTo(ghiChu),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (laKhoanTuDong(ghiChu)) ...[
                        const SizedBox(width: 6),
                        const NhanTuDong(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${laKhoanRut ? '−' : '+'}'
              '${CurrencyFormatter.format(amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: laKhoanRut ? AppColors.error : const Color(0xFF2E6B27),
              ),
            ),
          ],
        );
      },
    );
  }
}
