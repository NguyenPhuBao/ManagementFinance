/// Adapter tool `danh_sach_muc_tieu`: bộ chỉnh tham số theo câu hỏi
/// (`chinhThamSoMucTieu`) → đọc repository → `hangMucTieu`.
///
/// Lát 3 Task 10: đọc thêm ví (`watchAll` — BẢNG TRA, cần thấy cả ví lưu trữ để
/// nói đúng "trích tự động không chạy được") chỉ khi có mục tiêu bật trích tự
/// động. `wallet_picker_sources_test` quét `walletDao.*`, không quét repository.
library;

import '../../goal/data/repositories/goal_repository.dart';
import '../../wallet/data/repositories/wallet_repository.dart';
import '../domain/chinh_tham_so.dart';
import '../domain/cong_cu.dart';
import '../domain/hang_muc_tieu.dart';
import '../domain/hang_so_lieu.dart';

class CongCuMucTieu implements CongCu {
  CongCuMucTieu(this.mucTieu, {required this.vi, this.log = print});
  final GoalRepository mucTieu;
  final WalletRepository vi;

  /// Log khi bộ chỉnh tham số đổi gì đó — `print`, không `debugPrint` (bẫy 4.31).
  final void Function(String) log;

  @override
  KhaiBaoCongCu get khaiBao => KhaiBaoCongCu(
        ten: kTenCongCuMucTieu,
        moTa: 'Liệt kê các mục tiêu tiết kiệm đang theo đuổi theo TÊN, kèm trạng thái '
            '(đúng hay chậm kế hoạch, quá hạn), tiến độ, đã tích, số tiền mục tiêu, còn '
            'thiếu, còn bao nhiêu ngày tới hạn, theo nhịp tích luỹ hiện tại cần thêm bao '
            'nhiêu ngày, cần và đang tích mỗi kỳ; với trích tự động: kỳ trích tiếp, trích '
            'mỗi kỳ, ví nguồn có đủ tiền không. Gọi khi hỏi mục tiêu thế nào, bao giờ '
            'đạt, có kịp hạn không, mỗi tháng cần để dành bao nhiêu. Không có lịch sử '
            'từng lần nạp: hỏi lần nạp gần nhất thì dùng truy_van_giao_dich với tu_khoa là '
            'tên mục tiêu. chon: chỉ mục tiêu ở một trạng thái — hỏi mục tiêu nào chậm, '
            'quá hạn, đúng kế hoạch, ví không đủ để trích.',
        thamSo: {
          'type': 'object',
          'properties': {
            'chon': {
              'type': 'string',
              'enum': kChonMucTieu,
              'description': 'Lọc theo trạng thái: ${[
                for (final e in kChuChonMucTieu.entries) '${e.key} = ${e.value}',
              ].join('; ')}. Bỏ trống khi hỏi chung.',
            },
          },
        },
      );

  @override
  Future<KetQuaCongCu> chay(
    Map<String, dynamic> args, {
    required int idaccount,
    required DateTime now,
    String cauHoi = '',
  }) async {
    final chinh = chinhThamSoMucTieu(cauHoi, args);
    if (chinh.ghiChu.isNotEmpty) {
      log('[SLM][tool] chỉnh tham số theo câu hỏi: ${chinh.ghiChu.join('; ')}');
    }
    final chon = chinh.args['chon']?.toString().trim();
    final goals = await mucTieu.watchGoals(idaccount).first;
    Map<String, ViNguon>? viNguon;
    if (goals.any((g) => g.autoDepositEnabled)) {
      final ds = await vi.watchAll(idaccount).first;
      viNguon = {
        for (final w in ds)
          // Ví đã xoá mềm = ví không còn: bộ trích nhận `null` từ `getById`.
          if (!w.isDeleted)
            w.id: (ten: w.name, soDu: w.balance, trangThai: w.status),
      };
    }
    return hangMucTieu(
      goals,
      now: now,
      chon: (chon == null || chon.isEmpty) ? null : chon,
      viNguon: viNguon,
    );
  }
}
