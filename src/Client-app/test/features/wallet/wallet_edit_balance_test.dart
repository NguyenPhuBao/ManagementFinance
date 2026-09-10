/// Ô số dư trên màn Sửa ví — nay là đường **đối soát**, không còn ghi đè.
///
/// ## Lỗ mà nó bịt
///
/// Trước bản này ô ấy ghi thẳng vào cột `balance` qua `updateWallet`. Nghĩa là
/// số dư ví **trôi khỏi lịch sử giao dịch** mà không có dòng nào giải thích:
/// cộng hết giao dịch của ví ra một số, ví hiện một số khác, và không màn nào
/// nói vì sao. Đó cũng là thứ khiến "số dư cuối kỳ" của báo cáo — vốn suy ngược
/// từ số dư hiện tại — không đối chiếu được với gì cả.
///
/// Nay sửa ô ấy **sinh một khoản điều chỉnh**: lịch sử tự khớp lại, và người
/// dùng xoá nhầm khoản bù thì số dư quay về như cũ.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/di/injection_container.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/data/repositories/wallet_repository.dart';
import 'package:flowmoney/features/wallet/data/services/dieu_chinh_so_du_service.dart';
import 'package:flowmoney/features/wallet/presentation/pages/wallet_edit_page.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';

class _RepoGhiLai implements WalletRepository {
  _RepoGhiLai(this.vi);

  WalletEntity vi;
  final List<WalletEntity> luoiGoiUpdate = [];

  @override
  Future<WalletEntity?> getById(String id) async => vi;

  @override
  Future<void> updateWallet(WalletEntity wallet) async {
    luoiGoiUpdate.add(wallet);
    vi = wallet;
  }

  @override
  Future<void> setArchived(String id, {required bool luuTru}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Ghi lại lời gọi thay vì đụng CSDL — đường ghi thật đã có test riêng ở
/// `dieu_chinh_so_du_service_test.dart`.
class _DichVuGia implements DieuChinhSoDuService {
  final List<({String walletId, double soDuThucTe, String lyDo})> loiGoi = [];

  @override
  Future<void> dieuChinh({
    required String walletId,
    required double soDuThucTe,
    required String lyDo,
    DateTime? vaoLuc,
  }) async {
    loiGoi.add((walletId: walletId, soDuThucTe: soDuThucTe, lyDo: lyDo));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _chamSauKhiCuon(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _moTrang(
  WidgetTester tester,
  WalletRepository repo,
  DieuChinhSoDuService dichVu,
) async {
  for (final huy in [
    () async {
      if (sl.isRegistered<WalletRepository>()) {
        await sl.unregister<WalletRepository>();
      }
    },
    () async {
      if (sl.isRegistered<DieuChinhSoDuService>()) {
        await sl.unregister<DieuChinhSoDuService>();
      }
    },
  ]) {
    await huy();
    addTearDown(huy);
  }
  sl.registerSingleton<WalletRepository>(repo);
  sl.registerSingleton<DieuChinhSoDuService>(dichVu);

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

WalletEntity _vi({double soDu = 1000000}) => WalletEntity(
      id: 'w1',
      idaccount: 10,
      name: 'Tiền mặt',
      type: 'cash',
      balance: soDu,
      updatedAt: DateTime(2026, 9, 10),
    );

void main() {
  testWidgets('sửa ô số dư thì đi qua đường ĐỐI SOÁT, không ghi đè',
      (tester) async {
    final repo = _RepoGhiLai(_vi());
    final dichVu = _DichVuGia();
    await _moTrang(tester, repo, dichVu);

    await tester.enterText(find.byType(TextField).at(1), '1250000');
    await tester.pumpAndSettle();
    await _chamSauKhiCuon(tester, find.text('Lưu & Cập Nhật Ví'));

    expect(dichVu.loiGoi.length, 1,
        reason: 'Ô số dư phải sinh một khoản điều chỉnh. Không gọi nghĩa là nó '
            'vẫn đang ghi đè, và số dư lại trôi khỏi lịch sử giao dịch.');
    expect(dichVu.loiGoi.single.walletId, 'w1');
    expect(dichVu.loiGoi.single.soDuThucTe, 1250000);

    for (final w in repo.luoiGoiUpdate) {
      expect(w.balance, 1000000,
          reason: '`updateWallet` phải giữ NGUYÊN số dư cũ. Nó mang số mới '
              'nghĩa là vẫn còn đường ghi đè thứ hai — và khi ấy số dư bị cộng '
              'hai lần: một lần ghi đè, một lần bởi khoản bù.');
    }
  });

  testWidgets('KHÔNG đụng ô số dư thì KHÔNG sinh khoản điều chỉnh nào',
      (tester) async {
    final repo = _RepoGhiLai(_vi());
    final dichVu = _DichVuGia();
    await _moTrang(tester, repo, dichVu);

    await tester.enterText(find.byType(TextField).first, 'Ví tiền mặt');
    await tester.pumpAndSettle();
    await _chamSauKhiCuon(tester, find.text('Lưu & Cập Nhật Ví'));

    expect(dichVu.loiGoi, isEmpty,
        reason: 'Sửa tên ví không được đẻ ra một dòng trong sổ giao dịch.');
    expect(repo.luoiGoiUpdate, isNotEmpty);
  });

  testWidgets('có dòng giải thích rằng sửa số dư sẽ tạo khoản điều chỉnh',
      (tester) async {
    await _moTrang(tester, _RepoGhiLai(_vi()), _DichVuGia());

    expect(find.textContaining('điều chỉnh'), findsWidgets,
        reason: 'Đây là đổi HÀNH VI của một ô đang chạy: hôm qua sửa số dư là '
            'ghi đè lặng lẽ, hôm nay là ghi một dòng vào sổ. Không nói ra thì '
            'người dùng thấy sổ giao dịch mọc thêm dòng lạ.');
  });
}
