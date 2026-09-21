import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/current_account.dart';
import '../../../ai_edge/domain/goi_so_phan_tich.dart';
import '../../../ai_edge/presentation/widgets/khoi_nhan_xet.dart';
import '../../../../core/category/category_classify.dart';
import '../../../../core/category/category_visuals.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/analytics_repository.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/bao_cao_xuat.dart';
import '../../domain/dong_tien_tu_do.dart';
import '../../domain/du_bao_dong_tien.dart';
import '../../domain/lich_chi_tieu.dart';
import '../../domain/moc_so_sanh.dart';
import '../../domain/pham_vi_ky.dart';
import '../../domain/vai_vay_no.dart';
import '../../domain/phan_loai_dong_tien.dart';
import '../../domain/thac_nuoc.dart';
import '../../domain/thong_ke_thang.dart';
import '../../domain/tong_tai_san.dart';
import '../bloc/analytics_cubit.dart';
import '../widgets/chon_pham_vi_sheet.dart';

/// Trang Phân tích — bố cục theo màn Stitch `c2a2b615c9514ca180b28d189b2ea197`
/// *"Thống kê - Xu hướng 6 tháng & Cơ cấu dòng tiền"* (2026-09-14).
///
/// ⚠️ **Không** phải màn cũ `a228fa69…` *"FlowMoney Analytics Dashboard"*: nó
/// vẫn còn trong dự án Stitch nhưng đã lỗi thời, vì `edit_screens` **tạo màn
/// mới** chứ không sửa màn được chọn.
///
/// Trước 2026-09-08 trang này là **số cứng**: mọi con số là hằng số, kể cả
/// tháng đang hiện ("T6 2026" khi đang là tháng 9). Nay mọi thứ đi qua
/// [AnalyticsCubit]; widget không tự cộng gì cả.
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ĐĂNG KÝ với AuthBloc, không chỉ đọc một phát — cùng lỗi G17 ở trang Mục
    // tiêu: `currentAccountIdOrNull` dùng `context.read` bên trong (không đăng
    // ký), và `BlocProvider.create` chỉ chạy MỘT lần. Phiên tới muộn thì cubit
    // nhận `null` rồi không bao giờ hỏi lại. `ValueKey(idaccount)` buộc dựng
    // lại provider khi phiên đổi.
    context.watch<AuthBloc>();
    final idaccount = currentAccountIdOrNull(context);

    return BlocProvider<AnalyticsCubit>(
      key: ValueKey(idaccount),
      create: (_) => sl<AnalyticsCubit>()..xem(idaccount),
      child: const _NoiDung(),
    );
  }
}

/// Màu lát "Khác" và màu dự phòng khi danh mục không có màu.
const Color _mauKhac = Color(0xFF586062);
const Color _mauXanhLa = Color(0xFF2E6B27);

/// Màu của một dòng. Ba ca không có màu thật phải ra BA màu khác nhau: trên
/// máy thật, "Chưa phân loại" và "Danh mục đã xoá" từng cùng xanh dự phòng nên
/// hai lát donut không phân biệt được — test không bắt vì nó không nhìn màu.
Color _mauCua(DongDanhMuc? d) {
  if (d == null || d.categoryId == null) return AppColors.textSecondary;
  if (d.mauHex == null) return AppColors.outline; // id có, hàng không còn
  return categoryColorFrom(d.mauHex, fallback: _mauXanhLa);
}

/// Số dòng danh mục dựng thẳng trên trang; phần còn lại vào bảng "Xem tất cả".
/// Cùng lý do với lịch sử mục tiêu: danh sách ở đây không ảo hoá.
const int _soDongToiDa = 5;

class _NoiDung extends StatelessWidget {
  const _NoiDung();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<AnalyticsCubit, AnalyticsState>(
          builder: (context, state) {
            return SingleChildScrollView(
              // Đệm đáy 96 chứ không 8: FAB của MainShell đè lên dòng cuối
              // (thấy trên máy thật — chú giải "Khác" nằm dưới nút cộng).
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(state: state),
                  const SizedBox(height: 24),
                  ..._than(context, state),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _than(BuildContext context, AnalyticsState state) {
    switch (state) {
      case AnalyticsLoaded(
          :final thongKe,
          :final phanLoaiDangXem,
          :final danhMucXuHuong,
          :final mocSoSanh
        ):
        if (thongKe.rong) {
          return [
            _Rong(ky: thongKe.ky),
            // Dự báo KHÔNG nói về kỳ đang xem. Kỳ rỗng — ngày đầu tháng, hay
            // một tháng cũ không có giao dịch — vẫn là lúc người dùng cần
            // biết 30 ngày tới có gì phải trả.
            if (thongKe.duBao != null) ...[
              const SizedBox(height: 24),
              _KhoiDuBao(duBao: thongKe.duBao),
            ],
          ];
        }
        // Thứ tự khối chép đúng trang Xuất báo cáo (P2, 2026-09-15) — hai
        // trang cùng dữ liệu thì phải kể cùng một câu chuyện, theo cùng một
        // trình tự. Thứ tự câu hỏi vẫn đọc ra được: tiền ở đâu → bao nhiêu →
        // xu hướng ra sao → tiêu thế nào → đi vào đâu → từ ví nào → khoản nào.
        return [
          if (thongKe.dongTien != null) ...[
            _KhoiDongTien(dt: thongKe.dongTien!),
            const SizedBox(height: 24),
            // Thác nước đứng ngay sau khối dòng tiền: nó kể **chi tiết** đúng
            // hai con số mà khối trên vừa nêu — đầu kỳ và cuối kỳ — nên tách
            // hai khối ra xa nhau là bắt người đọc nhớ số rồi cuộn đi tìm.
            _KhoiThacNuoc(tk: thongKe),
            const SizedBox(height: 24),
          ],
          _KhoiTong(tk: thongKe, mocSoSanh: mocSoSanh),
          const SizedBox(height: 24),
          // Ngay sau thẻ tổng: "còn tiêu được 30 ngày tới" đứng cạnh "số dư
          // còn lại" của kỳ — hiện tại rồi tới tương lai, mắt đọc liền mạch.
          // Chốt hai lớp: `if` ở đây và guard `null` trong widget.
          if (thongKe.duBao != null) ...[
            _KhoiDuBao(duBao: thongKe.duBao),
            const SizedBox(height: 24),
          ],
          _KhoiXuHuong(tk: thongKe, danhMucXuHuong: danhMucXuHuong),
          const SizedBox(height: 24),
          // Đứng ngay sau khối Xu hướng: cùng dạng đường, cùng sáu kỳ, và nó
          // trả lời tiếp đúng câu hỏi khối trên vừa đặt — "thu về bấy nhiêu thì
          // thực sự còn lại bao nhiêu".
          _KhoiDongTienTuDo(tk: thongKe),
          const SizedBox(height: 24),
          // Đường thứ BA của bộ sáu kỳ, đứng ngay sau hai đường kia: cùng dạng
          // biểu đồ, cùng trục hoành, cùng số kỳ — mắt học trục một lần rồi đọc
          // được cả ba. Nó cũng khép lại mạch mà hai khối trên mở ra: "thu về
          // bấy nhiêu → thực còn bấy nhiêu → dồn lại thì tài sản đi về đâu".
          //
          // Chốt lớp thứ nhất: chuỗi rỗng thì không dựng. Lớp thứ hai nằm
          // trong chính widget; bản sai phải phá cả hai mới làm test đỏ.
          if (thongKe.taiSan.isNotEmpty) ...[
            _KhoiTongTaiSan(tk: thongKe),
            const SizedBox(height: 24),
          ],
          _KhoiSoLieuNhanh(tk: thongKe),
          // Lịch chi tiêu đứng ngay sau Số liệu nhanh: nó kể **chi tiết** đúng
          // con số mà khối trên vừa nêu — "ngày chi nhiều nhất" — và hai khối
          // đọc chung một phép gom theo ngày.
          //
          // ⚠️ Chốt lớp thứ nhất: chỉ hiện khi đơn vị là **Tháng**. Lớp thứ hai
          // nằm trong chính widget; bản sai phải phá cả hai mới làm test đỏ.
          if (thongKe.ky.donVi == DonViKy.thang) ...[
            const SizedBox(height: 24),
            _KhoiLich(tk: thongKe),
          ],
          const SizedBox(height: 24),
          _KhoiDonut(tk: thongKe, phanLoaiDangXem: phanLoaiDangXem),
          const SizedBox(height: 24),
          _DanhSachDanhMuc(tk: thongKe, phanLoai: phanLoaiDangXem),
          if (thongKe.theoVi.isNotEmpty) ...[
            const SizedBox(height: 24),
            _KhoiTheoVi(ds: thongKe.theoVi),
          ],
          if (thongKe.topChi.isNotEmpty) ...[
            const SizedBox(height: 24),
            _KhoiTopChi(ds: thongKe.topChi),
          ],
          // Hai biểu đồ vay/nợ đứng CUỐI: phần lớn người dùng không ghi khoản
          // vay/nợ nào, và khi ấy chúng không hiện — đặt ở giữa trang thì mỗi
          // lần cuộn qua là một khoảng trống không giải thích được.
          if (coVayNo(thongKe.chuoiVayNo, chieuRa: true)) ...[
            const SizedBox(height: 24),
            _KhoiVayNo(
              tieuDe: 'Cho vay & Thu nợ',
              ds: thongKe.chuoiVayNo,
              sau: _CotVayNo.choVay,
              truoc: _CotVayNo.thuNo,
            ),
          ],
          if (coVayNo(thongKe.chuoiVayNo, chieuRa: false)) ...[
            const SizedBox(height: 24),
            _KhoiVayNo(
              tieuDe: 'Đi vay & Trả nợ',
              ds: thongKe.chuoiVayNo,
              sau: _CotVayNo.diVay,
              truoc: _CotVayNo.traNo,
            ),
          ],
          if (thongKe.chuoiVayNo.any((d) => d.khacRa > 0 || d.khacVao > 0)) ...[
            const SizedBox(height: 24),
            _KhoiVayNoKhac(ds: thongKe.chuoiVayNo),
          ],
        ];
      case AnalyticsError(:final message):
        return [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ];
      default:
        return const [
          Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
    }
  }
}

// ── Định dạng dùng chung ──────────────────────────────────────────────────

String _dong(double x) => CurrencyFormatter.format(x);

/// "Tăng 25% so với T8" / "Giảm 5% so với Tuần 37" / "Không có dữ liệu T9 2025".
///
/// [nhan] là **tên kỳ nền**, do `nenSoSanh` cấp cùng lúc với con số của nó — từ
/// 2026-09-16 nền có thể là kỳ liền trước **hoặc** cùng kỳ năm trước, và một
/// hàm tự suy tên từ `ky` sẽ nói sai ngay khi người dùng chạm chip thứ hai.
///
/// [phanTram] `null` là nền bằng 0: không in "tăng ∞%" hay "tăng 100%" — cả hai
/// đều là số bịa. ⚠️ Với mốc năm trước thì đây là ca **thường**, không phải ca
/// hiếm: mọi tài khoản chưa đủ một năm tuổi đều rơi vào đó ở mọi kỳ.
String _soVoiNen(double? phanTram, String nhan) {
  if (phanTram == null) return 'Không có dữ liệu $nhan';
  final tu = phanTram >= 0 ? 'Tăng' : 'Giảm';
  return '$tu ${phanTram.abs().round()}% so với $nhan';
}

// ── Đầu trang ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final AnalyticsState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    // Trái co, phải giữ: ở 411dp thì "Thống kê" + nút xuất + ô chọn tháng
    // không đủ chỗ (tràn 53px trên máy ảo). Tiêu đề nhường trước vì nó là
    // thứ người dùng đã biết; ô chọn tháng mới là thứ họ cần đọc được.
    // Không có icon menu: bản trước vẽ một `Icon` trần trông hệt hamburger mở
    // drawer của Trang chủ, mà trang này không có drawer và icon không bọc nút
    // nào — bấm không xảy ra gì (UX 2026-09-19, A2).
    return Row(
      children: [
        // Tỉ lệ 1:2, KHÔNG phải Expanded + Flexible bằng nhau: flex chia chỗ
        // trống theo hệ số bất kể con cần bao nhiêu, nên bản đầu cho tiêu đề
        // một nửa trong khi nó chỉ cần ~95px — và ô tháng bị cắt thành
        // "Tháng này (…" trên máy thật dù test 411dp xanh (font test khác
        // font thật, bẫy 4.4 `ANALYTICS_FEATURE.md`).
        const Flexible(
          flex: 2,
          child: Text(
            // Một đích một tên (D4, 2026-09-19): tab gọi là "Phân tích" nên
            // tiêu đề trang cũng thế. Drawer đã thôi có mục "Thống kê", nên
            // không còn chỗ thứ hai nào gọi trang này bằng tên khác.
            // Đúng 9 ký tự như tên cũ, nên phép đo bề rộng ở chú thích ngay
            // trên không đổi.
            'Phân tích',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        // Nút gọn 40px thay vì 48px mặc định: ở 411dp thật, tiêu đề 24px +
        // nút + nhãn tháng đầy đủ thiếu đúng vài chục px, và flex chia kiểu gì
        // cũng phải cắt một trong hai chữ. Bớt chỗ chiếm cố định mới là cách.
        IconButton(
          icon: const Icon(Icons.download, color: AppColors.primary),
          onPressed: () => context.push('/analytics/export'),
          tooltip: 'Xuất Báo cáo',
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        Flexible(flex: 3, child: _ChonPhamVi(state: state)),
      ],
    );
  }
}

/// Ô chọn phạm vi. Nhãn "Tháng này (T9 2026)" chỉ khi kỳ đang xem chứa hôm nay;
/// kỳ đã qua thì "T8 2026" — giữ "Tháng này" cho một tháng đã qua là nói dối về
/// thứ đang hiện. Luật ấy có một chỗ định nghĩa: `nhanOChon`.
///
/// Bấm vào mở bottom sheet hai tầng chứ không phải menu một tầng: từ 2026-09-15
/// có năm đơn vị, và một danh sách phẳng trộn tuần lẫn quý thì không ai đọc
/// được. Ô này **không đổi kích thước**, nên không đụng lại bài toán tràn 53px
/// của hàng header.
class _ChonPhamVi extends StatelessWidget {
  final AnalyticsState state;
  const _ChonPhamVi({required this.state});

  @override
  Widget build(BuildContext context) {
    final (nhan, ky, moc) = switch (state) {
      AnalyticsLoaded(:final thongKe, :final moc) => (
          nhanOChon(thongKe.ky, moc),
          thongKe.ky,
          moc,
        ),
      AnalyticsLoading(:final ky) => (ky.nhanNgan, null, null),
      _ => ('Tháng này', null, null),
    };

    final o = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              nhan,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.expand_more, size: 16, color: AppColors.textSecondary),
        ],
      ),
    );

    // Chưa có dữ liệu thì ô chỉ là một nhãn: mở bộ chọn lúc chưa biết kỳ nào
    // đang xem sẽ vẽ một sheet không có dấu tích ở đâu cả.
    if (ky == null || moc == null) return o;

    return Semantics(
      button: true,
      label: 'Chọn phạm vi',
      child: InkWell(
        onTap: () async {
          final cubit = context.read<AnalyticsCubit>();
          final chon = await moChonPhamVi(context, kyHienTai: ky, moc: moc);
          // Đóng sheet TRƯỚC rồi mới đổi kỳ (`moChonPhamVi` pop rồi mới trả
          // về): gọi `chonKy` khi sheet còn đứng là nó nháy một khung dữ liệu
          // mới ngay trước lúc biến mất.
          if (chon != null) cubit.chonKy(chon);
        },
        borderRadius: BorderRadius.circular(8),
        child: o,
      ),
    );
  }
}

// ── Rỗng ──────────────────────────────────────────────────────────────────

class _Rong extends StatelessWidget {
  final Ky ky;
  const _Rong({required this.ky});

  @override
  Widget build(BuildContext context) {
    // Nói rỗng chứ không vẽ toàn số 0: donut của một tháng rỗng là một vòng
    // tròn xám với chữ "0" ở giữa — trông như lỗi tải dữ liệu.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.bar_chart_rounded,
                size: 48, color: AppColors.outline),
            const SizedBox(height: 12),
            Text(
              'Chưa có giao dịch nào trong ${ky.nhanNgan}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ba thẻ tổng ───────────────────────────────────────────────────────────

class _KhoiTong extends StatelessWidget {
  final ThongKeKy tk;
  final MocSoSanh mocSoSanh;
  const _KhoiTong({required this.tk, required this.mocSoSanh});

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
        const _HangChipSoSanh(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TheTong(
                title: 'Tổng thu',
                // `formatCoDau` chứ không nối dấu bằng tay: **số 0 không mang
                // dấu**. Kỳ không có khoản thu (hoặc chi) nào là ca thường từ
                // khi trang xem được năm đơn vị, và `-0 đ` đọc như một con số
                // âm bằng không. Cùng luật đã áp cho bảng "Phân bổ theo ví"
                // (2026-09-15) và thẻ tổng trang Sổ giao dịch (2026-09-21).
                amount: CurrencyFormatter.formatCoDau(tk.tong.thu, thu: true),
                diff: _soVoiNen(
                    phanTramSoVoi(tk.tong.thu, nen.nen.thu), nen.nhan),
                icon: Icons.arrow_upward,
                color: AppColors.income,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TheTong(
                title: 'Tổng chi',
                amount: CurrencyFormatter.formatCoDau(tk.tong.chi, thu: false),
                diff: _soVoiNen(
                    phanTramSoVoi(tk.tong.chi, nen.nen.chi), nen.nhan),
                icon: Icons.arrow_downward,
                color: AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _TheConLai(tk: tk),
        // Khối Nhận xét (Edge-SLM P2, A6): gói số đọc `tk` qua đúng các hàm
        // ba thẻ trên đang dùng, nên câu khớp con số của thẻ.
        const SizedBox(height: 16),
        KhoiNhanXet(goi: GoiSoPhanTich.tu(tk)),
      ],
    );
  }
}

/// Hai chip chọn mốc so sánh của hai thẻ tổng (#2 khảo sát, 2026-09-16).
///
/// Đứng **trên** hai thẻ chứ không thêm dòng vào trong chúng: thẻ chỉ rộng
/// chừng 180dp ở khổ 411dp, và chỗ này từng tràn 53px một lần rồi.
class _HangChipSoSanh extends StatelessWidget {
  const _HangChipSoSanh();

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

class _TheTong extends StatelessWidget {
  final String title;
  final String amount;
  final String diff;
  final IconData icon;
  final Color color;

  const _TheTong({
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
      decoration: _theTrang(),
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

class _TheConLai extends StatelessWidget {
  final ThongKeKy tk;
  const _TheConLai({required this.tk});

  @override
  Widget build(BuildContext context) {
    final conLai = tk.tong.conLai;
    // Thanh = phần thu còn giữ được. Thu bằng 0 thì không có gì để chia.
    final tiLe = tk.tong.thu > 0 ? (conLai / tk.tong.thu).clamp(0.0, 1.0) : 0.0;

    // Tỉ lệ tiết kiệm (2026-09-15, mục 3.26). Mẫu số là **thu nhập** — đã trừ
    // tiền đi vay và thu nợ — chứ không phải `tong.thu`; phép tính ở tầng thuần
    // và dùng chung với khối "Dòng tiền tự do". Chuỗi rỗng thì bỏ qua: không có
    // gì để suy ra phần vay/nợ của kỳ, và đoán bừa là bịa một con số.
    final double? tyLe = tk.chuoiVayNo.isEmpty
        ? null
        : tyLeTietKiem(
            thuNhap: thuNhapCua(tong: tk.tong, vayNo: tk.chuoiVayNo.last),
            chi: tk.tong.chi,
          );
    // Số ÂM hiện là số âm, không kẹp về 0: người dùng mở trang này chính là
    // để biết tháng này đã âm.
    final chu = conLai < 0 ? '-${_dong(-conLai)}' : _dong(conLai);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _theTrang(color: AppColors.primary),
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
              Icon(Icons.account_balance_wallet,
                  color: Colors.white, size: 20),
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
              'Để dành ${(tyLe * 100).round()}% thu nhập',
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

/// Sáu tháng gần nhất, hai đường: thu và chi.
///
/// **Cố ý lệch bản Stitch.** Màn "Analytics Dashboard" chỉ có donut, tức chỉ
/// trả lời *tiền đi đâu*; câu *đang tăng hay đang giảm* không có chỗ nào trên
/// trang trả lời. Khối này nằm giữa khối tổng và donut vì đó là thứ tự câu
/// hỏi: bao nhiêu → xu hướng ra sao → đi vào đâu. Đừng "sửa lại cho khớp
/// Stitch".
/// Biểu đồ đường sáu tháng — A8 #6 (hai đường Thu/Chi) và A8 #7 (tới
/// `kToiDaDuongXuHuong` đường danh mục, bật/tắt bằng chip).
///
/// ⓘ Khối này từng **lệch Stitch có chủ ý** (mục 3.12 `ANALYTICS_FEATURE.md`):
/// tra cả 35 màn ngày 2026-09-08, không màn nào có biểu đồ đường. Từ 2026-09-14
/// nó **đã có** trên Stitch — màn `c2a2b615c9514ca180b28d189b2ea197` — nên lý
/// do lệch đã hết hiệu lực.
class _KhoiXuHuong extends StatelessWidget {
  final ThongKeKy tk;

  /// Rỗng là hai đường Thu/Chi. Tối đa `kToiDaDuongXuHuong` phần tử — cubit
  /// chốt, ở đây chỉ vẽ.
  final Set<String> danhMucXuHuong;
  const _KhoiXuHuong({required this.tk, required this.danhMucXuHuong});

  @override
  Widget build(BuildContext context) {
    final chuoi = tk.chuoi;
    // Không điểm nào thì không có thang đo — bỏ khối, đừng chia cho 0.
    if (chuoi.isEmpty) return const SizedBox.shrink();

    // Cubit đã loại khoá không còn, nhưng khung dựng lại có thể tới trước —
    // chỉ vẽ những danh mục thật sự có chuỗi, đừng `!`. Sắp theo tên để thứ
    // tự đường, chú giải và tooltip là MỘT thứ tự: `lineBarsData[i]` chính là
    // `barIndex` của tooltip.
    final dong = <String, DongDanhMuc?>{
      for (final id in danhMucXuHuong)
        if (tk.chuoiDanhMuc.containsKey(id)) id: tk.dongCua(id),
    };
    String tenCua(String id) => dong[id]?.ten ?? 'Danh mục';
    final chon = dong.keys.toList()
      ..sort((a, b) =>
          tenCua(a).toLowerCase().compareTo(tenCua(b).toLowerCase()));
    final theoThuChi = chon.isEmpty;

    // Một danh mục thường chỉ đi một chiều tiền, nên đường của nó vẽ tổng thu
    // + chi. Riêng danh mục vay/nợ có cả hai chiều: cộng lại là "tổng tiền đi
    // qua danh mục", đúng câu hỏi "nó đang lớn lên hay nhỏ đi".
    double giaTri(DiemThoiGian d) => d.tong.thu + d.tong.chi;

    var dinh = 0.0;
    if (theoThuChi) {
      for (final d in chuoi) {
        if (d.tong.thu > dinh) dinh = d.tong.thu;
        if (d.tong.chi > dinh) dinh = d.tong.chi;
      }
    } else {
      for (final id in chon) {
        for (final d in tk.chuoiDanhMuc[id]!) {
          if (giaTri(d) > dinh) dinh = giaTri(d);
        }
      }
    }
    // Trần cao hơn đỉnh để đường không dính mép trên. Sáu tháng rỗng sạch thì
    // `dinh` bằng 0 và mọi phép chia thang đo sau đây sẽ hỏng, nên đặt 1.
    final buoc = (dinh <= 0 ? 1.0 : dinh * 1.15) / 3;
    // ⚠️ Trần phải là ĐÚNG ba lần `buoc`, không phải con số đã đem chia.
    // fl_chart vẽ nhãn cho cả mốc theo `interval` lẫn biên trên, mà hai thứ ấy
    // ở cùng một vị trí; `3 * (x / 3)` lệch `x` chừng 1e-14 trong dấu phẩy động,
    // đủ để `rutGon` trả hai chuỗi khác nhau khi giá trị rơi đúng ranh giới làm
    // tròn — và hai nhãn in đè khít lên nhau, không ai đọc được (G39, thấy
    // trên máy ảo 2026-09-14; bẫy 4.18 `ANALYTICS_FEATURE.md`).
    final maxY = buoc * 3;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cùng lý do với tiêu đề donut: Text đứng trong Row không co được.
          SizedBox(
            width: double.infinity,
            child: Text(
              tieuDeXuHuong(tk.ky.donVi),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ChonDanhMucXuHuong(tk: tk, dangChon: danhMucXuHuong),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: theoThuChi
                ? const [
                    _ChuGiaiDuong(mau: AppColors.income, ten: 'Thu'),
                    _ChuGiaiDuong(mau: AppColors.expense, ten: 'Chi'),
                  ]
                : [
                    for (final id in chon)
                      _ChuGiaiDuong(mau: _mauCua(dong[id]), ten: tenCua(id)),
                  ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (chuoi.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: buoc,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.outlineVariant,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: buoc,
                      // Số tiền rút gọn nên "123.5M" là chuỗi dài nhất; font
                      // của bộ test rộng gấp đôi ngoài đời nên chừa rộng tay.
                      reservedSize: 46,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          rutGon(v),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) {
                        final i = v.round();
                        // fl_chart hỏi cả những mốc ngoài dải khi vẽ lưới.
                        if (i < 0 || i >= chuoi.length) {
                          return const SizedBox.shrink();
                        }
                        // Tháng đang xem là điểm cuối — in đậm để biết mình
                        // đang đứng ở đâu trên trục.
                        final cuoi = i == chuoi.length - 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            chuoi[i].ky.nhanTruc,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  cuoi ? FontWeight.bold : FontWeight.normal,
                              color: cuoi
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primary,
                    // Bắt buộc: mặc định fl_chart đặt hộp giữa điểm chạm và
                    // để nó tràn ra ngoài. Chạm điểm cuối (tháng đang xem,
                    // sát mép phải) là hộp lòi khỏi màn hình và mất chữ —
                    // thấy trên máy ảo 411dp, không test nào bắt được vì
                    // tooltip vẽ trong canvas của thư viện.
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          theoThuChi
                              ? '${s.barIndex == 0 ? 'Thu' : 'Chi'} ${rutGon(s.y)}'
                              : '${tenCua(chon[s.barIndex])} ${rutGon(s.y)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                // Điểm ngoài dải vẫn được VẼ nếu không cắt — mặc định của
                // fl_chart là `FlClipData.none()` và đường tràn khỏi thẻ
                // (bẫy 4.17 `ANALYTICS_FEATURE.md`, chỉ lộ trên máy thật).
                // Đường danh mục có dải hẹp hơn nên dễ vấp hơn bản hai đường.
                clipData: const FlClipData.all(),
                lineBarsData: theoThuChi
                    ? [
                        _duong(
                          [
                            for (var i = 0; i < chuoi.length; i++)
                              FlSpot(i.toDouble(), chuoi[i].tong.thu),
                          ],
                          AppColors.income,
                        ),
                        _duong(
                          [
                            for (var i = 0; i < chuoi.length; i++)
                              FlSpot(i.toDouble(), chuoi[i].tong.chi),
                          ],
                          AppColors.expense,
                        ),
                      ]
                    : [
                        for (final id in chon)
                          _duong(
                            [
                              for (var i = 0;
                                  i < tk.chuoiDanhMuc[id]!.length;
                                  i++)
                                FlSpot(i.toDouble(),
                                    giaTri(tk.chuoiDanhMuc[id]![i])),
                            ],
                            _mauCua(dong[id]),
                          ),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Thứ tự trong `lineBarsData` **là** thứ tự `barIndex` của tooltip: đường
  /// thu phải đứng trước để nhãn "Thu"/"Chi" không đổi chỗ cho nhau.
  static LineChartBarData _duong(List<FlSpot> diem, Color mau) =>
      LineChartBarData(
        spots: diem,
        isCurved: true,
        curveSmoothness: 0.25,
        // Đường cong nội suy có thể vọt xuống dưới 0 giữa hai điểm, vẽ ra một
        // tháng "âm tiền" không có thật.
        preventCurveOverShooting: true,
        color: mau,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: 3.5,
            color: mau,
            strokeWidth: 2,
            strokeColor: Colors.white,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              mau.withValues(alpha: 0.25),
              mau.withValues(alpha: 0.0),
            ],
          ),
        ),
      );
}

/// Bộ chọn danh mục của khối xu hướng — A8 #7, chọn **nhiều** (từ 2026-09-14;
/// bản đầu là dropdown chọn một).
///
/// Hàng chip cuộn ngang **tại chỗ** — không màn mới, không bottom sheet — cố
/// ý. Trang này nằm trong `StatefulShellRoute`, và `push` một route trong
/// shell từ chỗ khác đã từng làm app chết màn đỏ (bẫy 7.8
/// `NOTIFICATION_FEATURE.md`).
///
/// Chỉ liệt kê danh mục **có phát sinh trong sáu tháng** đang vẽ: liệt kê tất
/// cả là bắt người dùng lướt qua hàng chục chip để tìm ra một đường phẳng
/// bằng 0.
///
/// Đủ trần `kToiDaDuongXuHuong` thì chip chưa bật bị **khoá** (`onSelected`
/// null) — người dùng thấy được vì sao, thay vì bấm mà không có gì xảy ra.
/// Chốt thật nằm ở cubit; khoá ở đây chỉ để nhìn thấy.
class _ChonDanhMucXuHuong extends StatelessWidget {
  final ThongKeKy tk;
  final Set<String> dangChon;
  const _ChonDanhMucXuHuong({required this.tk, required this.dangChon});

  @override
  Widget build(BuildContext context) {
    // Tên tra từ cả `danhMuc` (chi) lẫn các nhóm (thu, vay/nợ) — nếu không
    // thì danh mục thu có chuỗi mà không có tên, và hàng chip bỏ sót nó.
    final ten = <String, String>{};
    for (final d in tk.danhMuc) {
      if (d.categoryId != null) ten[d.categoryId!] = d.ten;
    }
    for (final ds in tk.danhMucTheoLat.values) {
      for (final d in ds) {
        if (d.categoryId != null) ten[d.categoryId!] = d.ten;
      }
    }
    final id = [
      for (final k in tk.chuoiDanhMuc.keys)
        if (k != null && ten.containsKey(k)) k,
    ]..sort((a, b) => ten[a]!.toLowerCase().compareTo(ten[b]!.toLowerCase()));

    if (id.isEmpty) return const SizedBox.shrink();

    final dayTran = dangChon.length >= kToiDaDuongXuHuong;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final k in id)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ChipDanhMuc(
                    chipKey: Key('chip-xu-huong-$k'),
                    ten: ten[k]!,
                    mau: _mauCua(tk.dongCua(k)),
                    dangBat: dangChon.contains(k),
                    // Đang bật thì luôn tắt được; chưa bật mà đủ trần thì khoá.
                    onChon: (!dangChon.contains(k) && dayTran)
                        ? null
                        : () => context
                            .read<AnalyticsCubit>()
                            .batTatDanhMucXuHuong(k),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Chọn tối đa $kToiDaDuongXuHuong danh mục · Bỏ chọn hết để xem Thu/Chi',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Một chip danh mục của hàng chọn: chấm màu + tên, đổi nền khi bật.
///
/// Bọc `FilterChip` để test tìm được `onSelected == null` (chip bị khoá) mà
/// không phải đọc màu.
class _ChipDanhMuc extends StatelessWidget {
  /// Đặt lên chính `FilterChip` (không phải widget bọc) để widget test
  /// `find.byKey` rồi đọc `onSelected` được.
  final Key chipKey;
  final String ten;
  final Color mau;
  final bool dangBat;
  final VoidCallback? onChon;
  const _ChipDanhMuc({
    required this.chipKey,
    required this.ten,
    required this.mau,
    required this.dangBat,
    required this.onChon,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      key: chipKey,
      avatar: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
      ),
      // Tên danh mục dài tới 200 ký tự (`DoRongCot`), phải cắt được ở 411dp.
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Text(ten, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: dangBat ? FontWeight.w600 : FontWeight.w500,
        color: dangBat ? AppColors.primary : AppColors.textSecondary,
      ),
      selected: dangBat,
      showCheckmark: false,
      selectedColor: mau.withValues(alpha: 0.16),
      backgroundColor: Colors.white,
      side: BorderSide(color: dangBat ? mau : AppColors.outlineVariant),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: onChon == null ? null : (_) => onChon!(),
    );
  }
}


class _ChuGiaiDuong extends StatelessWidget {
  final Color mau;
  final String ten;
  const _ChuGiaiDuong({required this.mau, required this.ten});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          ten,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Donut ─────────────────────────────────────────────────────────────────

/// Vòng tròn "Cơ cấu theo danh mục" — A8 #3.
///
/// Ba chip *Chi | Thu | Vay-nợ* chọn nhóm; vòng tròn vẽ các danh mục **bên
/// trong** nhóm ấy (top 4 + "Khác"), và danh sách cuối trang đi theo cùng lựa
/// chọn nên hai khối luôn nói cùng một con số.
///
/// Mức gốc ba lát theo phân loại (A8 #2) **đã bỏ** ngày 2026-09-14 — người
/// dùng chốt. `theoPhanLoai()` ở tầng domain vẫn giữ: nó là nguồn duy nhất
/// cho biết nhóm nào có phát sinh, tức chip nào được hiện.
///
/// ⚠️ Nhóm "Chi" ở đây **không bằng** con số "Tổng chi" của thẻ đầu trang:
/// phần chi gắn danh mục vay/nợ đã sang nhóm Vay/nợ. Ba nhóm phải rời nhau
/// thì tỷ trọng mới có nghĩa — xem §2.1 spec
/// `2026-09-14-thong-ke-phan-loai-va-xu-huong-danh-muc-design.md`.
// ── Bốn khối mượn từ trang Xuất báo cáo (P2, 2026-09-15) ──────────────────
//
// Phép tính nằm trọn ở bốn hàm thuần của `bao_cao_xuat.dart`, dùng chung với
// trang Báo cáo — ở đây chỉ có việc vẽ. Khuôn thẻ và cách xếp chữ chép từ
// `report_preview_page.dart` để hai trang trông như một; riêng tiêu đề thì theo
// kiểu của trang này (18px đậm) chứ không phải nhãn in hoa của tờ báo cáo.

/// ⚠️ **Cột số tiền phải là `Expanded`, không phải `Flexible`.**
///
/// Cả hai đều mang `flex: 1` nên chia đôi chỗ trống như nhau — khác biệt nằm ở
/// chỗ `Flexible` để con giữ bề rộng tự nhiên, và `MainAxisAlignment.start` đẩy
/// phần thừa về **cuối hàng**. Mỗi hàng thừa một kiểu, nên mép phải răng cưa:
/// đo được **26,5px** lệch giữa hai dòng của cùng một khối. `Expanded` cho con
/// chiếm trọn suất của nó, và khi ấy `alignment: Alignment.centerRight` mới đẩy
/// được chữ ra sát mép. Không mất chỗ nào của cột trái — tỉ lệ chia vẫn 1:1.
///
/// Người dùng bắt được trên máy ảo 2026-09-15; có ca test so mép phải canh.

/// Tiêu đề khối, cùng kiểu với "Xu hướng …" và "Cơ cấu theo danh mục".
///
/// `Text` đứng trong `Row` không co được, nên bọc `SizedBox` rộng vô hạn — cùng
/// lý do đã ghi ở hai khối kia.
Widget _tieuDeKhoi(String chu) => SizedBox(
      width: double.infinity,
      child: Text(
        chu,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );

/// Xu hướng **dòng tiền tự do** — A8 #8 (2026-09-15).
///
/// Phép tính nằm trọn ở `dongTienTuDo()` (tầng thuần, có test); ở đây chỉ vẽ.
///
/// ⚠️ **Dòng giải nghĩa dưới tiêu đề là bắt buộc**, cùng lý do khối Dòng tiền
/// luôn kèm câu "Suy ngược từ số dư hiện tại": "thu nhập" ở đây **không phải**
/// tổng thu của khối trên — nó đã trừ tiền đi vay và tiền thu nợ. Hai khối kề
/// nhau nói hai con số khác nhau mà không nói vì sao là cách chắc chắn để người
/// đọc tưởng một trong hai bị sai.
///
/// Khối **luôn hiện** khi kỳ có giao dịch (người dùng chốt 2026-09-15), kể cả
/// khi không ai nợ ai — khi ấy đường này trùng khít đường "Thu" của khối trên.
class _KhoiDongTienTuDo extends StatelessWidget {
  final ThongKeKy tk;
  const _KhoiDongTienTuDo({required this.tk});

  @override
  Widget build(BuildContext context) {
    final ds = dongTienTuDo(tk.chuoi, tk.chuoiVayNo);
    // Không điểm nào thì không có thang đo — bỏ khối, đừng chia cho 0.
    if (ds.isEmpty) return const SizedBox.shrink();

    var dinh = 0.0, day = 0.0;
    for (final d in ds) {
      if (d.tuDo > dinh) dinh = d.tuDo;
      if (d.tuDo < day) day = d.tuDo;
    }
    final coAm = day < 0;
    // Sáu kỳ phẳng bằng 0 thì `dinh` lẫn `day` đều bằng 0 và mọi phép chia
    // thang đo sau đây sẽ hỏng — đặt trần 1.
    final tran = dinh > 0 ? dinh * 1.15 : (coAm ? 0.0 : 1.0);
    final san = coAm ? day * 1.15 : 0.0;
    final buoc = (tran - san) / 3;
    // ⚠️ Trần phải là ĐÚNG `san + 3 * buoc`, không phải con số đã đem chia:
    // fl_chart vẽ nhãn cho cả mốc theo `interval` lẫn biên, và sai số dấu phẩy
    // động đủ để `rutGon` trả hai chuỗi khác nhau cho cùng một vị trí — hai
    // nhãn in đè khít lên nhau (G39, bẫy 4.18 `ANALYTICS_FEATURE.md`).
    final maxY = san + buoc * 3;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text đứng trong Row không co được — cùng lý do với tiêu đề donut.
          SizedBox(
            width: double.infinity,
            child: Text(
              tieuDeDongTienTuDo(tk.ky.donVi),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Thu nhập sau khi trả nợ; không tính tiền đi vay và thu hồi nợ',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _dong(ds.last.tuDo),
              maxLines: 1,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: ds.last.tuDo < 0 ? AppColors.expense : AppColors.income,
              ),
            ),
          ),
          Text(
            tk.ky.nhanNgan,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (ds.length - 1).toDouble(),
                minY: san,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: buoc,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.outlineVariant,
                    strokeWidth: 1,
                  ),
                ),
                // Vạch 0 chỉ có nghĩa khi dải có phần âm; khi mọi kỳ đều dương
                // thì `san` đã bằng 0 và vạch trùng đúng mép dưới.
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (coAm)
                      HorizontalLine(
                        y: 0,
                        color: AppColors.textSecondary,
                        strokeWidth: 1,
                        dashArray: const [6, 4],
                      ),
                  ],
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: buoc,
                      // "-123.5M" là chuỗi dài nhất ở đây — dài hơn khối Xu
                      // hướng đúng một dấu trừ, vì dải này đi xuống dưới 0.
                      reservedSize: 50,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          rutGon(v),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) {
                        final i = v.round();
                        // fl_chart hỏi cả mốc ngoài dải khi vẽ lưới.
                        if (i < 0 || i >= ds.length) {
                          return const SizedBox.shrink();
                        }
                        final cuoi = i == ds.length - 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            ds[i].ky.nhanTruc,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  cuoi ? FontWeight.bold : FontWeight.normal,
                              color: cuoi
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primary,
                    // Bắt buộc: mặc định hộp tooltip tràn ra ngoài màn hình ở
                    // điểm cuối, sát mép phải — thấy trên máy ảo 411dp.
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          rutGon(s.y),
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                // Điểm ngoài dải vẫn được VẼ nếu không cắt — mặc định của
                // fl_chart là `FlClipData.none()` (bẫy 4.17).
                clipData: const FlClipData.all(),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < ds.length; i++)
                        FlSpot(i.toDouble(), ds[i].tuDo),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.25,
                    // Đường cong nội suy có thể vọt qua mốc 0 giữa hai điểm,
                    // vẽ ra một kỳ âm không có thật.
                    preventCurveOverShooting: true,
                    color: AppColors.income,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      // Kỳ âm đổi màu chấm: đó là thứ người đọc phải thấy ngay.
                      // Đổi màu theo từng ĐIỂM thì chính xác — đổi màu cả đoạn
                      // đường phải dựa vào hộp bao của đường, thứ không trùng
                      // với dải của biểu đồ.
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color:
                            spot.y < 0 ? AppColors.expense : AppColors.income,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    // Tô phần DƯƠNG (từ đường xuống mốc 0) …
                    belowBarData: BarAreaData(
                      show: true,
                      applyCutOffY: true,
                      cutOffY: 0,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.income.withValues(alpha: 0.25),
                          AppColors.income.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    // … và phần ÂM (từ mốc 0 xuống đường) bằng màu chi. Thiếu
                    // vế này thì vùng tô đổ suốt xuống đáy biểu đồ và kỳ âm
                    // trông y hệt kỳ dương.
                    aboveBarData: BarAreaData(
                      show: coAm,
                      applyCutOffY: true,
                      cutOffY: 0,
                      color: AppColors.expense.withValues(alpha: 0.18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dự báo 30 ngày tới ────────────────────────────────────────────────────

/// Khối "Dự báo 30 ngày tới" — spec
/// `docs/superpowers/specs/2026-09-16-du-bao-dong-tien-design.md` §5.3; màn
/// Stitch `732587777370466098aa98d17bd0cbd4` *"Thống kê - Dự báo 30 ngày
/// tới"* (2026-09-16).
///
/// Phép tính nằm trọn ở `du_bao_dong_tien.dart`; ở đây chỉ vẽ.
/// `StatefulWidget` **chỉ** để giữ cờ "đã mở hết" của danh sách — state cục
/// bộ, không qua cubit, vì nó không phải một lựa chọn cần sống sót qua lần
/// repository phát lại (khác `phanLoaiDangXem` và `danhMucXuHuong`).
///
/// `null` → `SizedBox.shrink()`: lớp **thứ hai** của chốt "không có ví thì ẩn
/// cả khối"; lớp thứ nhất là `if` ở `_than`. Cùng cách thác nước.
class _KhoiDuBao extends StatefulWidget {
  final DuBaoDongTien? duBao;
  const _KhoiDuBao({required this.duBao});

  @override
  State<_KhoiDuBao> createState() => _KhoiDuBaoState();
}

/// Số dòng cam kết khi chưa bấm "Xem thêm".
const int _soDongCamKetThuGon = 5;

String _ddMM(DateTime d) => DateFormat('dd/MM').format(d);

class _KhoiDuBaoState extends State<_KhoiDuBao> {
  bool _moHet = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.duBao;
    if (d == null) return const SizedBox.shrink();

    final hien =
        _moHet ? d.camKet : d.camKet.take(_soDongCamKetThuGon).toList();
    final conLai = d.camKet.length - hien.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dự báo 30 ngày tới',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Từ hôm nay, không theo kỳ đang xem — chỉ tính hoá đơn và trích tự '
            'động đã đặt',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _BaConSoDuBao(d: d),
          for (final v in d.viThieu) ...[
            const SizedBox(height: 12),
            _DongViThieu(v: v),
          ],
          const SizedBox(height: 20),
          if (d.camKet.isEmpty)
            const Text(
              'Không có hoá đơn hay trích tự động nào trong 30 ngày tới',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else ...[
            SizedBox(height: 180, child: _BieuDoDuBao(d: d)),
            const SizedBox(height: 8),
            _ChuGiaiDuBao(coNganSach: d.coNganSach),
            const SizedBox(height: 12),
            for (final c in hien) _DongCamKet(c: c),
            if (conLai > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _moHet = true),
                  child: Text('Xem thêm ($conLai)'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BaConSoDuBao extends StatelessWidget {
  final DuBaoDongTien d;
  const _BaConSoDuBao({required this.d});

  @override
  Widget build(BuildContext context) {
    final am = d.conTieuDuoc < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Còn tiêu được',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _dong(d.conTieuDuoc),
            maxLines: 1,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: am ? AppColors.expense : AppColors.income,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _DongSo(nhan: 'Số dư hiện tại', giaTri: _dong(d.soDuHienTai)),
        if (d.coNganSach) ...[
          const SizedBox(height: 4),
          _DongSo(
            nhan: 'Nếu tiêu đúng ngân sách',
            giaTri: _dong(d.conTieuDuocTheoNganSach),
          ),
        ],
      ],
    );
  }
}

class _DongSo extends StatelessWidget {
  final String nhan;
  final String giaTri;
  const _DongSo({required this.nhan, required this.giaTri});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            nhan,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          giaTri,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DongViThieu extends StatelessWidget {
  final ViThieu v;
  const _DongViThieu({required this.v});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ví ${v.ten} thiếu ${_dong(v.thieu)} để trả cam kết ngày '
              '${_ddMM(v.ngay)}',
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chú giải hai đường. Có trong màn Stitch và **cần thật**: nét đứt đi chéo
/// xuống mà không có nhãn thì người đọc không đoán được nó là kế hoạch tiêu
/// hay một dự báo thứ hai.
class _ChuGiaiDuBao extends StatelessWidget {
  final bool coNganSach;
  const _ChuGiaiDuBao({required this.coNganSach});

  @override
  Widget build(BuildContext context) {
    // `Wrap`, không phải `Row`: hai mục chú giải cạnh nhau tràn 55px ở 411dp
    // (bắt được bằng widget test ở đúng khổ ấy). Font của bộ test rộng gấp đôi
    // ngoài đời nên trên máy thật nó vừa — nhưng một hàng không co được là
    // đúng bẫy 4.4, và xuống dòng thì đọc vẫn tự nhiên.
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const _MucChuGiai(
            mau: AppColors.primary, netDut: false, chu: 'Thực tế cam kết'),
        if (coNganSach)
          const _MucChuGiai(
              mau: AppColors.warning, netDut: true, chu: 'Theo ngân sách'),
      ],
    );
  }
}

class _MucChuGiai extends StatelessWidget {
  final Color mau;
  final bool netDut;
  final String chu;
  const _MucChuGiai(
      {required this.mau, required this.netDut, required this.chu});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NetChuGiai(mau: mau, netDut: netDut),
        const SizedBox(width: 6),
        Text(chu,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _NetChuGiai extends StatelessWidget {
  final Color mau;
  final bool netDut;
  const _NetChuGiai({required this.mau, required this.netDut});

  @override
  Widget build(BuildContext context) {
    if (!netDut) {
      return Container(width: 16, height: 3, color: mau);
    }
    return SizedBox(
      width: 16,
      height: 3,
      child: Row(
        children: [
          Container(width: 6, height: 3, color: mau),
          const SizedBox(width: 4),
          Container(width: 6, height: 3, color: mau),
        ],
      ),
    );
  }
}

/// Biểu đồ bậc thang tầng 1 + nét đứt "theo ngân sách".
///
/// Khối `fl_chart` thứ **tám** của app và là chỗ **đầu tiên** dùng
/// `isStepLineChart` — số dư không giảm dần đều, nó đứng yên rồi tụt một bậc
/// đúng ngày phải trả; vẽ đường cong là nói dối về hình dạng của tiền.
///
/// Tầng vẽ không test tự động được (bẫy 4.9): bậc thang, nét đứt, nhãn trục
/// và vùng tô chỉ kiểm được bằng mắt trên máy ảo 411dp.
class _BieuDoDuBao extends StatelessWidget {
  final DuBaoDongTien d;
  const _BieuDoDuBao({required this.d});

  @override
  Widget build(BuildContext context) {
    final ds = d.chuoi;
    // Dải trục CO theo dữ liệu — phép tính và lý lẽ ở `daiTrucDuBao`, nơi nó
    // được test (kể cả ca dải hẹp làm bốn nhãn in ra cùng một chuỗi).
    final (:san, :buoc) = daiTrucDuBao([
      for (final p in ds) ...[
        p.chacChan,
        if (d.coNganSach) p.theoNganSach,
      ],
    ]);
    // Trần phải là ĐÚNG `san + 3 * buoc`, không phải con số đã đem chia: sai
    // số dấu phẩy động đủ để `rutGon` trả hai chuỗi khác nhau cho cùng một vị
    // trí, và hai nhãn in đè khít lên nhau (G39, bẫy 4.18).
    final maxY = san + buoc * 3;
    // Vạch 0 và vùng tô phần âm chỉ có nghĩa khi mốc 0 NẰM TRONG dải. Trục co
    // nên số dư dương lớn cho ra một khung hoàn toàn trên 0.
    final coAm = san < 0;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: kSoNgayDuBao.toDouble(),
        minY: san,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: buoc,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        // Vạch 0 chỉ có nghĩa khi dải có phần âm; khi mọi điểm đều dương thì
        // `san` đã bằng 0 và vạch trùng đúng mép dưới.
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (coAm)
              HorizontalLine(
                y: 0,
                color: AppColors.textSecondary,
                strokeWidth: 1,
                dashArray: const [6, 4],
              ),
          ],
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: buoc,
              reservedSize: 50,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  rutGon(v),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 10,
              reservedSize: 26,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                // Bốn nhãn: 0 · 10 · 20 · 30. Hai biên trùng đúng mốc
                // `interval` nên không sinh nhãn thứ năm in đè (bẫy 4.18).
                if (i < 0 || i > kSoNgayDuBao || i % 10 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _ddMM(ds[i].ngay),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.primary,
            // Bắt buộc: mặc định hộp tooltip tràn ra ngoài màn hình ở điểm
            // cuối, sát mép phải — thấy trên máy ảo 411dp.
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  rutGon(s.y),
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        // Điểm ngoài dải vẫn được VẼ nếu không cắt — mặc định của fl_chart là
        // `FlClipData.none()` (bẫy 4.17).
        clipData: const FlClipData.all(),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < ds.length; i++)
                FlSpot(i.toDouble(), ds[i].chacChan),
            ],
            isStepLineChart: true,
            isCurved: false,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              // Chỉ cắt ở mốc 0 khi 0 nằm trong dải; trục co thì nó thường
              // không, và cắt ở một mốc ngoài khung là tô đặc cả biểu đồ.
              applyCutOffY: coAm,
              cutOffY: 0,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
            // Phần ÂM tô màu chi. Thiếu vế này thì vùng tô đổ suốt xuống đáy
            // và một ngày âm trông y hệt một ngày dương.
            aboveBarData: BarAreaData(
              show: coAm,
              applyCutOffY: true,
              cutOffY: 0,
              color: AppColors.expense.withValues(alpha: 0.18),
            ),
          ),
          if (d.coNganSach)
            LineChartBarData(
              spots: [
                for (var i = 0; i < ds.length; i++)
                  FlSpot(i.toDouble(), ds[i].theoNganSach),
              ],
              isCurved: false,
              color: AppColors.warning,
              barWidth: 2,
              dashArray: const [6, 4],
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
        ],
      ),
    );
  }
}

class _DongCamKet extends StatelessWidget {
  final CamKet c;
  const _DongCamKet({required this.c});

  @override
  Widget build(BuildContext context) {
    final laHoaDon = c.loai == LoaiCamKet.hoaDon;
    final mau = laHoaDon ? AppColors.expense : AppColors.income;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: mau.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              laHoaDon ? Icons.receipt_long : Icons.savings,
              size: 18,
              color: mau,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.ten,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_ddMM(c.ngay)} · ${c.tenVi ?? 'Ví đã xoá'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-${_dong(c.soTien)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.expense,
                ),
              ),
              if (c.quaHan)
                const _NhanNho(chu: 'Quá hạn', mau: AppColors.expense)
              else if (c.laKyChieu)
                const _NhanNho(chu: 'Dự kiến', mau: AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}

class _NhanNho extends StatelessWidget {
  final String chu;
  final Color mau;
  const _NhanNho({required this.chu, required this.mau});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        chu,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: mau),
      ),
    );
  }
}

/// Số dư ví ở hai đầu kỳ.
///
/// ⚠️ **Câu "Suy ngược từ số dư hiện tại của các ví" là bắt buộc.** App không
/// lưu lịch sử số dư, nên hai con số này suy ngược từ số dư hôm nay; bê mỗi con
/// số là để người đọc tưởng đây là số đo. Ví tạo giữa kỳ mang theo số dư ban
/// đầu không phải giao dịch, nên nó rơi vào số dư đầu kỳ — mục 3.16.
class _KhoiDongTien extends StatelessWidget {
  final DongTien dt;
  const _KhoiDongTien({required this.dt});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _theTrang(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tieuDeKhoi('Dòng tiền trong kỳ'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _oSoDu('SỐ DƯ ĐẦU KỲ', dt.dauKy)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward,
                      size: 18, color: AppColors.textSecondary),
                ),
                Expanded(child: _oSoDu('SỐ DƯ CUỐI KỲ', dt.cuoiKy)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Thay đổi trong kỳ',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        CurrencyFormatter.formatCoDau(dt.thayDoi,
                            thu: dt.thayDoi >= 0),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: dt.thayDoi >= 0
                              ? AppColors.income
                              : AppColors.expense,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Suy ngược từ số dư hiện tại của các ví',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      );

  Widget _oSoDu(String nhan, double soTien) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nhan,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(soTien),
              maxLines: 1,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      );
}

/// Thác nước: số dư đầu kỳ → cộng thu → trừ dần từng nhóm chi → số dư cuối kỳ.
///
/// Phép tính ở `domain/thac_nuoc.dart`; khối này chỉ lo vẽ và tra tên danh mục.
/// Nhóm chi mượn **`topVaKhac`** — cùng hàm mà vòng tròn cơ cấu dùng, nên hai
/// khối không thể nói hai con số cho một kỳ.
class _KhoiThacNuoc extends StatelessWidget {
  final ThongKeKy tk;

  const _KhoiThacNuoc({required this.tk});

  /// Năm nhóm lớn nhất, phần còn lại gom thành "Khác" — chín cột là đã kịch
  /// khổ 411dp.
  static const int _soNhom = 5;
  static const double _rongCot = 15;

  @override
  Widget build(BuildContext context) {
    final dt = tk.dongTien;
    // Cùng điều kiện với khối "Dòng tiền trong kỳ": lọc theo một ví thì số dư
    // hai đầu không suy ngược được (mục 3.16), và thác nước mất luôn hai cột
    // mốc — còn lại một hình không kể được gì.
    if (dt == null) return const SizedBox.shrink();

    // `danhMuc` cùng thứ tự với `chiTheoDanhMuc` và đã tra sẵn tên.
    final ten = <String?, String>{};
    for (final d in tk.danhMuc) {
      ten[d.categoryId] = d.ten;
    }

    final lat = topVaKhac(tk.chiTheoDanhMuc, top: _soNhom);
    final nhomChi = <({String ten, double soTien})>[
      for (final l in lat)
        (
          ten: l.laKhac ? 'Khác' : (ten[l.categoryId] ?? 'Chưa phân loại'),
          soTien: l.soTien,
        ),
    ];

    final buoc = thacNuocCua(
      dauKy: dt.dauKy,
      cuoiKy: dt.cuoiKy,
      thu: tk.tong.thu,
      nhomChi: nhomChi,
    );
    if (buoc.isEmpty) return const SizedBox.shrink();

    final tb = trungBinhNhomChi(nhomChi);

    var lo = 0.0;
    var hi = 0.0;
    for (final b in buoc) {
      lo = math.min(lo, math.min(b.tu, b.den));
      hi = math.max(hi, math.max(b.tu, b.den));
    }
    // Cùng cách chống nhãn trục tung in đè của G39 (bẫy 4.18): tính `buocTruc`
    // trước rồi đặt trần bằng bội của nó.
    final dai = hi - lo;
    final buocTruc = (dai <= 0 ? 1.0 : dai * 1.12) / 3;
    final maxY = lo + buocTruc * 3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tieuDeKhoi('Tiền đi đâu'),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _ChuGiai(mau: AppColors.textPrimary, nhan: 'Số dư'),
              _ChuGiai(mau: AppColors.income, nhan: 'Thu'),
              _ChuGiai(mau: AppColors.expense, nhan: 'Chi'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: lo,
                alignment: BarChartAlignment.spaceAround,
                // ⚠️ `BarChartData` **không có** `clipData` — bẫy 4.17 nói về
                // `LineChartData`. Ở đây chống tràn bằng cách khác: `minY`/
                // `maxY` bọc trọn mọi bậc (`lo`/`hi` quét cả `tu` lẫn `den`),
                // nên không cột nào rơi ra ngoài dải để mà tràn.
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: buocTruc,
                  getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.outlineVariant, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: const BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: buocTruc,
                      reservedSize: 46,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          rutGon(v),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 40,
                      getTitlesWidget: (v, meta) {
                        final i = v.round();
                        if (i < 0 || i >= buoc.length) {
                          return const SizedBox.shrink();
                        }
                        // ⚠️ Chín cột trên 411dp: vùng vẽ ngang còn chừng
                        // 325dp sau khi trừ trục tung và đệm thẻ, tức mỗi cột
                        // được ~36dp. Ô nhãn **phải hẹp hơn** con số ấy, nếu
                        // không hai nhãn cạnh nhau dính thành một chuỗi không
                        // đọc được ("ChưaDi chuyểnMua sắDanh mục…") — thấy
                        // trên máy ảo, và `flutter test` không bắt được vì
                        // `find.text` so `data` chứ không so thứ vẽ ra
                        // (bẫy 4.4). Cùng họ G39.
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: SizedBox(
                            width: 32,
                            child: Text(
                              buoc[i].nhan,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 8, color: AppColors.textSecondary),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < buoc.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [_cot(buoc[i], tb)],
                    ),
                ],
              ),
            ),
          ),
          if (tb > 0) ...[
            const SizedBox(height: 12),
            Text(
              'Phần đậm là chỗ vượt mức trung bình '
              '${CurrencyFormatter.format(tb)}/nhóm',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  /// Một cột của thác nước.
  ///
  /// Hai cột mốc mọc từ đáy; cột thu và các cột chi **nổi** — `fromY`/`toY` là
  /// thứ làm nên bậc thang. `fl_chart` đòi `fromY < toY` nên phải lấy `min`/
  /// `max`, còn chiều thì đã nằm trong `tu`/`den` của bậc.
  BarChartRodData _cot(BuocThacNuoc b, double tb) {
    final day = math.min(b.tu, b.den);
    final dinh = math.max(b.tu, b.den);
    final mau = switch (b.loai) {
      LoaiBuoc.moc => AppColors.textPrimary,
      LoaiBuoc.thu => AppColors.income,
      LoaiBuoc.chi => AppColors.expense,
    };
    final ranh = ranhVuotTrungBinh(b, tb);

    return BarChartRodData(
      fromY: day,
      toY: dinh,
      width: _rongCot,
      color: mau,
      borderRadius: BorderRadius.circular(3),
      // Nhóm vượt mức trung bình thì cột chia hai sắc độ: phần trong mức nhạt,
      // phần vượt đậm. Vì sao KHÔNG phải một đường ngang vắt qua biểu đồ —
      // xem `ranhVuotTrungBinh`.
      rodStackItems: ranh == null
          ? const []
          : [
              BarChartRodStackItem(day, ranh, mau),
              BarChartRodStackItem(
                  ranh, dinh, mau.withValues(alpha: 0.35)),
            ],
    );
  }
}

/// Ba con số người dùng hỏi ngay, kiểu Money Lover / MISA.
class _KhoiSoLieuNhanh extends StatelessWidget {
  final ThongKeKy tk;
  const _KhoiSoLieuNhanh({required this.tk});

  @override
  Widget build(BuildContext context) {
    final s = tk.soLieu;

    // Cả BA chỉ số của khối này đều nói về **chi**, nên một kỳ không có khoản
    // chi nào cho ra một thẻ gồm `0 đ` và hai dấu `—`: chiếm chỗ, không mang
    // tin nào. Kỳ như thế **không** rơi vào nhánh `thongKe.rong` — nhánh ấy đòi
    // `thu == 0` **và** `chi == 0` — nên nó đi thẳng vào thân trang.
    //
    // ⚠️ Phải đòi **cả ba** cùng rỗng, không chỉ hai trường `null`:
    // `chiMoiNgay` khác 0 là một con số có thật và đáng nói, kể cả khi kỳ không
    // xác định được ngày chi nhiều nhất.
    //
    // ⚠️ Và phép chốt đọc đúng `s` — chính thứ đang được vẽ — chứ không đọc
    // `tk.tong.chi`: hai vế của cùng một câu mà lấy từ hai chỗ khác nhau thì có
    // ngày chúng nói ngược nhau, im lặng.
    if (s.chiMoiNgay == 0 &&
        s.ngayChiNhieuNhat == null &&
        s.khoanChiLonNhat == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tieuDeKhoi('Số liệu nhanh'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child:
                    _o('CHI MỖI NGÀY', CurrencyFormatter.format(s.chiMoiNgay)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _o(
                  'NGÀY CHI NHIỀU NHẤT',
                  s.ngayChiNhieuNhat == null
                      ? '—'
                      : DateFormatter.formatDate(s.ngayChiNhieuNhat!),
                  phu: s.ngayChiNhieuNhat == null
                      ? null
                      : CurrencyFormatter.format(s.chiNgayNhieuNhat),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _o(
            'KHOẢN CHI LỚN NHẤT',
            s.khoanChiLonNhat?.tieuDe ?? '—',
            phu: s.khoanChiLonNhat == null
                ? null
                : CurrencyFormatter.format(s.khoanChiLonNhat!.soTien),
          ),
        ],
      ),
    );
  }

  Widget _o(String nhan, String giaTri, {String? phu}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nhan,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              giaTri,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (phu != null) ...[
            const SizedBox(height: 2),
            Text(
              phu,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      );
}

/// Thu/chi theo từng ví, giảm dần theo chi.
/// Lịch chi tiêu — heatmap theo ngày (#6 khảo sát lần hai, 2026-09-16).
///
/// Lưới lịch **tháng** chứ không phải dải kiểu GitHub: PocketSmith và Money
/// Lover đều vẽ thế, và 30 ô còn có chỗ in số ngày còn 365 ô thì không.
///
/// Dựng bằng `GridView` chứ không `CustomPainter` — app chưa dùng `CustomPaint`
/// ở đâu, và một ô vuông có chữ số thì `GridView` đủ; mở một lối vẽ mới ở đây
/// là thêm một vùng **không test tự động được** (bẫy 4.9) mà chẳng được gì.
class _KhoiLich extends StatefulWidget {
  final ThongKeKy tk;
  const _KhoiLich({required this.tk});

  @override
  State<_KhoiLich> createState() => _KhoiLichState();
}

class _KhoiLichState extends State<_KhoiLich> {
  DateTime? _chon;

  @override
  void didUpdateWidget(covariant _KhoiLich old) {
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
      decoration: _theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ⚠️ `_tieuDeKhoi` là `SizedBox(width: double.infinity)` — nó
              // dành cho `Column`. Đặt trần vào `Row` là ép bề rộng vô hạn và
              // **cả cây dừng dựng**, kéo theo mọi ca test của trang.
              Expanded(child: _tieuDeKhoi('Lịch chi tiêu')),
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
              return _O(
                ngay: ngay,
                muc: widget.tk.lichChiTieu[ngay],
                trungBinh: tb,
                dangChon: _chon == ngay,
                onTap: () => setState(() => _chon = ngay),
              );
            },
          ),
          const SizedBox(height: 12),
          const _ChuGiaiNhiet(),
          if (_chon != null) ...[
            const SizedBox(height: 16),
            _TomTatNgay(ngay: _chon!, muc: widget.tk.lichChiTieu[_chon!]),
          ],
        ],
      ),
    );
  }
}

/// Một ô ngày. `muc == null` là **không chi đồng nào** — khác hẳn "chi rất ít",
/// nên nó có nền riêng chứ không phải bậc nhạt nhất.
class _O extends StatelessWidget {
  final DateTime ngay;
  final NgayChiTieu? muc;
  final double trungBinh;
  final bool dangChon;
  final VoidCallback onTap;

  const _O({
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
          color: _nenBac(bac),
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
Color _nenBac(int bac) => switch (bac) {
      0 => Colors.white,
      1 => AppColors.expense.withValues(alpha: 0.18),
      2 => AppColors.expense.withValues(alpha: 0.40),
      3 => AppColors.expense.withValues(alpha: 0.65),
      _ => AppColors.expense,
    };

/// Chú giải thang màu. Nói rõ thang neo vào **mức trung bình** chứ không vào
/// ngày lớn nhất — nếu không, hai tháng có lưới giống hệt nhau lại là hai mức
/// chi hoàn toàn khác.
class _ChuGiaiNhiet extends StatelessWidget {
  const _ChuGiaiNhiet();

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
              color: _nenBac(b),
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
class _TomTatNgay extends StatelessWidget {
  final DateTime ngay;
  final NgayChiTieu? muc;
  const _TomTatNgay({required this.ngay, required this.muc});

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
                '-${_dong(m.tongChi)}',
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
                // `_dong` chứ không `CurrencyFormatter.format`: hai hàm khác
                // nhau ở **khoảng trắng trước chữ đ**, và máy ảo cho thấy hai
                // định dạng nằm trong CÙNG một thẻ đọc rất chối. Ngoài thẻ này
                // thì cả hai vẫn cùng tồn tại trên trang, đúng như trước.
                'Lớn nhất: ${m.lonNhat!.tenDanhMuc} · ${_dong(m.lonNhat!.soTien)}',
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

class _KhoiTheoVi extends StatelessWidget {
  final List<DongVi> ds;
  const _KhoiTheoVi({required this.ds});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _theTrang(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tieuDeKhoi('Phân bổ theo ví'),
            for (final v in ds)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.ten,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${v.soGiaoDich} giao dịch',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.formatCoDau(v.thu, thu: true),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.income,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.formatCoDau(v.chi, thu: false),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.expense,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

/// Năm khoản chi lớn nhất của kỳ.
class _KhoiTopChi extends StatelessWidget {
  final List<DongGiaoDich> ds;
  const _KhoiTopChi({required this.ds});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _theTrang(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tieuDeKhoi('Top 5 khoản chi'),
            for (var i = 0; i < ds.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ds[i].tieuDe,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${ds[i].tenDanhMuc} · '
                            '${DateFormatter.formatDate(ds[i].ngay)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          CurrencyFormatter.formatCoDau(-ds[i].soTien,
                              thu: false),
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.expense,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

// ── Hai biểu đồ vay/nợ — A8 #4 và #5 (2026-09-15) ─────────────────────────
//
// Mỗi kỳ một **cặp cột chồng nhau**: cột sau rộng và mờ, cột trước hẹp và đậm
// vẽ đè lên chính giữa. Người dùng chốt hình dạng này ngày 2026-09-15.
//
// ⚠️ **Màu theo CHIỀU TIỀN, không theo vị trí**: xanh luôn là tiền vào, đỏ luôn
// là tiền ra — cùng quy ước với mọi chỗ khác trong app. Nên khối "Cho vay & Thu
// nợ" có cột sau đỏ, còn khối "Đi vay & Trả nợ" có cột sau XANH. Đảo lại cho
// "hai khối trông giống nhau" là dạy người đọc một quy ước thứ hai.

enum _CotVayNo { choVay, thuNo, diVay, traNo }

extension _CotVayNoX on _CotVayNo {
  String get nhan => switch (this) {
        _CotVayNo.choVay => 'Cho vay',
        _CotVayNo.thuNo => 'Thu nợ',
        _CotVayNo.diVay => 'Đi vay',
        _CotVayNo.traNo => 'Trả nợ',
      };

  /// Tiền vào thì xanh, tiền ra thì đỏ — không phụ thuộc cột nằm trước hay sau.
  Color get mau => switch (this) {
        _CotVayNo.choVay || _CotVayNo.traNo => AppColors.expense,
        _CotVayNo.thuNo || _CotVayNo.diVay => AppColors.income,
      };

  double soTien(DiemVayNo d) => switch (this) {
        _CotVayNo.choVay => d.choVay,
        _CotVayNo.thuNo => d.thuNo,
        _CotVayNo.diVay => d.diVay,
        _CotVayNo.traNo => d.traNo,
      };
}

/// Chuỗi có phát sinh nào ở chiều đang hỏi không.
///
/// [chieuRa] `true` hỏi cặp *Cho vay / Thu nợ*, `false` hỏi cặp *Đi vay / Trả
/// nợ*. Vẽ một biểu đồ toàn số 0 trông như lỗi tải dữ liệu, nên khối nào không
/// có gì thì không hiện.
bool coVayNo(List<DiemVayNo> ds, {required bool chieuRa}) => ds.any(
      (d) => chieuRa ? (d.choVay > 0 || d.thuNo > 0) : (d.diVay > 0 || d.traNo > 0),
    );

class _KhoiVayNo extends StatelessWidget {
  final String tieuDe;
  final List<DiemVayNo> ds;

  /// Cột **rộng, mờ**, vẽ trước nên nằm dưới.
  final _CotVayNo sau;

  /// Cột **hẹp, đậm**, vẽ sau nên đè lên trên.
  final _CotVayNo truoc;

  const _KhoiVayNo({
    required this.tieuDe,
    required this.ds,
    required this.sau,
    required this.truoc,
  });

  /// Bề rộng hai cột. Cột trước phải hẹp hơn hẳn thì mắt mới thấy nó nằm
  /// **trong lòng** cột sau chứ không phải một cột thứ hai đứng cạnh.
  static const double _rongSau = 22;
  static const double _rongTruoc = 12;

  @override
  Widget build(BuildContext context) {
    var dinh = 0.0;
    for (final d in ds) {
      final a = sau.soTien(d);
      final b = truoc.soTien(d);
      if (a > dinh) dinh = a;
      if (b > dinh) dinh = b;
    }
    // Cùng cách chống nhãn trục tung in đè của G39 (bẫy 4.18): tính `buoc`
    // trước rồi đặt trần bằng `buoc * 3`, đừng chia một số rồi dùng lại chính
    // nó làm trần — `3 * (maxY / 3)` lệch `maxY` chừng 1e-14 và `rutGon` cho ra
    // hai chuỗi khác nhau ở cùng một vị trí.
    final buoc = (dinh <= 0 ? 1.0 : dinh * 1.15) / 3;
    final maxY = buoc * 3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tieuDeKhoi(tieuDe),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _ChuGiai(mau: sau.mau, nhan: sau.nhan),
              _ChuGiai(mau: truoc.mau, nhan: truoc.nhan),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: buoc,
                  getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.outlineVariant, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                // `fitInside*` là hai chốt đã học ở khối Xu hướng (mục 3.11):
                // không có chúng thì tooltip của cột đầu và cột cuối tràn ra
                // ngoài thẻ.
                barTouchData: const BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: buoc,
                      reservedSize: 46,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          rutGon(v),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) {
                        final i = v.round();
                        if (i < 0 || i >= ds.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            ds[i].ky.nhanTruc,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < ds.length; i++)
                    BarChartGroupData(
                      x: i,
                      // `barsSpace` ÂM là thứ làm hai cột chồng nhau.
                      // `-(rộng1 + rộng2) / 2` đặt tâm hai cột trùng khít —
                      // lệch đi là cột trước trồi ra một bên, trông như lỗi vẽ.
                      barsSpace: -(_rongSau + _rongTruoc) / 2,
                      barRods: [
                        // Thứ tự trong danh sách LÀ thứ tự vẽ: cột sau phải
                        // đứng trước để cột trước đè lên nó.
                        BarChartRodData(
                          toY: sau.soTien(ds[i]),
                          width: _rongSau,
                          color: sau.mau.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        BarChartRodData(
                          toY: truoc.soTien(ds[i]),
                          width: _rongTruoc,
                          color: truoc.mau,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Khoản thuộc nhóm Vay/nợ mà **không đoán được vai** — chỉ hiện khi có.
///
/// Vì sao không nhét vào hai khối trên: một khoản tiền ra không rõ tên có thể là
/// *cho vay* **hoặc** *trả nợ*. Xếp vào một khối là chọn bừa, xếp vào cả hai là
/// đếm hai lần. Khối riêng là chỗ duy nhất không phải bịa — và giấu nó đi thì
/// tổng trên hai biểu đồ nhỏ hơn tiền thật mà không ai biết vì sao.
class _KhoiVayNoKhac extends StatelessWidget {
  final List<DiemVayNo> ds;
  const _KhoiVayNoKhac({required this.ds});

  @override
  Widget build(BuildContext context) {
    final ra = ds.fold<double>(0, (s, d) => s + d.khacRa);
    final vao = ds.fold<double>(0, (s, d) => s + d.khacVao);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tieuDeKhoi('Vay/nợ chưa xếp được vai'),
          const SizedBox(height: 8),
          const Text(
            'Danh mục vay/nợ do bạn tự đặt tên — app chỉ biết chiều tiền, '
            'không biết là cho vay hay trả nợ.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _o('TIỀN RA', ra, AppColors.expense)),
              const SizedBox(width: 12),
              Expanded(child: _o('TIỀN VÀO', vao, AppColors.income)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _o(String nhan, double soTien, Color mau) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nhan,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(soTien),
              maxLines: 1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: mau,
              ),
            ),
          ),
        ],
      );
}

class _KhoiDonut extends StatelessWidget {
  final ThongKeKy tk;
  final String phanLoaiDangXem;
  const _KhoiDonut({required this.tk, required this.phanLoaiDangXem});

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
      decoration: _theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Một Text đứng trong Row không co được: chiếm hết chiều ngang, nếu
          // không tiêu đề tràn (test 411dp bắt được).
          const SizedBox(
            width: double.infinity,
            child: Text(
              'Cơ cấu theo danh mục',
              maxLines: 1,
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
                _Donut(
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
                        _ChuGiai(mau: v.mau[i], nhan: v.ten[i]),
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
  _NoiDungDonut _mucDanhMuc(String pl) {
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
        for (final l in lat) l.laKhac ? _mauKhac : _mauCua(tra[l.categoryId]),
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
typedef _NoiDungDonut = ({
  List<ChiTheoDanhMuc> lat,
  List<Color> mau,
  List<String> ten,
  String nhanTam,
  double tongTam,
});

class _Donut extends StatelessWidget {
  final List<ChiTheoDanhMuc> lat;
  final List<Color> mau;

  /// Nhãn nhỏ ở tâm — "TỔNG CHI" / "TỔNG THU" / "VAY/NỢ" theo nhóm đang
  /// chọn. Luôn có một nhóm, nên không còn nhãn chung nào.
  final String nhan;
  final double tong;

  const _Donut({
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

class _ChuGiai extends StatelessWidget {
  final Color mau;
  final String nhan;
  const _ChuGiai({required this.mau, required this.nhan});

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

class _DanhSachDanhMuc extends StatelessWidget {
  final ThongKeKy tk;

  /// Nhóm đang chọn ở donut — luôn có một nhóm, mức gốc đã bỏ (2026-09-14).
  final String phanLoai;
  const _DanhSachDanhMuc({required this.tk, required this.phanLoai});

  /// Nguồn dòng: **đi theo donut** để hai khối luôn nói cùng một con số. Hai
  /// chỗ đọc hai nguồn khác nhau là donut nói 8.2M mà danh sách cộng ra 8.5M.
  List<DongDanhMuc> get _dong => tk.danhMucCua(phanLoai);

  /// Mẫu số của nhãn "% …" trong từng dòng.
  String get _nhomTiLe => phanLoai;

  @override
  Widget build(BuildContext context) {
    final dong = _dong;
    if (dong.isEmpty) return const SizedBox.shrink();
    final hien = dong.take(_soDongToiDa).toList();

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
            if (dong.length > _soDongToiDa)
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
        for (final d in hien) _DongDanhMuc(d: d, phanLoai: _nhomTiLe),
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
            for (final d in _dong)
              _DongDanhMuc(d: d, phanLoai: _nhomTiLe),
          ],
        ),
      ),
    );
  }
}

class _DongDanhMuc extends StatelessWidget {
  final DongDanhMuc d;

  /// Nhóm chứa dòng này; quyết định mẫu số của nhãn "% …". Mặc định `'chi'`
  /// vì đó cũng là nhóm trang mở sẵn.
  final String phanLoai;
  const _DongDanhMuc({required this.d, this.phanLoai = 'chi'});

  @override
  Widget build(BuildContext context) {
    final mau = _mauCua(d);
    // Có ngân sách thì đo theo hạn mức; không thì theo tổng chi — và ĐỔI nhãn,
    // không hiện "0% ngân sách" cho một hạn mức không tồn tại.
    final tiLe = d.coNganSach ? d.tiLeNganSach! : d.tiLeTongChi;
    final nhan = d.coNganSach
        ? '${(tiLe * 100).round()}% ngân sách'
        : '${(tiLe * 100).round()}% ${nhanTongCua(phanLoai)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _theTrang(),
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
                _dong(d.soTien),
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

BoxDecoration _theTrang({Color color = Colors.white}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );


/// Tổng tài sản theo thời gian — #5 của khảo sát lần hai (2026-09-17).
///
/// Phép tính nằm trọn ở `tongTaiSanCua()` (tầng thuần, có test); ở đây chỉ vẽ.
/// Khối `fl_chart` thứ **chín** của app.
///
/// ## Ba điều dễ phá, cả ba hỏng im lặng
///
/// 1. **Con số lớn là `ds.last.tong`, không phải một phép cộng riêng.** Nó phải
///    bằng đúng số dư Trang chủ — đó là mốc để người dùng tin cả đường. Cộng
///    lại ví ở đây là bản chép tay thứ sáu của `viTinhVaoTong` (G42).
/// 2. **Dòng thay đổi ẨN khi [thayDoiTaiSan] trả `null`.** Đừng thay bằng
///    `?? 0` hay một hiệu tính tay: khi chuỗi chạm quãng chưa có giao dịch nào,
///    điểm đầu là số 0 **"chưa biết"**, và hiệu với nó in ra nguyên cả tài sản
///    như thể người dùng vừa kiếm được ngần ấy trong sáu kỳ.
/// 3. **Trục CO theo dữ liệu, bước TRÒN** — mượn nguyên `daiTrucDuBao` (bẫy
///    4.21). Trục từ 0 cho ra một đường phẳng khi dao động chỉ vài phần trăm
///    số dư; bước lẻ làm hai nhãn cuối in đè (G39, bẫy 4.18).
///
/// Tầng vẽ không test tự động được (bẫy 4.9): vùng tô, chấm cuối và vị trí
/// tooltip chỉ kiểm được bằng mắt trên máy ảo 411dp.
class _KhoiTongTaiSan extends StatelessWidget {
  final ThongKeKy tk;
  const _KhoiTongTaiSan({required this.tk});

  @override
  Widget build(BuildContext context) {
    final ds = tk.taiSan;
    // Chốt lớp thứ hai — xem chú thích ở chỗ dựng khối trong `_NoiDung`.
    if (ds.isEmpty) return const SizedBox.shrink();

    final thieu = mocThieuDuLieu(ds, giaoDichDauTien: tk.giaoDichDauTien);
    final thayDoi = thayDoiTaiSan(ds, giaoDichDauTien: tk.giaoDichDauTien);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _theTrang(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tieuDeKhoi(tieuDeTongTaiSan(tk.ky.donVi)),
          const SizedBox(height: 12),
          Text(
            // ⚠️ Điểm cuối của đường, không phải một phép cộng ví riêng.
            CurrencyFormatter.format(ds.last.tong),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          if (thayDoi != null) ...[
            const SizedBox(height: 4),
            Text(
              '${CurrencyFormatter.formatCoDau(thayDoi, thu: thayDoi >= 0)}'
              ' trong ${cumSoKy(tk.ky.donVi)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: thayDoi >= 0 ? AppColors.income : AppColors.expense,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(height: 180, child: _BieuDoTaiSan(ds: ds)),
          if (thieu != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                // ⚠️ `Expanded` chứ không `Flexible`: câu này dài hơn một dòng
                // ở 411dp, và `Flexible` để con giữ bề rộng tự nhiên nên chữ
                // tràn ra ngoài thẻ (bẫy 4.19).
                Expanded(
                  child: Text(
                    'Trước ${DateFormatter.formatDate(thieu)} chưa có giao '
                    'dịch nào để suy ra số dư.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Đường tổng tài sản sáu kỳ.
class _BieuDoTaiSan extends StatelessWidget {
  final List<DiemTaiSan> ds;
  const _BieuDoTaiSan({required this.ds});

  @override
  Widget build(BuildContext context) {
    // Dải trục CO theo dữ liệu với bước TRÒN — mượn nguyên phép của khối Dự
    // báo, nơi nó đã có test (kể cả ca dải hẹp làm bốn nhãn in ra cùng chuỗi).
    final (:san, :buoc) = daiTrucDuBao([for (final d in ds) d.tong]);
    // Trần phải là ĐÚNG `san + 3 * buoc`, không phải con số đã đem chia: sai số
    // dấu phẩy động đủ để `rutGon` trả hai chuỗi khác nhau cho cùng một vị trí,
    // và hai nhãn in đè khít lên nhau (G39, bẫy 4.18).
    final maxY = san + buoc * 3;
    final coAm = san < 0;
    final cuoi = ds.length - 1;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: cuoi.toDouble(),
        minY: san,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: buoc,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (coAm)
              HorizontalLine(
                y: 0,
                color: AppColors.textSecondary,
                strokeWidth: 1,
                dashArray: const [6, 4],
              ),
          ],
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: buoc,
              reservedSize: 50,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  rutGon(v),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 26,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i > cuoi) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    // Nhãn kỳ lấy từ `Ky.nhanTruc` — nơi luật "sáu nhãn phải
                    // đôi một khác nhau" đã được giải quyết (quý mang năm).
                    ds[i].ky.nhanTruc,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.primary,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  rutGon(s.y),
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        // Điểm ngoài dải vẫn được VẼ nếu không cắt (bẫy 4.17).
        clipData: const FlClipData.all(),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < ds.length; i++)
                FlSpot(i.toDouble(), ds[i].tong),
            ],
            // Số dư đổi theo từng giao dịch chứ không theo một đường cong —
            // nối thẳng là nói đúng hình dạng của tiền.
            isCurved: false,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
                // Chấm cuối to hơn và có viền trắng: đó là con số đang hiện ở
                // dòng lớn phía trên, mắt cần nối được hai thứ với nhau.
                radius: i == cuoi ? 5 : 3,
                color: AppColors.primary,
                strokeWidth: i == cuoi ? 2 : 0,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              // Chỉ cắt ở mốc 0 khi 0 nằm trong dải; trục co thì nó thường
              // không, và cắt ở một mốc ngoài khung là tô đặc cả biểu đồ.
              applyCutOffY: coAm,
              cutOffY: 0,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
            // Phần ÂM tô màu chi. Thiếu vế này thì vùng tô đổ suốt xuống đáy và
            // một kỳ âm trông y hệt một kỳ dương.
            aboveBarData: BarAreaData(
              show: coAm,
              applyCutOffY: true,
              cutOffY: 0,
              color: AppColors.expense.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}
