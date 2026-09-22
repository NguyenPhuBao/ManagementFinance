/// Sheet "Lọc theo số tiền" của sổ giao dịch (2026-09-21).
///
/// ## Ba nghĩa của giá trị trả về
///
/// Sheet trả `KhoangTien?`, và **ba** kết quả khác nhau phải phân biệt được:
///
/// - `null` — người dùng đóng sheet mà không chọn gì. Bộ lọc **giữ nguyên**.
/// - `KhoangTien()` rỗng — họ bấm **Xoá**. Bộ lọc **bỏ** điều kiện tiền.
/// - `KhoangTien(tu: …, den: …)` — họ bấm **Áp dụng**.
///
/// Gộp hai cái đầu làm một là bấm ra ngoài sheet cũng xoá mất bộ lọc đang có.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/transaction/domain/khoang_tien.dart';
import 'package:flowmoney/features/transaction/presentation/widgets/chon_khoang_tien_sheet.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

void main() {
  /// Mở sheet và trả về thứ nó cho ra. `ketQua` còn `null` nghĩa là sheet chưa
  /// đóng.
  Future<KhoangTien?> moSheet(
    WidgetTester tester, {
    KhoangTien? hienTai,
    required Future<void> Function(WidgetTester) thaoTac,
  }) async {
    KhoangTien? ketQua;
    var daDong = false;

    await tester.pumpWidget(
      MaterialApp(
        // ⚠️ Theme thật: theme của app ép mọi `ElevatedButton` rộng vô hạn
        // (bẫy 4.11), nên bố cục hỏng chỉ lộ ra khi dựng bằng đúng theme đang
        // chạy.
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  ketQua = await moChonKhoangTien(ctx, hienTai: hienTai);
                  daDong = true;
                },
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await thaoTac(tester);
    await tester.pumpAndSettle();

    expect(daDong, isTrue, reason: 'sheet phải đóng sau thao tác');
    return ketQua;
  }

  Future<void> go(WidgetTester tester, Key o, String chu) async {
    await tester.enterText(find.byKey(o), chu);
    await tester.pump();
  }

  const oTu = Key('khoang-tien-tu');
  const oDen = Key('khoang-tien-den');
  const nutApDung = Key('khoang-tien-ap-dung');
  const nutXoa = Key('khoang-tien-xoa');

  testWidgets('điền cả hai ô rồi Áp dụng trả về đúng khoảng', (tester) async {
    final ket = await moSheet(tester, thaoTac: (t) async {
      await go(t, oTu, '100000');
      await go(t, oDen, '500000');
      await t.tap(find.byKey(nutApDung));
    });
    expect(ket, const KhoangTien(tu: 100000, den: 500000));
  });

  testWidgets('để trống ô "Đến" nghĩa là không chặn trên', (tester) async {
    final ket = await moSheet(tester, thaoTac: (t) async {
      await go(t, oTu, '500000');
      await t.tap(find.byKey(nutApDung));
    });
    expect(ket, const KhoangTien(tu: 500000),
        reason: 'ô trống là "mọi mức", không phải 0');
  });

  testWidgets('để trống ô "Từ" nghĩa là không chặn dưới', (tester) async {
    final ket = await moSheet(tester, thaoTac: (t) async {
      await go(t, oDen, '200000');
      await t.tap(find.byKey(nutApDung));
    });
    expect(ket, const KhoangTien(den: 200000));
  });

  testWidgets('gõ ngược hai ô thì nút Áp dụng TẮT', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => moChonKhoangTien(ctx, hienTai: null),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    await go(tester, oTu, '500000');
    await go(tester, oDen, '100000');
    await tester.pumpAndSettle();

    final nut = tester.widget<ElevatedButton>(find.byKey(nutApDung));
    expect(nut.onPressed, isNull,
        reason: 'chặn chứ KHÔNG tự hoán đổi — hoán đổi là đoán ý người dùng, '
            'và đoán sai thì kết quả trông vẫn hoàn toàn hợp lý');
    expect(find.textContaining('nhỏ hơn'), findsOneWidget,
        reason: 'nút tắt mà không nói vì sao là một nút chết dưới mắt người dùng');
  });

  testWidgets('nút Xoá trả về khoảng RỖNG, khác null của việc đóng sheet',
      (tester) async {
    final ket = await moSheet(
      tester,
      hienTai: const KhoangTien(tu: 500000),
      thaoTac: (t) async => t.tap(find.byKey(nutXoa)),
    );
    expect(ket, const KhoangTien(),
        reason: 'null = đóng không chọn; rỗng = chủ động bỏ lọc. Hai ý khác nhau');
    expect(ket!.rong, isTrue);
  });

  testWidgets('mở lại sheet thì hai ô mang sẵn giá trị đang lọc',
      (tester) async {
    final ket = await moSheet(
      tester,
      hienTai: const KhoangTien(tu: 100000, den: 500000),
      thaoTac: (t) async => t.tap(find.byKey(nutApDung)),
    );
    expect(ket, const KhoangTien(tu: 100000, den: 500000),
        reason: 'không điền lại gì mà bấm Áp dụng thì khoảng phải y nguyên');
  });

  testWidgets('ô tiền có trần số chữ số: đúng 13 chữ số thì nhận', (tester) async {
    final ket = await moSheet(tester, thaoTac: (t) async {
      await go(t, oTu, '1234567890123'); // đúng 13 — vừa trần
      await t.tap(find.byKey(nutApDung));
    });
    expect(ket?.tu, 1234567890123,
        reason: 'trần là 13 chữ số phần nguyên của numeric(15,2), không ít hơn');
  });

  testWidgets('ô tiền có trần số chữ số: vượt trần thì GIỮ NGUYÊN chuỗi cũ',
      (tester) async {
    final ket = await moSheet(tester, thaoTac: (t) async {
      // 20 chữ số trong một lô. `GioiHanSoChuSo` trả về **oldValue** chứ không
      // cắt đuôi — cố ý, vì con trỏ có thể đang ở giữa và cắt đuôi là xoá chữ
      // số người dùng không đụng tới (xem `gioi_han_do_dai.dart`). Ô lúc ấy
      // đang rỗng, nên nó ở lại rỗng.
      await go(t, oTu, '12345678901234567890');
      await t.tap(find.byKey(nutApDung));
    });
    expect(ket?.tu, isNull,
        reason: 'không có trần thì chuỗi 20 chữ số lọt qua và cho một double '
            'vô nghĩa; ô ở lại rỗng chính là bằng chứng trần có tác dụng');
  });
}
