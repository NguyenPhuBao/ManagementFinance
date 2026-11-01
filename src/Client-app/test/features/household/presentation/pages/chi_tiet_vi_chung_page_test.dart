// Màn Chi tiết ví chung (đợt 1B, Task 7; Stitch ac57e216 tab Giao dịch, 6d63311f tab Bảng góp).
import 'dart:async';

import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/household/domain/bang_gop.dart';
import 'package:flowmoney/features/household/domain/hoat_dong_nha.dart';
import 'package:flowmoney/features/household/presentation/pages/chi_tiet_vi_chung_page.dart';
import 'package:flowmoney/features/household/presentation/widgets/bang_gop_view.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/bat_thong_bao.dart';
import '../../../../helpers/du_lieu_nha_gia.dart';
import '../../../../helpers/font_that.dart';
import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

final _homNay = DateTime(2026, 11, 2, 10);

TransactionEntity _k(
  String id, {
  int ai = 18,
  String type = 'chi',
  double tien = 120000,
  String vi = 'v1',
  String? dich,
  String? cap,
  String? cat = 'c1',
  String note = '',
  DateTime? ngay,
}) =>
    TransactionEntity(
      id: id,
      walletId: vi,
      walletTransfer: dich,
      idaccount: ai,
      idhousehold: 12,
      fundPairId: cap,
      categoryId: cat,
      amount: tien,
      type: type,
      note: note,
      date: ngay ?? DateTime(2026, 11, 2, 9),
      updatedAt: ngay ?? DateTime(2026, 11, 2, 9),
    );

CategoryEntity _dm(String id, String ten) =>
    CategoryEntity(id: id, idaccount: 18, name: ten, classify: 'chi', idhousehold: 12, updatedAt: DateTime(2026, 11, 1));

List<Map<String, Object?>> _thanhVien({bool them = false}) => [
      {'idaccount': 18, 'displayName': 'Trần An', 'role': 'Owner', 'joinedAt': '2026-10-23T08:00:00.000Z'},
      {'idaccount': 25, 'displayName': 'Nguyễn Bình', 'role': 'Member', 'joinedAt': '2026-10-23T09:12:00.000Z'},
      if (them) {'idaccount': 40, 'displayName': 'Phạm Cường', 'role': 'Member', 'joinedAt': '2026-10-24T09:12:00.000Z'},
    ];

void main() {
  setUpAll(napFontThat);

  late BatThongBao bat;
  late DuLieuNhaGia nguon;
  late GoRouter router;

  /// Mở `/nha/vi/<id>` trên stack thật `/` → chi tiết, để `pop` về GOC. Mọi route đích ghi lại vị trí.
  Future<void> mo(
    WidgetTester t, {
    String vai = 'Owner',
    String status = 'Active',
    List<WalletEntity>? vi,
    List<TransactionEntity>? ds,
    List<Map<String, Object?>>? members,
    String id = 'v1',
  }) async {
    dat360(t);
    bat = batThongBao();
    nguon = DuLieuNhaGia(vi: vi ?? [viChungGia('v1', 'Tiền chợ', 3200000), viChungGia('v2', 'Điện nước', 1250000)])
      ..datKhoan(ds ?? [])
      ..datDanhMuc([_dm('c1', 'Ăn uống'), _dm('c2', 'Đi lại')]);
    final repo = await repoNhaThu(HouseholdApiGia()..cuaToiJson = nhaJson(myRole: vai, status: status, members: members));
    router = GoRouter(initialLocation: '/', routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('GOC'))),
      GoRoute(
        path: '/nha/vi/:id',
        builder: (_, s) => ChiTietViChungPage(idVi: s.pathParameters['id']!, repo: repo, duLieu: nguon, dongHo: () => _homNay),
      ),
      GoRoute(path: '/nha/vi/:id/sua', builder: (_, s) => Scaffold(body: Text('SUA-${s.pathParameters['id']}'))),
      GoRoute(path: '/nha/khoan', builder: (_, s) => Scaffold(body: Text('KHOAN ${s.uri}'))),
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(bocRouterNha(router, idaccount: 18));
    await t.pumpAndSettle();
    unawaited(router.push('/nha/vi/$id'));
    await t.pumpAndSettle();
  }

  group('hàng nút theo vai', () {
    testWidgets('Chủ nhà: Chi · Thu · Chuyển theo thứ tự màn 3; thẻ số dư, huy hiệu, dòng loại ví, bút sửa', (t) async {
      await mo(t);
      expect(find.text('Tiền chợ'), findsOneWidget, reason: 'tiêu đề thanh trên');
      expect(find.text('SỐ DƯ'), findsOneWidget);
      expect(find.text('Chủ nhà'), findsOneWidget);
      expect(find.text('3.200.000 đ'), findsOneWidget);
      expect(find.text('Tiền mặt · Ví chung'), findsOneWidget, reason: 'WalletType.nhan + " · Ví chung"');
      final x = [for (final k in ['nut-chi', 'nut-thu', 'nut-chuyen']) t.getTopLeft(find.byKey(Key(k))).dx];
      expect(x[0], lessThan(x[1]));
      expect(x[1], lessThan(x[2]), reason: 'thứ tự Chi, Thu, Chuyển');
      expect(find.byKey(const Key('nut-sua-vi')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Thành viên: Chi · Thu, không Chuyển, không bút sửa', (t) async {
      await mo(t, vai: 'Member');
      expect(find.byKey(const Key('nut-chi')), findsOneWidget);
      expect(find.byKey(const Key('nut-thu')), findsOneWidget);
      expect(find.byKey(const Key('nut-chuyen')), findsNothing, reason: 'chuyển giữa ví chung chỉ Chủ nhà');
      expect(find.byKey(const Key('nut-sua-vi')), findsNothing);
      expect(find.text('Thành viên'), findsOneWidget, reason: 'huy hiệu vai');
    });

    testWidgets('Chỉ xem: không hàng nút, vẫn có số dư, hai tab và danh sách', (t) async {
      await mo(t, vai: 'Viewer', ds: [_k('chi')]);
      for (final k in ['nut-chi', 'nut-thu', 'nut-chuyen']) {
        expect(find.byKey(Key(k)), findsNothing);
      }
      expect(find.text('3.200.000 đ'), findsOneWidget);
      expect(find.byKey(const Key('tab-giao-dich')), findsOneWidget);
      expect(find.byKey(const Key('tab-bang-gop')), findsOneWidget);
      expect(find.byKey(const ValueKey('khoan-chi')), findsOneWidget);
    });

    testWidgets('nhà chỉ xem (Chủ hết Premium): không hàng nút, không bút sửa', (t) async {
      await mo(t, status: 'ReadOnly');
      expect(find.byKey(const Key('nut-chi')), findsNothing);
      expect(find.byKey(const Key('nut-sua-vi')), findsNothing, reason: 'quản lý ví chỉ khi nhà hoạt động');
      expect(find.text('3.200.000 đ'), findsOneWidget);
    });

    testWidgets('ví lưu trữ: không hàng nút, có dải "Ví đã lưu trữ"; Chủ vẫn có bút (để bỏ lưu trữ)', (t) async {
      await mo(t, vi: [viChungGia('v1', 'Tiền chợ', 3200000, status: 'inactive')]);
      expect(find.byKey(const Key('nut-chi')), findsNothing);
      expect(find.text('Ví đã lưu trữ'), findsOneWidget);
      expect(find.byKey(const Key('nut-sua-vi')), findsOneWidget);
    });
  });

  group('điều hướng', () {
    testWidgets('Chi / Thu / Chuyển đẩy /nha/khoan với ví và hướng', (t) async {
      for (final (khoa, huong) in [('nut-chi', 'chi'), ('nut-thu', 'thu'), ('nut-chuyen', 'transfer')]) {
        await mo(t);
        await t.tap(find.byKey(Key(khoa)));
        await t.pumpAndSettle();
        expect(find.text('KHOAN /nha/khoan?vi=v1&huong=$huong'), findsOneWidget, reason: khoa);
      }
    });

    testWidgets('bút sửa đẩy /nha/vi/<id>/sua', (t) async {
      await mo(t);
      await t.tap(find.byKey(const Key('nut-sua-vi')));
      await t.pumpAndSettle();
      expect(find.text('SUA-v1'), findsOneWidget);
    });

    testWidgets('ví bị xoá khi trang đang mở: pop về trang trước kèm câu, không vỡ', (t) async {
      await mo(t);
      nguon.datVi([viChungGia('v2', 'Điện nước', 1250000)]);
      await t.pumpAndSettle();
      expect(find.text('GOC'), findsOneWidget, reason: 'tự đóng màn');
      expect(bat.cau, contains('Ví chung này không còn nữa.'));
      expect(t.takeException(), isNull);
    });

    testWidgets('ví đánh dấu xoá mềm cũng coi là mất', (t) async {
      await mo(t);
      nguon.datVi([viChungGia('v1', 'Tiền chợ', 3200000).copyWith(isDeleted: true)]);
      await t.pumpAndSettle();
      expect(find.text('GOC'), findsOneWidget);
    });

    testWidgets('mở thẳng một ví không có trong nhà: pop kèm câu', (t) async {
      await mo(t, id: 'khong-co');
      expect(find.text('GOC'), findsOneWidget);
      expect(bat.cau, contains('Ví chung này không còn nữa.'));
    });
  });

  group('tab Giao dịch', () {
    testWidgets('nhóm theo ngày; dòng theo màn 3: tiêu đề, dòng phụ, số tiền có dấu', (t) async {
      await mo(t, ds: [
        _k('chi', note: 'Đi chợ sáng'),
        _k('gop', ai: 25, type: 'thu', tien: 2000000, cap: 'p1', cat: null),
        _k('rut', ai: 25, type: 'chi', tien: 500000, cap: 'p2', cat: null, ngay: DateTime(2026, 11, 1, 20)),
        _k('thu', type: 'thu', tien: 300000, cat: 'c2', ngay: DateTime(2026, 11, 1, 8)),
        _k('chuyen', tien: 70000, type: 'transfer', dich: 'v2', cat: null),
      ]);
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('3 giao dịch'), findsOneWidget);
      expect(find.text('Hôm qua'), findsOneWidget);
      expect(find.text('2 giao dịch'), findsOneWidget);
      expect(find.text('Trần An chi · Ăn uống'), findsOneWidget);
      expect(find.text('Đi chợ sáng'), findsOneWidget, reason: 'dòng phụ là ghi chú khi có');
      expect(find.text('-120.000 đ'), findsOneWidget);
      expect(find.text('Nguyễn Bình góp'), findsOneWidget);
      expect(find.text('Từ ví riêng'), findsOneWidget, reason: 'góp không ghi chú');
      expect(find.text('+2.000.000 đ'), findsOneWidget);
      expect(find.text('Nguyễn Bình rút'), findsOneWidget);
      expect(find.text('Về ví riêng'), findsOneWidget);
      expect(find.text('-500.000 đ'), findsOneWidget);
      expect(find.text('Trần An thu · Đi lại'), findsOneWidget);
      expect(find.text('+300.000 đ'), findsOneWidget);
      expect(find.text('Trần An chuyển'), findsOneWidget);
      expect(find.text('Tiền chợ → Điện nước'), findsOneWidget);
      expect(find.text('70.000 đ'), findsOneWidget, reason: 'chuyển không dấu');
      expect(t.takeException(), isNull);
    });

    testWidgets('chỉ khoản của ví này (gồm chuyển ĐẾN ví này); neo và khoản xoá không hiện', (t) async {
      await mo(t, ds: [
        _k('cua-v1', tien: 11000),
        _k('cua-v2', vi: 'v2', tien: 22000),
        _k('den-v1', vi: 'v2', dich: 'v1', type: 'transfer', tien: 33000, cat: null),
      ]);
      expect(find.byKey(const ValueKey('khoan-cua-v1')), findsOneWidget);
      expect(find.byKey(const ValueKey('khoan-cua-v2')), findsNothing, reason: 'ví khác');
      expect(find.byKey(const ValueKey('khoan-den-v1')), findsOneWidget, reason: 'chuyển đến ví này là một dòng của ví này');
    });

    testWidgets('trống: "Chưa có khoản nào."', (t) async {
      await mo(t);
      expect(find.text('Chưa có khoản nào.'), findsOneWidget);
    });
  });

  group('tab Bảng góp', () {
    // An: chỉ chi tháng này 1.250.000 (+ một khoản chi ví khác và một chuyển ĐẾN ví này: không được cộng).
    // Bình: góp 2.000.000 tháng này + 6.000.000 tháng 9, rút 500.000, chi 300.000. Lê Bình (đã rời): góp 2.000.000 tháng 9.
    final ds = [
      _k('an-chi', tien: 1250000),
      _k('an-v2', vi: 'v2', tien: 999000),
      _k('an-chuyen-den', vi: 'v2', dich: 'v1', type: 'transfer', tien: 777000, cat: null),
      _k('b-gop1', ai: 25, type: 'thu', tien: 2000000, cap: 'p1', cat: null),
      _k('b-gop2', ai: 25, type: 'thu', tien: 6000000, cap: 'p2', cat: null, ngay: DateTime(2026, 9, 10)),
      _k('b-rut', ai: 25, tien: 500000, cap: 'p3', cat: null),
      _k('b-chi', ai: 25, tien: 300000),
      _k('lb-gop', ai: 31, type: 'thu', tien: 2000000, cap: 'p4', cat: null, ngay: DateTime(2026, 9, 1)),
    ];

    Future<void> sangBangGop(WidgetTester t, {List<TransactionEntity>? du, List<Map<String, Object?>>? members}) async {
      await mo(t, ds: du ?? ds, members: members);
      await t.tap(find.byKey(const Key('tab-bang-gop')));
      await t.pumpAndSettle();
    }

    String chu(WidgetTester t, String khoa) => t.widget<Text>(find.descendant(of: find.byKey(Key(khoa)), matching: find.byType(Text)).last).data!;

    testWidgets('thẻ theo màn 4: bốn nhãn, số đúng, ví khác và chuyển đến không cộng', (t) async {
      await sangBangGop(t);
      expect(find.text('Thành viên ví (3)'), findsOneWidget, reason: 'hai thành viên đang ở + một người đã rời có khoản');
      expect(find.text('Góp tháng này'), findsNWidgets(3));
      expect(find.text('Góp từ trước tới nay'), findsNWidgets(3));
      expect(find.text('Đã rút'), findsNWidgets(3));
      expect(find.text('Đã chi tháng này'), findsNWidgets(3));
      expect(chu(t, 'o-gop-thang-25'), '2.000.000 đ');
      expect(chu(t, 'o-gop-tong-25'), '8.000.000 đ');
      expect(chu(t, 'o-da-rut-25'), '500.000 đ');
      expect(chu(t, 'o-da-chi-25'), '300.000 đ');
      expect(chu(t, 'o-da-chi-18'), '1.250.000 đ', reason: 'khoản chi ví khác (999.000) và chuyển đến (777.000) không vào bảng góp');
      expect(chu(t, 'o-gop-tong-18'), '0 đ');
      expect(find.text('Đã góp'), findsNothing, reason: 'Stitch ghi "có thể thừa": bỏ huy hiệu Đã góp');
      expect(find.text('Cập nhật tháng này'), findsNothing);
    });

    testWidgets('thứ tự: thành viên đang ở rồi người đã rời; người đã rời có huy hiệu "Đã rời" và màu xám', (t) async {
      await sangBangGop(t);
      final an = t.getTopLeft(find.byKey(const Key('the-gop-18'))).dy;
      final binh = t.getTopLeft(find.byKey(const Key('the-gop-25'))).dy;
      final roi = t.getTopLeft(find.byKey(const Key('the-gop-31'))).dy;
      expect(an, lessThan(binh));
      expect(binh, lessThan(roi));
      expect(find.text('Đã rời'), findsOneWidget, reason: 'chỉ người đã rời có huy hiệu');
      expect(find.descendant(of: find.byKey(const Key('the-gop-31')), matching: find.text('Đã rời')), findsOneWidget);
      expect(find.text('Lê Bình (đã rời)'), findsOneWidget);
      final gop = t.widget<Text>(find.descendant(of: find.byKey(const Key('o-gop-tong-31')), matching: find.byType(Text)).last);
      expect(gop.data, '2.000.000 đ');
      expect(gop.style?.color, const Color(0xFF767872), reason: 'giá trị của người đã rời xám');
      final binhTien = t.widget<Text>(find.descendant(of: find.byKey(const Key('o-gop-tong-25')), matching: find.byType(Text)).last);
      expect(binhTien.style?.color, isNot(const Color(0xFF767872)), reason: 'người đang ở không xám');
    });

    testWidgets('thành viên đang ở mà chưa có khoản vẫn có thẻ 0 đ; người đã rời không có khoản thì không có thẻ', (t) async {
      await sangBangGop(t, du: [_k('an-chi', tien: 1250000)], members: _thanhVien(them: true));
      expect(find.byKey(const Key('the-gop-40')), findsOneWidget);
      expect(chu(t, 'o-gop-tong-40'), '0 đ');
      expect(chu(t, 'o-da-chi-40'), '0 đ');
      expect(find.byKey(const Key('the-gop-25')), findsOneWidget, reason: 'Bình đang ở dù không có khoản');
      expect(find.byKey(const Key('the-gop-31')), findsNothing, reason: 'Lê Bình đã rời và không có khoản trong ví này');
      expect(find.textContaining('Lê Bình'), findsNothing);
      expect(find.text('Thành viên ví (3)'), findsOneWidget);
    });

    testWidgets('người ngoài danh sách (không còn thành viên lẫn người cũ) mà có khoản vẫn hiện, như đã rời', (t) async {
      await sangBangGop(t, du: [_k('la', ai: 77, type: 'thu', tien: 100000, cap: 'p9', cat: null)]);
      expect(find.byKey(const Key('the-gop-77')), findsOneWidget, reason: 'tiền của họ vẫn nằm trong ví');
      expect(find.text('Thành viên #77 (đã rời)'), findsOneWidget);
    });

    testWidgets('chuyển sang tab và về lại: danh sách giao dịch quay lại', (t) async {
      await sangBangGop(t);
      expect(find.byKey(const ValueKey('khoan-an-chi')), findsNothing);
      await t.tap(find.byKey(const Key('tab-giao-dich')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('khoan-an-chi')), findsOneWidget);
      expect(find.byKey(const Key('the-gop-25')), findsNothing);
    });

    testWidgets('BangGopView rỗng: có câu', (t) async {
      await t.pumpWidget(MaterialApp(
          home: Scaffold(body: BangGopView(the: const [], tenNguoi: (_) => const TenNguoi('x')))));
      expect(find.text('Chưa có ai góp vào ví này.'), findsOneWidget);
    });

    testWidgets('BangGopView: thẻ chỉ gồm ô cần', (t) async {
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: BangGopView(
        the: const [(dong: DongBangGop(idaccount: 5, gopTuTruoc: 10), daRoi: false)],
        tenNguoi: (_) => const TenNguoi('Ba'),
      ))));
      expect(find.byKey(const Key('the-gop-5')), findsOneWidget);
    });
  });

  group('360 dp, 13 chữ số', () {
    testWidgets('thẻ số dư không tràn, một dòng', (t) async {
      await mo(t, vi: [viChungGia('v1', 'Tên ví chung khá dài ${'x' * 40}', 9999999999999)]);
      expect(t.takeException(), isNull);
      final so = find.byKey(const Key('so-du-vi'));
      expect(find.text('9.999.999.999.999 đ'), findsOneWidget);
      expect(t.getSize(so).height, lessThan(50), reason: '30 px một dòng ≈ 36; xuống dòng sẽ ≥ 72 (Text xuống dòng không báo tràn)');
      expect(t.getRect(so).right, lessThanOrEqualTo(360));
    });

    testWidgets('ô bảng góp 13 chữ số: một dòng, nằm trong thẻ', (t) async {
      await mo(t, ds: [_k('g', ai: 25, type: 'thu', tien: 9999999999999, cap: 'p1', cat: null)]);
      await t.tap(find.byKey(const Key('tab-bang-gop')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final o = find.byKey(const Key('o-gop-tong-25'));
      final so = find.descendant(of: o, matching: find.text('9.999.999.999.999 đ'));
      expect(so, findsOneWidget);
      expect(t.getSize(so).height, lessThan(24), reason: '13 px một dòng ≈ 16; xuống dòng ≥ 32');
      final the = t.getRect(find.byKey(const Key('the-gop-25')));
      expect(t.getRect(so).right, lessThanOrEqualTo(the.right));
      expect(t.getRect(so).left, greaterThanOrEqualTo(the.left));
    });

    testWidgets('ô bảng góp ở cỡ chữ hệ thống 1,5: 13 chữ số vẫn trọn một dòng (không bị cắt "đ")', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.platformDispatcher.clearAllTestValues);
      await mo(t, ds: [_k('g', ai: 25, type: 'thu', tien: 9999999999999, cap: 'p1', cat: null)]);
      await t.tap(find.byKey(const Key('tab-bang-gop')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final so = find.descendant(of: find.byKey(const Key('o-gop-tong-25')), matching: find.text('9.999.999.999.999 đ'));
      expect((t.renderObject(so) as RenderParagraph).didExceedMaxLines, isFalse,
          reason: 'hết chỗ thì Text cắt chữ "đ" im lặng (maxLines 1 không báo tràn): FittedBox phải co lại');
    });

    testWidgets('dòng giao dịch số tiền 13 chữ số không đè hết câu tiêu đề', (t) async {
      await mo(t, ds: [_k('lon', tien: 9999999999999)]);
      expect(t.takeException(), isNull);
      final so = find.text('-9.999.999.999.999 đ');
      expect(so, findsOneWidget);
      expect(t.getSize(so).height, lessThan(24), reason: '15 px một dòng ≈ 18; xuống dòng ≥ 36');
      expect(t.getRect(so).right, lessThanOrEqualTo(360));
      expect(find.text('Trần An chi · Ăn uống'), findsOneWidget, reason: 'câu tiêu đề còn đủ, không bị số tiền nuốt');
    });
  });
}
