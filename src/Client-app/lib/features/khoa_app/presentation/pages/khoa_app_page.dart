import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/ui/do_chu.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/current_account.dart';
import '../../application/khoa_app_service.dart';
import '../../domain/luat_khoa_app.dart';
import '../bloc/cai_dat_khoa_app_cubit.dart';
import '../bloc/khoa_app_cubit.dart';
import '../widgets/mau_khoa_app.dart';
import 'dat_ma_pin_page.dart';

typedef MoDatPin = Future<bool?> Function(BuildContext context, CheDatPin che);

Future<bool?> _moDatPinMacDinh(BuildContext context, CheDatPin che) =>
    context.push<bool>('/settings/khoa-app/dat-pin?che=${che.name}');

const _xamPhu = Color(0xFF636360);
const _xamNhat = Color(0xFF8E8E89);

/// Trang Khoá ứng dụng — Stitch `129c2d77d97d4cff9322d05be9142a92` *"Khoá ứng dụng - Cài đặt (2 biến thể)"*.
class KhoaAppPage extends StatefulWidget {
  const KhoaAppPage({super.key, this.service, this.idaccount, this.moDatPin});

  final KhoaAppService? service;
  final int? idaccount;
  final MoDatPin? moDatPin;

  @override
  State<KhoaAppPage> createState() => _KhoaAppPageState();
}

class _KhoaAppPageState extends State<KhoaAppPage> {
  CaiDatKhoaAppCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final id = widget.idaccount ?? currentAccountIdOrNull(context);
    if (id == null) return;
    // `KhoaAppCubit` dựng ở `main.dart`, không ở DI; widget test dựng trang trần thì không có → `khiDoi` null.
    KhoaAppCubit? toanApp;
    try {
      toanApp = BlocProvider.of<KhoaAppCubit>(context);
    } catch (_) {}
    _cubit = CaiDatKhoaAppCubit(
      service: widget.service ?? sl<KhoaAppService>(),
      idaccount: id,
      khiDoi: toanApp?.napLai,
    )..napLai();
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  MoDatPin get _mo => widget.moDatPin ?? _moDatPinMacDinh;

  /// Đang có một trang PIN mở từ đây — chạm lần hai (công tắc, hàng Đổi PIN) bị bỏ qua, nếu không hai trang PIN chồng nhau.
  /// `dangLam` của cubit chỉ bật SAU khi trang PIN pop nên không chặn được.
  bool _dangMoTrangPin = false;

  Future<bool?> _moMotLan(CheDatPin che) async {
    if (_dangMoTrangPin) return null;
    _dangMoTrangPin = true;
    try {
      return await _mo(context, che);
    } finally {
      _dangMoTrangPin = false;
    }
  }

  Future<void> _batTatKhoa(bool bat) async {
    final c = _cubit!;
    final ok = await _moMotLan(bat ? CheDatPin.dat : CheDatPin.tat);
    if (ok != true || !mounted) return;
    await c.sauDatPin();
    // Máy có vân tay → hộp hệ thống "Chạm vân tay để bật" chính là câu hỏi "Dùng vân tay để mở?" (spec mục 4).
    if (bat && c.state.may.daDangKy) await c.batVanTay();
  }

  Future<void> _doiPin() async {
    final ok = await _moMotLan(CheDatPin.doi);
    if (ok == true && mounted) await _cubit!.sauDatPin();
  }

  /// Stitch `129c2d77…` biến thể 2: thanh kéo, tiêu đề 16 bold + nút đóng, hàng 15 (chọn: bold + nền `#F8F8F5` + tròn
  /// đen có ✓; không chọn: vòng viền `#D0D0CA`).
  Future<void> _chonTuKhoa(TuKhoaSau hien) async {
    final chon = await showModalBottomSheet<TuKhoaSau>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                decoration: BoxDecoration(color: const Color(0xFFD6D6D2), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
              child: Row(children: [
                const Expanded(
                  child: Text('Tự khoá sau',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close, size: 20, color: _xamNhat),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0EB)),
            for (final m in TuKhoaSau.values)
              Material(
                color: m == hien ? const Color(0xFFF8F8F5) : AppColors.surface,
                child: InkWell(
                  key: Key('tu-khoa-${m.name}'),
                  onTap: () => Navigator.of(ctx).pop(m),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(children: [
                      Expanded(
                        child: Text(m.nhan,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: m == hien ? FontWeight.w700 : FontWeight.w500,
                                color: AppColors.primary)),
                      ),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: m == hien ? AppColors.primary : null,
                          border: m == hien ? null : Border.all(color: const Color(0xFFD0D0CA)),
                        ),
                        child: m == hien ? const Icon(Icons.check, size: 16, color: AppColors.onPrimary) : null,
                      ),
                    ]),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chon != null && chon != hien) await _cubit!.datTuKhoaSau(chon);
  }

  /// Công tắc Stitch: rãnh bật `#1A1A19`, tắt `#D6D6D2`, tắt mờ `#E6E6E2`; núm trắng. Không dùng `activeColor`
  /// (lỗi thời trên 3.47 — `flutter analyze` sẽ vượt `MUC_NEN`).
  Widget _congTac({required Key key, required bool value, required ValueChanged<bool>? onChanged}) {
    return Switch(
      key: key,
      value: value,
      onChanged: onChanged,
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      trackColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return const Color(0xFFE6E6E2);
        return s.contains(WidgetState.selected) ? AppColors.primary : const Color(0xFFD6D6D2);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Khoá ứng dụng')),
      body: cubit == null
          ? const SizedBox.shrink()
          : BlocConsumer<CaiDatKhoaAppCubit, CaiDatKhoaApp>(
              bloc: cubit,
              listenWhen: (_, b) => b.loiNhan != null,
              listener: (_, s) => baoNhanh(s.loiNhan!, loai: LoaiThongBao.loi),
              builder: (context, s) {
                if (s.dangTai) return const Center(child: CircularProgressIndicator());
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _nhom('KHOÁ FLOWMONEY', [
                      _hang(
                        icon: Icons.lock_outline,
                        tieuDe: 'Khoá FlowMoney',
                        phu: 'Hỏi mã PIN mỗi khi mở app',
                        cuoi: _congTac(key: const Key('cong-tac-khoa'), value: s.daBat, onChanged: s.dangLam ? null : _batTatKhoa),
                      ),
                      if (s.daBat)
                        _hang(
                          key: const Key('hang-doi-pin'),
                          icon: Icons.password,
                          tieuDe: 'Đổi mã PIN',
                          cuoi: const Icon(Icons.chevron_right, color: _xamNhat, size: 20),
                          onTap: _doiPin,
                        ),
                    ]),
                    if (s.daBat && s.may.hoTro) ...[
                      const SizedBox(height: 24),
                      _nhom('MỞ NHANH', [
                        _hang(
                          icon: Icons.fingerprint,
                          tieuDe: 'Mở bằng vân tay',
                          mo: !s.may.daDangKy,
                          phu: s.may.daDangKy
                              ? 'Dùng vân tay đã đăng ký trên máy'
                              : 'Thêm vân tay trong Cài đặt của máy để dùng',
                          cuoi: _congTac(
                            key: const Key('cong-tac-van-tay'),
                            value: s.coVanTay && s.may.daDangKy,
                            onChanged: s.may.daDangKy && !s.dangLam
                                ? (bat) => bat ? cubit.batVanTay() : cubit.tatVanTay()
                                : null,
                          ),
                        ),
                      ]),
                    ],
                    if (s.daBat) ...[
                      const SizedBox(height: 24),
                      _nhom('TỰ KHOÁ', [
                        _hang(
                          key: const Key('hang-tu-khoa'),
                          icon: Icons.timer_outlined,
                          tieuDe: 'Tự khoá sau',
                          phu: 'Khi app ở nền lâu hơn mức này',
                          giaTri: s.tuKhoaSau.nhan,
                          onTap: () => _chonTuKhoa(s.tuKhoaSau),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Quên mã PIN thì đăng xuất rồi đăng nhập lại bằng mật khẩu tài khoản. Mã PIN chỉ lưu trên máy này.',
                      style: TextStyle(fontSize: 13, color: _xamPhu),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _nhom(String nhan, List<Widget> hang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(nhan,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kXamChuKhoaApp, letterSpacing: 0.5)),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E5E0)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: [
              for (var i = 0; i < hang.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: Color(0xFFF0F0EB)),
                hang[i],
              ],
            ]),
          ),
        ),
      ],
    );
  }

  static const _kieuGiaTri = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary);

  /// Bề rộng [chu] vẽ ra — cùng họ chữ của theme (`DefaultTextStyle`) và cùng cỡ chữ người dùng đặt (`textScaler`), nếu
  /// không phép đo lệch với chữ thật trên máy.
  double _rongChu(BuildContext context, String chu, TextStyle kieu) {
    final p = TextPainter(
      text: TextSpan(text: chu, style: DefaultTextStyle.of(context).style.merge(kieu)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final rong = p.width;
    p.dispose();
    return rong;
  }

  /// Hàng Stitch: đệm 14, icon 20 trong vòng tròn 36 nền `#F4F4F0`, tiêu đề 15 semibold, phụ 13. [mo] = tắt mờ.
  ///
  /// [giaTri] (hàng chọn — giá trị + mũi tên ở bên phải theo Stitch): khi tiêu đề không còn vừa một dòng bên cạnh nó
  /// (khổ hẹp, cỡ chữ lớn — M15, Realme 320 dp) thì giá trị xuống dưới dòng phụ thay vì ép tiêu đề gãy dòng.
  Widget _hang({
    Key? key,
    required IconData icon,
    required String tieuDe,
    String? phu,
    Widget? cuoi,
    String? giaTri,
    VoidCallback? onTap,
    bool mo = false,
  }) {
    final kieuTieuDe = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: mo ? _xamPhu : AppColors.primary);
    Widget oGiaTri(String chu) => Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(chu, style: _kieuGiaTri)),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more, color: _xamNhat, size: 20),
        ]);
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: BoCucTheoFont(builder: (context, rang) {
          var duoi = false;
          if (giaTri != null) {
            final rongGiaTri = _rongChu(context, giaTri, _kieuGiaTri) + 4 + 20;
            final conChoTieuDe = rang.maxWidth - 36 - 12 - 12 - rongGiaTri;
            duoi = _rongChu(context, tieuDe, kieuTieuDe) > conChoTieuDe;
          }
          final ben = giaTri == null ? cuoi : (duoi ? null : oGiaTri(giaTri));
          return Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: AppColors.surfaceContainerLow, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: mo ? _xamNhat : AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tieuDe, style: kieuTieuDe),
                    if (phu != null) ...[
                      const SizedBox(height: 2),
                      Text(phu, style: TextStyle(fontSize: 13, color: mo ? _xamNhat : _xamPhu)),
                    ],
                    if (duoi) ...[const SizedBox(height: 6), oGiaTri(giaTri!)],
                  ],
                ),
              ),
              if (ben != null) ...[const SizedBox(width: 12), ben],
            ],
          );
        }),
      ),
    );
  }
}
