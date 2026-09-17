/// Tầng thuần của trang Phân tích.
///
/// Canh chừng điều gì: trang này từng là **số cứng** suốt nhiều tuần — mọi con
/// số là hằng số, kể cả cái tháng đang hiện. Từ nay số nào lên màn hình cũng
/// phải đi qua các hàm dưới đây, và các hàm ấy sai thì sai **im lặng**: một
/// khoản đếm hai lần, một khoản chuyển ví bị coi là chi tiêu, một tháng 31 ngày
/// bị cắt còn 30 — không exception nào cả, chỉ có con số khác đi.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
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

    test('⚠️ số làm tròn ra 0 thì KHÔNG mang dấu trừ', () {
      // Máy ảo bắt được 2026-09-15 ở khối "Dòng tiền tự do": biểu đồ có phần
      // âm nên biên trên tính bằng `san + 3 * buoc`, và sai số dấu phẩy động
      // cho ra một số âm cỡ 1e-16 ngay tại vị trí lẽ ra là 0. Nhãn trục in ra
      // "-0" — một con số không tồn tại.
      //
      // Cùng luật với `CurrencyFormatter.formatCoDau`: số 0 không mang dấu.
      expect(rutGon(-1e-16), '0');
      expect(rutGon(-0.0), '0');
      expect(rutGon(-0.4), '0',
          reason: 'làm tròn ra 0 thì dấu của số gốc không còn nghĩa gì');
      expect(rutGon(-1), '-1',
          reason: 'số âm thật vẫn phải giữ dấu — đừng nuốt cả những số này');
      expect(rutGon(-950000), '-950K');
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

  group('chuoiTheoKy — biểu đồ xu hướng theo thời gian', () {
    test('đủ số tháng, CŨ NHẤT TRƯỚC, tháng cuối là tháng đang xem', () {
      final ds = chuoiTheoKy(const [], ky: Ky.thang(2026, 9));
      expect(ds.length, 6);
      expect(ds.first.ky, Ky.thang(2026, 4));
      expect(ds.last.ky, Ky.thang(2026, 9),
          reason: 'Trục thời gian đọc trái sang phải, nên điểm cuối phải là '
              'kỳ đang xem. `cacKyGanNhat` sắp NGƯỢC LẠI (mới nhất trước) vì '
              'nó phục vụ bộ chọn — dùng nhầm thứ tự ấy là biểu đồ chạy lùi '
              'mà không có lỗi nào báo.');
    });

    test('cuộn qua năm trước khi tháng đang xem ở đầu năm', () {
      final ds = chuoiTheoKy(const [], ky: Ky.thang(2026, 2));
      expect(ds.first.ky, Ky.thang(2025, 9));
      expect(ds[3].ky, Ky.thang(2025, 12),
          reason: 'Lùi từ tháng 2 phải đi qua tháng 12 năm trước, không phải '
              'tháng 0. Tự trừ rồi cộng 12 là chỗ đã sinh lỗi ở nhiều app.');
    });

    test('khoản ngày 29/02 năm nhuận rơi đúng điểm tháng 2', () {
      final ds = chuoiTheoKy(
        [k(ngay: DateTime(2028, 2, 29, 12), soTien: 700000)],
        ky: Ky.thang(2028, 2),
      );
      expect(ds.last.tong.chi, 700000,
          reason: 'Chia trục bằng "mỗi tháng 30 ngày" là đánh rơi ngày 29/02 '
              'của năm nhuận — sai im lặng, cột chỉ thấp đi.');
    });

    test('tháng không có giao dịch vẫn giữ chỗ với số 0', () {
      final ds = chuoiTheoKy(
        [k(ngay: DateTime(2026, 9, 5), soTien: 300000)],
        ky: Ky.thang(2026, 9),
      );
      expect(ds.length, 6);
      expect(ds.take(5).every((d) => d.tong.thu == 0 && d.tong.chi == 0),
          isTrue);
      expect(ds.last.tong.chi, 300000,
          reason: 'Bỏ tháng rỗng khỏi chuỗi là trục thời gian co lại: hai '
              'tháng cách nhau nửa năm sẽ nằm cạnh nhau như liền kề.');
    });

    test('chuyển ví không vào thu lẫn chi của bất kỳ điểm nào', () {
      final ds = chuoiTheoKy(
        [k(ngay: DateTime(2026, 9, 5), soTien: 500000, loai: 'transfer')],
        ky: Ky.thang(2026, 9),
      );
      expect(ds.last.tong.chi, 0);
      expect(ds.last.tong.thu, 0,
          reason: 'Tiền đổi chỗ giữa hai ví không phải thu cũng không phải '
              'chi. Đếm nó là mỗi kỳ trích tự động vào mục tiêu đội đường '
              '"chi" lên — đúng lỗi mục 3.2 GOAL_FEATURE đã sửa một lần.');
    });

    test('khoản lúc 00:00 ngày 1 thuộc đúng một điểm, không đếm hai lần', () {
      final ds = chuoiTheoKy(
        [k(ngay: DateTime(2026, 9, 1), soTien: 200000)],
        ky: Ky.thang(2026, 9),
      );
      expect(ds.last.tong.chi, 200000);
      expect(ds[4].tong.chi, 0,
          reason: 'Biên `to` mở: khoản 00:00 ngày 1 tháng 9 thuộc tháng 9, '
              'không thuộc tháng 8. Đóng biên là nó hiện ở cả hai cột.');
      expect(ds.fold(0.0, (s, d) => s + d.tong.chi), 200000,
          reason: 'Tổng mọi điểm phải bằng đúng số tiền đã ghi — các khoảng '
              'không được chồng lên nhau.');
    });

    // ── Đơn vị khác tháng — thêm 2026-09-15 (P1) ──────────────────────────
    test('chuỗi theo TUẦN có 6 điểm tuần, cũ nhất trước', () {
      final ds = chuoiTheoKy(
        [
          k(ngay: DateTime(2026, 9, 15), soTien: 100000),
          k(ngay: DateTime(2026, 9, 8), soTien: 200000),
        ],
        ky: Ky.tuan(DateTime(2026, 9, 17)),
      );
      expect(ds.length, 6);
      expect(ds.last.ky.from, DateTime(2026, 9, 14),
          reason: 'điểm cuối là tuần đang xem');
      expect(ds.last.tong.chi, 100000);
      expect(ds[4].tong.chi, 200000, reason: 'tuần liền trước');
    });

    test('chuỗi theo QUÝ lùi đúng ba tháng mỗi điểm', () {
      final ds = chuoiTheoKy(const [], ky: Ky.quy(2026, 3));
      expect(ds.length, 6);
      expect(ds.last.ky, Ky.quy(2026, 3));
      expect(ds.first.ky, Ky.quy(2025, 2),
          reason: 'lùi 5 quý từ Q3/2026 là Q2/2025 — phải đi qua mốc năm');
    });

    test('mỗi điểm mang đúng Ky của nó, nhãn trục đọc thẳng từ đó', () {
      final ds = chuoiTheoKy(const [], ky: Ky.thang(2026, 9));
      expect(ds.map((d) => d.ky.nhanTruc).toList(),
          ['T4', 'T5', 'T6', 'T7', 'T8', 'T9'],
          reason: 'trang không phải đoán đơn vị từ hai con số nữa');
    });
  });

  group('chuoiTheoDanhMuc', () {
    KhoanThuChi kd(String? cat, DateTime ngay, double tien, String loai) =>
        KhoanThuChi(
          ngay: ngay,
          soTien: tien,
          loai: loai,
          categoryId: cat,
        );

    test('mỗi danh mục một chuỗi đủ soKy điểm, cũ nhất trước', () {
      final ds = [
        kd('an', DateTime(2026, 7, 10), 1000, 'chi'),
        kd('an', DateTime(2026, 9, 10), 3000, 'chi'),
        kd('luong', DateTime(2026, 9, 5), 9000, 'thu'),
      ];

      final m = chuoiTheoDanhMuc(ds, ky: Ky.thang(2026, 9));

      expect(m.keys.toSet(), {'an', 'luong'});
      expect(m['an']!.length, 6);
      expect(m['an']!.first.ky, Ky.thang(2026, 4),
          reason: 'Cũ nhất trước, như chuoiTheoKy');
      expect(m['an']!.last.ky, Ky.thang(2026, 9));
      expect(m['an']![3].tong.chi, 1000, reason: 'T7 là điểm thứ tư');
      expect(m['an']![5].tong.chi, 3000);
    });

    test('tháng rỗng vẫn là một điểm mang số 0', () {
      final ds = [kd('an', DateTime(2026, 9, 10), 3000, 'chi')];

      final m = chuoiTheoDanhMuc(ds, ky: Ky.thang(2026, 9));

      expect(m['an']!.length, 6);
      expect(m['an']!.take(5).every((d) => d.tong.chi == 0), isTrue,
          reason: 'Bỏ tháng rỗng là trục co lại, hai tháng cách nửa năm hiện '
              'ra như liền kề — bài học của lát 2b');
    });

    test('cho cùng kết quả với chuoiTheoKy lọc tay từng danh mục', () {
      final ds = [
        kd('an', DateTime(2026, 5, 3), 700, 'chi'),
        kd('an', DateTime(2026, 8, 21), 1200, 'chi'),
        kd('di', DateTime(2026, 8, 21), 400, 'chi'),
      ];

      final m = chuoiTheoDanhMuc(ds, ky: Ky.thang(2026, 9));
      final thuCong = chuoiTheoKy(
        ds.where((x) => x.categoryId == 'an').toList(),
        ky: Ky.thang(2026, 9),
      );

      expect(
        m['an']!.map((d) => d.tong.chi).toList(),
        thuCong.map((d) => d.tong.chi).toList(),
        reason: 'Một lượt duyệt phải cho đúng kết quả của phép tính từng danh '
            'mục — nó chỉ nhanh hơn, không được khác',
      );
    });

    test('tháng ngắn: khoản cuối tháng 2 vẫn vào đúng cột', () {
      final ds = [kd('an', DateTime(2026, 2, 28), 500, 'chi')];

      final m = chuoiTheoDanhMuc(ds, ky: Ky.thang(2026, 3), soKy: 3);

      expect(m['an']!.map((d) => d.ky.nhanTruc).toList(), ['T1', 'T2', 'T3']);
      expect(m['an']![1].tong.chi, 500);
    });

    test('năm nhuận: 29/02/2024 nằm đúng tháng 2', () {
      final ds = [kd('an', DateTime(2024, 2, 29), 800, 'chi')];

      final m = chuoiTheoDanhMuc(ds, ky: Ky.thang(2024, 3), soKy: 3);

      expect(m['an']![1].ky, Ky.thang(2024, 2));
      expect(m['an']![1].tong.chi, 800);
    });

    test('cuộn qua năm: tháng 1 lùi về tháng 12 năm trước', () {
      final ds = [kd('an', DateTime(2025, 12, 15), 600, 'chi')];

      final m = chuoiTheoDanhMuc(ds, ky: Ky.thang(2026, 1), soKy: 3);

      expect(m['an']!.map((d) => d.ky).toList(),
          [Ky.thang(2025, 11), Ky.thang(2025, 12), Ky.thang(2026, 1)]);
      expect(m['an']![1].tong.chi, 600);
    });

    test('khoản chuyển ví không tạo ra khoá nào', () {
      final ds = [
        kd('an', DateTime(2026, 9, 10), 1000, 'chi'),
        kd('vi', DateTime(2026, 9, 11), 5000, 'transfer'),
      ];

      final m = chuoiTheoDanhMuc(ds, ky: Ky.thang(2026, 9));

      expect(m.keys.toSet(), {'an'},
          reason: 'Danh mục chỉ có khoản chuyển thì không đáng có chip');
    });

    test('danh mục chỉ có khoản ngoài 6 tháng thì không có khoá', () {
      final ds = [kd('cu', DateTime(2025, 1, 5), 1000, 'chi')];

      expect(chuoiTheoDanhMuc(ds, ky: Ky.thang(2026, 9)), isEmpty,
          reason: 'Dropdown chỉ liệt kê danh mục CÓ phát sinh trong 6 tháng');
    });
  });
}
