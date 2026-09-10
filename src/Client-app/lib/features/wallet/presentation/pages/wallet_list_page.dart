import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/wallet_status.dart';
import '../../domain/wallet_type.dart';
import '../widgets/wallet_type_icon.dart';
import '../../../../core/auth/current_account.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/data/models/user_model.dart';
import '../../../../shared/theme/app_colors.dart';
import '../bloc/wallet_cubit.dart';
import '../../data/models/wallet_entity.dart';

/// WalletListPage — hiển thị danh sách ví thực từ DB local chuẩn thiết kế Stitch UI.
class WalletListPage extends StatelessWidget {
  const WalletListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // `watch` chứ không `read` (G17): `read` không đăng ký gì, và
    // `BlocProvider.create` chỉ chạy MỘT lần — trang dựng trước khi phiên
    // khôi phục xong sẽ gọi `loadWallets(0)` rồi không bao giờ hỏi lại.
    final authState = context.watch<AuthBloc>().state;
    final user = (authState is AuthSuccess) ? authState.user : null;

    // Phép suy mã tài khoản có ĐÚNG MỘT định nghĩa, ở
    // `core/auth/current_account.dart` (bài học G4). Trang này từng chép tay
    // `int.tryParse(user?.id ?? '') ?? 0` — bản chép tay cuối cùng còn sót.
    final idaccount = currentAccountIdOrNull(context) ?? 0;

    return BlocProvider<WalletCubit>(
      // Khoá theo mã tài khoản: phiên tới thì khoá đổi và `create` chạy lại.
      key: ValueKey(idaccount),
      create: (_) => sl<WalletCubit>()..loadWallets(idaccount),
      child: _WalletListView(idaccount: idaccount, user: user),
    );
  }
}

class _WalletListView extends StatelessWidget {
  final int idaccount;
  final UserModel? user;

  const _WalletListView({required this.idaccount, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Danh sách ví',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocConsumer<WalletCubit, WalletState>(
        listener: (context, state) {
          if (state is WalletOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.income,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          } else if (state is WalletError) {
            final cleanMsg = state.message
                .replaceAll('CacheException: ', '')
                .replaceAll('Exception: ', '');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(cleanMsg),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
            context.read<WalletCubit>().loadWallets(idaccount);
          }
        },
        builder: (context, state) {
          return switch (state) {
            WalletLoading() => const Center(child: CircularProgressIndicator()),
            WalletError(:final message) => _ErrorView(
                message: message,
                onRetry: () =>
                    context.read<WalletCubit>().loadWallets(idaccount),
              ),
            WalletLoaded(:final wallets, :final totalBalance) ||
            WalletOperating(:final wallets, :final totalBalance) ||
            WalletOperationSuccess(:final wallets, :final totalBalance) =>
              _buildContent(
                  context, wallets, totalBalance, state is WalletOperating),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<WalletEntity> wallets,
    double totalBalance,
    bool isOperating,
  ) {
    // Hai nhóm, một nguồn: `WalletCubit` tải MỌI ví (kể cả lưu trữ) vì màn
    // này là chỗ duy nhất trong app còn thấy chúng — bỏ lưu trữ phải làm
    // được từ đây. Việc chia nhóm là việc hiển thị, nên nó nằm ở đây.
    final viHoatDong =
        wallets.where((w) => WalletStatus.laHoatDong(w.status)).toList();
    final viLuuTru =
        wallets.where((w) => !WalletStatus.laHoatDong(w.status)).toList();
    final soViLuuTru = viLuuTru.length;

    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCard(totalBalance, soViLuuTru),
                const SizedBox(height: 24),
                _buildWalletListHeader(),
                const SizedBox(height: 12),
                _buildWalletList(context, viHoatDong),
                if (viLuuTru.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _MucLuuTru(
                    vi: viLuuTru,
                    idaccount: idaccount,
                  ),
                ],
                const SizedBox(height: 24),
                _buildBankIntegrationSection(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        if (isOperating)
          Container(
            color: Colors.black.withValues(alpha: 0.15),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildOverviewCard(double totalBalance, int soViLuuTru) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TỔNG TÀI SẢN',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(totalBalance),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: AppColors.primary,
            ),
          ),
          // Thiếu dòng này thì người dùng lưu trữ một ví, thấy tổng tài sản
          // tụt đúng số dư ví ấy, và không màn nào nói vì sao. Chỉ hiện khi
          // thật sự có ví lưu trữ — nếu không nó là một dòng nhiễu vĩnh viễn.
          if (soViLuuTru > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Không gồm $soViLuuTru ví đã lưu trữ',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Nút "SẮP XẾP" của thiết kế Stitch đã gỡ khỏi đây: `onTap` của nó là một
  /// thân hàm rỗng, nên nó hiện đầy đủ trên màn hình mà không làm gì. Nó quay
  /// lại cùng tính năng sắp xếp thật — thứ tự hiện tại đã ổn định (ví mặc định
  /// rồi tới tên, xem `WalletDao`), nên chỗ này không còn hứa suông nào.
  Widget _buildWalletListHeader() {
    return const Text(
      'DANH SÁCH VÍ',
      style: TextStyle(
        fontSize: 12,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildWalletList(BuildContext context, List<WalletEntity> wallets) {
    return Column(
      children: [
        ...wallets.map((w) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _WalletItem(
              wallet: w,
              onTap: () async {
                final result = await context.push('/wallets/${w.id}/edit');
                if (result == true && context.mounted) {
                  context.read<WalletCubit>().loadWallets(idaccount);
                }
              },
              onDelete: () => _confirmDelete(context, w),
              onArchive: () => doiLuuTru(context, w, idaccount),
            ),
          );
        }),
        _buildAddWalletButton(context),
      ],
    );
  }

  Widget _buildAddWalletButton(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await context.push('/wallets/add');
        if (result == true && context.mounted) {
          context.read<WalletCubit>().loadWallets(idaccount);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.6),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'Thêm ví mới',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WalletEntity wallet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ví?'),
        content: Text('Bạn có chắc muốn xóa ví "${wallet.name}"?\n'
            'Các giao dịch sẽ vẫn được lưu lại.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      context.read<WalletCubit>().deleteWallet(
            walletId: wallet.id,
            walletName: wallet.name,
            idaccount: idaccount,
          );
    }
  }

  Widget _buildBankIntegrationSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LIÊN KẾT NGÂN HÀNG',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => context.push('/wallets/bank-link'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Liên kết tài khoản ngân hàng',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Đổi trạng thái lưu trữ của một ví, kèm một câu xác nhận.
///
/// Hộp thoại **chỉ hỏi ở chiều lưu trữ**: bỏ lưu trữ là hành động khôi phục,
/// không mất gì, nên bắt xác nhận chỉ là một cú chạm thừa.
///
/// Câu cảnh báo nói thẳng hai thứ sẽ DỪNG. Ví đang gắn mục tiêu hoặc hoá đơn
/// tự động vẫn lưu trữ được — chốt chặn cố ý không cản, vì lưu trữ chính là
/// lối thoát cho những ví không xoá nổi — nhưng hai bộ chạy tự động sẽ bỏ qua
/// ví ấy, và im lặng ở đây là người dùng mất một kỳ nạp mà không biết.
Future<void> doiLuuTru(
  BuildContext context,
  WalletEntity wallet,
  int idaccount,
) async {
  final dangLuuTru = !WalletStatus.laHoatDong(wallet.status);

  if (!dangLuuTru) {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lưu trữ ví?'),
        content: Text(
          'Ví "${wallet.name}" sẽ được cất đi: không hiện ra khi ghi giao '
          'dịch, không cộng vào tổng tài sản, và mọi khoản trả hoá đơn hay '
          'nạp mục tiêu tự động từ ví này sẽ dừng lại.\n\n'
          'Số dư và toàn bộ lịch sử giao dịch được giữ nguyên. Bạn có thể bỏ '
          'lưu trữ bất cứ lúc nào.',
        ),
        actions: [
          // `Navigator.pop`, KHÔNG phải `ctx.pop` của go_router: hộp thoại
          // này nằm ngoài cây route, và `ctx.pop` ở đó ném 'No GoRouter
          // found in context'. Cùng cách viết với hộp thoại xoá ví ngay
          // dưới đây.
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lưu trữ'),
          ),
        ],
      ),
    );
    if (dongY != true || !context.mounted) return;
  }

  await context.read<WalletCubit>().setArchived(
        walletId: wallet.id,
        luuTru: !dangLuuTru,
        idaccount: idaccount,
      );
}

/// Mục "ĐÃ LƯU TRỮ (n)" ở cuối danh sách ví — thu gọn được.
///
/// Mở sẵn khi vào trang, theo thiết kế Stitch: người dùng mở màn này để LÀM gì
/// đó với ví, và thứ họ hay tìm nhất ở đây là đường bỏ lưu trữ.
class _MucLuuTru extends StatefulWidget {
  const _MucLuuTru({required this.vi, required this.idaccount});

  final List<WalletEntity> vi;
  final int idaccount;

  @override
  State<_MucLuuTru> createState() => _MucLuuTruState();
}

class _MucLuuTruState extends State<_MucLuuTru> {
  bool _mo = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _mo = !_mo),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ĐÃ LƯU TRỮ (${widget.vi.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                Icon(
                  _mo ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_mo) ...[
          const SizedBox(height: 8),
          ...widget.vi.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WalletItem(
                wallet: w,
                // Ví lưu trữ vẫn sửa và xoá được: đóng băng nói về việc ghi
                // chép mới, không phải về quyền quản lý chính cái ví.
                onTap: () async {
                  final result =
                      await context.push('/wallets/${w.id}/edit');
                  if (result == true && context.mounted) {
                    context
                        .read<WalletCubit>()
                        .loadWallets(widget.idaccount);
                  }
                },
                onArchive: () => doiLuuTru(context, w, widget.idaccount),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WalletItem extends StatelessWidget {
  final WalletEntity wallet;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onArchive;

  const _WalletItem({
    required this.wallet,
    this.onTap,
    this.onDelete,
    this.onArchive,
  });

  bool get _daLuuTru => !WalletStatus.laHoatDong(wallet.status);

  Color get _iconColor {
    // `wallet.type == 'debt'` đã bỏ: loại ấy không còn tồn tại (xem
    // `WalletType`), và số dư âm vốn đã là điều kiện thật sự cần bắt.
    if (wallet.balance < 0) {
      return const Color(0xFFD32F2F);
    }
    if (wallet.isDefault || wallet.type == 'cash') {
      return const Color(0xFF2E7D32);
    }
    return AppColors.primary;
  }

  Color get _iconBg {
    if (wallet.balance < 0) {
      return const Color(0xFFFFEBEE);
    }
    if (wallet.isDefault || wallet.type == 'cash') {
      return const Color(0xFFC8E6C9);
    }
    return AppColors.surfaceContainerHigh;
  }

  IconData get _iconData => WalletType.tuKhoa(wallet.type).icon;

  @override
  Widget build(BuildContext context) {
    final isNegative = wallet.balance < 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(_iconData, color: _iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            // Title + Badge + Balance
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        wallet.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      if (wallet.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC8E6C9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'MẶC ĐỊNH',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                      if (_daLuuTru) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'LƯU TRỮ',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(wallet.balance),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      // Ví lưu trữ dùng màu xám cho CẢ số dư âm: thiết kế
                      // Stitch vẽ chúng mờ hẳn đi, và một con số đỏ chói
                      // trong khối 'đã cất đi' đọc như một cảnh báo cần xử
                      // lý — đúng thứ người dùng vừa chủ động dẹp sang bên.
                      color: _daLuuTru
                          ? AppColors.textSecondary
                          : (isNegative
                              ? AppColors.error
                              : AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            // Trailing action — MỘT bộ hành động cho mọi loại ví.
            //
            // Trước đây ví `bank` hiện một `Switch` THAY CHỖ menu này, nên nó
            // không có đường nào tới "Chỉnh sửa" hay "Xóa ví". Bản thân công
            // tắc ấy cũng không ghi đi đâu: nó chỉ đổi một `Map` trong `State`,
            // rời trang là mất. Thiết kế Stitch nói rõ nó là bật/tắt ví, tức
            // cột `status` — thứ đã có ở cả hai đầu CSDL nhưng client chưa
            // mang. Công tắc quay lại khi làm tính năng lưu trữ ví, gắn vào
            // `status` thật, và khi ấy nó nằm CẠNH menu chứ không thay chỗ.
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: AppColors.textSecondary, size: 20),
              onSelected: (value) {
                if (value == 'edit') onTap?.call();
                if (value == 'delete') onDelete?.call();
                if (value == 'archive') onArchive?.call();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit', child: Text('Chỉnh sửa')),
                // Chữ đổi theo trạng thái của CHÍNH ví này. Một nhãn cố
                // định là người dùng bấm mà không biết nó sẽ làm gì.
                if (onArchive != null)
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(_daLuuTru ? 'Bỏ lưu trữ' : 'Lưu trữ'),
                  ),
                if (onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Xóa ví',
                        style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
