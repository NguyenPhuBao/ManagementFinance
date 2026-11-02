// Màn Góp vào quỹ / Rút về ví riêng (đợt 1B, Task 8; Stitch f77f5bc0 Góp, c39ac4f7 Rút).
import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/features/household/data/repositories/nha_repository_impl.dart';
import 'package:flowmoney/features/household/presentation/bloc/gop_rut_cubit.dart';
import 'package:flowmoney/features/household/presentation/pages/gop_rut_page.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/bat_thong_bao.dart';
import '../../../../helpers/du_lieu_nha_gia.dart';
import '../../../../helpers/font_that.dart';
import '../../../../helpers/goi_gia.dart';
import '../../../../helpers/gop_quy_gia.dart';
import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

final _homNay = DateTime(2026, 11, 2, 10);

WalletEntity _rieng(String id, String ten, double soDu, {bool macDinh = false}) => WalletEntity(
      id: id,
      idaccount: 18,
      name: ten,
      type: 'bank',
      balance: soDu,
      isDefault: macDinh,
      updatedAt: DateTime(2026, 11, 1),
    );

TransactionEntity _nua({required String type, String vi = 'v1', int? nha = 12, double tien = 2000000}) => TransactionEntity(
      id: nha == null ? 'r' : 'n',
      walletId: vi,
      idaccount: 18,
      idhousehold: nha,
      fundPairId: 'p',
      amount: tien,
      type: type,
      note: 'tiền chợ',
      date: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

void main() {
  setUpAll(napFontThat);

  late BatThongBao bat;
  late DuLieuNhaGia nguon;
  late GopQuyGia gq;
  late HouseholdApiGia api;
  late NhaRepositoryImpl repoNha;

  Future<void> mo(
    WidgetTester t, {
    CheDoQuy cheDo = CheDoQuy.gop,
    String? viChungId = 'v1',
    String? maCap,
    String vai = 'Owner',
    String status = 'Active',
    int? phien = 18,
    bool banPhim = false,
    Map<String, bool>? quyen,
    List<WalletEntity>? riengs,
  }) async {
    dat360(t, banPhim: banPhim);
    bat = batThongBao();
    nguon = DuLieuNhaGia(vi: [viChungGia('v1', 'Tiền chợ', 3200000), viChungGia('v2', 'Điện nước', 1250000)]);
    api = HouseholdApiGia()..cuaToiJson = nhaJson(myRole: vai, status: status);
    repoNha = await repoNhaThu(api);
    final ds = riengs ?? [_rieng('r1', 'Ví MB', 5420000), _rieng('r2', 'Ví mặc định', 100000, macDinh: true)];
    final r = routerThu(GopRutPage(
      cheDo: cheDo,
      viChungId: viChungId,
      maCap: maCap,
      nha: repoNha,
      duLieu: nguon,
      gopQuy: gq,
      napViRieng: () async => ds,
      dongHo: () => _homNay,
    ));
    await t.pumpWidget(bocRouterNha(r, idaccount: phien, goi: quyen == null ? null : goiBasic(quyen)));
    r.push('/dich');
    await t.pumpAndSettle();
  }

  setUp(() => gq = GopQuyGia());

  Finder banPhim() => find.byKey(const Key('ban-phim-so'));
  Finder phim(String k) => find.descendant(of: banPhim(), matching: find.text(k));
  Finder phimXong() => find.descendant(of: banPhim(), matching: find.byIcon(Icons.check));
  Future<void> bam(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> go(WidgetTester t, List<String> ks) async {
    for (final k in ks) {
      await bam(t, phim(k));
    }
  }

  testWidgets('Góp: tiêu đề, hàng form, chú thích, bàn phím 16 phím, không ✓ tiêu đề', (t) async {
    await mo(t);
    expect(find.text('Góp vào quỹ'), findsOneWidget);
    for (final s in [
      'Vào ví chung',
      'Tiền chợ',
      'Từ ví riêng',
      'Ví mặc định · 100.000 đ',
      'Tiền mặt trao tay',
      'Không trừ ví nào của bạn',
      'Ngày',
      'Hôm nay',
      'Ghi chú',
      'Thêm ghi chú',
      'Số tiền được trừ khỏi ví riêng của bạn và cộng vào quỹ.',
      'VNĐ - VIỆT NAM ĐỒNG',
    ]) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('0 đ'), findsOneWidget, reason: 'khối số tiền');
    expect(banPhim(), findsOneWidget);
    expect(find.byKey(const Key('luu-thanh-tieu-de')), findsNothing, reason: 'luật G58: ✓ tiêu đề chỉ khi 16 phím không trên màn');
    expect(find.byType(Switch), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(3), reason: 'ví chung, ví riêng, ngày; công tắc và ghi chú không có');
    expect(t.takeException(), isNull);
  });

  testWidgets('Góp: ví chung theo query đứng đầu, ví riêng mặc định được chọn', (t) async {
    await mo(t, viChungId: 'v2');
    expect(find.text('Điện nước'), findsOneWidget);
    expect(find.text('Ví mặc định · 100.000 đ'), findsOneWidget);
  });

  testWidgets('Góp từ ví riêng: gõ rồi ✓ bàn phím → gop đúng tham số, pop, báo', (t) async {
    await mo(t);
    await go(t, ['5', '0', '000']);
    expect(find.text('50.000 đ'), findsOneWidget);
    await t.enterText(find.byKey(const Key('o-ghi-chu')), 'Chợ tuần');
    await bam(t, phimXong());
    final g = gq.gop_.single;
    expect((g.idNha, g.idaccount, g.viChungId, g.tenViChung, g.soTien, g.viRiengId, g.ghiChu), (12, 18, 'v1', 'Tiền chợ', 50000, 'r2', 'Chợ tuần'));
    expect(g.ngay, _homNay);
    expect(find.text('GOC'), findsOneWidget);
    expect(bat.cau, ['Đã góp vào quỹ.']);
  });

  testWidgets('Tiền mặt trao tay: bật thì ẩn hàng ví riêng, đổi chú thích, ghi không ví riêng', (t) async {
    await mo(t);
    await bam(t, find.byType(Switch));
    expect(find.text('Từ ví riêng'), findsNothing);
    expect(find.text('Số tiền được cộng vào quỹ, không trừ ví nào của bạn.'), findsOneWidget);
    expect(find.text('Số tiền được trừ khỏi ví riêng của bạn và cộng vào quỹ.'), findsNothing);
    await go(t, ['7']);
    await bam(t, phimXong());
    expect(gq.gop_.single.viRiengId, isNull);
  });

  testWidgets('Chọn ví chung khác qua bảng chọn', (t) async {
    await mo(t);
    await bam(t, find.byKey(const Key('dong-vi-chung')));
    await bam(t, find.text('Điện nước'));
    await go(t, ['5']);
    await bam(t, phimXong());
    expect(gq.gop_.single.viChungId, 'v2');
    expect(gq.gop_.single.tenViChung, 'Điện nước');
  });

  testWidgets('Rút: tiêu đề, hàng form, chú thích, không công tắc tiền mặt', (t) async {
    await mo(t, cheDo: CheDoQuy.rut);
    expect(find.text('Rút về ví riêng'), findsWidgets);
    for (final s in [
      'Từ ví chung',
      'Tiền chợ · 3.200.000 đ',
      'Về ví riêng',
      'Ví mặc định · 100.000 đ',
      'Ngày',
      'Ghi chú',
      'Số tiền được trừ khỏi quỹ và cộng vào ví riêng của bạn.',
    ]) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.byType(Switch), findsNothing, reason: 'rút không có tiền mặt trao tay');
    await go(t, ['9']);
    await bam(t, phimXong());
    final r = gq.rut_.single;
    expect((r.viChungId, r.viRiengId, r.soTien), ('v1', 'r2', 9));
    expect(bat.cau, ['Đã rút về ví riêng.']);
  });

  testWidgets('Sửa khoản góp: tiêu đề, hàng ví không chevron, không công tắc, đủ số sẵn, ✓ tiêu đề (16 phím ẩn)', (t) async {
    gq
      ..nha = _nua(type: 'thu')
      ..rieng = _nua(type: 'chi', vi: 'r1', nha: null);
    await mo(t, maCap: 'p');
    expect(find.text('Sửa khoản góp'), findsOneWidget);
    expect(find.text('2.000.000 đ'), findsOneWidget);
    expect(find.text('Hôm qua'), findsOneWidget);
    expect(find.text('Ví MB · 5.420.000 đ'), findsOneWidget);
    expect(find.byType(Switch), findsNothing, reason: 'tiền mặt không đổi được khi sửa');
    expect(find.byIcon(Icons.chevron_right), findsOneWidget, reason: 'chỉ hàng Ngày còn chevron');
    expect(banPhim(), findsNothing);
    expect(find.byKey(const Key('luu-thanh-tieu-de')), findsOneWidget);
    await bam(t, find.byKey(const Key('luu-thanh-tieu-de')));
    expect(gq.sua_.single.maCap, 'p');
    expect(gq.sua_.single.soTien, 2000000);
    expect(bat.cau, ['Đã sửa khoản.']);
    expect(find.text('GOC'), findsOneWidget);
  });

  testWidgets('Sửa khoản rút', (t) async {
    gq
      ..nha = _nua(type: 'chi')
      ..rieng = _nua(type: 'thu', vi: 'r1', nha: null);
    await mo(t, maCap: 'p', cheDo: CheDoQuy.gop);
    expect(find.text('Sửa khoản rút'), findsOneWidget);
    expect(find.text('Từ ví chung'), findsOneWidget);
  });

  testWidgets('FINAL: sửa khoản rút mà máy không có nửa riêng — chú thích chỉ nói quỹ, không hứa cộng ví riêng', (t) async {
    gq
      ..nha = _nua(type: 'chi')
      ..rieng = null;
    await mo(t, maCap: 'p');
    expect(find.text('Sửa khoản rút'), findsOneWidget, reason: 'tiền đề: đây là sửa khoản rút, chỉ còn nửa nhà');
    expect(find.text('Số tiền được trừ khỏi quỹ.'), findsOneWidget);
    expect(find.text('Số tiền được trừ khỏi quỹ và cộng vào ví riêng của bạn.'), findsNothing,
        reason: '`sua` chỉ đổi nửa nhà: không có nửa riêng để cộng');
  });

  testWidgets('Sửa mà khoản không còn lúc mở: báo và đóng', (t) async {
    await mo(t, maCap: 'p'); // docCap trả hai nửa rỗng
    expect(bat.cau, ['Khoản này không còn.']);
    expect(find.text('GOC'), findsOneWidget);
  });

  testWidgets('Dịch vụ ném CacheException: báo câu của nó, ở lại màn, mở khoá nút', (t) async {
    await mo(t);
    gq.loi = const CacheException('Ví chung không thuộc nhà đang chọn.');
    await go(t, ['5']);
    await bam(t, phimXong());
    expect(bat.cau, ['Ví chung không thuộc nhà đang chọn.']);
    expect(find.text('GOC'), findsNothing);
    expect(find.text('Góp vào quỹ'), findsOneWidget);
  });

  testWidgets('Không phiên: báo, không ghi (quy tắc 2: không `?? 1`)', (t) async {
    await mo(t, phien: null);
    await go(t, ['5']);
    await bam(t, phimXong());
    expect(gq.gop_, isEmpty);
    expect(bat.cau, ['Không xác định được tài khoản. Hãy đăng nhập lại.']);
  });

  testWidgets('Vai đổi sau lúc mở (Chủ hạ xuống Chỉ xem): lưu thì không ghi, báo và đóng', (t) async {
    await mo(t);
    await go(t, ['5']);
    api.cuaToiJson = nhaJson(myRole: 'Viewer');
    await repoNha.lamMoi();
    await bam(t, phimXong());
    expect(gq.gop_, isEmpty, reason: 'đọc lại vai ngay đầu lúc lưu — server sẽ từ chối, ví nhà đã nhận tiền');
    expect(bat.cau, ['Bạn không còn quyền ghi khoản trong nhà này.']);
    expect(find.text('GOC'), findsOneWidget);
  });

  testWidgets('Nhà đổi sang nhà khác sau lúc mở: không ghi', (t) async {
    await mo(t);
    await go(t, ['5']);
    api.cuaToiJson = nhaJson(id: 99);
    await repoNha.lamMoi();
    await bam(t, phimXong());
    expect(gq.gop_, isEmpty);
  });

  for (final c in [(vai: 'Viewer', status: 'Active'), (vai: 'Owner', status: 'ReadOnly')]) {
    testWidgets('mở khi không được ghi (${c.vai} / ${c.status}): tự đóng kèm câu', (t) async {
      await mo(t, vai: c.vai, status: c.status);
      expect(bat.cau, ['Bạn không còn quyền ghi khoản trong nhà này.']);
      expect(find.text('GOC'), findsOneWidget);
    });
  }

  testWidgets('số tiền 0: báo câu, không ghi', (t) async {
    await mo(t);
    await bam(t, phimXong());
    expect(bat.cau, ['Vui lòng nhập số tiền lớn hơn 0.']);
    expect(gq.gop_, isEmpty);
  });

  testWidgets('bàn phím hệ thống mở: ✓ lên tiêu đề, 16 phím ẩn, bấm ✓ lưu thật', (t) async {
    gq
      ..nha = _nua(type: 'thu')
      ..rieng = _nua(type: 'chi', vi: 'r1', nha: null);
    await mo(t, banPhim: true, maCap: 'p');
    expect(banPhim(), findsNothing);
    expect(find.byKey(const Key('luu-thanh-tieu-de')), findsOneWidget);
    expect(t.takeException(), isNull);
    await bam(t, find.byKey(const Key('luu-thanh-tieu-de')));
    expect(gq.sua_.single.soTien, 2000000, reason: '✓ tiêu đề là đường lưu duy nhất khi 16 phím không trên màn');
    expect(find.text('GOC'), findsOneWidget);
  });

  testWidgets('chạm khối số tiền: ẩn rồi hiện lại 16 phím', (t) async {
    await mo(t);
    await bam(t, find.byKey(const Key('so-tien-cham')));
    expect(banPhim(), findsNothing);
    expect(find.byKey(const Key('luu-thanh-tieu-de')), findsOneWidget);
    await bam(t, find.byKey(const Key('so-tien-cham')));
    expect(banPhim(), findsOneWidget);
  });

  testWidgets('13 chữ số gõ bằng 16 phím ở 360 dp không tràn, gõ quá trần bị chặn', (t) async {
    await mo(t);
    await go(t, ['9', '000', '000', '000', '000', '000']);
    expect(find.text('9.000.000.000.000 đ'), findsOneWidget, reason: 'gõ quá 13 chữ số bị chặn');
    expect(t.takeException(), isNull);
    // Text bọc trong FittedBox nên không bao giờ xuống dòng; thứ cần đo là khung chữ SAU khi thu nhỏ có nằm trong màn không.
    final khung = t.getRect(find.text('9.000.000.000.000 đ'));
    expect(khung.left, greaterThanOrEqualTo(0), reason: 'chữ không tràn trái');
    expect(khung.right, lessThanOrEqualTo(360), reason: 'chữ không tràn phải ở 360 dp');
  });

  testWidgets('13 chữ số + bàn phím hệ thống mở ở ô ghi chú: không tràn, ✓ tiêu đề lưu đúng số', (t) async {
    gq
      ..nha = _nua(type: 'thu', tien: 9999999999999)
      ..rieng = _nua(type: 'chi', vi: 'r1', nha: null, tien: 9999999999999);
    await mo(t, banPhim: true, maCap: 'p');
    expect(find.text('9.999.999.999.999 đ'), findsOneWidget, reason: 'số tiền 13 chữ số đã nạp vào khối số');
    await t.enterText(find.byKey(const Key('o-ghi-chu')), 'Ghi chú khá dài để thử xem hàng có tràn hay không nhé');
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final khung = t.getRect(find.text('9.999.999.999.999 đ'));
    expect(khung.left, greaterThanOrEqualTo(0));
    expect(khung.right, lessThanOrEqualTo(360), reason: 'chữ số tiền (sau thu nhỏ) không tràn phải ở 360 dp');
    await bam(t, find.byKey(const Key('luu-thanh-tieu-de')));
    expect(gq.sua_.single.soTien, 9999999999999);
    expect(gq.sua_.single.ghiChu, startsWith('Ghi chú khá dài'));
  });

  testWidgets('phép tính theo quyền: tắt in_app_calculator thì + và − không đổi chuỗi', (t) async {
    await mo(t, quyen: {'in_app_calculator': false});
    await go(t, ['5', '+', '5']);
    expect(find.text('55 đ'), findsOneWidget, reason: 'phím + bị khoá, hai số 5 liền nhau');
  });

  testWidgets('phép tính được phép: 5 + 5 hiện biểu thức, lưu ghi 10', (t) async {
    await mo(t);
    await go(t, ['5', '+', '5']);
    await bam(t, phimXong());
    expect(gq.gop_.single.soTien, 10);
  });
}
