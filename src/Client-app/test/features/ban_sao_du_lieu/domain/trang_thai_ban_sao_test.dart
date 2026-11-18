import 'package:flowmoney/features/ban_sao_du_lieu/domain/trang_thai_ban_sao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bốn chuỗi server → đúng trạng thái; lạ / null → loi (cho yêu cầu lại, server tự chặn 429)', () {
    expect(trangThaiTuChuoi('PROCESSING'), TrangThaiBanSao.dangTao);
    expect(trangThaiTuChuoi('READY'), TrangThaiBanSao.sanSang);
    expect(trangThaiTuChuoi('EXPIRED'), TrangThaiBanSao.hetHan);
    expect(trangThaiTuChuoi('FAILED'), TrangThaiBanSao.loi);
    expect(trangThaiTuChuoi('QUEUED'), TrangThaiBanSao.loi, reason: 'chuỗi lạ không được đọc thành "đang tạo" (khoá nút mãi)');
    expect(trangThaiTuChuoi(null), TrangThaiBanSao.loi);
  });

  test('chuChoYeuCauLai làm tròn LÊN theo phút', () {
    expect(chuChoYeuCauLai(const Duration(seconds: 18720)), '5 giờ 12 phút');
    expect(chuChoYeuCauLai(const Duration(seconds: 18721)), '5 giờ 13 phút');
    expect(chuChoYeuCauLai(const Duration(hours: 24)), '24 giờ');
    expect(chuChoYeuCauLai(const Duration(minutes: 12)), '12 phút');
    expect(chuChoYeuCauLai(const Duration(seconds: 59)), 'dưới 1 phút');
    expect(chuChoYeuCauLai(Duration.zero), 'dưới 1 phút');
  });
}
