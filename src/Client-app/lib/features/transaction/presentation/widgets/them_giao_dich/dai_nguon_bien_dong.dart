/// Các khối riêng của form điền sẵn từ biến động số dư / ảnh quét — tách từ `_buildDaiNguon`, `_buildChonSoTien`,
/// `_buildGoiYChuyen`, `_buildNhacTrung`, `_xemKhoanTrung` ngày 2026-10-10 (spec bịt điểm rò mục 5.2). Trạng thái ở lại trang.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import '../../../../../core/utils/date_formatter.dart';

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/theme/app_colors.dart';
import '../../../domain/dien_san_bien_dong.dart';
import '../../../domain/goi_y_chuyen_khoan.dart';
import '../xem_anh_bien_lai.dart';

/// D1 — dải nguồn (Stitch `52d9d2ef…`): *"Từ thông báo MB Bank · TK ••7777 · 02/09 12:01"*.
class DaiNguonBienDong extends StatelessWidget {
  const DaiNguonBienDong(
      {super.key, required this.d, required this.duongDanAnh});

  final DienSanBienDong d;
  final String? duongDanAnh;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('bien-dong-dai-nguon'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Chia sẻ biên lai: hàng mang ảnh → ảnh nhỏ thay biểu tượng ngân hàng, chạm để xem to. Khung CỐ ĐỊNH
          // 48 × 64 (biên lai dọc) để dải không nhảy chiều cao khi ảnh giải mã xong.
          if (duongDanAnh case final p?)
            Semantics(
              button: true,
              label: 'Xem ảnh biên lai',
              child: GestureDetector(
                key: const Key('bien-lai-anh-nho'),
                onTap: () => xemAnhBienLai(context, p),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 64,
                    child: Image.file(
                      File(p),
                      fit: BoxFit.cover,
                      // Canh GIỮA: ảnh chia sẻ từ app ngân hàng là ảnh toàn màn, thẻ biên lai nằm giữa — canh đỉnh là
                      // ảnh nhỏ chỉ thấy nền (đo Realme 2026-10-02, biên lai MB Bank 1080 × 2400).
                      alignment: Alignment.center,
                      cacheWidth: 144,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppColors.surfaceContainerHigh,
                        child: Icon(Icons.receipt_long_outlined,
                            size: 20, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Icon(
                d.laQuet
                    ? Icons.document_scanner_outlined
                    : d.cachDoc == null
                        ? Icons.account_balance
                        : Icons.receipt_long_outlined,
                size: 18,
                color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dongNguonBienDong(d),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                if (dongPhuBienLai(d.cachDoc) case final phu?) ...[
                  const SizedBox(height: 4),
                  Text(
                    phu,
                    key: const Key('bien-lai-dong-phu'),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A5 mục 13 — ảnh quét mà số AI (Gemma nhìn ảnh) và số luật LỆCH > 1%: ô số tiền để trống, người dùng chạm một chip
/// để điền (hoặc gõ số khác). Chip đang khớp ô số tiền được tô chọn. Người dùng chốt 2026-10-08.
class KhoiChonSoTien extends StatelessWidget {
  const KhoiChonSoTien(
      {super.key,
      required this.ds,
      required this.dangChon,
      required this.onChon});

  final List<double> ds;
  final double dangChon;
  final ValueChanged<double> onChon;

  @override
  Widget build(BuildContext context) {
    final dang = dangChon;
    return Container(
      key: const Key('khoi-chon-so-tien'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            const Border(left: BorderSide(color: AppColors.warning, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đọc ra hai số khác nhau — chọn số đúng:',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < ds.length; i++)
                ChoiceChip(
                  key: Key('chon-so-tien-$i'),
                  label: Text(CurrencyFormatter.format(ds[i]),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  selected: (ds[i] - dang).abs() < 0.5,
                  onSelected: (_) => onChon(ds[i]),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Hoặc nhập số khác bằng bàn phím',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Thẻ gợi ý Chuyển khoản (spec 2026-09-30 §4, Stitch *"Thêm giao dịch - Gợi ý chuyển khoản từ biến động"*).
class TheGoiYChuyen extends StatelessWidget {
  const TheGoiYChuyen({super.key, required this.gy, required this.onApDung});

  final GoiYChuyenKhoan gy;
  final VoidCallback onApDung;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('the-goi-y-chuyen-khoan'),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      // Nút ở hàng RIÊNG, căn phải: cùng hàng với chữ thì ở 360 dp cả hai dòng chữ ngắt đôi (đo Realme 2026-09-30).
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    shape: BoxShape.circle),
                child: const Icon(Icons.swap_horiz,
                    size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Có vẻ là chuyển khoản',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Từ ${gy.nguonTu} sang ${gy.nguonDen}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          OutlinedButton(
            key: const Key('goi-y-chuyen-khoan'),
            onPressed: onApDung,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            child: const Text('Ghi là chuyển khoản',
                style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// D1 — *"Có thể bạn đã ghi khoản này"* (spec §3.3): chỉ NHẮC, không chặn lưu. **Xem** liệt kê các khoản khớp.
class NhacTrung extends StatelessWidget {
  const NhacTrung({super.key, required this.d, required this.trung});

  final DienSanBienDong d;
  final List<KhoanSo> trung;

  @override
  Widget build(BuildContext context) {
    final chieu = d.chieu == 'thu' ? 'thu' : 'chi';
    return Container(
      key: const Key('bien-dong-nhac-trung'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, size: 20, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Có thể bạn đã ghi khoản này',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${CurrencyFormatter.format(d.soTien!)} $chieu hôm '
                  '${DateFormatter.formatDayMonth(d.thoiGian!)} đã có trong sổ',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
              onPressed: () => moKhoanTrung(context, trung),
              child: const Text('Xem')),
        ],
      ),
    );
  }
}

Future<void> moKhoanTrung(BuildContext context, List<KhoanSo> trung) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Khoản đã có trong sổ',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              for (final k in trung)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(k.ghiChu.isEmpty ? '(không ghi chú)' : k.ghiChu),
                  subtitle: Text(DateFormatter.formatDateTime(k.ngay)),
                  trailing: Text(CurrencyFormatter.formatCoDau(k.soTien,
                      thu: k.loai == 'thu')),
                ),
            ],
          ),
        ),
      ),
    );
