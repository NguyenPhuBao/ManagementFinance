// test/features/ai_chat/data/datasources/tro_ly_online_remote_data_source_test.dart
/// Datasource SSE của trợ lý online (spec 2026-10-11 §3.2, §4): adapter Dio giả
/// phát khung SSE theo byte — không chạm mạng. Luật rơi KHÔNG ở đây (xem duong_hoi_test).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/ai_chat/data/datasources/tro_ly_online_remote_data_source.dart';
import 'package:flowmoney/features/ai_chat/domain/su_kien_online.dart';

/// Adapter giả: trả thân SSE cho `/ai/chatbot/chat/stream`, cắt thành [goi] chunk.
class _MayChuSse implements HttpClientAdapter {
  _MayChuSse({required this.than, this.status = 200, this.goi = 1, this.nem});
  final String than;
  final int status;
  final int goi;
  final DioExceptionType? nem;
  RequestOptions? daNhan;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    daNhan = options;
    if (nem != null) throw DioException(requestOptions: options, type: nem!, message: 'giả: ${nem!.name}');
    final bytes = utf8.encode(than);
    final buoc = (bytes.length / goi).ceil().clamp(1, bytes.isEmpty ? 1 : bytes.length);
    final chunks = <Uint8List>[];
    for (var i = 0; i < bytes.length; i += buoc) {
      chunks.add(Uint8List.fromList(bytes.sublist(i, (i + buoc).clamp(0, bytes.length))));
    }
    return ResponseBody(Stream.fromIterable(chunks), status,
        headers: {Headers.contentTypeHeader: ['text/event-stream']});
  }

  @override
  void close({bool force = false}) {}
}

TroLyOnlineRemoteDataSourceImpl _dung(HttpClientAdapter may) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'))..httpClientAdapter = may;
  return TroLyOnlineRemoteDataSourceImpl(dio);
}

Future<List<SuKienOnline>> _gom(TroLyOnlineRemoteDataSource ds, {CancelToken? cancel}) =>
    ds.hoi(cauHoi: 'quỹ khẩn cấp là gì', conversationId: 'c-1',
        history: const [(role: 'user', text: 'chào'), (role: 'model', text: 'chào bạn')],
        cancel: cancel ?? CancelToken()).toList();

void main() {
  const thanThuong = 'event: meta\ndata: {"snapshotLoaded":true,"healthScore":72}\n\n'
      'event: delta\ndata: {"text":"Quỹ khẩn ","content":"Quỹ khẩn "}\n\n'
      'event: delta\ndata: {"text":"cấp là…","content":"cấp là…"}\n\n'
      'event: done\ndata: {"responseTimeMs":720}\n\n';

  test('request: POST đúng đường, Accept text/event-stream, thân message/conversationId/history, stream, 45 s', () async {
    final may = _MayChuSse(than: thanThuong);
    await _gom(_dung(may));
    final o = may.daNhan!;
    expect(o.method, 'POST');
    expect(o.path, '/ai/chatbot/chat/stream');
    expect(o.headers['Accept'], 'text/event-stream');
    expect(o.responseType, ResponseType.stream);
    expect(o.receiveTimeout, const Duration(seconds: 45));
    final body = o.data as Map<String, dynamic>;
    expect(body['message'], 'quỹ khẩn cấp là gì');
    expect(body['conversationId'], 'c-1');
    expect(body['history'], [
      {'role': 'user', 'text': 'chào'},
      {'role': 'model', 'text': 'chào bạn'},
    ]);
  });

  test('meta → bỏ; delta ×2 → ChuOnline ×2; done → XongOnline(720)', () async {
    final sk = await _gom(_dung(_MayChuSse(than: thanThuong)));
    expect(sk.map((e) => e.runtimeType).toList(), [ChuOnline, ChuOnline, XongOnline]);
    expect((sk[0] as ChuOnline).text, 'Quỹ khẩn ');
    expect((sk[1] as ChuOnline).text, 'cấp là…');
    expect((sk[2] as XongOnline).responseTimeMs, 720);
  });

  test('thân cắt thành 17 chunk byte (cắt giữa ký tự UTF-8) → cùng kết quả', () async {
    final sk = await _gom(_dung(_MayChuSse(than: thanThuong, goi: 17)));
    expect(sk.whereType<ChuOnline>().map((e) => e.text).join(), 'Quỹ khẩn cấp là…');
    expect(sk.last, isA<XongOnline>());
  });

  test('done.fallback → DuPhongOnline(reason), KHÔNG XongOnline', () async {
    const than = 'event: delta\ndata: {"text":"Hệ thống AI đám mây tạm thời không phản hồi."}\n\n'
        'event: done\ndata: {"fallback":true,"reason":"Hệ thống chưa thiết lập API Key Google Gemini"}\n\n';
    final sk = await _gom(_dung(_MayChuSse(than: than)));
    expect(sk.last, isA<DuPhongOnline>());
    expect((sk.last as DuPhongOnline).reason, contains('API Key'));
    expect(sk.whereType<XongOnline>(), isEmpty);
  });

  test('done mang khoá error (luồng dự phòng của server ném) → DuPhongOnline, không XongOnline / LoiOnline', () async {
    const than = 'event: delta\ndata: {"text":"⚠️ Sự cố kết nối…"}\n\n'
        'event: done\ndata: {"error":"Sự cố kết nối tới AI"}\n\n';
    final sk = await _gom(_dung(_MayChuSse(than: than)));
    expect(sk.last, isA<DuPhongOnline>());
    expect((sk.last as DuPhongOnline).reason, contains('Sự cố'));
    expect(sk.whereType<XongOnline>(), isEmpty);
    expect(sk.whereType<LoiOnline>(), isEmpty,
        reason: 'chatbot.service.js:229-237 → chatbot.controller.js:53: server phát chunk báo lỗi TRƯỚC done{error} '
            'nên daCoChu = true; LoiOnline sẽ đi nhánh giữ chữ và câu báo lỗi của server ở lại màn. '
            'DuPhongOnline luôn rơi về máy (luật rơi Task 4).');
  });

  test('done trống {} → XongOnline(null), không đoán thêm', () async {
    final sk = await _gom(_dung(_MayChuSse(than: 'event: done\ndata: {}\n\n')));
    expect((sk.single as XongOnline).responseTimeMs, isNull);
  });

  test('luồng ném HttpException giữa chừng (mất mạng) sau delta → [ChuOnline, LoiOnline(http null)], không ném', () async {
    final may = _MayChuNem(
        'event: delta\ndata: {"text":"nửa chừng"}\n\n', const HttpException('Connection closed while receiving data'));
    final sk = await _gom(_dung(may));
    expect(sk.map((e) => e.runtimeType).toList(), [ChuOnline, LoiOnline]);
    expect((sk.last as LoiOnline).http, isNull);
    expect(sk.whereType<XongOnline>(), isEmpty,
        reason: 'quyetDinhSauOnline có nhánh LoiOnline + daCoChu → giữ phần đã có (gián đoạn); '
            'lỗi không phải DioException mà lọt khỏi async* là nhánh ấy không bao giờ tới');
  });

  test('thân cụt giữa ký tự UTF-8, luồng đóng sạch → sự kiện cuối là LoiOnline, không ném', () async {
    final cut = utf8.encode(thanThuong).sublist(0, 195);
    final may = _MayChuNem('', null, rawBytes: cut);
    final sk = await _gom(_dung(may));
    expect(sk.last, isA<LoiOnline>(),
        reason: 'utf8.decoder ném FormatException ở close khi thân cụt giữa ký tự nhiều byte');
    expect(sk.whereType<XongOnline>(), isEmpty);
  });

  test('event error → LoiOnline(http 200, lyDo = message)', () async {
    const than = 'event: error\ndata: {"message":"Lỗi nội bộ"}\n\n';
    final sk = await _gom(_dung(_MayChuSse(than: than)));
    expect(sk.single, isA<LoiOnline>());
    expect((sk.single as LoiOnline).http, 200);
    expect((sk.single as LoiOnline).lyDo, 'Lỗi nội bộ');
  });

  for (final ma in [403, 429, 503]) {
    test('HTTP $ma → LoiOnline(http $ma), không ném ra ngoài', () async {
      final sk = await _gom(_dung(_MayChuSse(than: '{"success":false,"code":"X"}', status: ma)));
      expect(sk.single, isA<LoiOnline>());
      expect((sk.single as LoiOnline).http, ma);
    });
  }

  test('hết giờ nhận (receiveTimeout) → LoiOnline(http null)', () async {
    final sk = await _gom(_dung(_MayChuSse(than: '', nem: DioExceptionType.receiveTimeout)));
    expect(sk.single, isA<LoiOnline>());
    expect((sk.single as LoiOnline).http, isNull);
    expect((sk.single as LoiOnline).lyDo, contains('receiveTimeout'));
  });

  test('luồng đóng mà không có done → LoiOnline "đóng không done"', () async {
    const than = 'event: delta\ndata: {"text":"một nửa"}\n\n';
    final sk = await _gom(_dung(_MayChuSse(than: than)));
    expect(sk.first, isA<ChuOnline>());
    expect(sk.last, isA<LoiOnline>());
    expect((sk.last as LoiOnline).lyDo, contains('không done'));
  });

  test('dòng data không phải JSON → bỏ qua, luồng đi tiếp', () async {
    const than = 'event: delta\ndata: không json\n\nevent: done\ndata: {"responseTimeMs":1}\n\n';
    final sk = await _gom(_dung(_MayChuSse(than: than)));
    expect(sk.single, isA<XongOnline>());
  });

  test('huỷ qua CancelToken trước khi gọi → LoiOnline lyDo chứa "cancel", không ném', () async {
    final cancel = CancelToken()..cancel('người dùng dừng');
    final sk = await _gom(_dung(_MayChuSse(than: thanThuong)), cancel: cancel);
    expect(sk.single, isA<LoiOnline>());
    expect((sk.single as LoiOnline).lyDo.toLowerCase(), contains('cancel'));
  });
}

/// Adapter giả: phát [phan] (hoặc [rawBytes]) rồi ném [loi] (nếu có) từ chính luồng thân.
class _MayChuNem implements HttpClientAdapter {
  _MayChuNem(this.phan, this.loi, {this.rawBytes});
  final String phan;
  final Object? loi;
  final List<int>? rawBytes;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    Stream<Uint8List> luong() async* {
      yield Uint8List.fromList(rawBytes ?? utf8.encode(phan));
      if (loi != null) throw loi!;
    }

    return ResponseBody(luong(), 200, headers: {Headers.contentTypeHeader: ['text/event-stream']});
  }

  @override
  void close({bool force = false}) {}
}
