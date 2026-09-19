/// Drawer của Trang chủ — tách thành widget riêng ngày 2026-09-19 để test được
/// mà không phải dựng cả `HomePage` (CSDL, AuthBloc, bảy stream).
///
/// Ba lỗi lượt đánh giá UX 2026-09-19 đo được trên máy ảo, cả ba nằm ở đây:
///
/// - Mục "Xuất báo cáo" trỏ vào `/reports`, một route **không tồn tại**, và
///   handler chặn nó bằng SnackBar "đang phát triển" — trong khi trang Xuất
///   báo cáo đã có từ 2026-09-09 ở `/export-report`.
/// - Avatar là một **vòng đen trống**: chữ cái đầu tô `AppColors.primary` trên
///   nền `AppColors.primaryContainer`, mà hai màu ấy là **một** (`#1A1A19`).
///   Màn Stitch "Home with Side Menu Drawer" vẽ chữ trắng trên nền đen.
/// - Thiếu "Đăng xuất" ở đáy — Stitch có, bản chạy không.
library;

import 'dart:io';

import 'package:flowmoney/core/constants/app_router.dart';
import 'package:flowmoney/core/notification/notification_deeplink.dart';
import 'package:flowmoney/features/auth/data/repositories/auth_repository.dart';
import 'package:flowmoney/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flowmoney/features/home/presentation/widgets/drawer_trang_chu.dart';
import 'package:flowmoney/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepoGia implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('mọi đường trong drawer đều là route có thật của app', () {
    final bloc = AuthBloc(authRepository: _RepoGia());
    addTearDown(bloc.close);
    final router = AppRouter.createRouter('/home', bloc);
    addTearDown(router.dispose);

    for (final m in kMucDrawer) {
      final khop = router.configuration.findMatch(Uri.parse(m.duong));
      expect(khop.isError, isFalse,
          reason: 'Mục "${m.nhan}" trỏ vào ${m.duong} mà router không có. Bản '
              'trước là `/reports`: một route không tồn tại, được che bằng '
              'SnackBar "đang phát triển" dù trang Xuất báo cáo đã có.');
    }
  });

  test('"Xuất báo cáo" trỏ vào trang Xuất báo cáo thật', () {
    final muc = kMucDrawer.singleWhere((m) => m.nhan == 'Xuất báo cáo');
    expect(muc.duong, '/export-report');
  });

  test('⚠️ drawer KHÔNG chứa đích nào đã có ở thanh dưới', () {
    // Nguyên tắc của lối B (nhóm D, 2026-09-19): thanh dưới giữ việc hằng
    // ngày, drawer giữ mọi thứ CÒN LẠI, và không đích nào xuất hiện ở cả hai
    // chỗ. Lặp lại là dạy người dùng hai đường tới cùng một nơi — và ở bản
    // trước, hai đường ấy còn mang hai cái TÊN khác nhau.
    for (final m in kMucDrawer) {
      expect(nhanhThanhTab.contains(m.duong), isFalse,
          reason: 'Mục "${m.nhan}" (${m.duong}) đã là một tab. Ca này đọc '
              'chính `nhanhThanhTab`, nên thêm tab mới mà quên rút khỏi '
              'drawer là đỏ ngay.');
    }
  });

  test('⚠️ MỌI trang tính năng đều vào được từ menu', () {
    // Người dùng báo ngày 2026-09-19: "vài chức năng ở phần cài đặt đã chuyển
    // đi nhưng không thấy chuyển qua chỗ nào". Đúng — nhóm D bỏ nhóm "QUẢN LÝ
    // TÀI KHOẢN" khỏi tab Cá nhân, ba trong bốn mục đã có sẵn ở drawer, nhưng
    // **"Danh mục tùy chỉnh" thì chưa bao giờ**: drawer cũ không cần nó vì tab
    // Cá nhân đang giữ. Bản spec sáu mục thừa hưởng đúng chỗ thiếu ấy, nên
    // trang Quản lý danh mục mất hẳn lối vào qua menu — chỉ còn một nút chôn
    // trong bảng chọn danh mục của màn Thêm giao dịch.
    //
    // Ca này canh **luật**, không canh một danh sách: mỗi trang tính năng phải
    // vào được từ drawer HOẶC từ thanh dưới. Chuyển một mục đi đâu cũng được,
    // miễn nó còn một cửa.
    const trangTinhNang = {
      '/wallets': 'Quản lý ví',
      '/goals': 'Mục tiêu tiết kiệm',
      '/budget': 'Ngân sách',
      '/bills': 'Hoá đơn',
      '/categories': 'Quản lý danh mục',
      '/export-report': 'Xuất báo cáo',
      '/ai-chat': 'Trợ lý AI',
      '/analytics': 'Phân tích',
      '/transactions': 'Sổ giao dịch',
      '/profile': 'Cá nhân',
      '/home': 'Trang chủ',
    };
    final coTrongMenu = {
      ...kMucDrawer.map((m) => m.duong),
      ...nhanhThanhTab,
    };
    for (final e in trangTinhNang.entries) {
      expect(coTrongMenu.contains(e.key), isTrue,
          reason: 'Trang "${e.value}" (${e.key}) không có lối vào nào từ menu '
              '— không ở drawer, không ở thanh dưới. Một trang không tới được '
              'là một tính năng đã biến mất, và `flutter analyze` không nói '
              'gì vì route vẫn tồn tại.');
    }
  });

  test('drawer còn đúng bảy mục, giữ nguyên thứ tự đã chốt', () {
    expect(kMucDrawer.map((m) => m.nhan).toList(), [
      'Quản lý ví',
      'Mục tiêu tiết kiệm',
      'Ngân sách',
      'Hóa đơn & Dịch vụ',
      'Danh mục',
      'Xuất báo cáo',
      'Trợ lý AI',
    ]);
  });

  test('⚠️ không còn mục nào tên "Thống kê" (D4)', () {
    expect(kMucDrawer.any((m) => m.nhan == 'Thống kê'), isFalse,
        reason: 'Một đích hai tên: "Phân tích" ở tab, "Thống kê" ở đây và ở '
            'tiêu đề trang. Drawer thôi có mục ấy nên tên còn lại là "Phân '
            'tích", và tiêu đề trang đổi theo.');
  });

  test('tiêu đề trang Phân tích khớp nhãn tab', () {
    final nguon = File(
            'lib/features/analytics/presentation/pages/analytics_page.dart')
        .readAsStringSync();
    expect(nguon.contains("            'Phân tích',"), isTrue,
        reason: 'Tiêu đề `AppBar` phải là "Phân tích" cho khớp nhãn tab. Ba '
            'chỗ "Thống kê" còn lại trong tệp là CHÚ THÍCH nhắc tên màn '
            'Stitch — đổi chúng là làm hỏng đường lần về bản thiết kế.');
  });

  Future<void> bom(
    WidgetTester tester, {
    required void Function(String) onChon,
    required VoidCallback onDangXuat,
    String ten = 'Đạt',
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: DrawerTrangChu(
          ten: ten,
          email: 'dat@example.com',
          onChon: onChon,
          onDangXuat: onDangXuat,
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('chạm một mục thì báo đúng đường, không SnackBar', (tester) async {
    final daChon = <String>[];
    await bom(tester, onChon: daChon.add, onDangXuat: () {});

    await tester.tap(find.text('Xuất báo cáo'));
    await tester.pump();

    expect(daChon, ['/export-report']);
    expect(find.byType(SnackBar), findsNothing,
        reason: 'Không còn "đang phát triển": tính năng đã có.');
  });

  testWidgets('có "Đăng xuất" ở đáy và chạm thì gọi onDangXuat', (tester) async {
    var goi = 0;
    await bom(tester, onChon: (_) {}, onDangXuat: () => goi++);

    await tester.tap(find.text('Đăng xuất'));
    await tester.pump();

    expect(goi, 1, reason: 'Stitch có "Đăng xuất" ở đáy drawer; bản chạy thiếu.');
  });

  testWidgets('chữ cái đầu của avatar phải khác màu nền', (tester) async {
    await bom(tester, onChon: (_) {}, onDangXuat: () {});

    final chu = tester.widget<Text>(find.text('Đ'));
    final nen = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(chu.style?.color, isNot(equals(nen.backgroundColor)),
        reason: 'Bản trước tô chữ `AppColors.primary` trên nền '
            '`AppColors.primaryContainer` — hai màu là một, nên avatar là vòng '
            'đen trống trên máy ảo.');
  });
}
