/// Khối "khoi_tong" của trang Phân tích — tách từ `analytics_page.dart` ngày 2026-10-10 (spec bịt điểm rò mục 5.1).
/// Dời nguyên văn, chỉ đổi tên riêng tư → công khai; trạng thái và thứ tự cụm vẫn ở trang.
library;

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/phan_tram.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../ai_edge/domain/goi_so_phan_tich.dart';
import '../../../../ai_edge/presentation/widgets/khoi_nhan_xet.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../data/models/thong_ke_ky.dart';
import '../../../domain/dong_tien_tu_do.dart';
import '../../../domain/moc_so_sanh.dart';
import '../../../../premium/domain/cau_quyen.dart';
import '../../../../premium/domain/quyen_tinh_nang.dart';
import '../../../../premium/presentation/bloc/co_quyen.dart';
import '../../../../premium/presentation/widgets/the_khoa_quyen.dart';
import '../../../domain/thong_ke_thang.dart';
import '../../bloc/analytics_cubit.dart';
import 'chung.dart';

/// "Tăng 25% so với T8" / "Giảm 5% so với Tuần 37" / "Không có dữ liệu T9 2025".
///
/// [nhan] là **tên kỳ nền**, do `nenSoSanh` cấp cùng lúc với con số của nó — từ
/// 2026-09-16 nền có thể là kỳ liền trước **hoặc** cùng kỳ năm trước, và một
/// hàm tự suy tên từ `ky` sẽ nói sai ngay khi người dùng chạm chip thứ hai.
///
/// [phanTram] `null` là nền bằng 0: không in "tăng ∞%" hay "tăng 100%" — cả hai
/// đều là số bịa. ⚠️ Với mốc năm trước thì đây là ca **thường**, không phải ca
/// hiếm: mọi tài khoản chưa đủ một năm tuổi đều rơi vào đó ở mọi kỳ.
String soVoiNen(double? phanTram, String nhan) {
  if (phanTram == null) return 'Không có dữ liệu $nhan';
  final tu = phanTram >= 0 ? 'Tăng' : 'Giảm';
  return '$tu ${phanTram.abs().round()}% so với $nhan';
}

// ── Đầu trang ─────────────────────────────────────────────────────────────

class KhoiTong extends StatelessWidget {
  final ThongKeKy tk;
  final MocSoSanh mocSoSanh;
  const KhoiTong({super.key, required this.tk, required this.mocSoSanh});

  @override
  Widget build(BuildContext context) {
    // Nền so sánh và TÊN của nó lấy cùng một chỗ — `nenSoSanh` là định nghĩa
    // duy nhất. Lấy số một nơi và nhãn một nơi thì thẻ nói một câu hoàn toàn
    // hợp lý và hoàn toàn sai.
    final nen = nenSoSanh(
      moc: mocSoSanh,
      ky: tk.ky,
      kyTruoc: tk.tongTruoc,
      namTruoc: tk.tongNamTruoc,
    );
    return Column(
      children: [
        const HangChipSoSanh(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TheTong(
                title: 'Tổng thu',
                // `formatCoDau` chứ không nối dấu bằng tay: **số 0 không mang
                // dấu**. Kỳ không có khoản thu (hoặc chi) nào là ca thường từ
                // khi trang xem được năm đơn vị, và `-0 đ` đọc như một con số
                // âm bằng không. Cùng luật đã áp cho bảng "Phân bổ theo ví"
                // (2026-09-15) và thẻ tổng trang Sổ giao dịch (2026-09-21).
                amount: CurrencyFormatter.formatCoDau(tk.tong.thu, thu: true),
                diff:
                    soVoiNen(phanTramSoVoi(tk.tong.thu, nen.nen.thu), nen.nhan),
                icon: Icons.arrow_upward,
                color: AppColors.income,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TheTong(
                title: 'Tổng chi',
                amount: CurrencyFormatter.formatCoDau(tk.tong.chi, thu: false),
                diff:
                    soVoiNen(phanTramSoVoi(tk.tong.chi, nen.nen.chi), nen.nhan),
                icon: Icons.arrow_downward,
                color: AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TheConLai(tk: tk),
        // Khối Nhận xét (Edge-SLM P2, A6): gói số đọc `tk` qua đúng các hàm
        // ba thẻ trên đang dùng, nên câu khớp con số của thẻ.
        const SizedBox(height: 16),
        // Quyền `anomaly_spending_insights`: không có → gói bỏ câu chi bất thường; khi THẬT có bất thường thì một dòng
        // khoá trong khối thay vào (không có thì im — không quảng cáo suông).
        Builder(builder: (context) {
          final khoaBt = !context.coQuyen(MaQuyen.anomalySpendingInsights);
          final coBt = tk.chiBatThuong?.isNotEmpty ?? false;
          return KhoiNhanXet(
            goi: GoiSoPhanTich.tu(tk, boChiBatThuong: khoaBt),
            chanDuoi: khoaBt && coBt
                ? const DongKhoaQuyen(
                    key: Key('dong-khoa-bat-thuong'),
                    ma: MaQuyen.anomalySpendingInsights,
                    cau: kDongKhoaChiBatThuong,
                  )
                : null,
          );
        }),
      ],
    );
  }
}

/// Hai chip chọn mốc so sánh của hai thẻ tổng (#2 khảo sát, 2026-09-16).
///
/// Đứng **trên** hai thẻ chứ không thêm dòng vào trong chúng: thẻ chỉ rộng
/// chừng 180dp ở khổ 411dp, và chỗ này từng tràn 53px một lần rồi.
class HangChipSoSanh extends StatelessWidget {
  const HangChipSoSanh({super.key});

  @override
  Widget build(BuildContext context) {
    final moc = context.select<AnalyticsCubit, MocSoSanh?>((c) {
      final s = c.state;
      return s is AnalyticsLoaded ? s.mocSoSanh : null;
    });
    if (moc == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final m in MocSoSanh.values)
            ChoiceChip(
              label: Text(m.nhanChip),
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: m == moc ? Colors.white : AppColors.textPrimary,
              ),
              selected: m == moc,
              showCheckmark: false,
              selectedColor: AppColors.textPrimary,
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.outlineVariant),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onSelected: (_) =>
                  context.read<AnalyticsCubit>().chonMocSoSanh(m),
            ),
        ],
      ),
    );
  }
}

class TheTong extends StatelessWidget {
  final String title;
  final String amount;
  final String diff;
  final IconData icon;
  final Color color;

  const TheTong({
    super.key,
    required this.title,
    required this.amount,
    required this.diff,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            diff,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class TheConLai extends StatelessWidget {
  final ThongKeKy tk;
  const TheConLai({super.key, required this.tk});

  @override
  Widget build(BuildContext context) {
    final conLai = tk.tong.conLai;
    // Thanh = phần thu còn giữ được. Thu bằng 0 thì không có gì để chia.
    final tiLe = tk.tong.thu > 0 ? (conLai / tk.tong.thu).clamp(0.0, 1.0) : 0.0;

    // Tỉ lệ tiết kiệm (2026-09-15, mục 3.26). Mẫu số là **thu nhập** — đã trừ
    // tiền đi vay và thu nợ — chứ không phải `tong.thu`; phép tính ở tầng thuần
    // và dùng chung với khối "Dòng tiền tự do". Chuỗi rỗng thì bỏ qua: không có
    // gì để suy ra phần vay/nợ của kỳ, và đoán bừa là bịa một con số.
    final double? thuNhap = tk.chuoiVayNo.isEmpty
        ? null
        : thuNhapCua(tong: tk.tong, vayNo: tk.chuoiVayNo.last);
    final double? tyLe = thuNhap == null
        ? null
        : tyLeTietKiem(thuNhap: thuNhap, chi: tk.tong.chi);
    // G56: chi từ 2 lần thu nhập trở lên thì nói "gấp N lần" — "Để dành
    // -26360% thu nhập" (tuần thu nhập gần 0, Realme) đúng mà không đọc được.
    final gapLan = thuNhap == null
        ? null
        : soLanChiGapThuNhap(thuNhap: thuNhap, chi: tk.tong.chi);
    // Số ÂM hiện là số âm, không kẹp về 0: người dùng mở trang này chính là
    // để biết tháng này đã âm.
    final chu = conLai < 0 ? '-${chuoiTien(-conLai)}' : chuoiTien(conLai);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: theTrang(color: AppColors.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Số dư còn lại',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            chu,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: conLai < 0 ? const Color(0xFFFFB3AE) : Colors.white,
            ),
          ),
          // Dòng này **ẩn hẳn** khi không có thu nhập, không in "0%": xem
          // `tyLeTietKiem`. Đứng ngay dưới con số vì nó diễn giải chính con số
          // ấy — cùng tử số, chỉ khác chỗ là mẫu số đã trừ phần vay/nợ.
          if (tyLe != null) ...[
            const SizedBox(height: 4),
            Text(
              gapLan != null
                  ? 'Chi gấp ${chuoiSoLan(gapLan)} lần thu nhập'
                  : 'Để dành ${chuPhanTram(tyLe)} thu nhập',
              style: TextStyle(
                fontSize: 12,
                color: tyLe < 0 ? const Color(0xFFFFB3AE) : Colors.white70,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: tiLe,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF94F990), // secondary-fixed của Stitch
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Xu hướng theo thời gian ───────────────────────────────────────────────
