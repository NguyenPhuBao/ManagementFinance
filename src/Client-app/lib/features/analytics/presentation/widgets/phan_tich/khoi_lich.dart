/// Khối "khoi_lich" của trang Phân tích — tách từ `analytics_page.dart` ngày 2026-10-10 (spec bịt điểm rò mục 5.1).
/// Dời nguyên văn, chỉ đổi tên riêng tư → công khai; trạng thái và thứ tự cụm vẫn ở trang.
library;

import 'package:flutter/material.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../../../domain/lich_chi_tieu.dart';
import '../../../domain/pham_vi_ky.dart';
import 'chung.dart';

/// Thu/chi theo từng ví, giảm dần theo chi.
/// Lịch chi tiêu — heatmap theo ngày (#6 khảo sát lần hai, 2026-09-16).
///
/// Lưới lịch **tháng** chứ không phải dải kiểu GitHub: PocketSmith và Money
/// Lover đều vẽ thế, và 30 ô còn có chỗ in số ngày còn 365 ô thì không.
///
/// Dựng bằng `GridView` chứ không `CustomPainter` — app chưa dùng `CustomPaint`
/// ở đâu, và một ô vuông có chữ số thì `GridView` đủ; mở một lối vẽ mới ở đây
/// là thêm một vùng **không test tự động được** (bẫy 4.9) mà chẳng được gì.
class KhoiLich extends StatefulWidget {
  final ThongKeKy tk;
  const KhoiLich({super.key, required this.tk});

  @override
  State<KhoiLich> createState() => _KhoiLichState();
}

class _KhoiLichState extends State<KhoiLich> {
  DateTime? _chon;

  @override
  void didUpdateWidget(covariant KhoiLich old) {
    super.didUpdateWidget(old);
    // Đổi kỳ thì bỏ chọn: ngày cũ không còn ô nào trên lưới, và giữ nó lại là
    // thẻ tóm tắt nói về một ngày người dùng không còn nhìn thấy.
    if (old.tk.ky != widget.tk.ky) _chon = null;
  }

  @override
  Widget build(BuildContext context) {
    // Chốt lớp thứ hai — xem chú thích ở `_than()`.
    if (widget.tk.ky.donVi != DonViKy.thang) return const SizedBox.shrink();

    final o = oLich(widget.tk.ky);
    // Thang màu neo vào mức chi trung bình mỗi ngày, KHÔNG vào ngày lớn nhất —
    // lý lẽ ở docstring `bacNhiet`.
    final tb = widget.tk.soLieu.chiMoiNgay;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ⚠️ `tieuDeKhoi` là `SizedBox(width: double.infinity)` — nó
              // dành cho `Column`. Đặt trần vào `Row` là ép bề rộng vô hạn và
              // **cả cây dừng dựng**, kéo theo mọi ca test của trang.
              Expanded(child: tieuDeKhoi('Lịch chi tiêu')),
              const SizedBox(width: 8),
              Text(
                widget.tk.ky.nhanNgan,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Thứ Hai đứng ĐẦU, Chủ nhật đứng CUỐI — quy ước Việt Nam, và
              // `oLich` chèn ô trống theo đúng luật ấy.
              for (final t in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
                Expanded(
                  child: Center(
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: o.length,
            itemBuilder: (_, i) {
              final ngay = o[i];
              if (ngay == null) return const SizedBox.shrink();
              return OLich(
                ngay: ngay,
                muc: widget.tk.lichChiTieu[ngay],
                trungBinh: tb,
                dangChon: _chon == ngay,
                onTap: () => setState(() => _chon = ngay),
              );
            },
          ),
          const SizedBox(height: 12),
          const ChuGiaiNhiet(),
          if (_chon != null) ...[
            const SizedBox(height: 16),
            TomTatNgay(ngay: _chon!, muc: widget.tk.lichChiTieu[_chon!]),
          ],
        ],
      ),
    );
  }
}

/// Một ô ngày. `muc == null` là **không chi đồng nào** — khác hẳn "chi rất ít",
/// nên nó có nền riêng chứ không phải bậc nhạt nhất.
class OLich extends StatelessWidget {
  final DateTime ngay;
  final NgayChiTieu? muc;
  final double trungBinh;
  final bool dangChon;
  final VoidCallback onTap;

  const OLich({
    super.key,
    required this.ngay,
    required this.muc,
    required this.trungBinh,
    required this.dangChon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bac = bacNhiet(muc?.tongChi ?? 0, trungBinh: trungBinh);
    final chu = bac >= 3 ? Colors.white : AppColors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: nenBac(bac),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: dangChon
                ? AppColors.textPrimary
                : (bac == 0 ? AppColors.outlineVariant : Colors.transparent),
            width: dangChon ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            '${ngay.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: dangChon ? FontWeight.bold : FontWeight.w500,
              color: bac == 0 ? AppColors.textSecondary : chu,
            ),
          ),
        ),
      ),
    );
  }
}

/// Nền của một bậc — **một chỗ định nghĩa**, để ô và chú giải không thể lệch
/// nhau. Màu là `AppColors.expense` chứ không phải xanh: cả app dùng đỏ cho
/// khoản chi, và một lưới xanh cho "tiêu nhiều" đọc như một lời khen.
Color nenBac(int bac) => switch (bac) {
      0 => Colors.white,
      1 => AppColors.expense.withValues(alpha: 0.18),
      2 => AppColors.expense.withValues(alpha: 0.40),
      3 => AppColors.expense.withValues(alpha: 0.65),
      _ => AppColors.expense,
    };

/// Chú giải thang màu. Nói rõ thang neo vào **mức trung bình** chứ không vào
/// ngày lớn nhất — nếu không, hai tháng có lưới giống hệt nhau lại là hai mức
/// chi hoàn toàn khác.
class ChuGiaiNhiet extends StatelessWidget {
  const ChuGiaiNhiet({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Ít',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(width: 6),
        for (var b = 0; b <= 4; b++) ...[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: nenBac(b),
              borderRadius: BorderRadius.circular(3),
              border:
                  b == 0 ? Border.all(color: AppColors.outlineVariant) : null,
            ),
          ),
          const SizedBox(width: 4),
        ],
        const SizedBox(width: 2),
        const Text('Nhiều',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const Spacer(),
        const Flexible(
          child: Text(
            'So với mức chi trung bình mỗi ngày',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Thẻ tóm tắt của ngày đang chọn.
///
/// Ngày **không chi** vẫn hiện thẻ, và nói thẳng "Không chi" — im lặng ở đây
/// làm người dùng tưởng cú chạm không ăn.
class TomTatNgay extends StatelessWidget {
  final DateTime ngay;
  final NgayChiTieu? muc;
  const TomTatNgay({super.key, required this.ngay, required this.muc});

  @override
  Widget build(BuildContext context) {
    final m = muc;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                nhanNgayLich(ngay),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                m == null ? 'Không chi' : '${m.soKhoan} khoản',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (m != null) ...[
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '-${chuoiTien(m.tongChi)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.expense,
                ),
              ),
            ),
            if (m.lonNhat != null) ...[
              const SizedBox(height: 4),
              Text(
                // `chuoiTien` chứ không `CurrencyFormatter.format`: hai hàm khác
                // nhau ở **khoảng trắng trước chữ đ**, và máy ảo cho thấy hai
                // định dạng nằm trong CÙNG một thẻ đọc rất chối. Ngoài thẻ này
                // thì cả hai vẫn cùng tồn tại trên trang, đúng như trước.
                'Lớn nhất: ${m.lonNhat!.tenDanhMuc} · ${chuoiTien(m.lonNhat!.soTien)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
