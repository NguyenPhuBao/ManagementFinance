import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/gioi_han_do_dai.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/datasources/chia_se_chu.dart';
import '../../data/models/loi_moi.dart';
import '../../data/repositories/nha_repository.dart';
import '../../domain/cau_loi_nha.dart';
import '../../domain/moi_thanh_vien.dart';
import '../../domain/quyen_nha.dart';
import '../../domain/vai_nha.dart';
import '../bloc/moi_thanh_vien_cubit.dart';
import '../bloc/nha_cubit.dart';
import '../widgets/chu_don_cach.dart';
import '../widgets/gac_vai_chu.dart';
import '../widgets/moi_thanh_vien/chon_vai_moi.dart';
import '../widgets/moi_thanh_vien/danh_sach_loi_moi.dart';
import '../widgets/khung_the_nha.dart';

/// Màn Mời thành viên `/nha/moi` (`01` mục 2.1; spec 5.2, 12.2; Stitch `b017710c…`).
class MoiThanhVienPage extends StatefulWidget {
  const MoiThanhVienPage({super.key, this.repo, this.chiaSe});

  /// `null` → `sl<NhaRepository>()`.
  final NhaRepository? repo;

  /// `null` → `sl<ChiaSeChu>()`.
  final ChiaSeChu? chiaSe;

  @override
  State<MoiThanhVienPage> createState() => _MoiThanhVienPageState();
}

class _MoiThanhVienPageState extends State<MoiThanhVienPage> {
  final _email = TextEditingController();
  late final NhaCubit _nha;
  late final MoiThanhVienCubit _moi;
  final _subs = <StreamSubscription<String>>[];
  StreamSubscription<NhaState>? _subNha;
  VaiNha _vaiEmail = VaiNha.thanhVien;
  VaiNha _vaiMa = VaiNha.thanhVien;

  @override
  void initState() {
    super.initState();
    final repo = widget.repo ?? sl<NhaRepository>();
    _nha = NhaCubit(repo);
    _moi = MoiThanhVienCubit(repo);
    void bao(String c) => baoNhanh(c, loai: LoaiThongBao.loi);
    _subs..add(_nha.canBao.listen(bao))..add(_moi.canBao.listen(bao));
    // Nhà đổi từ máy khác (người được mời nhận mã / từ chối): nạp lại danh sách, nếu không `conChoMoi` đếm mã đã chết. Chỉ khi
    // vẫn là Chủ (người khác gọi `/invites` là 403 → làm mới nhà → vòng lặp) và khi chính `nha` đổi (không phải cờ dangXuLy).
    var nhaTruoc = _nha.state.nha;
    _subNha = _nha.stream.listen((s) {
      if (identical(s.nha, nhaTruoc)) return;
      nhaTruoc = s.nha;
      if (s.daNap && s.nha.coNha && s.nha.vai == VaiNha.chu) unawaited(_moi.napTuDong());
    });
    unawaited(_nha.moTrang());
    unawaited(_moi.nap());
  }

  @override
  void dispose() {
    _email.dispose();
    unawaited(_subNha?.cancel());
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(_nha.close());
    unawaited(_moi.close());
    super.dispose();
  }

  Future<void> _chepMa(String ma) async {
    try {
      await Clipboard.setData(ClipboardData(text: ma));
    } catch (_) {
      if (mounted) baoNhanh(cauLoiNha(LoaiLoiNha.khac), loai: LoaiThongBao.loi);
      return;
    }
    if (mounted) baoNhanh('Đã chép mã mời', loai: LoaiThongBao.xong);
  }

  Future<void> _chiaSeMa(String chu) async {
    try {
      await (widget.chiaSe ?? sl<ChiaSeChu>()).chiaSe(chu);
    } catch (_) {
      if (mounted) baoNhanh(cauLoiNha(LoaiLoiNha.khac), loai: LoaiThongBao.loi);
    }
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [BlocProvider.value(value: _nha), BlocProvider.value(value: _moi)],
        child: GacVaiChu(
          dangTuThaoTac: () => false,
          child: Scaffold(
            appBar: AppBar(title: const Text('Mời thành viên')),
            body: SafeArea(
              child: BlocBuilder<NhaCubit, NhaState>(
                builder: (context, n) => BlocBuilder<MoiThanhVienCubit, MoiThanhVienState>(
                  builder: (context, m) => ListView(padding: const EdgeInsets.all(16), children: _than(n, m)),
                ),
              ),
            ),
          ),
        ),
      );

  List<Widget> _than(NhaState n, MoiThanhVienState m) {
    final chu = Theme.of(context).textTheme;
    final nha = n.nha.nha;
    final now = DateTime.now();
    final choPhep = duocLamViecNha(ViecNha.taoMa, vai: n.nha.vai, trangThai: nha?.trangThai);
    final conCho = nha == null ||
        conChoMoi(soThanhVien: n.nha.thanhVien.length, soLoiMoiConHieuLuc: _moi.soConHieuLuc, toiDa: nha.toiDaThanhVien);
    // Kho chưa nạp thì `vai` còn null: `choPhep` false nhưng chưa có gì để nói.
    final lyDo = !n.daNap
        ? null
        : n.nha.vai != VaiNha.chu
            ? cauLoiNha(LoaiLoiNha.khongPhaiChu)
            : !choPhep
                ? cauLoiNha(LoaiLoiNha.nhaChiXem)
                : (conCho ? null : 'Nhà đã đủ người, kể cả lời mời còn hiệu lực.');
    final khoa = !n.daNap || lyDo != null;
    final hien = dongLoiMoiHien(m.ds, now);
    // Mã vừa tạo mà đã quá hạn thì không còn gì để chia sẻ (cùng định nghĩa `conHieuLucLuc` với danh sách).
    final ma = m.maVuaTao != null && m.maVuaTao!.conHieuLucLuc(now) ? m.maVuaTao : null;
    return [
      if (lyDo != null) ...[
        Text(lyDo, style: chu.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
      ],
      KhungTheNha(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.mail_outline, size: 22),
              const SizedBox(width: 8),
              Text('Mời qua email', style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            // Nhãn đặt TRÊN ô, gợi ý trong ô (Stitch `b017710c…`), không dùng nhãn nổi của ô.
            Text('Email', style: chu.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              inputFormatters: const [GioiHanDoRong(DoRongCot.email)],
              // Gợi ý xám (Stitch `moi`): hint mặc định của theme là màu chữ nên đen đậm hơn chữ đã gõ. Chỉ ô này, không đổi theme.
              decoration: InputDecoration(
                hintText: 'ten@gmail.com',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                errorText: emailCoDau(_email.text) ? 'Email không được có dấu' : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            ChonVaiMoi(vai: _vaiEmail, onDoi: (v) => setState(() => _vaiEmail = v)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: !khoa && emailHopLeSoBo(_email.text) && !m.dangGuiEmail
                  ? () => unawaited(_moi.guiEmail(_email.text, _vaiEmail))
                  : null,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Gửi lời mời'),
            ),
            // Một câu cho mọi email hợp lệ: không cho biết email có tài khoản hay không (`01` mục 2.2).
            if (m.emailVuaGui != null) ...[
              const SizedBox(height: 8),
              Container(
                key: const Key('da-gui-loi-moi'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFAF1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.secondaryContainer),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline, size: 20, color: AppColors.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Đã gửi lời mời tới ${m.emailVuaGui}',
                        style: chu.bodyMedium?.copyWith(color: AppColors.onSecondaryContainer)),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      KhungTheNha(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.vpn_key_outlined, size: 22),
              const SizedBox(width: 8),
              Text('Mã mời', style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: const Key('vai-ma'),
              child: ChonVaiMoi(vai: _vaiMa, onDoi: (v) => setState(() => _vaiMa = v)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: !khoa && !m.dangTaoMa ? () => unawaited(_moi.taoMa(_vaiMa)) : null,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Tạo mã'),
            ),
            if (ma != null) ...[
              const SizedBox(height: 12),
              // Ô xám bo góc ôm mã + hạn + hai nút (Stitch `moi`).
              Container(
                key: const Key('khoi-ma-vua-tao'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(ma.ma, textAlign: TextAlign.center, style: chu.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 4, fontFamily: kHoFontDonCach)),
                    if (ma.hetHan != null)
                      Text('Hết hạn ${DateFormatter.formatDateTime(ma.hetHan!.toLocal())}',
                          textAlign: TextAlign.center, style: chu.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => unawaited(_chiaSeMa(
                                cauChiaSeMaMoi(tenNha: nha?.ten ?? '', ma: ma.ma, hetHan: ma.hetHan))),
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Chia sẻ'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => unawaited(_chepMa(ma.ma)),
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('Chép mã'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      if (hien.isNotEmpty) ...[
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('LỜI MỜI', style: chu.labelMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ),
        DanhSachLoiMoi(ds: hien, now: now, onHuy: (x) => unawaited(_moi.huy(x)), dangHuy: m.dangHuy),
      ],
    ];
  }
}
