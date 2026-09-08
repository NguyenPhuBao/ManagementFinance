# FlowMoney — Client app (Flutter)

Ứng dụng di động của FlowMoney. Kiến trúc **offline-first**: ghi vào SQLite
(Drift) trước rồi đồng bộ nền hai chiều với backend sau.

Flutter · Drift/SQLite · BLoC (`flutter_bloc`) · GoRouter · GetIt.

> Tài liệu dự án nằm ở **[README gốc của repo](../../README.md)** và
> **[`CLAUDE.md`](../../CLAUDE.md)**. Đọc `CLAUDE.md` trước khi sửa gì — nó ghi
> các quy tắc mà vi phạm sẽ hỏng **âm thầm** (tên trường đồng bộ, `idaccount`,
> `insertAllOnConflictUpdate`, xoá mềm…).

## Lệnh hay dùng

```bash
flutter pub get
flutter run -d chrome --web-port 9090   # bản web, nhanh để thử
flutter build apk --debug               # bản Android

flutter test                            # mức nền: 1538/1538 pass, ~75 giây
flutter analyze                         # mức nền: 25 issue, KHÔNG có error

# sau khi sửa bảng/DAO của Drift (schema hiện tại: v19)
dart run build_runner build --delete-conflicting-outputs
```

## Ba điều dễ vấp nhất

1. **`.gitignore` có dòng `test/`** → tệp test mới bị git bỏ qua không báo gì.
   Luôn `git add -f` **từng đường dẫn** (thêm cả thư mục sẽ thất bại).
2. **Đụng vào giao diện hoặc điều hướng thì phải chạy máy ảo Android** ở 411dp.
   Bộ test và bản web chạy ở 1280px nên không bắt được lỗi tràn bố cục.
3. **Đừng ngắt `flutter test` giữa chừng, và đừng chạy hai lần cùng lúc.**
   `flutter_tester.exe` mồ côi giữ `build/native_assets/windows/sqlite3.dll`,
   mọi lần chạy sau nổ `PathExistsException`.

Chi tiết đầy đủ của cả ba: mục "Ghi chú vận hành" và "Ghi chú về kiểm thử" trong
[`CLAUDE.md`](../../CLAUDE.md).
