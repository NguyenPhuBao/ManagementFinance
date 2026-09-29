/// Thẻ "Có vẻ là khoản lặp" trên trang Hoá đơn (B2) — màn Stitch `e8b460b4…`.
///
/// ⚠️ Dựng bằng `AppTheme.lightTheme`: theme của app ép mọi `ElevatedButton`
/// rộng vô hạn, nút trần trong `Row` làm trắng cả trang (bẫy 4.11).
library;

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/utils/currency_formatter.dart';
import 'package:flowmoney/features/bill/data/de_xuat_hoa_don_nguon.dart';
import 'package:flowmoney/features/bill/domain/dien_san_hoa_don.dart';
import 'package:flowmoney/features/bill/presentation/widgets/the_khoan_lap.dart';
import 'package:flowmoney/features/transaction/domain/khoan_lap.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

KhoanLap _kl(String ten, {double tien = 3000000, String chuKy = kBillCycleMonth, int soLan = 3}) =>
    KhoanLap(
      khoaNhom: '${ten.toLowerCase()}|c-nha',
      ten: ten,
      soTien: tien,
      chuKy: chuKy,
      ngayGoc: chuKy == kBillCycleMonth ? 5 : null,
      ngayGanNhat: DateTime(2026, 11, 5),
      categoryId: 'c-nha',
      walletId: 'v1',
      soLan: soLan,
    );

/// Nguồn giả: giữ danh sách trong bộ nhớ; Bỏ qua / Tạo gỡ nhóm ấy ra như bảng
/// phản hồi thật sẽ làm ở lần `tai` kế tiếp.
class _NguonGia implements DeXuatHoaDonNguon {
  _NguonGia(this._ds);
  final List<KhoanLap>? _ds;
  final boQuaGoi = <(int, String)>[];
  final daTaoGoi = <(int, String)>[];
  int soLanTai = 0;

  @override
  Future<List<KhoanLap>?> tai(int idaccount) async {
    soLanTai++;
    final d = _ds;
    return (d == null || d.isEmpty) ? null : List.of(d);
  }

  @override
  Future<Map<String, Category>> bangDanhMuc(int idaccount) async => const {};

  @override
  Future<void> boQua(int idaccount, String khoaNhom) async {
    boQuaGoi.add((idaccount, khoaNhom));
    _ds?.removeWhere((k) => k.khoaNhom == khoaNhom);
  }

  @override
  Future<void> daTao(int idaccount, String khoaNhom) async {
    daTaoGoi.add((idaccount, khoaNhom));
    _ds?.removeWhere((k) => k.khoaNhom == khoaNhom);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _dung(
  WidgetTester tester,
  _NguonGia nguon, {
  Future<bool?> Function(Map<String, String>)? moForm,
  Size kho = const Size(411, 900),
}) async {
  tester.view.physicalSize = kho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          TheKhoanLap(idaccount: 10, nguon: nguon, moForm: moForm ?? (_) async => null),
          const Text('DUOI THE'),
        ]),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('không có ứng viên (tai trả null) → không dựng gì, không chiếm chỗ', (tester) async {
    await _dung(tester, _NguonGia(null));
    expect(find.text('CÓ VẺ LÀ KHOẢN LẶP'), findsNothing);
    expect(tester.getSize(find.byType(TheKhoanLap)).height, 0,
        reason: 'thẻ ẩn không được để lại khoảng trắng giữa khối Nhận xét và hàng tab');
    expect(find.text('DUOI THE'), findsOneWidget);
  });

  testWidgets('ba dòng: tên, dòng phụ đúng tiền + chu kỳ + số lần, chip số khoản, ba nút Tạo',
      (tester) async {
    await _dung(tester, _NguonGia([
      _kl('Tiền nhà'),
      _kl('Gửi xe', tien: 50000, chuKy: kBillCycleWeek, soLan: 4),
      _kl('Netflix', tien: 260000),
    ]));
    expect(find.text('CÓ VẺ LÀ KHOẢN LẶP'), findsOneWidget);
    expect(find.text('3 khoản'), findsOneWidget);
    for (final t in ['Tiền nhà', 'Gửi xe', 'Netflix']) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('Tạo'), findsNWidgets(3));
    expect(find.text('Bỏ qua'), findsNWidgets(3));
    expect(find.text('khoảng ${CurrencyFormatter.format(3000000)} mỗi tháng · 3 lần'), findsOneWidget);
    expect(find.text('khoảng ${CurrencyFormatter.format(50000)} mỗi tuần · 4 lần'), findsOneWidget,
        reason: 'chu kỳ tuần phải nói "mỗi tuần" — nói "mỗi tháng" là sai số tiền gấp bốn');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bỏ qua → gọi boQua đúng tài khoản + khoá, dòng biến mất sau khi nạp lại',
      (tester) async {
    final n = _NguonGia([_kl('Tiền nhà'), _kl('Netflix', tien: 260000)]);
    await _dung(tester, n);
    await tester.tap(find.byKey(const ValueKey('khoan-lap-bo-qua-tiền nhà|c-nha')));
    await tester.pumpAndSettle();
    expect(n.boQuaGoi, [(10, 'tiền nhà|c-nha')]);
    expect(find.text('Tiền nhà'), findsNothing);
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('1 khoản'), findsOneWidget);
  });

  testWidgets('Bỏ qua dòng cuối cùng → cả thẻ biến mất', (tester) async {
    final n = _NguonGia([_kl('Tiền nhà')]);
    await _dung(tester, n);
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(find.text('CÓ VẺ LÀ KHOẢN LẶP'), findsNothing);
  });

  group('Tạo', () {
    testWidgets('mở form với đúng query của dòng; form trả true → ghi da_tao', (tester) async {
      final n = _NguonGia([_kl('Tiền nhà'), _kl('Netflix', tien: 260000)]);
      Map<String, String>? nhan;
      await _dung(tester, n, moForm: (q) async {
        nhan = q;
        return true;
      });
      await tester.tap(find.byKey(const ValueKey('khoan-lap-tao-netflix|c-nha')));
      await tester.pumpAndSettle();
      expect(nhan, queryTuKhoanLap(_kl('Netflix', tien: 260000)));
      expect(n.daTaoGoi, [(10, 'netflix|c-nha')]);
      expect(find.text('Netflix'), findsNothing);
    });

    for (final kq in [null, false]) {
      testWidgets('form trả $kq (thoát không lưu) → KHÔNG ghi da_tao', (tester) async {
        final n = _NguonGia([_kl('Tiền nhà')]);
        await _dung(tester, n, moForm: (_) async => kq);
        await tester.tap(find.text('Tạo'));
        await tester.pumpAndSettle();
        expect(n.daTaoGoi, isEmpty,
            reason: 'thoát form không lưu mà ẩn nhóm là mất gợi ý người dùng chưa từ chối');
        expect(find.text('Tiền nhà'), findsOneWidget);
      });
    }
  });

  testWidgets('khổ 360 × 640, ba dòng tên và số tiền dài → không tràn', (tester) async {
    await _dung(
      tester,
      _NguonGia([
        _kl('Tiền thuê căn hộ chung cư tầng mười hai khu đô thị mới', tien: 9999999999999),
        _kl('Học phí lớp tiếng Anh giao tiếp buổi tối cho con', tien: 12500000),
        _kl('Gửi xe tháng ở toà nhà văn phòng trung tâm', tien: 50000, chuKy: kBillCycleWeek),
      ]),
      kho: const Size(360, 640),
    );
    expect(tester.takeException(), isNull);
  });
}
