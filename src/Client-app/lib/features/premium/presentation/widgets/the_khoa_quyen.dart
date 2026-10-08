import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/quyen_tinh_nang.dart';
import '../co_quyen.dart';
import 'nut_nang_cap.dart';

/// Ba dạng khoá theo quyền (spec phân quyền 2026-10-08 mục 4.3 (2); chốt *"hiện khoá + Nâng cấp"*). Màn Stitch:
/// `595529bf…` *"Thống kê - Khối bị khoá theo gói (Basic)"* (thẻ khoá + dòng khoá) và `68593384…` *"Thêm hóa đơn - Tự
/// trả bị khoá (Basic)"* (băng khoá công tắc) — người dùng xác nhận 2026-10-08.
///
/// Chữ KHÔNG cắt `…` (luật G74–G78): tên tính năng dài nhất phải xuống dòng thay vì mất chữ.

/// Nút chạm → `/premium?quyen=…`. [onMo] là khe tiêm cho test.
void _moNangCap(BuildContext context, MaQuyen ma, VoidCallback? onMo) =>
    onMo != null ? onMo() : context.push(duongNangCap(quyen: ma));

/// Thẻ thay chỗ một khối trong trang khi không có quyền: ổ khoá tròn xám, tên tính năng, *"Dành cho Premium"*, nút đen.
class TheKhoaQuyen extends StatelessWidget {
  const TheKhoaQuyen({super.key, required this.ma, this.onMo});

  final MaQuyen ma;
  final VoidCallback? onMo;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('the-khoa-${ma.maServer}'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFF4F4F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF767872)),
          ),
          const SizedBox(height: 8),
          Text(
            ma.ten,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          const Text(
            'Dành cho Premium',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF767872)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: FilledButton(
              key: const Key('nut-nang-cap'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onPressed: () => _moNangCap(context, ma, onMo),
              child: const Text('Nâng cấp'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Có quyền → [child]; không → [TheKhoaQuyen]. Không có `GoiCubit` → [child] (quy ước Premium).
class KhoaTheoQuyen extends StatelessWidget {
  const KhoaTheoQuyen({super.key, required this.ma, required this.child, this.onMo});

  final MaQuyen ma;
  final Widget child;
  final VoidCallback? onMo;

  @override
  Widget build(BuildContext context) =>
      context.coQuyen(ma) ? child : TheKhoaQuyen(ma: ma, onMo: onMo);
}

/// Một dòng khoá nằm TRONG một khối (vd. câu chi bất thường ở khối Nhận xét): ổ khoá vàng, [cau], nút viên vàng.
class DongKhoaQuyen extends StatelessWidget {
  const DongKhoaQuyen({super.key, required this.ma, required this.cau, this.onMo});

  final MaQuyen ma;
  final String cau;
  final VoidCallback? onMo;

  static const _vang = Color(0xFFD97706);
  static const _nenVang = Color(0xFFFEF3C7);

  @override
  Widget build(BuildContext context) {
    return Row(
      key: Key('dong-khoa-${ma.maServer}'),
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(color: _nenVang, shape: BoxShape.circle),
          child: const Icon(Icons.lock_outline, size: 15, color: _vang),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(cau,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
        const SizedBox(width: 8),
        TextButton(
          key: const Key('nut-nang-cap'),
          style: TextButton.styleFrom(
            backgroundColor: _nenVang,
            foregroundColor: _vang,
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          onPressed: () => _moNangCap(context, ma, onMo),
          child: const Text('Nâng cấp'),
        ),
      ],
    );
  }
}

/// Băng dưới một công tắc bị khoá. [dangBat] — giá trị đang lưu là BẬT (vd. đã bật tự trả khi còn Premium) → băng
/// hồng *"Tạm dừng — cần Premium"* (chốt *"dừng chạy, giữ công tắc"*); không → băng vàng *"Cần Premium"*.
class DongKhoaCongTac extends StatelessWidget {
  const DongKhoaCongTac({super.key, required this.ma, required this.dangBat, this.onMo});

  final MaQuyen ma;
  final bool dangBat;
  final VoidCallback? onMo;

  @override
  Widget build(BuildContext context) {
    final nen = dangBat ? const Color(0xFFFFF4F2) : const Color(0xFFFAF8EE);
    final vien = dangBat ? const Color(0xFFFAD7D4) : const Color(0xFFECE5CD);
    final mau = dangBat ? AppColors.error : const Color(0xFF523F0C);
    return Container(
      key: Key('dong-khoa-cong-tac-${ma.maServer}'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: nen,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: vien),
      ),
      child: Row(
        children: [
          Icon(dangBat ? Icons.lock_clock_outlined : Icons.lock_outline,
              size: 18, color: dangBat ? AppColors.error : const Color(0xFF8C6D1F)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dangBat ? 'Tạm dừng — cần Premium' : 'Cần Premium',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: mau),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: const Key('nut-nang-cap'),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: Color(0xFFD5D3CA)),
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onPressed: () => _moNangCap(context, ma, onMo),
            child: const Text('Nâng cấp'),
          ),
        ],
      ),
    );
  }
}
