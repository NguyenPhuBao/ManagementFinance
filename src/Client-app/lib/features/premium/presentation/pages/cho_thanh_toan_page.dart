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
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/bo_hoi_trang_thai_don.dart';
import '../../data/mo_lien_ket.dart';
import '../../data/payment_api.dart';
import '../../domain/don_thanh_toan.dart';
import '../bloc/goi_cubit.dart';

/// Màn Đang chờ thanh toán `/premium/cho-thanh-toan` (spec Premium 2026-10-06
/// & Quy trình đối soát thanh toán 2026-10-15).
///
/// Hiển thị mã QR VietQR động kèm mã nhận diện 6 ký tự sinh tự động.
/// Hỗ trợ xử lý chuyển thừa tiền (xác nhận kích hoạt / hoàn tiền),
/// chuyển thiếu tiền (thông báo hoàn trả), và đếm ngược 10-30 phút.
class ChoThanhToanPage extends StatefulWidget {
  const ChoThanhToanPage({
    super.key,
    required this.don,
    this.api,
    this.goi,
    this.moLienKet,
    this.suKien,
    this.clock,
  });

  final DonThanhToan don;

  /// `null` → `sl<PaymentApi>()`.
  final PaymentApi? api;

  /// `null` → `context.read<GoiCubit>()`.
  final GoiCubit? goi;

  /// `null` → `moLienKetNgoai` (url_launcher).
  final MoLienKet? moLienKet;

  /// `null` → `sl<RealtimeChannel>().events`.
  final Stream<RealtimeEvent>? suKien;
  final DateTime Function()? clock;

  @override
  State<ChoThanhToanPage> createState() => _ChoThanhToanPageState();
}

enum _Man { cho, thanhCong, choXacNhanThua, canHoanTien, daHoanTien, hetHan, daHuy }

class _ChoThanhToanPageState extends State<ChoThanhToanPage>
    with WidgetsBindingObserver {
  late final BoHoiTrangThaiDon _bo;
  Timer? _demNguoc;
  StreamSubscription<RealtimeEvent>? _subSuKien;
  ValueListenable<TickerModeData>? _ticker;
  ModalRoute<Object?>? _route;
  AppLifecycleState _vongDoi =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;

  _Man _man = _Man.cho;
  bool _moHong = false;
  bool _daChepMa = false;
  bool _dangXuLyXacNhan = false;
  Duration _conLai = Duration.zero;

  PaymentApi get _api => widget.api ?? sl<PaymentApi>();
  GoiCubit get _goi => widget.goi ?? context.read<GoiCubit>();
  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bo = BoHoiTrangThaiDon(
      hoi: () async =>
          trangThaiDonTuChuoi((await _api.trangThaiDon(widget.don.orderCode))['status']),
      khiCo: _khiCo,
    );
    _subSuKien = (widget.suKien ?? sl<RealtimeChannel>().events).listen((e) {
      if (e == RealtimeEvent.taiKhoanNangCap && _man == _Man.cho) {
        unawaited(_bo.hoiNgay());
      }
    });
    _capNhatConLai();
    _demNguoc = Timer.periodic(const Duration(seconds: 1), (_) => _nhipDem());
    // Mở trang PayOS sau khung đầu — không chặn dựng màn.
    WidgetsBinding.instance.addPostFrameCallback((_) => _mo());
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
    // Quay lại app (từ trình duyệt) → hỏi ngay, không chờ nhịp.
    if (state == AppLifecycleState.resumed && vua != AppLifecycleState.resumed && _man == _Man.cho) {
      unawaited(_bo.hoiNgay());
    }
  }

  bool get _hien =>
      (_ticker?.value.enabled ?? true) &&
      _vongDoi == AppLifecycleState.resumed &&
      (_route?.isCurrent ?? true);

  void _xet() {
    if (_hien && _man == _Man.cho) {
      _bo.batDau();
    } else {
      _bo.dung();
    }
  }

  Future<void> _mo() async {
    final ok = await (widget.moLienKet ?? moLienKetNgoai)(widget.don.checkoutUrl);
    if (!ok && mounted) setState(() => _moHong = true);
  }

  void _capNhatConLai() {
    final d = widget.don.hetHanLuc.difference(_now());
    _conLai = d.isNegative ? Duration.zero : d;
  }

  void _nhipDem() {
    if (!mounted) return;
    // `isCurrent` không có bộ báo — hỏi mỗi nhịp, như `TheoDoiXem`.
    _xet();
    setState(_capNhatConLai);
    if (_conLai == Duration.zero && _man == _Man.cho) {
      setState(() => _man = _Man.hetHan);
      _bo.dung();
    }
  }

  Future<void> _khiCo(TrangThaiDon t) async {
    if (!mounted || _man != _Man.cho) return;
    switch (t) {
      case TrangThaiDon.pending:
        return;
      case TrangThaiDon.paid:
        _bo.dung();
        await _goi.lamMoi();
        if (!mounted) return;
        setState(() => _man = _Man.thanhCong);
      case TrangThaiDon.waitingConfirmation:
        _bo.dung();
        setState(() => _man = _Man.choXacNhanThua);
      case TrangThaiDon.refundPending:
        _bo.dung();
        setState(() => _man = _Man.canHoanTien);
      case TrangThaiDon.refunded:
        _bo.dung();
        setState(() => _man = _Man.daHoanTien);
      case TrangThaiDon.expired:
        _bo.dung();
        setState(() => _man = _Man.hetHan);
      case TrangThaiDon.cancelled:
        _bo.dung();
        setState(() => _man = _Man.daHuy);
    }
  }

  void _chepMa(String ma) {
    Clipboard.setData(ClipboardData(text: ma));
    setState(() => _daChepMa = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _daChepMa = false);
    });
  }

  Future<void> _xacNhanNangCap(bool accept) async {
    setState(() => _dangXuLyXacNhan = true);
    try {
      await _api.xacNhanNangCap(orderCode: widget.don.orderCode, accept: accept);
      if (accept) {
        await _goi.lamMoi();
        if (mounted) setState(() => _man = _Man.thanhCong);
      } else {
        if (mounted) setState(() => _man = _Man.canHoanTien);
      }
    } catch (e) {
      debugPrint('[Payment] Lỗi xác nhận nâng cấp: $e');
    } finally {
      if (mounted) setState(() => _dangXuLyXacNhan = false);
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
          style: TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: switch (_man) {
            _Man.cho => _thanCho(),
            _Man.thanhCong => _thanThanhCong(),
            _Man.choXacNhanThua => _thanChoXacNhanThua(),
            _Man.canHoanTien => _thanCanHoanTien(),
            _Man.daHoanTien => _thanDaHoanTien(),
            _Man.hetHan => _thanKetThuc('Đơn đã hết hạn',
                'Đơn thanh toán chỉ có hiệu lực trong thời hạn quy định.'),
            _Man.daHuy =>
              _thanKetThuc('Đơn đã huỷ', 'Đơn thanh toán này đã bị huỷ.'),
          },
        ),
      ),
    );
  }

  Widget _the(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _the([
          const Icon(Icons.hourglass_top, size: 40, color: AppColors.warning),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.format(don.soTien.toDouble()),
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text('Mã đơn #${don.orderCode}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),

          // Mã nhận diện 6 ký tự
          if (don.recognitionCode != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCE93D8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MÃ NHẬN DIỆN CHUYỂN KHOẢN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7B1FA2),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          don.recognitionCode!,
                          key: const Key('cho-ma-nhan-dien'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Color(0xFF4A148C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('cho-chep-ma'),
                    onPressed: () => _chepMa(don.recognitionCode!),
                    icon: Icon(_daChepMa ? Icons.check : Icons.copy, size: 16),
                    label: Text(_daChepMa ? 'Đã chép' : 'Sao chép'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF7B1FA2),
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          Text(
            'Còn ${_mmss(_conLai)}',
            key: const Key('cho-dem-nguoc'),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE65100)),
          ),
          const SizedBox(height: 12),

          if (don.qrUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                don.qrUrl.toString(),
                height: 160,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Flexible(
                child: Text('Đang chờ xác nhận từ ngân hàng…',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            ],
          ),
          if (_moHong) ...[
            const SizedBox(height: 16),
            const Text('Không mở được trình duyệt. Chép link rồi mở tay:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            SelectableText(don.checkoutUrl.toString(),
                key: const Key('cho-link'),
                style: const TextStyle(fontSize: 12, color: AppColors.primary)),
            TextButton(
              onPressed: () => Clipboard.setData(
                  ClipboardData(text: don.checkoutUrl.toString())),
              child: const Text('Chép'),
            ),
          ],
        ]),
        const SizedBox(height: 12),
        const Text(
          'Trang thanh toán đã mở trong trình duyệt. Trả xong, quay lại app là đủ.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          key: const Key('cho-mo-lai'),
          onPressed: _mo,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Mở lại trang thanh toán'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          key: const Key('cho-da-chuyen'),
          onPressed: () => unawaited(_bo.hoiNgay()),
          style: _nutChinh,
          child: const Text('Tôi đã chuyển khoản'),
        ),
        TextButton(
          key: const Key('cho-huy'),
          onPressed: () => context.pop(),
          child: const Text('Huỷ'),
        ),
      ],
    );
  }

  Widget _thanChoXacNhanThua() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _the([
            const Icon(Icons.help_outline, size: 48, color: Color(0xFF7B1FA2)),
            const SizedBox(height: 12),
            const Text(
              'Xác nhận chuyển thừa tiền',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hệ thống ghi nhận bạn đã chuyển nhiều hơn số tiền gói cước yêu cầu. Bạn có đồng ý sử dụng số tiền này để kích hoạt gói dịch vụ Premium không?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            if (widget.don.amountReceived != null) ...[
              const SizedBox(height: 8),
              Text(
                'Số tiền đã chuyển: ${CurrencyFormatter.format(widget.don.amountReceived!.toDouble())}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF7B1FA2)),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('cho-dong-y-thua'),
            onPressed: _dangXuLyXacNhan ? null : () => _xacNhanNangCap(true),
            style: _nutChinh,
            child: _dangXuLyXacNhan
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Đồng ý kích hoạt gói'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('cho-tu-choi-thua'),
            onPressed: _dangXuLyXacNhan ? null : () => _xacNhanNangCap(false),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Từ chối & Yêu cầu hoàn tiền'),
          ),
        ],
      );

  Widget _thanCanHoanTien() => _thanKetThuc(
        'Cần xử lý hoàn tiền',
        'Số tiền bạn chuyển không khớp hoặc bạn đã từ chối kích hoạt. Đơn hàng đã được chuyển sang danh sách hoàn tiền. Quản trị viên sẽ liên hệ và hoàn trả lại số tiền cho bạn.',
      );

  Widget _thanDaHoanTien() => _thanKetThuc(
        'Đã hoàn tiền',
        'Đơn hàng này đã được Quản trị viên hoàn trả số tiền thành công.',
      );

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
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 6),
            Text(moTa,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
