import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../transaction/domain/doc_tin_bien_dong.dart';

/// Bốn cam kết của màn xin đồng ý — spec D1 §3.4, đơn backend
/// `DA-XONG/CLIENT_DOC_BIEN_DONG_SO_DU_TREN_MAY.md` câu 4 (Nghị định 13: mục đích, danh sách trắng,
/// lọc OTP, lưu cục bộ, không gửi ra ngoài).
const List<String> kCamKetBienDong = [
  'Bỏ tin OTP / mã xác thực trước khi lưu',
  'Chỉ lưu trên máy này',
  'Xoá khi bạn đã ghi hoặc bỏ qua, tối đa 30 ngày',
  'Không gửi ra ngoài, không liên kết tài khoản ngân hàng',
];

/// Dòng nhắc ở trang Cài đặt thông báo khi người dùng TẮT tính năng mà quyền hệ thống vẫn còn:
/// tắt trong app chỉ dừng đọc, còn quyền *Truy cập thông báo* thì app không tự thu hồi được.
const String kNhacThuHoiQuyen =
    'Muốn thu hồi hẳn quyền thì tắt FlowMoney trong Cài đặt hệ thống → Truy cập thông báo.';

/// D1 Task 6 — màn giải thích + xin đồng ý trước khi dẫn người dùng tới Cài đặt *Truy cập thông
/// báo* của Android. **Backend bắt buộc** (Nghị định 13/2023) — không được bỏ hay rút gọn.
/// Màn Stitch `bed4d292bff6449cb2847af7eb95faf1`.
///
/// Trả qua `Navigator.pop`: `true` = *Đồng ý*, `false` = *Không, cảm ơn*, `null` = bấm Back. Màn
/// **không tự làm gì** — bật dịch vụ và mở Cài đặt là việc của nơi gọi, để mọi đường "không đồng
/// ý" (kể cả Back) đều không bật được gì.
///
/// Danh sách nguồn là [nguonDangDoc] — chỉ nguồn dịch vụ THẬT SỰ đọc (người dùng chốt 2026-09-30),
/// không phải bảy nguồn của [kNguonBienDong]; Stitch vẽ đủ bảy vì lúc gửi chưa đo gói nào.
class DongYBienDongPage extends StatelessWidget {
  const DongYBienDongPage({super.key});

  @override
  Widget build(BuildContext context) {
    final nguon = nguonDangDoc;
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
        title: const Text(
          'Đọc biến động số dư',
          style: TextStyle(
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
                  child: const Icon(Icons.notifications_active_outlined,
                      size: 40, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ghi giao dịch từ thông báo ngân hàng',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'FlowMoney đọc thông báo biến động số dư đã hiện trên máy bạn để điền sẵn form '
                'Thêm giao dịch. Bạn xem lại rồi mới bấm Lưu — app không tự tạo giao dịch nào.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF5F605C)),
              ),
              const SizedBox(height: 24),
              _TieuDeMuc('CHỈ ĐỌC THÔNG BÁO CỦA ${nguon.length} NGUỒN'),
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
                        for (final c in kCamKetBienDong) ...[
                          if (c != kCamKetBienDong.first) const SizedBox(height: 14),
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
