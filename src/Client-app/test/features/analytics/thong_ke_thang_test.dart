/// Tầng thuần của trang Phân tích.
///
/// Canh chừng điều gì: trang này từng là **số cứng** suốt nhiều tuần — mọi con
/// số là hằng số, kể cả cái tháng đang hiện. Từ nay số nào lên màn hình cũng
/// phải đi qua các hàm dưới đây, và các hàm ấy sai thì sai **im lặng**: một
/// khoản đếm hai lần, một khoản chuyển ví bị coi là chi tiêu, một tháng 31 ngày
/// bị cắt còn 30 — không exception nào cả, chỉ có con số khác đi.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';

void main() {
  KhoanThuChi k({
    required DateTime ngay,
    double soTien = 100000,
    String loai = 'chi',
    String? danhMuc = 'an_uong',
  }) =>
      KhoanThuChi(ngay: ngay, soTien: soTien, loai: loai, categoryId: danhMuc);

  group('bienThang — [from, to)', () {
    test('tháng thường: từ 00:00 ngày 1 tới 00:00 ngày 1 tháng sau', () {
      final b = bienThang(2026, 9);
      expect(b.from, DateTime(2026, 9, 1));
      expect(b.to, DateTime(2026, 10, 1));
    });

    test('tháng 12 sang năm sau', () {
      final b = bienThang(2026, 12);
      expect(b.to, DateTime(2027, 1, 1),
          reason: 'Cộng 1 vào tháng mà không cuộn năm là biên `to` rơi về '
              'tháng 13 — Dart tự chuẩn hoá, nhưng đừng trông chờ vào đó mà '
              'không có test.');
    });

    test('tháng 2 NĂM NHUẬN có ngày 29', () {
      final b = bienThang(2028, 2);
      expect(b.to, DateTime(2028, 3, 1));
      final t = tongThuChi([k(ngay: DateTime(2028, 2, 29, 12))],
          from: b.from, to: b.to);
      expect(t.chi, 100000,
          reason: 'Khoản ngày 29/02 của năm nhuận phải nằm trong tháng 2. Lấy '
              'biên bằng "28 ngày" là mất nó.');
    });

    test('tháng 2 năm thường kết thúc ngày 28', () {
      final b = bienThang(2027, 2);
      expect(b.to, DateTime(2027, 3, 1));
      expect(b.to.difference(b.from).inDays, 28);
    });
  });

  group('tongThuChi', () {
    final from = DateTime(2026, 9, 1);
    final to = DateTime(2026, 10, 1);

    test('cộng riêng thu và chi', () {
      final t = tongThuChi([
        k(ngay: DateTime(2026, 9, 3), soTien: 5000000, loai: 'thu'),
        k(ngay: DateTime(2026, 9, 4), soTien: 200000),
        k(ngay: DateTime(2026, 9, 5), soTien: 300000),
      ], from: from, to: to);
      expect(t.thu, 5000000);
      expect(t.chi, 500000);
      expect(t.conLai, 4500000);
    });

    test('khoản chuyển ví (transfer) KHÔNG phải thu, KHÔNG phải chi', () {
      final t = tongThuChi([
        k(ngay: DateTime(2026, 9, 3), soTien: 1000000, loai: 'transfer'),
      ], from: from, to: to);
      expect(t.thu, 0);
      expect(t.chi, 0,
          reason: 'Nạp mục tiêu và chuyển giữa hai ví là tiền đổi chỗ, không '
              'phải tiền ra khỏi túi. Đếm nó là chi tiêu thì mỗi lần trích tự '
              'động vào mục tiêu là "Tổng chi" tháng tăng lên — đúng lỗi mà '
              'mục 3.2 GOAL_FEATURE.md đã sửa ở phần thống kê trước đây.');
    });

    test('biên TO là biên mở: khoản lúc 00:00 ngày 1 tháng sau không tính', () {
      final t = tongThuChi([
        k(ngay: DateTime(2026, 10, 1)), // đúng mốc to
        k(ngay: DateTime(2026, 9, 1)), // đúng mốc from
      ], from: from, to: to);
      expect(t.chi, 100000,
          reason: 'Cùng bài học với ngân sách: bộ chọn ngày trả về 00:00, nên '
              'khoản ghi ngày đầu kỳ sau nằm đúng mốc `to` của kỳ trước — đóng '
              'biên là đếm nó ở CẢ HAI tháng.');
    });

    test('rỗng ra số 0, không ném', () {
      final t = tongThuChi(const [], from: from, to: to);
      expect(t.thu, 0);
      expect(t.chi, 0);
    });
  });

  group('phanTramSoVoi — so với tháng trước', () {
    test('tăng', () {
      expect(phanTramSoVoi(6500000, 5000000), closeTo(30, 0.001));
    });

    test('giảm', () {
      expect(phanTramSoVoi(5000000, 6500000), closeTo(-23.077, 0.01));
    });

    test('tháng trước bằng 0 thì KHÔNG có phần trăm', () {
      expect(phanTramSoVoi(6500000, 0), isNull,
          reason: 'Chia cho 0 ra vô cực, và "tăng ∞%" hay "tăng 100%" đều là '
              'số bịa. Không có gì để so thì nói không có, đừng đoán.');
      expect(phanTramSoVoi(0, 0), isNull);
    });
  });

  group('chiTheoDanhMuc', () {
    final from = DateTime(2026, 9, 1);
    final to = DateTime(2026, 10, 1);

    test('gom theo danh mục, sắp giảm dần, tỉ lệ cộng lại bằng 1', () {
      final ds = chiTheoDanhMuc([
        k(ngay: DateTime(2026, 9, 2), soTien: 100000, danhMuc: 'a'),
        k(ngay: DateTime(2026, 9, 3), soTien: 300000, danhMuc: 'b'),
        k(ngay: DateTime(2026, 9, 4), soTien: 200000, danhMuc: 'a'),
      ], from: from, to: to);

      expect(ds.map((x) => x.categoryId), ['a', 'b'],
          reason: 'a = 100k + 200k = 300k, b = 300k → HOÀ. Không dựa vào thứ '
              'tự tới trước (b tới trước a) mà sắp ổn định theo id tăng dần, '
              'để hai lần vẽ không đảo chỗ nhau. Bản test đầu ghi nhầm '
              '[b, a] — nó cãi với chính lời giải thích của nó.');
      expect(ds.map((x) => x.soTien), [300000, 300000]);
      expect(ds.fold(0.0, (s, x) => s + x.tiLe), closeTo(1.0, 1e-9));
    });

    test('chỉ tính khoản CHI trong tháng', () {
      final ds = chiTheoDanhMuc([
        k(ngay: DateTime(2026, 9, 2), loai: 'thu', danhMuc: 'a'),
        k(ngay: DateTime(2026, 9, 2), loai: 'transfer', danhMuc: 'a'),
        k(ngay: DateTime(2026, 8, 2), danhMuc: 'a'),
        k(ngay: DateTime(2026, 9, 2), danhMuc: 'b'),
      ], from: from, to: to);
      expect(ds.map((x) => x.categoryId), ['b']);
    });

    test('khoản không có danh mục vẫn được gom, categoryId = null', () {
      final ds = chiTheoDanhMuc([
        k(ngay: DateTime(2026, 9, 2), danhMuc: null),
        k(ngay: DateTime(2026, 9, 3), danhMuc: null),
      ], from: from, to: to);
      expect(ds.single.categoryId, isNull);
      expect(ds.single.soTien, 200000,
          reason: 'Bỏ rơi khoản chưa phân loại là tổng của các lát nhỏ hơn '
              'tổng chi trên thẻ phía trên — hai con số cãi nhau trên cùng '
              'một màn hình.');
    });

    test('không có chi thì danh sách rỗng, không chia cho 0', () {
      expect(chiTheoDanhMuc(const [], from: from, to: to), isEmpty);
    });
  });

  group('rutGon — số ở tâm donut', () {
    test('triệu lấy một chữ số lẻ, bỏ ".0"', () {
      expect(rutGon(6500000), '6.5M');
      expect(rutGon(6000000), '6M');
      expect(rutGon(1250000), '1.3M',
          reason: 'Tâm donut chỉ có chỗ cho một chữ số lẻ. Làm tròn chứ không '
              'cắt: 1,25 triệu mà hiện "1.2M" là bớt của người ta 50 nghìn.');
    });

    test('nghìn và tỷ', () {
      expect(rutGon(950000), '950K');
      expect(rutGon(12000), '12K');
      expect(rutGon(1500000000), '1.5B');
    });

    test('dưới một nghìn hiện nguyên', () {
      expect(rutGon(0), '0');
      expect(rutGon(999), '999');
    });
  });

  group('cacThangGanNhat — bộ chọn tháng', () {
    test('12 tháng, mới nhất trước, cuộn qua năm trước', () {
      final ds = cacThangGanNhat(DateTime(2026, 9, 8));
      expect(ds.length, 12);
      expect(ds.first, (nam: 2026, thang: 9));
      expect(ds[8], (nam: 2026, thang: 1));
      expect(ds[9], (nam: 2025, thang: 12),
          reason: 'Lùi từ tháng 1 phải sang tháng 12 năm trước, không phải '
              'tháng 0 hay tháng -1 — Dart chuẩn hoá được, nhưng có test thì '
              'mới dám tin.');
      expect(ds.last, (nam: 2025, thang: 10));
    });

    test('tháng 1 lùi 11 tháng về tháng 2 năm trước', () {
      final ds = cacThangGanNhat(DateTime(2027, 1, 15));
      expect(ds.last, (nam: 2026, thang: 2));
    });
  });

  group('topVaKhac — lát cho donut', () {
    List<ChiTheoDanhMuc> sau(List<double> soTien) {
      final tong = soTien.fold(0.0, (s, x) => s + x);
      return [
        for (var i = 0; i < soTien.length; i++)
          ChiTheoDanhMuc(
            categoryId: 'c$i',
            soTien: soTien[i],
            tiLe: soTien[i] / tong,
          ),
      ];
    }

    test('nhiều hơn 4 thì 4 lát đầu + một lát "Khác" gom phần còn lại', () {
      final lat = topVaKhac(sau([500, 400, 300, 200, 60, 40]));
      expect(lat.length, 5);
      expect(lat.take(4).map((x) => x.categoryId), ['c0', 'c1', 'c2', 'c3']);
      expect(lat.last.laKhac, isTrue);
      expect(lat.last.soTien, 100);
      expect(lat.fold(0.0, (s, x) => s + x.tiLe), closeTo(1.0, 1e-9),
          reason: 'Lát "Khác" mang đúng phần tỉ lệ còn lại; thiếu nó là vòng '
              'donut hở một khoảng trông như lỗi vẽ.');
    });

    test('đúng 4 hoặc ít hơn thì không có lát "Khác"', () {
      expect(topVaKhac(sau([1, 2, 3, 4])).any((x) => x.laKhac), isFalse);
      expect(topVaKhac(sau([1])).length, 1);
    });

    test('5 danh mục vẫn gom cái thứ 5 thành "Khác" chứ không hiện 5 lát', () {
      final lat = topVaKhac(sau([5, 4, 3, 2, 1]));
      expect(lat.length, 5);
      expect(lat.last.laKhac, isTrue,
          reason: 'Chú giải của thiết kế có đúng bốn ô. Lát thứ năm hiện tên '
              'thật thì chú giải thiếu một ô, hiện "Khác" thì nhất quán.');
    });
  });

  group('chuoiTheoThang — biểu đồ xu hướng theo thời gian', () {
    test('đủ số tháng, CŨ NHẤT TRƯỚC, tháng cuối là tháng đang xem', () {
      final ds = chuoiTheoThang(const [], nam: 2026, thang: 9);
      expect(ds.length, 6);
      expect((ds.first.nam, ds.first.thang), (2026, 4));
      expect((ds.last.nam, ds.last.thang), (2026, 9),
          reason: 'Trục thời gian đọc trái sang phải, nên điểm cuối phải là '
              'tháng đang xem. `cacThangGanNhat` sắp NGƯỢC LẠI (mới nhất '
              'trước) vì nó phục vụ bộ chọn tháng — dùng nhầm thứ tự ấy là '
              'biểu đồ chạy lùi mà không có lỗi nào báo.');
    });

    test('cuộn qua năm trước khi tháng đang xem ở đầu năm', () {
      final ds = chuoiTheoThang(const [], nam: 2026, thang: 2);
      expect((ds.first.nam, ds.first.thang), (2025, 9));
      expect((ds[3].nam, ds[3].thang), (2025, 12),
          reason: 'Lùi từ tháng 2 phải đi qua tháng 12 năm trước, không phải '
              'tháng 0. Tự trừ rồi cộng 12 là chỗ đã sinh lỗi ở nhiều app.');
    });

    test('khoản ngày 29/02 năm nhuận rơi đúng điểm tháng 2', () {
      final ds = chuoiTheoThang(
        [k(ngay: DateTime(2028, 2, 29, 12), soTien: 700000)],
        nam: 2028,
        thang: 2,
      );
      expect(ds.last.tong.chi, 700000,
          reason: 'Chia trục bằng "mỗi tháng 30 ngày" là đánh rơi ngày 29/02 '
              'của năm nhuận — sai im lặng, cột chỉ thấp đi.');
    });

    test('tháng không có giao dịch vẫn giữ chỗ với số 0', () {
      final ds = chuoiTheoThang(
        [k(ngay: DateTime(2026, 9, 5), soTien: 300000)],
        nam: 2026,
        thang: 9,
      );
      expect(ds.length, 6);
      expect(ds.take(5).every((d) => d.tong.thu == 0 && d.tong.chi == 0),
          isTrue);
      expect(ds.last.tong.chi, 300000,
          reason: 'Bỏ tháng rỗng khỏi chuỗi là trục thời gian co lại: hai '
              'tháng cách nhau nửa năm sẽ nằm cạnh nhau như liền kề.');
    });

    test('chuyển ví không vào thu lẫn chi của bất kỳ điểm nào', () {
      final ds = chuoiTheoThang(
        [k(ngay: DateTime(2026, 9, 5), soTien: 500000, loai: 'transfer')],
        nam: 2026,
        thang: 9,
      );
      expect(ds.last.tong.chi, 0);
      expect(ds.last.tong.thu, 0,
          reason: 'Tiền đổi chỗ giữa hai ví không phải thu cũng không phải '
              'chi. Đếm nó là mỗi kỳ trích tự động vào mục tiêu đội đường '
              '"chi" lên — đúng lỗi mục 3.2 GOAL_FEATURE đã sửa một lần.');
    });

    test('khoản lúc 00:00 ngày 1 thuộc đúng một điểm, không đếm hai lần', () {
      final ds = chuoiTheoThang(
        [k(ngay: DateTime(2026, 9, 1), soTien: 200000)],
        nam: 2026,
        thang: 9,
      );
      expect(ds.last.tong.chi, 200000);
      expect(ds[4].tong.chi, 0,
          reason: 'Biên `to` mở: khoản 00:00 ngày 1 tháng 9 thuộc tháng 9, '
              'không thuộc tháng 8. Đóng biên là nó hiện ở cả hai cột.');
      expect(ds.fold(0.0, (s, d) => s + d.tong.chi), 200000,
          reason: 'Tổng mọi điểm phải bằng đúng số tiền đã ghi — các khoảng '
              'không được chồng lên nhau.');
    });
  });
}
