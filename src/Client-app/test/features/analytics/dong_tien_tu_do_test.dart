/// Dòng tiền tự do — A8 #8 (2026-09-15).
///
/// Nguyên văn mục 8 của bảng A8 (`Project.md` dòng 1036): *"Xu hướng của dòng
/// tiền tự do (thu nhập sau khi trả nợ)"*.
///
/// Chỗ dễ hiểu sai nhất nằm ở hai chữ **thu nhập**: `TongThuChi.thu` là **mọi**
/// khoản `type = 'thu'`, nên nó **đã gồm cả tiền đi vay và tiền thu nợ**. Tiền
/// mượn không phải thu nhập, tiền thu hồi vốn cũng không. Lấy nguyên `tong.thu`
/// thì tháng nào người dùng vay tiền, đường này lại **vọt lên** — đúng tháng mà
/// tình hình tài chính của họ xấu đi. Sai kiểu ấy không có exception nào báo.
///
/// Nên luật là: **thu nhập = tổng thu − mọi khoản tiền VÀO thuộc nhóm Vay/nợ**,
/// tức trừ cả `khacVao` chứ không chỉ hai vai đọc được tên. Một khoản vay/nợ
/// tiền vào mà không đoán được vai thì chỉ có thể là *đi vay* hoặc *thu nợ* —
/// không đường nào biến nó thành thu nhập.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/analytics/domain/dong_tien_tu_do.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flowmoney/features/analytics/domain/vai_vay_no.dart';

/// Một điểm của chuỗi thu/chi.
DiemThoiGian _diem(Ky ky, {double thu = 0, double chi = 0}) =>
    DiemThoiGian(ky: ky, tong: TongThuChi(thu: thu, chi: chi));

void main() {
  final t7 = Ky.thang(2026, 7);
  final t8 = Ky.thang(2026, 8);
  final t9 = Ky.thang(2026, 9);

  group('dongTienTuDo — ghép hai chuỗi theo kỳ', () {
    test('không vay nợ gì thì tự do bằng đúng tổng thu', () {
      final ra = dongTienTuDo(
        [_diem(t8, thu: 10000000, chi: 4000000)],
        [DiemVayNo(ky: t8)],
      );

      expect(ra.length, 1);
      expect(ra.single.ky, t8);
      expect(ra.single.thuNhap, 10000000,
          reason: 'kỳ không có khoản vay/nợ nào thì thu nhập là toàn bộ tổng thu');
      expect(ra.single.traNo, 0);
      expect(ra.single.tuDo, 10000000);
    });

    test('trả nợ bị trừ khỏi thu nhập', () {
      final ra = dongTienTuDo(
        [_diem(t8, thu: 10000000)],
        [DiemVayNo(ky: t8, traNo: 3000000)],
      );

      expect(ra.single.thuNhap, 10000000);
      expect(ra.single.traNo, 3000000);
      expect(ra.single.tuDo, 7000000);
    });

    test('tiền ĐI VAY không phải thu nhập — bị trừ khỏi tổng thu', () {
      // 20tr tiền vào, trong đó 5tr là tiền vay mượn. Trả nợ 3tr.
      final ra = dongTienTuDo(
        [_diem(t8, thu: 20000000)],
        [DiemVayNo(ky: t8, diVay: 5000000, traNo: 3000000)],
      );

      expect(ra.single.thuNhap, 15000000,
          reason: 'tiền mượn về không làm người dùng giàu thêm đồng nào');
      expect(ra.single.tuDo, 12000000,
          reason: 'lấy nguyên tong.thu sẽ ra 17tr — tháng đi vay lại trông đẹp lên');
    });

    test('tiền THU NỢ không phải thu nhập — bị trừ khỏi tổng thu', () {
      final ra = dongTienTuDo(
        [_diem(t8, thu: 20000000)],
        [DiemVayNo(ky: t8, thuNo: 8000000)],
      );

      expect(ra.single.thuNhap, 12000000,
          reason: 'thu hồi vốn đã cho vay là tiền cũ quay về, không phải tiền kiếm được');
      expect(ra.single.tuDo, 12000000);
    });

    test('khoản vay/nợ tiền VÀO không đoán được vai cũng bị trừ', () {
      // `khacVao` chỉ có thể là đi vay hoặc thu nợ — không đường nào là thu nhập.
      final ra = dongTienTuDo(
        [_diem(t8, thu: 20000000)],
        [DiemVayNo(ky: t8, khacVao: 2000000)],
      );

      expect(ra.single.thuNhap, 18000000,
          reason: 'bỏ sót ô thứ ba này là chừa một lối cho tiền vay lọt vào thu nhập');
    });

    test('khoản vay/nợ tiền RA (cho vay, khacRa) KHÔNG đụng tới thu nhập', () {
      // Cho vay là tiền đi ra; nó đã nằm ở `tong.chi`, không liên quan vế thu.
      final ra = dongTienTuDo(
        [_diem(t8, thu: 20000000, chi: 9000000)],
        [DiemVayNo(ky: t8, choVay: 6000000, khacRa: 1000000)],
      );

      expect(ra.single.thuNhap, 20000000);
      expect(ra.single.tuDo, 20000000);
    });

    test('trả nợ vượt thu nhập thì tự do ÂM, không kẹp về 0', () {
      final ra = dongTienTuDo(
        [_diem(t8, thu: 4000000)],
        [DiemVayNo(ky: t8, traNo: 6500000)],
      );

      expect(ra.single.tuDo, -2500000,
          reason: 'kẹp về 0 là giấu đúng cái kỳ người dùng cần thấy nhất');
    });

    test('nhiều kỳ giữ nguyên thứ tự cũ-nhất-trước của hai chuỗi nguồn', () {
      final ra = dongTienTuDo(
        [
          _diem(t7, thu: 1000000),
          _diem(t8, thu: 2000000),
          _diem(t9, thu: 3000000),
        ],
        [
          DiemVayNo(ky: t7, traNo: 100000),
          DiemVayNo(ky: t8, traNo: 200000),
          DiemVayNo(ky: t9, traNo: 300000),
        ],
      );

      expect(ra.map((e) => e.ky).toList(), [t7, t8, t9]);
      expect(ra.map((e) => e.tuDo).toList(), [900000, 1800000, 2700000]);
    });

    test('hai chuỗi rỗng ra chuỗi rỗng', () {
      expect(dongTienTuDo(const [], const []), isEmpty);
    });
  });

  group('tieuDeDongTienTuDo — đổi theo đơn vị kỳ', () {
    test('mỗi đơn vị một tiêu đề, kỳ tuỳ chọn rơi về tháng', () {
      // Cùng luật với `tieuDeXuHuong`: chuỗi của kỳ tuỳ chọn cũng lùi theo
      // tháng, nên "6 khoảng 17 ngày" không phải thứ ai đọc được.
      expect(tieuDeDongTienTuDo(DonViKy.tuan), 'Dòng tiền tự do 6 tuần');
      expect(tieuDeDongTienTuDo(DonViKy.thang), 'Dòng tiền tự do 6 tháng');
      expect(tieuDeDongTienTuDo(DonViKy.quy), 'Dòng tiền tự do 6 quý');
      expect(tieuDeDongTienTuDo(DonViKy.nam), 'Dòng tiền tự do 6 năm');
      expect(tieuDeDongTienTuDo(DonViKy.tuyChon), 'Dòng tiền tự do 6 tháng');
    });

    test('số kỳ lấy từ kSoKyXuHuong chứ không viết cứng', () {
      expect(
        tieuDeDongTienTuDo(DonViKy.thang),
        contains('$kSoKyXuHuong'),
        reason: 'đổi kSoKyXuHuong mà tiêu đề vẫn nói "6" là nói dối người đọc',
      );
    });
  });

  group('dongTienTuDo — chốt chặn ghép nhầm kỳ', () {
    test('hai chuỗi lệch độ dài thì NỔ', () {
      expect(
        () => dongTienTuDo(
          [_diem(t8, thu: 1), _diem(t9, thu: 2)],
          [DiemVayNo(ky: t8)],
        ),
        throwsArgumentError,
        reason: 'repository đổi soKy một bên mà quên bên kia thì biểu đồ vẽ sai '
            'kỳ mà không ai biết — thà nổ ngay',
      );
    });

    test('hai chuỗi cùng độ dài nhưng lệch kỳ thì NỔ', () {
      expect(
        () => dongTienTuDo(
          [_diem(t8, thu: 1), _diem(t9, thu: 2)],
          [DiemVayNo(ky: t7), DiemVayNo(ky: t9)],
        ),
        throwsArgumentError,
        reason: 'cùng độ dài không đủ: ghép theo chỉ số mà hai chuỗi lệch một kỳ '
            'là gán số trả nợ của tháng này cho thu nhập của tháng khác',
      );
    });
  });
}
