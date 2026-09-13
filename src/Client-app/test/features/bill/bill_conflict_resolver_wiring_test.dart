/// `BillPaymentConflictResolver` phải được nối vào app **đúng một lần**.
///
/// Hai rủi ro khác nhau, cả hai đều không có triệu chứng nào ngoài dữ liệu sai:
///
/// 1. **Không nối** — lớp có đủ test riêng, xanh hết, nhưng chẳng bao giờ chạy
///    trong app thật. Khoản trả của máy thua nằm lại mãi.
/// 2. **Nối hai lần** — hoàn tác chạy hai lượt cho cùng một khoản chi.
///    `undoPayment` lượt sau ném `BillNotPaidException` nên không hoàn tiền
///    hai lần, nhưng đó là may chứ không phải thiết kế.
///
/// Cùng khuôn với `test/core/sync/sync_engine_start_owner_test.dart` — test
/// quét `lib/` thứ tư của dự án.
library;

import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/core/sync/sync_models.dart';

class _Online implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.wifi];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Client implements DioClient {
  @override
  final Dio dio = Dio();
}

void main() {
  test('pushResultStream chịu được HAI người nghe cùng lúc', () async {
    // `AppToast` đã nghe stream này từ `main.dart`. Nếu controller không phải
    // broadcast thì người nghe thứ hai ném `Bad state: Stream has already been
    // listened to` — LÚC CHẠY, không phải lúc biên dịch. Tức `flutter test`
    // xanh mà app chết trên máy thật.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final engine =
        SyncEngine(dioClient: _Client(), db: db, connectivity: _Online());
    addTearDown(() async {
      engine.dispose();
      await db.close();
    });

    final mot = <SyncResult>[];
    final hai = <SyncResult>[];
    final subMot = engine.pushResultStream.listen(mot.add);
    final subHai = engine.pushResultStream.listen(hai.add);
    addTearDown(() async {
      await subMot.cancel();
      await subHai.cancel();
    });

    expect(engine.pushResultStream.isBroadcast, isTrue,
        reason: 'AppToast đang nghe sẵn; stream một-người-nghe sẽ khiến '
            'BillPaymentConflictResolver ném Bad state lúc chạy.');
  });

  test('chỉ MỘT chỗ trong lib/ dựng BillPaymentConflictResolver', () {
    final lib = Directory('lib');
    final choDung = <String>[];

    for (final f in lib.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      // Chính tệp định nghĩa lớp thì không tính.
      if (f.path.replaceAll(r'\', '/').endsWith(
          'features/bill/data/services/bill_payment_conflict_resolver.dart')) {
        continue;
      }
      final noiDung = f.readAsStringSync();
      if (noiDung.contains('BillPaymentConflictResolver(')) {
        choDung.add(f.path);
      }
    }

    expect(choDung, hasLength(1),
        reason: 'Không chỗ nào dựng: lớp có đủ test riêng, xanh hết, nhưng '
            'chẳng bao giờ chạy trong app thật — khoản trả của máy thua nằm '
            'lại mãi. Dựng hai chỗ: hoàn tác chạy hai lượt cho cùng một khoản '
            'chi. Thấy: $choDung');
  });

  test('resolver được BẮT ĐẦU NGHE, không chỉ được dựng', () {
    // Dựng mà quên `batDauNghe` là lớp nằm im — cùng hậu quả với không dựng,
    // nhưng khó thấy hơn vì DI trông đã đủ.
    final choGoi = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      // Bỏ chính tệp định nghĩa: `void batDauNghe(` ở đó cũng khớp chuỗi, và
      // đếm nó vào là test tự xanh mà chẳng chứng minh điều gì.
      if (f.path.replaceAll(r'\', '/').endsWith(
          'features/bill/data/services/bill_payment_conflict_resolver.dart')) {
        continue;
      }
      if (f.readAsStringSync().contains('batDauNghe(')) choGoi.add(f.path);
    }
    expect(choGoi, hasLength(1),
        reason: 'Dựng mà quên batDauNghe là lớp nằm im — cùng hậu quả với '
            'không dựng, nhưng khó thấy hơn vì DI trông đã đủ. Thấy: $choGoi');
  });
}
