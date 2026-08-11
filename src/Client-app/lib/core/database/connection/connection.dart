import 'package:drift/drift.dart';

import 'unsupported.dart'
    if (dart.library.js_interop) 'web.dart'
    if (dart.library.html) 'web.dart'
    if (dart.library.io) 'native.dart';

QueryExecutor openConnection() => connect();
