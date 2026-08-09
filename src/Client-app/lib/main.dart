import 'package:flutter/material.dart';
import 'core/constants/app_router.dart';
import 'core/di/injection_container.dart';
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
