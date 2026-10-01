/// Một cú chạm vào thông báo hệ điều hành, **thô**: payload gốc (chính là
/// `dedupeKey`) và mã nút nếu có. Router biến nó thành route bằng
/// `khoaSauChamNut`; nhật ký B5a ghi nó bằng [suKienTuCham].
library;

import 'notification_actions.dart';
import 'su_kien_thong_bao.dart';

class ChamHdh {
  final String payload;
  final String? actionId;
  const ChamHdh(this.payload, [this.actionId]);

  @override
  bool operator ==(Object other) =>
      other is ChamHdh && other.payload == payload && other.actionId == actionId;

  @override
  int get hashCode => Object.hash(payload, actionId);

  @override
  String toString() => 'ChamHdh($payload, $actionId)';
}

String suKienTuCham(ChamHdh c) => switch (c.actionId) {
      hanhDongTraNgay => SuKienThongBao.nutTraNgay,
      hanhDongHoan => SuKienThongBao.hoan,
      _ => SuKienThongBao.chamHdh,
    };
