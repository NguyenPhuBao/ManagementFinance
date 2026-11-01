import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../premium/domain/quyen_tinh_nang.dart';
import '../../../premium/presentation/bloc/co_quyen.dart';
import '../../data/models/loi_moi.dart';
import '../../data/repositories/nha_repository.dart';
import '../../domain/cau_loi_nha.dart';
import '../../domain/ma_moi.dart';
import '../bloc/tham_gia_nha_cubit.dart';
import '../widgets/chu_don_cach.dart';
import '../widgets/nhan_vai.dart';
import '../widgets/khung_the_nha.dart';

/// Ô mã mời: in hoa, bỏ khoảng trắng / gạch nối ngay lúc gõ, tối đa [kDoDaiMaMoi] ký tự.
class MaMoiFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final s = trichMaMoi(newValue.text)
        .split('')
        .where(kBangKyTuMaMoi.contains)
        .join();
    final cat = s.length > kDoDaiMaMoi ? s.substring(0, kDoDaiMaMoi) : s;
    if (cat == newValue.text) return newValue;
    return TextEditingValue(
        text: cat, selection: TextSelection.collapsed(offset: cat.length));
  }
}

/// Màn Tham gia bằng mã `/nha/tham-gia` (spec 5.3, 12.4; Stitch `c1a372b4…`). Quyền `thamGiaNha` KHÔNG qua `redirectTheoQuyen`:
/// mặc định mở với Basic, bị tắt nghĩa là admin chủ động, nên khoá kèm câu trung tính, không mời mua.
class ThamGiaNhaPage extends StatefulWidget {
  const ThamGiaNhaPage({super.key, this.repo});

  /// `null` → `sl<NhaRepository>()`.
  final NhaRepository? repo;

  @override
  State<ThamGiaNhaPage> createState() => _ThamGiaNhaPageState();
}

class _ThamGiaNhaPageState extends State<ThamGiaNhaPage> {
  late final ThamGiaNhaCubit _cubit;
  StreamSubscription<String>? _subBao;

  @override
  void initState() {
    super.initState();
    _cubit = ThamGiaNhaCubit(widget.repo ?? sl<NhaRepository>());
    _subBao = _cubit.canBao.listen((c) => baoNhanh(c, loai: LoaiThongBao.loi));
  }

  @override
  void dispose() {
    unawaited(_subBao?.cancel());
    unawaited(_cubit.close());
    super.dispose();
  }

  Future<void> _thamGia() async {
    if (await _cubit.thamGia() && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final duoc = context.coQuyen(MaQuyen.thamGiaNha);
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(title: const Text('Tham gia bằng mã')),
        body: SafeArea(
          child: BlocBuilder<ThamGiaNhaCubit, ThamGiaNhaState>(
            builder: (context, s) => Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                          duoc
                              ? 'Nhập mã 8 ký tự chủ nhà gửi cho bạn.'
                              : cauLoiNha(LoaiLoiNha.tinhNangKhongMo),
                          style: chu.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      TextField(
                        enabled: duoc && !s.dangThamGia,
                        keyboardType: TextInputType.visiblePassword,
                        enableSuggestions: false,
                        textAlign: TextAlign.center,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.characters,
                        style: chu.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700, letterSpacing: 4, fontFamily: kHoFontDonCach),
                        inputFormatters: [MaMoiFormatter()],
                        onChanged: _cubit.doiMa,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: duoc && maMoiHopLe(s.ma) && !s.dangXem && !s.dangThamGia
                            ? () => unawaited(_cubit.xem())
                            : null,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Xem trước'),
                      ),
                      if (s.xemTruoc != null) ...[
                        const SizedBox(height: 16),
                        _TheXemTruoc(x: s.xemTruoc!),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                'Vào nhà xong, dữ liệu của nhà sẽ tải về máy này.',
                                style: chu.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary)),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: duoc && s.xemTruoc != null && !s.dangThamGia && !s.dangXem
                          ? () => unawaited(_thamGia())
                          : null,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Tham gia'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18)
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TheXemTruoc extends StatelessWidget {
  const _TheXemTruoc({required this.x});

  final XemTruocLoiMoi x;

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    Widget dongWidget(String nhan, Widget gt) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Text(nhan,
                  style:
                      chu.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              Expanded(child: gt),
            ],
          ),
        );
    Widget dong(String nhan, String gt, {bool donCach = false}) => dongWidget(
        nhan,
        Text(gt,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: donCach ? const TextStyle(fontFamily: kHoFontDonCach) : null));
    return KhungTheNha(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12)),
              child:
                  const Icon(Icons.home_outlined, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('XEM TRƯỚC NHÀ',
                        style: chu.labelSmall
                            ?.copyWith(color: AppColors.textSecondary)),
                    Text(x.tenNha,
                        style: chu.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
          ]),
          const Divider(height: 20, color: AppColors.outlineVariant),
          dong('Chủ nhà', x.tenChuNha),
          dong('Thành viên', '${x.soThanhVien}/${x.toiDa}'),
          dongWidget(
              'Vai của bạn',
              Align(
                  alignment: Alignment.centerRight,
                  child: NhanVai(vai: x.vai))),
          if (x.hetHan != null)
            dong('Hạn mã', DateFormatter.formatDateTime(x.hetHan!.toLocal()), donCach: true),
        ],
      ),
    );
  }
}
