/// Công tắc "Kích hoạt hoạt động" trên màn Sửa ví.
///
/// Thiết kế Stitch của màn *"Chỉnh Sửa Ví"* (`5a8f2b3b48974a8f9c0a10428e537466`)
/// có công tắc này từ đầu, cạnh "Ví mặc định" và "Tính vào tổng tài sản".
///
/// ⚠️ Bẫy của riêng màn này: nó **không** đi qua `WalletCubit`, mà gọi thẳng
/// `WalletRepository.updateWallet`. Gắn công tắc vào `copyWith(status: ...)` là
/// ghi trạng thái lưu trữ bằng một đường **không có chốt chặn nào** — người
/// dùng lưu trữ được cả ví mặc định lẫn ví hoạt động cuối cùng, đúng hai thứ
/// `setArchived` sinh ra để ngăn, và cả hai đều hỏng im lặng.
///
/// Vì thế màn này phải gọi `setArchived` cho phần trạng thái, và `updateWallet`
/// cho mọi thứ còn lại.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flowmoney/features/wallet/presentation/pages/wallet_edit_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

class _RepoGhiLai implements WalletRepository {
  _RepoGhiLai(this.vi);

  WalletEntity vi;

  /// Lỗi mà `setArchived` ném ra, nếu ca test dựng đường chốt chặn.
  Object? loiKhiLuuTru;

  final List<({String id, bool luuTru})> luoiGoiSetArchived = [];
  final List<WalletEntity> luoiGoiUpdate = [];

  @override
  Future<WalletEntity?> getById(String id) async => vi;

  @override
  Future<void> updateWallet(WalletEntity wallet) async {
    luoiGoiUpdate.add(wallet);
    vi = wallet;
  }

  @override
  Future<void> setArchived(String id, {required bool luuTru}) async {
    if (loiKhiLuuTru != null) throw loiKhiLuuTru!;
    luoiGoiSetArchived.add((id: id, luuTru: luuTru));
    vi = vi.copyWith(status: luuTru ? 'inactive' : 'active');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WalletEntity _vi({String status = 'active'}) => WalletEntity(
      id: 'w1',
      idaccount: 10,
      name: 'Tiền mặt',
      type: 'cash',
      balance: 1000000,
      status: status,
      updatedAt: DateTime(2026, 9, 10),
    );

/// Chạm vào một widget nằm ngoài vùng nhìn thấy.
///
/// Màn Sửa ví dài hơn một màn hình điện thoại, nên nút Lưu và cả khối công
/// tắc đều nằm dưới nếp gấp. `tap()` trần chỉ **cảnh báo** rồi trả về bình
/// thường — test đỏ ở dòng `expect` cách đó vài dòng, với thông điệp không
/// liên quan gì tới việc cuộn.
Future<void> _chamSauKhiCuon(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _moTrang(WidgetTester tester, WalletRepository repo) async {
  if (sl.isRegistered<WalletRepository>()) {
    await sl.unregister<WalletRepository>();
  }
  sl.registerSingleton<WalletRepository>(repo);
  addTearDown(() async {
    if (sl.isRegistered<WalletRepository>()) {
      await sl.unregister<WalletRepository>();
    }
  });

  // 411dp — khổ điện thoại thật, không phải 800x600 mặc định của bộ test.
  tester.view.physicalSize = const Size(411 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: const WalletEditPage(id: 'w1'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('màn Sửa ví có công tắc "Kích hoạt hoạt động"', (tester) async {
    await _moTrang(tester, _RepoGhiLai(_vi()));

    expect(find.text('Kích hoạt hoạt động'), findsOneWidget,
        reason: 'Đúng chữ của thiết kế Stitch cho màn này.');
  });

  testWidgets('công tắc BẬT với ví đang hoạt động, TẮT với ví đã lưu trữ',
      (tester) async {
    await _moTrang(tester, _RepoGhiLai(_vi(status: 'inactive')));

    // Công tắc lưu trữ là công tắc CUỐI trong khối ba công tắc, theo thứ tự
    // của thiết kế Stitch: Ví mặc định → Tính vào tổng tài sản → Kích hoạt.
    final congTac = tester.widget<Switch>(find.byType(Switch).last);
    expect(congTac.value, isFalse,
        reason: 'Công tắc phải đọc trạng thái THẬT của ví. Luôn bật là người '
            'dùng mở ví đã lưu trữ ra và tưởng nó đang chạy.');
  });

  testWidgets('tắt công tắc rồi Lưu thì đi qua setArchived, KHÔNG qua updateWallet',
      (tester) async {
    final repo = _RepoGhiLai(_vi());
    await _moTrang(tester, repo);

    await _chamSauKhiCuon(tester, find.byType(Switch).last);
    await _chamSauKhiCuon(tester, find.text('Lưu & Cập Nhật Ví'));

    expect(repo.luoiGoiSetArchived, [(id: 'w1', luuTru: true)],
        reason: 'Hai chốt chặn (không lưu trữ ví mặc định, không lưu trữ ví '
            'hoạt động cuối cùng) chỉ nằm trong `setArchived`. Ghi trạng thái '
            'bằng `copyWith` + `updateWallet` là đi vòng qua CẢ HAI, im lặng.');
    for (final w in repo.luoiGoiUpdate) {
      expect(w.status, 'active',
          reason: '`updateWallet` phải giữ nguyên trạng thái cũ. Nó mang trạng '
              'thái mới nghĩa là vẫn còn một đường ghi thứ hai, và đường ấy '
              'không qua chốt chặn nào.');
    }
  });

  testWidgets('không đụng công tắc thì KHÔNG gọi setArchived', (tester) async {
    final repo = _RepoGhiLai(_vi());
    await _moTrang(tester, repo);

    await _chamSauKhiCuon(tester, find.text('Lưu & Cập Nhật Ví'));

    expect(repo.luoiGoiSetArchived, isEmpty,
        reason: 'Mỗi lần gọi là một lần ghi và một lần vào hàng đợi đẩy. Sửa '
            'tên ví không được kéo theo một lượt đẩy trạng thái vô ích.');
    expect(repo.luoiGoiUpdate, isNotEmpty);
  });

  testWidgets('chốt chặn chặn được từ màn Sửa ví, và nói ra lý do',
      (tester) async {
    final repo = _RepoGhiLai(_vi())
      ..loiKhiLuuTru =
          const CacheException('Ví "Tiền mặt" đang là ví mặc định.');
    await _moTrang(tester, repo);

    await _chamSauKhiCuon(tester, find.byType(Switch).last);
    await _chamSauKhiCuon(tester, find.text('Lưu & Cập Nhật Ví'));

    expect(find.textContaining('ví mặc định'), findsWidgets,
        reason: 'Chốt chặn ném lỗi mà màn hình nuốt lặng thì người dùng bấm '
            'Lưu, trang đóng lại, và ví vẫn nguyên như cũ — không lời giải '
            'thích nào.');
  });
}
