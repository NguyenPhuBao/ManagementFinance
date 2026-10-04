import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../transaction/domain/doc_tin_bien_dong.dart';

/// Khung chung của màn xin đồng ý trước khi dẫn người dùng tới một trang quyền của Android — D1 (*Truy cập thông
/// báo*, Stitch `bed4d292…`) và nhắc ghi sau khi dùng app ngân hàng (*Truy cập dữ liệu sử dụng*, 2026-10-03).
///
/// Màn **không tự làm gì**: `Navigator.pop` trả `true` = *Đồng ý*, `false` = *Không, cảm ơn*, `null` = Back — bật tính
/// năng và mở Cài đặt là việc của nơi gọi, để mọi đường "không đồng ý" (kể cả Back) đều không bật được gì.
class ManDongY extends StatelessWidget {
  const ManDongY({
    super.key,
    required this.tieuDeThanh,
    required this.icon,
    required this.tieuDe,
    required this.moTa,
    required this.tieuDeNguon,
    required this.nguon,
    required this.camKet,
  });

  final String tieuDeThanh;
  final IconData icon;
  final String tieuDe;
  final String moTa;
  final String tieuDeNguon;
  final List<String> nguon;
  final List<String> camKet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF9F7),
        elevation: 0,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          tieuDeThanh,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0EDE6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 40, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tieuDe,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                moTa,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF5F605C)),
              ),
              const SizedBox(height: 24),
              _TieuDeMuc(tieuDeNguon),
              _Khung(
                children: [
                  for (final n in nguon) ...[
                    if (n != nguon.first)
                      const Divider(height: 1, color: AppColors.outlineVariant),
                    _HangNguon(n),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              const _TieuDeMuc('CAM KẾT'),
              _Khung(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (final c in camKet) ...[
                          if (c != camKet.first) const SizedBox(height: 14),
                          _HangCamKet(c),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Đồng ý và mở Cài đặt',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF5F605C)),
                child: const Text(
                  'Không, cảm ơn',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TieuDeMuc extends StatelessWidget {
  const _TieuDeMuc(this.chu);
  final String chu;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(
          chu,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: AppColors.textSecondary,
          ),
        ),
      );
}

class _Khung extends StatelessWidget {
  const _Khung({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

/// Chữ tắt + màu thương hiệu mờ cho vòng tròn đầu dòng — đúng màn Stitch. Nguồn chưa có trong bảng
/// (thêm gói mới mà quên bảng này) rơi về chữ cái đầu trên nền trung tính, không ném.
const Map<String, (String, Color)> _kHuyHieu = {
  kNguonMb: ('MB', Color(0xFF1B3699)),
  kNguonVcb: ('VCB', Color(0xFF006037)),
  kNguonTcb: ('TCB', Color(0xFFE31837)),
  kNguonBidv: ('BIDV', Color(0xFF005F56)),
  kNguonMomo: ('MM', Color(0xFFA50064)),
  kNguonZalopay: ('ZP', Color(0xFF008FE5)),
};

class _HangNguon extends StatelessWidget {
  const _HangNguon(this.nguon);
  final String nguon;

  @override
  Widget build(BuildContext context) {
    final hh = _kHuyHieu[nguon];
    final mau = hh?.$2 ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: mau.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: nguon == kNguonSms
                ? Icon(Icons.sms_outlined, size: 18, color: mau)
                : Text(
                    hh?.$1 ?? nguon.characters.first,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: mau),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              nguon,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _HangCamKet extends StatelessWidget {
  const _HangCamKet(this.chu);
  final String chu;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 14, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              chu,
              style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF2C2D2A)),
            ),
          ),
        ],
      );
}
