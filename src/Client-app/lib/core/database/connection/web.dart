import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor connect() {
  return LazyDatabase(() async {
    return WebDatabase('flowmoney');
  });
}
