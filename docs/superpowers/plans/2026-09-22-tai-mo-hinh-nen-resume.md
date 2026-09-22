# Tải mô hình chạy nền + resume — kế hoạch thi công

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tải mô hình Gemma 4 E2B (2,41 GB) chạy tiếp khi app ở nền hoặc bị thoát, và tiếp tục được từ chỗ đứt thay vì tải lại từ đầu.

**Architecture:** Đổi mô hình trạng thái của `MoHinhTaiVe` — từ *"một `Future` đang chạy trong tiến trình này"* sang *"một lượt tải có danh tính, hỏi được từ hệ thống"*. Thêm giao diện thuần `NguonTaiNen` (bản thật bọc `background_downloader`, bản giả cho test), đúng khuôn `SlmRuntime` đang dùng cho `flutter_gemma`.

**Tech Stack:** Flutter 3.47.5 / Dart 3.13.4 · `background_downloader ^9.6.2` (đang là phụ thuộc transitive qua `flutter_gemma`, lát này nâng thành dependency trực tiếp) · Drift/SQLite (không đụng) · Android `targetSdk 36`.

**Spec:** `docs/superpowers/specs/2026-09-22-tai-mo-hinh-nen-resume-design.md`

## Global Constraints

- **Chỉ sửa `src/Client-app`.** Không đụng `src/Backend`, `src/Admin-web`, `docs/Rule_Project/*`, `docs/progress/*`.
- **Không đổi schema Drift** (đang là **v24**) và **không thêm trường đồng bộ nào**. Lát này chỉ đổi *cách tệp về máy*.
- **Mức nền phải giữ:** `flutter analyze` = **26** issue, 0 error. `flutter test` = **3348/3348** pass, **2** skip trước khi bắt đầu.
- **Hằng đã chốt, copy nguyên văn:** `kCoTepByte = 2588147712` · `kTenTep = 'gemma-4-E2B-it.litertlm'` · `kUrlMoHinh` giữ nguyên · `taskId` mới = `'gemma-4-E2B'` (hằng của dự án, **không** để gói sinh ngẫu nhiên).
- **Tiền tệ / định dạng:** không đụng — lát này không hiện số tiền nào.
- **Chạy lệnh từ `src/Client-app`.**

---

### Task 1: `NguonTaiNen` — giao diện thuần và bản giả

**Files:**
- Create: `src/Client-app/lib/features/ai_edge/data/nguon_tai_nen.dart`
- Test: `src/Client-app/test/features/ai_edge/data/nguon_tai_nen_test.dart`

**Interfaces:**
- Consumes: không có (task đầu)
- Produces: `enum TrangThaiLuot { dangCho, dangChay, tamDung, xong, hong, huy }` · `typedef TinLuot = ({TrangThaiLuot trangThai, double phanTram, String? loi})` · `abstract class NguonTaiNen` với `Future<void> batDau({required String url, required String tenTep, required bool chiWifi})`, `Future<TinLuot?> luotDangSong()`, `Future<void> tamDung()`, `Future<void> tiepTuc()`, `Future<void> huy()`, `Stream<TinLuot> get tin` · `class NguonTaiNenGia implements NguonTaiNen` (dùng trong test của Task 3 và 5)

- [ ] **Step 1: Viết test trước**

Tạo `test/features/ai_edge/data/nguon_tai_nen_test.dart`:

```dart
/// Giao diện `NguonTaiNen` và bản giả của nó.
///
/// Bản giả là thứ mọi test tầng trên dùng — nó phải cư xử đúng như bản thật ở
/// những chỗ có thể đo được mà không cần máy Android.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/data/nguon_tai_nen.dart';

void main() {
  test('bản giả: chưa bắt đầu thì KHÔNG có lượt nào đang sống', () async {
    final n = NguonTaiNenGia();
    expect(await n.luotDangSong(), isNull,
        reason: '`null` nghĩa là "không có lượt", khác hẳn "có lượt ở 0%".');
  });

  test('bản giả: batDau phát dangChay và nhớ được chiWifi', () async {
    final n = NguonTaiNenGia();
    final thu = <TinLuot>[];
    final dk = n.tin.listen(thu.add);

    await n.batDau(url: 'u', tenTep: 't', chiWifi: false);
    await Future<void>.delayed(Duration.zero);

    expect(thu.single.trangThai, TrangThaiLuot.dangChay);
    expect(n.chiWifiLanCuoi, isFalse,
        reason: 'Task 6 cần đọc lại giá trị này để kiểm hộp thoại 4G.');
    await dk.cancel();
  });

  test('bản giả: tamDung rồi tiepTuc đi qua đúng hai trạng thái', () async {
    final n = NguonTaiNenGia();
    final thu = <TrangThaiLuot>[];
    final dk = n.tin.listen((t) => thu.add(t.trangThai));

    await n.batDau(url: 'u', tenTep: 't', chiWifi: true);
    await n.tamDung();
    await n.tiepTuc();
    await Future<void>.delayed(Duration.zero);

    expect(thu, [
      TrangThaiLuot.dangChay,
      TrangThaiLuot.tamDung,
      TrangThaiLuot.dangChay,
    ]);
    await dk.cancel();
  });

  test('bản giả: huy xong thì KHÔNG còn lượt đang sống', () async {
    final n = NguonTaiNenGia();
    await n.batDau(url: 'u', tenTep: 't', chiWifi: true);
    expect(await n.luotDangSong(), isNotNull);

    await n.huy();
    expect(await n.luotDangSong(), isNull,
        reason: 'Huỷ mà vẫn báo "còn lượt" thì màn sẽ hiện tiến độ ma.');
  });

  test('bản giả: tienToi() đẩy phần trăm cho test tầng trên', () async {
    final n = NguonTaiNenGia();
    await n.batDau(url: 'u', tenTep: 't', chiWifi: true);
    n.tienToi(0.5);
    final luot = await n.luotDangSong();
    expect(luot?.phanTram, 0.5);
  });
}
```

- [ ] **Step 2: Chạy test để chắc nó ĐỎ**

Run: `flutter test test/features/ai_edge/data/nguon_tai_nen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:flowmoney/features/ai_edge/data/nguon_tai_nen.dart'`

- [ ] **Step 3: Viết bản nhỏ nhất cho test xanh**

Tạo `lib/features/ai_edge/data/nguon_tai_nen.dart`:

```dart
// lib/features/ai_edge/data/nguon_tai_nen.dart
/// Một lượt tải tệp **sống lâu hơn tiến trình app**.
///
/// ⚠️ Vì sao cần một giao diện riêng thay vì một hàm `taiTep` như trước: hàm
/// ấy là một `Future` sống *trong* tiến trình này. Khi người dùng thoát app,
/// tiến trình chết, và lúc app sống lại thì **không ai gọi hàm ấy nữa** — phải
/// hỏi hệ thống *"còn lượt nào đang chạy không"*. [luotDangSong] là câu hỏi đó,
/// và là cả lý do lớp này tồn tại.
///
/// Giao diện **thuần**, đúng khuôn `SlmRuntime`: bản thật bọc thư viện native
/// (`background_downloader`), bản giả cho test — nhờ vậy tầng trên vẫn chạy
/// được trong `flutter test` trên máy phát triển x86_64.
library;

import 'dart:async';

enum TrangThaiLuot { dangCho, dangChay, tamDung, xong, hong, huy }

typedef TinLuot = ({
  TrangThaiLuot trangThai,
  double phanTram,
  String? loi,
});

abstract class NguonTaiNen {
  /// Bắt đầu một lượt tải.
  ///
  /// [chiWifi] `false` nghĩa là người dùng **đã đồng ý** dùng dữ liệu di động.
  Future<void> batDau({
    required String url,
    required String tenTep,
    required bool chiWifi,
  });

  /// Lượt đang sống, kể cả lượt do **lần chạy trước** của app tạo ra.
  ///
  /// `null` = không có lượt nào. ⚠️ Khác hẳn *"có lượt ở 0 %"*: gộp hai thứ ấy
  /// là màn hình hiện một thanh tiến độ đứng yên cho một lượt không tồn tại.
  Future<TinLuot?> luotDangSong();

  Future<void> tamDung();

  Future<void> tiepTuc();

  Future<void> huy();

  Stream<TinLuot> get tin;
}

/// Bản giả cho test — **không** chạm mạng, không chạm nền tảng.
class NguonTaiNenGia implements NguonTaiNen {
  final _phat = StreamController<TinLuot>.broadcast();
  TinLuot? _luot;

  /// Giá trị `chiWifi` của lần [batDau] gần nhất. Test hộp thoại 4G đọc nó.
  bool? chiWifiLanCuoi;

  @override
  Stream<TinLuot> get tin => _phat.stream;

  @override
  Future<void> batDau({
    required String url,
    required String tenTep,
    required bool chiWifi,
  }) async {
    chiWifiLanCuoi = chiWifi;
    _dat((trangThai: TrangThaiLuot.dangChay, phanTram: 0, loi: null));
  }

  @override
  Future<TinLuot?> luotDangSong() async => _luot;

  @override
  Future<void> tamDung() async {
    final l = _luot;
    if (l == null) return;
    _dat((trangThai: TrangThaiLuot.tamDung, phanTram: l.phanTram, loi: null));
  }

  @override
  Future<void> tiepTuc() async {
    final l = _luot;
    if (l == null) return;
    _dat((trangThai: TrangThaiLuot.dangChay, phanTram: l.phanTram, loi: null));
  }

  @override
  Future<void> huy() async {
    _luot = null;
    _phat.add((trangThai: TrangThaiLuot.huy, phanTram: 0, loi: null));
  }

  // ── Chỉ dành cho test: đẩy lượt giả đi tới ───────────────────────────────

  void tienToi(double phanTram) {
    _dat((trangThai: TrangThaiLuot.dangChay, phanTram: phanTram, loi: null));
  }

  void choMang() {
    _dat((trangThai: TrangThaiLuot.dangCho, phanTram: _luot?.phanTram ?? 0, loi: null));
  }

  void xong() {
    _dat((trangThai: TrangThaiLuot.xong, phanTram: 1, loi: null));
  }

  void hong(String loi) {
    _dat((trangThai: TrangThaiLuot.hong, phanTram: 0, loi: loi));
  }

  /// Dựng sẵn một lượt "của lần chạy trước" mà KHÔNG phát tin nào — đúng cảnh
  /// app vừa khởi động lại: lượt có thật, nhưng stream chưa từng phát gì.
  void dungSanLuotCu(TinLuot l) => _luot = l;

  void _dat(TinLuot l) {
    _luot = l;
    _phat.add(l);
  }

  Future<void> dong() => _phat.close();
}
```

- [ ] **Step 4: Chạy test, phải XANH**

Run: `flutter test test/features/ai_edge/data/nguon_tai_nen_test.dart`
Expected: PASS — 5 ca.

- [ ] **Step 5: Commit**

```bash
git add src/Client-app/lib/features/ai_edge/data/nguon_tai_nen.dart \
        src/Client-app/test/features/ai_edge/data/nguon_tai_nen_test.dart
git commit -m "feat(ai-edge): giao diện NguonTaiNen cho lượt tải sống lâu hơn tiến trình"
```

---

### Task 2: `daCo()` kiểm kích thước, và thôi xoá tệp dở

**Files:**
- Modify: `src/Client-app/lib/features/ai_edge/data/mo_hinh_tai_ve.dart` — hàm `daCo()` và khối `catch` của `_tai()`
- Test: `src/Client-app/test/features/ai_edge/data/mo_hinh_tai_ve_test.dart` (thêm nhóm ca)

**Interfaces:**
- Consumes: `kCoTepByte` (đã có trong chính tệp ấy)
- Produces: `daCo()` nay trả `true` **chỉ khi** tệp tồn tại **và** dài đúng `kCoTepByte`

⚠️ **Hai việc trong task này KHÔNG tách rời được.** Giữ tệp dở mà vẫn để `daCo()` dùng `existsSync()` là tạo ra đúng lỗi mà chú thích cũ cảnh báo: tệp cụt đọc thành "đã có mô hình", rồi `getActiveModel` ném *"Model may be invalid"* ở một chỗ chẳng liên quan gì tới việc tải.

- [ ] **Step 1: Viết test trước**

Thêm vào cuối `test/features/ai_edge/data/mo_hinh_tai_ve_test.dart`, **bên trong** `void main() {`:

```dart
  group('daCo() kiểm KÍCH THƯỚC, không chỉ kiểm tồn tại', () {
    late Directory tam;

    setUp(() => tam = Directory.systemTemp.createTempSync('mohinh'));
    tearDown(() => tam.deleteSync(recursive: true));

    MoHinhTaiVe dung() => MoHinhTaiVe(
          thuMuc: () async => tam,
          nguon: NguonTaiNenGia(),
        );

    test('tệp dở (thiếu ĐÚNG MỘT byte) đọc là CHƯA CÓ', () async {
      final m = dung();
      File('${tam.path}/$kTenTep')
          .writeAsBytesSync(List.filled(kCoTepByte - 1, 0));
      expect(await m.daCo(), isFalse,
          reason: 'Resume giữ tệp dở lại; `existsSync()` sẽ đọc nó thành '
              '"đã có mô hình" rồi engine ném "Model may be invalid".');
    }, skip: 'tệp 2,4 GB — xem ca dưới dùng cỡ giả');

    test('tệp đúng kCoTepByte đọc là ĐÃ CÓ', () async {
      final m = dung();
      File('${tam.path}/$kTenTep').writeAsBytesSync(List.filled(8, 0));
      expect(await m.daCo(), isFalse,
          reason: '8 byte không phải 2.588.147.712 byte.');
    });

    test('không có tệp thì CHƯA CÓ', () async {
      expect(await dung().daCo(), isFalse);
    });
  });
```

⚠️ Ca "đúng kích thước" **không dựng nổi tệp 2,4 GB trong test**, nên nó được đo ở Task 7 trên máy thật. Ca ở đây đo chiều ngược lại — tệp sai cỡ phải bị từ chối — và đó là chiều gây hại.

- [ ] **Step 2: Chạy test để chắc nó ĐỎ**

Run: `flutter test test/features/ai_edge/data/mo_hinh_tai_ve_test.dart`
Expected: FAIL — `MoHinhTaiVe` chưa có tham số `nguon` (lỗi biên dịch). Đó là đỏ **đúng chỗ**: Task 3 mới đổi chữ ký. Nếu muốn tách hẳn, tạm dựng bằng `taiTep:` cũ rồi đổi ở Task 3.

- [ ] **Step 3: Sửa `daCo()`**

Trong `lib/features/ai_edge/data/mo_hinh_tai_ve.dart`, thay:

```dart
  Future<bool> daCo() async => File(await duongTep()).existsSync();
```

bằng:

```dart
  /// Tệp mô hình đã **đủ** trên máy chưa.
  ///
  /// ⚠️ Kiểm **kích thước**, không chỉ kiểm tồn tại. Từ khi có resume, một tệp
  /// tải dở được **giữ lại** để lượt sau tiếp tục — mà `existsSync()` đúng với
  /// cả tệp 650 MB lẫn tệp đủ 2,41 GB. Đọc nhầm thì engine ném *"Model may be
  /// invalid"* ở một chỗ chẳng liên quan gì tới việc tải, và người sửa lỗi đi
  /// tìm nguyên nhân trong `SlmRuntime`.
  ///
  /// Không dùng checksum: phải đọc trọn 2,41 GB mỗi lần mở màn Cài đặt AI.
  Future<bool> daCo() async {
    final f = File(await duongTep());
    if (!f.existsSync()) return false;
    return f.lengthSync() == kCoTepByte;
  }
```

- [ ] **Step 4: Thôi xoá tệp dở ở khối `catch`**

Trong `_tai()`, **xoá** khối này:

```dart
      if (dich.existsSync()) {
        try {
          dich.deleteSync();
        } catch (_) {}
      }
```

và thay bằng chú thích:

```dart
      // ⚠️ KHÔNG xoá tệp dở nữa — nó là thứ lượt sau sẽ tiếp tục. Phép chặn
      // "tệp cụt trông như tệp đủ" nay nằm ở `daCo()`, chỗ nó thuộc về.
      // Tệp chỉ bị xoá khi người dùng **huỷ** hẳn hoặc bấm "Xoá mô hình".
```

- [ ] **Step 5: Chạy lại nhóm ca, phải XANH**

Run: `flutter test test/features/ai_edge/data/mo_hinh_tai_ve_test.dart`
Expected: PASS (sau khi Task 3 đổi xong chữ ký; nếu chạy riêng Task 2 thì tạm giữ `taiTep:`).

- [ ] **Step 6: Commit**

```bash
git add src/Client-app/lib/features/ai_edge/data/mo_hinh_tai_ve.dart \
        src/Client-app/test/features/ai_edge/data/mo_hinh_tai_ve_test.dart
git commit -m "fix(ai-edge): daCo() kiểm đúng kCoTepByte, và giữ tệp dở cho resume"
```

---

### Task 3: `MoHinhTaiVe` chuyển sang `NguonTaiNen`

**Files:**
- Modify: `src/Client-app/lib/features/ai_edge/data/mo_hinh_tai_ve.dart`
- Delete: `src/Client-app/lib/features/ai_edge/data/tai_tep_dio.dart`
- Delete: `src/Client-app/test/features/ai_edge/data/tai_tep_dio_test.dart`
- Test: `src/Client-app/test/features/ai_edge/data/mo_hinh_tai_ve_test.dart`

**Interfaces:**
- Consumes: `NguonTaiNen`, `NguonTaiNenGia`, `TinLuot`, `TrangThaiLuot` (Task 1)
- Produces: `enum TrangThaiMoHinh { chuaTai, dangTai, tamDung, choMang, daTai, loi }` · `MoHinhTaiVe({required Future<Directory> Function() thuMuc, required NguonTaiNen nguon})` · `Future<void> tai({bool chiWifi = true})` · `Future<void> khoiPhuc()` · `Future<void> tamDung()` · `Future<void> tiepTuc()` · `Future<void> huy()` — `DauHuy` và `taiTep` **bị xoá**

- [ ] **Step 1: Viết test trước**

Thêm vào `test/features/ai_edge/data/mo_hinh_tai_ve_test.dart`:

```dart
  group('lượt tải sống lâu hơn tiến trình', () {
    late Directory tam;
    late NguonTaiNenGia nguon;

    setUp(() {
      tam = Directory.systemTemp.createTempSync('mohinh');
      nguon = NguonTaiNenGia();
    });
    tearDown(() {
      tam.deleteSync(recursive: true);
      nguon.dong();
    });

    MoHinhTaiVe dung() => MoHinhTaiVe(thuMuc: () async => tam, nguon: nguon);

    test('khoiPhuc() nối lại lượt của LẦN CHẠY TRƯỚC', () async {
      // Lượt có thật nhưng stream chưa từng phát gì — đúng cảnh app vừa mở lại.
      nguon.dungSanLuotCu(
        (trangThai: TrangThaiLuot.dangChay, phanTram: 0.4, loi: null),
      );
      final m = dung();
      final thu = <TienDoTai>[];
      final dk = m.tienDo.listen(thu.add);

      await m.khoiPhuc();
      await Future<void>.delayed(Duration.zero);

      expect(thu.single.trangThai, TrangThaiMoHinh.dangTai,
          reason: 'Không nối lại thì màn hiện "Chưa tải" và nút Tải sẽ đẻ '
              'lượt thứ hai ghi đè cùng một tệp.');
      expect(thu.single.phanTram, 0.4);
      await dk.cancel();
    });

    test('khoiPhuc() khi KHÔNG có lượt nào thì không phát gì', () async {
      final m = dung();
      final thu = <TienDoTai>[];
      final dk = m.tienDo.listen(thu.add);

      await m.khoiPhuc();
      await Future<void>.delayed(Duration.zero);

      expect(thu, isEmpty,
          reason: 'Phát một tin "0%" cho một lượt không tồn tại là vẽ ra '
              'thanh tiến độ ma.');
      await dk.cancel();
    });

    test('dangCho của nguồn dịch thành choMang, KHÔNG phải dangTai', () async {
      final m = dung();
      final thu = <TrangThaiMoHinh>[];
      final dk = m.tienDo.listen((t) => thu.add(t.trangThai));

      await m.tai();
      nguon.choMang();
      await Future<void>.delayed(Duration.zero);

      expect(thu.last, TrangThaiMoHinh.choMang,
          reason: 'requiresWiFi làm lượt đứng im VÔ THỜI HẠN và gói không báo '
              'lỗi gì; gộp vào dangTai là hiện 0% đứng yên mãi mãi.');
      await dk.cancel();
    });

    test('tamDung/tiepTuc đi thẳng xuống nguồn và phát đúng trạng thái',
        () async {
      final m = dung();
      final thu = <TrangThaiMoHinh>[];
      final dk = m.tienDo.listen((t) => thu.add(t.trangThai));

      await m.tai();
      await m.tamDung();
      await m.tiepTuc();
      await Future<void>.delayed(Duration.zero);

      expect(thu, [
        TrangThaiMoHinh.dangTai,
        TrangThaiMoHinh.tamDung,
        TrangThaiMoHinh.dangTai,
      ]);
      await dk.cancel();
    });

    test('huy() xoá tệp dở', () async {
      final f = File('${tam.path}/$kTenTep')..writeAsBytesSync([1, 2, 3]);
      final m = dung();
      await m.tai();
      await m.huy();
      expect(f.existsSync(), isFalse,
          reason: 'Huỷ là ý định dừng HẲN — giữ tệp dở lại thì nó chiếm chỗ '
              'mà không ai tiếp tục nó nữa.');
    });

    test('tai(chiWifi: false) truyền thẳng xuống nguồn', () async {
      final m = dung();
      await m.tai(chiWifi: false);
      expect(nguon.chiWifiLanCuoi, isFalse);
    });
  });
```

- [ ] **Step 2: Chạy test để chắc nó ĐỎ**

Run: `flutter test test/features/ai_edge/data/mo_hinh_tai_ve_test.dart`
Expected: FAIL — lỗi biên dịch: `MoHinhTaiVe` chưa nhận `nguon`, chưa có `khoiPhuc`, `TrangThaiMoHinh` chưa có `choMang`/`tamDung`.

- [ ] **Step 3: Viết lại phần thân của `MoHinhTaiVe`**

Trong `lib/features/ai_edge/data/mo_hinh_tai_ve.dart`:

Đổi enum:

```dart
enum TrangThaiMoHinh { chuaTai, dangTai, tamDung, choMang, daTai, loi }
```

**Xoá trọn lớp `DauHuy`** và chú thích của nó.

Thay thân lớp:

```dart
class MoHinhTaiVe {
  final Future<Directory> Function() thuMuc;
  final NguonTaiNen nguon;

  final _phat = StreamController<TienDoTai>.broadcast();
  StreamSubscription<TinLuot>? _nghe;

  MoHinhTaiVe({required this.thuMuc, required this.nguon}) {
    _nghe = nguon.tin.listen(_dich);
  }

  Stream<TienDoTai> get tienDo => _phat.stream;

  Future<String> duongTep() async => '${(await thuMuc()).path}/$kTenTep';

  Future<bool> daCo() async {
    final f = File(await duongTep());
    if (!f.existsSync()) return false;
    return f.lengthSync() == kCoTepByte;
  }

  /// Bắt đầu tải. [chiWifi] `false` = người dùng đã đồng ý dùng dữ liệu di động.
  Future<void> tai({bool chiWifi = true}) async {
    await nguon.batDau(url: kUrlMoHinh, tenTep: kTenTep, chiWifi: chiWifi);
  }

  /// Hỏi lại lượt tải của **lần chạy trước** và phát lại trạng thái của nó.
  ///
  /// ⚠️ Màn Cài đặt AI phải gọi hàm này khi mở, không chỉ nghe stream: lượt
  /// tải có thể đã chạy từ lần mở app trước, mà stream chỉ phát những gì xảy
  /// ra **từ lúc nghe trở đi**. Cùng họ lỗi G48.
  Future<void> khoiPhuc() async {
    final l = await nguon.luotDangSong();
    if (l == null) return;
    _dich(l);
  }

  Future<void> tamDung() => nguon.tamDung();

  Future<void> tiepTuc() => nguon.tiepTuc();

  /// Dừng HẲN: cắt lượt tải và xoá tệp dở.
  Future<void> huy() async {
    await nguon.huy();
    final f = File(await duongTep());
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
    _phat.add((trangThai: TrangThaiMoHinh.chuaTai, phanTram: 0, loi: null));
  }

  Future<void> xoa() async {
    final f = File(await duongTep());
    if (f.existsSync()) f.deleteSync();
    _phat.add((trangThai: TrangThaiMoHinh.chuaTai, phanTram: 0, loi: null));
  }

  Future<void> dong() async {
    await _nghe?.cancel();
    await _phat.close();
  }

  void _dich(TinLuot l) {
    final tt = switch (l.trangThai) {
      TrangThaiLuot.dangCho => TrangThaiMoHinh.choMang,
      TrangThaiLuot.dangChay => TrangThaiMoHinh.dangTai,
      TrangThaiLuot.tamDung => TrangThaiMoHinh.tamDung,
      TrangThaiLuot.xong => TrangThaiMoHinh.daTai,
      TrangThaiLuot.hong => TrangThaiMoHinh.loi,
      TrangThaiLuot.huy => TrangThaiMoHinh.chuaTai,
    };
    _phat.add((
      trangThai: tt,
      phanTram: l.phanTram,
      loi: l.loi == null ? null : cauLoiTai(l.loi!),
    ));
  }
}
```

Thêm import ở đầu tệp:

```dart
import 'nguon_tai_nen.dart';
```

⚠️ Giữ nguyên hàm `cauLoiTai` — nó vẫn là chỗ duy nhất biến một lỗi bất kỳ thành câu ngắn cho người đọc.

- [ ] **Step 4: Xoá đường tải Dio cũ**

```bash
git rm src/Client-app/lib/features/ai_edge/data/tai_tep_dio.dart \
       src/Client-app/test/features/ai_edge/data/tai_tep_dio_test.dart
```

⚠️ Bài học của tệp ấy **không mất theo nó** — phần *"`HttpResponse.flush()` nói dối trên kết nối đã chết"* đã nằm trong mục 9.7 `docs/AI_EDGE_FEATURE.md` và trong ghi chú vận hành `CLAUDE.md`.

- [ ] **Step 5: Chạy test, phải XANH**

Run: `flutter test test/features/ai_edge/`
Expected: PASS. Nếu đỏ ở `slm_dien_giai_test.dart`, đó là vì nó dựng `MoHinhTaiVe(taiTep: …)` — sửa sang `nguon: NguonTaiNenGia()`.

- [ ] **Step 6: Commit**

```bash
git add -A src/Client-app/lib/features/ai_edge src/Client-app/test/features/ai_edge
git commit -m "refactor(ai-edge): MoHinhTaiVe nhận NguonTaiNen, bỏ DauHuy và đường Dio"
```

---

### Task 4: Bản thật `BackgroundDownloaderTaiNen` + cấu hình nền tảng

**Files:**
- Create: `src/Client-app/lib/features/ai_edge/data/tai_nen_background_downloader.dart`
- Modify: `src/Client-app/pubspec.yaml`
- Modify: `src/Client-app/android/app/src/main/AndroidManifest.xml`
- Modify: `src/Client-app/lib/core/di/injection_container.dart`
- Test: `src/Client-app/test/core/nhan_dien_app_test.dart` (thêm 1 ca)

**Interfaces:**
- Consumes: `NguonTaiNen`, `TinLuot`, `TrangThaiLuot` (Task 1); `MoHinhTaiVe` (Task 3)
- Produces: `class BackgroundDownloaderTaiNen implements NguonTaiNen` · `const kTaskId = 'gemma-4-E2B'`

- [ ] **Step 1: Thêm gói và quyền**

`pubspec.yaml`, khối `dependencies`, ngay dưới `flutter_gemma`:

```yaml
  # Tải mô hình 2,41 GB chạy nền + resume. Vốn đã là phụ thuộc transitive của
  # `flutter_gemma`; khai trực tiếp vì lát này gọi thẳng API của nó.
  background_downloader: ^9.6.2
```

`android/app/src/main/AndroidManifest.xml`, ngay dưới `INTERNET`:

```xml
    <!-- ⚠️ Tải mô hình chạy nền. `background_downloader` khai service của nó
         với android:foregroundServiceType="dataSync", và từ Android 14 (API 34)
         mỗi loại foreground service đòi một quyền riêng — dự án targetSdk 36
         nên đây là bắt buộc. Thiếu nó thì `flutter test`, `flutter analyze` và
         `flutter build apk` ĐỀU XANH; lỗi chỉ hiện khi lượt tải thật cố lên
         foreground trên máy Android 14+. Cùng vùng mù đã cho lỗi "APK release
         thiếu INTERNET" ngày 2026-09-22. -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>
```

Run: `flutter pub get`

- [ ] **Step 2: Viết ca test đọc manifest**

Thêm vào `test/core/nhan_dien_app_test.dart`, cạnh ca `INTERNET`:

```dart
  test('manifest khai FOREGROUND_SERVICE_DATA_SYNC (Android 14+ đòi)', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
        manifest,
        contains(
            'android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"'),
        reason: 'background_downloader chạy foreground service loại dataSync; '
            'thiếu quyền thì build vẫn xanh và lượt tải chết trên máy thật.');
  });
```

- [ ] **Step 3: Chạy ca đó, phải XANH ngay** (vì Step 1 đã thêm quyền)

Run: `flutter test test/core/nhan_dien_app_test.dart`
Expected: PASS — 6 ca.

Rồi **kiểm bằng bản sai**: tạm xoá dòng quyền, chạy lại, phải ĐỎ, rồi khôi phục.

- [ ] **Step 4: Viết bản thật**

Tạo `lib/features/ai_edge/data/tai_nen_background_downloader.dart`:

```dart
// lib/features/ai_edge/data/tai_nen_background_downloader.dart
/// Bản [NguonTaiNen] thật — bọc `background_downloader`.
///
/// Tệp **duy nhất** của dự án import gói ấy, cùng khuôn `slm_runtime.dart` với
/// `flutter_gemma`: mọi tầng trên chỉ thấy [NguonTaiNen] nên test dựng được
/// bản giả mà không cần máy Android.
library;

import 'dart:async';

import 'package:background_downloader/background_downloader.dart';

import 'nguon_tai_nen.dart';

/// ⚠️ **Hằng của dự án, KHÔNG để gói sinh ngẫu nhiên.**
///
/// Id này là sợi dây duy nhất nối lượt tải của **lần chạy trước** với tiến
/// trình lần này. Id ngẫu nhiên thì sau khi app bị thoát, lượt tải vẫn chạy
/// nhưng không ai tìm lại được nó — hỏng đúng thứ lát này làm ra.
const String kTaskId = 'gemma-4-E2B';

class BackgroundDownloaderTaiNen implements NguonTaiNen {
  final _phat = StreamController<TinLuot>.broadcast();
  final _tai = FileDownloader();

  StreamSubscription<TaskUpdate>? _nghe;
  double _phanTramCuoi = 0;

  BackgroundDownloaderTaiNen() {
    _nghe = _tai.updates.listen(_nhan);
  }

  /// Phải gọi MỘT lần lúc dựng DI, trước khi màn nào hỏi [luotDangSong].
  Future<void> chuanBi() async {
    await _tai.trackTasks();
    await _tai.resumeFromBackground();
    _tai.configureNotification(
      running: const TaskNotification('Đang tải mô hình AI', '{progress}'),
      complete: const TaskNotification('Đã tải xong mô hình AI', ''),
      paused: const TaskNotification('Tạm dừng tải mô hình AI', '{progress}'),
      error: const TaskNotification('Tải mô hình AI hỏng', ''),
      progressBar: true,
    );
  }

  @override
  Stream<TinLuot> get tin => _phat.stream;

  @override
  Future<void> batDau({
    required String url,
    required String tenTep,
    required bool chiWifi,
  }) async {
    await _tai.enqueue(DownloadTask(
      taskId: kTaskId,
      url: url,
      filename: tenTep,
      baseDirectory: BaseDirectory.applicationSupport,
      updates: Updates.statusAndProgress,
      requiresWiFi: chiWifi,
      allowPause: true,
      retries: 3,
    ));
  }

  @override
  Future<TinLuot?> luotDangSong() async {
    final t = await _tai.taskForId(kTaskId);
    if (t == null) return null;
    final ghi = await _tai.database.recordForId(kTaskId);
    if (ghi == null) return null;
    final tt = _dich(ghi.status);
    if (tt == null) return null;
    return (trangThai: tt, phanTram: ghi.progress, loi: null);
  }

  @override
  Future<void> tamDung() async {
    final t = await _tai.taskForId(kTaskId);
    if (t is DownloadTask) await _tai.pause(t);
  }

  @override
  Future<void> tiepTuc() async {
    final t = await _tai.taskForId(kTaskId);
    if (t is DownloadTask) await _tai.resume(t);
  }

  @override
  Future<void> huy() async {
    await _tai.cancelTaskWithId(kTaskId);
  }

  void _nhan(TaskUpdate u) {
    if (u.task.taskId != kTaskId) return;
    if (u is TaskProgressUpdate) {
      _phanTramCuoi = u.progress;
      _phat.add((
        trangThai: TrangThaiLuot.dangChay,
        phanTram: u.progress,
        loi: null,
      ));
      return;
    }
    if (u is TaskStatusUpdate) {
      final tt = _dich(u.status);
      if (tt == null) return;
      _phat.add((
        trangThai: tt,
        phanTram: tt == TrangThaiLuot.xong ? 1 : _phanTramCuoi,
        loi: u.exception?.description,
      ));
    }
  }

  /// `null` = trạng thái không đáng phát lên giao diện.
  TrangThaiLuot? _dich(TaskStatus s) => switch (s) {
        TaskStatus.enqueued || TaskStatus.waitingToRetry =>
          TrangThaiLuot.dangCho,
        TaskStatus.running => TrangThaiLuot.dangChay,
        TaskStatus.paused => TrangThaiLuot.tamDung,
        TaskStatus.complete => TrangThaiLuot.xong,
        TaskStatus.canceled => TrangThaiLuot.huy,
        TaskStatus.failed || TaskStatus.notFound => TrangThaiLuot.hong,
      };

  Future<void> dong() async {
    await _nghe?.cancel();
    await _phat.close();
  }
}
```

⚠️ `TaskStatus.enqueued` dịch thành `dangCho` chứ không thành `dangChay`: khi `requiresWiFi` bật mà máy chỉ có 4G, lượt **nằm ở `enqueued` vô thời hạn** và không có lỗi nào được phát. Đó chính là trạng thái `choMang` mà màn phải nói ra.

- [ ] **Step 5: Nối DI**

Trong `lib/core/di/injection_container.dart`, thay khối đăng ký `MoHinhTaiVe` hiện tại:

```dart
  final taiNen = BackgroundDownloaderTaiNen();
  await taiNen.chuanBi();
  sl.registerSingleton<NguonTaiNen>(taiNen);

  sl.registerLazySingleton<MoHinhTaiVe>(
    () => MoHinhTaiVe(
      thuMuc: getApplicationSupportDirectory,
      nguon: sl<NguonTaiNen>(),
    ),
  );
```

⚠️ `registerSingleton` chứ không `registerLazySingleton` cho `NguonTaiNen`: `chuanBi()` phải chạy **trước** khi màn nào hỏi `luotDangSong()`, và lazy nghĩa là nó chỉ chạy lúc ai đó hỏi lần đầu — tức sau khi màn đã dựng xong và đã kết luận "không có lượt nào".

Thêm import:

```dart
import '../../features/ai_edge/data/nguon_tai_nen.dart';
import '../../features/ai_edge/data/tai_nen_background_downloader.dart';
```

và **xoá** import `tai_tep_dio.dart` cùng closure `taiTep: taiTepQuaDio`.

- [ ] **Step 6: Chạy trọn bộ test và analyze**

Run: `flutter analyze` → Expected: **26** issue, 0 error
Run: `flutter test` → Expected: PASS, không ca nào đỏ

- [ ] **Step 7: Commit**

```bash
git add -A src/Client-app
git commit -m "feat(ai-edge): bản NguonTaiNen thật trên background_downloader + quyền dataSync"
```

---

### Task 5: Màn Cài đặt AI — tạm dừng, tiếp tục, chờ mạng

**Files:**
- Modify: `src/Client-app/lib/features/ai_edge/presentation/pages/cai_dat_ai_page.dart`
- Test: `src/Client-app/test/features/ai_edge/presentation/cai_dat_ai_page_test.dart`

**Interfaces:**
- Consumes: `TrangThaiMoHinh` (6 giá trị, Task 3) · `MoHinhTaiVe.khoiPhuc/tamDung/tiepTuc/huy` (Task 3)
- Produces: không có (tầng trên cùng)

- [ ] **Step 1: Viết test trước**

Thêm vào `test/features/ai_edge/presentation/cai_dat_ai_page_test.dart`:

```dart
  testWidgets('mở màn thì HỎI LẠI lượt tải của lần chạy trước', (t) async {
    final nguon = NguonTaiNenGia()
      ..dungSanLuotCu(
        (trangThai: TrangThaiLuot.dangChay, phanTram: 0.3, loi: null),
      );
    final tam = Directory.systemTemp.createTempSync('caidat');
    addTearDown(() => tam.deleteSync(recursive: true));
    final m = MoHinhTaiVe(thuMuc: () async => tam, nguon: nguon);
    addTearDown(m.dong);

    await t.pumpWidget(boc(CaiDatAiPage(moHinh: m, congTac: const CongTacAi())));
    await t.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('30'), findsWidgets,
        reason: 'Không hỏi lại thì màn hiện "Chưa tải mô hình" trong khi lượt '
            'tải vẫn đang chạy ở nền, và nút Tải sẽ đẻ lượt thứ hai.');
  });

  testWidgets('trạng thái chờ mạng nói RA, không hiện như đang tải', (t) async {
    final nguon = NguonTaiNenGia();
    final tam = Directory.systemTemp.createTempSync('caidat');
    addTearDown(() => tam.deleteSync(recursive: true));
    final m = MoHinhTaiVe(thuMuc: () async => tam, nguon: nguon);
    addTearDown(m.dong);

    await t.pumpWidget(boc(CaiDatAiPage(moHinh: m, congTac: const CongTacAi())));
    await m.tai();
    nguon.choMang();
    await t.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Wi-Fi'), findsWidgets,
        reason: 'requiresWiFi làm lượt đứng im vô thời hạn mà không báo lỗi; '
            'im lặng ở đây là một thanh 0% đứng yên mãi mãi.');
  });

  testWidgets('đang tải thì có nút Tạm dừng; tạm dừng thì có Tiếp tục',
      (t) async {
    final nguon = NguonTaiNenGia();
    final tam = Directory.systemTemp.createTempSync('caidat');
    addTearDown(() => tam.deleteSync(recursive: true));
    final m = MoHinhTaiVe(thuMuc: () async => tam, nguon: nguon);
    addTearDown(m.dong);

    await t.pumpWidget(boc(CaiDatAiPage(moHinh: m, congTac: const CongTacAi())));
    await m.tai();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Tạm dừng'), findsOneWidget);

    await t.tap(find.text('Tạm dừng'));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(find.text('Tạm dừng'), findsNothing);
  });

  testWidgets('bấm Tạm dừng KHÔNG tự đặt trạng thái, mà chờ tin từ nguồn',
      (t) async {
    // Bấm Tạm dừng trên THÔNG BÁO (ngoài app) cũng phải làm màn đổi theo, nên
    // nguồn là sự thật duy nhất. Màn tự đặt trạng thái là mở đường cho hai nơi
    // nói hai điều khác nhau.
    final nguon = _NguonKhongPhanHoi();
    final tam = Directory.systemTemp.createTempSync('caidat');
    addTearDown(() => tam.deleteSync(recursive: true));
    final m = MoHinhTaiVe(thuMuc: () async => tam, nguon: nguon);
    addTearDown(m.dong);

    await t.pumpWidget(boc(CaiDatAiPage(moHinh: m, congTac: const CongTacAi())));
    await m.tai();
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.text('Tạm dừng'));
    await t.pump(const Duration(milliseconds: 50));

    expect(find.text('Tiếp tục'), findsNothing,
        reason: 'Nguồn chưa xác nhận thì màn chưa được đổi.');
  });
```

Thêm lớp phụ ở cuối tệp test:

```dart
/// Nguồn nhận lệnh nhưng KHÔNG phát tin nào — dùng để chứng minh màn không tự
/// đặt trạng thái.
class _NguonKhongPhanHoi extends NguonTaiNenGia {
  @override
  Future<void> tamDung() async {}
}
```

- [ ] **Step 2: Chạy test để chắc nó ĐỎ**

Run: `flutter test test/features/ai_edge/presentation/cai_dat_ai_page_test.dart`
Expected: FAIL — chưa có nút "Tạm dừng", chưa gọi `khoiPhuc()`.

- [ ] **Step 3: Sửa màn**

Trong `initState`, sau `unawaited(_doTrangThai());` thêm:

```dart
      // ⚠️ Lượt tải có thể đã chạy từ LẦN MỞ APP TRƯỚC — stream chỉ phát những
      // gì xảy ra từ lúc nghe trở đi, nên không hỏi lại là màn hiện "Chưa tải"
      // cho một lượt đang chạy. Cùng họ G48.
      unawaited(_moHinh?.khoiPhuc() ?? Future<void>.value());
```

Thêm hai handler:

```dart
  Future<void> _tamDung() async => _moHinh?.tamDung();

  Future<void> _tiepTuc() async => _moHinh?.tiepTuc();
```

⚠️ Cả hai **không** gọi `setState`: trạng thái đến từ stream của nguồn. Đặt tay ở đây là mở đường cho màn và thông báo hệ thống nói hai điều khác nhau.

Trong `_khoiTrangThai()`, thêm hai nhánh:

```dart
      case TrangThaiMoHinh.tamDung:
        return _khoiTamDung();
      case TrangThaiMoHinh.choMang:
        return _khoiChoMang();
```

Thêm hai widget:

```dart
  Widget _khoiTamDung() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dongTieuDe(
            icon: Icons.pause_circle_outline,
            tieuDe: 'Đã tạm dừng · ${(_phanTram * 100).toStringAsFixed(0)}%',
            phu: 'Phần đã tải được giữ lại, bấm Tiếp tục để tải nốt.',
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(value: _phanTram),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _tiepTuc,
                  child: const Text('Tiếp tục'),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(onPressed: _huy, child: const Text('Huỷ')),
            ],
          ),
        ],
      );

  Widget _khoiChoMang() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dongTieuDe(
            icon: Icons.wifi_off_outlined,
            tieuDe: 'Đang chờ Wi-Fi',
            phu: 'Lượt tải sẽ tự tiếp tục khi máy vào Wi-Fi. '
                'Phần đã tải được giữ lại.',
          ),
          const SizedBox(height: 14),
          TextButton(onPressed: _huy, child: const Text('Huỷ tải')),
        ],
      );
```

Và trong `_khoiDangTai()`, thêm nút Tạm dừng cạnh nút Huỷ hiện có:

```dart
              TextButton(onPressed: _tamDung, child: const Text('Tạm dừng')),
```

Thêm handler huỷ:

```dart
  Future<void> _huy() async => _moHinh?.huy();
```

- [ ] **Step 4: Chạy test, phải XANH**

Run: `flutter test test/features/ai_edge/presentation/cai_dat_ai_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Kiểm bố cục ở khổ 411dp**

Thêm ca:

```dart
  testWidgets('hàng nút lúc đang tải không tràn ở 411dp', (t) async {
    await t.binding.setSurfaceSize(const Size(411, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));

    final nguon = NguonTaiNenGia();
    final tam = Directory.systemTemp.createTempSync('caidat');
    addTearDown(() => tam.deleteSync(recursive: true));
    final m = MoHinhTaiVe(thuMuc: () async => tam, nguon: nguon);
    addTearDown(m.dong);

    await t.pumpWidget(boc(CaiDatAiPage(moHinh: m, congTac: const CongTacAi())));
    await m.tai();
    nguon.tienToi(0.42);
    await t.pump(const Duration(milliseconds: 50));

    expect(t.takeException(), isNull);
    expect(find.text('Tạm dừng'), findsOneWidget);
    expect(find.text('Huỷ'), findsOneWidget);
  });
```

⚠️ Hàng nút nay có **ba** phần tử (tiến độ · Tạm dừng · Huỷ) thay vì hai. Font của bộ test rộng gấp đôi ngoài đời (bẫy 4.4 `ANALYTICS_FEATURE.md`), nên ca này đỏ không có nghĩa là máy thật tràn — nhưng nó xanh thì máy thật chắc chắn không tràn.

- [ ] **Step 6: Commit**

```bash
git add -A src/Client-app/lib/features/ai_edge src/Client-app/test/features/ai_edge
git commit -m "feat(ai-edge): màn Cài đặt AI có Tạm dừng/Tiếp tục và trạng thái chờ Wi-Fi"
```

---

### Task 6: Hộp thoại dữ liệu di động

**Files:**
- Modify: `src/Client-app/lib/features/ai_edge/presentation/pages/cai_dat_ai_page.dart`
- Create: `src/Client-app/lib/features/ai_edge/domain/hoi_dung_4g.dart`
- Test: `src/Client-app/test/features/ai_edge/presentation/cai_dat_ai_page_test.dart`

**Interfaces:**
- Consumes: `MoHinhTaiVe.tai({bool chiWifi})` (Task 3)
- Produces: `const String kCauHoi4G` · `const String kCauDongY4G` (dùng lại trong test)

- [ ] **Step 1: Viết test trước**

```dart
  testWidgets('không có Wi-Fi: bấm Tải thì HỎI trước, chưa tải ngay',
      (t) async {
    final nguon = NguonTaiNenGia();
    final tam = Directory.systemTemp.createTempSync('caidat');
    addTearDown(() => tam.deleteSync(recursive: true));
    final m = MoHinhTaiVe(thuMuc: () async => tam, nguon: nguon);
    addTearDown(m.dong);

    await t.pumpWidget(boc(CaiDatAiPage(
      moHinh: m,
      congTac: const CongTacAi(),
      coWifi: () async => false,
    )));
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.text('Tải mô hình'));
    await t.pumpAndSettle();

    expect(find.text(kCauHoi4G), findsOneWidget);
    expect(nguon.chiWifiLanCuoi, isNull,
        reason: 'Chưa ai đồng ý thì chưa được bắt đầu lượt nào.');
  });

  testWidgets('đồng ý dùng 4G thì tải với chiWifi = false', (t) async {
    final nguon = NguonTaiNenGia();
    final tam = Directory.systemTemp.createTempSync('caidat');
    addTearDown(() => tam.deleteSync(recursive: true));
    final m = MoHinhTaiVe(thuMuc: () async => tam, nguon: nguon);
    addTearDown(m.dong);

    await t.pumpWidget(boc(CaiDatAiPage(
      moHinh: m,
      congTac: const CongTacAi(),
      coWifi: () async => false,
    )));
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.text('Tải mô hình'));
    await t.pumpAndSettle();
    await t.tap(find.text(kCauDongY4G));
    await t.pumpAndSettle();

    expect(nguon.chiWifiLanCuoi, isFalse);
  });

  testWidgets('có Wi-Fi: bấm Tải thì tải thẳng, KHÔNG hỏi', (t) async {
    final nguon = NguonTaiNenGia();
    final tam = Directory.systemTemp.createTempSync('caidat');
    addTearDown(() => tam.deleteSync(recursive: true));
    final m = MoHinhTaiVe(thuMuc: () async => tam, nguon: nguon);
    addTearDown(m.dong);

    await t.pumpWidget(boc(CaiDatAiPage(
      moHinh: m,
      congTac: const CongTacAi(),
      coWifi: () async => true,
    )));
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.text('Tải mô hình'));
    await t.pumpAndSettle();

    expect(find.text(kCauHoi4G), findsNothing);
    expect(nguon.chiWifiLanCuoi, isTrue);
  });
```

- [ ] **Step 2: Chạy test để chắc nó ĐỎ**

Run: `flutter test test/features/ai_edge/presentation/cai_dat_ai_page_test.dart`
Expected: FAIL — `CaiDatAiPage` chưa có tham số `coWifi`, chưa có `kCauHoi4G`.

- [ ] **Step 3: Viết chuỗi và phép hỏi**

Tạo `lib/features/ai_edge/domain/hoi_dung_4g.dart`:

```dart
// lib/features/ai_edge/domain/hoi_dung_4g.dart
/// Chuỗi của hộp thoại "tải bằng dữ liệu di động".
///
/// Tách khỏi màn để test khẳng định đúng câu người dùng đọc, thay vì chép lại
/// chuỗi ở hai nơi rồi để chúng trôi khỏi nhau.
library;

const String kCauHoi4G = 'Tải bằng dữ liệu di động?';

const String kCauMoTa4G =
    'Tệp nặng 2,41 GB. Tải bằng Wi-Fi thì không tốn dung lượng gói cước.';

const String kCauDongY4G = 'Tải tiếp';

const String kCauTuChoi4G = 'Để sau';
```

Trong `cai_dat_ai_page.dart`, thêm tham số:

```dart
  /// Máy có đang ở Wi-Fi không. Tiêm để test dựng được cả hai nhánh mà không
  /// chạm nền tảng; đường chạy thật đọc `Connectivity()`.
  final Future<bool> Function()? coWifi;
```

Đổi `_tai()`:

```dart
  Future<void> _tai() async {
    final wifi = await (widget.coWifi?.call() ?? _doWifiThat());
    if (!mounted) return;

    var chiWifi = true;
    if (!wifi) {
      final dongY = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text(kCauHoi4G),
              content: const Text(kCauMoTa4G),
              actions: [
                TextButton(
                  onPressed: () => c.pop(false),
                  child: const Text(kCauTuChoi4G),
                ),
                TextButton(
                  onPressed: () => c.pop(true),
                  child: const Text(kCauDongY4G),
                ),
              ],
            ),
          ) ??
          false;
      if (!dongY) return;
      chiWifi = false;
    }

    await _moHinh?.tai(chiWifi: chiWifi);
  }

  Future<bool> _doWifiThat() async {
    final kq = await Connectivity().checkConnectivity();
    return kq.contains(ConnectivityResult.wifi);
  }
```

⚠️ `_tai()` **không** còn `setState` đặt `dangTai` như bản cũ — trạng thái đến từ stream. Đặt tay ở đây là vẽ ra "đang tải" cho một lượt có thể chưa bắt đầu (đang chờ Wi-Fi).

Thêm import `package:connectivity_plus/connectivity_plus.dart` (gói đã có trong dự án — kiểm bằng `grep connectivity_plus pubspec.yaml`).

- [ ] **Step 4: Chạy test, phải XANH**

Run: `flutter test test/features/ai_edge/presentation/cai_dat_ai_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A src/Client-app/lib/features/ai_edge src/Client-app/test/features/ai_edge
git commit -m "feat(ai-edge): hỏi trước khi tải 2,41 GB bằng dữ liệu di động"
```

---

### Task 7: Nghiệm thu máy thật + tài liệu

**Files:**
- Modify: `docs/AI_EDGE_FEATURE.md` — mục 4 (bẫy mới), mục 9 (bổ sung 9.8)
- Modify: `docs/PROJECT_CONTEXT.md` mục 14 · `CLAUDE.md` (mốc test, hàng AI Edge-SLM)

- [ ] **Step 1: analyze + trọn bộ test**

Run: `flutter analyze` → Expected: **26** issue, 0 error
Run: `flutter test` → Expected: PASS. Đếm ca mới bằng máy:
`flutter test test/features/ai_edge test/features/ai_chat`

- [ ] **Step 2: Nghiệm thu trên MÁY THẬT — sáu phép đo**

`flutter build apk --release --target-platform android-arm64` rồi cài lên OnePlus 13R.

⚠️ Xoá mô hình cũ trước (nút "Xoá mô hình") để lượt tải bắt đầu từ 0.

| # | Phép đo | Đạt khi |
|---|---|---|
| 1 | Bắt đầu tải → **vuốt app khỏi recents** | thông báo vẫn chạy, `%` vẫn tăng |
| 2 | Mở lại app → vào Cài đặt AI | hiện **đúng tiến độ đang chạy**, không hiện "Chưa tải" |
| 3 | Bấm **Tạm dừng trên thông báo** → mở app | màn hiện trạng thái tạm dừng |
| 4 | Tắt Wi-Fi giữa lượt (`adb shell svc wifi disable`) | chuyển "Đang chờ Wi-Fi"; bật lại thì **tự tiếp** |
| 5 | Ngắt giữa chừng rồi tiếp tục | **kích thước tệp không giảm** — đo bằng `adb`, xem cảnh báo dưới |
| 6 | Tải xong | `daCo()` true, mô hình nạp được, hỏi đáp trả lời |

⚠️ **Đo phép 5 bằng kích thước tệp, đừng tin con số phần trăm**: phần trăm là thứ chính lát này tính ra, nên dùng nó nghiệm thu chính nó là một vòng lặp kín. Bản `--release` không `run-as` được, nên đo gián tiếp: ghi lại `%` trước khi ngắt, và sau khi tải xong kiểm tệp đủ `kCoTepByte` — tệp đủ cỡ chứng minh phần đã tải không bị ném đi.

⚠️ **Tải 2,41 GB ở 97 KB/s mất ~7 giờ.** Để đo trong một buổi, dùng lại mẹo của Task 9: tải tệp trên máy tính, phục vụ qua một HTTP server cục bộ có hỗ trợ `Range`, `adb reverse tcp:8099 tcp:8099`, và trỏ `kUrlMoHinh` tạm vào `http://127.0.0.1:8099/…` — **hoàn tác, không commit**. Server phải trả `Accept-Ranges: bytes` và `206`, nếu không **chính phép resume không đo được**.

- [ ] **Step 3: Ghi bảng đo vào `docs/AI_EDGE_FEATURE.md` mục 9.8**

Ghi: kết quả sáu phép trên; thời gian tải thật; có lỗi nào chỉ máy thật thấy không.

- [ ] **Step 4: Thêm bẫy mới vào mục 4**

Ít nhất bốn hàng: tệp dở đọc thành "đã có" · lượt mồ côi · `choMang` gộp vào `dangTai` · ba nơi giữ `tamDung` lệch nhau. Mỗi hàng ghi **ca test canh**.

- [ ] **Step 5: Cập nhật `PROJECT_CONTEXT.md` và `CLAUDE.md`**

Mốc test mới (đếm bằng máy), hàng *"Đụng vào AI Edge-SLM"*, và ⚠️ **gỡ câu cũ** nói đường tải dùng `Dio` — `grep -rn "tai_tep_dio\|DauHuy\|taiTep" docs/ CLAUDE.md` rồi sửa từng chỗ.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "docs(ai-edge): tải nền + resume xong — bảng đo máy thật và bốn bẫy mới"
```

---

## Ghi chú cho người thi công

**Ba thứ lát này KHÔNG làm** (spec mục 9): không checksum · không hàng đợi nhiều mô hình · không đụng `SlmRuntime`, khối Nhận xét, schema, payload.

**Một rủi ro đã biết:** lát này làm việc tải *chịu được gián đoạn*, **không** làm nó nhanh hơn. Trên mạng 97 KB/s người dùng vẫn chờ nhiều giờ — chỉ khác là họ không phải ngồi nhìn màn hình.

**Thứ tự task có ràng buộc:** Task 2 và 3 phải vào cùng một lượt làm việc (Task 2 đổi `daCo()`, Task 3 đổi chữ ký hàm dựng — chạy riêng Task 2 sẽ đỏ biên dịch trừ khi tạm giữ `taiTep:`). Task 4 phải xong trước khi nghiệm thu máy thật ở Task 7.
