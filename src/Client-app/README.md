# FlowMoney — Client app (Flutter)

Ứng dụng di động của FlowMoney. Kiến trúc **offline-first**: ghi vào SQLite
(Drift) trước rồi đồng bộ nền hai chiều với backend sau.

Flutter · Drift/SQLite · BLoC (`flutter_bloc`) · GoRouter · GetIt.

## Kiến trúc
Feature-first ba tầng `data · domain · presentation`, offline-first với SQLite là nguồn sự thật cục bộ; luật nghiệp vụ là hàm
thuần có một định nghĩa, được 28 test quét mã nguồn canh (25 tệp mang số 1–24, số 14 cấp hai lần, cộng 3 tệp không số);
mọi ranh giới nền tảng là cổng có bản giả. Chi tiết, cây thư mục và luật vị trí tệp:
[`docs/KIEN_TRUC_CLIENT_APP.md`](../../docs/KIEN_TRUC_CLIENT_APP.md).

> Tài liệu dự án nằm ở **[README gốc của repo](../../README.md)** và
> **[`CLAUDE.md`](../../CLAUDE.md)**. Đọc `CLAUDE.md` trước khi sửa gì — nó ghi
> các quy tắc mà vi phạm sẽ hỏng **âm thầm** (tên trường đồng bộ, `idaccount`,
> `insertAllOnConflictUpdate`, xoá mềm…).

## Lệnh hay dùng

```bash
flutter pub get
flutter run -d chrome --web-port 9090   # bản web, nhanh để thử
flutter build apk --debug               # bản Android

flutter test                            # mức nền: 6621/6621 pass (+9 skip), ~4–6 phút (đo 2026-10-10)
flutter analyze                         # mức nền: 20 issue, KHÔNG có error

# sau khi sửa bảng/DAO của Drift (schema hiện tại: v30)
dart run build_runner build --delete-conflicting-outputs
```

## Ba điều dễ vấp nhất

1. **`test/` đã bỏ khỏi `.gitignore` từ 2026-09-21** → tệp test mới hiện trong `git status` như mọi tệp khác (chỉ `src/Backend/Test/` còn bị chặn).
2. **Đụng vào giao diện hoặc điều hướng thì phải chạy máy ảo Android** ở 411dp.
   Bộ test và bản web chạy ở 1280px nên không bắt được lỗi tràn bố cục.
3. **Đừng ngắt `flutter test` giữa chừng, và đừng chạy hai lần cùng lúc.**
   `flutter_tester.exe` mồ côi giữ `build/native_assets/windows/sqlite3.dll`,
   mọi lần chạy sau nổ `PathExistsException`.

Chi tiết đầy đủ của cả ba: mục "Ghi chú vận hành" và "Ghi chú về kiểm thử" trong
[`CLAUDE.md`](../../CLAUDE.md).
