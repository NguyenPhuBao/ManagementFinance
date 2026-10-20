/// Phân loại phản hồi máy chủ (spec G89 2026-10-20 mục 3.1) — một định nghĩa cho dòng nhắc, đồng bộ và màn Đăng nhập.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/network/trang_thai_may_chu.dart';

void main() {
  final bayGio = DateTime(2026, 10, 20, 10, 0);

  TinhTrangMayChu? pl(int? status, Object? body, {String? retryAfter}) =>
      phanLoaiPhanHoi(status: status, body: body, retryAfter: retryAfter, bayGio: bayGio);

  group('phanLoaiPhanHoi', () {
    test('503 MAINTENANCE_MODE + Retry-After 60 → bảo trì, thử lại sau 60 s', () {
      final t = pl(503, {'code': 'MAINTENANCE_MODE', 'message': 'Admin gõ'}, retryAfter: '60');
      expect(t, isA<MayChuBaoTri>());
      expect((t as MayChuBaoTri).thuLaiLuc, bayGio.add(const Duration(seconds: 60)));
    });

    test('Retry-After thiếu / rác / âm / 0 → 60 s mặc định', () {
      for (final ra in [null, 'abc', '-5', '0', '']) {
        final t = pl(503, {'code': 'MAINTENANCE_MODE'}, retryAfter: ra) as MayChuBaoTri;
        expect(t.thuLaiLuc, bayGio.add(kThuLaiBaoTriMacDinh), reason: 'Retry-After: $ra');
      }
    });

    test('Retry-After: 1 → sàn 30 s', () {
      final t = pl(503, {'code': 'MAINTENANCE_MODE'}, retryAfter: '1') as MayChuBaoTri;
      expect(
        t.thuLaiLuc,
        bayGio.add(kSanThuLai),
        reason: 'không sàn thì một bản server gửi Retry-After: 1 là vòng request mỗi giây',
      );
    });

    test('503 không code / code khác → null (quá tải, lỗi lược đồ giữ hành vi cũ)', () {
      expect(pl(503, {'message': 'Service Unavailable'}), isNull);
      expect(pl(503, {'code': 'SERVER_OVERLOADED'}), isNull);
      expect(pl(503, {'code': 'DB_POOL_OVERLOADED'}), isNull);
    });

    test('403 AIOPS_QUARANTINED có giờ → phong toả, giờ ĐỊA PHƯƠNG cùng thời điểm', () {
      final het = DateTime(2026, 10, 20, 15, 30);
      final t = pl(403, {
        'code': 'AIOPS_QUARANTINED',
        'error': 'AIOPS_QUARANTINED',
        'quarantineExpiresAt': het.toUtc().toIso8601String(),
        'reason': 'x',
      });
      expect(t, isA<MayChuPhongToa>());
      final h = (t as MayChuPhongToa).hetHanLuc!;
      expect(h.isAtSameMomentAs(het), isTrue);
      expect(h.isUtc, isFalse, reason: 'DateTime.== so cả múi — mốc UTC lọt vào SyncEngine là phép so mốc hẹn lệch');
    });

    test('403 AIOPS_QUARANTINED giờ null / rác → phong toả không giờ', () {
      expect((pl(403, {'code': 'AIOPS_QUARANTINED', 'quarantineExpiresAt': null}) as MayChuPhongToa).hetHanLuc, isNull);
      expect(
          (pl(403, {'code': 'AIOPS_QUARANTINED', 'quarantineExpiresAt': 'rác'}) as MayChuPhongToa).hetHanLuc, isNull);
    });

    test('403 FEATURE_DISABLED / trạng thái tài khoản → null', () {
      expect(pl(403, {'code': 'FEATURE_DISABLED', 'featureId': 'x'}), isNull);
      expect(pl(403, {'code': 'ACCOUNT_INACTIVE'}), isNull);
    });

    test('KHÔNG phân loại theo mã HTTP một mình: body không phải Map, code sai mã HTTP → null', () {
      expect(pl(503, '<html>503</html>'), isNull);
      expect(pl(503, null), isNull);
      expect(pl(403, {'code': 'MAINTENANCE_MODE'}), isNull, reason: 'bảo trì chỉ đi với 503');
      expect(pl(503, {'code': 'AIOPS_QUARANTINED'}), isNull, reason: 'phong toả chỉ đi với 403');
      expect(pl(null, {'code': 'MAINTENANCE_MODE'}), isNull);
    });

    test('code lồng dưới errors / data → null (chỉ đọc cấp gốc)', () {
      expect(
          pl(503, {
            'errors': {'code': 'MAINTENANCE_MODE'}
          }),
          isNull);
    });

    test('mỗi lời chặn là một đối tượng MỚI — SyncEngine phân biệt bằng identical', () {
      final a = pl(403, {'code': 'AIOPS_QUARANTINED'});
      final b = pl(403, {'code': 'AIOPS_QUARANTINED'});
      expect(
        identical(a, b),
        isFalse,
        reason: 'constructor const sẽ chuẩn tắc hoá hai lời chặn không giờ thành một',
      );
    });
  });

  group('mocThuLaiKhiBiChan', () {
    test('bình thường → null; phong toả không giờ → null (giãn cách như cũ)', () {
      expect(mocThuLaiKhiBiChan(const MayChuBinhThuong(), bayGio), isNull);
      expect(mocThuLaiKhiBiChan(MayChuPhongToa(), bayGio), isNull);
    });

    test('bảo trì → đúng thuLaiLuc', () {
      final moc = bayGio.add(const Duration(seconds: 60));
      expect(mocThuLaiKhiBiChan(MayChuBaoTri(thuLaiLuc: moc), bayGio), moc);
    });

    test('phong toả giờ tương lai → đúng giờ ấy', () {
      final het = bayGio.add(const Duration(minutes: 20));
      expect(mocThuLaiKhiBiChan(MayChuPhongToa(hetHanLuc: het), bayGio), het);
    });

    test('⭐ giờ đã QUA → sàn bayGio + 30 s, không bao giờ "ngay"', () {
      final qua = bayGio.subtract(const Duration(minutes: 5));
      expect(
        mocThuLaiKhiBiChan(MayChuPhongToa(hetHanLuc: qua), bayGio),
        bayGio.add(kSanThuLai),
        reason:
            'hẹn ở quá khứ là Duration.zero → thử ngay → 403 → thử ngay: vòng request dồn vào IP AIOps đang nghi DoS',
      );
      expect(mocThuLaiKhiBiChan(MayChuBaoTri(thuLaiLuc: qua), bayGio), bayGio.add(kSanThuLai));
    });
  });

  group('chuGioHetHan', () {
    test('cùng ngày → HH:mm', () {
      expect(chuGioHetHan(DateTime(2026, 10, 20, 15, 30), bayGio), '15:30');
    });
    test('khác ngày → HH:mm dd/MM', () {
      expect(chuGioHetHan(DateTime(2026, 10, 21, 9, 0), bayGio), '09:00 21/10');
    });
  });

  test('TrangThaiMayChu khởi đầu bình thường, và ghi lại bình thường không phát', () {
    final t = TrangThaiMayChu();
    var soLanPhat = 0;
    t.addListener(() => soLanPhat++);
    expect(t.value, isA<MayChuBinhThuong>());
    t.value = const MayChuBinhThuong();
    expect(soLanPhat, 0, reason: 'mỗi 2xx ghi bình thường — không được dựng lại dòng nhắc mỗi request');
    t.value = MayChuBaoTri(thuLaiLuc: bayGio);
    expect(soLanPhat, 1);
  });
}
