/// Biểu đồ **thác nước** — cơ cấu dòng tiền của một kỳ (A8 #10, 2026-09-15).
///
/// Câu chuyện nó kể: số dư đầu kỳ → cộng thu → trừ dần từng nhóm chi → số dư
/// cuối kỳ. Mỗi bước là một khối **nổi**, đáy của khối này là đỉnh của khối
/// trước, nên cả biểu đồ đọc được như một bậc thang.
///
/// Thứ đắt nhất ở đây là **phép cân**: nếu `đầu kỳ + thu − Σ nhóm chi` không ra
/// đúng `cuối kỳ` thì bậc thang hở một khe ngay giữa biểu đồ — không exception,
/// không log, chỉ là một hình vẽ sai mà người đọc tưởng là thật.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/analytics/domain/thac_nuoc.dart';

void main() {
  // Số thật đọc trên máy ảo ngày 2026-09-15, tài khoản có dữ liệu:
  // 10.000 + 14.625.000 − 1.045.000 = 13.590.000.
  const dauKy = 10000.0;
  const thu = 14625000.0;
  const cuoiKy = 13590000.0;
  final nhomChi = <({String ten, double soTien})>[
    (ten: 'Chưa phân loại', soTien: 500000),
    (ten: 'Di chuyển', soTien: 305000),
    (ten: 'Mua sắm', soTien: 60000),
    (ten: 'Danh mục đã xoá', soTien: 55000),
    (ten: 'Ăn uống', soTien: 50000),
    (ten: 'Khác', soTien: 75000),
  ];

  List<BuocThacNuoc> dung({
    double dau = dauKy,
    double cuoi = cuoiKy,
    double tongThu = thu,
    List<({String ten, double soTien})>? chi,
  }) =>
      thacNuocCua(
        dauKy: dau,
        cuoiKy: cuoi,
        thu: tongThu,
        nhomChi: chi ?? nhomChi,
      );

  group('các bậc', () {
    test('mở bằng cột mốc đầu kỳ, đóng bằng cột mốc cuối kỳ', () {
      final b = dung();

      expect(b.first.loai, LoaiBuoc.moc);
      expect(b.first.nhan, 'Đầu kỳ');
      expect(b.first.tu, 0, reason: 'cột mốc mọc từ đáy, không phải khối nổi');
      expect(b.first.den, dauKy);

      expect(b.last.loai, LoaiBuoc.moc);
      expect(b.last.nhan, 'Cuối kỳ');
      expect(b.last.tu, 0);
      expect(b.last.den, cuoiKy);
    });

    test('cột thu bắt đầu từ đỉnh cột đầu kỳ', () {
      final b = dung();
      expect(b[1].loai, LoaiBuoc.thu);
      expect(b[1].tu, dauKy);
      expect(b[1].den, dauKy + thu);
    });

    test('mỗi nhóm chi là một khối nổi, đáy nối đúng đỉnh khối trước', () {
      final b = dung();
      // Bỏ hai cột mốc ở hai đầu; phần giữa phải nối liền nhau.
      final giua = b.sublist(1, b.length - 1);
      for (var i = 1; i < giua.length; i++) {
        expect(giua[i].tu, moreOrLessEquals(giua[i - 1].den, epsilon: 0.001),
            reason: 'bậc "${giua[i].nhan}" phải bắt đầu đúng chỗ bậc '
                '"${giua[i - 1].nhan}" kết thúc — hở một khe là biểu đồ nói dối');
      }
    });

    test('nhóm chi đi XUỐNG, nên den nhỏ hơn tu', () {
      final b = dung().where((x) => x.loai == LoaiBuoc.chi);
      expect(b, isNotEmpty);
      for (final x in b) {
        expect(x.den, lessThan(x.tu),
            reason: 'khối chi tụt xuống; đảo chiều là vẽ ngược câu chuyện');
      }
    });

    test('⚠️ PHÉP CÂN: bậc chi cuối cùng kết thúc ĐÚNG ở số dư cuối kỳ', () {
      final b = dung();
      final chiCuoi = b.lastWhere((x) => x.loai == LoaiBuoc.chi);

      expect(chiCuoi.den, moreOrLessEquals(cuoiKy, epsilon: 0.001),
          reason: 'Đây là điều kiện để bậc thang khép kín. Lệch thì cột "Cuối '
              'kỳ" không chạm bậc cuối — một khe hở ngay giữa biểu đồ, không '
              'exception và không một dòng log nào.');
    });

    test('số bậc = 2 cột mốc + 1 cột thu + số nhóm chi', () {
      expect(dung().length, 2 + 1 + nhomChi.length);
    });

    test('giaTri là độ cao khối, luôn không âm', () {
      for (final x in dung()) {
        expect(x.giaTri, greaterThanOrEqualTo(0));
      }
      expect(dung()[1].giaTri, thu);
    });
  });

  group('ca biên', () {
    test('kỳ không có khoản chi nào thì chỉ còn ba bậc', () {
      final b = dung(chi: const [], cuoi: dauKy + thu);
      expect(b.map((x) => x.nhan), ['Đầu kỳ', '+Thu', 'Cuối kỳ']);
      expect(b.any((x) => x.loai == LoaiBuoc.chi), isFalse);
    });

    test('kỳ rỗng hoàn toàn trả danh sách RỖNG, không phải ba cột 0', () {
      // Khối gọi hàm này chỉ vẽ khi có gì để vẽ. Trả ba cột bằng 0 thì biểu đồ
      // hiện ra một hình phẳng, người dùng tưởng app hỏng.
      expect(dung(dau: 0, cuoi: 0, tongThu: 0, chi: const []), isEmpty);
    });

    test('số dư đầu kỳ ÂM vẫn dựng được', () {
      // Ví có thể âm sau một khoản chi vượt số dư; kẹp về 0 là giấu sự thật.
      final b = dung(dau: -50000, tongThu: 100000, chi: const [], cuoi: 50000);
      expect(b.first.den, -50000);
      expect(b[1].tu, -50000);
      expect(b[1].den, 50000);
    });
  });

  group('ranhVuotTrungBinh — vạch TB trên từng cột chi', () {
    // Đường ngang ở giá trị tuyệt đối KHÔNG dùng được cho thác nước: các khối
    // chi nổi ở vùng cao (14.6M → 13.6M) còn mức trung bình là 174K, nằm tít
    // dưới đáy trục nên không cắt cột nào. Mắt so **độ cao** khối, mà đường
    // ngang thì so **vị trí**. Nên mức trung bình vẽ thành một vạch NGAY TRÊN
    // từng cột chi: phần trong mức TB nhạt, phần vượt đậm.
    const tb = 174166.67;

    BuocThacNuoc bacChi({required double tu, required double soTien}) =>
        BuocThacNuoc(
            nhan: 'x', tu: tu, den: tu - soTien, loai: LoaiBuoc.chi);

    test('nhóm vượt TB thì ranh nằm cách ĐỈNH khối đúng một mức TB', () {
      final b = bacChi(tu: 14635000, soTien: 500000);
      expect(ranhVuotTrungBinh(b, tb),
          moreOrLessEquals(14635000 - tb, epsilon: 0.01),
          reason: 'phần nhạt đo từ đỉnh khối xuống, nên ranh = tu − tb');
    });

    test('nhóm KHÔNG vượt TB thì không có ranh', () {
      expect(ranhVuotTrungBinh(bacChi(tu: 100000, soTien: 50000), tb), isNull,
          reason: 'cả khối nằm trong mức trung bình — tô một sắc độ, và vẽ '
              'thêm một vạch ở ngoài khối là bịa ra chỗ không có');
    });

    test('nhóm bằng đúng TB cũng không có ranh', () {
      expect(ranhVuotTrungBinh(bacChi(tu: 500000, soTien: tb), tb), isNull);
    });

    test('bậc mốc và bậc thu KHÔNG có vạch', () {
      final b = dung();
      expect(ranhVuotTrungBinh(b.first, tb), isNull);
      expect(ranhVuotTrungBinh(b[1], tb), isNull,
          reason: 'mức trung bình là của các nhóm CHI; vẽ nó lên cột thu là '
              'so hai đại lượng khác nhau');
    });

    test('trung bình bằng 0 thì không vạch nào cả', () {
      // Kỳ không có nhóm chi nào; chia cho 0 đã chặn ở `trungBinhNhomChi`.
      expect(ranhVuotTrungBinh(bacChi(tu: 100, soTien: 50), 0), isNull);
    });
  });

  group('trungBinhNhomChi', () {
    test('tổng chi chia cho số nhóm', () {
      expect(trungBinhNhomChi(nhomChi),
          moreOrLessEquals(1045000 / 6, epsilon: 0.001));
    });

    test('không nhóm nào thì bằng 0, không chia cho 0', () {
      expect(trungBinhNhomChi(const []), 0);
    });

    test('một nhóm thì trung bình bằng chính nó', () {
      expect(trungBinhNhomChi(const [(ten: 'Ăn uống', soTien: 50000)]), 50000);
    });
  });
}
