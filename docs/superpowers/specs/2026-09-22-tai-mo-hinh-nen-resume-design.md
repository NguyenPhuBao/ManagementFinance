# Tải mô hình chạy nền + resume — thiết kế

**Ngày:** 2026-09-22 · **Trạng thái:** đã duyệt · ✅ **thi công xong 2026-09-22 tối muộn** (7 task, từ `018a1d5`;
nghiệm thu Realme RMX2205 — mục **9.10** `docs/AI_EDGE_FEATURE.md`). *(Dòng này ghi "chưa thi công" tới 2026-09-24 —
sửa ở lượt soát tài liệu của bước 2b.)*
**Mảng:** AI Edge-SLM (P3 đã xong 10/10 task) · **Người yêu cầu:** người dùng, trong lượt nghiệm thu Task 9

---

## 1. Vì sao làm — ba con số đo được, không phải phỏng đoán

Lượt nghiệm thu P3 Task 9 (2026-09-22, OnePlus 13R) dựng đúng trạng thái mà tính năng này
sinh ra để chữa:

| Đo | Kết quả |
|---|---|
| Tốc độ tải thẳng từ HuggingFace **trên máy thật** | **97 KB/s** → 2,41 GB mất **~7 giờ** |
| Lượt tải ấy | **đứt ở ~650 MB** với `HttpException: Connection closed while receiving data` |
| Phần đã tải được giữ lại | **0 byte** — `MoHinhTaiVe` xoá tệp dở ngay ở khối `catch` |

Ba con số ấy cộng lại thành một trải nghiệm không dùng được: người dùng phải **mở app và
nhìn màn hình suốt bảy tiếng**, và bất kỳ gián đoạn nào cũng ném đi toàn bộ công sức.

⚠️ Và chính phép xoá tệp dở ấy là **đúng** với thiết kế hiện tại — chú thích trong mã nói rõ
vì sao: *"một tệp cụt trông y hệt tệp đủ với `existsSync()`, và lần mở app sau sẽ nạp nó rồi
ném Model may be invalid"*. Muốn giữ tệp dở để resume thì **phải** thay phép kiểm ấy trước;
hai việc này không tách rời nhau được.

## 2. Ba quyết định của người dùng

| # | Quyết định | Hệ quả |
|---|---|---|
| 1 | **Wi-Fi mặc định, nhưng cho phép dữ liệu di động sau khi hỏi** | Một hộp thoại xác nhận, và một trạng thái *"đang chờ Wi-Fi"* phải nói ra được |
| 2 | **Thông báo có cả Huỷ lẫn Tạm dừng/Tiếp tục** | Thêm trạng thái `tamDung`, và nó phải khớp ở **ba** nơi: thông báo hệ thống · màn Cài đặt AI · trạng thái gói giữ lại sau khi app chết |
| 3 | **`daCo()` kiểm đúng `kCoTepByte` = 2.588.147.712** | Tệp dở đọc là *chưa có*; không checksum (phải đọc trọn 2,41 GB mỗi lần) |

## 3. Lối đi — và hai lối đã loại

**Chọn: đổi mô hình trạng thái của `MoHinhTaiVe`** — từ *"một `Future` đang chạy trong tiến
trình này"* sang *"một lượt tải có danh tính, hỏi được từ hệ thống"*.

Hai lối đã loại, kèm lý do:

- **Chỉ thay ruột `taiTep`, giữ nguyên `MoHinhTaiVe`.** Không làm được yêu cầu chính. Khe
  `taiTep` hiện là `Future<void> Function(url, dich, bao, dauHuy)` — một lời gọi sống *trong*
  tiến trình. Khi app bị thoát rồi sống lại, **không ai gọi `taiTep` nữa**; phải hỏi hệ thống
  *"còn lượt nào đang chạy không"*. Chữ ký ấy không diễn đạt được câu hỏi đó.
- **Dùng đường tải sẵn của `flutter_gemma`** (`installModel(...).fromNetwork`). Ít mã nhất,
  nhưng mất quyền kiểm soát **đúng ba thứ vừa chốt ở mục 2**: thông báo, ràng buộc Wi-Fi, nút
  Tạm dừng. Nó cũng tự quản tệp, trong khi quyết định 3 là app **tự kiểm** kích thước.

## 4. Giao diện mới: `NguonTaiNen`

Tệp mới `lib/features/ai_edge/data/nguon_tai_nen.dart`.

Cùng khuôn `SlmRuntime`: một **giao diện thuần** để test dựng bản giả, cộng một bản thật bọc
thư viện. Nhờ đó phần lớn logic vẫn chạy được trên máy phát triển x86_64 — thư viện tải nền
là mã native Android, `flutter test` không chạm tới.

```dart
enum TrangThaiLuot { dangCho, dangChay, tamDung, xong, hong, huy }

typedef TinLuot = ({TrangThaiLuot trangThai, double phanTram, String? loi});

abstract class NguonTaiNen {
  /// Bắt đầu một lượt. [chiWifi] false = người dùng đã đồng ý dùng dữ liệu di động.
  Future<void> batDau({required String url, required String tenTep, required bool chiWifi});

  /// Lượt đang sống của LẦN CHẠY TRƯỚC, nếu có. `null` = không có lượt nào.
  Future<TinLuot?> luotDangSong();

  Future<void> tamDung();
  Future<void> tiepTuc();
  Future<void> huy();

  Stream<TinLuot> get tin;
}
```

⚠️ **`luotDangSong()` là cả lý do lát này tồn tại.** Mọi phương thức khác đều có bản tương
đương trong mã hôm nay; riêng nó thì không, vì hôm nay không có khái niệm *"lượt tải sống lâu
hơn tiến trình"*.

Bản thật `BackgroundDownloaderTaiNen` bọc `background_downloader` 9.6.2:

| Việc | Lời gọi |
|---|---|
| Bắt đầu | `FileDownloader().enqueue(DownloadTask(url:…, filename: kTenTep, baseDirectory: BaseDirectory.applicationSupport, requiresWiFi: chiWifi, allowPause: true, retries: 3, updates: Updates.statusAndProgress))` |
| Hỏi lượt cũ | `FileDownloader().trackTasks()` + `resumeFromBackground()` ở khởi động, rồi `taskForId(kTaskId)` |
| Tạm dừng / tiếp | `pause(task)` · `resume(task)` |
| Huỷ | `cancelTaskWithId(kTaskId)` |
| Thông báo | `configureNotification(running:…, complete:…, paused:…, error:…, progressBar: true)` |

⚠️ **`taskId` phải là một hằng của dự án** (ví dụ `'gemma-4-E2B'`), không để gói sinh ngẫu
nhiên: id ấy là thứ duy nhất nối lượt tải của **lần chạy trước** với tiến trình lần này. Id
ngẫu nhiên thì sau khi app chết, lượt tải vẫn chạy nhưng **không ai tìm lại được nó** — hỏng
đúng thứ lát này làm ra.

⚠️ `BaseDirectory.applicationSupport` khớp `getApplicationSupportDirectory()` mà
`MoHinhTaiVe.thuMuc` đang dùng — **đừng đổi sang `applicationDocuments`**, tệp sẽ nằm một nơi
còn `duongTep()` trỏ một nơi khác, và triệu chứng là *"tải xong mà app bảo chưa có"*.

## 5. `MoHinhTaiVe` đổi những gì

| Bỏ | Thêm |
|---|---|
| `taiTep` (khe tiêm) | `nguon` (`NguonTaiNen`) |
| `DauHuy` — cả lớp | — (huỷ nay là `nguon.huy()`) |
| `_dangChay` (`Future?`) | `khoiPhuc()` — hỏi `luotDangSong()` rồi phát lại trạng thái |
| — | `tamDung()` · `tiepTuc()` |

`TrangThaiMoHinh` thêm **hai** giá trị: `tamDung` và `choMang`.

⚠️ `choMang` là trạng thái **riêng**, không gộp vào `dangTai`: khi `requiresWiFi: true` mà máy
chỉ có 4G, lượt tải **đứng im vô thời hạn** và gói không báo lỗi gì cả. Gộp nó vào `dangTai`
là để màn hình hiện một thanh tiến độ 0% đứng yên mãi mãi — người dùng không có cách nào biết
vì sao. Đây là bẫy thứ ba ở mục 8.

`daCo()` đổi theo quyết định 3:

```dart
Future<bool> daCo() async {
  final f = File(await duongTep());
  return f.existsSync() && f.lengthSync() == kCoTepByte;
}
```

⚠️ **Khối `catch` thôi xoá tệp dở.** Đó là đảo ngược một hành vi cố ý, nên phép kiểm kích
thước ở trên **phải vào cùng lúc** — không được tách làm hai commit. Xoá tệp vẫn xảy ra ở
`xoa()` (người dùng bấm "Xoá mô hình") và khi lượt tải bị **huỷ** hẳn.

## 6. Màn Cài đặt AI

| Trạng thái | Màn hiện |
|---|---|
| `chuaTai` | như hiện nay |
| `dangTai` | thanh tiến độ + **Tạm dừng** + **Huỷ** |
| `tamDung` | thanh tiến độ đứng + **Tiếp tục** + **Huỷ**, kèm câu nói rõ đang dừng |
| `choMang` | *"Đang chờ Wi-Fi — lượt tải sẽ tự tiếp tục khi có"* + **Huỷ** + lối đổi sang dữ liệu di động |
| `daTai` / `loi` | như hiện nay |

**Hộp thoại dữ liệu di động** hiện khi người dùng bấm Tải mà máy không có Wi-Fi: *"Tải bằng
dữ liệu di động? Tệp nặng 2,41 GB."* — Huỷ / Tải tiếp. Chọn "Tải tiếp" thì gọi
`batDau(chiWifi: false)`.

⚠️ **Màn phải gọi `khoiPhuc()` khi mở** (`initState`), không chỉ nghe stream: lượt tải có thể
đã chạy từ **lần mở app trước**, và stream chỉ phát những gì xảy ra từ lúc nghe trở đi. Đây là
cùng họ lỗi **G48** và lỗi *"quay lại từ Cài đặt AI không đọc lại trạng thái"* đã vấp ở Task 8.

## 7. Cấu hình nền tảng

**`pubspec.yaml`** — `background_downloader` chuyển từ phụ thuộc **transitive** (qua
`flutter_gemma`) thành **dependency trực tiếp**, ghim `^9.6.2`. Không thêm gói nào khác.

**`AndroidManifest.xml`** — thêm `FOREGROUND_SERVICE_DATA_SYNC`. Gói khai service của nó với
`android:foregroundServiceType="dataSync"`, và từ Android 14 (API 34) mỗi loại foreground
service đòi quyền riêng; dự án `targetSdk 36` nên **bắt buộc**. `FOREGROUND_SERVICE`,
`POST_NOTIFICATIONS` và `WAKE_LOCK` đã có sẵn.

⚠️ Thiếu quyền ấy thì **`flutter test`, `flutter analyze` và `flutter build apk` đều xanh** —
lỗi chỉ hiện khi lượt tải thật cố lên foreground trên máy Android 14+. Cùng vùng mù đã cho
lỗi *"APK release thiếu `INTERNET`"* ở Task 9, và cách chặn cũng giống: **một ca test đọc
thẳng tệp manifest**.

## 8. Bốn chỗ hỏng im lặng — mỗi chỗ một ca test

| # | Hỏng | Vì sao im lặng | Ca canh |
|---|---|---|---|
| 1 | **Tệp dở đọc thành "đã có mô hình"** | `existsSync()` đúng với cả tệp 650 MB lẫn tệp 2,41 GB; triệu chứng là `getActiveModel` ném *"Model may be invalid"* ở một chỗ chẳng liên quan gì tới việc tải | `daCo()` trả `false` cho tệp thiếu **một** byte, `true` cho tệp đúng `kCoTepByte` |
| 2 | **Lượt tải mồ côi** — app chết, tải vẫn chạy, mở lại thì màn hiện "Chưa tải mô hình" và nút Tải lại **đẻ lượt thứ hai** ghi đè cùng tệp | không lỗi, không log; chỉ là tệp hỏng và 2,41 GB data trôi đi hai lần | `khoiPhuc()` với bản giả trả `dangChay` → màn phải hiện tiến độ, và bấm Tải **không** gọi `batDau` lần nữa |
| 3 | **`choMang` gộp vào `dangTai`** | `requiresWiFi` khiến lượt đứng im **không báo lỗi**; màn hiện 0% mãi mãi | trạng thái `choMang` phải sinh ra **câu chữ khác** `dangTai`, có ca so hai chuỗi |
| 4 | **Ba nơi giữ `tamDung` lệch nhau** | bấm Tạm dừng trên **thông báo** (ngoài app) thì màn trong app không biết, và ngược lại | stream của `NguonTaiNen` là **nguồn sự thật duy nhất**; màn không tự đặt trạng thái sau khi bấm, chỉ chờ tin |

## 9. Cố ý KHÔNG làm

- **Không checksum.** Quyết định 3. Kiểm kích thước bắt được ca thật (tải dở); checksum bắt
  thêm ca *"đủ độ dài nhưng hỏng ruột"*, đổi lại đọc trọn 2,41 GB mỗi lần mở màn.
- **Không tải nhiều mô hình song song.** Dự án có đúng **một** mô hình (E2B cho mọi máy, P1
  chốt 2026-09-20), nên hàng đợi nhiều lượt là hạ tầng cho một thứ không tồn tại.
- **Không đụng `SlmRuntime`, khối Nhận xét, schema, payload đồng bộ.** Lát này chỉ đổi *cách
  tệp về máy*, không đổi thứ gì xảy ra sau khi nó đã về.
- **Không làm tải nền trên iOS/web.** Dự án chỉ chạy Android; `.litertlm` cũng chỉ arm64.

## 10. Nghiệm thu — và vì sao bộ test không đủ

`flutter test` **không** chạm được: foreground service, thông báo hệ thống, việc app bị giết,
và ràng buộc Wi-Fi. Cả bốn đều là vùng mù. Nên phải đo trên **máy thật**, bản `--release`:

1. Bắt đầu tải → **thoát hẳn app** (vuốt khỏi recents) → thông báo vẫn chạy, tiến độ vẫn tăng.
2. Mở lại app → màn Cài đặt AI hiện **đúng tiến độ đang chạy**, không hiện "Chưa tải".
3. Bấm **Tạm dừng trên thông báo** → mở app → màn hiện `tamDung` (bẫy 4).
4. **Tắt Wi-Fi giữa lượt** → lượt chuyển `choMang`, bật lại → tự tiếp, **không mất phần đã tải**.
5. Huỷ giữa lượt → tệp dở bị xoá, `daCo()` false.
6. Tải xong → `daCo()` true, mô hình nạp được, hỏi đáp trả lời.

⚠️ Đo phần "resume không mất dữ liệu" bằng **kích thước tệp trước và sau khi ngắt**, đừng tin
con số phần trăm trên màn hình: phần trăm là thứ lát này tính ra, nên dùng nó để nghiệm thu
chính nó là một vòng lặp kín.

## 11. Rủi ro đã biết

- **Tốc độ 97 KB/s không đổi.** Lát này làm việc tải *chịu được gián đoạn*, **không** làm nó
  nhanh hơn. Trên mạng ấy người dùng vẫn chờ nhiều giờ — chỉ khác là họ không phải ngồi nhìn.
- **`background_downloader` là mã native** mà dự án chưa từng dùng trực tiếp. Rủi ro lớn nhất
  không nằm ở API Dart mà ở hành vi khi app bị giết — đúng thứ chỉ máy thật trả lời được.
