// Recompute, outside the app, what FlowMoney's budget-detail page shows for the users loaded by app_load.py:
// "Theo nhịp thường lệ" = B x phanDaChiMoiKhi(x), and the end-of-period projection S + conChiMoiKhi(x).
// Runs nhip_chi.dart from src/Client-app unchanged. Wall-clock times (Vietnam, no DST) are handled as UTC
// values on both sides, which leaves every time difference unchanged.
//
// Usage (from experiment/): dart run dart_check/app_check.dart N 2026-11-10T09:40:00 [more times...]
import 'dart:convert';
import 'dart:io';

import '../../../../src/Client-app/lib/features/budget/domain/nhip_chi.dart';

DateTime t(String s) => DateTime.parse('${s}Z');

void main(List<String> args) {
  final n = int.parse(args.first);
  final users = jsonDecode(File('results/app_users.json').readAsStringSync()) as List;
  final u = users[n - 1] as Map<String, dynamic>;
  final tx = [
    for (final r in (u['transactions'] as List).cast<Map<String, dynamic>>())
      (ngay: t(r['date'] as String), soTien: (r['amount'] as num).toDouble())
  ];
  final ky = [
    for (var m = 5; m <= 10; m++)
      KyChi(
        from: DateTime.utc(2026, m, 1),
        to: DateTime.utc(2026, m + 1, 1),
        khoan: [for (final k in tx) if (!k.ngay.isBefore(DateTime.utc(2026, m, 1)) && k.ngay.isBefore(DateTime.utc(2026, m + 1, 1))) k],
      )
  ];
  final nhip = hocNhipChi(ky)!;
  final b = ((u['budget'] as num) / 1000).round() * 1000.0;
  final from = DateTime.utc(2026, 11, 1), to = DateTime.utc(2026, 12, 1);
  for (final s in args.skip(1)) {
    final now = t(s);
    final spent = [for (final k in tx) if (!k.ngay.isBefore(from) && !k.ngay.isAfter(now)) k.soTien].fold(0.0, (a, x) => a + x);
    final x = viTriTrongKy(from, to, now);
    final share = nhip.phanDaChiMoiKhi(x);
    print('ROW|n=$n now=$s K=${nhip.soKy} B=${b.toStringAsFixed(0)} spent=${spent.toStringAsFixed(0)} '
        'x=${x.toStringAsFixed(5)} expected=${(b * share).toStringAsFixed(0)} '
        'projection=${(spent + nhip.conChiMoiKhi(x)).toStringAsFixed(0)} spentShare=${(spent / b).toStringAsFixed(4)} paceShare=${share.toStringAsFixed(4)}');
  }
}
