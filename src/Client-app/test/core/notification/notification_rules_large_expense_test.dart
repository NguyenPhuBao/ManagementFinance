/// Luật "Khoản chi lớn" — loại thông báo **thứ 17** (mục #7 khảo sát lần hai).
///
/// Canh chừng điều gì: đây là loại duy nhất nhìn thẳng vào **giao dịch**, nên
/// nó thừa hưởng mọi cái bẫy của việc phân biệt "tiền thật đi ra" với "tiền đổi
/// chỗ". Ngưỡng **là** công tắc (0 = tắt), nên ca đầu tiên phải chứng minh
/// ngưỡng 0 im lặng tuyệt đối — bật nhầm là mọi bản đã cài đột nhiên bắn thông
/// báo cho những khoản người dùng tự tay gõ từ tháng trước.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/notification_rules.dart';

/// Một khoản chi bình thường: có danh mục, không ghi chú đặc biệt.
KhoanChiLon _chi(
  String id,
  double soTien, {
  DateTime? ngay,
  String loai = 'chi',
  String? categoryId = 'c1',
  String? ghiChu,
  String walletId = 'w1',
  String? tenDanhMuc = 'Mua sắm',
}) =>
    (
      id: id,
      soTien: soTien,
      ngay: ngay ?? DateTime(2026, 9, 15),
      loai: loai,
      categoryId: categoryId,
      ghiChu: ghiChu,
      walletId: walletId,
      tenDanhMuc: tenDanhMuc,
    );

NotificationRuleInput _vao({
  required List<KhoanChiLon> chiLon,
  int nguong = 1000000,
  DateTime? now,
  DateTime? silenceBefore,
}) =>
    NotificationRuleInput(
      now: now ?? DateTime(2026, 9, 17, 12),
      chiLon: chiLon,
      nguongChiLon: nguong,
      silenceBefore: silenceBefore,
    );

List<NotificationCandidate> _chay(NotificationRuleInput vao) =>
    buildNotificationCandidates(vao)
        .where((c) => c.kind == NotificationKind.largeExpense)
        .toList();

void main() {
  group('ngưỡng là công tắc', () {
    test('⚠️ ngưỡng 0 thì IM, dù có khoản một trăm triệu', () {
      // Mặc định của `nguongChiLon` là 0. Hiểu nó thành một ngưỡng thật là bật
      // tính năng cho mọi bản đã cài mà người dùng chưa hề đặt gì — đúng lỗi
      // mà `nguongSoDuThap` đã chặn từ 2026-09-07.
      final ra = _chay(_vao(chiLon: [_chi('t1', 100000000)], nguong: 0));

      expect(ra, isEmpty);
    });

    test('ngưỡng âm cũng im — không có nghĩa nào khác', () {
      final ra = _chay(_vao(chiLon: [_chi('t1', 100000000)], nguong: -1));

      expect(ra, isEmpty);
    });

    test('khoản dưới ngưỡng không báo', () {
      final ra = _chay(_vao(chiLon: [_chi('t1', 999999)], nguong: 1000000));

      expect(ra, isEmpty);
    });

    test('khoản ĐÚNG BẰNG ngưỡng thì báo', () {
      // Biên đóng: "vượt 1 triệu" mà im ở đúng 1 triệu là thứ người dùng đọc
      // thành lỗi, và không có lý lẽ nào để chọn biên mở ở đây.
      final ra = _chay(_vao(chiLon: [_chi('t1', 1000000)], nguong: 1000000));

      expect(ra, hasLength(1));
    });

    test('danh sách rỗng thì không nổ, dù ngưỡng đang bật', () {
      expect(_chay(_vao(chiLon: const [])), isEmpty);
    });
  });

  group('⚠️ khoản nào được tính là CHI', () {
    test('khoản chuyển KHÔNG báo, dù số tiền rất lớn', () {
      // Tiền đổi chỗ giữa hai ví, không rời khỏi tài sản. Không có vế này thì
      // mỗi kỳ trích tự động vào mục tiêu là một cảnh báo "chi lớn".
      final ra = _chay(_vao(chiLon: [
        _chi('t1', 50000000, loai: 'transfer', categoryId: null),
      ]));

      expect(ra, isEmpty);
    });

    test('khoản THU không báo', () {
      final ra = _chay(_vao(chiLon: [_chi('t1', 50000000, loai: 'thu')]));

      expect(ra, isEmpty);
    });

    test('khoản ĐIỀU CHỈNH SỐ DƯ không báo', () {
      // Phép sửa sổ, không phải chi tiêu. Nhận dạng đòi **cặp** điều kiện —
      // không danh mục VÀ tiền tố ghi chú — nên ca này phải dựng đủ cả hai.
      final ra = _chay(_vao(chiLon: [
        _chi('t1', 50000000, categoryId: null, ghiChu: 'Điều chỉnh số dư'),
      ]));

      expect(ra, isEmpty);
    });

    test('⚠️ khoản MỞ SỔ không báo — tạo ví 20 triệu không phải chi 20 triệu',
        () {
      // Không có vế này thì người dùng tạo một ví với số dư ban đầu 20 triệu
      // sẽ nhận ngay "Bạn vừa chi 20 triệu" — sai hẳn nghĩa, và sai im lặng.
      final ra = _chay(_vao(chiLon: [
        _chi('t1', 20000000, categoryId: null, ghiChu: 'Số dư ban đầu'),
      ]));

      expect(ra, isEmpty);
    });

    test('khoản chi KHÔNG danh mục vẫn báo — chưa phân loại là chi thật', () {
      // `khoanVaoThongKe` cố ý vẫn tính khoản chưa phân loại: giao dịch kéo về
      // từ server có thể trống danh mục, và loại theo mỗi cột ấy là giấu mất
      // chi tiêu thật.
      final ra = _chay(_vao(chiLon: [
        _chi('t1', 5000000, categoryId: null, tenDanhMuc: null),
      ]));

      expect(ra, hasLength(1));
    });
  });

  group('khoá chống trùng', () {
    test('⚠️ khoá chỉ chứa id giao dịch, KHÔNG chứa số tiền', () {
      // Số tiền trong khoá là mỗi lần sửa khoản chi đẻ một thông báo mới —
      // đúng cái bẫy 7.1 mà `budgetNear` đã phải tránh bằng cách dùng *bậc*
      // thay vì tỉ lệ thô.
      final ra = _chay(_vao(chiLon: [_chi('t-abc', 5000000)]));

      expect(ra.single.dedupeKey, 'bigSpend:t-abc');
    });

    test('cùng một giao dịch ở hai lượt quét cho cùng một khoá', () {
      final a = _chay(_vao(chiLon: [_chi('t1', 5000000)]));
      final b = _chay(_vao(
        chiLon: [_chi('t1', 5000000)],
        now: DateTime(2026, 9, 20, 9),
      ));

      expect(a.single.dedupeKey, b.single.dedupeKey,
          reason: 'Khoá không được chứa mốc quét: lượt quét sau sẽ sinh khoá '
              'mới và người dùng nhận lại đúng thông báo cũ mỗi lần mở app.');
    });

    test('hai giao dịch khác nhau cho hai khoá khác nhau', () {
      final ra = _chay(_vao(chiLon: [
        _chi('t1', 5000000),
        _chi('t2', 6000000),
      ]));

      expect(ra.map((c) => c.dedupeKey).toSet(), hasLength(2));
    });
  });

  group('mốc sự kiện và cửa sổ im lặng', () {
    test('⚠️ createdAt là NGÀY GIAO DỊCH, không phải mốc quét', () {
      final ra = _chay(_vao(
        chiLon: [_chi('t1', 5000000, ngay: DateTime(2026, 9, 10, 8))],
        now: DateTime(2026, 9, 17, 12),
      ));

      expect(ra.single.createdAt, DateTime(2026, 9, 10, 8));
    });

    test('khoản cũ hơn cửa sổ im lặng bị chặn', () {
      // Đây là thứ giữ cho lần BẬT đầu tiên không bắn hàng chục thông báo cho
      // những khoản người dùng đã tự tay gõ từ mấy tháng trước. Nó chỉ chạy
      // được vì `createdAt` là ngày giao dịch — mốc quét thì luôn là hôm nay.
      final ra = _chay(_vao(
        chiLon: [_chi('t1', 5000000, ngay: DateTime(2026, 8, 1))],
        now: DateTime(2026, 9, 17, 12),
        silenceBefore: DateTime(2026, 8, 18, 12),
      ));

      expect(ra, isEmpty);
    });

    test('khoản trong cửa sổ vẫn báo', () {
      final ra = _chay(_vao(
        chiLon: [_chi('t1', 5000000, ngay: DateTime(2026, 9, 10))],
        now: DateTime(2026, 9, 17, 12),
        silenceBefore: DateTime(2026, 8, 18, 12),
      ));

      expect(ra, hasLength(1));
    });
  });

  group('nội dung', () {
    test('nêu số tiền và tên danh mục', () {
      // Khác Tổng kết tuần (cố ý không nêu số): con số ở đây là số người dùng
      // đã gõ hoặc đã về từ ngân hàng, không phải một bản tổng hợp app tự dựng.
      final ra = _chay(_vao(chiLon: [_chi('t1', 5000000)]));

      expect(ra.single.title, 'Khoản chi lớn');
      expect(ra.single.body, 'Bạn vừa chi 5 triệu cho Mua sắm.');
    });

    test('không có danh mục thì bỏ hẳn vế "cho …"', () {
      final ra = _chay(_vao(chiLon: [
        _chi('t1', 5000000, categoryId: null, tenDanhMuc: null),
      ]));

      expect(ra.single.body, 'Bạn vừa chi 5 triệu.');
    });

    test('mức cảnh báo, chủ thể và deeplink', () {
      final ra = _chay(_vao(chiLon: [_chi('t1', 5000000)]));

      expect(ra.single.severity, NotificationSeverity.warning,
          reason: 'Một khoản chi lớn là thứ đáng nhìn lại, không phải dấu hiệu '
              'có gì đó đã sai — mức `critical` dành cho ví âm.');
      expect(ra.single.subjectType, 'transaction');
      expect(ra.single.subjectId, 't1');
      expect(ra.single.deeplink, '/transactions');
    });
  });
}
