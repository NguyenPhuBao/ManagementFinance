/// Thẻ "VÍ TRÙNG TÊN" ở màn Quản lý ví (G63, spec mục 5.1; màn Stitch
/// `c5a2cecebc9f4959966346b3e99b4d47`). Dựng bằng `AppTheme.lightTheme` (bẫy 4.11) và thử 360 dp (bẫy 12).
library;

import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/core/ui/thong_bao_nhanh.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flowmoney/features/wallet/data/services/gop_vi_service.dart';
import 'package:flowmoney/features/wallet/data/vi_trung_ten_nguon.dart';
import 'package:flowmoney/features/wallet/domain/gop_vi.dart';
import 'package:flowmoney/features/wallet/presentation/widgets/the_vi_trung_ten.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _NguonGia implements ViTrungTenNguon {
  _NguonGia(this.ds);
  final List<CapViHienThi> ds;
  @override
  Stream<List<CapViHienThi>> theoDoi(int idaccount) => Stream.value(ds);
  @override
  Future<Set<String>> viCanTha(int idaccount) async => {};
  @override
  Future<Set<String>> viDangBiGiu(int idaccount) async => {for (final c in ds) c.idViMayNay};
}

class _RepoGia implements WalletRepository {
  _RepoGia(this.vi);
  final WalletEntity vi;
  WalletEntity? daCapNhat;
  Object? nem;
  @override
  Future<WalletEntity?> getById(String id) async => id == vi.id ? vi : null;
  @override
  Future<void> updateWallet(WalletEntity wallet) async {
    if (nem != null) throw nem!;
    daCapNhat = wallet;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WalletEntity _e(String id, String ten, {bool tuChoi = false}) => WalletEntity(
    id: id, idaccount: 7, name: ten, type: 'bank', balance: 0, biTuChoiTrungTen: tuChoi, updatedAt: DateTime(2026, 10, 5));

class _GopGia implements GopViService {
  _GopGia(this.kh);
  final KeHoachGop kh;
  int soLanGop = 0;
  Object? nem;
  @override
  Future<KeHoachGop> lapKeHoach({required String idViBo, required String idViGiu}) async => kh;
  @override
  Future<void> gop(KeHoachGop k) async {
    if (nem != null) throw nem!;
    soLanGop++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

KeHoachGop khDon() => keHoachGop(
      viBo: const ViChoGop(id: 'r', loai: 'bank', soDu: 0, tongSo: 0),
      viGiu: const ViChoGop(id: 'p', loai: 'bank', soDu: 0, tongSo: 0),
      giaoDich: const [],
      hoaDon: const [],
      mucTieu: const [],
    );

CapViHienThi capMau({String id = 'r', String ten = 'Ví MB Bank', String? lyDo}) => CapViHienThi(
      idViMayNay: id,
      idViDaDongBo: 'p$id',
      ten: ten,
      soDuMayNay: 1250000,
      soDuDaDongBo: 3400000,
      soGiaoDich: 7,
      lyDoKhongGop: lyDo,
    );

Future<void> dungThe(WidgetTester tester, Widget the, {Size kho = const Size(411, 900)}) async {
  tester.view.physicalSize = kho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [the, const Text('DUOI THE')]),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('không có cặp nào → không dựng gì, không chiếm chỗ', (tester) async {
    await dungThe(tester, TheViTrungTen(idaccount: 7, nguon: _NguonGia(const [])));
    expect(find.byKey(const ValueKey('the-vi-trung-ten')), findsNothing);
    expect(tester.getSize(find.byType(TheViTrungTen)).height, 0);
  });

  testWidgets('⭐ một cặp → tên, số dư hai ví, số giao dịch (chữ của Stitch)', (tester) async {
    await dungThe(tester, TheViTrungTen(idaccount: 7, nguon: _NguonGia([capMau()])));
    expect(find.byKey(const ValueKey('the-vi-trung-ten')), findsOneWidget);
    expect(find.text('VÍ TRÙNG TÊN'), findsOneWidget);
    expect(find.text('1 ví'), findsOneWidget);
    expect(
      find.text('Tên này đã có trên tài khoản (tạo từ thiết bị khác) nên ví trên máy này chưa đồng bộ được.'),
      findsOneWidget,
    );
    expect(find.text('Ví MB Bank'), findsOneWidget);
    expect(find.text('Máy này: 1.250.000 đ · 7 giao dịch'), findsOneWidget);
    expect(find.text('Đã đồng bộ: 3.400.000 đ'), findsOneWidget);
  });

  testWidgets('360 dp, tên dài, hai cặp → không tràn, đếm đúng', (tester) async {
    await dungThe(
      tester,
      TheViTrungTen(
        idaccount: 7,
        nguon: _NguonGia([
          capMau(ten: 'Ví ngân hàng MB Bank chi nhánh Hà Nội số hai của gia đình'),
          capMau(id: 'r2', ten: 'Ví MoMo'),
        ]),
      ),
      kho: const Size(360, 800),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('2 ví'), findsOneWidget);
    expect(find.text('Ví MoMo'), findsOneWidget);
  });

  group('Đổi tên', () {
    testWidgets('⭐ Đổi tên → hộp điền sẵn "(2)" → Lưu → updateWallet tên mới, thông báo, gọi nạp lại', (tester) async {
      final r = _e('r', 'Ví MB Bank', tuChoi: true);
      final repo = _RepoGia(r);
      final tb = ThongBaoNhanh();
      final cau = <String>[];
      final sub = tb.stream.listen(cau.add);
      addTearDown(sub.cancel);
      var soLanNap = 0;

      await dungThe(
        tester,
        TheViTrungTen(
          idaccount: 7,
          nguon: _NguonGia([capMau()]),
          viHienCo: [_e('p', 'Ví MB Bank'), r],
          viRepo: repo,
          thongBao: tb,
          onDaXuLy: () => soLanNap++,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('vi-trung-doi-ten-r')));
      await tester.pumpAndSettle();
      expect(find.text('Ví MB Bank (2)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nut-luu-ten-vi')));
      await tester.pumpAndSettle();

      expect(repo.daCapNhat?.name, 'Ví MB Bank (2)');
      expect(repo.daCapNhat?.id, 'r', reason: 'đổi tên ví TRÊN MÁY NÀY, không phải ví đã đồng bộ');
      expect(cau, ['Đã đổi tên ví.']);
      expect(soLanNap, 1);
    });

    testWidgets('Hủy → không ghi gì, không nạp lại', (tester) async {
      final r = _e('r', 'Ví MB Bank', tuChoi: true);
      final repo = _RepoGia(r);
      var soLanNap = 0;
      await dungThe(
        tester,
        TheViTrungTen(
          idaccount: 7,
          nguon: _NguonGia([capMau()]),
          viHienCo: [_e('p', 'Ví MB Bank'), r],
          viRepo: repo,
          thongBao: ThongBaoNhanh(),
          onDaXuLy: () => soLanNap++,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('vi-trung-doi-ten-r')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(repo.daCapNhat, isNull);
      expect(soLanNap, 0);
    });

    testWidgets('datasource từ chối (CacheException) → nói đúng câu lỗi', (tester) async {
      final r = _e('r', 'Ví MB Bank', tuChoi: true);
      final repo = _RepoGia(r)..nem = const CacheException('Đã có ví tên "Ví MB Bank (2)". Hãy đặt tên khác.');
      final tb = ThongBaoNhanh();
      final cau = <String>[];
      final sub = tb.stream.listen(cau.add);
      addTearDown(sub.cancel);

      await dungThe(
        tester,
        TheViTrungTen(
            idaccount: 7, nguon: _NguonGia([capMau()]), viHienCo: [_e('p', 'Ví MB Bank'), r], viRepo: repo, thongBao: tb),
      );
      await tester.tap(find.byKey(const ValueKey('vi-trung-doi-ten-r')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nut-luu-ten-vi')));
      await tester.pumpAndSettle();

      expect(cau, ['Đã có ví tên "Ví MB Bank (2)". Hãy đặt tên khác.']);
    });
  });

  group('Gộp', () {
    testWidgets('⭐ Gộp → hộp → xác nhận → gop chạy, thông báo, nạp lại', (tester) async {
      final svc = _GopGia(khDon());
      final tb = ThongBaoNhanh();
      final cau = <String>[];
      final sub = tb.stream.listen(cau.add);
      addTearDown(sub.cancel);
      var soLanNap = 0;

      await dungThe(
        tester,
        TheViTrungTen(
            idaccount: 7, nguon: _NguonGia([capMau()]), gopVi: svc, thongBao: tb, onDaXuLy: () => soLanNap++),
      );
      await tester.tap(find.byKey(const ValueKey('vi-trung-gop-r')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nut-xac-nhan-gop')));
      await tester.pumpAndSettle();

      expect(svc.soLanGop, 1);
      expect(cau, ['Đã gộp ví.']);
      expect(soLanNap, 1);
    });

    testWidgets('Hủy trong hộp → không gộp, không nạp lại', (tester) async {
      final svc = _GopGia(khDon());
      var soLanNap = 0;
      await dungThe(
        tester,
        TheViTrungTen(
            idaccount: 7,
            nguon: _NguonGia([capMau()]),
            gopVi: svc,
            thongBao: ThongBaoNhanh(),
            onDaXuLy: () => soLanNap++),
      );
      await tester.tap(find.byKey(const ValueKey('vi-trung-gop-r')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(svc.soLanGop, 0);
      expect(soLanNap, 0);
    });

    testWidgets('kế hoạch cũ → nói câu của KeHoachGopCuException', (tester) async {
      final svc = _GopGia(khDon())..nem = const KeHoachGopCuException();
      final tb = ThongBaoNhanh();
      final cau = <String>[];
      final sub = tb.stream.listen(cau.add);
      addTearDown(sub.cancel);
      await dungThe(tester, TheViTrungTen(idaccount: 7, nguon: _NguonGia([capMau()]), gopVi: svc, thongBao: tb));
      await tester.tap(find.byKey(const ValueKey('vi-trung-gop-r')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nut-xac-nhan-gop')));
      await tester.pumpAndSettle();
      expect(cau, [const KeHoachGopCuException().toString()]);
    });

    testWidgets('⭐ không gộp được → không có nút Gộp, có dòng lý do; nút Đổi tên vẫn còn', (tester) async {
      await dungThe(
        tester,
        TheViTrungTen(
            idaccount: 7,
            nguon: _NguonGia([capMau(lyDo: 'Ví kia là ví liên kết ngân hàng nên không gộp được.')])),
      );
      expect(find.byKey(const ValueKey('vi-trung-gop-r')), findsNothing);
      expect(find.text('Ví kia là ví liên kết ngân hàng nên không gộp được.'), findsOneWidget);
      expect(find.byKey(const ValueKey('vi-trung-doi-ten-r')), findsOneWidget);
    });

    testWidgets('360 dp: hai nút trên một hàng không tràn', (tester) async {
      await dungThe(tester, TheViTrungTen(idaccount: 7, nguon: _NguonGia([capMau()])), kho: const Size(360, 800));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('vi-trung-gop-r')), findsOneWidget);
      expect(find.byKey(const ValueKey('vi-trung-doi-ten-r')), findsOneWidget);
    });
  });
}
