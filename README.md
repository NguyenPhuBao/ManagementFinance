# FlowMoney — Ứng dụng quản lý tài chính cá nhân

Đồ án tốt nghiệp. Ứng dụng di động ghi chép thu chi, ví, ngân sách, hoá đơn và
mục tiêu tiết kiệm, có phân loại giao dịch bằng AI và đối soát với giao dịch
ngân hàng.

Kiến trúc **offline-first**: mọi thao tác ghi vào SQLite trên máy trước và hiện
lên màn hình ngay; một bộ đồng bộ nền đẩy/kéo hai chiều với server sau. Người
dùng mất mạng vẫn dùng được đầy đủ.

---

## Thành phần

| Thư mục | Là gì | Công nghệ |
|---|---|---|
| [`src/Client-app`](src/Client-app) | Ứng dụng di động | Flutter · Drift/SQLite · BLoC · GoRouter |
| [`src/Backend`](src/Backend) | API máy chủ | Node.js · **Express 4** · Prisma · PostgreSQL · Redis/BullMQ · Socket.io |
| [`src/Admin-web`](src/Admin-web) | Trang quản trị | — |
| [`docs/`](docs) | Tài liệu thiết kế và bàn giao | Markdown |

---

## Chạy thử

```bash
# Máy chủ — http://localhost:3000
cd src/Backend && npm install && npm run dev

# Ứng dụng
cd src/Client-app && flutter pub get
flutter run -d chrome --web-port 9090      # bản web, nhanh để thử
flutter build apk --debug                  # bản Android, BẮT BUỘC khi đụng giao diện
```

⚠️ Giao diện phải kiểm trên **máy ảo Android ở 411dp**. Bộ test và bản web chạy
ở 1280px nên **không** bắt được lỗi tràn bố cục — đã vấp nhiều lần, chi tiết ở
mục "Ghi chú về kiểm thử" trong [`CLAUDE.md`](CLAUDE.md).

---

## Kiểm thử

```bash
cd src/Client-app
flutter test        # mức nền: 1587/1587 pass, ~75 giây (đo 2026-09-08)
flutter analyze     # mức nền: 25 issue, KHÔNG có error
```

Bộ test là lưới an toàn chính của dự án: phần lớn lỗi trong quá khứ hỏng **âm
thầm** — không exception, không log. Nhiều assertion ghi rõ trong `reason:` nó
đang canh chừng lỗi nào.

⚠️ `.gitignore` có dòng `test/`, nên **tệp test mới bị git bỏ qua không báo gì**.
Luôn `git add -f` từng đường dẫn.

---

## Tài liệu

Điểm vào là [`CLAUDE.md`](CLAUDE.md) — nó nói *đọc gì trước khi làm việc gì*,
kèm các quy tắc mà vi phạm sẽ hỏng âm thầm. Sau đó:

| Cần gì | Mở |
|---|---|
| Bức tranh toàn cục, trạng thái hiện tại | [`docs/PROJECT_CONTEXT.md`](docs/PROJECT_CONTEXT.md) — mục 14 |
| Việc còn dang dở, kèm **lý do hoãn** | [`docs/CLIENT_APP_KNOWN_GAPS.md`](docs/CLIENT_APP_KNOWN_GAPS.md) |
| Việc phía backend còn phải làm | [`docs/superpowers/backend/CAN-LAM/README.md`](docs/superpowers/backend/CAN-LAM/README.md) — cửa vào duy nhất |
| Vì sao lược đồ có hình dạng hôm nay | [`docs/superpowers/backend/DA-XONG/`](docs/superpowers/backend/DA-XONG) |
| Mục tiêu tiết kiệm · Thông báo · Danh mục · Phân tích | [`GOAL_FEATURE.md`](docs/GOAL_FEATURE.md) · [`NOTIFICATION_FEATURE.md`](docs/NOTIFICATION_FEATURE.md) · [`CATEGORY_RATIONALE.md`](docs/CATEGORY_RATIONALE.md) · [`ANALYTICS_FEATURE.md`](docs/ANALYTICS_FEATURE.md) |
| Hợp đồng tên trường giữa hai phía | `src/Client-app/test/core/sync/sync_payload_contract_test.dart` — đọc **như tài liệu**, đây là nơi duy nhất ghi nó |

Các tài liệu ấy trả lời câu **"vì sao"**, không phải câu "cái gì": cái gì thì đọc
mã và test là ra, còn vì sao thì mất theo phiên làm việc.

> ⚠️ **Một số thư mục con của `docs/` bị `.gitignore` chặn** (`docs/bill/`,
> `docs/category/`, `docs/superpowers/plans/`, `docs/superpowers/sync/`…) nên chỉ
> có trên máy đã dựng. Tạo tài liệu ở chỗ mới thì kiểm trước bằng
> `git check-ignore -v <đường dẫn>`, nếu không nó biến mất không báo gì.

> ⚠️ **Tài liệu là ảnh chụp, không phải nguồn sự thật.** Luôn đối chiếu với mã
> nguồn trước khi kết luận — đã có nhiều phiên kết luận sai vì tin tài liệu hoặc
> trí nhớ thay vì mở tệp ra đọc.
