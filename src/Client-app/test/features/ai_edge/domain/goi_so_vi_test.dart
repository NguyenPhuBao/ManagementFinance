/// Gói số của trang Quản lý ví (chặng 1.5) — gói số **thứ sáu**.
///
/// Câu hỏi nó trả lời là câu người dùng thật sự hay hỏi: *"vì sao tổng tài sản
/// không bằng tổng các ví tôi nhìn thấy"*. Đáp án nằm ở hai chỗ tiền **cố ý**
/// bị loại khỏi tổng: ví tắt cờ `includeInTotal`, và ví đã lưu trữ.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so_vi.dart';
import 'package:flowmoney/features/ai_edge/domain/kiem_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flutter_test/flutter_test.dart';

ViChoGoiSo _vi(
  String ten,
  double soDu, {
  bool trongTong = true,
  String status = 'active',
  bool daXoa = false,
  bool choPhepAm = false,
}) =>
    ViChoGoiSo(
      ten: ten,
      soDu: soDu,
      includeInTotal: trongTong,
      status: status,
      isDeleted: daXoa,
      allowNegative: choPhepAm,
    );

void main() {
  group('thiếu dữ liệu', () {
    test('chưa có ví nào: câu THẬT, không thẻ số liệu nào', () {
      final g = GoiSoVi.tu(const []);
      expect(g.thieuDuLieu, isTrue);
      expect(g.mauCau().muc, MucNhanXet.thieuDuLieu);
      expect(g.soLieu, isEmpty);
    });

    test('ví đã xoá mềm KHÔNG kéo gói ra khỏi trạng thái rỗng', () {
      final g = GoiSoVi.tu([_vi('Cũ', 500000, daXoa: true)]);
      expect(g.thieuDuLieu, isTrue,
          reason: 'ví đã xoá không còn là ví của người dùng ở bất kỳ vế nào');
    });
  });

  group('số liệu', () {
    test('tổng tài sản chỉ cộng ví ĐƯỢC tính vào tổng', () {
      final g = GoiSoVi.tu([
        _vi('Tiền mặt', 1000000),
        _vi('Ngân hàng', 2000000),
        _vi('Quỹ đen', 500000, trongTong: false),
        _vi('Sổ cũ', 300000, status: 'inactive'),
      ]);
      final s = {for (final x in g.soLieu) x.nhan: x.soTho};
      expect(s['Tổng tài sản'], 3000000);
      expect(s['Số ví'], 2);
      expect(s['Ví ngoài tổng'], 2, reason: 'ví tắt cờ VÀ ví lưu trữ');
      expect(s['Không tính vào tổng'], 800000);
    });

    test('mọi ví đều vào tổng thì KHÔNG dựng thẻ "ngoài tổng"', () {
      final g = GoiSoVi.tu([_vi('Tiền mặt', 1000000)]);
      final nhan = g.soLieu.map((e) => e.nhan);
      expect(nhan, isNot(contains('Ví ngoài tổng')));
      expect(nhan, isNot(contains('Không tính vào tổng')),
          reason: 'thẻ "0 đ" là ô trống đội lốt số liệu');
    });

    test('ví CHO PHÉP âm không bị đếm là ví âm', () {
      // Cùng luật với G27: thẻ tín dụng âm là chuyện bình thường, đếm nó vào
      // cảnh báo là đổi một dòng nhiễu lấy một dòng nhiễu khác.
      final g = GoiSoVi.tu([
        _vi('Tiền mặt', 1000000),
        _vi('Thẻ tín dụng', -2000000, choPhepAm: true),
      ]);
      expect(g.soLieu.map((e) => e.nhan), isNot(contains('Ví đang âm')));
    });

    test('ví âm ngoài ý muốn thì có thẻ riêng', () {
      final g = GoiSoVi.tu([
        _vi('Tiền mặt', 1000000),
        _vi('Ví lỗi', -50000),
      ]);
      final s = {for (final x in g.soLieu) x.nhan: x.soTho};
      expect(s['Ví đang âm'], 1);
    });
  });

  group('mẫu câu', () {
    test('có tiền ngoài tổng → câu NÓI RA chỗ tiền ấy', () {
      final g = GoiSoVi.tu([
        _vi('Tiền mặt', 3000000),
        _vi('Quỹ đen', 800000, trongTong: false),
      ]);
      final cau = g.mauCau().cau;
      expect(cau, contains('không cộng vào tổng'));
      expect(g.mauCau().muc, MucNhanXet.binhThuong);
    });

    test('mọi ví vào tổng → câu gọn, không có vế thừa', () {
      final g = GoiSoVi.tu([_vi('Tiền mặt', 3000000)]);
      expect(g.mauCau().cau, isNot(contains('không cộng vào tổng')));
    });

    test('ví âm → mức cảnh báo, và nói trước mọi thứ khác', () {
      final g = GoiSoVi.tu([
        _vi('Tiền mặt', 3000000),
        _vi('Ví lỗi', -50000),
        _vi('Quỹ đen', 800000, trongTong: false),
      ]);
      final nx = g.mauCau();
      expect(nx.muc, MucNhanXet.canhBao);
      expect(nx.cau, startsWith('Có '));
      expect(nx.cau, contains('âm'));
    });
  });

  group('bộ kiểm số', () {
    // ⚠️ Ca BẮT BUỘC của mọi gói số (bẫy 4.1).
    final caTest = <String, List<ViChoGoiSo>>{
      'rỗng': const [],
      'một ví': [_vi('Tiền mặt', 3000000)],
      'có tiền ngoài tổng': [
        _vi('Tiền mặt', 3000000),
        _vi('Quỹ đen', 800000, trongTong: false),
        _vi('Sổ cũ', 300000, status: 'inactive'),
      ],
      'có ví âm': [_vi('Tiền mặt', 3000000), _vi('Ví lỗi', -50000)],
      'tổng bằng 0': [_vi('Quỹ đen', 800000, trongTong: false)],
    };

    for (final e in caTest.entries) {
      test('mẫu câu tự qua bộ kiểm số — ${e.key}', () {
        final g = GoiSoVi.tu(e.value);
        final cau = g.mauCau().cau;
        expect(kiemSo(cau, g), isTrue, reason: cau);
      });
    }
  });
}
