import 'package:flutter/material.dart';

import '../../../transaction/domain/doc_tin_bien_dong.dart';
import 'man_dong_y.dart';

/// Tên tính năng — trên thanh tiêu đề màn đồng ý và khối ở Cài đặt thông báo.
const String kTenNhacSauNganHang = 'Nhắc ghi sau khi dùng app ngân hàng';

/// Bốn cam kết của màn đồng ý (spec 2026-10-03 §3.1).
const List<String> kCamKetNhacSauNganHang = [
  'Chỉ xem giờ mở và giờ rời các app trên — không xem màn hình hay nội dung app',
  'Chỉ lưu trên máy này',
  'Nhắc im lặng, bạn ghi hay bỏ qua — app không tự tạo giao dịch',
  'Không gửi ra ngoài, không liên kết tài khoản ngân hàng',
];

/// Dòng nhắc ở Cài đặt khi TẮT tính năng mà quyền hệ thống vẫn còn — app không tự thu hồi được.
const String kNhacThuHoiQuyenSuDung =
    'Muốn thu hồi hẳn quyền thì tắt FlowMoney trong Cài đặt hệ thống → Truy cập dữ liệu sử dụng.';

/// Màn đồng ý trước khi dẫn người dùng tới *Truy cập dữ liệu sử dụng* (spec 2026-10-03 §3.1; Stitch: màn đồng ý mới
/// người dùng xác nhận 2026-10-03 — xem Nhật ký thi công Task 4 của kế hoạch). Danh sách app là [nguonDangDoc] — một
/// danh sách với D1.
class DongYNhacSauNganHangPage extends StatelessWidget {
  const DongYNhacSauNganHangPage({super.key});

  @override
  Widget build(BuildContext context) => ManDongY(
        tieuDeThanh: kTenNhacSauNganHang,
        icon: Icons.notifications_paused_outlined,
        tieuDe: 'Nhắc ghi những lần bạn quên',
        moTa: 'Khi bạn dùng app ngân hàng mà chưa thấy giao dịch nào được ghi, FlowMoney nhắc bạn ghi lại. '
            'Bạn xem lại rồi mới bấm Lưu — app không tự tạo giao dịch nào.',
        tieuDeNguon: 'CHỈ XEM GIỜ MỞ CỦA ${nguonDangDoc.length} APP',
        nguon: nguonDangDoc,
        camKet: kCamKetNhacSauNganHang,
      );
}
