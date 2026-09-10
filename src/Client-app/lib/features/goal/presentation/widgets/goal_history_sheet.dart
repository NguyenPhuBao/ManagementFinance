import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/goal_history_filter.dart';
import 'nhan_tu_dong.dart';

/// Bảng "Lịch sử tích lũy" đầy đủ, mở từ nút **Xem tất cả** ở trang chi tiết.
///
/// ## Vì sao là bottom sheet chứ không phải một trang mới
///
/// Một trang mới phải khai route, và mọi route mới trong dự án này đều phải
/// trả lời câu hỏi *nó có nằm trong `StatefulShellRoute` không* — đặt nhầm là
/// app **chết màn đỏ** khi điều hướng từ ngoài shell (bẫy 7.8
/// `NOTIFICATION_FEATURE.md`). Bottom sheet không đụng router nên tránh trọn
/// vẹn cả lớp lỗi ấy, và nó cũng đúng bản chất: người dùng xem xong thì quay
/// lại đúng chỗ đang đứng.
///
/// ## Vì sao nó có vùng cuộn RIÊNG
///
/// Danh sách ở trang chi tiết dùng `shrinkWrap: true` +
/// `NeverScrollableScrollPhysics` trong `SingleChildScrollView` của cả trang,
/// tức **dựng mọi dòng cùng lúc, không ảo hoá**. Với 11 khoản thì không sao,
/// nhưng một mục tiêu trích hàng ngày chạy hai năm là **730 dòng** — và trang
/// ấy nay vẽ lại mỗi lượt đồng bộ. Cắt xuống 5 dòng chỉ *giấu* vấn đề; đưa
/// danh sách đầy đủ vào một `ListView` cuộn riêng mới thật sự sửa nó.
class GoalHistorySheet extends StatefulWidget {
  final String tenMucTieu;
  final List<KhoanTichLuy> khoan;

  /// `null` = đồng hồ máy; test truyền mốc cố định.
  final DateTime? now;

  const GoalHistorySheet({
    super.key,
    required this.tenMucTieu,
    required this.khoan,
    this.now,
  });

  @override
  State<GoalHistorySheet> createState() => _GoalHistorySheetState();
}

class _GoalHistorySheetState extends State<GoalHistorySheet> {
  LocChieu _chieu = LocChieu.tatCa;
  LocKhoang _khoang = LocKhoang.tatCa;
  LocNguon _nguon = LocNguon.tatCa;

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final hien = locKhoan(
      widget.khoan,
      chieu: _chieu,
      khoang: _khoang,
      nguon: _nguon,
      now: now,
    );
    // Tổng tính trên danh sách ĐÃ LỌC: dòng tổng nằm ngay trên dải chip nên
    // nó phải nói về đúng thứ đang hiện.
    final tong = tongKet(hien);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lịch sử tích lũy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                // Dòng tổng: trả lời luôn câu mà phần lớn người mở danh sách
                // ra đang định tự cộng nhẩm.
                Text(
                  // Rỗng thì nói rỗng. "0 khoản · đã gửi 0 đ" cãi nhau với
                  // thân bảng đang nói không có gì — đọc ra ngay trên máy
                  // thật, không test nào bắt được vì cả hai chuỗi đều "đúng".
                  tong.soKhoan == 0
                      ? 'Không có khoản nào'
                      : '${tong.soKhoan} khoản · đã gửi '
                          '${CurrencyFormatter.format(tong.daGui)}'
                          '${tong.daRut > 0 ? ' · đã rút ${CurrencyFormatter.format(tong.daRut)}' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _DaiChip<LocChieu>(
            cacGiaTri: LocChieu.values,
            dangChon: _chieu,
            nhanCua: (v) => v.nhan,
            onChon: (v) => setState(() => _chieu = v),
          ),
          _DaiChip<LocKhoang>(
            cacGiaTri: LocKhoang.values,
            dangChon: _khoang,
            nhanCua: (v) => v.nhan,
            onChon: (v) => setState(() => _khoang = v),
          ),
          // Dải thứ ba CHỈ hiện khi có thứ để phân biệt. Mục tiêu chưa bật
          // trích tự động thì một chip "Tự động" lọc ra rỗng chỉ là nhiễu, và
          // ba dải trên 411dp là cái giá không đáng trả cho một chip vô dụng.
          // Xét trên danh sách GỐC chứ không phải danh sách đã lọc: nếu không,
          // chọn "Tay" xong là dải tự biến mất và người dùng hết đường quay lại.
          if (widget.khoan.any((k) => k.laTuDong))
            _DaiChip<LocNguon>(
              cacGiaTri: LocNguon.values,
              dangChon: _nguon,
              nhanCua: (v) => v.nhan,
              onChon: (v) => setState(() => _nguon = v),
            ),
          const Divider(height: 1),
          Expanded(
            child: hien.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Không có khoản nào khớp bộ lọc.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: hien.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _Dong(khoan: hien[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Dải chip lọc, **cuộn ngang chứ không `Wrap`**.
///
/// Cùng bài học đã ghi ở trung tâm thông báo (mục 4.6
/// `NOTIFICATION_FEATURE.md`): bốn chip cần khoảng 360px còn điện thoại thật
/// rộng 411dp — `Wrap` xuống hàng thứ hai và ăn mất một dòng lịch sử trên màn
/// hình vốn đã chật. `SingleChildScrollView` cho `Row` bề rộng vô hạn nên cũng
/// không bao giờ tràn.
class _DaiChip<T> extends StatelessWidget {
  final List<T> cacGiaTri;
  final T dangChon;
  final String Function(T) nhanCua;
  final ValueChanged<T> onChon;

  const _DaiChip({
    required this.cacGiaTri,
    required this.dangChon,
    required this.nhanCua,
    required this.onChon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            for (final v in cacGiaTri) ...[
              ChoiceChip(
                label: Text(nhanCua(v)),
                selected: v == dangChon,
                onSelected: (_) => onChon(v),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dong extends StatelessWidget {
  final KhoanTichLuy khoan;

  const _Dong({required this.khoan});

  @override
  Widget build(BuildContext context) {
    final rut = khoan.laKhoanRut;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: rut ? const Color(0xFFFBEDEC) : const Color(0xFFF0F5EE),
            shape: BoxShape.circle,
          ),
          child: Icon(
            rut ? Icons.north_east_rounded : Icons.savings_outlined,
            color: rut ? AppColors.error : const Color(0xFF2E6B27),
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      rut ? 'Rút khỏi mục tiêu' : 'Gửi vào mục tiêu',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  // Đọc thẳng cờ của hàng, KHÔNG suy từ chiều tiền: mọi khoản
                  // rút đều là tay, nhưng khoản gửi thì có cả hai loại — và
                  // suy như thế là dán nhãn lên đúng những khoản người dùng
                  // vừa tự tay bấm.
                  if (khoan.laTuDong) ...[
                    const SizedBox(width: 6),
                    const NhanTuDong(),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(khoan.ngay),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${rut ? '−' : '+'}${CurrencyFormatter.format(khoan.soTien)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: rut ? AppColors.error : const Color(0xFF2E6B27),
          ),
        ),
      ],
    );
  }
}
