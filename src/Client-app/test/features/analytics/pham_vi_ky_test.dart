/// Mô hình `Ky` — phạm vi thời gian của trang Phân tích (P1, 2026-09-15).
///
/// Trang này vốn chỉ xem được theo **tháng**. `Ky` là chỗ duy nhất định nghĩa
/// một kỳ, và mọi tầng bên trên nói bằng nó.
///
/// Hai thứ đắt nhất ở đây, cả hai đều hỏng **im lặng** nếu sai:
///  1. **Biên `to` MỞ.** Lấy biên đóng là đếm khoản 00:00 ngày đầu kỳ sau vào kỳ
///     này — không exception, chỉ là một con số lớn hơn thực tế.
///  2. **Lùi kỳ phải theo đơn vị lịch**, không trừ số ngày. Tháng 3 lùi một
///     tháng ra tháng 2, không phải "31 ngày trước".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';

void main() {
  group('biên của từng đơn vị', () {
    test('tháng ngắn và năm nhuận', () {
      expect(
        Ky.thang(2024, 2).to,
        DateTime(2024, 3, 1),
        reason: 'tháng 2 năm nhuận hết ngày 29, không phải 28',
      );
      expect(
        Ky.thang(2026, 12).to,
        DateTime(2027, 1, 1),
        reason: 'tháng 12 tự cuộn sang năm sau nhờ DateTime',
      );
    });

    test('quý trọn ba tháng', () {
      final q = Ky.quy(2026, 3);
      expect(q.from, DateTime(2026, 7, 1));
      expect(q.to, DateTime(2026, 10, 1));
      expect(Ky.quy(2026, 4).to, DateTime(2027, 1, 1));
      expect(Ky.quy(2026, 1).from, DateTime(2026, 1, 1));
    });

    test('năm trọn 12 tháng', () {
      expect(Ky.nam(2026).from, DateTime(2026, 1, 1));
      expect(Ky.nam(2026).to, DateTime(2027, 1, 1));
    });

    test('tuần mượn nguyên bienTuan', () {
      // 17/09/2026 là thứ Năm.
      final k = Ky.tuan(DateTime(2026, 9, 17));
      expect(k.from, DateTime(2026, 9, 14));
      expect(k.to, DateTime(2026, 9, 21));
    });

    test('tuỳ chọn giữ nguyên hai mốc đưa vào', () {
      final k =
          Ky.tuyChon(from: DateTime(2026, 9, 3), to: DateTime(2026, 9, 18));
      expect(k.from, DateTime(2026, 9, 3));
      expect(k.to, DateTime(2026, 9, 18));
    });
  });

  group('nhãn', () {
    test('ba dạng nhãn của một kỳ tháng', () {
      final k = Ky.thang(2026, 9);
      expect(k.nhan, 'T9 2026');
      expect(k.nhanNgan, 'T9 2026');
      expect(k.nhanTruc, 'T9');
    });

    test('nhãn đầy đủ của tuần kèm khoảng ngày', () {
      expect(
        Ky.tuan(DateTime(2026, 9, 17)).nhan,
        'Tuần 38 (14/09 – 20/09)',
        reason: 'ngày cuối là to - 1 ngày, vì biên to MỞ',
      );
    });

    test('số tuần lấy theo ISO, không phải chia cho 7', () {
      // 31/12/2025 thuộc 2026-W01 — năm ISO khác năm dương lịch. Phép chia
      // ngây thơ cho ra tuần 53.
      expect(Ky.tuan(DateTime(2025, 12, 31)).nhanNgan, 'Tuần 1');
    });

    test('nhãn kỳ tuỳ chọn hiện ngày cuối NẰM TRONG kỳ', () {
      final k =
          Ky.tuyChon(from: DateTime(2026, 9, 3), to: DateTime(2026, 9, 18));
      expect(
        k.nhan,
        '03/09 – 17/09',
        reason: 'hiện thẳng to là nhận có dữ liệu của một ngày không hề đếm',
      );
    });

    test('nhãn trục của từng đơn vị', () {
      expect(
        Ky.tuan(DateTime(2026, 9, 17)).nhanTruc,
        '14/09',
        reason: '"T38" đụng nghĩa với "T9" của tháng trên cùng một trục',
      );
      expect(Ky.quy(2026, 3).nhanTruc, 'Q3/26',
          reason: 'sáu quý trải qua một năm rưỡi — "Q3" một mình xuất hiện HAI '
              'lần trên cùng một trục');
      expect(Ky.nam(2026).nhanTruc, '2026');
    });

    test('nhãn trục của sáu kỳ liên tiếp phải ĐÔI MỘT KHÁC NHAU', () {
      // Hai cột khác nhau mang đúng một nhãn là lỗi đọc nhầm, và nó im lặng.
      for (final ky in [
        Ky.tuan(DateTime(2026, 9, 17)),
        Ky.thang(2026, 9),
        Ky.quy(2026, 3),
        Ky.nam(2026),
      ]) {
        final nhan = [
          for (var i = kSoKyXuHuong - 1; i >= 0; i--) lui(ky, i).nhanTruc,
        ];
        expect(nhan.toSet().length, kSoKyXuHuong,
            reason: 'đơn vị ${ky.donVi.name} có nhãn trùng: $nhan');
      }
    });

    test('tenKyNay null cho kỳ tuỳ chọn', () {
      expect(Ky.thang(2026, 9).tenKyNay, 'Tháng này');
      expect(Ky.tuan(DateTime(2026, 9, 17)).tenKyNay, 'Tuần này');
      expect(Ky.quy(2026, 3).tenKyNay, 'Quý này');
      expect(Ky.nam(2026).tenKyNay, 'Năm nay');
      expect(
        Ky.tuyChon(from: DateTime(2026, 9, 3), to: DateTime(2026, 9, 18))
            .tenKyNay,
        isNull,
        reason: 'một khoảng tuỳ ý không phải "kỳ này" của đơn vị nào',
      );
    });
  });

  group('chua', () {
    test('biên to là MỞ', () {
      final k = Ky.thang(2026, 9);
      expect(k.chua(DateTime(2026, 9, 1)), isTrue);
      expect(k.chua(DateTime(2026, 9, 30, 23, 59, 59)), isTrue);
      expect(
        k.chua(DateTime(2026, 10, 1)),
        isFalse,
        reason: '00:00 ngày đầu tháng sau đã thuộc kỳ sau',
      );
      expect(k.chua(DateTime(2026, 8, 31, 23, 59, 59)), isFalse);
    });
  });

  group('cacKyGanNhat', () {
    test('đúng số lượng cho từng đơn vị', () {
      final now = DateTime(2026, 9, 17);
      expect(cacKyGanNhat(now, DonViKy.tuan).length, 12);
      expect(cacKyGanNhat(now, DonViKy.thang).length, 12);
      expect(cacKyGanNhat(now, DonViKy.quy).length, 8);
      expect(cacKyGanNhat(now, DonViKy.nam).length, 5);
    });

    test('mới nhất trước, và phần tử đầu là kỳ chứa hôm nay', () {
      final now = DateTime(2026, 9, 17);
      final ds = cacKyGanNhat(now, DonViKy.thang);
      expect(ds.first.chua(now), isTrue);
      expect(ds[1].nhanNgan, 'T8 2026');
      expect(ds[11].nhanNgan, 'T10 2025', reason: 'lùi 11 tháng thì qua năm');
    });

    test('danh sách quý lùi đúng ba tháng mỗi bước', () {
      final ds = cacKyGanNhat(DateTime(2026, 9, 17), DonViKy.quy);
      expect(ds.first.nhanNgan, 'Q3 2026');
      expect(ds[1].nhanNgan, 'Q2 2026');
      expect(ds[3].nhanNgan, 'Q4 2025');
    });

    test('kỳ tuỳ chọn không có danh sách dựng sẵn', () {
      expect(
        cacKyGanNhat(DateTime(2026, 9, 17), DonViKy.tuyChon),
        isEmpty,
        reason: 'khoảng tuỳ ý do người dùng nhập, không liệt kê được',
      );
    });
  });

  group('lui', () {
    test('lùi theo đúng đơn vị, kể cả qua mốc năm', () {
      expect(lui(Ky.thang(2026, 2), 3).nhanNgan, 'T11 2025');
      expect(lui(Ky.quy(2026, 1), 1).nhanNgan, 'Q4 2025');
      expect(lui(Ky.nam(2026), 2).nhanNgan, '2024');
      expect(lui(Ky.tuan(DateTime(2026, 9, 17)), 1).from, DateTime(2026, 9, 7));
    });

    test('lùi 0 kỳ là chính nó', () {
      final k = Ky.thang(2026, 9);
      expect(lui(k, 0), k);
    });

    test('lùi từ tháng 31 ngày không rơi sang tháng khác', () {
      // Bản sai có chủ ý dùng subtract(Duration(days: 30)) rơi vào 01/03.
      expect(lui(Ky.thang(2026, 3), 1).from, DateTime(2026, 2, 1));
      expect(lui(Ky.thang(2026, 3), 1).to, DateTime(2026, 3, 1));
    });

    test('lùi giữ nguyên đơn vị', () {
      expect(lui(Ky.quy(2026, 3), 2).donVi, DonViKy.quy);
      expect(lui(Ky.tuan(DateTime(2026, 9, 17)), 2).donVi, DonViKy.tuan);
    });

    test('kỳ tuỳ chọn lùi đúng độ dài của nó', () {
      final k =
          Ky.tuyChon(from: DateTime(2026, 9, 11), to: DateTime(2026, 9, 18));
      expect(lui(k, 1).from, DateTime(2026, 9, 4));
      expect(lui(k, 1).to, DateTime(2026, 9, 11));
    });
  });

  group('khoangKyTruoc', () {
    test('trọn tháng thì lùi theo THÁNG, không trừ số ngày', () {
      final k = Ky.thang(2026, 9);
      final t = khoangKyTruoc(from: k.from, to: k.to);
      expect(t.from, DateTime(2026, 8, 1));
      expect(
        t.to,
        DateTime(2026, 9, 1),
        reason: 'tháng 9 dài 30 ngày; trừ 30 ngày ra 02/08–01/09, lệch một ngày',
      );
    });

    test('quý lùi ba tháng, năm lùi mười hai tháng', () {
      final q3 = Ky.quy(2026, 3);
      expect(khoangKyTruoc(from: q3.from, to: q3.to).from, DateTime(2026, 4, 1));
      final n = Ky.nam(2026);
      expect(khoangKyTruoc(from: n.from, to: n.to).from, DateTime(2025, 1, 1));
    });

    test('tuần lùi đúng bảy ngày', () {
      final k = Ky.tuan(DateTime(2026, 9, 17));
      final t = khoangKyTruoc(from: k.from, to: k.to);
      expect(t.from, DateTime(2026, 9, 7));
      expect(t.to, DateTime(2026, 9, 14));
    });
  });

  group('nhanOChon — nhãn ô trên header', () {
    final moc = DateTime(2026, 9, 17);

    test('kỳ chứa hôm nay thì có tiền tố "… này"', () {
      expect(nhanOChon(Ky.thang(2026, 9), moc), 'Tháng này (T9 2026)');
      expect(nhanOChon(Ky.tuan(moc), moc), 'Tuần này (Tuần 38)');
      expect(nhanOChon(Ky.nam(2026), moc), 'Năm nay (2026)');
    });

    test('kỳ đã qua thì hiện tên trần', () {
      expect(nhanOChon(Ky.thang(2026, 8), moc), 'T8 2026',
          reason: 'giữ "Tháng này" cho một tháng đã qua là nói dối về thứ '
              'đang hiện trên màn hình');
      expect(nhanOChon(Ky.quy(2026, 1), moc), 'Q1 2026');
    });

    test('⚠️ nhãn quý KHÔNG được dài hơn nhãn tháng', () {
      // Ô header chỉ vừa đúng chừng ấy chữ. "Tháng này (T9 2026)" là chuỗi dài
      // nhất từng được kiểm trên máy thật và nó vừa khít — nên nhãn nào dài
      // hơn nó là **chắc chắn cụt**. "Quý này (Quý 3 2026)" dài hơn đúng MỘT
      // ký tự, và máy ảo hiện ra "Quý này (Quý 3 20…", mất cả năm.
      //
      // Đây là phép canh ở tầng thuần thay cho phép đo bề rộng ở widget test:
      // font "Ahem" của bộ test rộng gấp đôi ngoài đời (bẫy 4.4
      // `ANALYTICS_FEATURE.md`) nên ở 411dp chuỗi nào cũng cụt, và một ca test
      // đo bề rộng sẽ đỏ cả với nhãn tháng vốn không sao.
      final thang = nhanOChon(Ky.thang(2026, 9), moc);
      final quy = nhanOChon(Ky.quy(2026, 3), moc);

      expect(quy, 'Quý này (Q3 2026)',
          reason: '`Q3` là đúng cách viết mà trục biểu đồ đã dùng (`Q3/26`), '
              'nên rút gọn ở đây không đẻ ra quy ước thứ hai');
      expect(quy.length, lessThanOrEqualTo(thang.length),
          reason: 'Nhãn tháng là mốc đã được máy thật chứng minh là vừa. Bất '
              'kỳ nhãn nào dài hơn nó đều bị cắt, và người dùng mất phần đuôi '
              '— chính là con số năm.');
    });

    test('kỳ tuỳ chọn không bao giờ mang dạng "… này"', () {
      final k =
          Ky.tuyChon(from: DateTime(2026, 9, 3), to: DateTime(2026, 9, 30));
      expect(k.chua(moc), isTrue, reason: 'khoảng này có chứa hôm nay');
      expect(nhanOChon(k, moc), '03/09 – 29/09');
    });
  });

  // ── `nhanRong` — nhãn cho chỗ KHÔNG chật ───────────────────────────────────
  //
  // Canh chừng điều gì: `nhanOChon` sinh ra cho **ô header** của trang Phân
  // tích, chỗ đã tràn 53px một lần, nên khi kỳ không chứa hôm nay nó rơi về
  // `nhanNgan` — "Tuần 37" trần, không kèm khoảng ngày.
  //
  // Chỗ **rộng** thì cần ngược lại. Nghiệm thu máy ảo 2026-09-18 bắt được: nút
  // chọn kỳ của trang Xuất báo cáo (chiếm trọn chiều ngang) hiện "Tuần 37"
  // trong khi dòng người dùng vừa chạm trong bộ chọn nói "Tuần 37 (07/09 –
  // 13/09)" — hai cách gọi tên cho cùng một kỳ, và cái ngắn hơn thì **không
  // cho biết đó là khoảng nào**. Bộ test không thấy vì cả hai chuỗi đều "hợp
  // lý".
  group('nhanRong — nhãn cho chỗ rộng (nút, dòng danh sách)', () {
    final moc = DateTime(2026, 9, 18, 12);

    test('kỳ CHỨA hôm nay: mang tiền tố "… này", giống hệt nhanOChon', () {
      final k = Ky.thang(2026, 9);
      expect(nhanRong(k, moc), 'Tháng này (T9 2026)');
      expect(nhanRong(k, moc), nhanOChon(k, moc),
          reason: 'Hai hàm chỉ được khác nhau ở nhánh KHÔNG chứa hôm nay.');
    });

    test('kỳ ĐÃ QUA: giữ khoảng ngày, khác nhanOChon', () {
      final k = Ky.tuan(DateTime(2026, 9, 8));
      expect(nhanRong(k, moc), 'Tuần 37 (07/09 – 13/09)');
      expect(nhanOChon(k, moc), 'Tuần 37',
          reason: 'Ghi lại chính chỗ lệch mà máy ảo bắt được: ô header hẹp thì '
              'rơi về nhãn ngắn, còn nút rộng thì không được mất khoảng ngày.');
    });

    test('kỳ tháng đã qua thì nhãn đầy đủ vốn đã bằng nhãn ngắn', () {
      final k = Ky.thang(2026, 7);
      expect(nhanRong(k, moc), 'T7 2026',
          reason: 'Chỉ tuần và khoảng tuỳ chọn mới có phần trong ngoặc, nên ba '
              'đơn vị còn lại không dài thêm chút nào.');
    });
  });

  group('nhanKyTruoc — câu "so với …" ở thẻ tổng', () {
    test('cùng năm thì bỏ năm cho thẻ đỡ chật', () {
      expect(nhanKyTruoc(Ky.thang(2026, 9)), 'T8');
      expect(nhanKyTruoc(Ky.quy(2026, 3)), 'Quý 2');
    });

    test('kỳ trước rơi sang năm khác thì GIỮ năm', () {
      expect(nhanKyTruoc(Ky.thang(2026, 1)), 'T12 2025',
          reason: 'đang xem T1 2026 mà đọc "so với T12" thì không biết T12 nào');
      expect(nhanKyTruoc(Ky.quy(2026, 1)), 'Q4 2025');
    });

    test('kỳ năm luôn giữ số năm', () {
      expect(nhanKyTruoc(Ky.nam(2026)), '2025');
    });

    test('tuần và khoảng tuỳ chọn dùng nhãn ngắn sẵn có', () {
      expect(nhanKyTruoc(Ky.tuan(DateTime(2026, 9, 17))), 'Tuần 37');
      final k =
          Ky.tuyChon(from: DateTime(2026, 9, 11), to: DateTime(2026, 9, 18));
      expect(nhanKyTruoc(k), '04/09 – 10/09');
    });
  });

  group('tieuDeXuHuong', () {
    test('đổi theo đơn vị, kỳ tuỳ chọn rơi về tháng', () {
      expect(tieuDeXuHuong(DonViKy.tuan), 'Xu hướng 6 tuần');
      expect(tieuDeXuHuong(DonViKy.thang), 'Xu hướng 6 tháng',
          reason: 'đúng chuỗi trang đang hiện — bước 1 không đổi hình thức');
      expect(tieuDeXuHuong(DonViKy.quy), 'Xu hướng 6 quý');
      expect(tieuDeXuHuong(DonViKy.nam), 'Xu hướng 6 năm');
      expect(
        tieuDeXuHuong(DonViKy.tuyChon),
        'Xu hướng 6 tháng',
        reason: 'khoảng tuỳ ý không có đơn vị tự nhiên để lùi',
      );
    });
  });

  group('bằng nhau', () {
    test('hai kỳ cùng đơn vị và cùng biên là một', () {
      expect(Ky.thang(2026, 9), Ky.thang(2026, 9));
      expect(Ky.thang(2026, 9).hashCode, Ky.thang(2026, 9).hashCode);
    });

    test('cùng biên nhưng khác đơn vị thì KHÁC nhau', () {
      // Cần cho bộ chọn: một tháng chọn bằng chip Tháng khác với cùng khoảng ấy
      // gõ tay ở chip Tuỳ chọn — hai thứ hiện nhãn khác nhau, và dấu tích phải
      // đánh đúng dòng.
      expect(
        Ky.thang(2026, 9) ==
            Ky.tuyChon(from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)),
        isFalse,
      );
    });
  });

  // ── Mốc so sánh thứ hai: cùng kỳ năm trước (#2 khảo sát, 2026-09-16) ──────
  //
  // Trang Phân tích vốn chỉ so với **kỳ liền trước**. Mốc thứ hai lùi đúng một
  // năm dương lịch. Ba cái bẫy ở đây, cả ba hỏng im lặng:
  //  1. Tuần **không** lùi 52 kỳ — 52 tuần là 364 ngày nên nó trôi một ngày
  //     mỗi năm, và sau vài năm "tuần này năm ngoái" rơi hẳn sang tuần khác.
  //  2. Khoảng tuỳ chọn phải **giữ nguyên độ dài**. Dời riêng từng mốc thì kỳ
  //     bắt đầu 29/2 hoá ra dài hơn hoặc ngắn hơn một ngày, và phần trăm so hai
  //     kỳ lệch độ dài trông vẫn rất hợp lý.
  //  3. Nhãn tuần phải lấy **năm ISO**, không lấy `from.year`: tuần bắt đầu
  //     30/12/2024 là tuần 1 của **2025**.
  group('cungKyNamTruoc', () {
    test('tháng, quý, năm lùi đúng một năm và giữ nguyên đơn vị', () {
      expect(cungKyNamTruoc(Ky.thang(2026, 9)), Ky.thang(2025, 9));
      expect(cungKyNamTruoc(Ky.quy(2026, 3)), Ky.quy(2025, 3));
      expect(cungKyNamTruoc(Ky.nam(2026)), Ky.nam(2025));
    });

    test('tháng 2 năm nhuận so với tháng 2 năm thường — độ dài KHÁC nhau', () {
      final t = cungKyNamTruoc(Ky.thang(2028, 2));
      expect(t, Ky.thang(2027, 2));
      expect(
        t.to.difference(t.from).inDays,
        28,
        reason: 'một tháng là một tháng; ép hai kỳ bằng nhau số ngày là so sai '
            'đơn vị, và 29/2 sẽ biến mất khỏi phép so',
      );
    });

    test('tuần lùi 52 kỳ, KHÔNG neo vào ngày dương lịch của thứ Hai', () {
      // Tuần bắt đầu thứ Hai 14/09/2026. Neo vào cùng ngày dương lịch ra
      // 14/09/2025 — một Chủ nhật, tức thuộc tuần TRƯỚC (08–14/09), chồng lấp
      // đúng MỘT ngày với 7 ngày cần so. Lùi 52 kỳ ra tuần 15–21/09/2025,
      // chồng lấp sáu ngày.
      final k = Ky.tuan(DateTime(2026, 9, 16));
      expect(
        cungKyNamTruoc(k),
        lui(k, 52),
        reason: 'đo 3131 tuần của 60 năm: lùi 52 kỳ trùng khít lối neo thứ Năm '
            '(ngày định danh tuần ISO) ở mọi tuần',
      );
      expect(
        cungKyNamTruoc(k).from,
        DateTime(2025, 9, 15),
        reason: 'neo vào thứ Hai năm trước sẽ ra 08/09/2025 — lệch hẳn một tuần',
      );
    });

    test('tuần vẫn là một tuần trọn vẹn và chứa đúng ngày năm trước', () {
      final t = cungKyNamTruoc(Ky.tuan(DateTime(2026, 9, 16)));
      expect(t.donVi, DonViKy.tuan);
      expect(t.to.difference(t.from).inDays, 7);
      expect(t.chua(DateTime(2025, 9, 16)), isTrue);
    });

    test('khoảng tuỳ chọn giữ nguyên độ dài', () {
      final k = Ky.tuyChon(from: DateTime(2026, 9, 5), to: DateTime(2026, 9, 18));
      final t = cungKyNamTruoc(k);
      expect(t.from, DateTime(2025, 9, 5));
      expect(t.to, DateTime(2025, 9, 18));
      expect(t.to.difference(t.from), k.to.difference(k.from));
    });

    test('khoảng tuỳ chọn bắt đầu 29/2 vẫn giữ nguyên độ dài', () {
      final k =
          Ky.tuyChon(from: DateTime(2028, 2, 29), to: DateTime(2028, 3, 10));
      final t = cungKyNamTruoc(k);
      expect(
        t.from,
        DateTime(2027, 3, 1),
        reason: 'Dart chuẩn hoá 29/2/2027 thành 1/3/2027 — 2027 không nhuận',
      );
      expect(
        t.to.difference(t.from),
        k.to.difference(k.from),
        reason: 'dời riêng từng mốc thì kỳ so sánh lệch một ngày và phần trăm '
            'sai mà không lỗi nào báo',
      );
    });
  });

  group('nhanCungKyNamTruoc', () {
    test('tháng, quý, năm mượn nguyên nhanNgan vì nó đã có năm', () {
      expect(nhanCungKyNamTruoc(Ky.thang(2026, 9)), 'T9 2025');
      expect(nhanCungKyNamTruoc(Ky.quy(2026, 3)), 'Q3 2025');
      expect(nhanCungKyNamTruoc(Ky.nam(2026)), '2025');
    });

    test('tuần được thêm năm ISO, không phải năm của ngày thứ Hai', () {
      expect(nhanCungKyNamTruoc(Ky.tuan(DateTime(2026, 9, 16))), 'Tuần 38 2025');
      // Tuần chứa 31/12/2025 bắt đầu thứ Hai 29/12/2025; lùi 52 kỳ ra tuần bắt
      // đầu 30/12/2024 — nằm trong tháng 12 năm 2024 nhưng là tuần **1 của
      // 2025** theo ISO.
      expect(
        nhanCungKyNamTruoc(Ky.tuan(DateTime(2025, 12, 31))),
        'Tuần 1 2025',
        reason: 'lấy from.year sẽ in "Tuần 1 2024" — sai hẳn một năm, im lặng',
      );
    });

    test('khoảng tuỳ chọn được thêm năm vì nhanNgan chỉ có ngày/tháng', () {
      final k = Ky.tuyChon(from: DateTime(2026, 9, 5), to: DateTime(2026, 9, 18));
      expect(nhanCungKyNamTruoc(k), '05/09 – 17/09 2025');
    });
  });

  // ── G43: khoảng khởi tạo của bộ chọn ngày (2026-09-16) ───────────────────
  //
  // `showDateRangePicker` **ném assertion** khi `initialDateRange` thò ra ngoài
  // `[firstDate, lastDate]`. Lỗi ấy là một exception bất đồng bộ **không ai
  // bắt**: nút không làm gì, không toast, không màn đỏ — chỉ có một dòng trong
  // logcat mà người dùng không bao giờ thấy.
  //
  // Và nó xảy ra ở đúng trạng thái MẶC ĐỊNH của trang: "Tháng này" kết thúc
  // ngày cuối tháng, tức sau hôm nay.
  group('khoangKhoiTaoBoChonNgay', () {
    final homNay = DateTime(2026, 9, 16, 8, 27);
    final somNhat = DateTime(2021, 1, 1);

    test('kỳ kết thúc SAU hôm nay thì kẹp mốc cuối về hôm nay', () {
      final k = khoangKhoiTaoBoChonNgay(
        ky: Ky.thang(2026, 9),
        somNhat: somNhat,
        muonNhat: homNay,
      );
      expect(k, isNotNull);
      expect(k!.from, DateTime(2026, 9, 1));
      expect(
        k.den,
        homNay,
        reason: 'không kẹp thì showDateRangePicker ném assertion và nút "Tuỳ '
            'chọn" chết im lặng — đúng ca mặc định "Tháng này"',
      );
    });

    test('kỳ đã qua hẳn thì giữ nguyên hai mốc', () {
      final k = khoangKhoiTaoBoChonNgay(
        ky: Ky.thang(2026, 7),
        somNhat: somNhat,
        muonNhat: homNay,
      );
      expect(k!.from, DateTime(2026, 7, 1));
      expect(
        k.den,
        DateTime(2026, 7, 31),
        reason: 'bộ chọn nhận biên ĐÓNG còn Ky giữ biên MỞ — lệch đúng một ngày',
      );
    });

    test('kỳ bắt đầu TRƯỚC mốc sớm nhất thì kẹp mốc đầu', () {
      final k = khoangKhoiTaoBoChonNgay(
        ky: Ky.nam(2020),
        somNhat: somNhat,
        muonNhat: homNay,
      );
      expect(k, isNull, reason: 'cả kỳ nằm ngoài dải — không có khoảng nào hợp lệ');

      final k2 = khoangKhoiTaoBoChonNgay(
        ky: Ky.tuyChon(from: DateTime(2020, 6, 1), to: DateTime(2021, 6, 1)),
        somNhat: somNhat,
        muonNhat: homNay,
      );
      expect(k2!.from, somNhat);
      expect(k2.den, DateTime(2021, 5, 31));
    });

    test('kỳ nằm hoàn toàn sau mốc muộn nhất thì KHÔNG có khoảng khởi tạo', () {
      final k = khoangKhoiTaoBoChonNgay(
        ky: Ky.thang(2026, 12),
        somNhat: somNhat,
        muonNhat: homNay,
      );
      expect(
        k,
        isNull,
        reason: 'trả một khoảng đảo đầu-cuối cũng là một assertion khác; null '
            'để chỗ gọi mở bộ chọn mà không đặt khoảng sẵn',
      );
    });

    test('tuần chứa hôm nay cũng phải kẹp — ngày Chủ nhật còn ở tương lai', () {
      final k = khoangKhoiTaoBoChonNgay(
        ky: Ky.tuan(homNay),
        somNhat: somNhat,
        muonNhat: homNay,
      );
      expect(k!.from, DateTime(2026, 9, 14));
      expect(k.den, homNay);
    });
  });
}
