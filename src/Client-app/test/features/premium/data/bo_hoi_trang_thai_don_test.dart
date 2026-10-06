/// `BoHoiTrangThaiDon` — hỏi trạng thái đơn mỗi 3 s khi chạy, hỏi ngay theo
/// yêu cầu, hỏng thì im và lượt sau vẫn chạy (spec Premium 9.3). Ai bật / tắt
/// là việc của màn (ba vế "đang hiện").
library;

import 'package:fake_async/fake_async.dart';
import 'package:flowmoney/features/premium/data/bo_hoi_trang_thai_don.dart';
import 'package:flowmoney/features/premium/domain/don_thanh_toan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hỏi mỗi 3 s khi chạy; dừng thì thôi; kết quả đẩy ra khiCo', () {
    fakeAsync((a) {
      var lan = 0;
      final nhan = <TrangThaiDon>[];
      final bo = BoHoiTrangThaiDon(
        hoi: () async {
          lan++;
          return TrangThaiDon.pending;
        },
        khiCo: nhan.add,
      );
      bo.batDau();
      a.elapse(const Duration(seconds: 9));
      expect(lan, 3);
      expect(nhan, everyElement(TrangThaiDon.pending));
      bo.dung();
      a.elapse(const Duration(seconds: 9));
      expect(lan, 3);
      expect(bo.dangChay, isFalse);
    });
  });

  test('hoiNgay hỏi ngay không chờ nhịp; hỏi ném → im, lượt sau vẫn chạy', () {
    fakeAsync((a) {
      var lan = 0;
      final nhan = <TrangThaiDon>[];
      final bo = BoHoiTrangThaiDon(
        hoi: () async {
          lan++;
          if (lan == 1) throw StateError('mạng');
          return TrangThaiDon.paid;
        },
        khiCo: nhan.add,
      );
      bo.batDau();
      bo.hoiNgay();
      a.flushMicrotasks();
      expect(lan, 1);
      expect(nhan, isEmpty, reason: 'ném thì im');
      a.elapse(const Duration(seconds: 3));
      expect(nhan, [TrangThaiDon.paid]);
      bo.dung();
    });
  });

  test('batDau hai lần = một timer; đang hỏi thì nhịp kế không chồng', () {
    fakeAsync((a) {
      var lan = 0;
      final bo = BoHoiTrangThaiDon(
        hoi: () async {
          lan++;
          await Future<void>.delayed(const Duration(seconds: 5));
          return TrangThaiDon.pending;
        },
        khiCo: (_) {},
      );
      bo
        ..batDau()
        ..batDau();
      a.elapse(const Duration(seconds: 3));
      expect(lan, 1);
      a.elapse(const Duration(seconds: 3));
      expect(lan, 1, reason: 'lượt trước (5 s) chưa về thì không hỏi chồng');
      bo.dung();
    });
  });
}
