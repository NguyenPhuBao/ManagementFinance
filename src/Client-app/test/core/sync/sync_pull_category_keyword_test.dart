/// Pull phải đọc cột `keyword` mà backend gửi kèm mỗi danh mục.
///
/// Vì sao cần: backend **đã** trả `keyword` trong `/sync/pull`
/// (`sync.repository.js`, khối `select` của `getCategoriesByAccount` có
/// `keyword: true`), nhưng mapper pull phía client bỏ qua nó hoàn toàn — cả
/// `sync_engine.dart` trước bản vá này không có một chữ `keyword` nào.
///
/// Hệ quả đo được: bảng `CategoryKeywords` của một máy vừa cài **rỗng tuyệt
/// đối**, vì hai đường seed danh mục (`AppDatabase._seedDefaultCategories` và
/// `PersonalDefaultCategories`) đều không chèn từ khoá nào, và đường ghi duy
/// nhất còn lại là người dùng tự gõ tay trong màn quản lý danh mục. Kết quả:
/// `CategorySuggestionEngine.suggest()` luôn trả `null` — thẻ gợi ý danh mục ở
/// màn thêm giao dịch **không bao giờ hiện**. Không exception, không log.
///
/// ## Quy tắc đã chốt: CHỈ GIEO KHI TRỐNG
///
/// Pull **không** ghi đè bộ từ khoá đã có của một danh mục. Lý do: từ khoá phía
/// client là dữ liệu người dùng (`CategoryKeywords` có `idaccount`, sửa được
/// trong màn quản lý danh mục), còn cột `keyword` phía backend là **một chuỗi
/// dùng chung cho mọi tài khoản**. Ghi đè mỗi chu kỳ pull sẽ làm thao tác xoá
/// từ khoá của người dùng **không bao giờ dính** — nó bị hồi sinh ở lần pull
/// sau. Đó đúng là khuôn mẫu hỏng âm thầm mà G7 và G14 đã dính.
///
/// Đánh đổi còn lại, có chủ ý: nếu người dùng xoá **hết** từ khoá của một danh
/// mục thì lần pull sau sẽ gieo lại. Chấp nhận được vì trạng thái "rỗng" không
/// phân biệt được với "chưa từng gieo" nếu không thêm cột mới — mà lược đồ vừa
/// lên v12, chưa nên bump tiếp chỉ vì việc này.
library;

import 'dart:convert';

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
  _Client() {
    dio.httpClientAdapter = adapter;
  }
  @override
  final Dio dio = Dio();
  final _Adapter adapter = _Adapter();
}

class _Adapter implements HttpClientAdapter {
  Map<String, dynamic> pullData = const {};

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/push')) {
      final ops =
          (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'results': ops
              .map((op) => {'localId': op['localId'], 'status': 'synced'})
              .toList(),
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    return ResponseBody.fromString(jsonEncode({'data': pullData}), 200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const accountId = 7;
  const nowIso = '2026-09-04T10:00:00.000Z';

  // Danh mục MẶC ĐỊNH: client lưu với idaccount = 0, nhưng từ khoá phải thuộc
  // về tài khoản đang đăng nhập — `loadKeywords` tra theo accountId người dùng,
  // không theo idaccount của hàng danh mục.
  const defaultCatId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  // Danh mục riêng của tài khoản.
  const ownCatId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

  late AppDatabase db;
  late _Client client;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    client = _Client();
    engine = SyncEngine(dioClient: client, db: db, connectivity: _Online());
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  Future<void> runSync() async {
    final done = engine.statusStream.where((s) => s.isTerminal).first;
    engine.start(idaccount: accountId);
    await done.timeout(const Duration(seconds: 5));
  }

  Map<String, dynamic> categoryPayload({
    required String id,
    required String name,
    required bool isDefault,
    String? keyword,
  }) =>
      {
        'idcategory': id,
        'create_by': isDefault ? 1 : accountId,
        'name_category': name,
        'classify': 'Chi',
        'is_default': isDefault,
        'keyword': keyword,
        'update_at': nowIso,
      };

  group('PULL — từ khoá phân loại của backend phải xuống tới client', () {
    test('Tách chuỗi CSV thành từng dòng từ khoá', () async {
      client.adapter.pullData = {
        'categories': [
          categoryPayload(
            id: defaultCatId,
            name: 'Ăn uống',
            isDefault: true,
            keyword: 'cà phê,trà sữa,cơm trưa',
          ),
        ],
      };

      await runSync();

      final keywords = await db.categoryDao.getKeywords(accountId, defaultCatId);
      expect(
        keywords.toSet(),
        {'cà phê', 'trà sữa', 'cơm trưa'},
        reason: 'Backend lưu từ khoá thành MỘT chuỗi nối bằng dấu phẩy '
            '(`classify.repository.js` ghi bằng `join(\',\')`), client lưu mỗi '
            'từ khoá một dòng. Không tách thì cả chuỗi thành một "từ khoá" dài '
            'và không bao giờ khớp với ghi chú người dùng gõ.',
      );
    });

    test('Từ khoá gắn với tài khoản đang đăng nhập, không phải idaccount của '
        'hàng danh mục', () async {
      client.adapter.pullData = {
        'categories': [
          categoryPayload(
            id: defaultCatId,
            name: 'Ăn uống',
            isDefault: true,
            keyword: 'cà phê',
          ),
        ],
      };

      await runSync();

      final row = await db.categoryDao.getById(defaultCatId);
      expect(row?.idaccount, 0,
          reason: 'Danh mục mặc định vẫn lưu với idaccount = 0 như trước.');

      expect(
        await db.categoryDao.getKeywords(accountId, defaultCatId),
        isNotEmpty,
        reason: 'Nhưng từ khoá phải tra được theo accountId NGƯỜI DÙNG: đó là '
            'thứ `CategoryManagementRepository.loadKeywords` truyền vào khi '
            'dựng danh sách ứng viên cho bộ gợi ý. Ghi bằng idaccount = 0 thì '
            'bộ gợi ý không bao giờ tìm thấy.',
      );
      expect(
        await db.categoryDao.getKeywords(0, defaultCatId),
        isEmpty,
        reason: 'Và KHÔNG được ghi thêm một bản sao dưới idaccount = 0 — '
            'bảng có UNIQUE(idaccount, categoryId, normalizedKeyword) nên bản '
            'sao thừa sẽ lọt qua ràng buộc mà vẫn gây trùng khi hiển thị.',
      );
    });

    test('KHÔNG ghi đè bộ từ khoá người dùng đã có', () async {
      await db.categoryDao.upsertAll([
        CategoriesCompanion.insert(
          id: ownCatId,
          idaccount: accountId,
          name: 'Ăn uống',
          classify: 'chi',
          updatedAt: DateTime.parse(nowIso),
        ),
      ]);
      await db.categoryDao.replaceKeywords(
        accountId: accountId,
        categoryId: ownCatId,
        keywords: const ['phở'],
        now: DateTime.parse(nowIso),
      );

      client.adapter.pullData = {
        'categories': [
          categoryPayload(
            id: ownCatId,
            name: 'Ăn uống',
            isDefault: false,
            keyword: 'cà phê,trà sữa',
          ),
        ],
      };

      await runSync();

      expect(
        await db.categoryDao.getKeywords(accountId, ownCatId),
        ['phở'],
        reason: 'Chỉ gieo khi TRỐNG. Cột `keyword` phía backend là chuỗi dùng '
            'chung cho mọi tài khoản, còn bảng client là dữ liệu riêng người '
            'dùng sửa được. Ghi đè mỗi chu kỳ pull sẽ khiến thao tác xoá từ '
            'khoá KHÔNG BAO GIỜ dính — bị hồi sinh ở lần pull sau, y hệt cách '
            'danh mục đã xoá từng bị hồi sinh ở G7.',
      );
    });

    test('Chuỗi rỗng, null, và khoảng trắng thừa đều không tạo hàng rác',
        () async {
      client.adapter.pullData = {
        'categories': [
          categoryPayload(
              id: defaultCatId, name: 'Không từ khoá', isDefault: true),
          categoryPayload(
            id: ownCatId,
            name: 'Toàn dấu phẩy',
            isDefault: false,
            keyword: ' , ,,  ',
          ),
        ],
      };

      await runSync();

      expect(await db.categoryDao.getKeywords(accountId, defaultCatId), isEmpty,
          reason: 'keyword = null là trường hợp thường gặp nhất: phần lớn danh '
              'mục trên server chưa ai đặt từ khoá.');
      expect(await db.categoryDao.getKeywords(accountId, ownCatId), isEmpty,
          reason: 'Chuỗi toàn dấu phân cách phải cho ra 0 hàng, không phải vài '
              'hàng rỗng — hàng rỗng sẽ khớp với MỌI ghi chú vì '
              '"bất kỳ chuỗi nào".contains("") luôn đúng.');
    });
  });
}
