import 'package:flowmoney/features/household/data/models/loi_moi.dart';
import 'package:flowmoney/features/household/domain/ma_moi.dart';
import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mã mời (đơn 50 C #3/#4): hình dạng cũ không có status → đang chờ, còn hiệu lực', () {
    final m = maMoiTuJson(const {'code': 'ABCD2345', 'role': 'Viewer', 'expiresAt': '2026-10-26T08:00:00.000Z'})!;
    expect((m.ma, m.vai, m.hetHan), ('ABCD2345', VaiNha.chiXem, DateTime.utc(2026, 10, 26, 8)));
    expect((m.email, m.taoLuc, m.trangThai, m.conHieuLuc), (null, null, TrangThaiLoiMoi.dangCho, true));
    expect(maMoiTuJson(const {'role': 'Member'}), isNull, reason: 'không mã thì không có gì để chia sẻ');
  });

  test('mã mời ở #4 hiện tại (04 mục 2): lời mời email mang email, createAt, status — chỉ Pending còn hiệu lực', () {
    final m = maMoiTuJson(const {
      'code': 'ABCD2345',
      'role': 'Member',
      'email': 'an@x.com',
      'createAt': '2026-10-25T08:00:00.000Z',
      'expiresAt': '2026-11-01T08:00:00.000Z',
      'status': 'Revoked',
    })!;
    expect(m.email, 'an@x.com');
    expect(m.taoLuc, DateTime.utc(2026, 10, 25, 8));
    expect(m.trangThai, TrangThaiLoiMoi.daHuy);
    expect(m.conHieuLuc, isFalse,
        reason:
            '#4 trả cả lời mời email đã huỷ / dùng / từ chối / hết hạn 7 ngày (đơn 57.8.5) — coi là còn hiệu lực thì danh '
            'sách mã có nút Huỷ trỏ vào mã chết');
    expect(maMoiTuJson(const {'code': 'X', 'status': 'Pending'})!.conHieuLuc, isTrue);
  });

  test('lời mời gửi tới tôi (#14 — 01 mục 2.4; server hiện KHÔNG trả memberCount / maxMembers, đơn 57.8.6)', () {
    final l = loiMoiToiTuJson(const {
      'code': 'ABCD2345',
      'householdName': 'Nhà An – Bình',
      'inviterName': 'Trần An',
      'role': 'Viewer',
      'expiresAt': '2026-11-02T08:00:00.000Z',
    })!;
    expect((l.ma, l.tenNha, l.tenNguoiMoi, l.vai), ('ABCD2345', 'Nhà An – Bình', 'Trần An', VaiNha.chiXem));
    expect(l.hetHan, DateTime.utc(2026, 11, 2, 8));
    expect((l.soThanhVien, l.toiDa), (null, null), reason: 'server im → chưa biết, không bịa 0 / 6');
    expect(loiMoiToiTuJson(const {'code': 'X', 'memberCount': 2, 'maxMembers': 6})!.toiDa, 6);
    expect(loiMoiToiTuJson(const {'householdName': 'x'}), isNull,
        reason: 'không mã thì không chấp nhận / từ chối được');
  });

  test('kết quả mời qua email (#13 — luôn cùng hình dạng dù email có tài khoản hay không)', () {
    final k = ketQuaMoiEmailTuJson(const {
      'sent': true,
      'email': 'an@x.com',
      'role': 'Member',
      'expiresAt': '2026-11-02T08:00:00.000Z',
    });
    expect((k.email, k.vai, k.hetHan), ('an@x.com', VaiNha.thanhVien, DateTime.utc(2026, 11, 2, 8)));
    expect(ketQuaMoiEmailTuJson(const {}).email, '', reason: 'không ném');
  });

  test('xem trước (đơn 50 C #6)', () {
    final x = xemTruocTuJson(const {
      'householdName': 'Nhà An – Bình',
      'ownerName': 'Trần An',
      'memberCount': 2,
      'maxMembers': 6,
      'role': 'Member',
      'expiresAt': '2026-10-26T08:00:00.000Z',
    });
    expect(
        (x.tenNha, x.tenChuNha, x.soThanhVien, x.toiDa, x.vai), ('Nhà An – Bình', 'Trần An', 2, 6, VaiNha.thanhVien));
    expect(x.hetHan, DateTime.utc(2026, 10, 26, 8));
  });

  test('xem trước thiếu trường → mặc định, không ném', () {
    final x = xemTruocTuJson(const {});
    expect((x.tenNha, x.soThanhVien, x.toiDa, x.vai), ('', 0, kToiDaThanhVienMacDinh, VaiNha.chiXem));
  });
}
