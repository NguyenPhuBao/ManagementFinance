import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
import 'package:flowmoney/features/analytics/domain/tong_tai_san.dart';

/// Một ví bình thường: tính vào tổng, đang hoạt động, chưa xoá.
ViHienTai _vi(String id, double soDu) => (
      id: id,
      soDu: soDu,
      includeInTotal: true,
      status: 'active',
      isDeleted: false,
    );

BienDongVi _thu(String vi, double soTien, DateTime ngay) =>
    (ngay: ngay, soTien: soTien, loai: 'thu', viNguon: vi, viDich: null);

BienDongVi _chi(String vi, double soTien, DateTime ngay) =>
    (ngay: ngay, soTien: soTien, loai: 'chi', viNguon: vi, viDich: null);

BienDongVi _chuyen(String tu, String? den, double soTien, DateTime ngay) =>
    (ngay: ngay, soTien: soTien, loai: 'transfer', viNguon: tu, viDich: den);

void main() {
  // Kỳ đang xem cố định để mọi ca đọc được bằng mắt: tháng 9/2026.
  final ky = Ky.thang(2026, 9);

  group('tongTaiSanCua — khung chuỗi', () {
    test('trả đúng sáu điểm, cũ nhất trước', () {
      final chuoi = tongTaiSanCua(
        const [],
        [_vi('v1', 1000)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(chuoi.length, kSoKyXuHuong,
          reason: 'Cùng số kỳ với khối Xu hướng và Dòng tiền tự do — ba đường '
              'nằm cạnh nhau phải chung một trục hoành.');
      expect(chuoi.first.ky, lui(ky, kSoKyXuHuong - 1));
      expect(chuoi.last.ky, ky,
          reason: 'Điểm cuối là kỳ đang xem; thứ tự cũ nhất trước.');
    });

    test('không giao dịch nào thì đường phẳng đúng số dư hiện tại', () {
      final chuoi = tongTaiSanCua(
        const [],
        [_vi('v1', 1000), _vi('v2', 500)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(chuoi.map((d) => d.tong).toSet(), {1500.0});
    });
  });

  group('tongTaiSanCua — điểm cuối phải khớp Trang chủ', () {
    test('điểm cuối bằng đúng tổng số dư các ví tính vào tổng', () {
      final chuoi = tongTaiSanCua(
        [_thu('v1', 300, DateTime(2026, 9, 5))],
        [_vi('v1', 1000), _vi('v2', 500)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(chuoi.last.tong, 1500,
          reason: 'Đây là mốc để người dùng tin cả đường: con số cuối cùng '
              'phải bằng đúng tổng tài sản họ thấy ở Trang chủ.');
    });

    test('⚠️ giao dịch ghi ngày TƯƠNG LAI không được trừ khỏi điểm cuối', () {
      // Dữ liệu thật đã có sẵn hai hàng như thế (đo 2026-09-16 trên tài khoản
      // 10: 2026-10-10 và 2026-11-10). `wallets.balance` cộng MỌI hàng bất kể
      // ngày, nên khoản hẹn 10/10 đã nằm trong số dư Trang chủ hôm nay. Trừ nó
      // ra là biểu đồ và Trang chủ nói hai con số khác nhau.
      //
      // ⚠️ Kẹp mốc về `now` một mình KHÔNG cứu được ca này — hàng 10/10 vẫn
      // nằm sau mốc nên vẫn bị trừ. Bản chỉ có phép kẹp đỏ đúng ở đây.
      final chuoi = tongTaiSanCua(
        [_thu('v1', 700, DateTime(2026, 10, 10))],
        [_vi('v1', 1000)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(chuoi.last.tong, 1000);
      expect(chuoi.first.tong, 1000,
          reason: 'Hàng ngày tương lai phải đứng yên ở MỌI điểm, không riêng '
              'điểm cuối: nó nằm trong `balance` suốt, nên trừ nó ở các điểm '
              'quá khứ là hạ cả đoạn đầu đường xuống 700 một cách im lặng.');
      expect(chuoi.last.moc, DateTime(2026, 9, 17),
          reason: 'Mốc của kỳ đang diễn ra vẫn phải kẹp về `now`, không phải '
              '`ky.to` nằm ở tương lai.');
    });

    test('mốc của kỳ đã qua vẫn là ky.to, không bị kẹp', () {
      final chuoi = tongTaiSanCua(
        const [],
        [_vi('v1', 1000)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(chuoi.first.moc, lui(ky, kSoKyXuHuong - 1).to);
    });
  });

  group('tongTaiSanCua — suy ngược', () {
    test('khoản thu trong kỳ làm điểm trước đó thấp hơn đúng số ấy', () {
      final chuoi = tongTaiSanCua(
        [_thu('v1', 300, DateTime(2026, 9, 5))],
        [_vi('v1', 1000)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(chuoi.last.tong, 1000);
      expect(chuoi[kSoKyXuHuong - 2].tong, 700,
          reason: 'Suy ngược: trước khi nhận 300 thì tài sản là 1000 − 300.');
    });

    test('khoản chi trong kỳ làm điểm trước đó CAO hơn đúng số ấy', () {
      final chuoi = tongTaiSanCua(
        [_chi('v1', 300, DateTime(2026, 9, 5))],
        [_vi('v1', 1000)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(chuoi[kSoKyXuHuong - 2].tong, 1300);
    });

    test('tài sản được phép âm', () {
      final chuoi = tongTaiSanCua(
        [_thu('v1', 500, DateTime(2026, 9, 5))],
        [_vi('v1', 100)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(chuoi[kSoKyXuHuong - 2].tong, -400,
          reason: 'Kẹp về 0 là giấu đúng lúc người dùng cần thấy nhất — cùng '
              'lý lẽ với đường dòng tiền tự do.');
    });

    test('biến động đúng tại mốc được tính là SAU mốc', () {
      // Biên `to` mở: hàng lúc 00:00 ngày đầu kỳ sau thuộc kỳ sau. Suy ngược
      // phải dùng cùng biên ấy, nếu không một khoản nằm đúng ranh giới bị đếm
      // ở cả hai bên hoặc không bên nào.
      final mocCu = lui(ky, 1).to;
      final chuoi = tongTaiSanCua(
        [_thu('v1', 200, mocCu)],
        [_vi('v1', 1000)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(chuoi[kSoKyXuHuong - 2].tong, 800);
    });
  });

  group('tongTaiSanCua — khoản chuyển', () {
    test('chuyển giữa hai ví CÙNG tính vào tổng thì tài sản không đổi', () {
      final chuoi = tongTaiSanCua(
        [_chuyen('v1', 'v2', 400, DateTime(2026, 9, 5))],
        [_vi('v1', 600), _vi('v2', 400)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(chuoi.map((d) => d.tong).toSet(), {1000.0},
          reason: 'Tiền đổi chỗ, không rời khỏi tài sản.');
    });

    test('⚠️ chuyển sang ví bị LOẠI khỏi tổng thì tài sản CÓ giảm', () {
      // Đây là lý do phép tính phải chạy theo từng ví rồi mới lọc, chứ không
      // lọc rồi cộng: nửa kia của khoản chuyển nằm ngoài tổng.
      final chuoi = tongTaiSanCua(
        [_chuyen('v1', 'vNgoai', 400, DateTime(2026, 9, 5))],
        [
          _vi('v1', 600),
          (
            id: 'vNgoai',
            soDu: 400.0,
            includeInTotal: false,
            status: 'active',
            isDeleted: false
          ),
        ],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(chuoi.last.tong, 600);
      expect(chuoi[kSoKyXuHuong - 2].tong, 1000,
          reason: 'Trước khi chuyển ra ngoài, 400 ấy vẫn nằm trong tổng.');
    });

    test('khoản chuyển thiếu ví đích bị bỏ qua', () {
      // Cùng luật với `tongTheoVi` và `_applyBalances`: không có ví đích thì
      // không biết tiền đi đâu, nên không đụng vào số dư bên nào cả.
      final chuoi = tongTaiSanCua(
        [_chuyen('v1', null, 400, DateTime(2026, 9, 5))],
        [_vi('v1', 1000)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(chuoi.map((d) => d.tong).toSet(), {1000.0});
    });
  });

  group('tongTaiSanCua — ví nào được cộng', () {
    test('ví bị loại khỏi tổng, ví lưu trữ và ví đã xoá đều không cộng', () {
      final chuoi = tongTaiSanCua(
        const [],
        [
          _vi('v1', 1000),
          (
            id: 'v2',
            soDu: 900.0,
            includeInTotal: false,
            status: 'active',
            isDeleted: false
          ),
          (
            id: 'v3',
            soDu: 800.0,
            includeInTotal: true,
            status: 'inactive',
            isDeleted: false
          ),
          (
            id: 'v4',
            soDu: 700.0,
            includeInTotal: true,
            status: 'active',
            isDeleted: true
          ),
        ],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(chuoi.last.tong, 1000,
          reason: 'Luật có một định nghĩa duy nhất ở `viTinhVaoTong` — G42 đã '
              'cho thấy một bản chép tay quên vế `isDeleted` phình con số lên '
              'đúng số dư ví người dùng đã xoá.');
    });

    test('biến động của ví không tính vào tổng không ảnh hưởng đường', () {
      final chuoi = tongTaiSanCua(
        [_thu('vNgoai', 5000, DateTime(2026, 9, 5))],
        [
          _vi('v1', 1000),
          (
            id: 'vNgoai',
            soDu: 5000.0,
            includeInTotal: false,
            status: 'active',
            isDeleted: false
          ),
        ],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(chuoi.map((d) => d.tong).toSet(), {1000.0});
    });
  });

  group('tongTaiSanCua — lịch', () {
    test('sáu tháng lùi qua mốc năm vẫn đúng kỳ', () {
      final chuoi = tongTaiSanCua(
        const [],
        [_vi('v1', 1)],
        ky: Ky.thang(2026, 2),
        now: DateTime(2026, 2, 15),
      );

      expect(chuoi.first.ky, Ky.thang(2025, 9));
      expect(chuoi.map((d) => d.ky.nhanTruc).toList(),
          ['T9', 'T10', 'T11', 'T12', 'T1', 'T2']);
    });

    test('tháng 2 năm nhuận: mốc cuối kỳ là 01/03', () {
      final chuoi = tongTaiSanCua(
        const [],
        [_vi('v1', 1)],
        ky: Ky.thang(2024, 2),
        now: DateTime(2024, 6, 1),
      );

      expect(chuoi.last.moc, DateTime(2024, 3, 1),
          reason: 'Kỳ đã qua nên không kẹp; biên `to` mở của tháng 2/2024 là '
              '01/03 dù tháng ấy có 29 ngày.');
    });

    test('lùi sáu kỳ theo quý vẫn ra sáu nhãn khác nhau', () {
      final chuoi = tongTaiSanCua(
        const [],
        [_vi('v1', 1)],
        ky: Ky.quy(2026, 3),
        now: DateTime(2026, 9, 17),
      );

      final nhan = chuoi.map((d) => d.ky.nhanTruc).toList();
      expect(nhan.toSet().length, kSoKyXuHuong,
          reason: 'Sáu quý trải qua một năm rưỡi nên `Q3` xuất hiện hai lần '
              'nếu nhãn không mang năm — cùng họ G39.');
    });
  });

  group('thayDoiTaiSan', () {
    test('chênh lệch giữa điểm đầu và điểm cuối', () {
      final chuoi = tongTaiSanCua(
        [_thu('v1', 300, DateTime(2026, 9, 5))],
        [_vi('v1', 1000)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(thayDoiTaiSan(chuoi, giaoDichDauTien: DateTime(2026, 1, 1)), 300);
    });

    test('⚠️ null khi chuỗi chạm vùng chưa có giao dịch nào', () {
      // Điểm đầu của chuỗi rơi vào quãng trước giao dịch đầu tiên, nên nó là
      // số 0 "chưa biết" chứ không phải 0 "không có gì". Lấy hiệu với nó là
      // in ra nguyên cả tài sản như thể vừa kiếm được trong sáu kỳ.
      final chuoi = tongTaiSanCua(
        [_thu('v1', 300, DateTime(2026, 9, 5))],
        [_vi('v1', 1000)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(thayDoiTaiSan(chuoi, giaoDichDauTien: DateTime(2026, 9, 2)), null);
    });

    test('null khi chưa có giao dịch nào', () {
      final chuoi = tongTaiSanCua(
        const [],
        [_vi('v1', 1000)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(thayDoiTaiSan(chuoi, giaoDichDauTien: null), null);
    });
  });

  group('mocThieuDuLieu', () {
    test('trả ngày giao dịch đầu tiên khi chuỗi chạm vùng chưa biết', () {
      final chuoi = tongTaiSanCua(
        [_thu('v1', 300, DateTime(2026, 9, 5))],
        [_vi('v1', 1000)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(mocThieuDuLieu(chuoi, giaoDichDauTien: DateTime(2026, 9, 2)),
          DateTime(2026, 9, 2));
    });

    test('null khi cả chuỗi nằm sau giao dịch đầu tiên', () {
      final chuoi = tongTaiSanCua(
        const [],
        [_vi('v1', 1000)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(mocThieuDuLieu(chuoi, giaoDichDauTien: DateTime(2025, 1, 1)), null);
    });

    test('null khi chưa có giao dịch nào', () {
      final chuoi = tongTaiSanCua(
        const [],
        [_vi('v1', 1000)],
        ky: ky,
        now: DateTime(2026, 9, 17),
      );

      expect(mocThieuDuLieu(chuoi, giaoDichDauTien: null), null);
    });
  });

  group('tieuDeTongTaiSan', () {
    test('đổi theo đơn vị đang xem', () {
      expect(tieuDeTongTaiSan(DonViKy.tuan), 'Tổng tài sản 6 tuần gần đây');
      expect(tieuDeTongTaiSan(DonViKy.thang), 'Tổng tài sản 6 tháng gần đây');
      expect(tieuDeTongTaiSan(DonViKy.quy), 'Tổng tài sản 6 quý gần đây');
      expect(tieuDeTongTaiSan(DonViKy.nam), 'Tổng tài sản 6 năm gần đây');
    });

    test('kỳ tuỳ chọn rơi về "tháng", cùng khuôn tieuDeXuHuong', () {
      expect(tieuDeTongTaiSan(DonViKy.tuyChon), 'Tổng tài sản 6 tháng gần đây');
    });

    test('cumSoKy là nguồn chung của tiêu đề và câu "trong …"', () {
      for (final dv in DonViKy.values) {
        expect(tieuDeTongTaiSan(dv), contains(cumSoKy(dv)),
            reason: 'Hai chỗ nói cùng một quãng thời gian thì phải đọc chung '
                'một hàm, nếu không lần đổi kSoKyXuHuong đầu tiên sẽ để lại '
                'hai con số khác nhau cạnh nhau.');
      }
    });
  });
}
