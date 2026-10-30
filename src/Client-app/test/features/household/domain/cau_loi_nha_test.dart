import 'dart:io';

import 'package:flowmoney/features/household/domain/cau_loi_nha.dart';
import 'package:flutter_test/flutter_test.dart';

/// Câu lỗi của mảng gia đình — MỘT chỗ (spec 7.1), không in mã / URL / số.
void main() {
  test('mỗi loại một câu, không câu nào trùng, không chữ số, không mã server', () {
    final cau = LoaiLoiNha.values.map(cauLoiNha).toList();
    expect(cau.toSet(), hasLength(cau.length),
        reason: 'hai lỗi khác nhau mà cùng một câu là người dùng không biết sửa gì');
    for (final c in cau) {
      expect(c.trim(), isNotEmpty);
      expect(RegExp(r'\d').hasMatch(c), isFalse, reason: c);
      expect(c.contains('HOUSEHOLD'), isFalse, reason: c);
    }
  });

  test('câu chốt của spec (5.3, 5.5)', () {
    expect(cauLoiNha(LoaiLoiNha.daONhaKhac), contains('Rời nhà hiện tại trước'));
    expect(cauLoiNha(LoaiLoiNha.chuPhaiChuyen), 'Chuyển quyền chủ nhà hoặc giải tán trước.');
  });

  test('mã API → loại: đọc CẢ tên tài liệu (đơn 50 C.3, 01 mục 2.5) lẫn mã thật (04 mục 2, đơn 57.7)', () {
    const bang = {
      // Tên tài liệu
      'HOUSEHOLD_INVITE_INVALID': LoaiLoiNha.maKhongCo,
      'HOUSEHOLD_INVITE_EXPIRED': LoaiLoiNha.maHetHan,
      'HOUSEHOLD_INVITE_USED': LoaiLoiNha.maDaDung,
      'HOUSEHOLD_ALREADY_IN_ONE': LoaiLoiNha.daONhaKhac,
      'HOUSEHOLD_FULL': LoaiLoiNha.nhaDu,
      'HOUSEHOLD_NOT_FOUND': LoaiLoiNha.khongONha,
      'HOUSEHOLD_NOT_OWNER': LoaiLoiNha.khongPhaiChu,
      'HOUSEHOLD_OWNER_MUST_TRANSFER': LoaiLoiNha.chuPhaiChuyen,
      'HOUSEHOLD_READ_ONLY': LoaiLoiNha.nhaChiXem,
      'HOUSEHOLD_CLOSED': LoaiLoiNha.nhaDaGiaiTan,
      'HOUSEHOLD_INVITE_WRONG_ACCOUNT': LoaiLoiNha.loiMoiKhongPhaiCuaBan,
      'HOUSEHOLD_INVITE_DECLINED': LoaiLoiNha.loiMoiDaTuChoi,
      'HOUSEHOLD_INVITE_RATE_LIMIT': LoaiLoiNha.guiMoiQuaNhieu,
      'FEATURE_DISABLED': LoaiLoiNha.tinhNangKhongMo,
      // Mã thật của backend 177dd0e1 (household.service.js / .controller.js) — tới khi đơn 57.7 chốt bảng mã
      'HOUSEHOLD_INVITE_NOT_FOUND': LoaiLoiNha.maKhongCo,
      'INVALID_INVITE_CODE': LoaiLoiNha.maKhongCo,
      'NOT_IN_HOUSEHOLD': LoaiLoiNha.khongONha,
      'FORBIDDEN_NOT_OWNER': LoaiLoiNha.khongPhaiChu,
      'OWNER_CANNOT_LEAVE': LoaiLoiNha.chuPhaiChuyen,
      'HOUSEHOLD_NOT_ACTIVE': LoaiLoiNha.nhaChiXem,
      'MEMBER_NOT_IN_HOUSEHOLD': LoaiLoiNha.thanhVienKhongONha,
      'TARGET_NOT_IN_HOUSEHOLD': LoaiLoiNha.thanhVienKhongONha,
      'INVALID_EMAIL': LoaiLoiNha.emailKhongHopLe,
      'PREMIUM_REQUIRED': LoaiLoiNha.canPremium,
    };
    bang.forEach((ma, loai) => expect(loaiLoiTuMa(ma), loai, reason: ma));
    expect(loaiLoiTuMa('WALLET_NAME_DUPLICATE'), isNull);
    expect(loaiLoiTuMa('CANNOT_REMOVE_SELF'), isNull,
        reason: 'form không cho chọn chính mình — tới đây là lỗi lập trình, rơi khac');
    expect(loaiLoiTuMa(null), isNull);
  });

  test('LoiNha mang loại; lỗi khác → khac', () {
    expect(loaiLoiNhaCua(const LoiNha(LoaiLoiNha.nhaDu)), LoaiLoiNha.nhaDu);
    expect(loaiLoiNhaCua(StateError('x')), LoaiLoiNha.khac);
  });

  test('lỗi cho thấy nhà đã đổi ở nơi khác → làm mới trạng thái', () {
    for (final l in [
      LoaiLoiNha.daONhaKhac,
      LoaiLoiNha.khongONha,
      LoaiLoiNha.khongPhaiChu,
      LoaiLoiNha.nhaChiXem,
      LoaiLoiNha.nhaDaGiaiTan,
      LoaiLoiNha.thanhVienKhongONha
    ]) {
      expect(loiChoThayNhaDaDoi(l), isTrue, reason: l.name);
    }
    for (final l in [
      LoaiLoiNha.maHetHan,
      LoaiLoiNha.matMang,
      LoaiLoiNha.loiMoiKhongPhaiCuaBan,
      LoaiLoiNha.guiMoiQuaNhieu
    ]) {
      expect(loiChoThayNhaDaDoi(l), isFalse, reason: l.name);
    }
  });

  test('⚠️ năm mã ĐẨY khớp tay với _permanentCodes của core/sync', () {
    final nguon = File('lib/core/sync/gui_lo_dong_bo.dart').readAsStringSync();
    expect(kMaDayLoiNha, hasLength(5));
    expect(kMaDayLoiNha, contains('HOUSEHOLD_ROLE_FORBIDDEN'),
        reason:
            '01 mục 3: mã này chỉ nổ khi vai vừa đổi ở máy khác — trạng thái nhà trên máy đã cũ (người dùng chốt 2026-10-28)');
    expect(kMaDayLoiNha, isNot(contains('HOUSEHOLD_WALLET_LIMIT')),
        reason: 'trần ví chung không nói gì về vai / trạng thái nhà');
    for (final ma in kMaDayLoiNha) {
      expect(nguon.contains("'$ma',"), isTrue,
          reason: '$ma thiếu ở _permanentCodes — hàng bị gửi lại mọi chu kỳ, im lặng (core không import mảng nên hai '
              'danh sách khớp tay)');
    }
    // Chiều ngược (Ruling Q1): mã `HOUSEHOLD_*` nào vĩnh viễn ở core mà không ở đây (trừ trần ví chung) thì mảng gia đình
    // không bao giờ làm mới khi gặp nó.
    final dau = nguon.indexOf('_permanentCodes = {');
    expect(dau, isNonNegative);
    final khoi = nguon.substring(dau, nguon.indexOf('};', dau));
    final maCore =
        RegExp(r"^\s*'(HOUSEHOLD_[A-Z_]+)',", multiLine: true).allMatches(khoi).map((m) => m.group(1)!).toSet();
    expect(maCore, hasLength(6), reason: 'tiền đề: đọc được sáu mã HOUSEHOLD_* ở _permanentCodes (không đọc rỗng)');
    expect(maCore.difference({'HOUSEHOLD_WALLET_LIMIT'}), kMaDayLoiNha,
        reason: 'mã gia đình vĩnh viễn ở core mà thiếu ở kMaDayLoiNha: trạng thái nhà trên máy cũ mà không ai làm mới');
    expect(nguon.contains('kMaDayLoiNha'), isTrue,
        reason:
            'chú thích ở _permanentCodes phải trỏ ngược về tập này — ai sửa một bên mới biết bên kia (Task 8 bước 3b)');
  });
}
