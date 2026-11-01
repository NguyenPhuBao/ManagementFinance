import 'package:flowmoney/features/household/presentation/bloc/nha_cubit.dart';
import 'package:flowmoney/features/household/presentation/widgets/gac_vai_chu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/bat_thong_bao.dart';
import '../../../../helpers/household_api_gia.dart';
import '../../../../helpers/nha_gia.dart';

void main() {
  Future<(HouseholdApiGia, dynamic, BatThongBao)> mo(WidgetTester t, {bool Function()? tuLam}) async {
    final bat = batThongBao();
    final api = HouseholdApiGia()..cuaToiJson = nhaJson();
    final repo = await repoNhaThu(api);
    final cubit = NhaCubit(repo);
    addTearDown(cubit.close);
    final r = routerThu(BlocProvider.value(
      value: cubit,
      child: GacVaiChu(dangTuThaoTac: tuLam ?? () => false, child: const Scaffold(body: Text('MAN CHU'))),
    ));
    await t.pumpWidget(bocRouterNha(r));
    r.push('/dich');
    await t.pumpAndSettle();
    return (api, repo, bat);
  }

  testWidgets('mất vai Chủ do máy khác: báo và pop về trang trước, không thay stack', (t) async {
    final (api, repo, bat) = await mo(t);
    api.cuaToiJson = nhaJson(myRole: 'Member');
    await repo.lamMoi();
    await t.pumpAndSettle();
    expect(find.text('GOC'), findsOneWidget, reason: 'go thì stack mất, Back thoát app');
    expect(bat.cau, ['Bạn không còn là chủ nhà.']);
  });

  testWidgets('nhà giải tán: câu riêng', (t) async {
    final (api, repo, bat) = await mo(t);
    api.cuaToiJson = const {'household': null};
    await repo.lamMoi();
    await t.pumpAndSettle();
    expect(find.text('GOC'), findsOneWidget);
    expect(bat.cau, ['Bạn không còn ở nhà này.']);
  });

  testWidgets('tự mình chuyển chủ: không báo, không pop hộ (trang tự pop một lần)', (t) async {
    final (api, repo, bat) = await mo(t, tuLam: () => true);
    api.cuaToiJson = nhaJson(myRole: 'Member');
    await repo.lamMoi();
    await t.pumpAndSettle();
    expect(find.text('MAN CHU'), findsOneWidget, reason: 'pop hộ + trang tự pop là pop hai lần, văng khỏi /nha');
    expect(bat.cau, isEmpty);
  });

  testWidgets('đang mở hộp thoại lúc mất vai: đóng hộp trước, pop đúng trang', (t) async {
    final (api, repo, _) = await mo(t);
    showDialog<void>(context: t.element(find.text('MAN CHU')), builder: (_) => const AlertDialog(content: Text('HOP')));
    await t.pumpAndSettle();
    api.cuaToiJson = nhaJson(myRole: 'Member');
    await repo.lamMoi();
    await t.pumpAndSettle();
    expect(find.text('HOP'), findsNothing);
    expect(find.text('GOC'), findsOneWidget);
  });

  testWidgets('phiên đóng (đăng xuất cưỡng chế): không báo, không pop', (t) async {
    final (_, repo, bat) = await mo(t);
    repo.xoaPhien();
    await t.pumpAndSettle();
    expect(find.text('MAN CHU'), findsOneWidget, reason: 'xoaPhien phát khongCo nhưng không phải mất nhà');
    expect(bat.cau, isEmpty);
  });
}
