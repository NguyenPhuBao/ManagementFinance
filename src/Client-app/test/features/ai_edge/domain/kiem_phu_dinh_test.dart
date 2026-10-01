/// Bộ kiểm PHỦ ĐỊNH — lớp chắn thứ năm (bẫy 4.52, OnePlus 2026-09-28, câu L5 của
/// mục 9.33 `AI_EDGE_FEATURE.md`): tool `danh_sach_vi` vừa trả BỐN hàng, mô hình
/// viết *"Không có dữ liệu về ví nào được cung cấp."* — câu không số, không tên,
/// nên bốn lớp chắn trước đều im, và người dùng đọc một câu SAI.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_cau_tra_loi.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_phu_dinh.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flutter_test/flutter_test.dart';

class _GoiBac1 extends GoiSo {
  @override
  String get man => 'vi';
  @override
  List<SoLieu> get soLieu => [soTien('Số dư', 500000, ten: 'Tiền mặt')];
  @override
  bool get thieuDuLieu => false;
  @override
  NhanXet mauCau() =>
      NhanXet(cau: '', theSoLieu: soLieu, muc: MucNhanXet.binhThuong);
}

KetQuaCongCu _vi() => KetQuaCongCu(
      hang: [
        HangSoLieu(
          ten: 'Tiền mặt',
          trangThai: 'đang hoạt động',
          canhBao: false,
          soLieu: [soTien('Số dư', 500000, ten: 'Tiền mặt')],
        ),
      ],
      tongHop: [soDem('Số ví', 1)],
    );

void main() {
  final coHang = GoiSoTraCuu()..them('danh_sach_vi', _vi());
  final khongHang = GoiSoTraCuu()
    ..them('danh_sach_vi', const KetQuaCongCu(hang: [], tongHop: []));

  test('⭐ L5: tool trả hàng mà câu không số nói "không có dữ liệu" → CHẶN', () {
    expect(kiemPhuDinh('Không có dữ liệu về ví nào được cung cấp.', [coHang]), isFalse);
    expect(kiemCauTraLoi('Không có dữ liệu về ví nào được cung cấp.', [coHang]), isFalse,
        reason: 'lớp chắn phải được NỐI vào kiemCauTraLoi, không chỉ tồn tại');
  });

  test('các cách nói khác của cùng một lời phủ định', () {
    for (final cau in [
      'Tôi không có thông tin về ví của bạn.',
      'Hiện chưa có dữ liệu nào.',
      'Không tìm thấy dữ liệu phù hợp.',
      'Không có số liệu để trả lời.',
      'KHÔNG CÓ DỮ LIỆU.',
    ]) {
      expect(kiemPhuDinh(cau, [coHang]), isFalse, reason: cau);
    }
  });

  test('tool trả 0 hàng → câu phủ định là câu THẬT, qua', () {
    expect(kiemPhuDinh('Không có dữ liệu về ví nào.', [khongHang]), isTrue);
  });

  test('⚠️ phủ định về MỘT trạng thái không phải phủ định dữ liệu: "không có hoá đơn nào quá hạn" qua', () {
    expect(kiemPhuDinh('Không có ví nào đang âm.', [coHang]), isTrue);
    expect(kiemPhuDinh('Bạn không có hoá đơn nào quá hạn.', [coHang]), isTrue);
  });

  test('câu CÓ SỐ thì không xét: "không có dữ liệu tháng trước, tháng này … 500.000 đ"', () {
    expect(
      kiemPhuDinh('Không có dữ liệu tháng trước, Tiền mặt còn 500.000 đ.', [coHang]),
      isTrue,
      reason: 'nền so sánh bằng 0 là câu thật; số đã có bốn lớp kia kiểm',
    );
  });

  test('gói bậc 1 (không phải gói tra cứu) không bị xét — cổng A điểm 4 giữ nguyên', () {
    expect(kiemPhuDinh('Không có dữ liệu về dự báo tiết kiệm.', [_GoiBac1()]), isTrue);
  });

  test('câu thường, không phủ định → qua', () {
    expect(kiemPhuDinh('Ví Tiền mặt đang hoạt động.', [coHang]), isTrue);
  });
}
