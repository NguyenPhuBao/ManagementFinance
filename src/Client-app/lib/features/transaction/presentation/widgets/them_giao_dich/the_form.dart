/// Thẻ form của màn Thêm giao dịch — tách từ `_buildFormCard` / `_buildFormRow` / `_buildDebtDirectionRow` /
/// `_directionChip` ngày 2026-10-10 (spec bịt điểm rò mục 5.2). Các khối phụ (nhắc trùng, đề xuất từ khoá, chiều tiền,
/// thẻ gợi ý) đi vào qua slot; trang giữ trạng thái và quyết định khi nào dựng chúng.
library;

import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_colors.dart';

class HangForm extends StatelessWidget {
  const HangForm({
    super.key,
    required this.icon,
    required this.label,
    required this.valueWidget,
    this.showArrow = false,
    this.trailingIcon,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget valueWidget;
  final bool showArrow;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.textSecondary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  valueWidget,
                ],
              ),
            ),
            if (trailingIcon != null)
              Icon(trailingIcon, color: AppColors.outline)
            else if (showArrow)
              const Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}

/// Công tắc chiều tiền — chỉ hiện khi danh mục là vay/nợ, vì đó là phân loại
/// duy nhất gom cả tiền vào lẫn tiền ra (Cho vay/Trả nợ ↔ Đi vay/Thu nợ).
class HangChieuTien extends StatelessWidget {
  const HangChieuTien({super.key, required this.chieu, required this.onChon});

  final String? chieu;
  final ValueChanged<String> onChon;

  @override
  Widget build(BuildContext context) {
    return HangForm(
      icon: Icons.swap_vert,
      label: 'Chiều tiền',
      valueWidget: Wrap(
        spacing: 8,
        children: [
          _chip('chi', 'Tiền ra'),
          _chip('thu', 'Tiền vào'),
        ],
      ),
    );
  }

  Widget _chip(String direction, String label) {
    final selected = chieu == direction;
    return ChoiceChip(
      key: Key('debt-direction-$direction'),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.outlineVariant),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppColors.primary,
      ),
      // Cùng giá trị với đoạn đầu màn — xem chú thích ở `_huong` của trang.
      onSelected: (_) => onChon(direction),
    );
  }
}

class TheForm extends StatelessWidget {
  const TheForm({
    super.key,
    required this.isTransfer,
    required this.walletDisplay,
    required this.destWalletDisplay,
    required this.tenDanhMuc,
    required this.nhanDanhMuc,
    required this.noteController,
    required this.ngayHienThi,
    required this.onChonVi,
    required this.onChonViDich,
    required this.onChonDanhMuc,
    required this.onPickDate,
    this.hienDongTach = false,
    this.onThemPhan,
    this.nhacTrung,
    this.deXuatTuKhoa,
    this.hangChieuTien,
    this.theGoiY,
  });

  final bool isTransfer;
  final String walletDisplay;
  final String destWalletDisplay;
  final String? tenDanhMuc;
  final String nhanDanhMuc;
  final TextEditingController noteController;
  final String ngayHienThi;
  final VoidCallback onChonVi;
  final VoidCallback onChonViDich;
  final VoidCallback onChonDanhMuc;
  final VoidCallback onPickDate;
  final bool hienDongTach;
  final VoidCallback? onThemPhan;
  final Widget? nhacTrung;
  final Widget? deXuatTuKhoa;
  final Widget? hangChieuTien;
  final Widget? theGoiY;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        children: [
          if (!isTransfer) ...[
            HangForm(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Ví thanh toán',
              valueWidget: Text(
                walletDisplay,
                style: const TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
              showArrow: true,
              onTap: onChonVi,
            ),
            if (nhacTrung != null) nhacTrung!,
            Divider(height: 1, indent: 64, color: AppColors.outlineVariant.withValues(alpha: 0.3)),
            HangForm(
              icon: Icons.category,
              label: nhanDanhMuc,
              valueWidget: Text(
                tenDanhMuc ?? 'Chọn danh mục',
                style: TextStyle(
                  fontSize: 16,
                  color: tenDanhMuc != null ? AppColors.primary : AppColors.outlineVariant,
                  fontWeight: tenDanhMuc != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              showArrow: true,
              onTap: onChonDanhMuc,
            ),
            if (hienDongTach) ...[
              Divider(height: 1, indent: 64, color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              KeyedSubtree(
                key: const Key('dong-tach'),
                child: HangForm(
                  icon: Icons.call_split,
                  label: 'Tách theo danh mục',
                  valueWidget: const Text(
                    'Chia khoản chi cho nhiều danh mục',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  showArrow: true,
                  onTap: onThemPhan,
                ),
              ),
            ],
            if (deXuatTuKhoa != null) deXuatTuKhoa!,
            if (hangChieuTien != null) ...[
              Divider(height: 1, indent: 64, color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              hangChieuTien!,
            ],
            if (theGoiY != null) ...[
              Divider(height: 1, indent: 64, color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              theGoiY!,
            ],
          ] else ...[
            HangForm(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Ví nguồn (Từ ví)',
              valueWidget: Text(
                walletDisplay,
                style: const TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
              showArrow: true,
              onTap: onChonVi,
            ),
            Divider(height: 1, indent: 64, color: AppColors.outlineVariant.withValues(alpha: 0.3)),
            HangForm(
              icon: Icons.account_balance_wallet,
              label: 'Ví đích (Đến ví)',
              valueWidget: Text(
                destWalletDisplay,
                style: const TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
              showArrow: true,
              onTap: onChonViDich,
            ),
          ],
          Divider(height: 1, indent: 64, color: AppColors.outlineVariant.withValues(alpha: 0.3)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notes, color: AppColors.textSecondary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    key: const Key('ghi-chu-giao-dich'),
                    controller: noteController,
                    // G84: hàng phẳng như Danh mục / Ngày (Stitch `8afdfe11…`) — tắt nền và ba loại viền
                    // của theme, như ô Nhập nhanh; `border: none` một mình không che được.
                    decoration: const InputDecoration(
                      filled: false,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      // Theme đệm ngang 16 — bỏ để chữ thẳng cột với "Chọn danh mục" / "Ngày".
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                      // G83: câu dài cũ bị cắt ở 320 dp — người dùng chọn rút gọn.
                      hintText: 'Thêm ghi chú…',
                      hintStyle: TextStyle(fontSize: 14, color: AppColors.outlineVariant),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 16, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, indent: 64, color: AppColors.outlineVariant.withValues(alpha: 0.3)),
          HangForm(
            icon: Icons.calendar_today,
            label: 'Ngày',
            valueWidget: Text(
              // D1: giờ trong tin là giờ giao dịch — hiện ra để người dùng thấy nó được giữ.
              ngayHienThi,
              style: const TextStyle(fontSize: 16, color: AppColors.primary),
            ),
            trailingIcon: Icons.calendar_month,
            onTap: onPickDate,
          ),
        ],
      ),
    );
  }
}
