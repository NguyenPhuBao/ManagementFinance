import 'package:flutter/material.dart';

import '../../../transaction/domain/doc_tin_bien_dong.dart';
import 'man_dong_y.dart';

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
/// ý" (kể cả Back) đều không bật được gì. Khung vẽ là [ManDongY], dùng chung với màn đồng ý của nhắc ghi
/// sau khi dùng app ngân hàng (2026-10-03).
///
/// Danh sách nguồn là [nguonDangDoc] — chỉ nguồn dịch vụ THẬT SỰ đọc (người dùng chốt 2026-09-30),
/// không phải bảy nguồn của [kNguonBienDong]; Stitch vẽ đủ bảy vì lúc gửi chưa đo gói nào.
class DongYBienDongPage extends StatelessWidget {
  const DongYBienDongPage({super.key});

  @override
  Widget build(BuildContext context) => ManDongY(
        tieuDeThanh: 'Đọc biến động số dư',
        icon: Icons.notifications_active_outlined,
        tieuDe: 'Ghi giao dịch từ thông báo ngân hàng',
        moTa: 'FlowMoney đọc thông báo biến động số dư đã hiện trên máy bạn để điền sẵn form '
            'Thêm giao dịch. Bạn xem lại rồi mới bấm Lưu — app không tự tạo giao dịch nào.',
        tieuDeNguon: 'CHỈ ĐỌC THÔNG BÁO CỦA ${nguonDangDoc.length} NGUỒN',
        nguon: nguonDangDoc,
        camKet: kCamKetBienDong,
      );
}
