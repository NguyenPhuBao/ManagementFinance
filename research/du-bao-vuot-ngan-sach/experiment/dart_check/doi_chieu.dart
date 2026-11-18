// Runs FlowMoney's own rule (src/Client-app/lib/features/budget/domain/nhip_chi.dart, imported by path,
// unchanged) on the cases exported by export_cases.py.
//
// The app stores the moment a transaction was entered. Berka has dates only, so each case is run with three
// times of day for the past-period transactions: 00:00, 12:00 and 23:59:59. TabFormer entries carry the minute
// of day as a third value; for them a fourth convention, "real", uses that time. "Now" is the end of day t of
// the current month, i.e. from + t days, the same checkpoint core.py uses.
//
// Usage (from experiment/): dart run dart_check/doi_chieu.dart [berka|tabformer]
//   -> results/m1_dart.json or results/m1_dart_tabformer.json
import 'dart:convert';
import 'dart:io';

import '../../../../src/Client-app/lib/features/budget/domain/nhip_chi.dart';

const gio = {
  'h00': Duration.zero,
  'h12': Duration(hours: 12),
  'h2359': Duration(hours: 23, minutes: 59, seconds: 59),
  'real': null, // minute of day from the data
};

void main(List<String> args) {
  final nguon = args.isEmpty ? 'berka' : args.first;
  final hau = nguon == 'berka' ? '' : '_$nguon';
  final vao = jsonDecode(File('results/m1_cases$hau.json').readAsStringSync()) as Map<String, dynamic>;
  final ra = <Map<String, dynamic>>[];
  for (final c in (vao['cases'] as List).cast<Map<String, dynamic>>()) {
    final from = DateTime.utc(c['y'] as int, c['m'] as int, 1);
    final to = DateTime.utc(c['y'] as int, (c['m'] as int) + 1, 1);
    final now = from.add(Duration(days: c['t'] as int));
    final x = viTriTrongKy(from, to, now);
    final S = (c['S'] as num).toDouble();
    final B = (c['B'] as num).toDouble();
    final past = (c['past'] as List).cast<Map<String, dynamic>>();
    final coGio = past.any((p) => (p['e'] as List).any((e) => (e as List).length > 2));
    final dong = <String, dynamic>{'x': x};
    for (final MapEntry(key: ten, value: lech) in gio.entries) {
      if (lech == null && !coGio) continue;
      final ky = [
        for (final p in past)
          KyChi(
            from: DateTime.utc(p['y'] as int, p['m'] as int, 1),
            to: DateTime.utc(p['y'] as int, (p['m'] as int) + 1, 1),
            khoan: [
              for (final e in (p['e'] as List).cast<List>())
                (
                  ngay: DateTime.utc(p['y'] as int, p['m'] as int, e[0] as int)
                      .add(lech ?? Duration(minutes: e[2] as int)),
                  soTien: (e[1] as num).toDouble(),
                ),
            ],
          ),
      ];
      final nhip = hocNhipChi(ky);
      if (nhip == null) {
        dong[ten] = null;
        continue;
      }
      final con = nhip.conChiMoiKhi(x);
      dong[ten] = {
        'K': nhip.soKy,
        'rmed': con,
        'share': nhip.phanDaChiMoiKhi(x),
        'duPhong': S + con, // tai_phan_bo.dart: duPhongCua = spent + conChiMoiKhi(x)
        'vuot': S + con > B,
      };
    }
    ra.add(dong);
  }
  File('results/m1_dart$hau.json').writeAsStringSync(jsonEncode(ra));
  stdout.writeln('${ra.length} cases -> results/m1_dart$hau.json');
}
