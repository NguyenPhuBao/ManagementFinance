
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/current_account.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../domain/moc_so_sanh.dart';
import '../../domain/pham_vi_ky.dart';
import '../../domain/vai_vay_no.dart';
import '../../../premium/domain/quyen_tinh_nang.dart';
import '../../../premium/presentation/widgets/the_khoa_quyen.dart';
import '../../domain/thu_tu_khoi.dart';
import '../bloc/analytics_cubit.dart';
import '../bloc/thu_tu_khoi_cubit.dart';
import '../widgets/khung_cho_phan_tich.dart';
import '../widgets/the_de_xuat_thu_tu.dart';
import '../widgets/theo_doi_xem.dart';
import '../widgets/phan_tich/header_phan_tich.dart';
import '../widgets/phan_tich/khoi_co_cau.dart';
import '../widgets/phan_tich/khoi_dong_tien.dart';
import '../widgets/phan_tich/khoi_dong_tien_tu_do.dart';
import '../widgets/phan_tich/khoi_du_bao.dart';
import '../widgets/phan_tich/khoi_lich.dart';
import '../widgets/phan_tich/khoi_so_lieu_nhanh.dart';
import '../widgets/phan_tich/khoi_theo_vi.dart';
import '../widgets/phan_tich/khoi_tong.dart';
import '../widgets/phan_tich/khoi_tong_tai_san.dart';
import '../widgets/phan_tich/khoi_top_chi.dart';
import '../widgets/phan_tich/khoi_vay_no.dart';
import '../widgets/phan_tich/khoi_xu_huong.dart';

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

    // Thứ tự khối theo thói quen xem (dự án C việc ba) là **phần phụ**: không
    // đăng ký cubit thì trang y hệt trước việc ấy — không thẻ, không đo, thứ
    // tự mặc định (kế hoạch, làm rõ 2).
    final coThuTu = sl.isRegistered<ThuTuKhoiCubit>();
    final noiDung = _NoiDung(coThuTu: coThuTu);
    return BlocProvider<AnalyticsCubit>(
      key: ValueKey(idaccount),
      create: (_) => sl<AnalyticsCubit>()..xem(idaccount),
      child: coThuTu
          ? BlocProvider<ThuTuKhoiCubit>(
              create: (_) => sl<ThuTuKhoiCubit>()..nap(idaccount),
              child: noiDung,
            )
          : noiDung,
    );
  }
}

class _NoiDung extends StatelessWidget {
  const _NoiDung({required this.coThuTu});

  /// `ThuTuKhoiCubit` có trong cây không (kế hoạch, làm rõ 2).
  final bool coThuTu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<AnalyticsCubit, AnalyticsState>(
          builder: (context, state) {
            if (!coThuTu) {
              return _cuon(
                  context, state, const ThuTuKhoiState(), null, null, null);
            }
            return BlocBuilder<ThuTuKhoiCubit, ThuTuKhoiState>(
              builder: (context, tt) {
                final cubit = context.read<ThuTuKhoiCubit>();
                // Chỉ đo khi trang có thân thật — kỳ rỗng không có cụm nào để
                // xem, đo nó là đếm giây cho trạng thái "chưa có gì".
                return TheoDoiXem(
                  dangDo: state is AnalyticsLoaded && !state.thongKe.rong,
                  onHienLai: cubit.napLai,
                  onGhi: cubit.ghiGiay,
                  builder: (context, scroll, khoaCua) =>
                      _cuon(context, state, tt, cubit, scroll, khoaCua),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _cuon(
    BuildContext context,
    AnalyticsState state,
    ThuTuKhoiState tt,
    ThuTuKhoiCubit? cubit,
    ScrollController? scroll,
    GlobalKey Function(CumKhoi)? khoaCua,
  ) {
    final coThan = state is AnalyticsLoaded && !state.thongKe.rong;
    final deXuat = tt.deXuat;
    return SingleChildScrollView(
      controller: scroll,
      // Đệm đáy 96 chứ không 8: FAB của MainShell đè lên dòng cuối
      // (thấy trên máy thật — chú giải "Khác" nằm dưới nút cộng).
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Header(state: state),
          const SizedBox(height: 24),
          if (coThan && cubit != null && deXuat != null) ...[
            TheDeXuatThuTu(
              cum: deXuat,
              onDuaLen: () => cubit.duaLen(deXuat),
              onBoQua: () => cubit.boQua(deXuat),
            ),
            const SizedBox(height: 12), // Stitch e081fc95… `gap-3`
          ],
          ..._than(context, state, tt.thuTu, khoaCua),
          // Chỉ khi thứ tự KHÁC mặc định — không thì "Về mặc định" là một
          // lối ra dẫn về đúng chỗ người dùng đang đứng.
          if (coThan &&
              cubit != null &&
              !listEquals(tt.thuTu, kThuTuCumMacDinh)) ...[
            const SizedBox(height: 24),
            DongVeMacDinh(onVeMacDinh: cubit.veMacDinh),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _than(
    BuildContext context,
    AnalyticsState state,
    List<CumKhoi> thuTu,
    GlobalKey Function(CumKhoi)? khoaCua,
  ) {
    switch (state) {
      case AnalyticsLoaded(
          :final thongKe,
          :final phanLoaiDangXem,
          :final danhMucXuHuong,
          :final mocSoSanh
        ):
        if (thongKe.rong) {
          return [
            Rong(ky: thongKe.ky),
            // Dự báo KHÔNG nói về kỳ đang xem. Kỳ rỗng — ngày đầu tháng, hay
            // một tháng cũ không có giao dịch — vẫn là lúc người dùng cần
            // biết 30 ngày tới có gì phải trả.
            if (thongKe.duBao != null) ...[
              const SizedBox(height: 24),
              // Quyền `cashflow_forecast` (spec phân quyền 2026-10-08): không có → thẻ khoá giữ chỗ khối.
              KhoaTheoQuyen(
                ma: MaQuyen.cashflowForecast,
                child: KhoiDuBao(
                  duBao: thongKe.duBao,
                  uocTinh: thongKe.uocTinhChiTuyY,
                ),
              ),
            ],
          ];
        }
        return _xepCum(
          _cacCum(thongKe, phanLoaiDangXem, danhMucXuHuong, mocSoSanh),
          thuTu,
          khoaCua,
        );
      case AnalyticsError(:final message):
        return [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ];
      default:
        // E1 (2026-10-06): hình dạng các khối đầu thay vì vòng xoay giữa
        // khoảng trống — `khung_cho_phan_tich.dart`.
        return const [KhungChoPhanTich()];
    }
  }

  /// Mỗi cụm → các khối của nó, đúng widget và đúng chốt ẩn/hiện như trước
  /// (spec 2.1). Cụm không có khối nào thì **vắng** khỏi bản đồ.
  ///
  /// Thứ tự **mặc định** (`kThuTuCumMacDinh`) chép đúng trang Xuất báo cáo
  /// (P2, 2026-09-15) — hai trang cùng dữ liệu thì phải kể cùng một câu
  /// chuyện, theo cùng một trình tự: tiền ở đâu → bao nhiêu → xu hướng ra sao
  /// → tiêu thế nào → đi vào đâu → từ ví nào → khoản nào. Người dùng đổi được
  /// thứ tự **CỤM** qua thẻ đề xuất (dự án C việc ba, mục 3.36
  /// `ANALYTICS_FEATURE.md`); khối bên trong một cụm thì không đổi chỗ, vì
  /// chúng kể tiếp nhau (chú thích từng cụm).
  Map<CumKhoi, List<Widget>> _cacCum(
    ThongKeKy thongKe,
    String phanLoaiDangXem,
    Set<String> danhMucXuHuong,
    MocSoSanh mocSoSanh,
  ) {
    List<Widget> giua(List<Widget> ds) => [
          for (var i = 0; i < ds.length; i++) ...[
            if (i > 0) const SizedBox(height: 24),
            ds[i],
          ],
        ];
    return {
      if (thongKe.dongTien != null)
        // Thác nước đứng ngay sau khối dòng tiền: nó kể **chi tiết** đúng
        // hai con số mà khối trên vừa nêu — đầu kỳ và cuối kỳ — nên tách
        // hai khối ra xa nhau là bắt người đọc nhớ số rồi cuộn đi tìm.
        CumKhoi.dongTien: giua([
          KhoiDongTien(dt: thongKe.dongTien!),
          KhoiThacNuoc(tk: thongKe),
        ]),
      CumKhoi.tong: [KhoiTong(tk: thongKe, mocSoSanh: mocSoSanh)],
      // Mặc định ngay sau thẻ tổng: "còn tiêu được 30 ngày tới" đứng cạnh
      // "số dư còn lại" của kỳ — hiện tại rồi tới tương lai.
      // Chốt hai lớp: `if` ở đây và guard `null` trong widget.
      if (thongKe.duBao != null)
        CumKhoi.duBao: [
          KhoaTheoQuyen(
            ma: MaQuyen.cashflowForecast,
            child: KhoiDuBao(duBao: thongKe.duBao, uocTinh: thongKe.uocTinhChiTuyY),
          ),
        ],
      // Ba đường cùng dạng biểu đồ, cùng sáu kỳ, cùng trục hoành — mắt học
      // trục một lần rồi đọc được cả ba: "thu về bấy nhiêu → thực còn bấy
      // nhiêu → dồn lại thì tài sản đi về đâu".
      CumKhoi.xuHuong: giua([
        KhoiXuHuong(tk: thongKe, danhMucXuHuong: danhMucXuHuong),
        KhoiDongTienTuDo(tk: thongKe),
        // Chốt lớp thứ nhất: chuỗi rỗng thì không dựng. Lớp thứ hai nằm
        // trong chính widget; bản sai phải phá cả hai mới làm test đỏ.
        if (thongKe.taiSan.isNotEmpty) KhoiTongTaiSan(tk: thongKe),
      ]),
      // Lịch chi tiêu đứng ngay sau Số liệu nhanh: nó kể **chi tiết** đúng
      // con số mà khối trên vừa nêu — "ngày chi nhiều nhất" — và hai khối
      // đọc chung một phép gom theo ngày.
      CumKhoi.chiTheoNgay: giua([
        KhoiSoLieuNhanh(tk: thongKe),
        // ⚠️ Chốt lớp thứ nhất: chỉ hiện khi đơn vị là **Tháng**. Lớp thứ
        // hai nằm trong chính widget; bản sai phải phá cả hai.
        if (thongKe.ky.donVi == DonViKy.thang) KhoiLich(tk: thongKe),
      ]),
      // Donut và danh sách danh mục đi theo cùng một chip phân loại.
      CumKhoi.coCau: giua([
        KhoiDonut(tk: thongKe, phanLoaiDangXem: phanLoaiDangXem),
        DanhSachDanhMuc(tk: thongKe, phanLoai: phanLoaiDangXem),
      ]),
      if (thongKe.theoVi.isNotEmpty)
        CumKhoi.theoVi: [KhoiTheoVi(ds: thongKe.theoVi)],
      if (thongKe.topChi.isNotEmpty)
        CumKhoi.topChi: [KhoiTopChi(ds: thongKe.topChi)],
      // Hai biểu đồ vay/nợ đứng CUỐI mặc định: phần lớn người dùng không ghi
      // khoản vay/nợ nào, và khi ấy chúng không hiện — đặt ở giữa trang thì
      // mỗi lần cuộn qua là một khoảng trống không giải thích được.
      CumKhoi.vayNo: giua([
        if (coVayNo(thongKe.chuoiVayNo, chieuRa: true))
          KhoiVayNo(
            tieuDe: 'Cho vay & Thu nợ',
            ds: thongKe.chuoiVayNo,
            sau: CotVayNo.choVay,
            truoc: CotVayNo.thuNo,
          ),
        if (coVayNo(thongKe.chuoiVayNo, chieuRa: false))
          KhoiVayNo(
            tieuDe: 'Đi vay & Trả nợ',
            ds: thongKe.chuoiVayNo,
            sau: CotVayNo.diVay,
            truoc: CotVayNo.traNo,
          ),
        if (thongKe.chuoiVayNo.any((d) => d.khacRa > 0 || d.khacVao > 0))
          KhoiVayNoKhac(ds: thongKe.chuoiVayNo),
      ]),
    }..removeWhere((_, v) => v.isEmpty);
  }

  /// Xếp cụm theo [thuTu], cách nhau 24 như danh sách cũ. Khi đang đo, mỗi
  /// cụm là `KeyedSubtree(GlobalKey)` — GlobalKey vừa để `TheoDoiXem` đo
  /// khung, vừa giữ state khối (lịch, chip) khi cụm đổi chỗ — bọc một
  /// `Column(ValueKey('cum-‹mã›'))` để test tìm cụm (kế hoạch, làm rõ 3).
  List<Widget> _xepCum(
    Map<CumKhoi, List<Widget>> cum,
    List<CumKhoi> thuTu,
    GlobalKey Function(CumKhoi)? khoaCua,
  ) {
    final ra = <Widget>[];
    for (final c in thuTu) {
      final ds = cum[c];
      if (ds == null) continue;
      if (ra.isNotEmpty) ra.add(const SizedBox(height: 24));
      final cot = Column(
        key: ValueKey('cum-${c.ma}'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ds,
      );
      ra.add(khoaCua == null ? cot : KeyedSubtree(key: khoaCua(c), child: cot));
    }
    return ra;
  }
}

// ── Định dạng dùng chung ──────────────────────────────────────────────────

/// Chuỗi có phát sinh nào ở chiều đang hỏi không.
///
/// [chieuRa] `true` hỏi cặp *Cho vay / Thu nợ*, `false` hỏi cặp *Đi vay / Trả
/// nợ*. Vẽ một biểu đồ toàn số 0 trông như lỗi tải dữ liệu, nên khối nào không
/// có gì thì không hiện.
bool coVayNo(List<DiemVayNo> ds, {required bool chieuRa}) => ds.any(
      (d) => chieuRa ? (d.choVay > 0 || d.thuNo > 0) : (d.diVay > 0 || d.traNo > 0),
    );

