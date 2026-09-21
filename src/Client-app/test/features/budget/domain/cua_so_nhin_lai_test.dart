/// Cửa sổ nhìn lại — định nghĩa duy nhất của "mức mỗi tháng" suy từ lịch sử.
///
/// Hàm này ra đời ngày 2026-09-21 sau một phép đo lật giả định của chính việc
/// đang làm: hai chỗ trong app tự cắt **ba tháng lịch đã đóng**, mà giao dịch
/// sớm nhất trong toàn bộ CSDL là **02/09/2026** — nên cả hai trả về rỗng trên
/// mọi tài khoản, **im lặng**. Gợi ý hạn mức trong form tạo ngân sách vì thế
/// chưa từng hiện một con số nào kể từ khi vào repo ngày 2026-09-06.
///
/// Spec: `docs/superpowers/specs/2026-09-21-cua-so-nhin-lai-va-de-xuat-tao-ngan-sach-design.md`
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/budget/domain/cua_so_nhin_lai.dart';

void main() {
  final now = DateTime(2026, 9, 21, 15, 30);

  test('tài khoản chưa có giao dịch nào thì chưa đủ để nói', () {
    expect(
      cuaSoNhinLai(now, null),
      isNull,
      reason: '`null` có MỘT nghĩa: chưa đủ để nói. Người gọi phải im hẳn — '
          '`?? 0` ở đây biến "tôi chưa biết" thành "bạn không chi gì"',
    );
  });

  test('13 ngày là chưa đủ, 14 ngày là đủ — biên đúng chỗ', () {
    expect(
      cuaSoNhinLai(now, now.subtract(const Duration(days: 13))),
      isNull,
      reason: 'suy một mức "mỗi tháng" từ chưa đầy hai tuần là bịa một lời hứa',
    );

    final cs = cuaSoNhinLai(now, now.subtract(const Duration(days: 14)));
    expect(cs, isNotNull, reason: 'đúng ngưỡng thì nói được');
    expect(cs!.soNgay, 14);
  });

  test('dữ liệu cũ hơn 90 ngày thì cửa sổ bị kẹp còn 90', () {
    final cs = cuaSoNhinLai(now, DateTime(2020, 1, 1))!;
    expect(cs.soNgay, kSoNgayNhinLai);
    expect(
      cs.from,
      now.subtract(const Duration(days: kSoNgayNhinLai)),
      reason: 'nhìn xa hơn 90 ngày thì thói quen chi tiêu cũ lấn át hiện tại',
    );
  });

  test('cửa sổ đóng ở đầu SAU: `to` đúng bằng `now`', () {
    final cs = cuaSoNhinLai(now, DateTime(2026, 9, 1))!;
    expect(
      cs.to,
      now,
      reason: 'CSDL thật có giao dịch ghi ngày TƯƠNG LAI (khoản trích mục tiêu '
          '10/10 và 10/11). Cửa sổ hở đầu sau sẽ nuốt tiền CHƯA TIÊU vào một '
          'con số nói về quá khứ — cùng họ với bẫy của Tổng tài sản theo thời '
          'gian, nơi vế [moc, now] phải đóng cả hai đầu',
    );
  });

  test('soNgay đếm theo ngày thật, không làm tròn lên', () {
    final cs = cuaSoNhinLai(now, DateTime(2026, 9, 1, 6))!;
    expect(
      cs.soNgay,
      20,
      reason: '01/09 06:00 → 21/09 15:30 là 20 ngày trọn. soNgay là MẪU SỐ khi '
          'quy về mức tháng, nên làm tròn lên ở đây là làm mọi mức tháng nhỏ đi',
    );
  });
}
