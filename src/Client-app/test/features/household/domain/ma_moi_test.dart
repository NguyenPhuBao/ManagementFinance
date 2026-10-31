import 'package:flowmoney/features/household/domain/ma_moi.dart';
import 'package:flowmoney/features/household/domain/moi_thanh_vien.dart';
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

  test('maMoiConHan: không có hạn là còn; đúng mốc là hết', () {
    final now = DateTime.utc(2026, 11, 1);
    expect(maMoiConHan(null, now), isTrue);
    expect(maMoiConHan(now.add(const Duration(seconds: 1)), now), isTrue);
    expect(maMoiConHan(now, now), isFalse);
  });

  test('nhanTrangThaiLoiMoi: mỗi trạng thái một nhãn', () {
    final nhan = TrangThaiLoiMoi.values.map(nhanTrangThaiLoiMoi).toList();
    expect(nhan.toSet(), hasLength(nhan.length));
    expect(nhanTrangThaiLoiMoi(TrangThaiLoiMoi.dangCho), 'Đang chờ');
    expect(nhanTrangThaiLoiMoi(TrangThaiLoiMoi.daTuChoi), 'Đã từ chối');
    expect(nhanTrangThaiLoiMoi(TrangThaiLoiMoi.hetHan), 'Hết hạn');
  });

  group('trichMaMoi', () {
    test('tin chia sẻ của chính app: lấy đúng mã sau "Mã mời:"', () {
      final tin = cauChiaSeMaMoi(tenNha: 'Nhà An – Bình', ma: 'ABCD2345', hetHan: DateTime.utc(2026, 11, 2, 8));
      expect(trichMaMoi(tin), 'ABCD2345');
    });

    test('tên nhà có từ 8 ký tự hợp lệ không thắng mã sau "Mã mời:"', () {
      final tin = cauChiaSeMaMoi(tenNha: 'NGUYENXX', ma: 'ZZYY2345');
      expect(trichMaMoi(tin), 'ZZYY2345');
    });

    test('tên nhà chứa nguyên "Mã mời: AAAA2222": lấy nhãn CUỐI, mã thật', () {
      final tin = cauChiaSeMaMoi(tenNha: 'Mã mời: AAAA2222', ma: 'ZZYY2345');
      expect(trichMaMoi(tin), 'ZZYY2345');
    });

    test('không tìm thấy cụm đứng riêng: giữ luật cũ', () {
      expect(trichMaMoi('ab cd 23 45 67'), 'ABCD234567');
      expect(trichMaMoi('abcd-2345'), 'ABCD2345');
      expect(trichMaMoi('abcd2345'), 'ABCD2345');
    });

    test('cụm 9 ký tự liền không bị cắt lấy 8', () {
      expect(trichMaMoi('xin chao ABCD23456 nhe'), isNot('ABCD2345'));
    });
  });
}
