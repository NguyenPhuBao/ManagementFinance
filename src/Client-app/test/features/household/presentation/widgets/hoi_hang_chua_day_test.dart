/// Hộp hỏi lại khi Rời nhà / Giải tán còn hàng chưa đẩy (Stitch `1e99ebfa`, đợt 1B Task 4). Thiếu hộp này thì người có hàng bị
/// server từ chối vĩnh viễn không rời được nhà.
library;

import 'package:flowmoney/features/household/data/repositories/nha_repository_impl.dart';
import 'package:flowmoney/features/household/data/nha_store.dart';
import 'package:flowmoney/features/household/domain/cau_loi_nha.dart';
import 'package:flowmoney/features/household/domain/hang_chua_day.dart';
import 'package:flowmoney/features/household/presentation/bloc/nha_cubit.dart';
import 'package:flowmoney/features/household/presentation/widgets/hoi_hang_chua_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/bat_thong_bao.dart';
import '../../../../helpers/font_that.dart';
import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

void main() {
  setUpAll(napFontThat);

  late HouseholdApiGia api;
  late NhaCubit cubit;
  late BuildContext ctx;
  late BatThongBao bat;
  late HangChuaDayNha hang;
  var con = 0;
  var soLanMoTa = 0;
  bool? ketQua;

  Future<void> mo(WidgetTester t, {double co = 1.0, int conBanDau = 2}) async {
    dat360(t);
    t.platformDispatcher.textScaleFactorTestValue = co;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    bat = batThongBao();
    api = HouseholdApiGia()..cuaToiJson = nhaJson(myRole: 'Member');
    con = conBanDau;
    soLanMoTa = 0;
    ketQua = null;
    final repo = NhaRepositoryImpl(api: api, kho: InMemoryNhaStore(), demHangChuaDay: (_) async => con);
    addTearDown(repo.dispose);
    await repo.datTaiKhoan(18);
    await repo.lamMoi();
    cubit = NhaCubit(repo);
    addTearDown(cubit.close);
    await t.pumpWidget(bocTrangNha(Builder(builder: (c) {
      ctx = c;
      return const Scaffold();
    })));
  }

  /// Chạy lượt rời nhà qua hộp; KHÔNG `await` mù (hộp mở thì future chưa xong).
  Future<void> chay(WidgetTester t, {bool giaiTan = false}) async {
    final f = lamCoHoiHangChuaDay(
      ctx,
      cubit: cubit,
      viec: giaiTan ? cubit.giaiTan : cubit.roiNha,
      moTa: () async {
        soLanMoTa++;
        return hang;
      },
      nhanLam: giaiTan ? 'Vẫn giải tán' : 'Vẫn rời nhà',
      giaiTan: giaiTan,
    );
    f.then((v) => ketQua = v);
    await t.pumpAndSettle();
  }

  testWidgets('Rời nhà còn hàng chưa đẩy: hộp nêu từng loại, Ở lại thì không gọi lại', (t) async {
    await mo(t);
    hang = const HangChuaDayNha(khoan: 2, gop: 1, rut: 1, vi: 1, danhMuc: 1);
    await chay(t);
    expect(find.text('Còn thay đổi chưa đồng bộ'), findsOneWidget);
    expect(find.text('Những thay đổi này chưa lên máy chủ và sẽ mất nếu bạn rời nhà:'), findsOneWidget);
    expect(find.text('2 khoản của nhà'), findsOneWidget);
    expect(find.text('1 khoản góp, 1 khoản rút'), findsOneWidget);
    expect(find.text('1 ví chung'), findsOneWidget);
    expect(find.text('1 danh mục của nhà'), findsOneWidget);
    expect(find.text('Tiền của khoản góp và rút chưa đồng bộ được trả lại ví riêng của bạn.'), findsOneWidget);
    await t.tap(find.text('Ở lại'));
    await t.pumpAndSettle();
    expect(ketQua, isFalse);
    expect(api.goi, isNot(contains('roiNha')), reason: 'Ở lại thì không được gọi API rời nhà');
    expect(bat.ds, isEmpty, reason: 'người dùng tự chọn ở lại, không có lỗi để báo');
  });

  testWidgets('Vẫn rời nhà gọi repo với boQuaHangChuaDay true', (t) async {
    await mo(t);
    hang = const HangChuaDayNha(khoan: 2);
    await chay(t);
    await t.tap(find.widgetWithText(FilledButton, 'Vẫn rời nhà'));
    await t.pumpAndSettle();
    expect(ketQua, isTrue);
    expect(api.goi.where((g) => g == 'roiNha'), hasLength(1), reason: 'đúng một lời gọi rời nhà, sau khi người dùng đồng ý');
    expect(soLanMoTa, 1);
  });

  testWidgets('FINAL: đếm hàng chưa đẩy (moTa) ném — trả false và báo câu, không để lỗi bay ra ngoài', (t) async {
    await mo(t);
    Object? loiBay;
    final f = lamCoHoiHangChuaDay(
      ctx,
      cubit: cubit,
      viec: cubit.roiNha,
      moTa: () async => throw StateError('đọc hàng chờ hỏng'),
      nhanLam: 'Vẫn rời nhà',
    );
    f.then((v) => ketQua = v, onError: (Object e) => loiBay = e);
    await t.pumpAndSettle();
    expect(loiBay, isNull,
        reason: 'lỗi bay ra `unawaited(_roiNha())`: không hộp, không toast; ở Giải tán còn nhảy qua `_tuThaoTac = false`');
    expect(ketQua, isFalse);
    expect(bat.cau, [cauLoiNha(LoaiLoiNha.hangChuaDay)], reason: 'phải có câu, không im lặng');
    expect(api.goi, isNot(contains('roiNha')));
  });

  testWidgets('Giải tán: câu và nút ghi giải tán', (t) async {
    await mo(t);
    hang = const HangChuaDayNha(khoan: 1);
    await chay(t, giaiTan: true);
    expect(find.text('Những thay đổi này chưa lên máy chủ và sẽ mất nếu bạn giải tán nhà:'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Vẫn giải tán'));
    await t.pumpAndSettle();
    expect(api.goi, contains('giaiTan'));
    expect(ketQua, isTrue);
  });

  testWidgets('hàng không góp / rút thì không có câu trả tiền', (t) async {
    await mo(t);
    hang = const HangChuaDayNha(khoan: 3, vi: 1);
    await chay(t);
    expect(find.textContaining('trả lại ví riêng'), findsNothing, reason: 'không có nửa của tôi nào được trả tiền');
    expect(find.text('3 khoản của nhà'), findsOneWidget);
  });

  testWidgets('đếm lại ra rỗng: lượt bù vừa đẩy xong, làm lại không hỏi', (t) async {
    await mo(t);
    // Lượt thứ nhất bị từ chối (còn 2); lúc đếm lại cho hộp thì lượt bù vừa đẩy xong (còn 0).
    final f = lamCoHoiHangChuaDay(
      ctx,
      cubit: cubit,
      viec: cubit.roiNha,
      moTa: () async {
        soLanMoTa++;
        con = 0;
        return const HangChuaDayNha();
      },
      nhanLam: 'Vẫn rời nhà',
    );
    f.then((v) => ketQua = v);
    await t.pumpAndSettle();
    expect(find.text('Còn thay đổi chưa đồng bộ'), findsNothing, reason: 'hết hàng thì không có gì để hỏi');
    expect(ketQua, isTrue);
    expect(api.goi, contains('roiNha'));
  });

  testWidgets('đếm lại rỗng mà repo vẫn từ chối: tự báo, không im lặng', (t) async {
    await mo(t);
    hang = const HangChuaDayNha();
    await chay(t);
    expect(ketQua, isFalse);
    expect(bat.cuoi?.cau, cauLoiNha(LoaiLoiNha.hangChuaDay), reason: '`_lam` không toast cho hangChuaDay nên chỗ này phải báo');
    expect(api.goi, isNot(contains('roiNha')));
  });

  for (final co in [1.0, 1.5]) {
    testWidgets('360 dp, cỡ chữ $co: hộp không tràn, nút vẫn thấy', (t) async {
      await mo(t, co: co);
      hang = const HangChuaDayNha(khoan: 12, gop: 3, rut: 2, vi: 4, danhMuc: 5, khac: 1);
      await chay(t);
      expect(t.takeException(), isNull);
      expect(find.widgetWithText(FilledButton, 'Vẫn rời nhà'), findsOneWidget);
      final nut = t.getRect(find.widgetWithText(FilledButton, 'Vẫn rời nhà'));
      expect(nut.right, lessThanOrEqualTo(360), reason: 'nút nguy hiểm không được rơi khỏi màn');
      expect(nut.bottom, lessThanOrEqualTo(800));
    });
  }
}
