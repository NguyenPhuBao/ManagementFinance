/// `system.broadcast` — hàm DUY NHẤT đọc payload của sự kiện này (spec 2026-10-26 mục 3.2).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/realtime/tin_he_thong.dart';

Map<String, Object?> _tin({
  Object? id = '8f1c2d3e-0000-4000-8000-000000000001',
  Object? title = 'Bảo trì nâng cấp tối nay',
  Object? message = 'FlowMoney nâng cấp máy chủ từ 23:00 đến 23:30.',
  Object? level = 'info',
  Object? metadata = const <String, Object?>{},
}) =>
    {
      'id': id,
      'title': title,
      'message': message,
      'level': level,
      'category': 'BROADCAST',
      'metadata': metadata,
      'isRead': false,
      'createdAt': '2026-10-26T08:00:00.000Z',
    };

void main() {
  test('tin admin gõ tay → đủ bốn trường', () {
    final t = docTinHeThong(_tin())!;
    expect(t.id, '8f1c2d3e-0000-4000-8000-000000000001');
    expect(t.tieuDe, 'Bảo trì nâng cấp tối nay');
    expect(t.noiDung, 'FlowMoney nâng cấp máy chủ từ 23:00 đến 23:30.');
    expect(t.mucDo, MucDoTinHeThong.info);
  });

  test('tin bảo trì tự động (metadata.type) → null', () {
    for (final loai in [
      'EMERGENCY_MAINTENANCE',
      'SYSTEM_UPGRADE',
      'SCHEDULED_MAINTENANCE',
      'UPGRADE_COMPLETED',
      'MAINTENANCE_RESTORED',
    ]) {
      expect(docTinHeThong(_tin(metadata: {'type': loai, 'isEmergency': true})), isNull,
          reason: '$loai — người dùng chốt chỉ hiện tin admin gõ tay; bảo trì đã có dòng nhắc G89');
    }
  });

  test('metadata.type rỗng / không phải chuỗi / metadata không phải Map → vẫn là tin admin', () {
    expect(docTinHeThong(_tin(metadata: {'type': ''})), isNotNull);
    expect(docTinHeThong(_tin(metadata: {'type': 3})), isNotNull);
    expect(docTinHeThong(_tin(metadata: null)), isNotNull);
    expect(docTinHeThong(_tin(metadata: 'x')), isNotNull);
  });

  test('payload không phải Map → null', () {
    for (final p in [null, 'hỏng', 3, const ['a']]) {
      expect(docTinHeThong(p), isNull, reason: '$p');
    }
  });

  test('thiếu id / id rỗng / id không phải chuỗi → null (id là khoá chống trùng)', () {
    for (final id in [null, '', '   ', 42]) {
      expect(docTinHeThong(_tin(id: id)), isNull, reason: 'id: $id');
    }
  });

  test('tiêu đề và nội dung cùng rỗng → null', () {
    expect(docTinHeThong(_tin(title: '  ', message: '')), isNull);
    expect(docTinHeThong(_tin(title: null, message: null)), isNull);
  });

  test('tiêu đề rỗng, nội dung có → tiêu đề mặc định', () {
    expect(docTinHeThong(_tin(title: ' '))!.tieuDe, kTieuDeTinHeThongMacDinh);
    expect(kTieuDeTinHeThongMacDinh, 'Tin từ FlowMoney');
  });

  test('nội dung rỗng, tiêu đề có → giữ tin, nội dung rỗng', () {
    expect(docTinHeThong(_tin(message: null))!.noiDung, '');
  });

  test('trim hai đầu', () {
    final t = docTinHeThong(_tin(title: '  A  ', message: '\n B \n'))!;
    expect(t.tieuDe, 'A');
    expect(t.noiDung, 'B');
  });

  test('cắt tiêu đề 120 / nội dung 1000 code point, không cắt đôi emoji', () {
    final t = docTinHeThong(_tin(title: 'a' * 300, message: '😀' * 1500))!;
    expect(t.tieuDe.runes.length, kTranTieuDeTinHeThong);
    expect(t.noiDung.runes.length, kTranNoiDungTinHeThong);
    expect(t.noiDung.runes.every((r) => r == 0x1F600), isTrue,
        reason: 'cắt theo UTF-16 là để lại nửa cặp surrogate — chữ vỡ trên khay hệ điều hành');
  });

  test('level không phân biệt hoa thường; thiếu / lạ → info', () {
    expect(docTinHeThong(_tin(level: 'critical'))!.mucDo, MucDoTinHeThong.critical);
    expect(docTinHeThong(_tin(level: 'WARNING'))!.mucDo, MucDoTinHeThong.warning,
        reason: 'Admin-web gửi chữ thường, backend mặc định "INFO" chữ hoa');
    expect(docTinHeThong(_tin(level: 'INFO'))!.mucDo, MucDoTinHeThong.info);
    expect(docTinHeThong(_tin(level: null))!.mucDo, MucDoTinHeThong.info);
    expect(docTinHeThong(_tin(level: 'danger'))!.mucDo, MucDoTinHeThong.info);
  });
}
