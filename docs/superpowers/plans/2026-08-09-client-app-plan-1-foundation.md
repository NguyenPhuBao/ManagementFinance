# Client-app Plan 1: Foundation — Project Setup, Theme, Navigation & DI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tạo Flutter project hoàn chỉnh với cấu trúc thư mục đúng kiến trúc, theme, navigation (GoRouter), và dependency injection (GetIt) sẵn sàng để các feature sau cài vào.

**Architecture:** BLoC + Repository + Feature-first. Core infrastructure (DI, Router, Theme) được setup một lần tại đây — mọi feature sau đều kế thừa không cần config lại.

**Tech Stack:** Flutter 3.x, flutter_bloc ^8, go_router ^14, get_it ^7, equatable ^2, flutter_secure_storage ^9, flutter_lints ^4, intl ^0.19

## Global Constraints

- Flutter SDK: >= 3.22.0
- Dart SDK: >= 3.4.0
- Tên package: `com.flowmoney.app`
- Tên app hiển thị: `FlowMoney`
- Design colors: Background `#EDEDE9`, Income `#4CAF50`, Expense `#F25F5C`, Surface `#FFFFFF`, Text Primary `#1A1C1A`
- Font: Inter (Google Fonts)
- Tất cả text trong app bằng tiếng Việt
- Không dùng `antd` hay UI framework bên ngoài — thuần Flutter widgets
- Mọi commit theo format: `feat:`, `fix:`, `chore:`, `docs:`

---

### Task 1: Khởi tạo Flutter project và cài packages

**Files:**
- Create: `src/Client-app/pubspec.yaml`
- Create: `src/Client-app/lib/main.dart`

**Interfaces:**
- Produces: Flutter project chạy được `flutter run`, hiện màn hình trắng

- [ ] **Bước 1: Tạo Flutter project**

```bash
cd src
flutter create --org com.flowmoney --project-name flowmoney client_app
```

Xác nhận project tạo thành công:
```bash
cd client_app
flutter run
```
Expected: App chạy, hiện màn hình mặc định Flutter.

- [ ] **Bước 2: Xóa code mặc định, giữ cấu trúc sạch**

Mở `lib/main.dart`, thay toàn bộ nội dung bằng:

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('FlowMoney')),
      ),
    );
  }
}
```

- [ ] **Bước 3: Cài tất cả packages vào pubspec.yaml**

Mở `pubspec.yaml`, thay phần `dependencies` và `dev_dependencies`:

```yaml
name: flowmoney
description: FlowMoney - Personal Finance Management App
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.4.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_bloc: ^8.1.6
  equatable: ^2.0.5

  # Navigation
  go_router: ^14.6.2

  # Dependency injection
  get_it: ^7.7.0

  # Local database
  drift: ^2.21.0
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4
  path: ^1.9.0

  # HTTP
  dio: ^5.7.0

  # Connectivity & sync
  connectivity_plus: ^6.1.1
  uuid: ^4.5.1

  # Security
  flutter_secure_storage: ^9.2.2

  # UI & fonts
  google_fonts: ^6.2.1
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  drift_dev: ^2.21.0
  build_runner: ^2.4.13
```

Chạy:
```bash
flutter pub get
```
Expected: `Got dependencies!` — không có lỗi.

- [ ] **Bước 4: Commit**

```bash
git add src/Client-app
git commit -m "feat: init Flutter project with all dependencies"
```

---

### Task 2: Tạo cấu trúc thư mục

**Files:**
- Create: `lib/core/` (và các subdirectory)
- Create: `lib/features/` (và các subdirectory)
- Create: `lib/shared/` (và các subdirectory)
- Create: `lib/core/constants/app_constants.dart`

**Interfaces:**
- Produces: Toàn bộ folder structure theo spec — các task sau biết chính xác file nào cần tạo ở đâu

- [ ] **Bước 1: Tạo toàn bộ thư mục bằng file placeholder**

Chạy lệnh sau (PowerShell) từ thư mục `src/Client-app/lib/`:

```powershell
# Core
New-Item -ItemType Directory -Force -Path "core/api/interceptors"
New-Item -ItemType Directory -Force -Path "core/database/daos"
New-Item -ItemType Directory -Force -Path "core/sync"
New-Item -ItemType Directory -Force -Path "core/di"
New-Item -ItemType Directory -Force -Path "core/constants"
New-Item -ItemType Directory -Force -Path "core/errors"
New-Item -ItemType Directory -Force -Path "core/utils"

# Features
$features = @("auth","transaction","wallet","budget","category","bill","goal","analytics","ai_chat","profile")
foreach ($f in $features) {
  New-Item -ItemType Directory -Force -Path "features/$f/data/datasources"
  New-Item -ItemType Directory -Force -Path "features/$f/data/models"
  New-Item -ItemType Directory -Force -Path "features/$f/data/repositories"
  New-Item -ItemType Directory -Force -Path "features/$f/presentation/bloc"
  New-Item -ItemType Directory -Force -Path "features/$f/presentation/pages"
  New-Item -ItemType Directory -Force -Path "features/$f/presentation/widgets"
}

# Shared
New-Item -ItemType Directory -Force -Path "shared/widgets"
New-Item -ItemType Directory -Force -Path "shared/theme"
```

- [ ] **Bước 2: Tạo file constants cơ bản**

Tạo `lib/core/constants/app_constants.dart`:

```dart
class AppConstants {
  // API
  static const String baseUrl = 'http://10.0.2.2:3000/api'; // Android emulator → localhost
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Sync
  static const Duration syncDebounce = Duration(seconds: 3);
  static const Duration syncInterval = Duration(minutes: 15);

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
}
```

- [ ] **Bước 3: Commit**

```bash
git add lib/
git commit -m "chore: scaffold folder structure and constants"
```

---

### Task 3: Theme — Colors, TextStyles, ThemeData

**Files:**
- Create: `lib/shared/theme/app_colors.dart`
- Create: `lib/shared/theme/app_text_styles.dart`
- Create: `lib/shared/theme/app_theme.dart`

**Interfaces:**
- Produces:
  - `AppColors.background`, `AppColors.primary`, `AppColors.income`, `AppColors.expense`, `AppColors.surface`, `AppColors.textPrimary`, `AppColors.textSecondary`, `AppColors.outline`
  - `AppTextStyles.headlineLg`, `AppTextStyles.headlineMd`, `AppTextStyles.bodyLg`, `AppTextStyles.bodyMd`, `AppTextStyles.labelMd`, `AppTextStyles.displayCurrency`
  - `AppTheme.lightTheme` — ThemeData đầy đủ

- [ ] **Bước 1: Tạo AppColors**

Tạo `lib/shared/theme/app_colors.dart`:

```dart
import 'package:flutter/material.dart';

class AppColors {
  // Background & Surface
  static const Color background = Color(0xFFEDEDE9);
  static const Color surface = Color(0xFFFFFFFF);

  // Primary (gần đen)
  static const Color primary = Color(0xFF1A1A19);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Semantic
  static const Color income = Color(0xFF4CAF50);   // Thu nhập / Tích cực
  static const Color expense = Color(0xFFF25F5C);  // Chi tiêu / Tiêu cực

  // Text
  static const Color textPrimary = Color(0xFF1A1C1A);
  static const Color textSecondary = Color(0xFF767872);

  // Border & Outline
  static const Color outline = Color(0xFFC6C7C1);
  static const Color outlineVariant = Color(0xFFE3E3DF);

  // Containers
  static const Color surfaceContainer = Color(0xFFEEEEEA);
  static const Color surfaceContainerHigh = Color(0xFFE8E8E4);

  // Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
}
```

- [ ] **Bước 2: Tạo AppTextStyles**

Tạo `lib/shared/theme/app_text_styles.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Số tiền lớn — hiển thị số dư tổng
  static TextStyle displayCurrency = GoogleFonts.inter(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02 * 40,
    color: AppColors.textPrimary,
  );

  // Tiêu đề màn hình
  static TextStyle headlineLg = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.01 * 24,
    color: AppColors.textPrimary,
  );

  // Tiêu đề card
  static TextStyle headlineMd = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Nội dung chính
  static TextStyle bodyLg = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Nội dung phụ
  static TextStyle bodyMd = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Label nhỏ (uppercase, tracking)
  static TextStyle labelMd = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.05 * 12,
    color: AppColors.textSecondary,
  );

  static TextStyle labelSm = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}
```

- [ ] **Bước 3: Tạo AppTheme**

Tạo `lib/shared/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.surface,
      error: AppColors.error,
      onError: AppColors.onError,
    ),
    scaffoldBackgroundColor: AppColors.background,
    textTheme: GoogleFonts.interTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    ),
  );
}
```

- [ ] **Bước 4: Kiểm tra build**

```bash
flutter build apk --debug 2>&1 | head -20
```
Expected: Không có lỗi compile.

- [ ] **Bước 5: Commit**

```bash
git add lib/shared/theme/
git commit -m "feat: add design system theme (colors, text styles, ThemeData)"
```

---

### Task 4: Shared Widgets tái sử dụng

**Files:**
- Create: `lib/shared/widgets/loading_widget.dart`
- Create: `lib/shared/widgets/error_widget.dart`
- Create: `lib/shared/widgets/empty_state_widget.dart`
- Create: `lib/shared/widgets/confirm_dialog.dart`
- Create: `lib/shared/widgets/app_card.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppTextStyles` từ Task 3
- Produces:
  - `LoadingWidget()` — hiện spinner
  - `AppErrorWidget({required String message, VoidCallback? onRetry})` — hiện lỗi + nút retry
  - `EmptyStateWidget({required String message})` — trạng thái trống
  - `ConfirmDialog.show(context, title, message, onConfirm)` — dialog xác nhận xóa
  - `AppCard({required Widget child, EdgeInsets? padding})` — card trắng với shadow

- [ ] **Bước 1: Tạo LoadingWidget**

Tạo `lib/shared/widgets/loading_widget.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
        strokeWidth: 2.5,
      ),
    );
  }
}
```

- [ ] **Bước 2: Tạo AppErrorWidget**

Tạo `lib/shared/widgets/error_widget.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorWidget({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.expense, size: 48),
            const SizedBox(height: 16),
            Text(message, style: AppTextStyles.bodyMd, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: const Text('Thử lại', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Bước 3: Tạo EmptyStateWidget**

Tạo `lib/shared/widgets/empty_state_widget.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class EmptyStateWidget extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 64),
            const SizedBox(height: 16),
            Text(message, style: AppTextStyles.bodyMd, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Bước 4: Tạo ConfirmDialog**

Tạo `lib/shared/widgets/confirm_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class ConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Xóa',
    String cancelText = 'Hủy',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: AppTextStyles.headlineMd),
        content: Text(message, style: AppTextStyles.bodyMd),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelText, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
```

- [ ] **Bước 5: Tạo AppCard**

Tạo `lib/shared/widgets/app_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Bước 6: Commit**

```bash
git add lib/shared/widgets/
git commit -m "feat: add shared widgets (Loading, Error, EmptyState, ConfirmDialog, AppCard)"
```

---

### Task 5: Bottom Navigation Bar & Main Shell

**Files:**
- Create: `lib/shared/widgets/bottom_nav_bar.dart`
- Create: `lib/shared/widgets/main_shell.dart`

**Interfaces:**
- Consumes: `AppColors`, GoRouter `StatefulShellRoute` context
- Produces:
  - `MainShell` — Scaffold với BottomNavigationBar cho 5 tab: Home, Analytics, Add, Budget, Profile
  - `AppBottomNavBar({required int currentIndex, required void Function(int) onTap})`

- [ ] **Bước 1: Tạo AppBottomNavBar**

Tạo `lib/shared/widgets/bottom_nav_bar.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Trang chủ'),
          const BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Thống kê'),
          BottomNavigationBarItem(
            icon: Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: AppColors.onPrimary, size: 28),
            ),
            label: 'Thêm',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Ngân sách'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Hồ sơ'),
        ],
      ),
    );
  }
}
```

- [ ] **Bước 2: Tạo MainShell**

Tạo `lib/shared/widgets/main_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'bottom_nav_bar.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
```

- [ ] **Bước 3: Commit**

```bash
git add lib/shared/widgets/
git commit -m "feat: add bottom navigation bar and main shell"
```

---

### Task 6: GoRouter — Khai báo tất cả routes

**Files:**
- Create: `lib/core/constants/app_router.dart`
- Create: `lib/features/auth/presentation/pages/login_page.dart` (placeholder)
- Create: `lib/features/auth/presentation/pages/register_page.dart` (placeholder)
- Create: `lib/features/auth/presentation/pages/forgot_password_page.dart` (placeholder)
- Create: `lib/features/transaction/presentation/pages/add_transaction_page.dart` (placeholder)
- Create: `lib/features/wallet/presentation/pages/wallet_list_page.dart` (placeholder)
- Create: `lib/features/wallet/presentation/pages/wallet_add_page.dart` (placeholder)
- Create: `lib/features/wallet/presentation/pages/wallet_edit_page.dart` (placeholder)
- Create: `lib/features/budget/presentation/pages/budget_page.dart` (placeholder)
- Create: `lib/features/budget/presentation/pages/budget_rules_page.dart` (placeholder)
- Create: `lib/features/category/presentation/pages/category_page.dart` (placeholder)
- Create: `lib/features/category/presentation/pages/category_group_page.dart` (placeholder)
- Create: `lib/features/bill/presentation/pages/bill_page.dart` (placeholder)
- Create: `lib/features/bill/presentation/pages/bill_add_page.dart` (placeholder)
- Create: `lib/features/bill/presentation/pages/bill_edit_page.dart` (placeholder)
- Create: `lib/features/goal/presentation/pages/goal_page.dart` (placeholder)
- Create: `lib/features/goal/presentation/pages/goal_add_page.dart` (placeholder)
- Create: `lib/features/goal/presentation/pages/goal_detail_page.dart` (placeholder)
- Create: `lib/features/analytics/presentation/pages/analytics_page.dart` (placeholder)
- Create: `lib/features/ai_chat/presentation/pages/ai_chat_page.dart` (placeholder)
- Create: `lib/features/profile/presentation/pages/profile_page.dart` (placeholder)
- Create: `lib/features/profile/presentation/pages/settings_page.dart` (placeholder)
- Create: `lib/features/profile/presentation/pages/change_password_page.dart` (placeholder)

**Interfaces:**
- Consumes: `MainShell` từ Task 5, tất cả placeholder pages
- Produces: `AppRouter.router` — GoRouter instance sẵn sàng dùng trong `main.dart`

- [ ] **Bước 1: Tạo tất cả placeholder pages**

Mẫu cho mọi placeholder page (thay `LoginPage`, `'Đăng nhập'` phù hợp):

```dart
// Ví dụ: lib/features/auth/presentation/pages/login_page.dart
import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Đăng nhập')),
    );
  }
}
```

Tạo tương tự cho tất cả 22 pages, thay tên class và text label:
- `RegisterPage` → `'Đăng ký'`
- `ForgotPasswordPage` → `'Quên mật khẩu'`
- `HomePage` → `'Trang chủ'`
- `AnalyticsPage` → `'Thống kê'`
- `AddTransactionPage` → `'Thêm giao dịch'`
- `BudgetPage` → `'Ngân sách'`
- `BudgetRulesPage` → `'Quy tắc ngân sách'`
- `ProfilePage` → `'Hồ sơ'`
- `SettingsPage` → `'Cài đặt'`
- `ChangePasswordPage` → `'Đổi mật khẩu'`
- `WalletListPage` → `'Danh sách ví'`
- `WalletAddPage` → `'Thêm ví'`
- `WalletEditPage` → `'Sửa ví'`
- `CategoryPage` → `'Danh mục'`
- `CategoryGroupPage` → `'Gom nhóm danh mục'`
- `BillPage` → `'Hóa đơn'`
- `BillAddPage` → `'Thêm hóa đơn'`
- `BillEditPage` → `'Sửa hóa đơn'`
- `GoalPage` → `'Mục tiêu'`
- `GoalAddPage` → `'Thêm mục tiêu'`
- `GoalDetailPage` → `'Chi tiết mục tiêu'`
- `AiChatPage` → `'Trợ lý AI'`
- `ExportReportPage` → `'Xuất báo cáo'`
- `BankLinkPage` → `'Liên kết ngân hàng'`

- [ ] **Bước 2: Tạo AppRouter**

Tạo `lib/core/constants/app_router.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/main_shell.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/transaction/presentation/pages/add_transaction_page.dart';
import '../../features/wallet/presentation/pages/wallet_list_page.dart';
import '../../features/wallet/presentation/pages/wallet_add_page.dart';
import '../../features/wallet/presentation/pages/wallet_edit_page.dart';
import '../../features/budget/presentation/pages/budget_page.dart';
import '../../features/budget/presentation/pages/budget_rules_page.dart';
import '../../features/category/presentation/pages/category_page.dart';
import '../../features/category/presentation/pages/category_group_page.dart';
import '../../features/bill/presentation/pages/bill_page.dart';
import '../../features/bill/presentation/pages/bill_add_page.dart';
import '../../features/bill/presentation/pages/bill_edit_page.dart';
import '../../features/goal/presentation/pages/goal_page.dart';
import '../../features/goal/presentation/pages/goal_add_page.dart';
import '../../features/goal/presentation/pages/goal_detail_page.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/ai_chat/presentation/pages/ai_chat_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/profile/presentation/pages/change_password_page.dart';

// TODO: Import thêm khi có HomePage
class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Trang chủ')));
}

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      // Auth routes (public)
      GoRoute(path: '/login',           builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register',        builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordPage()),

      // Main app với Bottom Navigation
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const _PlaceholderHome()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/add', builder: (_, __) => const AddTransactionPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/budget', builder: (_, __) => const BudgetPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
          ]),
        ],
      ),

      // Wallet
      GoRoute(path: '/wallets',                 builder: (_, __) => const WalletListPage()),
      GoRoute(path: '/wallets/add',             builder: (_, __) => const WalletAddPage()),
      GoRoute(path: '/wallets/:id/edit',        builder: (_, s) => WalletEditPage(id: s.pathParameters['id']!)),

      // Budget rules
      GoRoute(path: '/budget/rules',            builder: (_, __) => const BudgetRulesPage()),

      // Category
      GoRoute(path: '/categories',              builder: (_, __) => const CategoryPage()),
      GoRoute(path: '/categories/group',        builder: (_, __) => const CategoryGroupPage()),

      // Bill
      GoRoute(path: '/bills',                   builder: (_, __) => const BillPage()),
      GoRoute(path: '/bills/add',               builder: (_, __) => const BillAddPage()),
      GoRoute(path: '/bills/:id/edit',          builder: (_, s) => BillEditPage(id: s.pathParameters['id']!)),

      // Goal
      GoRoute(path: '/goals',                   builder: (_, __) => const GoalPage()),
      GoRoute(path: '/goals/add',               builder: (_, __) => const GoalAddPage()),
      GoRoute(path: '/goals/:id',               builder: (_, s) => GoalDetailPage(id: s.pathParameters['id']!)),

      // Other
      GoRoute(path: '/ai-chat',                 builder: (_, __) => const AiChatPage()),
      GoRoute(path: '/settings',                builder: (_, __) => const SettingsPage()),
      GoRoute(path: '/settings/change-password',builder: (_, __) => const ChangePasswordPage()),

      // Placeholder routes (implement sau)
      GoRoute(path: '/export-report',           builder: (_, __) => const Scaffold(body: Center(child: Text('Xuất báo cáo')))),
      GoRoute(path: '/bank-link',               builder: (_, __) => const Scaffold(body: Center(child: Text('Liên kết ngân hàng')))),
    ],
  );
}
```

- [ ] **Bước 3: Cập nhật `lib/main.dart` dùng theme và router**

```dart
import 'package:flutter/material.dart';
import 'core/constants/app_router.dart';
import 'shared/theme/app_theme.dart';

void main() {
  runApp(const FlowMoneyApp());
}

class FlowMoneyApp extends StatelessWidget {
  const FlowMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FlowMoney',
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Bước 4: Chạy app, kiểm tra navigation**

```bash
flutter run
```

Điều hướng thủ công trong simulator:
- App mở → hiện `Đăng nhập` (placeholder) ✅
- Bottom nav 5 tab xuất hiện ở màn Home ✅
- Bấm từng tab → đúng màn hình placeholder ✅

- [ ] **Bước 5: Commit**

```bash
git add lib/
git commit -m "feat: add GoRouter with all 23 routes and placeholder pages"
```

---

### Task 7: GetIt — Dependency Injection setup

**Files:**
- Create: `lib/core/di/injection.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Produces: `setupDependencies()` — hàm gọi một lần trong `main()`. Sau này mỗi feature chỉ cần thêm dòng đăng ký vào file này.

- [ ] **Bước 1: Tạo injection.dart**

Tạo `lib/core/di/injection.dart`:

```dart
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // ── Infrastructure sẽ đăng ký ở đây sau (Plan 3) ──
  // getIt.registerSingleton<AppDatabase>(AppDatabase());
  // getIt.registerSingleton<DioClient>(DioClient());
  // getIt.registerSingleton<SyncEngine>(...);

  // ── Auth (Plan 2) ──
  // getIt.registerLazySingleton<AuthRepository>(...);
  // getIt.registerFactory<AuthCubit>(...);

  // ── Features (Plan 4+) ──
  // Thêm dần theo từng Plan
}
```

- [ ] **Bước 2: Cập nhật main.dart gọi setupDependencies**

```dart
import 'package:flutter/material.dart';
import 'core/constants/app_router.dart';
import 'core/di/injection.dart';
import 'shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  runApp(const FlowMoneyApp());
}

class FlowMoneyApp extends StatelessWidget {
  const FlowMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FlowMoney',
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Bước 3: Chạy lại kiểm tra**

```bash
flutter run
```
Expected: App mở bình thường, không có lỗi.

- [ ] **Bước 4: Commit**

```bash
git add lib/
git commit -m "feat: add GetIt dependency injection scaffold"
```

---

### Task 8: Linting và kiểm tra cuối

**Files:**
- Create/Modify: `analysis_options.yaml`

**Interfaces:**
- Produces: Project không có lỗi lint, build release thành công

- [ ] **Bước 1: Tạo analysis_options.yaml**

Tạo `analysis_options.yaml` ở root `src/Client-app/`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    avoid_print: true
    use_key_in_widget_constructors: true
```

- [ ] **Bước 2: Chạy lint**

```bash
flutter analyze
```
Expected: `No issues found!` hoặc chỉ có warnings không phải errors.

- [ ] **Bước 3: Build debug APK để đảm bảo không lỗi**

```bash
flutter build apk --debug
```
Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Bước 4: Commit cuối**

```bash
git add analysis_options.yaml
git commit -m "chore: add linting rules and verify clean build"
```

---

## Checklist hoàn thành Plan 1

- [ ] Task 1: Flutter project + tất cả packages cài thành công
- [ ] Task 2: Cấu trúc thư mục đầy đủ theo spec
- [ ] Task 3: Theme — Colors, TextStyles, ThemeData
- [ ] Task 4: Shared widgets (Loading, Error, Empty, ConfirmDialog, AppCard)
- [ ] Task 5: Bottom Navigation Bar + MainShell
- [ ] Task 6: GoRouter với 23 routes + placeholder pages
- [ ] Task 7: GetIt DI scaffold
- [ ] Task 8: Lint clean, build APK thành công

**Kết quả sau Plan 1:** App chạy được, navigate qua tất cả màn hình (placeholder), theme đúng màu FlowMoney, sẵn sàng cho Plan 2 (Auth feature).

**Plan tiếp theo:** `2026-08-09-client-app-plan-2-auth.md`
