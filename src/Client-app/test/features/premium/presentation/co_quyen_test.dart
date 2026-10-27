import 'package:flowmoney/features/premium/data/repositories/goi_repository.dart';
import 'package:flowmoney/features/premium/data/goi_store.dart';
import 'package:flowmoney/features/premium/data/datasources/payment_api.dart';
import 'package:flowmoney/features/premium/domain/quyen_tinh_nang.dart';
import 'package:flowmoney/features/premium/data/models/trang_thai_goi.dart';
import 'package:flowmoney/features/premium/domain/hang_goi.dart';
import 'package:flowmoney/features/premium/presentation/bloc/co_quyen.dart';
import 'package:flowmoney/features/premium/presentation/bloc/goi_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/goi_gia.dart';

class _ApiIm implements PaymentApi {
  @override
  Future<Map<String, Object?>> thongTinGoi() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> taoDon() => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> trangThaiDon(int orderCode) => throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> lichSu({int page = 1, int limit = 20}) => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> xacNhanNangCap({required int orderCode, required bool accept}) => throw UnimplementedError();
}

void main() {
  final now = DateTime(2026, 10, 8, 12);

  testWidgets('không có GoiCubit → true (quy ước: không provider = không khoá)', (tester) async {
    late bool kq;
    await tester.pumpWidget(Builder(builder: (c) {
      kq = c.coQuyen(MaQuyen.cashflowForecast);
      return const SizedBox();
    }));
    expect(kq, isTrue);
  });

  testWidgets('bảng quyền đổi → trang dựng lại với giá trị mới', (tester) async {
    final repo = GoiRepository(api: _ApiIm(), kho: InMemoryGoiStore(), clock: () => now);
    final cubit = GoiCubit(repo, clock: () => now);
    addTearDown(() async {
      await cubit.close();
      await repo.dispose();
    });
    await tester.pumpWidget(BlocProvider<GoiCubit>.value(
      value: cubit,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (c) => Text(c.coQuyen(MaQuyen.cashflowForecast) ? 'MỞ' : 'KHOÁ')),
      ),
    ));
    expect(find.text('MỞ'), findsOneWidget);
    cubit.emit(TrangThaiGoi(
        loai: LoaiGoi.basic, nhanLuc: now, quyenTinhNang: const {'cashflow_forecast': false}));
    await tester.pump();
    await tester.pump();
    expect(find.text('KHOÁ'), findsOneWidget);
  });

  testWidgets('trangThaiQuyen: không provider → mo; Premium bảng tắt → tamNgung', (tester) async {
    late TrangThaiQuyen khongCo;
    await tester.pumpWidget(Builder(builder: (c) {
      khongCo = c.trangThaiQuyen(MaQuyen.exportReports);
      return const SizedBox();
    }));
    expect(khongCo, TrangThaiQuyen.mo);

    final cubit = goiPremium(const {'export_reports': false}, now: now);
    late TrangThaiQuyen co;
    await tester.pumpWidget(BlocProvider<GoiCubit>.value(
      value: cubit,
      child: Builder(builder: (c) {
        co = c.trangThaiQuyen(MaQuyen.exportReports);
        return const SizedBox();
      }),
    ));
    expect(co, TrangThaiQuyen.tamNgung);
  });
}
