/// Khối "khoi_co_cau" của trang Phân tích — tách từ `analytics_page.dart` ngày 2026-10-10 (spec bịt điểm rò mục 5.1).
/// Dời nguyên văn, chỉ đổi tên riêng tư → công khai; trạng thái và thứ tự cụm vẫn ở trang.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/category/category_classify.dart';
import '../../../../../core/category/category_visuals.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/analytics_repository.dart';
import '../../../domain/phan_loai_dong_tien.dart';
import '../../../domain/thong_ke_thang.dart';
import '../../bloc/analytics_cubit.dart';
import 'chung.dart';

/// Số dòng danh mục dựng thẳng trên trang; phần còn lại vào bảng "Xem tất cả".
/// Cùng lý do với lịch sử mục tiêu: danh sách ở đây không ảo hoá.
const int soDongToiDa = 5;

class KhoiDonut extends StatelessWidget {
  final ThongKeKy tk;
  final String phanLoaiDangXem;
  const KhoiDonut({super.key, required this.tk, required this.phanLoaiDangXem});

  @override
  Widget build(BuildContext context) {
    if (tk.latPhanLoai.isEmpty) return const SizedBox.shrink();
    // Chip theo thứ tự CỐ ĐỊNH của `kCategoryClassifies`, không theo số tiền:
    // chip đổi chỗ khi số đổi là người dùng bấm nhầm nhóm.
    final nhom = [
      for (final pl in kCategoryClassifies)
        if (tk.latPhanLoai.any((l) => l.phanLoai == pl)) pl,
    ];
    final v = _mucDanhMuc(phanLoaiDangXem);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Một Text đứng trong Row không co được: chiếm hết chiều ngang, nếu
          // không tiêu đề tràn (test 411dp bắt được).
          const SizedBox(
            width: double.infinity,
            child: Text(
              'Cơ cấu theo danh mục',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pl in nhom)
                ChoiceChip(
                  key: Key('chip-nhom-$pl'),
                  label: Text(tenLat(pl)),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: pl == phanLoaiDangXem
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                  selected: pl == phanLoaiDangXem,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: pl == phanLoaiDangXem
                        ? AppColors.primary
                        : AppColors.outlineVariant,
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (_) =>
                      context.read<AnalyticsCubit>().chonPhanLoai(pl),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 32,
              runSpacing: 24,
              children: [
                Donut(
                  lat: v.lat,
                  mau: v.mau,
                  nhan: v.nhanTam,
                  tong: v.tongTam,
                ),
                SizedBox(
                  width: 180,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < v.lat.length; i++)
                        ChuGiaiDonut(mau: v.mau[i], nhan: v.ten[i]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Danh mục bên trong một nhóm, top 4 + "Khác".
  NoiDungDonut _mucDanhMuc(String pl) {
    final dong = tk.danhMucCua(pl);
    final tong = dong.fold<double>(0, (s, d) => s + d.soTien);
    final lat = topVaKhac([
      for (final d in dong)
        ChiTheoDanhMuc(
          categoryId: d.categoryId,
          soTien: d.soTien,
          tiLe: tong <= 0 ? 0 : d.soTien / tong,
        ),
    ]);
    final tra = {for (final d in dong) d.categoryId: d};
    return (
      lat: lat,
      mau: [
        for (final l in lat) l.laKhac ? mauKhac : mauCua(tra[l.categoryId]),
      ],
      ten: [
        for (final l in lat)
          l.laKhac ? 'Khác' : (tra[l.categoryId]?.ten ?? 'Chưa phân loại'),
      ],
      nhanTam: nhanTongCua(pl).toUpperCase(),
      tongTam: tong,
    );
  }
}

/// Mọi thứ khối donut cần vẽ cho một nhóm.
typedef NoiDungDonut = ({
  List<ChiTheoDanhMuc> lat,
  List<Color> mau,
  List<String> ten,
  String nhanTam,
  double tongTam,
});

class Donut extends StatelessWidget {
  final List<ChiTheoDanhMuc> lat;
  final List<Color> mau;

  /// Nhãn nhỏ ở tâm — "TỔNG CHI" / "TỔNG THU" / "VAY/NỢ" theo nhóm đang
  /// chọn. Luôn có một nhóm, nên không còn nhãn chung nào.
  final String nhan;
  final double tong;

  const Donut({
    super.key,
    required this.lat,
    required this.mau,
    required this.nhan,
    required this.tong,
  });

  @override
  Widget build(BuildContext context) {
    // Mỗi lát hai stop cùng màu để có cạnh sắc; tổng tỉ lệ có thể hụt 1.0 vì
    // làm tròn, phần hụt tô màu nền để vòng không hở.
    final stops = <double>[];
    final colors = <Color>[];
    var dau = 0.0;
    for (var i = 0; i < lat.length; i++) {
      final cuoi = (dau + lat[i].tiLe).clamp(0.0, 1.0);
      stops
        ..add(dau)
        ..add(cuoi);
      colors
        ..add(mau[i])
        ..add(mau[i]);
      dau = cuoi;
    }
    if (dau < 1.0) {
      stops
        ..add(dau)
        ..add(1.0);
      colors
        ..add(AppColors.surfaceContainer)
        ..add(AppColors.surfaceContainer);
    }

    return SizedBox(
      width: 192,
      height: 192,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(stops: stops, colors: colors),
            ),
          ),
          Container(
            width: 154,
            height: 154,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  nhan,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rutGon(tong),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChuGiaiDonut extends StatelessWidget {
  final Color mau;
  final String nhan;
  const ChuGiaiDonut({super.key, required this.mau, required this.nhan});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: mau,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(
            nhan,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Chi tiết danh mục ─────────────────────────────────────────────────────

class DanhSachDanhMuc extends StatelessWidget {
  final ThongKeKy tk;

  /// Nhóm đang chọn ở donut — luôn có một nhóm, mức gốc đã bỏ (2026-09-14).
  final String phanLoai;
  const DanhSachDanhMuc({super.key, required this.tk, required this.phanLoai});

  /// Nguồn dòng: **đi theo donut** để hai khối luôn nói cùng một con số. Hai
  /// chỗ đọc hai nguồn khác nhau là donut nói 8.2M mà danh sách cộng ra 8.5M.
  List<DongDanhMuc> get _dong => tk.danhMucCua(phanLoai);

  /// Mẫu số của nhãn "% …" trong từng dòng.
  String get _nhomTiLe => phanLoai;

  @override
  Widget build(BuildContext context) {
    final dong = _dong;
    if (dong.isEmpty) return const SizedBox.shrink();
    final hien = dong.take(soDongToiDa).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CHI TIẾT DANH MỤC',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (dong.length > soDongToiDa)
              TextButton(
                onPressed: () => _moBang(context),
                child: const Text(
                  'Xem tất cả',
                  style: TextStyle(
                    color: AppColors.income,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final d in hien) DongDanhMucTrang(d: d, phanLoai: _nhomTiLe),
      ],
    );
  }

  /// Bottom sheet, không phải trang mới — cùng lý do với lịch sử mục tiêu:
  /// route mới phải trả lời "nằm trong shell không", đặt nhầm là màn đỏ.
  void _moBang(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Chi tiết danh mục',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            for (final d in _dong) DongDanhMucTrang(d: d, phanLoai: _nhomTiLe),
          ],
        ),
      ),
    );
  }
}

class DongDanhMucTrang extends StatelessWidget {
  final DongDanhMuc d;

  /// Nhóm chứa dòng này; quyết định mẫu số của nhãn "% …". Mặc định `'chi'`
  /// vì đó cũng là nhóm trang mở sẵn.
  final String phanLoai;
  const DongDanhMucTrang({super.key, required this.d, this.phanLoai = 'chi'});

  @override
  Widget build(BuildContext context) {
    final mau = mauCua(d);
    // Có ngân sách thì đo theo hạn mức; không thì theo tổng chi — và ĐỔI nhãn,
    // không hiện "0% ngân sách" cho một hạn mức không tồn tại.
    final tiLe = d.coNganSach ? d.tiLeNganSach! : d.tiLeTongChi;
    final nhan = d.coNganSach
        ? '${(tiLe * 100).round()}% ngân sách'
        : '${(tiLe * 100).round()}% ${nhanTongCua(phanLoai)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: theTrang(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(categoryIconFor(d.icon), color: mau),
          ),
          const SizedBox(width: 16),
          // Expanded + ellipsis: bản Stitch chép sang đặt tên trong một Row
          // không giới hạn bề rộng, tên dài tràn 521px qua cột số tiền — test
          // 411dp bắt được đúng ca ấy.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.ten,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nhan,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                chuoiTien(d.soTien),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 80,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: tiLe.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: mau,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
