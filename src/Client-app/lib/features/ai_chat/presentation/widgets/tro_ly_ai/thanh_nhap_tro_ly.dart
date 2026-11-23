// lib/features/ai_chat/presentation/widgets/tro_ly_ai/thanh_nhap_tro_ly.dart
/// Thanh nhập của màn Trợ lý AI — ô chữ, micro, nút Gửi (tách khỏi `ai_chat_page.dart` 2026-11-20: trang chạm trần 1.200
/// dòng của quét 23).
///
/// Micro (người dùng chốt 2026-11-20): Stitch gốc `75abffa9…` vẽ nút `mic` ngay trái nút Gửi; trạng thái nghe theo khuôn
/// đã duyệt của ô Nhập nhanh (`d696e81e…`, người dùng chọn không vẽ thêm). Dùng lại nguyên `NgheGiongNoiCubit` — nói xong
/// câu VÀO Ô, KHÔNG tự gửi (người dùng xem / sửa rồi bấm Gửi). Đang nghe → Gửi khoá; AI đang trả lời → micro khoá (lượt
/// chép lời bằng Gemma không được giành mô hình với lượt đang sinh).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../../transaction/data/nguon_giong_noi.dart';
import '../../../../transaction/presentation/bloc/nghe_giong_noi_cubit.dart';
import '../../../../transaction/presentation/bloc/nghe_giong_noi_state.dart';
import '../../../../transaction/presentation/widgets/bao_thong_bao_nghe.dart';
import '../../../../transaction/domain/chon_loi_nghe.dart' show ThongBaoNghe;
import '../../../../transaction/presentation/widgets/them_giao_dich/dong_dang_nghe.dart';

class ThanhNhapTroLy extends StatefulWidget {
  const ThanhNhapTroLy({
    super.key,
    required this.controller,
    required this.dangHoi,
    required this.khoaCaO,
    required this.goiY,
    required this.toiDaKyTu,
    required this.onGui,
    this.giongNoi,
  });

  final TextEditingController controller;

  /// AI đang trả lời — ô, Gửi và micro đều khoá.
  final bool dangHoi;

  /// Basic / tạm ngừng khoá cả ô (kể cả lệnh tạo) — spec Premium 8.1. Khoá thì không có micro.
  final bool khoaCaO;
  final String goiY;
  final int toiDaKyTu;
  final ValueChanged<String> onGui;

  /// `null` = máy không có bộ giọng nói (chưa đăng ký DI) → không micro.
  final NguonGiongNoi? giongNoi;

  @override
  State<ThanhNhapTroLy> createState() => _ThanhNhapTroLyState();
}

class _ThanhNhapTroLyState extends State<ThanhNhapTroLy> {
  late final NgheGiongNoiCubit? _nghe = widget.giongNoi == null ? null : NgheGiongNoiCubit(nguon: widget.giongNoi!);

  @override
  void dispose() {
    unawaited(_nghe?.close());
    super.dispose();
  }

  Future<void> _bamMicro() async {
    final nghe = _nghe;
    if (nghe == null) return;
    // IME đang soạn chữ với `controller.text` bị ghi mỗi lần có chữ tạm — bỏ focus trước (cùng lý do ô Nhập nhanh).
    if (nghe.state.trangThai == TrangThaiNghe.cho) FocusScope.of(context).unfocus();
    await nghe.bam();
  }

  void _bao(ThongBaoNghe t) => baoThongBaoNghe(t, nguon: widget.giongNoi, moCaiDatAi: () {
        if (mounted) unawaited(context.push('/ai-settings'));
      });

  @override
  Widget build(BuildContext context) {
    final nghe = _nghe;
    if (nghe == null) return _thanh(null);
    return MultiBlocListener(
      listeners: [
        // Lối Android: chữ đang nghe hiện dần trong ô.
        BlocListener<NgheGiongNoiCubit, NgheGiongNoiState>(
          bloc: nghe,
          listenWhen: (a, b) => b.trangThai == TrangThaiNghe.dangNghe && a.chuTam != b.chuTam,
          listener: (_, s) => widget.controller.text = s.chuTam,
        ),
        // Một câu xong → vào ô, KHÔNG gửi.
        BlocListener<NgheGiongNoiCubit, NgheGiongNoiState>(
          bloc: nghe,
          listenWhen: (a, b) => a.soLanXong != b.soLanXong,
          listener: (_, s) => widget.controller.text = s.cauXong ?? '',
        ),
        BlocListener<NgheGiongNoiCubit, NgheGiongNoiState>(
          bloc: nghe,
          listenWhen: (a, b) => a.soLanThongBao != b.soLanThongBao,
          listener: (_, s) => _bao(s.thongBao!),
        ),
      ],
      child: BlocBuilder<NgheGiongNoiCubit, NgheGiongNoiState>(bloc: nghe, builder: (_, s) => _thanh(s)),
    );
  }

  Widget _thanh(NgheGiongNoiState? s) {
    final trangThai = s?.trangThai ?? TrangThaiNghe.cho;
    final dangThu = trangThai == TrangThaiNghe.dangNghe || trangThai == TrangThaiNghe.dangGhi;
    final coMicro = _nghe != null && !widget.khoaCaO;
    final ranh = !widget.dangHoi && !widget.khoaCaO;
    final guiDuoc = ranh && trangThai == TrangThaiNghe.cho;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trangThai == TrangThaiNghe.dangNghe)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: NhanDangNghe(key: Key('tro-ly-dang-nghe')),
            )
          else if (trangThai == TrangThaiNghe.dangGhi)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: DongDangNghe(
                key: const Key('tro-ly-dang-ghi'),
                chamDo: true,
                chu: 'Đang ghi âm · ${s?.giay ?? 0} giây — nói xong ngừng 2 giây',
                onHuy: () => unawaited(_nghe?.huy()),
                khoaHuy: const Key('tro-ly-huy-nghe'),
              ),
            )
          else if (trangThai == TrangThaiNghe.dangChep)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: DongDangNghe(
                key: const Key('tro-ly-dang-chep'),
                chu: 'Đang chép lời bằng AI trên máy…',
                onHuy: () => unawaited(_nghe?.huy()),
                khoaHuy: const Key('tro-ly-huy-nghe'),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: dangThu
                  ? Border.all(color: AppColors.error, width: 2)
                  : Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    // Basic / tạm ngừng khoá cả ô (kể cả lệnh tạo) — spec Premium 8.1.
                    enabled: ranh,
                    maxLines: 4,
                    minLines: 1,
                    maxLength: widget.toiDaKyTu,
                    // Chỉ hiện bộ đếm khi sắp chạm giới hạn để không chiếm chỗ của ô nhập.
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                        currentLength < widget.toiDaKyTu - 100 ? null : Text('$currentLength/$maxLength'),
                    textInputAction: TextInputAction.send,
                    onSubmitted: guiDuoc ? widget.onGui : null,
                    style: const TextStyle(fontSize: 16, color: AppColors.onSurface),
                    decoration: InputDecoration(
                      // Đang nghe: ô trống chờ chữ chép lời (trạng thái ở dòng phía trên).
                      hintText: dangThu ? null : widget.goiY,
                      hintStyle: const TextStyle(color: AppColors.outline),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    ),
                  ),
                ),
                if (coMicro)
                  IconButton(
                    key: const Key('tro-ly-micro'),
                    tooltip: dangThu ? 'Dừng' : 'Nói',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    onPressed: widget.dangHoi || trangThai == TrangThaiNghe.dangChep
                        ? null
                        : () => unawaited(_bamMicro()),
                    // Dừng = vòng 32 dp nền đỏ 10 % + ô vuông 14 dp đỏ — khuôn ô Nhập nhanh (Stitch `d696e81e…`).
                    icon: dangThu
                        ? Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration:
                                BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: Container(
                              key: const Key('tro-ly-dung'),
                              width: 14,
                              height: 14,
                              decoration:
                                  BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(2)),
                            ),
                          )
                        : Icon(Icons.mic_none,
                            color: widget.dangHoi ? AppColors.outline : AppColors.onSurfaceVariant),
                  ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    color: guiDuoc ? AppColors.primary : AppColors.outline,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    key: const Key('tro-ly-gui'),
                    tooltip: 'Gửi',
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: guiDuoc ? () => widget.onGui(widget.controller.text) : null,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(10),
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
