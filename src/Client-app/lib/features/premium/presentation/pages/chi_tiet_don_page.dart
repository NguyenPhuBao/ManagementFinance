import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/realtime/realtime_channel.dart';
import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/models/dong_lich_su.dart';
import '../../data/repositories/don_thanh_toan_repository.dart';
import '../../data/repositories/goi_repository.dart';
import '../../domain/don_can_xu_ly.dart';
import '../../domain/trang_thai_don.dart';
import '../bloc/chi_tiet_don_cubit.dart';
import '../bloc/goi_cubit.dart';
import '../widgets/chi_tiet_don/khoi_doi_soat.dart';
import '../widgets/chi_tiet_don/the_dau_don.dart';
import '../widgets/chi_tiet_don/the_ket_qua_don.dart';

/// Màn Chi tiết đơn `/premium/don/:orderCode` (spec G94 2026-10-18 mục 5.5) — MỘT màn cho mọi trạng thái đơn, mở từ
/// Lịch sử mua, thẻ ở màn Nâng cấp, và màn Chờ thanh toán khi server trả trạng thái đối soát. Stitch: `408de0af…`
/// (*Chờ xác nhận chuyển thừa + Hộp hỏi lại*), `d3b59018…` (*Bốn trạng thái*).
///
/// Lệch có chủ ý so với bản viết: spec nói đầu màn *luôn có giá gói*, hai màn Stitch (người dùng duyệt) không vẽ giá ở
/// thẻ đầu — giá nằm ở thân: dòng *Giá gói* của khối đối soát, *Đã thanh toán X*, và một dòng *Giá gói X* ở ba thân
/// một dòng (`pending` · `expired` · `cancelled`).
///
/// Nạp lại khi: tín hiệu `payment.*` (`donThanhToanDoi`) hoặc `account.upgraded`; quay lại app (người dùng vừa ở app
/// ngân hàng, hoặc chờ Admin hoàn tiền). Không hẹn giờ hỏi — trạng thái đối soát đổi do người, không do đồng hồ.
class ChiTietDonPage extends StatefulWidget {
  const ChiTietDonPage({
    super.key,
    required this.orderCode,
    this.repo,
    this.goiRepo,
    this.goi,
    this.suKien,
  });

  final int orderCode;

  /// `null` → `sl<DonThanhToanRepository>()`.
  final DonThanhToanRepository? repo;

  /// `null` → `sl<GoiRepository>()` (Đồng ý → `lamMoi`).
  final GoiRepository? goiRepo;

  /// `null` → `context.read<GoiCubit>()` (hạn dùng mới sau khi kích hoạt).
  final GoiCubit? goi;

  /// `null` → `sl<RealtimeChannel>().events`.
  final Stream<RealtimeEvent>? suKien;

  @override
  State<ChiTietDonPage> createState() => _ChiTietDonPageState();
}

class _ChiTietDonPageState extends State<ChiTietDonPage> with WidgetsBindingObserver {
  late final ChiTietDonCubit _cubit;
  StreamSubscription<String>? _subBao;
  StreamSubscription<RealtimeEvent>? _subSuKien;

  /// Nút vừa bấm (`true` = Đồng ý) — Cubit chỉ biết *đang gửi*; vòng xoay hiện ở đúng nút ấy.
  bool _vuaBamDongY = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = ChiTietDonCubit(
      orderCode: widget.orderCode,
      repo: widget.repo ?? sl<DonThanhToanRepository>(),
      goi: widget.goiRepo ?? sl<GoiRepository>(),
    );
    _subBao = _cubit.canBao.listen((cau) => baoNhanh(cau, loai: LoaiThongBao.loi));
    _subSuKien = (widget.suKien ?? sl<RealtimeChannel>().events).listen((e) {
      if (e == RealtimeEvent.donThanhToanDoi || e == RealtimeEvent.taiKhoanNangCap) unawaited(_cubit.nap());
    });
    unawaited(_cubit.nap());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_cubit.nap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subSuKien?.cancel());
    unawaited(_subBao?.cancel());
    unawaited(_cubit.close());
    super.dispose();
  }

  Future<void> _hoiTuChoi(DongLichSu d) async {
    final chuyen = d.soDaChuyen;
    final khoan = chuyen == null ? 'khoản đã chuyển' : 'khoản ${CurrencyFormatter.format(chuyen.toDouble())} này';
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Yêu cầu hoàn tiền?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        content: Text(
          'Bạn sẽ không dùng $khoan để kích hoạt gói. Quản trị viên sẽ hoàn lại cho bạn. Không đổi lại được.',
          style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            key: const Key('chi-tiet-hoi-lai-dong-y'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yêu cầu hoàn tiền'),
          ),
        ],
      ),
    );
    // Chạm nền ngoài hộp → `null` = như Huỷ.
    if (dongY != true || !mounted) return;
    setState(() => _vuaBamDongY = false);
    unawaited(_cubit.tuChoi());
  }

  // ── Dựng ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Chi tiết đơn',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<ChiTietDonCubit, ChiTietDonState>(
          bloc: _cubit,
          builder: (_, s) => switch (s) {
            ChiTietDonDangNap() => const Center(child: CircularProgressIndicator()),
            ChiTietDonLoi(:final cau) => _thuLai(cau),
            ChiTietDonKhongThay() => _thuLai('Không tìm thấy đơn này'),
            ChiTietDonCo() => SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TheDauDon(s.don),
                    const SizedBox(height: 12),
                    ..._than(s),
                  ],
                ),
              ),
          },
        ),
      ),
    );
  }

  Widget _thuLai(String cau) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(cau,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextButton(
                key: const Key('chi-tiet-thu-lai'),
                onPressed: () => unawaited(_cubit.nap()),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );

  String _ngay(DateTime d) => DateFormat('dd/MM/yyyy').format(d.toLocal());

  String _tien(int so) => CurrencyFormatter.format(so.toDouble());

  List<Widget> _than(ChiTietDonCo s) {
    final d = s.don;
    switch (d.trangThai) {
      case TrangThaiDon.waitingConfirmation:
        return _thanChoXacNhan(s);
      case TrangThaiDon.refundPending:
        return [_thanChoHoanTien(d)];
      case TrangThaiDon.refunded:
        final hoan = d.soDaHoan ?? d.soDaChuyen;
        final luc = d.hoanLuc;
        return [
          TheKetQuaDon(
            bieuTuong: Icons.assignment_return,
            mau: AppColors.textSecondary,
            tieuDe: hoan == null ? 'Đã hoàn tiền' : 'Đã hoàn ${_tien(hoan)}',
            phu: luc == null ? null : 'Ngày ${_ngay(luc)}',
          ),
        ];
      case TrangThaiDon.paid:
        if (s.vuaKichHoat) return _thanVuaKichHoat();
        final luc = d.traLuc;
        return [
          TheKetQuaDon(
            bieuTuong: Icons.check_circle,
            mau: AppColors.income,
            tieuDe: 'Đã thanh toán ${_tien(d.soTien)}',
            phu: luc == null ? null : 'Ngày ${_ngay(luc)}',
          ),
        ];
      case TrangThaiDon.expired:
        return [_thanMotDong(Icons.timer_off_outlined, AppColors.textSecondary, 'Đơn đã hết hạn', d)];
      case TrangThaiDon.cancelled:
        return [_thanMotDong(Icons.cancel_outlined, AppColors.textSecondary, 'Đơn đã huỷ', d)];
      case TrangThaiDon.pending:
        return [_thanMotDong(Icons.hourglass_top, AppColors.warning, 'Đơn đang chờ thanh toán', d)];
    }
  }

  Widget _thanMotDong(IconData bieuTuong, Color mau, String cau, DongLichSu d) =>
      TheKetQuaDon(bieuTuong: bieuTuong, mau: mau, tieuDe: cau, phu: 'Giá gói ${_tien(d.soTien)}');

  List<Widget> _thanChoXacNhan(ChiTietDonCo s) {
    final d = s.don;
    final chuyen = d.soDaChuyen;
    final lech = soTienLech(d);
    const hoi = 'Bạn có muốn dùng khoản đã chuyển để kích hoạt gói Premium 30 ngày không?';
    final dangGuiDongY = s.dangGui && _vuaBamDongY;
    final dangGuiTuChoi = s.dangGui && !_vuaBamDongY;
    return [
      KhoiDoiSoat(
        bieuTuong: Icons.warning_amber_rounded,
        nhan: 'BẠN ĐÃ CHUYỂN THỪA',
        dong: chuyen == null || lech == null
            ? const []
            : [
                DongTien('Đã chuyển', chuyen),
                DongTien('Giá gói', d.soTien),
                DongTien('Thừa', lech, mauNoiBat: AppColors.warning),
              ],
        cau: chuyen == null || lech == null ? 'Bạn đã chuyển nhiều hơn giá gói. $hoi' : hoi,
        cauLaCauHoi: true,
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        key: const Key('chi-tiet-dong-y'),
        onPressed: s.dangGui
            ? null
            : () {
                setState(() => _vuaBamDongY = true);
                unawaited(_cubit.dongY());
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: dangGuiDongY ? _vongXoay(Colors.white) : const Text('Đồng ý kích hoạt gói'),
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        key: const Key('chi-tiet-tu-choi'),
        onPressed: s.dangGui ? null : () => _hoiTuChoi(d),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: dangGuiTuChoi ? _vongXoay(AppColors.primary) : const Text('Yêu cầu hoàn tiền'),
      ),
      const SizedBox(height: 12),
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text('Chọn hoàn tiền thì không đổi lại được. Quản trị viên sẽ hoàn lại khoản đã chuyển.',
                style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary)),
          ),
        ],
      ),
    ];
  }

  Widget _thanChoHoanTien(DongLichSu d) {
    final chuyen = d.soDaChuyen;
    final lech = soTienLech(d);
    switch (lyDoHoanTien(d)) {
      case LyDoHoanTien.chuyenThieu when chuyen != null && lech != null:
        return KhoiDoiSoat(
          bieuTuong: Icons.warning_amber_rounded,
          nhan: 'BẠN ĐÃ CHUYỂN THIẾU',
          dong: [
            DongTien('Đã chuyển', chuyen),
            DongTien('Giá gói', d.soTien),
            DongTien('Thiếu', -lech, mauNoiBat: AppColors.error),
          ],
          cau: 'Khoản này chưa đủ để kích hoạt gói. Quản trị viên sẽ hoàn lại khoản đã chuyển cho bạn.',
        );
      case LyDoHoanTien.daTuChoi when chuyen != null:
        return KhoiDoiSoat(
          bieuTuong: Icons.undo,
          nhan: 'BẠN ĐÃ CHỌN HOÀN TIỀN',
          dong: [DongTien('Đã chuyển', chuyen)],
          cau: 'Bạn đã chọn không dùng khoản này để kích hoạt gói. '
              'Quản trị viên sẽ hoàn lại khoản đã chuyển cho bạn.',
        );
      default:
        // Không rõ lý do (bằng giá gói / server chưa ghi số đã chuyển) — không đoán, không hứa số tiền hoàn.
        return const TheKetQuaDon(
          bieuTuong: Icons.currency_exchange,
          mau: AppColors.warning,
          tieuDe: 'Đang chờ hoàn tiền',
          phu: 'Quản trị viên sẽ hoàn lại khoản đã chuyển cho bạn.',
        );
    }
  }

  List<Widget> _thanVuaKichHoat() {
    final hetHan = (widget.goi ?? context.read<GoiCubit>()).state.hetHan;
    return [
      TheKetQuaDon(
        bieuTuong: Icons.check_circle,
        mau: AppColors.income,
        tieuDe: 'Đã kích hoạt Premium',
        phu: hetHan == null ? null : 'Hạn dùng đến ${_ngay(hetHan)}',
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        key: const Key('chi-tiet-xong'),
        onPressed: () => context.pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Xong'),
      ),
    ];
  }

  Widget _vongXoay(Color mau) =>
      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: mau));
}
