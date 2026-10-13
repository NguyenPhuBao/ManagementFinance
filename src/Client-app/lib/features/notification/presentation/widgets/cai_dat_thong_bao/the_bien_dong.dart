/// Thẻ D1 *Tự động hoá giao dịch* của trang Cài đặt thông báo (`notification_settings_page.dart`): công tắc Biến động số dư, dòng quyền, hàng gợi ý pin và ba hằng chữ của hàng gợi ý, dời nguyên văn khỏi trang.
library;

import 'package:flutter/material.dart';

import '../../../../../core/notification/prefs/notification_prefs.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../../premium/domain/quyen_tinh_nang.dart';
import '../../../../premium/presentation/bloc/co_quyen.dart';
import '../../../../premium/presentation/widgets/the_khoa_quyen.dart';
import '../../../../transaction/domain/doc_tin_bien_dong.dart';
import '../../../domain/cau_chu_dong_y.dart';
import 'khung_cai_dat.dart';
import 'ten_nhom_thong_bao.dart';

/// Hàng gợi ý pin của thẻ D1 (Stitch `2ff589c7…`).
const String kTieuDeTreNen = 'Tin có thể đến trễ khi app chạy nền';

/// Tiêu đề hàng gợi ý pin của khối *Nhắc ghi sau khi dùng app ngân hàng* (cùng mô tả [kMoTaTreNen]).
const String kTieuDeTreNenNhac = 'Lời nhắc có thể đến trễ khi app chạy nền';
const String kMoTaTreNen =
    'Một số máy (Realme, OPPO, Xiaomi…) tạm dừng FlowMoney khi ở nền. '
    'Bật "Cho phép hoạt động dưới nền" trong mục pin của ứng dụng để nhận ngay.';

/// Dòng trạng thái một quyền hệ thống: *sự thật của máy* ([co]), chữ cho hai trạng thái, nút mở trang quyền.
class DongQuyen extends StatelessWidget {
  const DongQuyen({
    super.key,
    required this.co,
    required this.chuCo,
    required this.chuChua,
    required this.moCaiDat,
    this.khoaNut,
  });

  final bool co;
  final String chuCo;
  final String chuChua;
  final Future<void> Function() moCaiDat;
  final Key? khoaNut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: co
                  ? AppColors.secondaryContainer
                  : AppColors.warning.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              co ? Icons.check_circle : Icons.warning_rounded,
              size: 18,
              color: co ? AppColors.onSecondaryContainer : AppColors.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: co
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chuCo,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nguonDangDoc.join(', '),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  )
                : Text(
                    chuChua,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          if (co)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle,
                      size: 6, color: AppColors.onSecondaryContainer),
                  SizedBox(width: 4),
                  Text(
                    'Hoạt động',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            )
          else
            // `TextButton` chứ không `ElevatedButton`: theme của app ép mọi ElevatedButton rộng vô
            // hạn (bẫy 4.11 `ANALYTICS_FEATURE.md`) — trong `Row` là trắng cả trang.
            TextButton(
              key: khoaNut,
              onPressed: moCaiDat,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const StadiumBorder(),
              ),
              child: const Text('Mở Cài đặt',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// Hàng gợi ý pin (Stitch `2ff589c7…`): ColorOS / MIUI tạm dừng app ở nền nên tin tới trễ. Gợi ý nhẹ, không
/// phải cảnh báo — tin không mất, chỉ trễ tới khi người dùng bật màn hình / mở app. Câu chữ theo tên mục thật
/// trên Realme ("Cho phép hoạt động dưới nền"), khác bản Stitch một cụm.
class DongTreNen extends StatelessWidget {
  const DongTreNen({
    super.key,
    this.tieuDe = kTieuDeTreNen,
    required this.moCaiDatPin,
    required this.khoaMoCaiDatPin,
  });

  final String tieuDe;
  final Future<void> Function() moCaiDatPin;
  final Key khoaMoCaiDatPin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.battery_saver_outlined,
                size: 20, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tieuDe,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                const Text(kMoTaTreNen,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: khoaMoCaiDatPin,
            onPressed: moCaiDatPin,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const StadiumBorder(
                  side: BorderSide(color: AppColors.outlineVariant)),
            ),
            child: const Text('Mở cài đặt',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// D1 — thẻ *Tự động hoá giao dịch* (Stitch `d42ce712…`): công tắc *Biến động số dư* và, khi
/// bật, một dòng trạng thái quyền nói sự thật của máy. Công tắc giữ khoá
/// `khoaCongTacNhom(bienDong)` như mọi nhóm.
class TheBienDong extends StatelessWidget {
  const TheBienDong({
    super.key,
    required this.prefs,
    required this.coQuyenBienDong,
    required this.duocChayNen,
    required this.onDoiBienDong,
    required this.khoaCongTac,
    required this.dongQuyen,
    required this.dongTreNen,
    required this.khoiNhacSau,
  });

  final NotificationPrefs prefs;
  final bool coQuyenBienDong;
  final bool duocChayNen;
  final ValueChanged<bool> onDoiBienDong;
  final Key khoaCongTac;
  final Widget dongQuyen;
  final Widget dongTreNen;
  final Widget khoiNhacSau;

  @override
  Widget build(BuildContext context) {
    final bat = prefs.docBienDong;
    return TheCaiDat(
      tieuDe: 'TỰ ĐỘNG HOÁ GIAO DỊCH',
      nhanMoi: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 18,
                                color: AppColors.onSecondaryContainer),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                tenNhomThongBao(NotificationGroup.bienDong),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          moTaNhomThongBao(NotificationGroup.bienDong),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    key: khoaCongTac,
                    value: bat,
                    // Quyền `bank_notification_parser` (spec phân quyền 2026-10-08).
                    onChanged: context.coQuyen(MaQuyen.bankNotificationParser)
                        ? onDoiBienDong
                        : null,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF006E1C),
                  ),
                ],
              ),
              if (!context.coQuyen(MaQuyen.bankNotificationParser))
                DongKhoaCongTac(
                    ma: MaQuyen.bankNotificationParser, dangBat: bat)
              else if (bat) ...[
                const SizedBox(height: 14),
                dongQuyen,
                // Chỉ khi đang đọc thật (chưa có quyền thì chưa có tin nào để trễ) VÀ máy chưa cho chạy nền.
                if (coQuyenBienDong && !duocChayNen) ...[
                  const SizedBox(height: 10),
                  dongTreNen,
                ],
              ] else if (coQuyenBienDong) ...[
                const SizedBox(height: 10),
                const Text(
                  kNhacThuHoiQuyen,
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        const Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: AppColors.outlineVariant),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: khoiNhacSau,
        ),
      ],
    );
  }
}
