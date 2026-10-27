/// Thẻ *Nhập nhanh* của màn Thêm giao dịch (C2, spec §3) — tách từ `_buildNhapNhanh` ngày 2026-10-10 (spec bịt điểm rò
/// mục 5.2). Controller / focus / kết quả đọc do trang giữ; widget chỉ vẽ và báo `onDien` / `onHuy`.
library;

import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../../premium/domain/cau_quyen.dart';
import '../../../../premium/domain/quyen_tinh_nang.dart';
import '../../../../premium/presentation/widgets/nut_nang_cap.dart';
import '../../bloc/nghe_giong_noi_state.dart' show TrangThaiNghe;
import '../../bloc/them_giao_dich_state.dart' show KetQuaDien;
import 'dong_dang_nghe.dart';

/// Thẻ *Nhập nhanh* (C2, spec §3): ô một dòng + nút **Điền**; dưới là dòng tóm tắt những ô đã điền, cảnh báo, và câu lý
/// do khi danh mục đến từ B1.
///
/// Phần giọng nói theo màn Stitch `d696e81e…` (người dùng chốt 2026-10-16): nhãn *"Giọng nói & Gõ"* / *"Đang nghe…"* ở
/// đầu thẻ, đỏ lỗi [_doNghe] cho viền ô · nút dừng ■ · chấm đang ghi, khối hai chip ([khoiChonSoTien]) nằm TRONG thẻ.
/// Lệch giữ có chủ ý: dòng *"Đang ghi âm / chép lời"* và *"Đang kiểm"* hiện LẦN LƯỢT (Stitch vẽ cùng lúc) — hai việc
/// chạy nối tiếp. Tia sét giữ `AppColors.expense` theo màn C2 `8afdfe11…`.
class ONhapNhanh extends StatelessWidget {
  const ONhapNhanh({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.laPremium,
    required this.dangDocAi,
    required this.ketQua,
    required this.onDien,
    required this.onHuy,
    this.tamNgung = false,
    this.coMicro = false,
    this.trangThaiNghe = TrangThaiNghe.cho,
    this.giayGhi = 0,
    this.onMicro,
    this.onHuyNghe,
    this.khoiChonSoTien,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool laPremium;

  /// B1: ai_quick_input tạm ngừng — không nút Nâng cấp.
  final bool tamNgung;
  final bool dangDocAi;
  final KetQuaDien? ketQua;
  final VoidCallback onDien;
  final VoidCallback onHuy;

  /// C4 — micro (Task 14). Chỉ vẽ khi [coMicro] và [laPremium].
  final bool coMicro;
  final TrangThaiNghe trangThaiNghe;
  final int giayGhi;
  final VoidCallback? onMicro;
  final VoidCallback? onHuyNghe;

  /// Khối hai chip khi luật và Gemma đọc ra hai số khác nhau (C4 §3.4) — vẽ ở đáy thẻ.
  final Widget? khoiChonSoTien;

  /// Đỏ của trạng thái nghe — `error` của Stitch `d696e81e…`.
  static const _doNghe = AppColors.error;

  @override
  Widget build(BuildContext context) {
    final kq = ketQua;
    final dangThu = trangThaiNghe == TrangThaiNghe.dangNghe || trangThaiNghe == TrangThaiNghe.dangGhi;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `Wrap` chứ không `Row` + `Spacer`: chật (cỡ chữ lớn, 320 dp) thì chip xuống dòng thay vì tràn ra ngoài thẻ
          // (Realme 2026-10-26); đủ chỗ thì vẫn một hàng như Stitch `d696e81e…`.
          SizedBox(
            width: double.infinity,
            child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, size: 16, color: AppColors.expense),
                  SizedBox(width: 4),
                  Text(
                    'NHẬP NHANH',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (dangThu)
                const _NhanDangNghe()
              else if (laPremium && coMicro)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(4)),
                  child: const Text('Giọng nói & Gõ',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                ),
            ],
            ),
          ),
          const SizedBox(height: 8),
          // Nút Điền nằm TRONG khung ô, mép phải — màn Stitch `8afdfe11…` (C2 T5). Khung tự vẽ, nút đứng ngoài
          // `TextField`. ⚠️ Bản dựng bằng `suffixIcon` làm ca Huỷ của `nhap_nhanh_test` trượt tay (cú chạm rơi vào lúc
          // vùng cuộn không nhận chạm); hai phép đo tối giản (ô chưa / đã focus, chạm nút trong `suffixIcon`) không tái
          // hiện được nên chưa lần ra nguyên nhân — đừng đổi lại khi chưa đo trên máy thật.
          ListenableBuilder(
            listenable: focusNode,
            builder: (context, child) => Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: focusNode.hasFocus || dangThu
                    ? Border.all(color: dangThu ? _doNghe : AppColors.primary, width: 2)
                    : Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: child,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('nhap-nhanh-o'),
                    controller: controller,
                    focusNode: focusNode,
                    // Basic khoá cả ô — spec Premium 8.2.
                    enabled: laPremium,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onDien(),
                    style:
                        const TextStyle(fontSize: 15, color: AppColors.primary),
                    // ⚠️ Tắt CẢ nền và ba loại viền: theme của app đặt `filled` + `enabledBorder` / `focusedBorder` cho
                    // mọi ô nhập, `border: none` một mình không che được — máy thật hiện một ô trắng có viền nằm
                    // trong khung xám (nghiệm thu Realme 2026-09-30).
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      // G84: hai câu cũ bị cắt ở 320 dp ("VD: hôm qua ăn phở …" mất đúng phần số tiền + ví).
                      // Có micro (36 dp) thì ô hẹp lại: ở 300–320 dp "phở 45k tiền mặt" bị cắt (đo vòng sửa 1, Task 14);
                      // vẫn phải nêu ví (nguyên tắc G84) nên bỏ chữ "phở" chứ không bỏ ví (review toàn nhánh, I2).
                      // Đang nghe thì trạng thái nằm ở nhãn đầu thẻ (Stitch) — ô để trống chờ chữ chép lời.
                      hintText: dangThu
                          ? null
                          : (laPremium ? (coMicro ? '45k tiền mặt' : 'phở 45k tiền mặt') : (tamNgung ? kTheKhoaTamNgung : 'Chỉ Premium')),
                      hintStyle: const TextStyle(
                          fontSize: 14, color: AppColors.outlineVariant),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (laPremium && coMicro)
                  IconButton(
                    key: const Key('nhap-nhanh-micro'),
                    tooltip: dangThu ? 'Dừng' : 'Nói',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                    onPressed: trangThaiNghe == TrangThaiNghe.dangChep ? null : onMicro,
                    // Stitch: dừng = vòng 32 dp nền đỏ 10 % + ô vuông 14 dp đỏ, không phải icon.
                    icon: dangThu
                        ? Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration:
                                BoxDecoration(color: _doNghe.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: Container(
                              key: const Key('nhap-nhanh-dung'),
                              width: 14,
                              height: 14,
                              decoration:
                                  BoxDecoration(color: _doNghe, borderRadius: BorderRadius.circular(2)),
                            ),
                          )
                        : const Icon(Icons.mic_none, color: AppColors.primary),
                  ),
                const SizedBox(width: 6),
                // `minimumSize` hữu hạn: theme của app ép mọi ElevatedButton rộng vô hạn (bẫy 4.11).
                if (laPremium)
                  ElevatedButton(
                    key: const Key('nhap-nhanh-dien'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    // Đang nghe / ghi / chép thì khoá: Điền lúc ấy nuốt câu nói xong hoặc chồng phiên chữ lên lượt chép lời (Stitch 2).
                    onPressed: dangDocAi || trangThaiNghe != TrangThaiNghe.cho ? null : onDien,
                    child: const Text('Điền'),
                  )
                else if (!tamNgung)
                  const NutNangCap(),
              ],
            ),
          ),
          if (!laPremium)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                tamNgung
                    ? cauMoDauQuyen(MaQuyen.aiQuickInput, tamNgung: true)
                    : 'Nâng cấp để đọc câu bằng AI',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          if (dangDocAi)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Đang đọc bằng AI…',
                      key: Key('nhap-nhanh-dang-doc'),
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    key: const Key('nhap-nhanh-huy'),
                    onPressed: onHuy,
                    child: const Text('Huỷ'),
                  ),
                ],
              ),
            )
          else if (kq != null) ...[
            const SizedBox(height: 8),
            // Tóm tắt rỗng (số luật đã rút khỏi form sau kiểm chéo) mà còn nguồn / cảnh báo: không vẽ ✓ đứng một mình.
            if (kq.tomTat.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    kq.docDuoc ? Icons.check_circle : Icons.info_outline,
                    size: 16,
                    color:
                        kq.docDuoc ? AppColors.income : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      kq.tomTat,
                      key: const Key('nhap-nhanh-tom-tat'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kq.docDuoc
                            ? AppColors.income
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            Padding(
              padding: EdgeInsets.only(top: 4, left: kq.tomTat.isEmpty ? 0 : 22),
              child: Row(
                children: [
                  Icon(
                    kq.quaAi ? Icons.auto_awesome : Icons.rule,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    kq.quaAi ? 'Đọc bằng AI' : 'Đọc bằng luật',
                    key: const Key('nhap-nhanh-nguon'),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            for (final cb in kq.canhBao)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 22),
                child: Text(cb,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.expense)),
              ),
            if (kq.lyDo != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 22),
                child: Text(
                  kq.lyDo!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
          if (trangThaiNghe == TrangThaiNghe.dangGhi)
            DongDangNghe(
              key: const Key('nhap-nhanh-dang-ghi'),
              chamDo: true,
              chu: 'Đang ghi âm · $giayGhi giây — nói xong ngừng 2 giây',
              onHuy: onHuyNghe,
              khoaHuy: const Key('nhap-nhanh-huy-nghe'),
            )
          else if (trangThaiNghe == TrangThaiNghe.dangChep)
            DongDangNghe(
              key: const Key('nhap-nhanh-dang-chep'),
              chu: 'Đang chép lời bằng AI trên máy…',
              onHuy: onHuyNghe,
              khoaHuy: const Key('nhap-nhanh-huy-nghe'),
            ),
          if (khoiChonSoTien case final k?) ...[const SizedBox(height: 10), k],
        ],
      ),
    );
  }
}

/// Nhãn *"● Đang nghe…"* ở đầu thẻ — Stitch `d696e81e…` trạng thái 2: chữ 11 / 600 đỏ lỗi trên nền đỏ 10 %, viên tròn.
class _NhanDangNghe extends StatelessWidget {
  const _NhanDangNghe();

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('nhap-nhanh-dang-nghe'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration:
            BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            const Text('Đang nghe…',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error)),
          ],
        ),
      );
}
