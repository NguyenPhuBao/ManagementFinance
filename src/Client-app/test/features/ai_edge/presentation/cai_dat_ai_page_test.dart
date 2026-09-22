/// Màn **Cài đặt AI** — nơi duy nhất người dùng bật/tắt và tải mô hình trên máy.
///
/// Màn này dựng được **không cần DI**: tham số `daCoMoHinh` ép sẵn trạng thái,
/// nên mọi ca dưới đây chạy trọn vẹn trong `flutter test`. Cái `flutter test`
/// **không** thấy là tràn bố cục ở 411dp — ca cuối canh đúng chỗ ấy, và nghiệm
/// thu máy ảo vẫn bắt buộc.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/ai_edge/data/cong_tac_ai.dart';
import 'package:flowmoney/features/ai_edge/data/mo_hinh_tai_ve.dart';
import 'package:flowmoney/features/ai_edge/data/nguon_tai_nen.dart';
import 'package:flowmoney/features/ai_edge/domain/hoi_dung_4g.dart';
import 'package:flowmoney/features/ai_edge/presentation/pages/cai_dat_ai_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

void main() {
  // ⚠️ Theme thật, không `MaterialApp` trần: theme của app ép mọi
  // `ElevatedButton` rộng vô hạn, và nút trần trong `Row` làm trắng cả trang
  // mà không một dòng log nào (bẫy 4.11 `ANALYTICS_FEATURE.md`).
  Widget boc(Widget w) => MaterialApp(theme: AppTheme.lightTheme, home: w);

  testWidgets('chưa tải: hiện dung lượng và nút Tải, KHÔNG có nút Xoá',
      (t) async {
    await t.pumpWidget(boc(const CaiDatAiPage(daCoMoHinh: false)));
    expect(find.textContaining('2,41 GB'), findsWidgets);
    expect(find.text('Tải mô hình'), findsOneWidget);
    expect(find.text('Xoá mô hình'), findsNothing);
  });

  testWidgets('đã tải: hiện nút Xoá, KHÔNG còn nút Tải', (t) async {
    await t.pumpWidget(boc(const CaiDatAiPage(daCoMoHinh: true)));
    expect(find.text('Xoá mô hình'), findsOneWidget);
    expect(find.text('Tải mô hình'), findsNothing);
  });

  testWidgets('⚠️ luôn nói rõ số liệu KHÔNG rời khỏi máy — ở CẢ HAI trạng thái',
      (t) async {
    // Đây là lời hứa trung tâm của cả mảng (F1 đặc tả gốc, Nghị định 13). Người
    // dùng sắp tải 2,41 GB về máy mình — họ cần biết đổi lại được gì.
    //
    // ⚠️ Kế hoạch viết `find.textContaining('không')`; `textContaining` phân
    // biệt hoa thường còn câu bắt đầu bằng "Không", nên vế ấy đỏ trên cả bản
    // đúng. Ca này đòi thẳng **câu hứa**, không đòi một chữ rời.
    for (final co in [false, true]) {
      await t.pumpWidget(boc(CaiDatAiPage(daCoMoHinh: co)));
      expect(find.textContaining('rời khỏi thiết bị'), findsOneWidget,
          reason: 'daCoMoHinh=$co — lời hứa riêng tư không được biến mất ở '
              'trạng thái nào');
      expect(find.textContaining(RegExp('[Kk]hông')), findsWidgets,
          reason: 'daCoMoHinh=$co');
    }
  });

  testWidgets('công tắc "Dùng AI trên máy" có mặt và nói rõ tắt thì sao',
      (t) async {
    await t.pumpWidget(boc(const CaiDatAiPage(daCoMoHinh: true)));
    expect(find.text('Dùng AI trên máy'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    // Tắt công tắc không làm app mất tính năng — nó lùi về mẫu câu. Không nói
    // ra thì người dùng đọc cái tắt ấy là "mất khối Nhận xét".
    expect(find.textContaining('câu mẫu'), findsOneWidget);
  });

  testWidgets('chưa tải thì nhắc Wi-Fi kèm dung lượng', (t) async {
    await t.pumpWidget(boc(const CaiDatAiPage(daCoMoHinh: false)));
    expect(find.textContaining('Wi-Fi'), findsOneWidget);
  });

  testWidgets('411dp: không tràn bố cục ở cả hai trạng thái', (t) async {
    t.view.physicalSize = const Size(411 * 3, 914 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    for (final co in [false, true]) {
      await t.pumpWidget(boc(CaiDatAiPage(daCoMoHinh: co)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: 'daCoMoHinh=$co');
    }
  });

  testWidgets('⚠️ chip trạng thái theo CÔNG TẮC, không chỉ theo tệp',
      (t) async {
    // Đã tải mà công tắc tắt thì chip xanh "Hoạt động" là một lời khẳng định
    // đặt ngay trên chính cái công tắc đang nói ngược lại — và người dùng tin
    // cái chip. Thấy được khi nhìn màn thật, `flutter test` thì không.
    await t.pumpWidget(boc(const CaiDatAiPage(
      daCoMoHinh: true,
      congTac: _CongTacTat(),
    )));
    await t.pumpAndSettle();
    expect(find.text('Đang tắt'), findsOneWidget);
    expect(find.text('Hoạt động'), findsNothing);
  });

  testWidgets('công tắc bật thì chip nói Hoạt động', (t) async {
    await t.pumpWidget(boc(const CaiDatAiPage(daCoMoHinh: true)));
    await t.pumpAndSettle();
    expect(find.text('Hoạt động'), findsOneWidget);
  });

  // ── Tải nền + resume (2026-09-22, kế hoạch Task 5) ─────────────────────────

  MoHinhTaiVe moHinhVoi(WidgetTester t, NguonTaiNenGia nguon) {
    final tam = Directory.systemTemp.createTempSync('caidat');
    addTearDown(() => tam.deleteSync(recursive: true));
    final m = MoHinhTaiVe(thuMuc: () async => tam, nguon: nguon);
    addTearDown(m.dong);
    return m;
  }

  testWidgets('mở màn thì HỎI LẠI lượt tải của lần chạy trước', (t) async {
    final nguon = NguonTaiNenGia()
      ..dungSanLuotCu(
        (trangThai: TrangThaiLuot.dangChay, phanTram: 0.3, loi: null),
      );
    final m = moHinhVoi(t, nguon);

    await t.pumpWidget(boc(CaiDatAiPage(moHinh: m, congTac: const CongTacAi())));
    await t.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('30'), findsWidgets,
        reason: 'Không hỏi lại thì màn hiện "Chưa tải mô hình" trong khi lượt '
            'tải vẫn đang chạy ở nền, và nút Tải sẽ đẻ lượt thứ hai.');
  });

  testWidgets('trạng thái chờ mạng nói RA, không hiện như đang tải', (t) async {
    final nguon = NguonTaiNenGia();
    final m = moHinhVoi(t, nguon);

    await t.pumpWidget(boc(CaiDatAiPage(moHinh: m, congTac: const CongTacAi())));
    await m.tai();
    nguon.choMang();
    await t.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Wi-Fi'), findsWidgets,
        reason: 'requiresWiFi làm lượt đứng im vô thời hạn mà không báo lỗi; '
            'im lặng ở đây là một thanh 0% đứng yên mãi mãi.');
    expect(find.textContaining('Đang tải'), findsNothing);
  });

  testWidgets('đang tải thì có nút Tạm dừng; tạm dừng thì có Tiếp tục',
      (t) async {
    final nguon = NguonTaiNenGia();
    final m = moHinhVoi(t, nguon);

    await t.pumpWidget(boc(CaiDatAiPage(moHinh: m, congTac: const CongTacAi())));
    await m.tai();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Tạm dừng'), findsOneWidget);

    await t.tap(find.text('Tạm dừng'));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(find.text('Tạm dừng'), findsNothing);
  });

  testWidgets('bấm Tạm dừng KHÔNG tự đặt trạng thái, mà chờ tin từ nguồn',
      (t) async {
    // Bấm Tạm dừng trên THÔNG BÁO (ngoài app) cũng phải làm màn đổi theo, nên
    // nguồn là sự thật duy nhất. Màn tự đặt trạng thái là mở đường cho hai nơi
    // nói hai điều khác nhau.
    final nguon = _NguonKhongPhanHoi();
    final m = moHinhVoi(t, nguon);

    await t.pumpWidget(boc(CaiDatAiPage(moHinh: m, congTac: const CongTacAi())));
    await m.tai();
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.text('Tạm dừng'));
    await t.pump(const Duration(milliseconds: 50));

    expect(find.text('Tiếp tục'), findsNothing,
        reason: 'Nguồn chưa xác nhận thì màn chưa được đổi.');
  });

  testWidgets('hàng nút lúc đang tải không tràn ở 411dp', (t) async {
    await t.binding.setSurfaceSize(const Size(411, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));

    final nguon = NguonTaiNenGia();
    final m = moHinhVoi(t, nguon);

    await t.pumpWidget(boc(CaiDatAiPage(moHinh: m, congTac: const CongTacAi())));
    await m.tai();
    nguon.tienToi(0.42);
    await t.pump(const Duration(milliseconds: 50));

    expect(t.takeException(), isNull);
    expect(find.text('Tạm dừng'), findsOneWidget);
    expect(find.text('Huỷ'), findsOneWidget);
  });

  // ── Hộp thoại dữ liệu di động (kế hoạch Task 6) ────────────────────────────

  testWidgets('không có Wi-Fi: bấm Tải thì HỎI trước, chưa tải ngay',
      (t) async {
    final nguon = NguonTaiNenGia();
    final m = moHinhVoi(t, nguon);

    await t.pumpWidget(boc(CaiDatAiPage(
      moHinh: m,
      congTac: const CongTacAi(),
      coWifi: () async => false,
    )));
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.text('Tải mô hình'));
    await t.pumpAndSettle();

    expect(find.text(kCauHoi4G), findsOneWidget);
    expect(nguon.chiWifiLanCuoi, isNull,
        reason: 'Chưa ai đồng ý thì chưa được bắt đầu lượt nào.');
  });

  testWidgets('đồng ý dùng 4G thì tải với chiWifi = false', (t) async {
    final nguon = NguonTaiNenGia();
    final m = moHinhVoi(t, nguon);

    await t.pumpWidget(boc(CaiDatAiPage(
      moHinh: m,
      congTac: const CongTacAi(),
      coWifi: () async => false,
    )));
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.text('Tải mô hình'));
    await t.pumpAndSettle();
    await t.tap(find.text(kCauDongY4G));
    await t.pumpAndSettle();

    expect(nguon.chiWifiLanCuoi, isFalse);
  });

  testWidgets('"Để sau" thì KHÔNG tải, màn vẫn ở Chưa tải', (t) async {
    final nguon = NguonTaiNenGia();
    final m = moHinhVoi(t, nguon);

    await t.pumpWidget(boc(CaiDatAiPage(
      moHinh: m,
      congTac: const CongTacAi(),
      coWifi: () async => false,
    )));
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.text('Tải mô hình'));
    await t.pumpAndSettle();
    await t.tap(find.text(kCauTuChoi4G));
    await t.pumpAndSettle();

    expect(nguon.chiWifiLanCuoi, isNull);
    expect(find.text('Tải mô hình'), findsOneWidget,
        reason: 'Bản cũ `_tai()` tự đặt dangTai trước khi hỏi — từ chối rồi '
            'mà thanh tiến độ vẫn hiện cho một lượt không tồn tại.');
  });

  testWidgets('có Wi-Fi: bấm Tải thì tải thẳng, KHÔNG hỏi', (t) async {
    final nguon = NguonTaiNenGia();
    final m = moHinhVoi(t, nguon);

    await t.pumpWidget(boc(CaiDatAiPage(
      moHinh: m,
      congTac: const CongTacAi(),
      coWifi: () async => true,
    )));
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.text('Tải mô hình'));
    await t.pumpAndSettle();

    expect(find.text(kCauHoi4G), findsNothing);
    expect(nguon.chiWifiLanCuoi, isTrue);
  });
}

/// Nguồn nhận lệnh nhưng KHÔNG phát tin nào — dùng để chứng minh màn không tự
/// đặt trạng thái.
class _NguonKhongPhanHoi extends NguonTaiNenGia {
  @override
  Future<void> tamDung() async {}
}

/// Kho tuỳ chọn giả: luôn tắt. `FlutterSecureStorage` thật ném trong
/// `flutter test` (không có kênh nền tảng) và `CongTacAi` nuốt lỗi rồi trả
/// mặc định **bật** — nên không có lớp này thì nhánh "tắt" không dựng được.
class _CongTacTat extends CongTacAi {
  const _CongTacTat();
  @override
  Future<bool> doc() async => false;
}
