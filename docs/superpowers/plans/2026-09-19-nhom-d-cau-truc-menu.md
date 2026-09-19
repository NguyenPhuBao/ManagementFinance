# Nhóm D — cấu trúc menu và điều hướng: kế hoạch thi công

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dựng lại điều hướng FlowMoney theo lối B — thanh dưới mang Sổ giao dịch, drawer thành menu của mọi thứ còn lại, tab Cá nhân gộp trang Cài đặt, Trang chủ bớt ba khối thừa.

**Architecture:** Bốn `StatefulShellBranch` giữ nguyên số lượng; nhánh thứ ba đổi route từ `/budget` sang `/transactions`, còn `/budget` thành route gốc. Hằng `nhanhThanhTab` phải đổi cùng nhịp vì nó là thứ quyết định thông báo dùng `go` hay `push`. Drawer và tab Cá nhân chỉ là dữ liệu và widget, không đụng CSDL.

**Tech Stack:** Flutter, go_router (`StatefulShellRoute.indexedStack`), flutter_bloc, Drift/SQLite.

**Spec:** `docs/superpowers/specs/2026-09-19-nhom-d-cau-truc-menu-design.md`

## Global Constraints

- **Chỉ sửa `src/Client-app`.** Không đụng `src/Backend`, không đụng `src/Admin-web`.
- **Không đổi schema, không thêm trường đồng bộ.** Schema giữ **v23**; payload giao dịch **13 trường**, ví **13 trường**, hoá đơn **21 trường**, mục tiêu **22 trường**.
- **Mức nền phải giữ:** `flutter analyze` = **25 issue, không có error**. Bộ test khởi điểm **2937/2937 pass, 1 ca `skip` cố ý**.
- **`test/` và `docs/superpowers/{specs,plans}` bị `.gitignore`** → luôn `git add -f` **từng đường dẫn**; `git add <thư mục>` thất bại và không stage gì cả.
- **Test hành vi điều hướng phải dựng `GoRouter` thật**, không `MaterialApp` trần — bẫy shell chỉ nổ khi có cây route thật.
- **Nghiệm thu máy ảo bắt buộc** trước khi báo xong: `emulator -avd FlowMoney_16G -gpu swangle`, `flutter build apk --debug`, `adb install -r`, `adb shell am start -n com.flowmoney.flowmoney/.MainActivity`. `adb` ở `%LOCALAPPDATA%/Android/Sdk/platform-tools/adb.exe`.
- **Đừng ngắt `flutter test` giữa chừng** và đừng chạy hai lần cùng lúc — `flutter_tester.exe` mồ côi giữ `sqlite3.dll` và mọi lần chạy sau nổ `PathExistsException`.

---

## File Structure

| Tệp | Trách nhiệm sau khi sửa |
|---|---|
| `lib/core/constants/app_router.dart` | Nhánh shell thứ ba thành `/transactions`; `/budget` thành route gốc |
| `lib/core/notification/notification_deeplink.dart` | Hằng `nhanhThanhTab` khớp bốn nhánh mới |
| `lib/shared/widgets/main_shell.dart` | Nhãn + icon mục thứ tư của thanh dưới |
| `lib/features/wallet/presentation/pages/wallet_list_page.dart` | Hai lời gọi `push('/transactions…')` → `go` |
| `lib/features/home/presentation/pages/home_page.dart` | "Xem tất cả" → `go`; thẻ ngân sách → `push`; bỏ `_buildHeroSection` |
| `lib/features/home/presentation/widgets/home_action_buttons.dart` | **Xoá** — 0 chỗ gọi sau khi bỏ hero |
| `lib/features/home/presentation/widgets/drawer_trang_chu.dart` | `kMucDrawer` còn sáu mục |
| `lib/features/analytics/presentation/pages/analytics_page.dart` | Tiêu đề trang "Thống kê" → "Phân tích" |
| `lib/features/profile/presentation/pages/profile_page.dart` | Gộp thân trang Cài đặt vào; bỏ nhóm QUẢN LÝ TÀI KHOẢN |

---

### Task 1: Thanh dưới, nhánh router và `nhanhThanhTab`

Bốn thay đổi này **phải cùng một commit**. Tách ra là để lại một bản app chết màn đỏ ở giữa: đổi router mà chưa đổi chỗ gọi thì nút "Xem giao dịch" ở màn Ví nổ; đổi router mà chưa đổi `nhanhThanhTab` thì thông báo "khoản chi lớn" nổ.

**Files:**
- Modify: `lib/core/constants/app_router.dart:153-156`
- Modify: `lib/core/notification/notification_deeplink.dart:11-16`
- Modify: `lib/shared/widgets/main_shell.dart:83`
- Modify: `lib/features/wallet/presentation/pages/wallet_list_page.dart:253`, `:457`
- Modify: `lib/features/home/presentation/pages/home_page.dart:478`, `:617`
- Modify: `test/core/notification/notification_deeplink_test.dart:38-42`
- Test: `test/shared/widgets/main_shell_tab_so_giao_dich_test.dart` (tạo mới)

**Interfaces:**
- Consumes: `AppRouter.createRouter(String initialLocation, AuthBloc bloc)` — đã có, dùng trong `drawer_trang_chu_test.dart`.
- Produces: hằng `nhanhThanhTab` mang `'/transactions'` thay `'/budget'`; nhãn thanh dưới thứ tư là chuỗi `'Giao dịch'`.

- [ ] **Step 1: Viết ca test đỏ cho `nhanhThanhTab`**

Sửa `test/core/notification/notification_deeplink_test.dart`, thay khối khẳng định ở dòng 38–42:

```dart
    test('bốn nhánh của thanh tab đều thuộc shell', () {
      expect(thuocThanhTab('/transactions'), isTrue,
          reason: 'Từ 2026-09-19 nhánh thứ ba là Sổ giao dịch. Luật "khoản chi '
              'lớn" deeplink thẳng vào đây; để `thuocThanhTab` trả false thì '
              'nơi gọi dùng `push` từ `/notifications` — một trang NGOÀI shell '
              '— và app chết màn đỏ.');
      expect(thuocThanhTab('/home'), isTrue);
      expect(thuocThanhTab('/analytics'), isTrue);
      expect(thuocThanhTab('/profile'), isTrue);
    });

    test('⚠️ `/budget` KHÔNG còn thuộc thanh tab', () {
      expect(thuocThanhTab('/budget'), isFalse,
          reason: 'Nó rời shell thành route gốc cùng ngày. Để sót `true` thì '
              'thông báo ngân sách `go` tới một route ngoài shell: thay cả '
              'stack, thanh tab biến mất, không còn đường quay lại.');
      expect(thuocThanhTab('/budget/detail/abc'), isFalse);
    });
```

- [ ] **Step 2: Chạy để xem nó đỏ**

Run: `flutter test test/core/notification/notification_deeplink_test.dart`
Expected: FAIL — `thuocThanhTab('/transactions')` trả `false`, `thuocThanhTab('/budget')` trả `true`.

- [ ] **Step 3: Đổi hằng `nhanhThanhTab`**

Trong `lib/core/notification/notification_deeplink.dart`, thay khối hằng:

```dart
/// Các route nằm **bên trong** `StatefulShellRoute.indexedStack` — tức là bốn
/// nhánh của thanh tab dưới cùng.
///
/// Giữ đồng bộ tay với `app_router.dart`. Đáng lẽ suy ra được từ cây route,
/// nhưng go_router không phơi ra danh sách ấy, và một hằng số có test canh thì
/// đọc rõ hơn hẳn một phép dò cây.
///
/// ⚠️ `/budget` **đã rời** danh sách này ngày 2026-09-19 (nhóm D): nó thành
/// route gốc, còn nhánh thứ ba nay là `/transactions`. Bộ luật thông báo sinh
/// deeplink tới **cả hai**, nên sai một dòng ở đây là một đường chết màn đỏ và
/// một đường làm thanh tab biến mất.
const Set<String> nhanhThanhTab = {
  '/home',
  '/analytics',
  '/transactions',
  '/profile',
};
```

- [ ] **Step 4: Chạy lại, phải xanh**

Run: `flutter test test/core/notification/notification_deeplink_test.dart`
Expected: PASS.

- [ ] **Step 5: Viết ca test đỏ cho thanh dưới và điều hướng**

Tạo `test/shared/widgets/main_shell_tab_so_giao_dich_test.dart`:

```dart
/// Thanh dưới mang tab Sổ giao dịch, và `/budget` rời shell — nhóm D,
/// 2026-09-19.
///
/// ⚠️ Phải dựng `GoRouter` **thật**. Bẫy `!keyReservation.contains(key)` chỉ
/// nổ khi có cây route thật; `MaterialApp` trần cho mọi ca xanh trong khi máy
/// ảo chết màn đỏ (cùng bài học `main_shell_back_test.dart`).
library;

import 'dart:io';

import 'package:flowmoney/core/constants/app_router.dart';
import 'package:flowmoney/core/notification/notification_deeplink.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/budget/presentation/pages/budget_page.dart';
import 'package:flowmoney/features/transaction/presentation/pages/transaction_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('⚠️ `nhanhThanhTab` khớp ĐÚNG danh sách nhánh khai trong router', () {
    // Hai nơi giữ tay là chỗ trôi lệch kinh điển của dự án. Ca này đọc thẳng
    // tệp router thay vì chép lại danh sách, nên thêm/bớt nhánh mà quên hằng
    // là đỏ ngay.
    final nguon = File('lib/core/constants/app_router.dart').readAsStringSync();
    final than = nguon.substring(
      nguon.indexOf('StatefulShellRoute.indexedStack'),
      nguon.indexOf('// Analytics & Report Export standalone routes'),
    );
    final duongTrongShell = RegExp(r"path: '(/[a-z-]+)'")
        .allMatches(than)
        .map((m) => m.group(1)!)
        .toSet();
    expect(duongTrongShell, nhanhThanhTab,
        reason: 'Sai lệch ở đây làm thông báo chọn nhầm `go`/`push`: một '
            'chiều chết màn đỏ, một chiều làm thanh tab biến mất.');
  });

  testWidgets('nhãn thứ tư là "Giao dịch" và KHÔNG tràn ô 72dp ở 411dp',
      (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: AppRouter.createRouter('/home', _blocGia()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Giao dịch'), findsOneWidget,
        reason: 'Ô nhãn rộng CỐ ĐỊNH 72dp và mọi nhãn đang chạy được đều ≤ 9 '
            'ký tự. "Sổ giao dịch" là 12 ký tự — tràn. Tên đầy đủ vẫn là Sổ '
            'giao dịch ở tiêu đề trang.');
    expect(find.text('Ngân sách'), findsNothing,
        reason: 'Ngân sách rời thanh dưới về drawer.');
    expect(tester.takeException(), isNull);
  });
}
```

⚠️ Ca đầu cần `import 'dart:io';`. Chép nguyên lớp giả từ `drawer_trang_chu_test.dart` và dựng router thật trong mỗi ca:

```dart
class _RepoGia implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GoRouter _routerThat() {
  final bloc = AuthBloc(authRepository: _RepoGia());
  addTearDown(bloc.close);
  final r = AppRouter.createRouter('/home', bloc);
  addTearDown(r.dispose);
  return r;
}
```

Thêm **bốn ca điều hướng** vào cùng tệp — đây là mục 1–4 của phần kiểm chứng trong spec, và là lý do cả task này tồn tại:

```dart
  testWidgets('⚠️ từ màn Quản lý ví bấm "Xem giao dịch" KHÔNG chết màn đỏ',
      (tester) async {
    final router = _routerThat();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // Màn Ví nằm NGOÀI shell — đúng tình huống làm nổ
    // `!keyReservation.contains(key)` nếu chỗ gọi còn dùng `push`.
    router.push('/wallets');
    await tester.pumpAndSettle();
    router.go('/transactions?wallet=cash');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'Ca chính của cả hạng mục: push một route trong shell từ một '
            'trang ngoài shell bắt go_router dựng bản shell thứ hai.');
    expect(find.byType(TransactionPage), findsOneWidget,
        reason: '⚠️ Chỉ takeException() isNull thì một màn trắng cũng xanh — '
            'phải đòi THẤY trang, cùng bài học G43.');
  });

  testWidgets('bốn tab chuyển qua lại được, không tab nào ném', (tester) async {
    final router = _routerThat();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    for (final duong in ['/analytics', '/transactions', '/profile', '/home']) {
      router.go(duong);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Chuyển sang $duong.');
    }
    expect(find.text('Giao dịch'), findsOneWidget,
        reason: 'Thanh dưới còn đó sau khi đi hết một vòng.');
  });

  testWidgets('"Xem tất cả" ở Trang chủ chuyển sang tab Sổ giao dịch',
      (tester) async {
    final router = _routerThat();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xem tất cả'));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('⚠️ thẻ ngân sách ở Trang chủ mở /budget CÓ nút Back',
      (tester) async {
    final router = _routerThat();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.push('/budget');
    await tester.pumpAndSettle();

    expect(find.byType(BudgetPage), findsOneWidget);
    expect(router.canPop(), isTrue,
        reason: '/budget rời shell nên nó chồng lên Trang chủ và PHẢI pop về '
            'được. Dùng go ở chỗ gọi là thay cả stack: thanh tab biến mất và '
            'không còn đường quay lại.');
  });
```

⚠️ Bốn ca này dựng `HomePage` thật, thứ đòi CSDL và `AuthBloc`. Nếu chúng ném vì thiếu DI thì **đừng nới lỏng khẳng định** — dựng DI như `test/features/home/the_cho_xoa_trang_chu_test.dart` đang làm, hoặc chuyển ca "Xem tất cả" sang tệp ấy nơi bộ giả đã có sẵn.

- [ ] **Step 6: Chạy để xem đỏ**

Run: `flutter test test/shared/widgets/main_shell_tab_so_giao_dich_test.dart`
Expected: FAIL — `nhanhThanhTab` chứa `/budget` còn router chứa `/transactions`; và `find.text('Giao dịch')` không thấy gì.

- [ ] **Step 7: Đổi nhánh shell trong router**

Trong `lib/core/constants/app_router.dart`, thay nhánh thứ ba:

```dart
              StatefulShellBranch(routes: [
                GoRoute(
                  // ⚠️ Nhánh này từng là `/budget`. Đổi sang Sổ giao dịch ngày
                  // 2026-09-19 (nhóm D): sổ là thứ mở nhiều lần mỗi ngày còn
                  // ngân sách là thứ đặt một lần rồi xem lại thỉnh thoảng.
                  // Đổi ở đây thì PHẢI đổi `nhanhThanhTab` cùng lúc.
                  path: '/transactions',
                  builder: (_, state) => TransactionPage(
                    initialWalletId: state.uri.queryParameters['wallet'],
                  ),
                ),
              ]),
```

Rồi **xoá** khối `GoRoute(path: '/transactions', …)` cũ ở dòng 181–189, và **thêm** `/budget` vào nhóm route gốc, đặt ngay trước `/budget/rules`:

```dart
          // Rời `StatefulShellRoute` ngày 2026-09-19 (nhóm D). Hai route con
          // `/budget/rules` và `/budget/detail/:id` vốn đã là route gốc, nên
          // chỗ này chỉ là đưa cha về đứng cùng các con.
          GoRoute(path: '/budget', builder: (_, __) => const BudgetPage()),
```

- [ ] **Step 8: Đổi nhãn và icon thanh dưới**

Trong `lib/shared/widgets/main_shell.dart`, thay dòng 83:

```dart
            // ⚠️ Nhãn "Giao dịch" chứ không "Sổ giao dịch": ô nhãn rộng CỐ
            // ĐỊNH 72dp và mọi nhãn vừa được đều ≤ 9 ký tự. Icon `list_alt`
            // chứ không `receipt_long` — `receipt_long` đã là Hóa đơn ở
            // drawer, và một glyph hai nghĩa đúng là lỗi D8 vừa gỡ.
            _buildNavItem(context, 'Giao dịch', Icons.list_alt_outlined, 3, uiIndex),
```

- [ ] **Step 9: Đổi bốn chỗ gọi điều hướng**

`lib/features/wallet/presentation/pages/wallet_list_page.dart` — cả dòng 253 và 457:

```dart
              // ⚠️ `go` chứ KHÔNG `push`: `/transactions` nay là nhánh shell,
              // còn màn này nằm NGOÀI shell (drawer push nó). `push` một route
              // trong shell từ ngoài shell bắt go_router dựng bản shell thứ
              // hai và Navigator ném `!keyReservation.contains(key)` — màn đỏ.
              onXemGiaoDich: () => context.go('/transactions?wallet=${w.id}'),
```

`lib/features/home/presentation/pages/home_page.dart:478`:

```dart
              // `go` để chuyển sang tab Sổ giao dịch thay vì chồng một trang
              // mới lên tab Trang chủ.
              onPressed: () => context.go('/transactions'),
```

`lib/features/home/presentation/pages/home_page.dart:617`:

```dart
        // `push` chứ không `go`: `/budget` rời shell ngày 2026-09-19, nên nó
        // cần một nút Back để quay lại Trang chủ.
        onTap: () => context.push('/budget'),
```

- [ ] **Step 10: Chạy hai tệp test, phải xanh**

Run: `flutter test test/shared/widgets/main_shell_tab_so_giao_dich_test.dart test/core/notification/notification_deeplink_test.dart`
Expected: PASS.

- [ ] **Step 11: Chạy toàn bộ và analyze**

Run: `flutter test` rồi `flutter analyze`
Expected: không ca nào đỏ ngoài những ca mô tả hành vi cũ (ví dụ ca canh `/budget` là tab). Ca nào đỏ vì mô tả hành vi cũ thì **sửa ca ấy kèm chú thích vì sao**, đừng nới lỏng khẳng định. `flutter analyze` phải về **25**.

- [ ] **Step 12: Commit**

```bash
git add src/Client-app/lib/core/constants/app_router.dart \
        src/Client-app/lib/core/notification/notification_deeplink.dart \
        src/Client-app/lib/shared/widgets/main_shell.dart \
        src/Client-app/lib/features/wallet/presentation/pages/wallet_list_page.dart \
        src/Client-app/lib/features/home/presentation/pages/home_page.dart
git add -f src/Client-app/test/shared/widgets/main_shell_tab_so_giao_dich_test.dart \
           src/Client-app/test/core/notification/notification_deeplink_test.dart
git commit -m "feat(nav): thanh dưới mang tab Sổ giao dịch, /budget rời shell — nhóm D"
```

---

### Task 2: Drawer còn bảy mục, và tên "Phân tích"

**Files:**
- Modify: `lib/features/home/presentation/widgets/drawer_trang_chu.dart:24-34`
- Modify: `lib/features/analytics/presentation/pages/analytics_page.dart` (tiêu đề trang)
- Modify: `test/features/home/drawer_trang_chu_test.dart`

**Interfaces:**
- Consumes: `MucDrawer(String nhan, IconData icon, String duong)` và hằng `kMucDrawer` — đã có.
- Produces: `kMucDrawer` còn sáu phần tử; không phần tử nào trùng nhãn thanh dưới.

- [ ] **Step 1: Viết ca test đỏ**

Thêm vào `test/features/home/drawer_trang_chu_test.dart`:

```dart
  test('⚠️ drawer KHÔNG chứa đích nào đã có ở thanh dưới', () {
    // Nguyên tắc của lối B: thanh dưới = việc hằng ngày, drawer = mọi thứ còn
    // lại, không đích nào xuất hiện ở cả hai chỗ. Bốn đường dưới đây là bốn
    // nhánh shell; thêm tab mới mà quên rút khỏi drawer là ca này đỏ.
    const duongThanhDuoi = {'/home', '/analytics', '/transactions', '/profile'};
    for (final m in kMucDrawer) {
      expect(duongThanhDuoi.contains(m.duong), isFalse,
          reason: 'Mục "${m.nhan}" (${m.duong}) đã có ở thanh dưới. Lặp lại ở '
              'drawer là dạy người dùng hai đường tới cùng một chỗ.');
    }
  });

  test('drawer còn đúng sáu mục, giữ nguyên thứ tự đã chốt', () {
    expect(kMucDrawer.map((m) => m.nhan).toList(), [
      'Quản lý ví',
      'Mục tiêu tiết kiệm',
      'Ngân sách',
      'Hóa đơn & Dịch vụ',
      'Xuất báo cáo',
      'Trợ lý AI',
    ]);
  });

  test('⚠️ không còn mục nào tên "Thống kê"', () {
    expect(kMucDrawer.any((m) => m.nhan == 'Thống kê'), isFalse,
        reason: 'Một đích hai tên: "Phân tích" ở tab, "Thống kê" ở đây. '
            'Drawer thôi có mục ấy nên tên còn lại là "Phân tích" (D4).');
  });
```

- [ ] **Step 2: Chạy để xem đỏ**

Run: `flutter test test/features/home/drawer_trang_chu_test.dart`
Expected: FAIL — drawer còn chín mục, trong đó `Thống kê`→`/analytics`, `Cá nhân`→`/profile` trùng thanh dưới.

- [ ] **Step 3: Rút `kMucDrawer` còn sáu mục**

```dart
/// Danh sách mục của drawer Trang chủ.
///
/// ⚠️ **Nguyên tắc từ 2026-09-19 (nhóm D, lối B):** thanh dưới giữ việc hằng
/// ngày, drawer giữ **mọi thứ còn lại**, và không đích nào xuất hiện ở cả hai
/// chỗ. Ba mục "Thống kê", "Cá nhân", "Cài đặt" đã rút khỏi đây vì chúng có
/// tab riêng; "Ngân sách" thì đi ngược chiều — rời thanh dưới về đây.
///
/// Là hằng công khai để test đối chiếu **từng đường với router thật**: bản
/// trước trỏ "Xuất báo cáo" vào `/reports` — một route không tồn tại — rồi che
/// bằng SnackBar "đang phát triển" trong khi trang ấy đã có từ 2026-09-09 ở
/// `/export-report`. Route và lời gọi là hai chuỗi rời nhau nên
/// `flutter analyze` không nói gì.
const List<MucDrawer> kMucDrawer = [
  MucDrawer('Quản lý ví', Icons.account_balance_wallet, '/wallets'),
  MucDrawer('Mục tiêu tiết kiệm', Icons.track_changes, '/goals'),
  MucDrawer('Ngân sách', Icons.savings, '/budget'),
  MucDrawer('Hóa đơn & Dịch vụ', Icons.receipt_long, '/bills'),
  // ⚠️ Mục này CHƯA BAO GIỜ có trong drawer cũ — nó sống ở tab Cá nhân. Bỏ
  // sót nó là trang Quản lý danh mục mất hẳn lối vào qua menu.
  MucDrawer('Danh mục', Icons.category_outlined, '/categories'),
  MucDrawer('Xuất báo cáo', Icons.description, '/export-report'),
  MucDrawer('Trợ lý AI', Icons.smart_toy, '/ai-chat'),
];
```

⚠️ Hằng `_mucDauNhomDuoi = 'Cá nhân'` nay không khớp mục nào nên vạch ngăn giữa danh sách biến mất — đúng ý (sáu mục là một nhóm). **Xoá hằng ấy và khối `if (m.nhan == _mucDauNhomDuoi)`** trong `build`, nếu không `flutter analyze` báo hằng không dùng và mức nền lên 26.

- [ ] **Step 4: Đổi tiêu đề trang Phân tích**

Chuỗi tiêu đề nằm ở **`analytics_page.dart:282`** (đo bằng máy 2026-09-19). Đổi thành:

```dart
            // Một đích một tên (D4, 2026-09-19): tab gọi là "Phân tích", nên
            // tiêu đề trang cũng thế. Drawer đã thôi có mục "Thống kê".
            'Phân tích',
```

⚠️ **Chỉ đổi dòng 282.** Ba chỗ "Thống kê" còn lại trong tệp (`:33`, `:266`, `:1435`) là **chú thích** nhắc tên màn Stitch và một ghi chú bố cục — đổi chúng là làm hỏng đường lần về bản thiết kế. Riêng `:266` nói *"ở 411dp thì 'Thống kê' + nút xuất + ô chọn tháng…"*: "Phân tích" cũng đúng **9 ký tự** nên phép đo ấy không đổi, nhưng **vẫn phải nhìn lại trên máy ảo** vì đó là hàng đã từng tràn 53px.

- [ ] **Step 5: Chạy test và analyze**

Run: `flutter test test/features/home test/features/analytics` rồi `flutter analyze`
Expected: PASS; analyze về **25**.

- [ ] **Step 6: Commit**

```bash
git add src/Client-app/lib/features/home/presentation/widgets/drawer_trang_chu.dart \
        src/Client-app/lib/features/analytics/presentation/pages/analytics_page.dart
git add -f src/Client-app/test/features/home/drawer_trang_chu_test.dart
git commit -m "feat(nav): drawer còn sáu mục, một đích một tên — nhóm D"
```

---

### Task 3: Tab Cá nhân gộp trang Cài đặt

**Files:**
- Modify: `lib/features/profile/presentation/pages/profile_page.dart`
- Modify: `lib/features/profile/presentation/pages/settings_page.dart`
- Modify: `test/features/profile/profile_page_menu_test.dart`

**Interfaces:**
- Consumes: `VungNguyHiemCard` (`lib/features/profile/presentation/widgets/vung_nguy_hiem_card.dart`) — dùng nguyên, không sửa.
- Produces: `ProfilePage` hiện bốn khối; `SettingsPage` giữ nguyên route `/settings` và trỏ về cùng nội dung.

- [ ] **Step 1: Viết ca test đỏ**

Thêm vào `test/features/profile/profile_page_menu_test.dart`:

```dart
  testWidgets('tab Cá nhân bỏ nhóm QUẢN LÝ TÀI KHOẢN (nhóm D)', (tester) async {
    await moTrang(tester);

    expect(find.text('QUẢN LÝ TÀI KHOẢN'), findsNothing,
        reason: 'Bốn mục ấy lặp lại đúng drawer. Lối B cho drawer giữ module, '
            'tab Cá nhân giữ hồ sơ và cài đặt.');
    for (final nhan in ['Hóa đơn', 'Mục tiêu tiết kiệm', 'Ví',
        'Danh mục tùy chỉnh']) {
      expect(find.text(nhan), findsNothing, reason: '"$nhan" sống ở drawer.');
    }
  });

  testWidgets('tab Cá nhân mang luôn nội dung trang Cài đặt', (tester) async {
    await moTrang(tester);

    expect(find.text('BẢO MẬT & TÙY CHỌN'), findsOneWidget);
    expect(find.text('Thông tin cá nhân'), findsOneWidget);
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.text('Cài đặt thông báo'), findsOneWidget,
        reason: 'D7: tên cũ "Thông báo" lẫn với trung tâm thông báo, thứ vào '
            'bằng chuông ở Trang chủ — hai chỗ khác hẳn nhau.');
    expect(find.text('Thông báo'), findsNothing);
    expect(find.text('Thông tin và bảo mật'), findsNothing,
        reason: 'Mục ấy chỉ là lối nhảy sang /settings, nay nội dung đã nằm '
            'ngay đây.');
  });
```

- [ ] **Step 2: Chạy để xem đỏ**

Run: `flutter test test/features/profile/profile_page_menu_test.dart`
Expected: FAIL — nhóm QUẢN LÝ TÀI KHOẢN còn đó, chưa có "BẢO MẬT & TÙY CHỌN".

- [ ] **Step 3: Tách thân trang Cài đặt thành widget dùng chung**

Tạo `lib/features/profile/presentation/widgets/noi_dung_cai_dat.dart` và **chuyển** (không chép) hai hàm `_buildSecurityPreferencesCard` + `_buildActionItem` từ `settings_page.dart:155-210` vào đó:

```dart
/// Thân trang Cài đặt — **định nghĩa duy nhất**, dùng chung bởi tab Cá nhân và
/// route `/settings`.
///
/// ⚠️ Vì sao là widget dùng chung chứ không phải hai bản: hai bản chép tay của
/// cùng một khối là đúng thứ đã sinh ra **G41** và **G47** trong dự án này —
/// cả hai lần đều là một truy vấn được chép sang chỗ thứ hai rồi hai bên trôi
/// lệch, im lặng, hàng tháng trời.
///
/// Route `/settings` **giữ nguyên** dù tab Cá nhân đã mang nội dung này: bốn
/// route con khai báo bên trong nó (`/settings/change-password`,
/// `/settings/delete-account`, `/settings/edit-profile` ở `app_router.dart`
/// `:353`–`:359`, và `/settings/notifications` ở `:329`), và
/// `vung_nguy_hiem_card.dart:106` đang `push` một trong số đó.
class NoiDungCaiDat extends StatelessWidget {
  const NoiDungCaiDat({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _theBaoMat(context),
        const SizedBox(height: 32),
        // Chép đúng khối `BlocBuilder<AuthBloc, AuthState>` + `VungNguyHiemCard`
        // đang ở `settings_page.dart:42` — mở tệp ấy đọc tham số, đừng đoán.
      ],
    );
  }

  // `_theBaoMat` và `_mucHanhDong` chuyển nguyên từ `settings_page.dart`
  // (`_buildSecurityPreferencesCard`, `_buildActionItem`), giữ nguyên cả chú
  // thích về hai mục MFA / Cloud đã gỡ ngày 2026-09-19 — chú thích ấy ghi lại
  // vì sao chúng biến mất, và mất nó là mời người sau thêm lại.
}
```

⚠️ **Không chép mã sang `profile_page.dart`.** Hai bản chép tay của cùng một khối là đúng cái đã sinh ra G41 và G47 trong dự án này — cả hai lần đều là một truy vấn được chép sang chỗ thứ hai rồi hai bên trôi lệch.

`SettingsPage` sau đó chỉ còn `Scaffold` + `AppBar` + `NoiDungCaiDat`, giữ nguyên route `/settings` (bốn route con khai bên trong nó).

- [ ] **Step 4: Dựng lại thân `ProfilePage`**

Bỏ khối `_buildSection(title: 'QUẢN LÝ TÀI KHOẢN', …)`, và đổi nhóm CÀI ĐẶT còn một mục:

```dart
            _buildProfileHeader(),
            const SizedBox(height: 32),
            const NoiDungCaiDat(),
            const SizedBox(height: 32),
            _buildSection(
              title: 'CÀI ĐẶT',
              items: [
                _ProfileItem(
                  icon: Icons.notifications_none,
                  // D7: "Thông báo" lẫn với trung tâm thông báo (vào bằng
                  // chuông ở Trang chủ). Đây là trang CÀI ĐẶT thông báo.
                  title: 'Cài đặt thông báo',
                  onTap: () => context.push('/settings/notifications'),
                ),
              ],
            ),
```

⚠️ `NoiDungCaiDat` đã chứa `VungNguyHiemCard`, nên **đừng thêm lần thứ hai**.

- [ ] **Step 5: Chạy test và analyze**

Run: `flutter test test/features/profile` rồi `flutter analyze`
Expected: PASS; analyze về **25**. Nếu analyze lên 26 vì một hàm ở `settings_page.dart` hết chỗ gọi thì **xoá hàm ấy** — đúng nếp "quét API có 0 chỗ gọi trước khi commit".

- [ ] **Step 6: Commit**

```bash
git add src/Client-app/lib/features/profile/presentation/pages/profile_page.dart \
        src/Client-app/lib/features/profile/presentation/pages/settings_page.dart \
        src/Client-app/lib/features/profile/presentation/widgets/noi_dung_cai_dat.dart
git add -f src/Client-app/test/features/profile/profile_page_menu_test.dart
git commit -m "feat(profile): tab Cá nhân gộp trang Cài đặt, bỏ nhóm module — nhóm D"
```

---

### Task 4: Trang chủ bỏ slogan, nút hero và "Xem báo cáo"

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart:61`, `:281-308`
- Delete: `lib/features/home/presentation/widgets/home_action_buttons.dart`
- Modify: `test/features/layout/no_overflow_test.dart:125`
- Test: `test/features/home/trang_chu_gon_test.dart` (tạo mới)

**Interfaces:**
- Consumes: không có gì mới.
- Produces: `HomeActionButtons` **không còn tồn tại** — mọi chỗ import nó phải gỡ.

- [ ] **Step 1: Viết ca test đỏ**

Tạo `test/features/home/trang_chu_gon_test.dart`. Dựng `HomePage` đòi CSDL và bảy stream, nên ca này quét **nguồn** thay vì dựng widget — cùng khuôn với các test quét `lib/` đã có:

```dart
/// Trang chủ bỏ ba khối thừa — nhóm D, 2026-09-19.
///
/// Trang chủ từng có **năm** lối vào cùng một màn Thêm giao dịch: nút hero, ba
/// nút tròn, và FAB. Ba nút tròn từ C4 đã đặt sẵn chiều Chi/Thu/Chuyển nên
/// nhanh hơn hero; hero là lối vào duy nhất không thêm được gì mà chiếm cả một
/// hàng đầu màn.
///
/// Dựng `HomePage` thật đòi CSDL, AuthBloc và bảy stream, nên ca này quét
/// nguồn — cùng khuôn với các test quét `lib/` khác của dự án.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final nguon =
      File('lib/features/home/presentation/pages/home_page.dart')
          .readAsStringSync();

  test('không còn slogan hai dòng', () {
    expect(nguon.contains('Kiểm soát tiền bạc'), isFalse,
        reason: 'Slogan chiếm khoảng 120dp đầu màn và không nói gì về tiền của '
            'người dùng; bỏ nó thì số dư lên gần đỉnh màn.');
  });

  test('không còn nút hero và nút "Xem báo cáo"', () {
    expect(nguon.contains('HomeActionButtons'), isFalse);
    expect(nguon.contains('_buildHeroSection'), isFalse);
  });

  test('widget HomeActionButtons đã xoá khỏi cây nguồn', () {
    expect(
        File('lib/features/home/presentation/widgets/home_action_buttons.dart')
            .existsSync(),
        isFalse,
        reason: 'Còn 0 chỗ gọi sau khi bỏ hero. Giữ lại một widget không ai '
            'dùng là đúng thứ lượt soát 2026-09-10 đã dặn phải quét.');
  });

  test('ba nút tròn đặt sẵn chiều vẫn còn', () {
    for (final huong in ["'thu'", "'chi'", "'transfer'"]) {
      expect(nguon.contains("push('/add', extra: $huong)"), isTrue,
          reason: 'Ba nút tròn là lối vào nhanh nhất còn lại; chúng đặt sẵn '
              'chiều từ C4.');
    }
  });
}
```

⚠️ Ba chuỗi ấy đã đo bằng máy ngày 2026-09-19 và có dạng **chính xác** `context.push('/add', extra: 'thu')` (cùng `'chi'`, `'transfer'`), nằm trong `_buildQuickActions` ở `home_page.dart:371-400`.

- [ ] **Step 2: Chạy để xem đỏ**

Run: `flutter test test/features/home/trang_chu_gon_test.dart`
Expected: FAIL ở ba ca đầu.

- [ ] **Step 3: Bỏ hero khỏi `HomePage`**

Xoá dòng 61 `_buildHeroSection(context),` cùng một trong hai `const SizedBox(height: 32)` kề nó, và xoá cả hàm `_buildHeroSection` (dòng 281–308). Xoá dòng `import` của `home_action_buttons.dart`.

- [ ] **Step 4: Xoá widget và sửa ca test đang dùng nó**

```bash
rm src/Client-app/lib/features/home/presentation/widgets/home_action_buttons.dart
```

Trong `test/features/layout/no_overflow_test.dart`, xoá nhóm ca dựng `HomeActionButtons(onAdd: () {}, onReport: () {})` ở dòng 125 cùng `import` của nó — widget không còn thì ca ấy không biên dịch được.

- [ ] **Step 5: Chạy test và analyze**

Run: `flutter test` rồi `flutter analyze`
Expected: PASS toàn bộ; analyze về **25**.

- [ ] **Step 6: Commit**

```bash
git add src/Client-app/lib/features/home/presentation/pages/home_page.dart \
        src/Client-app/lib/features/home/presentation/widgets/home_action_buttons.dart
git add -f src/Client-app/test/features/home/trang_chu_gon_test.dart \
           src/Client-app/test/features/layout/no_overflow_test.dart
git commit -m "feat(home): bỏ slogan, nút hero và Xem báo cáo — nhóm D"
```

---

### Task 5: Nghiệm thu máy ảo và cập nhật tài liệu

Đây là task riêng vì nó là nơi **duy nhất** bắt được ba loại lỗi `flutter test` mù, và vì nó có thể lật kết luận của bốn task trên.

**Files:**
- Modify: `CLAUDE.md` (con số test, danh sách test quét `lib/`)
- Modify: `docs/PROJECT_CONTEXT.md` mục 14
- Modify: `docs/superpowers/plans/2026-09-19-ux-ui-danh-sach-viec.md` (đánh dấu D1–D11)

- [ ] **Step 1: Dựng và cài**

```bash
cd src/Client-app && flutter build apk --debug
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" install -r build/app/outputs/flutter-apk/app-debug.apk
"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" shell am start -n com.flowmoney.flowmoney/.MainActivity
```

- [ ] **Step 2: Đi hết sáu đường dễ hỏng, chụp màn từng bước**

1. Chạm cả bốn tab — nhãn "Giao dịch" **không cắt chữ**, tab Sổ giao dịch mở đúng danh sách.
2. Drawer → "Ngân sách" → có **nút Back** và bấm Back về Trang chủ.
3. Drawer → "Quản lý ví" → "Xem giao dịch" của một ví → **không màn đỏ**, sổ hiện đúng ví ấy.
4. Trang chủ → "Xem tất cả" → chuyển sang tab Sổ giao dịch.
5. Tab Cá nhân → đủ bốn khối, "Cài đặt thông báo" mở đúng trang.
6. Trang chủ → không còn slogan, không còn hai nút hero.

⚠️ Mẹo dò tràn hàng loạt: sọc cảnh báo của Flutter là **vàng thuần** và không màn nào của app dùng màu ấy — đếm pixel vàng trong ảnh `adb exec-out screencap` rẻ hơn mở từng ảnh ra nhìn.

- [ ] **Step 3: Kiểm hai đường thông báo — chỗ nguy hiểm nhất**

Đây là thứ không đường giao diện nào chạm tới. Mở trung tâm thông báo (chuông ở Trang chủ) rồi chạm một thông báo **ngân sách** và một thông báo **khoản chi lớn** nếu có. Không có sẵn thì hạ `nguongChiLon` ở màn cài đặt thông báo để sinh một cái.
Expected: cả hai mở đúng đích, **không màn đỏ**, và thanh tab vẫn còn.

- [ ] **Step 4: Đối chiếu Stitch**

`list_screens` cho dự án `5106367939423432838`, tìm ba màn của nhóm D: drawer `250229e651a74a83a85c6e9e7091f321`, Cá nhân `580ee88c6e81472297b523618137ba6a`, và màn Trang chủ (lượt gọi **timeout** ngày 2026-09-19 — có thể đã hiện).
⚠️ **Timeout không phải thất bại và tuyệt đối không gọi lại.** Chưa thấy thì **hỏi người dùng nhìn giúp trên canvas** — đó là phép đo duy nhất đáng tin.

- [ ] **Step 5: Cập nhật tài liệu**

Đếm lại **bằng máy**, đừng cộng dồn:

```bash
cd src/Client-app && flutter test 2>&1 | tail -1
flutter test test/features/home 2>&1 | tail -1
find test/features/home -name '*.dart' | wc -l
```

Ghi vào `CLAUDE.md` (mục "Lệnh hay dùng" và "Ghi chú về kiểm thử") và `docs/PROJECT_CONTEXT.md` mục 14 một khối tường thuật nhóm D nêu: hai quả mìn (`nhanhThanhTab`, push-từ-ngoài-shell), đánh đổi Back từ sổ đã lọc, và nhãn "Giao dịch" 9 ký tự vì ô rộng cố định 72dp.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md docs/PROJECT_CONTEXT.md
git add -f docs/superpowers/plans/2026-09-19-ux-ui-danh-sach-viec.md
git commit -m "docs: nhóm D xong — tường thuật, con số test đếm lại bằng máy"
```

---

## Ngoài phạm vi

Giữ nguyên, **không** đụng: **A5** nút Quét, **A6** thẻ Insight AI, **A11** hai nút Google/Apple, **E1** skeleton Phân tích, **E2** mục lục trang Phân tích, **E4** thay `SnackBar` bằng toast, **E6** nhắc ví âm hằng ngày, **G2** cỡ chữ hệ thống lớn.

⚠️ `ProfilePage` có nút "Đăng xuất" và drawer cũng có — **giữ cả hai**, đó là hiện trạng từ trước nhóm D và spec không đụng tới.
