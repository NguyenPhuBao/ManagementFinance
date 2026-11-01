// Màn Hoạt động của nhà (đợt 1B, Task 6; Stitch 50af4171, a8d53198, 6dc96c4a 8B).
import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/household/application/gop_quy_service.dart';
import 'package:flowmoney/features/household/application/thao_tac_khoan_nha.dart';
import 'package:flowmoney/features/household/presentation/pages/hoat_dong_nha_page.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/presentation/pages/add_transaction_page.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/bat_thong_bao.dart';
import '../../../../helpers/du_lieu_nha_gia.dart';
import '../../../../helpers/font_that.dart';
import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

class _ThaoTacGia implements ThaoTacKhoanNha {
  final daXoa = <TransactionEntity>[];
  Object? loi;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #xoa) {
      final t = invocation.positionalArguments.first as TransactionEntity;
      daXoa.add(t);
      final l = loi;
      return l == null ? Future<void>.value() : Future<void>.error(l);
    }
    return super.noSuchMethod(invocation);
  }
}

class _GopQuyGia implements GopQuyService {
  _GopQuyGia({this.rieng});

  final TransactionEntity? rieng;
  final goi = <String>[];

  @override
  Future<({TransactionEntity? rieng, TransactionEntity? nha})> docCap(String maCap) async {
    goi.add(maCap);
    return (rieng: rieng, nha: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ViRiengGia implements WalletRepository {
  @override
  Future<WalletEntity?> getById(String id) async => WalletEntity(
        id: id,
        idaccount: 18,
        name: 'Ví MB',
        type: 'bank',
        balance: 0,
        updatedAt: DateTime(2026, 11, 1),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
    CategoryEntity(id: id, idaccount: 25, name: ten, classify: 'chi', idhousehold: 12, updatedAt: DateTime(2026, 11, 1));

final _vi = [
  viChungGia('v1', 'Tiền chợ', 3200000),
  viChungGia('v2', 'Điện nước', 1250000),
  viChungGia('v3', 'Quỹ du lịch', 9000000),
];

Map<String, Object?> _nhaThanhVien() => nhaJson(
      myRole: 'Member',
      members: [
        {'idaccount': 18, 'displayName': 'Trần An', 'role': 'Member', 'joinedAt': '2026-10-23T08:00:00.000Z'},
        {'idaccount': 25, 'displayName': 'Nguyễn Bình', 'role': 'Owner', 'joinedAt': '2026-10-23T09:12:00.000Z'},
      ],
    );

void main() {
  setUpAll(napFontThat);

  late DuLieuNhaGia nguon;
  late _ThaoTacGia thaoTac;
  late _GopQuyGia gopQuy;
  late BatThongBao bat;

  Future<void> mo(
    WidgetTester t, {
    List<TransactionEntity>? ds,
    Map<String, Object?>? nha,
    _GopQuyGia? gq,
  }) async {
    dat360(t);
    bat = batThongBao();
    nguon = DuLieuNhaGia(vi: _vi)
      ..datKhoan(ds ??
          [
            _k('chi', tien: 120000),
            _k('gop', ai: 25, type: 'thu', tien: 2000000, cap: 'p1', cat: null),
            _k('chuyen', tien: 500000, type: 'transfer', dich: 'v2', cat: null),
            _k('cu', ai: 31, tien: 80000, ngay: DateTime(2026, 11, 1, 20), cat: 'c2'),
          ])
      ..datDanhMuc([_dm('c1', 'Ăn uống'), _dm('c2', 'Đi lại')]);
    thaoTac = _ThaoTacGia();
    gopQuy = gq ?? _GopQuyGia();
    final api = HouseholdApiGia()..cuaToiJson = nha ?? nhaJson();
    final repo = await repoNhaThu(api);
    final trang = HoatDongNhaPage(
      repo: repo,
      duLieu: nguon,
      thaoTac: thaoTac,
      gopQuy: gopQuy,
      viRieng: _ViRiengGia(),
      dongHo: () => _homNay,
    );
    await t.pumpWidget(bocTrangNha(trang));
    await t.pumpAndSettle();
  }

  testWidgets('nhóm theo ngày: Hôm nay / Hôm qua, đếm giao dịch, câu tiêu đề và dòng phụ theo màn 7', (t) async {
    await mo(t);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('3 giao dịch'), findsOneWidget);
    expect(find.text('Hôm qua'), findsOneWidget);
    expect(find.text('1 giao dịch'), findsOneWidget);
    expect(find.text('Trần An chi 120.000 đ'), findsOneWidget);
    expect(find.text('Ăn uống · Tiền chợ'), findsOneWidget, reason: 'chi: Danh mục · Ví');
    expect(find.text('Nguyễn Bình góp 2.000.000 đ'), findsOneWidget);
    expect(find.text('Trần An chuyển 500.000 đ'), findsOneWidget);
    expect(find.text('Tiền chợ → Điện nước'), findsOneWidget, reason: 'chuyển: ví nguồn → ví đích');
    expect(find.text('Chỉ các thành viên trong nhà mới có thể xem hoạt động'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('số tiền cột phải: dấu và màu theo loại; người đã rời có hậu tố, xám', (t) async {
    await mo(t);
    Text tien(String chu) => t.widget<Text>(find.text(chu));
    expect(tien('-120.000 đ').style?.color, const Color(0xFF1A1A19), reason: 'chi: đen');
    expect(tien('+2.000.000 đ').style?.color, const Color(0xFF008736), reason: 'góp: xanh, dấu +');
    expect(find.text('500.000 đ'), findsOneWidget, reason: 'chuyển: không dấu (cột phải)');
    expect(find.text('Lê Bình (đã rời) chi 80.000 đ'), findsOneWidget);
    expect(tien('-80.000 đ').style?.color, const Color(0xFF767872), reason: 'người đã rời: xám');
  });

  testWidgets('neo và khoản đã xoá không hiện trong danh sách', (t) async {
    await mo(t, ds: [
      _k('neo', type: 'thu', tien: 5000000, cat: null, note: tienToMoSo),
      _k('that', tien: 70000),
    ]);
    expect(find.text('1 giao dịch'), findsOneWidget, reason: 'neo không đếm');
    expect(find.text('Trần An chi 70.000 đ'), findsOneWidget);
    expect(find.textContaining('5.000.000'), findsNothing);
  });

  testWidgets('lọc theo người rồi theo ví đổi danh sách; rỗng thì nói "Chưa có khoản nào."', (t) async {
    await mo(t);
    await t.tap(find.byKey(const Key('chip-nguoi')));
    await t.pumpAndSettle();
    await t.tap(find.text('Nguyễn Bình'));
    await t.pumpAndSettle();
    expect(find.text('Nguyễn Bình góp 2.000.000 đ'), findsOneWidget);
    expect(find.text('Trần An chi 120.000 đ'), findsNothing, reason: 'lọc người');
    expect(find.text('Nguyễn Bình'), findsOneWidget, reason: 'chip đổi nhãn theo người đã chọn');

    await t.tap(find.byKey(const Key('chip-vi')));
    await t.pumpAndSettle();
    await t.tap(find.text('Quỹ du lịch'));
    await t.pumpAndSettle();
    expect(find.text('Chưa có khoản nào.'), findsOneWidget, reason: 'Bình × Quỹ du lịch không có khoản');
  });

  testWidgets('lọc ví gồm cả khoản chuyển ĐẾN ví ấy', (t) async {
    await mo(t);
    await t.tap(find.byKey(const Key('chip-vi')));
    await t.pumpAndSettle();
    await t.tap(find.text('Điện nước').last);
    await t.pumpAndSettle();
    expect(find.text('Trần An chuyển 500.000 đ'), findsOneWidget);
    expect(find.text('Trần An chi 120.000 đ'), findsNothing);
  });

  testWidgets('danh sách rỗng ngay từ đầu: "Chưa có khoản nào."', (t) async {
    await mo(t, ds: const []);
    expect(find.text('Chưa có khoản nào.'), findsOneWidget);
  });

  testWidgets('chạm dòng mở sheet chi tiết: loại, ví, người ghi, ngày, ghi chú', (t) async {
    await mo(t, ds: [_k('gop', ai: 25, type: 'thu', tien: 2000000, cap: 'p1', cat: null, note: 'Tiền chợ tháng 11')]);
    await t.tap(find.byKey(const ValueKey('khoan-gop')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('sheet-tieu-de')), findsOneWidget);
    expect(find.text('Góp vào quỹ'), findsOneWidget);
    expect(find.text('Tiền chợ tháng 11'), findsOneWidget);
    expect(find.text('02/11/2026'), findsOneWidget);
    expect(find.text('Hôm nay'), findsWidgets);
  });

  group('quyền trong sheet', () {
    testWidgets('Thành viên: khoản của người khác không có Sửa / Xoá; khoản của mình có cả hai', (t) async {
      await mo(t, nha: _nhaThanhVien(), ds: [_k('cua-toi', ai: 18), _k('cua-binh', ai: 25, tien: 90000)]);
      await t.tap(find.byKey(const ValueKey('khoan-cua-binh')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('sheet-sua')), findsNothing);
      expect(find.byKey(const Key('sheet-xoa')), findsNothing);
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('khoan-cua-toi')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('sheet-sua')), findsOneWidget);
      expect(find.byKey(const Key('sheet-xoa')), findsOneWidget);
    });

    testWidgets('Thành viên không có Sửa / Xoá khoản chuyển dù của mình', (t) async {
      await mo(t, nha: _nhaThanhVien(), ds: [_k('chuyen', ai: 18, type: 'transfer', dich: 'v2', cat: null)]);
      await t.tap(find.byKey(const ValueKey('khoan-chuyen')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('sheet-sua')), findsNothing,
          reason: 'route /nha/khoan không xét quyền sửa: chốt duy nhất là nút này');
      expect(find.byKey(const Key('sheet-xoa')), findsNothing);
    });

    testWidgets('Chủ với nửa nhà có mã cặp của người khác: chỉ Xoá', (t) async {
      await mo(t, ds: [_k('gop', ai: 25, type: 'thu', tien: 2000000, cap: 'p1', cat: null)]);
      await t.tap(find.byKey(const ValueKey('khoan-gop')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('sheet-xoa')), findsOneWidget);
      expect(find.byKey(const Key('sheet-sua')), findsNothing, reason: 'nửa riêng chỉ trên máy người ghi');
    });

    testWidgets('khoản cặp CỦA CHÍNH Chủ cũng chưa có Sửa ở Task 6 (bật ở Task 8)', (t) async {
      await mo(t, ds: [_k('gop', ai: 18, type: 'thu', tien: 2000000, cap: 'p1', cat: null)]);
      await t.tap(find.byKey(const ValueKey('khoan-gop')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('sheet-sua')), findsNothing);
      expect(find.byKey(const Key('sheet-xoa')), findsOneWidget);
    });
  });

  testWidgets('Sửa khoản thường: push /nha/khoan với EditTransactionArgs mang cả danh mục tra từ bảng nhà', (t) async {
    Object? extra;
    // Trang thật gắn vào route để `context.push` có router thật.
    dat360(t);
    bat = batThongBao();
    nguon = DuLieuNhaGia(vi: _vi)
      ..datKhoan([_k('chi')])
      ..datDanhMuc([_dm('c1', 'Ăn uống')]);
    final repo = await repoNhaThu(HouseholdApiGia()..cuaToiJson = nhaJson());
    final router = GoRouter(initialLocation: '/nha/hoat-dong', routes: [
      GoRoute(
        path: '/nha/hoat-dong',
        builder: (_, __) => HoatDongNhaPage(repo: repo, duLieu: nguon, thaoTac: _ThaoTacGia(), dongHo: () => _homNay),
      ),
      GoRoute(
        path: '/nha/khoan',
        builder: (_, s) {
          extra = s.extra;
          return const Scaffold(body: Text('FORM'));
        },
      ),
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(bocRouterNha(router));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('khoan-chi')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('sheet-sua')));
    await t.pumpAndSettle();
    expect(find.text('FORM'), findsOneWidget);
    final args = extra as EditTransactionArgs;
    expect(args.transaction.id, 'chi');
    expect(args.category?.name, 'Ăn uống',
        reason: 'thiếu category là form sửa báo "Vui lòng chọn danh mục" dù khoản có danh mục');
  });

  group('xoá', () {
    testWidgets('khoản thường: hỏi "Xoá khoản này?" rồi xoá đúng khoản', (t) async {
      await mo(t, ds: [_k('chi')]);
      await t.tap(find.byKey(const ValueKey('khoan-chi')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('sheet-xoa')));
      await t.pumpAndSettle();
      expect(find.text('Xoá khoản này?'), findsOneWidget);
      expect(thaoTac.daXoa, isEmpty, reason: 'chưa xác nhận thì chưa xoá');
      await t.tap(find.widgetWithText(ElevatedButton, 'Xoá'));
      await t.pumpAndSettle();
      expect(thaoTac.daXoa.map((e) => e.id), ['chi']);
      expect(bat.cau, contains('Đã xoá khoản.'));
    });

    testWidgets('Huỷ hộp thì không xoá', (t) async {
      await mo(t, ds: [_k('chi')]);
      await t.tap(find.byKey(const ValueKey('khoan-chi')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('sheet-xoa')));
      await t.pumpAndSettle();
      await t.tap(find.text('Huỷ'));
      await t.pumpAndSettle();
      expect(thaoTac.daXoa, isEmpty);
    });

    testWidgets('Chủ xoá nửa nhà của người khác: hộp nói đúng câu, rồi gọi ThaoTacKhoanNha.xoa', (t) async {
      await mo(t, ds: [_k('gop', ai: 25, type: 'thu', tien: 2000000, cap: 'p1', cat: null)]);
      await t.tap(find.byKey(const ValueKey('khoan-gop')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('sheet-xoa')));
      await t.pumpAndSettle();
      expect(gopQuy.goi, ['p1']);
      expect(find.text('Xoá khoản góp?'), findsOneWidget);
      expect(find.text('Khoản góp của Nguyễn Bình bị xoá, quỹ Tiền chợ giảm 2.000.000 đ. Tiền được trả về ví riêng của Nguyễn Bình.'),
          findsOneWidget);
      await t.tap(find.byKey(const Key('hop-xoa-xac-nhan')));
      await t.pumpAndSettle();
      expect(thaoTac.daXoa.map((e) => e.id), ['gop']);
    });

    testWidgets('khoản góp của chính mình có ví riêng: câu nêu tên ví riêng', (t) async {
      final rieng = _k('gop-rieng', ai: 18, type: 'chi', tien: 2000000, cap: 'p1', vi: 'rieng-1', cat: null);
      await mo(t,
          ds: [_k('gop', ai: 18, type: 'thu', tien: 2000000, cap: 'p1', cat: null)], gq: _GopQuyGia(rieng: rieng));
      await t.tap(find.byKey(const ValueKey('khoan-gop')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('sheet-xoa')));
      await t.pumpAndSettle();
      expect(find.text('Quỹ Tiền chợ cũng giảm 2.000.000 đ, và số tiền được trả về Ví MB.'), findsOneWidget);
    });

    testWidgets('khoản rút: tiêu đề "Xoá khoản rút?"', (t) async {
      final rieng = _k('rut-rieng', ai: 18, type: 'thu', tien: 500000, cap: 'p2', vi: 'rieng-1', cat: null);
      await mo(t, ds: [_k('rut', ai: 18, type: 'chi', tien: 500000, cap: 'p2', cat: null)], gq: _GopQuyGia(rieng: rieng));
      await t.tap(find.byKey(const ValueKey('khoan-rut')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('sheet-xoa')));
      await t.pumpAndSettle();
      expect(find.text('Xoá khoản rút?'), findsOneWidget);
      expect(find.text('Quỹ Tiền chợ được cộng lại 500.000 đ, và khoản nhận ở Ví MB bị huỷ.'), findsOneWidget);
    });

    testWidgets('xoá thất bại (cặp không còn trên máy): báo câu của CacheException, không im lặng', (t) async {
      await mo(t, ds: [_k('chi')]);
      thaoTac.loi = const CacheException('Khoản này không còn trên máy.');
      await t.tap(find.byKey(const ValueKey('khoan-chi')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('sheet-xoa')));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ElevatedButton, 'Xoá'));
      await t.pumpAndSettle();
      expect(bat.cau, contains('Khoản này không còn trên máy.'));
      expect(bat.cau, isNot(contains('Đã xoá khoản.')));
    });
  });

  testWidgets('13 chữ số ở 360 dp: dòng, sheet không tràn', (t) async {
    await mo(t, ds: [_k('lon', tien: 9999999999999)]);
    expect(t.takeException(), isNull);
    final dong = t.getRect(find.byKey(const ValueKey('khoan-lon')));
    final tien = t.getRect(find.byKey(const Key('tien-khoan-nha')));
    expect(tien.right, lessThanOrEqualTo(dong.right), reason: 'số tiền nằm trong dòng');
    await t.tap(find.byKey(const ValueKey('khoan-lon')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final sheet = t.getRect(find.byKey(const Key('sheet-so-tien')));
    expect(sheet.right, lessThanOrEqualTo(360));
    expect(t.getSize(find.byKey(const Key('sheet-so-tien'))).height, lessThan(60), reason: 'một dòng, không xuống dòng');
  });
}
