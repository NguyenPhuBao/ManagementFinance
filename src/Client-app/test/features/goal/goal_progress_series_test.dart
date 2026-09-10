/// Chuỗi tiến độ mục tiêu theo thời gian — thêm 2026-09-09.
///
/// Vì sao tầng thuần: phần khó của khối biểu đồ **không** phải phần vẽ. Phần
/// khó là chuỗi tích luỹ phải kết thúc đúng bằng con số mà vòng phần trăm ngay
/// phía trên đang hiện — và lịch sử giao dịch **không bảo đảm** cộng lại bằng
/// `currentAmount` (mục 3.4 `docs/GOAL_FEATURE.md`: tiến độ cố ý không tự hoà
/// giải). Cộng xuôi từ 0 là hai con số khác nhau cho cùng một thứ, cạnh nhau
/// trên một màn hình, và **không lỗi nào báo**.
///
/// Đường kế hoạch mượn nguyên định nghĩa của `GoalEntity.isBehindSchedule`:
/// tuyến tính theo ngày từ `startDate` tới `targetDate`. Đây là chỗ dễ đẻ ra
/// luật thứ hai nhất — thẻ "Cấu hình" đã nói "Chậm so với nhịp" bằng luật ấy
/// rồi, nên hai chỗ nói ngược nhau là lỗi người dùng đọc ra ngay.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/goal/domain/goal_history_filter.dart';
import 'package:flowmoney/features/goal/domain/goal_progress_series.dart';

void main() {
  KhoanTichLuy k(DateTime ngay, double soTien, {bool rut = false}) =>
      KhoanTichLuy(
        ngay: ngay,
        soTien: soTien,
        laKhoanRut: rut,
        laTuDong: false,
      );

  group('chuoiTienDo — chuỗi tích luỹ', () {
    test('không có khoản nào thì không có chuỗi', () {
      final chuoi = chuoiTienDo(
        khoan: const [],
        soTienHienTai: 0,
        soTienDich: 40000000,
        ngayBatDau: DateTime(2026, 3, 1),
        hanChot: DateTime(2026, 12, 1),
        now: DateTime(2026, 9, 9),
      );

      expect(
        chuoi,
        isNull,
        reason: 'Không có khoản nào thì không có gì để vẽ. Trả về một chuỗi '
            'rỗng thay vì null buộc mọi nơi gọi phải tự kiểm .isEmpty, và '
            'chia cho 0 khi tính thang đo.',
      );
    });

    test('điểm cuối của đường thực tế bằng đúng số tiền hiện tại', () {
      final chuoi = chuoiTienDo(
        khoan: [k(DateTime(2026, 4, 1), 5000000)],
        soTienHienTai: 5000000,
        soTienDich: 40000000,
        ngayBatDau: DateTime(2026, 3, 1),
        hanChot: DateTime(2026, 12, 1),
        now: DateTime(2026, 9, 9),
      )!;

      expect(
        chuoi.thucTe.last.soTien,
        5000000,
        reason: 'Điểm cuối là con số mà vòng phần trăm phía trên đang hiện. '
            'Lệch một đồng là hai câu trả lời khác nhau trên cùng màn hình.',
      );
    });

    test('cộng dồn theo thứ tự thời gian tăng dần dù đầu vào xếp mới nhất trước',
        () {
      // Đầu vào theo đúng thứ tự truy vấn thật: `date desc`.
      final chuoi = chuoiTienDo(
        khoan: [
          k(DateTime(2026, 6, 1), 3000000),
          k(DateTime(2026, 5, 1), 2000000),
          k(DateTime(2026, 4, 1), 5000000),
        ],
        soTienHienTai: 10000000,
        soTienDich: 40000000,
        ngayBatDau: DateTime(2026, 3, 1),
        hanChot: DateTime(2026, 12, 1),
        now: DateTime(2026, 6, 1),
      )!;

      final theoNgay = {
        for (final d in chuoi.thucTe) d.ngay: d.soTien,
      };

      expect(
        theoNgay[DateTime(2026, 4, 1)],
        5000000,
        reason: 'Truy vấn trả mới nhất trước; không đảo lại thì chuỗi chạy lùi '
            'mà không lỗi nào báo.',
      );
      expect(theoNgay[DateTime(2026, 5, 1)], 7000000);
      expect(theoNgay[DateTime(2026, 6, 1)], 10000000);
    });

    test('lịch sử không cộng đủ số tiền hiện tại thì điểm gốc khác 0', () {
      // Lịch sử chỉ có 4 triệu nhưng mục tiêu đang giữ 10 triệu — hàng cũ kéo
      // về từ máy khác không mang liên kết mục tiêu, hoặc khoản nạp đầu ghi
      // trước khi app biết nối. Phần chênh phải lộ ra ở ĐẦU chuỗi.
      final chuoi = chuoiTienDo(
        khoan: [k(DateTime(2026, 5, 1), 4000000)],
        soTienHienTai: 10000000,
        soTienDich: 40000000,
        ngayBatDau: DateTime(2026, 3, 1),
        hanChot: DateTime(2026, 12, 1),
        now: DateTime(2026, 5, 1),
      )!;

      expect(
        chuoi.thucTe.first.soTien,
        6000000,
        reason: 'Đi LÙI từ số tiền hiện tại: 10tr - 4tr = 6tr có sẵn trước '
            'khoản đầu tiên. Cộng xuôi từ 0 thì điểm cuối ra 4tr, cãi nhau '
            'với vòng phần trăm đang hiện 10tr.',
      );
      expect(chuoi.thucTe.last.soTien, 10000000);
    });

    test('lịch sử NHIỀU hơn số tiền hiện tại thì chuỗi không đi xuống dưới 0',
        () {
      // Số thật đo trên máy ảo 2026-09-09, mục tiêu "MuaXe" của tài khoản 10:
      // bảng lịch sử nói **11 khoản · đã gửi 2.201.000 đ** trong khi mục tiêu
      // đang giữ **1.101.000 đ**. Phép đi lùi cho điểm gốc −1.100.000 đ.
      //
      // Không kẹp thì đường vẽ xuống dưới 0 — vừa nói dối (mục tiêu chưa bao
      // giờ giữ số tiền âm) vừa rơi ra ngoài dải `minY: 0` của biểu đồ.
      final chuoi = chuoiTienDo(
        khoan: [
          for (var i = 0; i < 11; i++)
            k(DateTime(2026, 9, 9).subtract(Duration(days: i)), 200091),
        ],
        soTienHienTai: 1101000,
        soTienDich: 2000000,
        ngayBatDau: DateTime(2026, 9, 1),
        hanChot: DateTime(2028, 4, 27),
        now: DateTime(2026, 9, 9),
      )!;

      expect(
        chuoi.thucTe.map((d) => d.soTien),
        everyElement(greaterThanOrEqualTo(0)),
        reason: 'Điểm cuối vẫn phải bằng số tiền hiện tại, nên phần dư của '
            'lịch sử chỉ có chỗ đi là xuống dưới 0. Kẹp ở 0 đọc ra "chưa có '
            'dữ liệu mạch lạc tới đó" — gần sự thật hơn hẳn "mục tiêu từng âm '
            'một triệu".',
      );
      expect(
        chuoi.thucTe.last.soTien,
        1101000,
        reason: 'Phép kẹp KHÔNG được đụng vào điểm cuối: đó là chỗ neo vào '
            'vòng phần trăm.',
      );
    });

    test('khoản rút kéo chuỗi đi xuống', () {
      final chuoi = chuoiTienDo(
        khoan: [
          k(DateTime(2026, 6, 1), 2000000, rut: true),
          k(DateTime(2026, 5, 1), 5000000),
        ],
        soTienHienTai: 3000000,
        soTienDich: 40000000,
        ngayBatDau: DateTime(2026, 3, 1),
        hanChot: DateTime(2026, 12, 1),
        now: DateTime(2026, 6, 1),
      )!;

      final theoNgay = {
        for (final d in chuoi.thucTe) d.ngay: d.soTien,
      };

      expect(
        theoNgay[DateTime(2026, 5, 1)],
        5000000,
        reason: 'Khoản rút mang dấu âm. Cộng tất cả như nhau thì một lần rút '
            'trông y như một lần nạp — đường đi lên trong khi tiền đi ra.',
      );
      expect(theoNgay[DateTime(2026, 6, 1)], 3000000);
    });

    test('đường thực tế kéo phẳng tới hôm nay sau khoản cuối', () {
      final chuoi = chuoiTienDo(
        khoan: [k(DateTime(2026, 5, 1), 5000000)],
        soTienHienTai: 5000000,
        soTienDich: 40000000,
        ngayBatDau: DateTime(2026, 3, 1),
        hanChot: DateTime(2026, 12, 1),
        now: DateTime(2026, 9, 9),
      )!;

      expect(
        chuoi.thucTe.last.ngay,
        DateTime(2026, 9, 9),
        reason: 'Dừng đường ở khoản cuối thì một mục tiêu đứng im bốn tháng '
            'trông y hệt một mục tiêu chỉ mới thiếu dữ liệu. Đoạn phẳng nói '
            'rõ: tiền vẫn ở đó, và không có gì thêm vào.',
      );
      expect(chuoi.thucTe.last.soTien, 5000000);
    });
  });

  group('chuoiTienDo — đường kế hoạch', () {
    test('kế hoạch là đường thẳng từ ngày bắt đầu tới hạn chót', () {
      final chuoi = chuoiTienDo(
        khoan: [k(DateTime(2026, 5, 1), 5000000)],
        soTienHienTai: 5000000,
        soTienDich: 40000000,
        ngayBatDau: DateTime(2026, 3, 1),
        hanChot: DateTime(2026, 12, 1),
        now: DateTime(2026, 9, 9),
      )!;

      expect(
        chuoi.keHoach.map((d) => (d.ngay, d.soTien)).toList(),
        [
          (DateTime(2026, 3, 1), 0.0),
          (DateTime(2026, 12, 1), 40000000.0),
        ],
        reason: 'Mượn nguyên định nghĩa của GoalEntity.isBehindSchedule — '
            'tuyến tính theo ngày từ startDate tới targetDate. Thẻ "Cấu hình" '
            'đã nói "Chậm so với nhịp" bằng luật ấy; một đường kế hoạch dựng '
            'theo luật khác là hai câu trả lời ngược nhau trên một trang.',
      );
    });

    test('không có ngày bắt đầu thì không có đường kế hoạch', () {
      final chuoi = chuoiTienDo(
        khoan: [k(DateTime(2026, 5, 1), 5000000)],
        soTienHienTai: 5000000,
        soTienDich: 40000000,
        ngayBatDau: null,
        hanChot: DateTime(2026, 12, 1),
        now: DateTime(2026, 9, 9),
      )!;

      expect(
        chuoi.keHoach,
        isEmpty,
        reason: 'Cùng kỷ luật với isBehindSchedule: không đủ căn cứ thì im '
            'lặng chứ không đoán mốc bắt đầu. Nhưng đường THỰC TẾ vẫn vẽ — '
            'giấu cả khối thì mất luôn thứ app biết chắc.',
      );
      expect(chuoi.thucTe, isNotEmpty);
    });
  });

  group('chuoiTienDo — biên trục', () {
    test('trục trải từ ngày bắt đầu tới hạn chót', () {
      final chuoi = chuoiTienDo(
        khoan: [k(DateTime(2026, 5, 1), 5000000)],
        soTienHienTai: 5000000,
        soTienDich: 40000000,
        ngayBatDau: DateTime(2026, 3, 1),
        hanChot: DateTime(2026, 12, 1),
        now: DateTime(2026, 9, 9),
      )!;

      expect(chuoi.tuNgay, DateTime(2026, 3, 1));
      expect(
        chuoi.denNgay,
        DateTime(2026, 12, 1),
        reason: 'Trục phải chạy hết tới hạn chót chứ không dừng ở hôm nay: '
            'khoảng trống bên phải chính là quãng đường còn phải đi.',
      );
    });

    test('quá hạn mà chưa đạt thì trục kéo tới hôm nay', () {
      final chuoi = chuoiTienDo(
        khoan: [k(DateTime(2026, 5, 1), 5000000)],
        soTienHienTai: 5000000,
        soTienDich: 40000000,
        ngayBatDau: DateTime(2026, 3, 1),
        hanChot: DateTime(2026, 7, 1),
        now: DateTime(2026, 9, 9),
      )!;

      expect(
        chuoi.denNgay,
        DateTime(2026, 9, 9),
        reason: 'Cắt trục ở hạn chót thì điểm hôm nay rơi ra ngoài vùng vẽ và '
            'biến mất — đúng lúc người dùng cần nhìn nhất.',
      );
    });

    test('trục không bao giờ rộng 0 ngày', () {
      // Tạo mục tiêu, nạp tiền và tới hạn trong cùng một ngày. Hiếm, nhưng
      // trục rộng 0 là chia cho 0 ở mọi phép quy đổi ngày sang toạ độ.
      final chuoi = chuoiTienDo(
        khoan: [k(DateTime(2026, 9, 9), 5000000)],
        soTienHienTai: 5000000,
        soTienDich: 40000000,
        ngayBatDau: DateTime(2026, 9, 9),
        hanChot: DateTime(2026, 9, 9),
        now: DateTime(2026, 9, 9),
      )!;

      expect(chuoi.denNgay.isAfter(chuoi.tuNgay), isTrue);
    });

    test('trần trục dọc phủ cả số tiền đích lẫn đỉnh thực tế', () {
      // Nạp vượt mục tiêu được phép (mục 3.8): app nhắc chứ không chặn.
      final chuoi = chuoiTienDo(
        khoan: [k(DateTime(2026, 5, 1), 50000000)],
        soTienHienTai: 50000000,
        soTienDich: 40000000,
        ngayBatDau: DateTime(2026, 3, 1),
        hanChot: DateTime(2026, 12, 1),
        now: DateTime(2026, 9, 9),
      )!;

      expect(
        chuoi.dinhY,
        greaterThanOrEqualTo(50000000),
        reason: 'Lấy trần bằng đúng số tiền đích thì phần vượt bị cắt cụt — '
            'đường phẳng ở mép trên, không đọc ra là đã vượt bao nhiêu.',
      );
      expect(chuoi.dinhY, greaterThanOrEqualTo(40000000));
    });

    test('mục tiêu 0 đồng vẫn có trần dương', () {
      final chuoi = chuoiTienDo(
        khoan: [k(DateTime(2026, 5, 1), 0)],
        soTienHienTai: 0,
        soTienDich: 0,
        ngayBatDau: DateTime(2026, 3, 1),
        hanChot: DateTime(2026, 12, 1),
        now: DateTime(2026, 9, 9),
      )!;

      expect(
        chuoi.dinhY,
        greaterThan(0),
        reason: 'Trần 0 là chia cho 0 ở mọi phép tính thang đo phía sau.',
      );
    });
  });

  group('hienNhanTruc — chống nhãn trục chồng nhau', () {
    // Dải 0..1000; nhãn cách biên dưới 12% dải (tức 120) thì đâm vào nhãn biên.
    bool hien(double v) => hienNhanTruc(v: v, min: 0, max: 1000);

    test('hai đầu dải luôn có nhãn', () {
      expect(hien(0), isTrue);
      expect(
        hien(1000),
        isTrue,
        reason: 'Hai nhãn biên là mốc đầu và mốc cuối của cả quãng đường — bỏ '
            'chúng thì trục hết nói được nó trải từ đâu tới đâu.',
      );
    });

    test('mốc quá sát biên thì bỏ, vì nhãn biên đã chiếm chỗ ấy', () {
      expect(
        hien(950),
        isFalse,
        reason: 'Đo trên máy ảo 2026-09-09, mục tiêu "MuaDT": fl_chart vẽ nhãn '
            'ở CẢ hai biên **cộng thêm** các mốc theo `interval`, nên mốc '
            '08/27 in đè lên nhãn biên 09/27 thành một mớ không đọc được.',
      );
      expect(hien(50), isFalse);
    });

    test('mốc giữa dải thì hiện', () {
      expect(hien(500), isTrue);
      expect(hien(250), isTrue);
    });

    test('mốc ngoài dải thì bỏ', () {
      // fl_chart hỏi cả những mốc ngoài dải khi vẽ lưới.
      expect(hien(-100), isFalse);
      expect(hien(1200), isFalse);
    });
  });

  group('nhipSoVoiKeHoach — dòng chú thích dưới biểu đồ', () {
    // 01/03/2026 → 01/12/2026 là 275 ngày; 09/09/2026 là ngày thứ 192.
    // Mốc kế hoạch tại hôm ấy: 40tr × 192/275 ≈ 27,93tr.
    ({NhipKeHoach nhip, double chenhLech})? nhip(double hienTai) =>
        nhipSoVoiKeHoach(
          soTienHienTai: hienTai,
          soTienDich: 40000000,
          ngayBatDau: DateTime(2026, 3, 1),
          hanChot: DateTime(2026, 12, 1),
          now: DateTime(2026, 9, 9),
        );

    test('trong biên dung sai thì báo đang đúng nhịp', () {
      expect(
        nhip(28000000)!.nhip,
        NhipKeHoach.dungNhip,
        reason: 'Cùng biên dung sai 5% với GoalEntity.isBehindSchedule. Không '
            'có biên thì một mục tiêu lệch nửa phần trăm bị gọi là chậm, '
            'trong khi thẻ "Cấu hình" ngay bên trên nói "Đang đúng nhịp".',
      );
    });

    test('dưới biên thì báo chậm, kèm đúng số tiền còn thiếu', () {
      final n = nhip(20000000)!;

      expect(n.nhip, NhipKeHoach.cham);
      expect(
        n.chenhLech,
        closeTo(-7927272, 1),
        reason: 'Chênh lệch là tiền, không phải phần trăm: người dùng nạp bù '
            'bằng tiền chứ không bằng điểm phần trăm.',
      );
    });

    test('trên biên thì báo vượt kế hoạch', () {
      expect(nhip(36000000)!.nhip, NhipKeHoach.vuot);
    });

    test('không có ngày bắt đầu thì im lặng', () {
      expect(
        nhipSoVoiKeHoach(
          soTienHienTai: 20000000,
          soTienDich: 40000000,
          ngayBatDau: null,
          hanChot: DateTime(2026, 12, 1),
          now: DateTime(2026, 9, 9),
        ),
        isNull,
        reason: 'Không có mốc bắt đầu thì không có kế hoạch để so. Đoán mốc '
            'là bịa ra một lời phán xét về thói quen của người dùng.',
      );
    });

    test('chưa tới ngày bắt đầu thì im lặng', () {
      expect(
        nhipSoVoiKeHoach(
          soTienHienTai: 0,
          soTienDich: 40000000,
          ngayBatDau: DateTime(2026, 10, 1),
          hanChot: DateTime(2026, 12, 1),
          now: DateTime(2026, 9, 9),
        ),
        isNull,
        reason: 'Kỳ chưa mở mà báo "chậm hơn kế hoạch 0đ" là trách người dùng '
            'vì chưa làm một việc chưa tới hạn làm.',
      );
    });

    test('kỳ dài 0 ngày thì im lặng chứ không chia cho 0', () {
      expect(
        nhipSoVoiKeHoach(
          soTienHienTai: 1000000,
          soTienDich: 40000000,
          ngayBatDau: DateTime(2026, 9, 9),
          hanChot: DateTime(2026, 9, 9),
          now: DateTime(2026, 9, 9),
        ),
        isNull,
      );
    });

    test('quá hạn thì mốc kế hoạch là trọn số tiền đích', () {
      final n = nhipSoVoiKeHoach(
        soTienHienTai: 30000000,
        soTienDich: 40000000,
        ngayBatDau: DateTime(2026, 3, 1),
        hanChot: DateTime(2026, 7, 1),
        now: DateTime(2026, 9, 9),
      )!;

      expect(n.nhip, NhipKeHoach.cham);
      expect(
        n.chenhLech,
        closeTo(-10000000, 0.01),
        reason: 'Quá hạn thì kế hoạch đã đòi đủ 40tr. Ngoại suy tiếp theo tỉ '
            'lệ ngày cho ra một mốc LỚN HƠN mục tiêu, tức chê người dùng vì '
            'không vượt đích.',
      );
    });

    test('năm nhuận: tháng 2 có 29 ngày, không phải 28', () {
      // 01/02/2024 → 01/03/2024 là 29 ngày (2024 nhuận). Hôm nay là ngày thứ
      // 14, tức 14/29 ≈ 48,3% chứ không phải 14/28 = 50%.
      final n = nhipSoVoiKeHoach(
        soTienHienTai: 0,
        soTienDich: 29000000,
        ngayBatDau: DateTime(2024, 2, 1),
        hanChot: DateTime(2024, 3, 1),
        now: DateTime(2024, 2, 15),
      )!;

      expect(
        n.chenhLech,
        closeTo(-14000000, 1),
        reason: 'Đếm ngày thật giữa hai mốc. Giả định tháng 2 có 28 ngày cho '
            'ra 14,5tr — sai im lặng, và chỉ sai vào những năm nhuận.',
      );
    });

    test('tháng ngắn: mốc bắt đầu ngày 31 vẫn đếm đúng số ngày đã qua', () {
      // 31/01/2026 → 31/03/2026 là 59 ngày; 28/02/2026 là ngày thứ 28.
      final n = nhipSoVoiKeHoach(
        soTienHienTai: 0,
        soTienDich: 59000000,
        ngayBatDau: DateTime(2026, 1, 31),
        hanChot: DateTime(2026, 3, 31),
        now: DateTime(2026, 2, 28),
      )!;

      expect(
        n.chenhLech,
        closeTo(-28000000, 1),
        reason: 'Đếm bằng hiệu hai ngày, không bằng phép cộng tháng. Cộng '
            'tháng thì 31/01 + 1 tháng rơi vào 03/03 và mọi mốc lệch đi.',
      );
    });
  });
}
