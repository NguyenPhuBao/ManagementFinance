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

  // Nghiệm thu máy thật 2026-09-22 (P3 Task 9, OnePlus 13R) dựng đúng ca này:
  // kết nối tới CDN HuggingFace đứt giữa chừng, và màn Cài đặt AI hiện nguyên
  // `DioException.toString()` — một bức tường base64 phủ kín màn hình, vì URL
  // tải là đường ký có chữ ký + policy + hạn dùng, dài hàng nghìn ký tự.
  group('cauLoiTai — câu ngắn cho người đọc, chi tiết để lại cho log', () {
    // Chuỗi THẬT, chép từ máy lúc nghiệm thu (đã rút gọn phần đuôi chữ ký).
    const loiThat = 'DioException [unknown]: null\n'
        'Error: HttpException: Connection closed while receiving data, '
        'uri = https://us.aws.cdn.hf.co/xet-bridge-us/69c476dababacb9018e97cfa/'
        'ee3c29acd58e68bea04006a144cd2e40b3b34dcf5c08200a013744c518b15115'
        '?response-content-disposition=inline%3B+filename%2A%3DUTF-8%27%27'
        'gemma-4-E2B-it.litertlm&Expires=1790070305&Policy=eyJTdGF0ZW1lbnQi'
        'Olt7IlJlc291cmNlIjoiaHR0cHM6Ly91cy5hd3MuY2RuLmhmLmNvL3hldC1icmlkZ2Ut'
        'dXMvNjljNDc2ZGFiYWJhY2I5MDE4ZTk3Y2ZhLyoifV19&Signature=MEUCIE2R9OO';

    test('lỗi mạng thật: không còn URL, và ngắn hơn một dòng', () {
      final cau = cauLoiTai(loiThat);

      expect(cau, isNot(contains('http')),
          reason: 'URL ký là thứ đã phủ kín màn hình khi đo trên máy thật.');
      expect(cau, isNot(contains('Policy')));
      expect(cau.length, lessThan(80),
          reason: 'Chuỗi gốc dài ${loiThat.length} ký tự.');
      expect(cau, contains('Mất kết nối'));
    });

    test('hết dung lượng KHÔNG bị gộp vào nhánh mạng', () {
      // Ca thật với tệp 2,41 GB. Bảo người dùng "kiểm tra mạng" khi máy hết
      // chỗ là chỉ họ đi sai hướng hẳn — nên nhánh này phải đứng trước.
      final cau = cauLoiTai(
        const FileSystemException('write failed', '/data/x',
            OSError('No space left on device', 28)),
      );
      expect(cau, contains('dung lượng'));
      expect(cau, isNot(contains('Kiểm tra mạng')));
    });

    test('lỗi lạ: giữ phần đầu, cắt sạch từ chỗ URL trở đi', () {
      final cau = cauLoiTai(
        'Chuyện gì đó chưa gặp bao giờ, uri = https://example.com/${'a' * 500}',
      );
      expect(cau, startsWith('Chuyện gì đó chưa gặp bao giờ'));
      expect(cau, isNot(contains('http')));
      expect(cau.length, lessThanOrEqualTo(120));
    });

    test('lỗi lạ rất dài mà KHÔNG có URL vẫn bị cắt về 120 ký tự', () {
      final cau = cauLoiTai('x' * 500);
      expect(cau.length, lessThanOrEqualTo(120));
      expect(cau, endsWith('…'),
          reason: 'Cắt ngang mà không có dấu hiệu thì đọc như một câu cụt.');
    });
  });
}
