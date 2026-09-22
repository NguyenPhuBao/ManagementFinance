// test/features/ai_edge/data/mo_hinh_tai_ve_test.dart
/// `MoHinhTaiVe` từ 2026-09-22 tối đứng trên `NguonTaiNen` (lượt tải sống lâu
/// hơn tiến trình) thay vì một hàm `taiTep` tiêm vào. Các ca "huỷ cắt được
/// kết nối" của bản Dio cũ đi theo tệp `tai_tep_dio.dart` — bài học của chúng
/// nằm ở mục 9.7 `AI_EDGE_FEATURE.md`.
library;

import 'dart:io';

import 'package:flowmoney/features/ai_edge/data/mo_hinh_tai_ve.dart';
import 'package:flowmoney/features/ai_edge/data/nguon_tai_nen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tam;
  late NguonTaiNenGia nguon;

  setUp(() {
    tam = Directory.systemTemp.createTempSync('mohinh');
    nguon = NguonTaiNenGia();
  });
  tearDown(() {
    tam.deleteSync(recursive: true);
    nguon.dong();
  });

  MoHinhTaiVe dung() => MoHinhTaiVe(thuMuc: () async => tam, nguon: nguon);

  group('daCo() kiểm KÍCH THƯỚC, không chỉ kiểm tồn tại', () {
    // ⚠️ Hai việc không tách rời được: giữ tệp dở cho resume mà vẫn để
    // `daCo()` dùng `existsSync()` là tệp cụt đọc thành "đã có mô hình", rồi
    // engine ném "Model may be invalid" ở một chỗ chẳng liên quan tới tải.
    test('tệp dở (thiếu ĐÚNG MỘT byte) đọc là CHƯA CÓ', () async {
      final m = dung();
      File('${tam.path}/$kTenTep')
          .writeAsBytesSync(List.filled(kCoTepByte - 1, 0));
      expect(await m.daCo(), isFalse,
          reason: 'Resume giữ tệp dở lại; `existsSync()` sẽ đọc nó thành '
              '"đã có mô hình" rồi engine ném "Model may be invalid".');
    }, skip: 'tệp 2,4 GB — xem ca dưới dùng cỡ giả');

    test('tệp sai cỡ (8 byte) đọc là CHƯA CÓ', () async {
      // Ca "đúng kích thước" không dựng nổi tệp 2,4 GB trong test — đo ở
      // Task 7 trên máy thật. Ca này đo chiều ngược lại, chiều gây hại.
      final m = dung();
      File('${tam.path}/$kTenTep').writeAsBytesSync(List.filled(8, 0));
      expect(await m.daCo(), isFalse,
          reason: '8 byte không phải 2.588.147.712 byte.');
    });

    test('không có tệp thì CHƯA CÓ', () async {
      expect(await dung().daCo(), isFalse);
    });
  });

  group('lượt tải sống lâu hơn tiến trình', () {
    test('khoiPhuc() nối lại lượt của LẦN CHẠY TRƯỚC', () async {
      // Lượt có thật nhưng stream chưa từng phát gì — đúng cảnh app vừa mở lại.
      nguon.dungSanLuotCu(
        (trangThai: TrangThaiLuot.dangChay, phanTram: 0.4, loi: null),
      );
      final m = dung();
      final thu = <TienDoTai>[];
      final dk = m.tienDo.listen(thu.add);

      await m.khoiPhuc();
      await Future<void>.delayed(Duration.zero);

      expect(thu.single.trangThai, TrangThaiMoHinh.dangTai,
          reason: 'Không nối lại thì màn hiện "Chưa tải" và nút Tải sẽ đẻ '
              'lượt thứ hai ghi đè cùng một tệp.');
      expect(thu.single.phanTram, 0.4);
      await dk.cancel();
    });

    test('khoiPhuc() khi KHÔNG có lượt nào thì không phát gì', () async {
      final m = dung();
      final thu = <TienDoTai>[];
      final dk = m.tienDo.listen(thu.add);

      await m.khoiPhuc();
      await Future<void>.delayed(Duration.zero);

      expect(thu, isEmpty,
          reason: 'Phát một tin "0%" cho một lượt không tồn tại là vẽ ra '
              'thanh tiến độ ma.');
      await dk.cancel();
    });

    test('dangCho của nguồn dịch thành choMang, KHÔNG phải dangTai', () async {
      final m = dung();
      final thu = <TrangThaiMoHinh>[];
      final dk = m.tienDo.listen((t) => thu.add(t.trangThai));

      await m.tai();
      nguon.choMang();
      await Future<void>.delayed(Duration.zero);

      expect(thu.last, TrangThaiMoHinh.choMang,
          reason: 'requiresWiFi làm lượt đứng im VÔ THỜI HẠN và gói không báo '
              'lỗi gì; gộp vào dangTai là hiện 0% đứng yên mãi mãi.');
      await dk.cancel();
    });

    test('tamDung/tiepTuc đi thẳng xuống nguồn và phát đúng trạng thái',
        () async {
      final m = dung();
      final thu = <TrangThaiMoHinh>[];
      final dk = m.tienDo.listen((t) => thu.add(t.trangThai));

      await m.tai();
      await m.tamDung();
      await m.tiepTuc();
      await Future<void>.delayed(Duration.zero);

      expect(thu, [
        TrangThaiMoHinh.dangTai,
        TrangThaiMoHinh.tamDung,
        TrangThaiMoHinh.dangTai,
      ]);
      await dk.cancel();
    });

    test('phát tiến độ từ dangTai tới daTai', () async {
      final m = dung();
      final thu = <TienDoTai>[];
      final dk = m.tienDo.listen(thu.add);

      await m.tai();
      nguon.tienToi(0.5);
      nguon.xong();
      await Future<void>.delayed(Duration.zero);

      expect(thu.first.trangThai, TrangThaiMoHinh.dangTai);
      expect(thu.last.trangThai, TrangThaiMoHinh.daTai);
      expect(thu.last.phanTram, 1);
      await dk.cancel();
    });

    test('lượt hỏng → trạng thái loi kèm CÂU NGẮN, và tệp dở ĐƯỢC GIỮ',
        () async {
      // Trước resume, tải hỏng là xoá tệp dở ngay. Nay tệp dở là thứ lượt sau
      // tiếp tục; phép chặn "tệp cụt trông như tệp đủ" nằm ở `daCo()`.
      final f = File('${tam.path}/$kTenTep')..writeAsBytesSync([1, 2, 3]);
      final m = dung();
      final thu = <TienDoTai>[];
      final dk = m.tienDo.listen(thu.add);

      await m.tai();
      nguon.hong('HttpException: Connection closed while receiving data, '
          'uri = https://x/${'a' * 300}');
      await Future<void>.delayed(Duration.zero);

      expect(thu.last.trangThai, TrangThaiMoHinh.loi);
      expect(thu.last.loi, 'Mất kết nối giữa chừng. Kiểm tra mạng rồi tải lại.');
      expect(f.existsSync(), isTrue);
      expect(await m.daCo(), isFalse);
      await dk.cancel();
    });

    test('huy() xoá tệp dở và về chuaTai', () async {
      final f = File('${tam.path}/$kTenTep')..writeAsBytesSync([1, 2, 3]);
      final m = dung();
      final thu = <TrangThaiMoHinh>[];
      final dk = m.tienDo.listen((t) => thu.add(t.trangThai));

      await m.tai();
      await m.huy();
      await Future<void>.delayed(Duration.zero);

      expect(f.existsSync(), isFalse,
          reason: 'Huỷ là ý định dừng HẲN — giữ tệp dở lại thì nó chiếm chỗ '
              'mà không ai tiếp tục nó nữa.');
      expect(thu.last, TrangThaiMoHinh.chuaTai);
      expect(await nguon.luotDangSong(), isNull);
      await dk.cancel();
    });

    test('tai(chiWifi: false) truyền thẳng xuống nguồn', () async {
      final m = dung();
      await m.tai(chiWifi: false);
      expect(nguon.chiWifiLanCuoi, isFalse);
    });

    test('xoa() gỡ tệp và đưa daCo() về false', () async {
      File('${tam.path}/$kTenTep').writeAsBytesSync([1, 2, 3]);
      final m = dung();
      await m.xoa();
      expect(File(await m.duongTep()).existsSync(), isFalse);
      expect(await m.daCo(), isFalse);
    });
  });

  // ⚠️ Lý do nhóm này tồn tại: nghiệm thu máy thật 2026-09-22 (P3 Task 9) —
  // màn Cài đặt AI hiện MỘT BỨC TƯỜNG base64 khi kết nối đứt, vì URL
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
