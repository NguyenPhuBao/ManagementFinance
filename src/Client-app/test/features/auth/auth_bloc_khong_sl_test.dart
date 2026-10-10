/// Test quét thứ **24** (spec bịt điểm rò 2026-10-10, mục 6.4): `AuthBloc` không chạm service locator.
/// Trước đợt này nó gọi `sl<…>` 23 lần và là điểm ghép thật của phiên; nay mọi dịch vụ đi qua `PhienDieuPhoi`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth_bloc.dart không chứa sl< / sl.isRegistered và không import core/di', () {
    final dongs = File('lib/features/auth/presentation/bloc/auth_bloc.dart')
        .readAsLinesSync()
        .where((d) => !d.trimLeft().startsWith('//'))
        .toList();
    expect(dongs, isNotEmpty, reason: 'Chạy từ src/Client-app.');
    final viPham = dongs.where((d) => d.contains('sl<') || d.contains('sl.isRegistered') || d.contains('core/di/'));
    expect(viPham, isEmpty, reason: 'AuthBloc chỉ giữ trạng thái; dịch vụ phiên đi qua PhienDieuPhoi.');
  });
}
