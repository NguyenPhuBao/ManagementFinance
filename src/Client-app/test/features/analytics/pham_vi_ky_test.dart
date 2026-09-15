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
      expect(Ky.quy(2026, 3).nhanTruc, 'Q3');
      expect(Ky.nam(2026).nhanTruc, '2026');
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
      expect(ds.first.nhanNgan, 'Quý 3 2026');
      expect(ds[1].nhanNgan, 'Quý 2 2026');
      expect(ds[3].nhanNgan, 'Quý 4 2025');
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
      expect(lui(Ky.quy(2026, 1), 1).nhanNgan, 'Quý 4 2025');
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
      expect(nhanOChon(Ky.quy(2026, 1), moc), 'Quý 1 2026');
    });

    test('kỳ tuỳ chọn không bao giờ mang dạng "… này"', () {
      final k =
          Ky.tuyChon(from: DateTime(2026, 9, 3), to: DateTime(2026, 9, 30));
      expect(k.chua(moc), isTrue, reason: 'khoảng này có chứa hôm nay');
      expect(nhanOChon(k, moc), '03/09 – 29/09');
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
      expect(nhanKyTruoc(Ky.quy(2026, 1)), 'Quý 4 2025');
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
}
