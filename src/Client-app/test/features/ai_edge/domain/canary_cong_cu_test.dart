/// Canary cho PHIÊN CÓ TOOL (bước 1b, 2026-09-23) — bẫy 4.33 `AI_EDGE_FEATURE.md`.
///
/// Với `flutter_gemma_litertlm` 1.7.0, phiên có tool **sập native** ngay lượt
/// giải mã đầu trên cả hai máy đo — `try/catch` vô dụng, app văng ở MỌI câu
/// hỏi. Bản 1.9.0 / 1.8.0 hết sập, nhưng máy khác chưa đo.
///
/// Khác canary GPU ở một chỗ quyết định: dấu còn sót **không** tự nó là bằng
/// chứng sập. Realme giết app khi vuốt khỏi Recents (đo 2026-09-22), hệ điều
/// hành giết khi thiếu RAM, người dùng bấm Buộc dừng — cả ba để dấu lại y hệt
/// một cú sập. Chép nguyên khuôn GPU thì một lần vuốt app giữa lúc trả lời là
/// mất bậc tool **vĩnh viễn** trên máy ấy. Người dùng chốt lối B: hỏi Android
/// lý do lần thoát (`ApplicationExitInfo`, API 30+), chỉ tắt khi là sập native;
/// máy không cho biết lý do thì tắt khi dấu sót **hai lần liền**.
library;

import 'dart:async';
import 'dart:io';

import 'package:flowmoney/features/ai_edge/domain/canary_cong_cu.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lý do thoát của Android dùng trong test (`ApplicationExitInfo`).
const int _lyDoKhac = 13; // REASON_OTHER — Realme "remove task"
const int _lyDoNguoiDungDung = 10; // REASON_USER_REQUESTED — Buộc dừng
const int _lyDoThieuRam = 3; // REASON_LOW_MEMORY

class _NguonGia implements NguonLyDoThoat {
  _NguonGia({this.lanThoat, this.phien = 7});
  List<LanThoat>? lanThoat;
  int? phien;
  var soLanHoi = 0;

  @override
  Future<List<LanThoat>?> cacLanThoat() async {
    soLanHoi++;
    return lanThoat;
  }

  @override
  Future<int?> phienBan() async => phien;
}

void main() {
  late Directory tam;
  setUp(() => tam = Directory.systemTemp.createTempSync('canary_cong_cu'));
  tearDown(() => tam.deleteSync(recursive: true));

  final lucDat = DateTime(2026, 9, 23, 20, 0, 0);

  CanaryCongCu dung(_NguonGia nguon, {DateTime? luc}) => CanaryCongCu(
        thuMuc: () async => tam,
        nguon: nguon,
        dongHo: () => luc ?? lucDat,
      );

  File tep(String ten) => File('${tam.path}/$ten');

  group('xét dấu sót — Android cho biết lý do thoát (API 30+)', () {
    test('máy sạch → bậc tool mở, không hỏi hệ điều hành gì', () async {
      final nguon = _NguonGia(lanThoat: const []);
      expect(await dung(nguon).daTat(), isFalse);
      expect(nguon.soLanHoi, 0,
          reason: 'không có dấu sót thì không có gì để đối chiếu — hỏi kênh '
              'native ở mỗi câu hỏi là tốn công vô ích');
    });

    test('⭐ dấu sót + lần thoát đầu tiên sau dấu là SẬP NATIVE → tắt bậc tool',
        () async {
      await dung(_NguonGia()).batDauLuot();
      final nguon = _NguonGia(lanThoat: [
        LanThoat(
            lyDo: kLyDoSapNative, luc: lucDat.add(const Duration(seconds: 4))),
      ]);
      final c = dung(nguon); // tiến trình mới sau cú sập

      expect(await c.daTat(), isTrue,
          reason: 'không tắt thì mỗi câu hỏi lại mở phiên có tool và lại văng');
      expect(tep(kTepCongCuHong).readAsStringSync(), '7',
          reason: 'dấu "hỏng" ghi phiên bản app để tự mở lại khi app lên bản '
              'mới — bản mới có thể đã nâng engine');
      expect(tep(kTepCanaryCongCu).existsSync(), isFalse);
      expect(await c.daTat(), isTrue, reason: 'đã tắt thì tắt tiếp');
    });

    for (final (ten, lyDo) in [
      ('Realme giết app khi vuốt khỏi Recents', _lyDoKhac),
      ('người dùng bấm Buộc dừng', _lyDoNguoiDungDung),
      ('hệ điều hành giết vì thiếu RAM', _lyDoThieuRam),
    ]) {
      test('dấu sót vì $ten → CHỈ xoá dấu, bậc tool vẫn mở', () async {
        await dung(_NguonGia()).batDauLuot();
        final c = dung(_NguonGia(lanThoat: [
          LanThoat(lyDo: lyDo, luc: lucDat.add(const Duration(seconds: 6))),
        ]));

        expect(await c.daTat(), isFalse,
            reason: 'đây là lý do người dùng chọn lối B: chép khuôn GPU thì '
                'một lần app bị giết giữa lúc trả lời là mất bậc tool vĩnh viễn');
        expect(tep(kTepCanaryCongCu).existsSync(), isFalse,
            reason: 'dấu đã giải thích xong phải xoá, kẻo lần sau xét lại');
        expect(tep(kTepCongCuHong).existsSync(), isFalse);
      });
    }

    test('xét lần thoát ĐẦU TIÊN sau lúc đặt dấu, không phải lần mới nhất',
        () async {
      await dung(_NguonGia()).batDauLuot();
      // Danh sách của Android xếp MỚI NHẤT TRƯỚC. Tiến trình đặt dấu sập native;
      // tiến trình kế (chưa kịp xét dấu) bị người dùng buộc dừng.
      final c = dung(_NguonGia(lanThoat: [
        LanThoat(
            lyDo: _lyDoNguoiDungDung,
            luc: lucDat.add(const Duration(minutes: 5))),
        LanThoat(
            lyDo: kLyDoSapNative, luc: lucDat.add(const Duration(seconds: 3))),
        LanThoat(
            lyDo: kLyDoSapNative,
            luc: lucDat.subtract(const Duration(hours: 1))),
      ]));

      expect(await c.daTat(), isTrue,
          reason: 'lấy bản ghi mới nhất thì đọc nhầm "buộc dừng" và bỏ qua '
              'đúng cú sập để lại dấu');
    });

    test('lần thoát TRƯỚC lúc đặt dấu không tính', () async {
      await dung(_NguonGia()).batDauLuot();
      final c = dung(_NguonGia(lanThoat: [
        LanThoat(
            lyDo: _lyDoKhac, luc: lucDat.add(const Duration(seconds: 2))),
        LanThoat(
            lyDo: kLyDoSapNative,
            luc: lucDat.subtract(const Duration(seconds: 30))),
      ]));

      expect(await c.daTat(), isFalse,
          reason: 'cú sập cũ hơn dấu thuộc về một chuyện khác — lần thoát của '
              'tiến trình giữ dấu là bị giết, không phải sập');
    });
  });

  group('xét dấu sót — Android KHÔNG cho biết lý do (Android 10 trở xuống)', () {
    test('dấu sót lần đầu → chưa tắt; lần thứ hai LIỀN → tắt', () async {
      final nguon = _NguonGia(lanThoat: null);

      await dung(nguon).batDauLuot();
      expect(await dung(nguon).daTat(), isFalse,
          reason: 'một dấu sót có thể chỉ là app bị giết');

      await dung(nguon).batDauLuot();
      expect(await dung(nguon).daTat(), isTrue,
          reason: 'hai lần liền mới đủ để coi là sập');
    });

    test('một lượt chạy xong ở giữa làm lại từ đầu — "hai lần LIỀN"',
        () async {
      final nguon = _NguonGia(lanThoat: null);

      await dung(nguon).batDauLuot();
      expect(await dung(nguon).daTat(), isFalse);

      final c = dung(nguon);
      await c.batDauLuot();
      await c.xongLuot(); // một lượt sinh chạy trơn

      await dung(nguon).batDauLuot();
      expect(await dung(nguon).daTat(), isFalse,
          reason: 'lượt trơn ở giữa chứng minh engine chạy được trên máy này');
    });

    test('Android có danh sách nhưng không có bản ghi nào sau dấu → cũng đếm',
        () async {
      final nguon = _NguonGia(lanThoat: [
        LanThoat(
            lyDo: kLyDoSapNative,
            luc: lucDat.subtract(const Duration(days: 1))),
      ]);

      await dung(nguon).batDauLuot();
      expect(await dung(nguon).daTat(), isFalse);
      await dung(nguon).batDauLuot();
      expect(await dung(nguon).daTat(), isTrue,
          reason: 'không biết lý do thì rơi về luật hai lần liền, không đoán');
    });
  });

  group('phiên bản app', () {
    test('app lên bản mới → dấu "hỏng" tự xoá, bậc tool mở lại', () async {
      tep(kTepCongCuHong).writeAsStringSync('7');

      expect(await dung(_NguonGia(phien: 7)).daTat(), isTrue);
      expect(await dung(_NguonGia(phien: 8)).daTat(), isFalse,
          reason: 'bản mới có thể đã nâng engine và sửa lỗi — tắt vĩnh viễn '
              'là không bao giờ biết');
      expect(tep(kTepCongCuHong).existsSync(), isFalse);
    });

    test('không đọc được phiên bản → giữ nguyên trạng thái tắt', () async {
      tep(kTepCongCuHong).writeAsStringSync('7');
      expect(await dung(_NguonGia(phien: null)).daTat(), isTrue,
          reason: 'không biết là bản mới thì không thử lại — thử là liều văng '
              'app ở mọi câu hỏi');
    });
  });

  group('quaCanary — dấu bao đúng khoảng TRƯỚC sự kiện đầu tiên của lượt', () {
    test('dấu có mặt trước khi lượt phát gì, gỡ ngay ở sự kiện đầu', () async {
      final c = dung(_NguonGia());
      final nguon = StreamController<int>();
      var daGoiLuot = false;
      final nhan = <int>[];

      final sub = quaCanary(() {
        daGoiLuot = true;
        expect(tep(kTepCanaryCongCu).existsSync(), isTrue,
            reason: 'dấu phải nằm trên đĩa TRƯỚC khi engine bắt đầu giải mã '
                '— sập rồi thì không còn cơ hội ghi');
        return nguon.stream;
      }, c)
          .listen(nhan.add);
      // Gắn TRƯỚC khi luồng kết thúc — gắn sau thì sự kiện "xong" đã qua và
      // future này không bao giờ hoàn tất.
      final xong = sub.asFuture<void>();

      await pumpEventQueue();
      expect(daGoiLuot, isTrue);
      expect(tep(kTepCanaryCongCu).existsSync(), isTrue,
          reason: 'chưa có sự kiện nào thì engine chưa qua bước từng sập');

      nguon.add(1);
      await pumpEventQueue();
      expect(nhan, [1]);
      expect(tep(kTepCanaryCongCu).existsSync(), isFalse,
          reason: 'đã có sự kiện đầu là engine đã giải mã qua bước từng sập; '
              'giữ dấu tiếp là kéo dài cửa sổ báo nhầm');

      nguon.add(2);
      await nguon.close();
      await xong;
      expect(nhan, [1, 2]);
    });

    test('lượt rỗng, lượt ném lỗi, lượt bị huỷ — đều gỡ dấu', () async {
      final c = dung(_NguonGia());

      await quaCanary(() => const Stream<int>.empty(), c).drain<void>();
      expect(tep(kTepCanaryCongCu).existsSync(), isFalse, reason: 'lượt rỗng');

      await expectLater(
          quaCanary(() => Stream<int>.error(StateError('engine')), c),
          emitsError(isStateError));
      expect(tep(kTepCanaryCongCu).existsSync(), isFalse,
          reason: 'lỗi THƯỜNG không phải sập native — chỉ cú sập mới được '
              'để dấu lại');

      // Huỷ một luồng `async*` đang chờ `await for` chỉ có hiệu lực khi luồng
      // bên trong phát hoặc đóng — trong app, `huy()` gọi `stopGeneration` và
      // lượt của engine đóng lại. Test dựng đúng trình tự ấy.
      final treo = StreamController<int>();
      final sub = quaCanary(() => treo.stream, c).listen((_) {});
      await pumpEventQueue();
      expect(tep(kTepCanaryCongCu).existsSync(), isTrue);
      final huy = sub.cancel();
      await treo.close(); // stopGeneration: engine thôi giải mã
      await huy;
      expect(tep(kTepCanaryCongCu).existsSync(), isFalse,
          reason: 'người dùng rời màn giữa lượt — không có gì sập cả');
    });

    test('không có canary (test, máy không dùng) → lượt đi qua nguyên vẹn',
        () async {
      expect(await quaCanary(() => Stream.fromIterable([1, 2, 3]), null).toList(),
          [1, 2, 3]);
    });
  });
}
