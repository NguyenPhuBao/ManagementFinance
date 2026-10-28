import 'package:flowmoney/features/household/domain/quyen_nha.dart';
import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bảng vai × trạng thái × việc — đơn 50 mục 1 (server thi hành lại; client chỉ khoá nút).
void main() {
  bool lam(ViecNha v, VaiNha? vai, TrangThaiNha? tt) => duocLamViecNha(v, vai: vai, trangThai: tt);

  test('nhà hoạt động: chủ làm mọi việc quản lý trừ rời; thành viên ghi + rời; chỉ xem chỉ rời', () {
    const hd = TrangThaiNha.hoatDong;
    for (final v in [
      ViecNha.taoMa,
      ViecNha.huyMa,
      ViecNha.doiVai,
      ViecNha.moiRa,
      ViecNha.chuyenChu,
      ViecNha.giaiTan,
      ViecNha.ghiDuLieu
    ]) {
      expect(lam(v, VaiNha.chu, hd), isTrue, reason: v.name);
    }
    expect(lam(ViecNha.roiNha, VaiNha.chu, hd), isFalse, reason: 'chủ phải chuyển chủ hoặc giải tán trước');
    expect(lam(ViecNha.ghiDuLieu, VaiNha.thanhVien, hd), isTrue);
    expect(lam(ViecNha.roiNha, VaiNha.thanhVien, hd), isTrue);
    expect(lam(ViecNha.taoMa, VaiNha.thanhVien, hd), isFalse);
    expect(lam(ViecNha.ghiDuLieu, VaiNha.chiXem, hd), isFalse);
    expect(lam(ViecNha.roiNha, VaiNha.chiXem, hd), isTrue);
  });

  test('nhà chỉ xem (chủ hết Premium): không ai ghi, không tạo mã; quản lý / rời vẫn chạy', () {
    const cx = TrangThaiNha.chiXem;
    expect(lam(ViecNha.ghiDuLieu, VaiNha.chu, cx), isFalse);
    expect(lam(ViecNha.ghiDuLieu, VaiNha.thanhVien, cx), isFalse);
    expect(lam(ViecNha.taoMa, VaiNha.chu, cx), isFalse);
    expect(lam(ViecNha.doiVai, VaiNha.chu, cx), isTrue);
    expect(lam(ViecNha.moiRa, VaiNha.chu, cx), isTrue);
    expect(lam(ViecNha.chuyenChu, VaiNha.chu, cx), isTrue, reason: 'chuyển cho thành viên có Premium là lối thoát');
    expect(lam(ViecNha.roiNha, VaiNha.thanhVien, cx), isTrue);
  });

  test('nhà giải tán / chưa có nhà: không làm được gì', () {
    for (final v in ViecNha.values) {
      expect(lam(v, VaiNha.chu, TrangThaiNha.daGiaiTan), isFalse, reason: v.name);
      expect(lam(v, null, null), isFalse, reason: v.name);
    }
  });
}
