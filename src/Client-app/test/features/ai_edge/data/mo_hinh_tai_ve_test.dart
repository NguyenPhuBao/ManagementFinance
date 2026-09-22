// test/features/ai_edge/data/mo_hinh_tai_ve_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/data/mo_hinh_tai_ve.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('mohinh'));
  tearDown(() => tmp.deleteSync(recursive: true));

  MoHinhTaiVe dung({
    Future<void> Function(
            String url, File dich, void Function(double), DauHuy)?
        taiGia,
  }) =>
      MoHinhTaiVe(
        thuMuc: () async => tmp,
        taiTep: taiGia ??
            (url, dich, bao, dauHuy) async {
              bao(0.5);
              dich.writeAsBytesSync(List.filled(1024, 0));
              bao(1.0);
            },
      );

  test('chưa tải thì daCo() false', () async {
    expect(await dung().daCo(), isFalse);
  });

  test('tải xong thì daCo() true và tệp nằm đúng chỗ', () async {
    final m = dung();
    await m.tai();
    expect(await m.daCo(), isTrue);
    expect(File(await m.duongTep()).existsSync(), isTrue);
  });

  test('phát tiến độ từ dangTai tới daTai', () async {
    final m = dung();
    final thu = <TrangThaiMoHinh>[];
    final sub = m.tienDo.listen((t) => thu.add(t.trangThai));
    await m.tai();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(thu.first, TrangThaiMoHinh.dangTai);
    expect(thu.last, TrangThaiMoHinh.daTai);
  });

  test('⚠️ tải hỏng giữa chừng thì XOÁ tệp dở, không để lại bản cụt', () async {
    // Tệp cụt 1,2 GB trông y hệt tệp đủ với `existsSync()`, và lần mở app sau
    // sẽ nạp nó rồi ném "Model may be invalid" — đúng thông báo mà P1 đã mất
    // hàng giờ vì nó (mục 8.2). Xoá ngay lúc hỏng là chỗ rẻ nhất để chặn.
    final m = dung(taiGia: (url, dich, bao, _) async {
      dich.writeAsBytesSync(List.filled(512, 0));
      throw const SocketException('mất mạng');
    });
    await expectLater(m.tai(), throwsA(isA<Exception>()));
    expect(await m.daCo(), isFalse);
    expect(File(await m.duongTep()).existsSync(), isFalse);
  });

  test('trạng thái sau khi hỏng là loi, kèm câu lỗi', () async {
    final m = dung(taiGia: (url, dich, bao, _) async {
      throw const SocketException('mất mạng');
    });
    final thu = <TienDoTai>[];
    final sub = m.tienDo.listen(thu.add);
    try {
      await m.tai();
    } catch (_) {}
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(thu.last.trangThai, TrangThaiMoHinh.loi);
    expect(thu.last.loi, isNotNull);
  });

  test('xoa() gỡ tệp và đưa daCo() về false', () async {
    final m = dung();
    await m.tai();
    await m.xoa();
    expect(await m.daCo(), isFalse);
  });

  test('gọi tai() hai lần chồng nhau chỉ chạy MỘT lượt', () async {
    var soLan = 0;
    final m = dung(taiGia: (url, dich, bao, _) async {
      soLan++;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      dich.writeAsBytesSync(List.filled(16, 0));
    });
    await Future.wait([m.tai(), m.tai()]);
    expect(soLan, 1,
        reason: 'Người dùng bấm hai lần, hoặc màn dựng lại giữa chừng — hai '
            'lượt tải 2,41 GB song song vào cùng một tệp là hỏng tệp.');
  });

  group('Huỷ giữa chừng', () {
    /// ⚠️ Bốn ca này sinh ra từ một lỗi đo được trên bản đầu: `huy()` chỉ đặt
    /// một cờ, còn `taiTep` vẫn được `await` tới khi tải xong **trọn 2,41 GB**
    /// rồi mới ném và xoá tệp. Người dùng bấm Huỷ thì màn quay về "Chưa tải"
    /// trong khi máy **vẫn tải hết ở nền** — trên dữ liệu di động đó là 2,41 GB
    /// họ tưởng đã chặn. Không có ca nào canh nên lỗi sống qua cả Task 5 lẫn
    /// Task 7.

    /// Mô phỏng một lượt tải **dài** (thật thì hàng phút): nó chỉ kết thúc khi
    /// có người báo huỷ, hoặc khi hết 5 giây. Nếu `huy()` không đi tới được
    /// hàm tải thì ca này treo tới mốc 5 giây rồi đỏ ở `daChayHet`.
    Future<void> Function(String, File, void Function(double), DauHuy) taiDai(
      void Function() ghiDaChayHet,
    ) =>
        (url, dich, bao, dauHuy) async {
          dich.writeAsBytesSync(List.filled(512, 0));
          await Future.any([
            dauHuy.khiHuy,
            Future<void>.delayed(const Duration(seconds: 5))
                .then((_) => ghiDaChayHet()),
          ]);
        };

    test('⚠️ huỷ thì hàm tải ĐƯỢC BÁO, không chạy tiếp tới hết', () async {
      var daChayHet = false;
      final m = dung(taiGia: taiDai(() => daChayHet = true));
      final luot = m.tai();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      m.huy();
      await luot;
      expect(daChayHet, isFalse,
          reason: 'Huỷ phải CẮT lượt tải, không phải chỉ thôi vẽ tiến độ — '
              'người dùng bấm Huỷ là để máy thôi tải 2,41 GB.');
    });

    test('huỷ thì trạng thái về chuaTai, KHÔNG phải loi', () async {
      final m = dung(taiGia: taiDai(() {}));
      final thu = <TienDoTai>[];
      final sub = m.tienDo.listen(thu.add);
      final luot = m.tai();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      m.huy();
      await luot;
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(thu.last.trangThai, TrangThaiMoHinh.chuaTai,
          reason: 'Huỷ là việc người dùng CHỦ Ý làm. Dựng khối lỗi đỏ cho một '
              'thao tác thành công là nói dối họ rằng có gì đó hỏng.');
      expect(thu.last.loi, isNull);
    });

    test('huỷ thì tệp dở bị xoá', () async {
      final m = dung(taiGia: taiDai(() {}));
      final luot = m.tai();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      m.huy();
      await luot;
      expect(await m.daCo(), isFalse);
      expect(File(await m.duongTep()).existsSync(), isFalse,
          reason: 'Cùng lý lẽ với nhánh tải hỏng: một tệp cụt trông y hệt tệp '
              'đủ với `existsSync()`.');
    });

    test('⚠️ tải LẠI sau khi huỷ thì chạy được, không huỷ sẵn', () async {
      // Cờ huỷ phải thuộc về TỪNG LƯỢT tải. Dùng chung một tín hiệu cho cả
      // đời đối tượng thì lượt sau bị huỷ ngay khi vừa bắt đầu — im lặng, và
      // người dùng thấy nút Tải bấm mãi không lên gì.
      final m = dung(taiGia: (url, dich, bao, dauHuy) async {
        if (dauHuy.daHuy) return; // tín hiệu cũ còn bật → không tải gì cả
        await Future.any([
          dauHuy.khiHuy,
          Future<void>.delayed(const Duration(milliseconds: 200)),
        ]);
        if (dauHuy.daHuy) return;
        dich.writeAsBytesSync(List.filled(16, 0));
      });

      final luot = m.tai();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      m.huy();
      await luot;
      expect(await m.daCo(), isFalse);

      await m.tai();
      expect(await m.daCo(), isTrue,
          reason: 'Lượt tải thứ hai phải có tín hiệu huỷ MỚI, chưa bị bật.');
    });
  });
}
