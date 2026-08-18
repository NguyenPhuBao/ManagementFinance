import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor connect() {
  return LazyDatabase(() async {
    // ignore: experimental_member_use
    return WebDatabase.withStorage(DriftWebStorage.indexedDb('flowmoney'));
  });
}
