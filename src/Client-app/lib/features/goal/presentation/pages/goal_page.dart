import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/widgets/notification_bell.dart';
import '../../data/models/goal_entity.dart';
import '../widgets/goal_appearance.dart';
import '../widgets/goal_progress.dart';
import '../../domain/goal_grouping.dart';
import '../bloc/goal_cubit.dart';
import '../../../../core/auth/current_account.dart';

class GoalPage extends StatelessWidget {
  const GoalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GoalCubit>(
      create: (_) {
        final idaccount = currentAccountIdOrNull(context) ?? 0;
        return sl<GoalCubit>()..watchGoals(idaccount);
      },
      child: const _GoalPageContent(),
    );
  }
}

class _GoalPageContent extends StatelessWidget {
  const _GoalPageContent();

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
        locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    // BlocBuilder bọc NGOÀI `Scaffold` chứ không nằm trong `body`: nhãn tab
    // mang số đếm ("Đang theo đuổi (3)"), mà số ấy chỉ có trong state. Để
    // BlocBuilder ở trong thì `AppBar.bottom` không với tới được.
    return BlocBuilder<GoalCubit, GoalState>(
      builder: (context, state) {
        if (state is GoalLoading) {
          return _khungTrang(
            context,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is GoalError) {
          return _khungTrang(
            context,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Lỗi: ${state.message}',
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      final idaccount = currentAccountIdOrNull(context) ?? 0;
                      context.read<GoalCubit>().watchGoals(idaccount);
                    },
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        final goals = (state is GoalLoaded) ? state.goals : <GoalEntity>[];
        final tongDaTich =
            (state is GoalLoaded) ? state.totalCurrentAmount : 0.0;
        final tongMucTieu =
            (state is GoalLoaded) ? state.totalTargetAmount : 0.0;
        final nhom = chiaMucTieu(goals);

        return DefaultTabController(
          length: 2,
          child: _khungTrang(
            context,
            // Nhãn mang số đếm, cùng lối với tab Ngân sách: người dùng biết
            // được tab bên kia có gì mà không phải bấm sang xem.
            tabBar: TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'Đang theo đuổi (${nhom.dangTheoDuoi.length})'),
                Tab(text: 'Đã hoàn thành (${nhom.daHoanThanh.length})'),
              ],
            ),
            body: TabBarView(
              children: [
                _tabDangTheoDuoi(
                  context,
                  goals: nhom.dangTheoDuoi,
                  coMucTieuNaoKhong: goals.isNotEmpty,
                  tongDaTich: tongDaTich,
                  tongMucTieu: tongMucTieu,
                  currencyFormatter: currencyFormatter,
                ),
                _tabDaHoanThanh(
                  context,
                  goals: nhom.daHoanThanh,
                  currencyFormatter: currencyFormatter,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Khung chung của trang: nền, thanh tiêu đề, chuông thông báo.
  ///
  /// Tách ra vì bốn nhánh (đang tải, lỗi, và hai tab) đều cần đúng bộ khung
  /// ấy. Chép nó bốn lần là bốn chỗ phải sửa khi đổi một cái nút.
  ///
  /// Tiêu đề lớn "Mục tiêu tiết kiệm" từng lặp lại trong thân trang, ngay dưới
  /// thanh tiêu đề đã nói đúng câu đó. Thêm hàng tab vào giữa thì ba tầng chữ
  /// chồng nhau chiếm gần một phần tư màn hình 411dp trước khi thấy mục tiêu
  /// đầu tiên, nên bản lặp bị bỏ.
  Widget _khungTrang(BuildContext context,
      {required Widget body, TabBar? tabBar}) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Mục tiêu tiết kiệm',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          NotificationBell(
            unreadCount: currentAccountIdOrNull(context) == null
                ? null
                : sl<AppDatabase>()
                    .notificationDao
                    .watchUnreadCount(currentAccountIdOrNull(context)!),
            onTap: () => context.push('/notifications'),
          ),
        ],
        bottom: tabBar,
      ),
      body: body,
    );
  }

  Widget _tabDangTheoDuoi(
    BuildContext context, {
    required List<GoalEntity> goals,
    required bool coMucTieuNaoKhong,
    required double tongDaTich,
    required double tongMucTieu,
    required NumberFormat currencyFormatter,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (goals.isEmpty)
            _khungRong(
              icon: Icons.savings_outlined,
              tieuDe: coMucTieuNaoKhong
                  ? 'Không còn mục tiêu nào đang chạy'
                  : 'Chưa có mục tiêu tiết kiệm nào',
              moTa: coMucTieuNaoKhong
                  // Nói rõ tiền đâu: người dùng vừa thấy tab bên kia có số
                  // đếm khác 0, câu "chưa có gì" ở đây sẽ mâu thuẫn với nó.
                  ? 'Mọi mục tiêu của bạn đều đã đạt. Xem lại ở tab '
                      '"Đã hoàn thành", hoặc đặt một mục tiêu mới.'
                  : 'Hãy tạo mục tiêu đầu tiên để theo dõi tiến độ tích lũy '
                      'tài chính của bạn!',
            )
          else
            ...goals.map((goal) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _theMucTieu(context, goal, currencyFormatter),
                )),
          const SizedBox(height: 16),

          // Thẻ tổng kết.
          //
          // Chỗ này trước đây là một thẻ mẹo chép từ mockup Stitch: câu "Tốc
          // độ tiết kiệm của bạn đã tăng 12% so với tháng trước" — một con số
          // cố định, không nối với dữ liệu nào — kèm nút "Xem báo cáo" có
          // `onPressed: () {}`, tức bấm vào không xảy ra gì.
          //
          // Nay nó nói đúng những gì app biết chắc, và hai con số này lấy
          // thẳng từ `GoalLoaded` chứ không tính lại — cùng nguyên tắc
          // một-định-nghĩa với `GoalEntity.progress`. Số đếm thì lấy theo tab
          // này, để câu "đang theo đuổi N" khớp với nhãn tab ngay phía trên.
          if (goals.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đang theo đuổi ${goals.length} mục tiêu',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đã tích được ${currencyFormatter.format(tongDaTich)} '
                    'trên tổng ${currencyFormatter.format(tongMucTieu)}.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          if (goals.isNotEmpty) const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await context.push('/goals/add');
              if (context.mounted) {
                final idaccount = currentAccountIdOrNull(context) ?? 0;
                context.read<GoalCubit>().loadGoals(idaccount);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'Thêm mục tiêu mới',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Tab "Đã hoàn thành".
  ///
  /// Cố ý **không** có nút "Thêm mục tiêu mới": tab này để nhìn lại, không
  /// phải để tạo. Nút ấy ở tab bên kia, cách một cú chạm.
  Widget _tabDaHoanThanh(
    BuildContext context, {
    required List<GoalEntity> goals,
    required NumberFormat currencyFormatter,
  }) {
    if (goals.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _khungRong(
          icon: Icons.emoji_events_outlined,
          tieuDe: 'Chưa có mục tiêu nào hoàn thành',
          moTa: 'Mục tiêu đạt đủ số tiền sẽ được chuyển sang đây, kèm toàn bộ '
              'lịch sử tích luỹ của nó.',
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: goals
            .map((goal) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _theMucTieu(context, goal, currencyFormatter),
                      // Lối tắt cho mục tiêu lặp lại. Chỉ là lối tắt: nó mở
                      // trang chi tiết chứ KHÔNG tự đặt lại. Một nút xoá tiến
                      // độ ngay trong danh sách là chỗ dễ bấm nhầm nhất, và
                      // thao tác này không hoàn tác được.
                      if (goal.recurrence)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: TextButton.icon(
                            onPressed: () async {
                              await context.push('/goals/${goal.id}');
                              if (context.mounted) {
                                final idaccount =
                                    currentAccountIdOrNull(context) ?? 0;
                                context.read<GoalCubit>().loadGoals(idaccount);
                              }
                            },
                            icon: const Icon(Icons.restart_alt_rounded,
                                size: 18),
                            label: const Text('Bắt đầu vòng mới'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.income,
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _khungRong({
    required IconData icon,
    required String tieuDe,
    required String moTa,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            tieuDe,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            moTa,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Một thẻ mục tiêu, dùng chung cho cả hai tab.
  Widget _theMucTieu(
    BuildContext context,
    GoalEntity goal,
    NumberFormat currencyFormatter,
  ) {
    return _buildGoalCard(
      goal: goal,
      title: goal.name,
      subtitle: 'MỤC TIÊU TIẾT KIỆM',
      // Trước đây ba dòng này là hằng số: mọi mục tiêu đều là lá cờ xanh, dù
      // `icon`/`colour` đã có trong CSDL và đồng bộ đủ hai chiều từ lâu.
      icon: bieuTuongMucTieu(goal.icon),
      iconColor: mauMucTieu(goal.colour),
      iconBgColor: mauMucTieu(goal.colour).withValues(alpha: 0.1),
      currentAmount: currencyFormatter.format(goal.currentAmount),
      targetAmount: '/ ${currencyFormatter.format(goal.targetAmount)}',
      extraWidget: Row(
        children: [
          const Icon(Icons.event, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Hạn chót:',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
          Text(
            DateFormat('dd/MM/yyyy').format(goal.targetDate),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
      onTap: () async {
        await context.push('/goals/${goal.id}');
        if (context.mounted) {
          final idaccount = currentAccountIdOrNull(context) ?? 0;
          context.read<GoalCubit>().loadGoals(idaccount);
        }
      },
    );
  }

  Widget _buildGoalCard({
    required GoalEntity goal,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String currentAmount,
    required String targetAmount,
    required Widget extraWidget,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: iconColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Dấu ba chấm từng ở đây không mở menu nào — nó là hình vẽ
                // trong mockup Stitch. Mọi thao tác trên một mục tiêu (nạp,
                // rút, đổi ví, sửa, xoá) đều nằm ở trang chi tiết, và bấm vào
                // thẻ là tới đó.
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      currentAmount,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      targetAmount,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  goalPercentLabel(goal),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.income,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GoalProgressBar(goal: goal),
            const SizedBox(height: 12),
            extraWidget,
          ],
        ),
      ),
    );
  }
}
