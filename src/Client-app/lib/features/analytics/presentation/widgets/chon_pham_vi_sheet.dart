/// Bottom sheet chọn phạm vi thời gian của trang Phân tích (P1, 2026-09-15).
///
/// **Hai tầng**: hàng chip chọn *đơn vị* ở trên, danh sách *kỳ* ở dưới. Đổi chip
/// chỉ đổi danh sách — nó chưa phải một lựa chọn, vì người dùng còn phải nói rõ
/// kỳ nào. Trộn hai thao tác ấy làm một là bấm "Quý" liền nhảy sang quý này mà
/// không ai yêu cầu.
///
/// **Vì sao là bottom sheet chứ không phải chip trên header:** hàng header của
/// trang Phân tích đã chật — nó từng tràn 53px ở 411dp và phải chỉnh tỉ lệ flex
/// 2:3 mới vừa (xem chú thích `_Header` ở `analytics_page.dart`). Thêm năm chip
/// vào hàng ấy là vỡ lại chỗ vừa vá.
///
/// Danh sách kỳ dựng tại chỗ bằng `cacKyGanNhat(moc, donVi)` chứ không đi qua
/// cubit: người dùng có thể lướt qua bốn đơn vị trước khi chọn, và mỗi lần chạm
/// một chip mà phải dựng lại cả trang là trả giá cho một thao tác chưa đổi dữ
/// liệu. Luật "12 kỳ" vẫn có đúng một chỗ định nghĩa ở domain.
library;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/pham_vi_ky.dart';

/// Mở sheet và trả về kỳ người dùng chọn; `null` khi họ đóng mà không chọn.
Future<Ky?> moChonPhamVi(
  BuildContext context, {
  required Ky kyHienTai,
  required DateTime moc,
}) =>
    showModalBottomSheet<Ky>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ChonPhamViSheet(
        kyHienTai: kyHienTai,
        moc: moc,
        onChon: (k) => Navigator.of(ctx).pop(k),
      ),
    );

class ChonPhamViSheet extends StatefulWidget {
  final Ky kyHienTai;

  /// Số đọc của đồng hồ, lấy từ `AnalyticsLoaded.moc`. Không gọi
  /// `DateTime.now()` trong widget — widget test sẽ phụ thuộc đồng hồ máy chạy
  /// nó, và "Tháng này" sẽ đổi nghĩa vào ngày 1 hằng tháng.
  final DateTime moc;

  final ValueChanged<Ky> onChon;

  const ChonPhamViSheet({
    super.key,
    required this.kyHienTai,
    required this.moc,
    required this.onChon,
  });

  @override
  State<ChonPhamViSheet> createState() => _ChonPhamViSheetState();
}

class _ChonPhamViSheetState extends State<ChonPhamViSheet> {
  late DonViKy _donVi = widget.kyHienTai.donVi;

  /// Thứ tự cố định theo **độ dài kỳ**, không theo tần suất dùng: người đọc quét
  /// một hàng chip bằng cách tìm chỗ của nó trong một dãy đã biết, nên dãy phải
  /// đứng yên giữa các lần mở.
  static const _thuTu = [
    (DonViKy.tuan, 'Tuần'),
    (DonViKy.thang, 'Tháng'),
    (DonViKy.quy, 'Quý'),
    (DonViKy.nam, 'Năm'),
    (DonViKy.tuyChon, 'Tuỳ chọn'),
  ];

  Future<void> _chonKhoangTuyY() async {
    final nay = widget.moc;
    final somNhat = DateTime(nay.year - 5);
    // ⚠️ Khoảng khởi tạo phải NẰM TRỌN trong `[somNhat, nay]`, kẻo
    // `showDateRangePicker` ném assertion — và ở đây nó là một exception bất
    // đồng bộ không ai bắt, nên nút chỉ đơn giản là **không làm gì** (G43).
    // Ca vấp thật là trạng thái mặc định của trang: "Tháng này" kết thúc ngày
    // cuối tháng, tức sau hôm nay. Phép kẹp là hàm thuần, có test riêng.
    final khoi = khoangKhoiTaoBoChonNgay(
      ky: widget.kyHienTai,
      somNhat: somNhat,
      muonNhat: nay,
    );
    final chon = await showDateRangePicker(
      context: context,
      firstDate: somNhat,
      lastDate: nay,
      currentDate: nay,
      initialDateRange: khoi == null
          ? null
          : DateTimeRange(start: khoi.from, end: khoi.den),
    );
    if (chon == null) {
      // Thoát bộ chọn ngày mà không chọn gì: **giữ nguyên** đơn vị cũ. Rơi về
      // tháng này ở đây là tự đổi thứ người dùng đang xem chỉ vì họ bấm nhầm
      // rồi thoát ra.
      return;
    }
    widget.onChon(Ky.tuyChon(
      from: DateTime(chon.start.year, chon.start.month, chon.start.day),
      // `day + 1` để ngày cuối họ chọn nằm TRONG kỳ, và nó tự cuộn qua cuối
      // tháng, cuối năm và 29/02 năm nhuận.
      to: DateTime(chon.end.year, chon.end.month, chon.end.day + 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ds = cacKyGanNhat(widget.moc, _donVi);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'CHỌN PHẠM VI',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        // Cuộn ngang: năm chip tiếng Việt có dấu không vừa 411dp khi font hệ
        // thống lớn, và bọc xuống hàng hai làm sheet nhảy chiều cao mỗi lần đổi
        // cỡ chữ.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final (dv, ten) in _thuTu) ...[
                _Chip(
                  ten: ten,
                  bat: _donVi == dv,
                  onTap: () {
                    if (dv == DonViKy.tuyChon) {
                      _chonKhoangTuyY();
                      return;
                    }
                    setState(() => _donVi = dv);
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.outlineVariant),
        // ⚠️ Chiều cao CỐ ĐỊNH, không co theo số dòng. Mỗi đơn vị có số kỳ khác
        // nhau (12 tuần, 8 quý, 5 năm), nên để danh sách tự co là sheet nhảy
        // chiều cao mỗi lần đổi chip — và vì sheet neo ở đáy, **hàng chip trượt
        // xuống dưới ngón tay**: cú chạm tiếp theo rơi vào lớp phủ và đóng
        // sheet. Vấp thật trên máy ảo 2026-09-15, trong khi widget test xanh vì
        // ở đó sheet bị bọc trong một khung cao cố định sẵn.
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.45,
          child: ds.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Chọn "Tuỳ chọn" để nhập một khoảng ngày bất kỳ.',
                    style:
                        TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [for (final k in ds) _dong(k)],
                ),
        ),
      ],
    );
  }

  Widget _dong(Ky k) {
    final dangXem = k == widget.kyHienTai;
    // Dòng của kỳ chứa hôm nay mang tiền tố "… này" — cùng luật với ô trên
    // header, và `nhanOChon` là chỗ duy nhất định nghĩa nó.
    final nhan = k.chua(widget.moc) ? nhanOChon(k, widget.moc) : k.nhan;

    return InkWell(
      onTap: () => widget.onChon(k),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                nhan,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: dangXem ? FontWeight.w700 : FontWeight.w400,
                  color: dangXem
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (dangXem)
              const Icon(Icons.check, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String ten;
  final bool bat;
  final VoidCallback onTap;

  const _Chip({required this.ten, required this.bat, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bat ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: bat ? AppColors.primary : AppColors.outlineVariant,
            ),
          ),
          child: Text(
            ten,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: bat ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      );
}
