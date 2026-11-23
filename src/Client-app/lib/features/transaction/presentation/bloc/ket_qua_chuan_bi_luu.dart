// lib/features/transaction/presentation/bloc/ket_qua_chuan_bi_luu.dart
/// Kết quả `ThemGiaoDichCubit.chuanBiLuu` — tách khỏi tệp cubit 2026-11-20 (tệp ấy chạm trần 1.200 dòng của quét 23);
/// `them_giao_dich_cubit.dart` export lại tệp này nên chỗ gọi không đổi import.
library;

import '../../../budget/domain/budget_impact.dart';
import '../../data/models/transaction_entity.dart';
import '../../domain/vi_se_am.dart';

/// Kết quả `ThemGiaoDichCubit.chuanBiLuu`.
sealed class KetQuaChuanBiLuu {
  const KetQuaChuanBiLuu();
}

/// Không lưu được — trang báo [cau] bằng toast lỗi.
class LoiLuu extends KetQuaChuanBiLuu {
  const LoiLuu(this.cau);
  final String cau;
}

/// Sẵn sàng gửi cho `TransactionBloc`.
class SanSangLuu extends KetQuaChuanBiLuu {
  const SanSangLuu({
    required this.giaoDich,
    required this.truoc,
    required this.laTach,
    required this.tacDong,
    required this.canXacNhan,
    this.viSeAm = const [],
  });

  /// Một phần tử, trừ khi [laTach].
  final List<TransactionEntity> giaoDich;

  /// Giao dịch đang sửa → `UpdateTransactionEvent(before: truoc, after: giaoDich.single)`.
  final TransactionEntity? truoc;
  final bool laTach;

  /// Tác động ngân sách cho lời nhắn sau lưu.
  final BudgetImpact? tacDong;

  /// Ngân sách *Chặn* bị vượt — rỗng = không hỏi. Tách: MỘT hộp cho cả lô.
  final List<BudgetImpact> canXacNhan;

  /// Ví KHÔNG cho âm sẽ âm vì lần ghi này — rỗng = không hỏi; có thì trang hỏi *"Vẫn ghi?"* (người dùng chốt 2026-11-20:
  /// hỏi rồi cho lưu, không chặn).
  final List<ViSeAm> viSeAm;
}
