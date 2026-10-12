/// C4 — hợp đồng một lượt nghe: chữ tạm rồi ĐÚNG MỘT kết thúc, lỗi thắng `done` (Task 12 vòng sửa 1).
library;

import 'package:fake_async/fake_async.dart';
import 'package:flowmoney/features/transaction/data/datasources/luot_nghe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> nhat;
  late LuotNghe luot;

  setUp(() {
    nhat = [];
    luot = LuotNghe(
      onChu: (c, x) => nhat.add('chu:$c:$x'),
      onLoi: (m) => nhat.add('loi:$m'),
      onDung: () => nhat.add('dung'),
    );
  });

  test('(i) done rồi lỗi trong nhịp → chỉ onLoi', () {
    fakeAsync((t) {
      luot.done();
      t.elapse(kChoLoiSauDone ~/ 2);
      luot.loi('error_network');
      t.elapse(kChoLoiSauDone * 2);
      expect(nhat, ['loi:error_network'], reason: 'lỗi đến sau done phải thắng — không thì Cubit mất mã lỗi');
    });
  });

  test('(ii) done, hết nhịp không lỗi → onDung đúng một lần', () {
    fakeAsync((t) {
      luot.done();
      luot.done();
      t.elapse(kChoLoiSauDone * 2);
      expect(nhat, ['dung']);
    });
  });

  test('(iii) chữ cuối rồi done → không gì thêm', () {
    fakeAsync((t) {
      luot.chu('an pho', true);
      luot.done();
      t.elapse(kChoLoiSauDone * 2);
      expect(nhat, ['chu:an pho:true']);
    });
  });

  test('(iv) chữ tạm rồi lỗi (không done) → onLoi', () {
    fakeAsync((t) {
      luot.chu('an', false);
      luot.loi('error_no_match');
      t.elapse(kChoLoiSauDone * 2);
      expect(nhat, ['chu:an:false', 'loi:error_no_match']);
    });
  });

  test('(v) lỗi rồi done → không gì thêm', () {
    fakeAsync((t) {
      luot.loi('error_network');
      luot.done();
      t.elapse(kChoLoiSauDone * 2);
      expect(nhat, ['loi:error_network']);
    });
  });

  test('(vi) huỷ → không phát gì, kể cả done đang hẹn', () {
    fakeAsync((t) {
      luot.done();
      luot.huy();
      luot.loi('error_network');
      luot.chu('x', true);
      t.elapse(kChoLoiSauDone * 2);
      expect(nhat, isEmpty);
    });
  });

  test('chữ cuối tới trong nhịp hoãn → phát chữ cuối, không onDung', () {
    fakeAsync((t) {
      luot.done();
      luot.chu('an pho', true);
      t.elapse(kChoLoiSauDone * 2);
      expect(nhat, ['chu:an pho:true']);
    });
  });
}
