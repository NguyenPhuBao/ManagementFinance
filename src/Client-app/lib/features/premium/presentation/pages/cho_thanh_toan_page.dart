import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/realtime/realtime_channel.dart';
import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/luu_anh_qr.dart';
import '../../data/mo_lien_ket.dart';
import '../../data/models/don_thanh_toan.dart';
import '../../data/repositories/don_thanh_toan_repository.dart';
import '../../domain/trang_thai_don.dart';
import '../bloc/goi_cubit.dart';
import '../state/bo_hoi_trang_thai_don.dart';
import '../widgets/cho_thanh_toan/khoi_ma_qr.dart';
import '../widgets/cho_thanh_toan/khoi_thong_tin_chuyen_khoan.dart';

/// Màn Đang chờ thanh toán `/premium/cho-thanh-toan` (spec Premium 2026-10-06 mục 9.3; spec G94 2026-10-18 mục 5.4).
/// Màn Stitch *"Thanh toán Premium - Đang chờ (mã QR + Lưu mã)"* `95b2774f085747fa8777aea3505bb6ee` (thân chờ — thay
/// `b05060e3…` của bản 2026-10-06) và *"Thanh toán Premium - Thành công"* `8586dc34…` (thành công + hết hạn; Stitch vẽ
/// thêm danh sách đặc quyền ở màn thành công — bản thi công không chép, lệch có chủ ý).
///
/// Đủ thông tin để trả mà KHÔNG rời app: ảnh VietQR server dựng + *Lưu mã QR* (lưu rồi *Quét từ ảnh* trong app ngân
/// hàng — số tiền, nội dung điền sẵn), khối thông tin chuyển khoản có nút chép, ba bước hướng dẫn. **Không tự mở** trang
/// PayOS (đảo mục 9.3 của spec 2026-10-06 — người dùng chốt 2026-10-18); nút phụ *Mở trang thanh toán PayOS* giữ lối ấy.
///
/// Hỏi `order-status` mỗi 3 s CHỈ khi màn đang hiện — ba vế, thiếu vế nào là hỏi ngầm vô ích: `TickerMode` (nhánh shell
/// / route bị che), `ModalRoute.isCurrent` (có route chồng lên), vòng đời app `resumed` (người dùng đang ở app ngân hàng).
/// Hỏi NGAY khi quay lại app, khi bấm *Tôi đã chuyển khoản*, và khi socket báo (`account.upgraded`, `payment.*`).
/// Đồng hồ trên máy chỉ để HIỆN — server quyết hết hạn (G94 việc 1).
///
/// Server trả trạng thái đối soát (`WAITING_CONFIRMATION` · `REFUND_PENDING` · `REFUNDED`) → màn được THAY bằng Chi tiết
/// đơn `/premium/don/:orderCode` (Back từ đó về Nâng cấp) — xác nhận chuyển thừa ở đó, một chỗ cho mọi lối vào.
class ChoThanhToanPage extends StatefulWidget {
  const ChoThanhToanPage({
    super.key,
    required this.don,
    this.repo,
    this.goi,
    this.moLienKet,
    this.luuAnh,
    this.nguonAnhQr,
    this.suKien,
    this.clock,
  });

  final DonThanhToan don;

  /// `null` → `sl<DonThanhToanRepository>()`.
  final DonThanhToanRepository? repo;

  /// `null` → `context.read<GoiCubit>()`.
  final GoiCubit? goi;

  /// `null` → `moLienKetNgoai` (url_launcher).
  final MoLienKet? moLienKet;

  /// `null` → `sl<LuuAnhQr>()`.
  final LuuAnhQr? luuAnh;

  /// Dựng ảnh từ `qrUrl`. `null` → `NetworkImage`. Khe tiêm vì `flutter test` trả 400 cho mọi ảnh mạng.
  final ImageProvider Function(Uri url)? nguonAnhQr;

  /// `null` → `sl<RealtimeChannel>().events`.
  final Stream<RealtimeEvent>? suKien;
  final DateTime Function()? clock;

  @override
  State<ChoThanhToanPage> createState() => _ChoThanhToanPageState();
}

enum _Man { cho, thanhCong, hetHan, daHuy }

class _ChoThanhToanPageState extends State<ChoThanhToanPage> with WidgetsBindingObserver {
  late final BoHoiTrangThaiDon _bo;

  /// Ảnh QR dựng MỘT lần — dựng lại mỗi nhịp đồng hồ là mỗi giây một lượt tải với nguồn không so bằng giá trị.
  late final ImageProvider? _anhQr;
  Timer? _demNguoc;
  StreamSubscription<RealtimeEvent>? _subSuKien;
  ValueListenable<TickerModeData>? _ticker;
  ModalRoute<Object?>? _route;
  AppLifecycleState _vongDoi = WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;

  _Man _man = _Man.cho;

  /// Đã gọi `pushReplacement` sang Chi tiết đơn — mọi câu trả lời về muộn bỏ qua.
  bool _daSangChiTiet = false;
  bool _moHong = false;
  bool _dangLuu = false;
  Duration _conLai = Duration.zero;

  DonThanhToanRepository get _repo => widget.repo ?? sl<DonThanhToanRepository>();
  GoiCubit get _goi => widget.goi ?? context.read<GoiCubit>();
  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bo = BoHoiTrangThaiDon(
      hoi: () => _repo.trangThaiDon(widget.don.orderCode),
      khiCo: _khiCo,
    );
    _subSuKien = (widget.suKien ?? sl<RealtimeChannel>().events).listen((e) {
      if ((e == RealtimeEvent.taiKhoanNangCap || e == RealtimeEvent.donThanhToanDoi) && _man == _Man.cho) {
        unawaited(_bo.hoiNgay());
      }
    });
    final qr = widget.don.qrUrl;
    _anhQr = qr == null ? null : (widget.nguonAnhQr ?? (u) => NetworkImage(u.toString()))(qr);
    _capNhatConLai();
    _demNguoc = Timer.periodic(const Duration(seconds: 1), (_) => _nhipDem());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = TickerMode.getValuesNotifier(context);
    if (!identical(t, _ticker)) {
      _ticker?.removeListener(_xet);
      _ticker = t..addListener(_xet);
    }
    _route = ModalRoute.of(context);
    _xet();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final vua = _vongDoi;
    _vongDoi = state;
    _xet();
    // Quay lại app (từ app ngân hàng / trình duyệt) → hỏi ngay, không chờ nhịp.
    if (state == AppLifecycleState.resumed && vua != AppLifecycleState.resumed && _man == _Man.cho) {
      unawaited(_bo.hoiNgay());
    }
  }

  bool get _hien =>
      (_ticker?.value.enabled ?? true) && _vongDoi == AppLifecycleState.resumed && (_route?.isCurrent ?? true);

  void _xet() {
    if (_hien && _man == _Man.cho && !_daSangChiTiet) {
      _bo.batDau();
    } else {
      _bo.dung();
    }
  }

  Future<void> _mo() async {
    final ok = await (widget.moLienKet ?? moLienKetNgoai)(widget.don.checkoutUrl);
    if (!ok && mounted) setState(() => _moHong = true);
  }

  Future<void> _luuMa(Uri qr) async {
    setState(() => _dangLuu = true);
    final kq = await (widget.luuAnh ?? sl<LuuAnhQr>()).luu(qr, ten: 'FlowMoney-QR-${widget.don.orderCode}.png');
    if (!mounted) return;
    setState(() => _dangLuu = false);
    if (kq == KetQuaLuuAnh.daLuu) {
      baoNhanh('Đã lưu mã QR vào Thư viện ảnh', loai: LoaiThongBao.xong);
    } else {
      baoNhanh('Không lưu được mã QR. Hãy chụp màn hình.', loai: LoaiThongBao.loi);
    }
  }

  void _capNhatConLai() {
    final d = widget.don.hetHanLuc.difference(_now());
    _conLai = d.isNegative ? Duration.zero : d;
  }

  /// Đồng hồ trên máy chỉ để HIỆN số giây còn lại — về 0 cũng không đưa màn sang hết hạn. Server là nguồn sự thật:
  /// `order-status` tự trả `EXPIRED` cho đơn `PENDING` quá `expired_at`, còn `WAITING_CONFIRMATION` không bao giờ hết
  /// hạn. Tự kết luận ở đây là chặn mọi câu trả lời sau đó (`_khiCo` chỉ nhận khi màn còn `cho`): người chuyển thừa quay
  /// lại sau hạn từng thấy *"Đơn đã hết hạn"* thay cho lối xác nhận (G94 việc 1).
  void _nhipDem() {
    if (!mounted) return;
    // `isCurrent` không có bộ báo — hỏi mỗi nhịp, như `TheoDoiXem`.
    _xet();
    setState(_capNhatConLai);
  }

  Future<void> _khiCo(TrangThaiDon t) async {
    if (!mounted || _man != _Man.cho || _daSangChiTiet) return;
    switch (t) {
      case TrangThaiDon.pending:
        return;
      case TrangThaiDon.paid:
        _bo.dung();
        await _goi.lamMoi();
        if (!mounted) return;
        setState(() => _man = _Man.thanhCong);
      case TrangThaiDon.waitingConfirmation || TrangThaiDon.refundPending || TrangThaiDon.refunded:
        _bo.dung();
        _daSangChiTiet = true;
        context.pushReplacement('/premium/don/${widget.don.orderCode}');
      case TrangThaiDon.expired:
        _bo.dung();
        setState(() => _man = _Man.hetHan);
      case TrangThaiDon.cancelled:
        _bo.dung();
        setState(() => _man = _Man.daHuy);
    }
  }

  @override
  void dispose() {
    _bo.dung();
    _demNguoc?.cancel();
    unawaited(_subSuKien?.cancel());
    _ticker?.removeListener(_xet);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
          'Thanh toán Premium',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: switch (_man) {
            _Man.cho => _thanCho(),
            _Man.thanhCong => _thanThanhCong(),
            _Man.hetHan => _thanKetThuc('Đơn đã hết hạn', 'Đơn thanh toán chỉ có hiệu lực trong thời hạn quy định.'),
            _Man.daHuy => _thanKetThuc('Đơn đã huỷ', 'Đơn thanh toán này đã bị huỷ.'),
          },
        ),
      ),
    );
  }

  BoxDecoration get _nenThe => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      );

  Widget _the(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _nenThe,
        child: Column(children: children),
      );

  ButtonStyle get _nutChinh => ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  String _mmss(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _thanCho() {
    final don = widget.don;
    final qr = don.qrUrl;
    final anh = _anhQr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _theTren(don),
        if (qr != null && anh != null) ...[
          const SizedBox(height: 12),
          KhoiMaQr(
            anh: anh,
            dangLuu: _dangLuu,
            onLuu: () => unawaited(_luuMa(qr)),
          ),
        ],
        const SizedBox(height: 12),
        KhoiThongTinChuyenKhoan(
          soTien: don.soTien,
          soTaiKhoan: don.soTaiKhoan,
          chuTaiKhoan: don.chuTaiKhoan,
          noiDung: don.noiDung,
        ),
        const SizedBox(height: 14),
        // `Flexible` cho chữ: ở 360 dp hàng này tràn 155 px khi để trần (test bắt).
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Flexible(
              child: Text('Đang chờ bạn chuyển khoản…',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _theCachThanhToan(),
        const SizedBox(height: 16),
        ElevatedButton(
          key: const Key('cho-da-chuyen'),
          onPressed: () => unawaited(_bo.hoiNgay()),
          style: _nutChinh,
          child: const Text('Tôi đã chuyển khoản'),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          key: const Key('cho-mo-payos'),
          onPressed: _mo,
          icon: const Icon(Icons.open_in_new, size: 17, color: AppColors.textSecondary),
          label: const Text('Mở trang thanh toán PayOS'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        if (_moHong) ...[
          const Text('Không mở được trình duyệt. Chép link rồi mở tay:',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          SelectableText(don.checkoutUrl.toString(),
              key: const Key('cho-link'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.primary)),
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: don.checkoutUrl.toString())),
            child: const Text('Chép'),
          ),
        ],
        TextButton(
          key: const Key('cho-huy'),
          onPressed: () => context.pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Huỷ'),
        ),
      ],
    );
  }

  Widget _theTren(DonThanhToan don) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _nenThe,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, size: 15, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        'Còn ${_mmss(_conLai)}',
                        key: const Key('cho-dem-nguoc'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Mã đơn #${don.orderCode}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                CurrencyFormatter.format(don.soTien.toDouble()),
                maxLines: 1,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 4),
            const Text('Gói FlowMoney Premium 30 ngày',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _theCachThanhToan() {
    const buoc = [
      'Lưu mã QR hoặc chụp màn hình',
      'Mở app ngân hàng → Quét QR → chọn ảnh',
      'Chuyển xong quay lại đây — app tự kiểm tra',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _nenThe,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CÁCH THANH TOÁN',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: AppColors.textPrimary)),
          for (var i = 0; i < buoc.length; i++) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(buoc[i], style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _thanThanhCong() {
    final hetHan = _goi.state.hetHan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _the([
          const Icon(Icons.check_circle, size: 56, color: AppColors.income),
          const SizedBox(height: 12),
          const Text('Nâng cấp Premium thành công',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
          if (hetHan != null) ...[
            const SizedBox(height: 6),
            Text(
              'Hạn dùng đến ${DateFormat('dd/MM/yyyy').format(hetHan.toLocal())}',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Mã đơn #${widget.don.orderCode} · ${CurrencyFormatter.format(widget.don.soTien.toDouble())}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ]),
        const SizedBox(height: 16),
        ElevatedButton(
          key: const Key('cho-xong'),
          // Về màn TRƯỚC Nâng cấp (hai lớp). Đến từ cửa chặn thì người dùng tự
          // bấm + lần nữa — không tự mở form (spec 9.3).
          onPressed: () {
            context.pop();
            if (context.canPop()) context.pop();
          },
          style: _nutChinh,
          child: const Text('Xong'),
        ),
      ],
    );
  }

  Widget _thanKetThuc(String tieuDe, String moTa) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _the([
            const Icon(Icons.timer_off_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(tieuDe,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 6),
            Text(moTa,
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('cho-tao-don-moi'),
            onPressed: () => context.pop(),
            style: _nutChinh,
            child: const Text('Tạo đơn mới'),
          ),
        ],
      );
}
