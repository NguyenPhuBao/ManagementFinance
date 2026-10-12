/// Thẻ *Nhập nhanh* của màn Thêm giao dịch (C2, spec §3) — tách từ `_buildNhapNhanh` ngày 2026-10-10 (spec bịt điểm rò
/// mục 5.2). Controller / focus / kết quả đọc do trang giữ; widget chỉ vẽ và báo `onDien` / `onHuy`.
library;

import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';
import '../../../../premium/presentation/widgets/nut_nang_cap.dart';
import '../../bloc/them_giao_dich_state.dart' show KetQuaDien;
import 'dong_dang_nghe.dart';

/// Thẻ *Nhập nhanh* (C2, spec §3): ô một dòng + nút **Điền**; dưới là dòng tóm tắt những ô đã điền, cảnh báo, và câu lý
/// do khi danh mục đến từ B1.
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
    this.dangKiemSoTien = false,
    this.onHuyKiem,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool laPremium;
  final bool dangDocAi;
  final KetQuaDien? ketQua;
  final VoidCallback onDien;
  final VoidCallback onHuy;
  final bool dangKiemSoTien;
  final VoidCallback? onHuyKiem;

  @override
  Widget build(BuildContext context) {
    final kq = ketQua;
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
          const Row(
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
                border: focusNode.hasFocus
                    ? Border.all(color: AppColors.primary, width: 2)
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
                      hintText: laPremium ? 'phở 45k tiền mặt' : 'Chỉ Premium',
                      hintStyle: const TextStyle(
                          fontSize: 14, color: AppColors.outlineVariant),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
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
                    onPressed: dangDocAi ? null : onDien,
                    child: const Text('Điền'),
                  )
                else
                  const NutNangCap(),
              ],
            ),
          ),
          if (!laPremium)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Nâng cấp để đọc câu bằng AI',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
              padding: const EdgeInsets.only(top: 4, left: 22),
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
          if (dangKiemSoTien)
            DongDangNghe(
              key: const Key('nhap-nhanh-dang-kiem'),
              chu: 'Đang kiểm số tiền bằng AI…',
              onHuy: onHuyKiem,
              khoaHuy: const Key('nhap-nhanh-huy-kiem'),
            ),
        ],
      ),
    );
  }
}
