// Runs the app's trial forecasting code (src/Client-app/lib/features/budget/domain/du_bao_vuot_ngan_sach.dart,
// imported by path, unchanged) on every row exported by `python -u app_bulk.py export`.
// For each row: the user's daily spending from their first month to day t of the current month, and B.
// Writes results/app_bulk/out.f64 (p0, p1, p2, p3 per row; NaN when the app code returns null).
//
// Usage (from experiment/): dart run dart_check/app_bulk.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../../src/Client-app/lib/features/budget/domain/du_bao_vuot_ngan_sach.dart';

Float64List docF64(String duong) {
  final b = File(duong).readAsBytesSync();
  return Float64List.view(Uint8List.fromList(b).buffer);
}

void main() {
  const dir = 'results/app_bulk';
  final meta = jsonDecode(File('$dir/meta.json').readAsStringSync()) as Map<String, dynamic>;
  final soThang = meta['months'] as int;
  final days = (meta['days'] as List).cast<int>();
  final start = (meta['start'] as List).cast<int>();
  final y = docF64('$dir/Y.f64');
  final rows = docF64('$dir/rows.f64');
  final n = meta['rows'] as int;
  final out = Float64List(n * 4);
  final dongHo = Stopwatch()..start();
  var rong = 0;
  for (var i = 0; i < n; i++) {
    final u = rows[i * 4].toInt(), m = rows[i * 4 + 1].toInt(), t = rows[i * 4 + 2].toInt();
    final b = rows[i * 4 + 3];
    final thang = <List<double>>[
      for (var k = start[u]; k <= m; k++)
        Float64List.sublistView(y, (u * soThang + k) * 31, (u * soThang + k) * 31 + (k == m ? t : days[k])),
    ];
    final kq = duBaoVuotNganSach(thang: thang, soNgayKyNay: days[m], nganSach: b);
    if (kq == null) {
      rong++;
      out.fillRange(i * 4, i * 4 + 4, double.nan);
    } else {
      out[i * 4] = kq.p0;
      out[i * 4 + 1] = kq.p1;
      out[i * 4 + 2] = kq.p2;
      out[i * 4 + 3] = kq.p3;
    }
    if (i % 50000 == 0) stdout.writeln('$i / $n  (${dongHo.elapsed.inSeconds}s)');
  }
  File('$dir/out.f64').writeAsBytesSync(out.buffer.asUint8List());
  stdout.writeln('done: $n rows, $rong null, ${dongHo.elapsed.inSeconds}s');
}
