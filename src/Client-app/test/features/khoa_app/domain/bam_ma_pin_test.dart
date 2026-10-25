import 'dart:convert';

import 'package:flowmoney/features/khoa_app/domain/bam_ma_pin.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _hex(String h) => [for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)];

void main() {
  test('RFC 7914 §11: passwd / salt / 1 vòng / 64 byte', () {
    expect(
      pbkdf2HmacSha256(utf8.encode('passwd'), utf8.encode('salt'), 1, 64),
      _hex('55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
          '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783'),
    );
  });

  test('RFC 7914 §11: Password / NaCl / 80000 vòng / 64 byte', () {
    expect(
      pbkdf2HmacSha256(utf8.encode('Password'), utf8.encode('NaCl'), 80000, 64),
      _hex('4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56'
          'a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d'),
    );
  });

  test('bamMaPin = base64 của 32 byte PBKDF2 (đối chiếu Python)', () {
    expect(
      bamMaPin('123456', List<int>.generate(16, (i) => i), 1000),
      base64Encode(_hex('6e3849111be8d3070634220666e93c55dbfd75e923f34d35716805464c0a7eaf')),
    );
  });

  test('soSanhHangThoiGian', () {
    expect(soSanhHangThoiGian([1, 2, 3], [1, 2, 3]), isTrue);
    expect(soSanhHangThoiGian([1, 2, 3], [1, 2, 4]), isFalse);
    expect(soSanhHangThoiGian([1, 2, 3], [1, 2]), isFalse);
    // M2: khác ở byte ĐẦU / GIỮA (không chỉ cuối) — bản sai `khac = a[i] ^ b[i]` (bỏ `|`) chỉ so byte cuối.
    expect(soSanhHangThoiGian([9, 2, 3], [1, 2, 3]), isFalse, reason: 'khác ở byte đầu');
    expect(soSanhHangThoiGian([1, 2, 3], [1, 7, 3]), isFalse, reason: 'khác ở byte giữa');
    expect(soSanhHangThoiGian([1, 2, 3, 4, 5], [1, 2, 9, 4, 5]), isFalse);
  });
}
