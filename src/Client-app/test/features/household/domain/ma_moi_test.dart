import 'package:flowmoney/features/household/domain/ma_moi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bảng ký tự bỏ 0 O 1 I, đủ 32 ký tự', () {
    expect(kBangKyTuMaMoi.length, 32);
    for (final c in ['0', 'O', '1', 'I']) {
      expect(kBangKyTuMaMoi.contains(c), isFalse, reason: c);
    }
  });

  test('chuẩn hoá: in hoa, bỏ khoảng trắng và gạch nối', () {
    expect(chuanHoaMaMoi(' abcd-2345 '), 'ABCD2345');
    expect(chuanHoaMaMoi('ab cd\t23 45'), 'ABCD2345');
  });

  test('hợp lệ: đúng 8 ký tự trong bảng', () {
    expect(maMoiHopLe('ABCD2345'), isTrue);
    expect(maMoiHopLe('ABCD234'), isFalse, reason: 'thiếu một ký tự');
    expect(maMoiHopLe('ABCD23456'), isFalse);
    expect(maMoiHopLe('ABCD2340'), isFalse, reason: 'số 0 không bao giờ có trong mã');
    expect(maMoiHopLe('abcd2345'), isFalse, reason: 'chưa chuẩn hoá — nơi gọi chuẩn hoá trước');
  });

  test(
      'trạng thái lời mời của GET /households/invites (04 mục 2 #4): thiếu / Pending → đang chờ, lạ → không còn hiệu lực',
      () {
    expect(trangThaiLoiMoiTuServer(null), TrangThaiLoiMoi.dangCho, reason: 'mã thường hình dạng cũ không có `status`');
    expect(trangThaiLoiMoiTuServer('Pending'), TrangThaiLoiMoi.dangCho);
    expect(trangThaiLoiMoiTuServer('Declined'), TrangThaiLoiMoi.daTuChoi);
    expect(trangThaiLoiMoiTuServer('Revoked'), TrangThaiLoiMoi.daHuy);
    expect(trangThaiLoiMoiTuServer('Used'), TrangThaiLoiMoi.daDung);
    expect(trangThaiLoiMoiTuServer('Expired'), TrangThaiLoiMoi.hetHan);
    expect(trangThaiLoiMoiTuServer('Cancelled'), TrangThaiLoiMoi.hetHan,
        reason: 'trạng thái lạ đọc là CÒN HIỆU LỰC thì nút Huỷ trỏ vào một mã server đã bỏ — quyền ít nhất');
  });
}
