/// Test quét `lib/` thứ **38** — lệnh in log (`debugPrint` / `print` / `log`) không được in số dư, số tiền, ghi chú giao
/// dịch, tham số tool AI hay nguyên văn tin ngân hàng ở bản RELEASE (2026-10-24, soát bảo mật toàn client-app).
///
/// Vì sao: `debugPrint` **không** bị lược ở bản release — nó vào logcat (thẻ `flutter`). Từ `271c7774` (2026-08-12) Trang
/// chủ in tổng tài sản, tên + số dư từng ví và 5 giao dịch gần nhất kèm NGUYÊN VĂN ghi chú, ở mỗi lần stream ví / giao dịch
/// phát (kể cả sau mỗi lượt đồng bộ nền). Với khoản D1, ghi chú là nội dung chuyển khoản — chính bộ test của
/// `doc_tin_bien_dong` có `NGUYEN PHU BAO Chuyen tien…`, `MOMO-CASHOUT-0355281276…`: tên và số điện thoại người khác. Ai
/// cắm cáp vào máy đã bật gỡ lỗi USB, ai nhận bug report, bộ thu log chẩn đoán của hãng đều đọc được. Trái quy định §13.6
/// `docs/progress/Client-app.md` (*Không ghi log dữ liệu nhạy cảm*); phía Kotlin của cùng luồng D1 đã che số + chỉ log ở
/// bản debug. Cùng lượt: `vong_lap_cong_cu.dart` in `g.args` (tham số tool do mô hình điền — tên ví, ghi chú tìm, khoảng
/// ngày) không chặn, trong khi `phien_mot_loi_goi.dart` đã chặn đúng chỗ ấy bằng `kDebugMode`.
///
/// Quét: dòng MÃ (bỏ dòng bắt đầu bằng `//`) có lời gọi `debugPrint(` / `print(` / `log(` (từ trọn — `_log(`, `dialog(`
/// không tính); câu lệnh gom tới dấu `;` (tối đa 8 dòng); câu nhắc `.balance` · `.amount` · `.note` · `.args` · `.noiDung`
/// mà không qua `kDebugMode` — trong chính câu lệnh (`${kDebugMode ? … : ''}`) hoặc ở một khối bao quanh mở bằng dòng có
/// `kDebugMode` / `assert(` — là đỏ.
///
/// Giới hạn đã biết: không thấy dữ liệu đi qua biến trung gian (`final s = w.balance; debugPrint('$s')`), không thấy chặn
/// bằng `return` sớm (`if (!kDebugMode) return;`), và nhận nhầm `if (!kDebugMode) {` là đã chặn. Số 37 dành cho quét gia
/// đình (spec `2026-10-23-gia-dinh-nen-mong-design.md` mục 7.2).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _lenhLog = RegExp(r'\b(debugPrint|print|log)\(');
final _duLieu = RegExp(r'\.(balance|amount|note|args|noiDung)\b');

/// Số dòng (đếm từ 1) có lệnh log in dữ liệu người dùng mà không qua `kDebugMode`.
List<int> dongLoRaBanRelease(List<String> dong) {
  final vi = <int>[];
  for (var i = 0; i < dong.length; i++) {
    final d = dong[i].trimLeft();
    if (d.startsWith('//') || !_lenhLog.hasMatch(d)) continue;
    final cau = StringBuffer();
    for (var j = i; j < dong.length && j < i + 8; j++) {
      cau.writeln(dong[j]);
      if (dong[j].trimRight().endsWith(';')) break;
    }
    final s = cau.toString();
    if (!_duLieu.hasMatch(s)) continue;
    if (s.contains('kDebugMode') || _trongKhoiDebug(dong, i)) continue;
    vi.add(i + 1);
  }
  return vi;
}

/// Có khối nào bao quanh dòng [i] mở bằng một dòng nhắc `kDebugMode` / `assert(` không — đi lùi, đếm ngoặc nhọn.
bool _trongKhoiDebug(List<String> dong, int i) {
  var chuaKhop = 0; // số `}` gặp khi đi lùi mà chưa gặp `{` của nó
  for (var j = i - 1; j >= 0; j--) {
    final d = dong[j];
    if (d.trimLeft().startsWith('//')) continue;
    for (var k = d.length - 1; k >= 0; k--) {
      if (d[k] == '}') {
        chuaKhop++;
      } else if (d[k] == '{') {
        if (chuaKhop > 0) {
          chuaKhop--;
        } else if (d.contains('kDebugMode') || d.contains('assert(')) {
          return true;
        }
      }
    }
  }
  return false;
}

void main() {
  test('không lệnh log nào trong lib/ in số dư / số tiền / ghi chú / tham số tool ở bản release', () {
    final vi = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;
      final p = f.path.replaceAll(r'\', '/');
      final dong = f.readAsLinesSync();
      for (final so in dongLoRaBanRelease(dong)) {
        vi.add('$p:$so: ${dong[so - 1].trim()}');
      }
    }
    expect(vi, isEmpty,
        reason: '`debugPrint` / `print` không bị lược ở bản release — in dữ liệu người dùng chỉ sau `kDebugMode` '
            '(vd. `\${kDebugMode ? \' \${g.args}\' : \'\'}`), hoặc bỏ hẳn. Thấy ${vi.length} dòng: $vi');
  });

  group('bộ đọc (mẫu viết tay)', () {
    test('in số dư trần → đỏ', () {
      expect(dongLoRaBanRelease([r"debugPrint('Ví ${w.name}: ${w.balance}');"]), [1]);
    });

    test('chặn ngay trong câu bằng kDebugMode → không đỏ', () {
      expect(dongLoRaBanRelease([r"debugPrint('gọi ${g.ten}${kDebugMode ? ' ${g.args}' : ''}');"]), isEmpty);
    });

    test('nằm trong khối if (kDebugMode), kể cả khối lồng → không đỏ', () {
      expect(
          dongLoRaBanRelease([
            'if (kDebugMode) {',
            '  for (final t in ds) {',
            r"    print('${t.note}');",
            '  }',
            '}',
          ]),
          isEmpty);
    });

    test('khối kDebugMode đã ĐÓNG trước lệnh log thì không che được nó', () {
      expect(
          dongLoRaBanRelease([
            'if (kDebugMode) {',
            "  print('a');",
            '}',
            r"debugPrint('${t.amount}');",
          ]),
          [4]);
    });

    test('câu lệnh nhiều dòng: dữ liệu ở dòng sau vẫn bị bắt, báo ở dòng mở lời gọi', () {
      expect(
          dongLoRaBanRelease([
            r"log('lượt $luot: gọi ${g.ten}'",
            r"    ' ${g.args} xong');",
          ]),
          [1]);
    });

    test('không phải lời gọi log, hoặc là chú thích → không đỏ', () {
      expect(
          dongLoRaBanRelease([
            r"final s = '${t.amount}';",
            r"// debugPrint('${w.balance}');",
            r"_log('${t.note}');",
          ]),
          isEmpty);
    });
  });
}
