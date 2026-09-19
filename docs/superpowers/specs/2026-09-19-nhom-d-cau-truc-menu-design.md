# Nhóm D — cấu trúc menu và điều hướng (lối B)

**Ngày:** 2026-09-19 · **Trạng thái:** đã duyệt, chưa thi công
**Nguồn:** mục D của `docs/superpowers/plans/2026-09-19-ux-ui-danh-sach-viec.md`

---

## 1. Vấn đề

Lượt đánh giá UX/UI ngày 2026-09-19 đo trên máy ảo 411dp tìm ra rằng app có
**hai hệ điều hướng chồng nhau**: một drawer mở từ Trang chủ và một thanh tab ở
đáy màn. Bốn trong chín mục của drawer lặp lại đúng thứ thanh tab đã có, và tab
Cá nhân lại chứa thêm một nhóm module lặp lại drawer lần nữa. Người dùng học
được một đường rồi gặp chính đích ấy ở chỗ khác với tên khác.

Bốn chỗ cụ thể:

- **Sổ giao dịch** — thứ người dùng mở nhiều lần mỗi ngày — **không có lối vào
  cố định**; chỉ vào được qua "Xem tất cả" ở Trang chủ hoặc một nút trong màn
  Quản lý ví.
- Cùng một đích mang **hai tên**: "Phân tích" ở tab, "Thống kê" ở drawer và ở
  tiêu đề trang.
- Tab Cá nhân và trang `/settings` **cùng vẽ avatar + tên + email + nút sửa**, và
  một mục của tab chỉ là lối nhảy sang trang kia.
- Trang chủ có **năm** lối vào cùng một màn Thêm giao dịch.

## 2. Lối đã chọn

Người dùng chốt **lối B**: giữ drawer làm menu, thay vì lối A (bỏ drawer, dựng
một hệ năm mục kèm màn "Khác" mới). Lý do: bản thiết kế Stitch **đã có sẵn** màn
drawer (`6c692ef11f2d4f40aee3666449b4988d`), nên lối B bám vào thiết kế đang có
thay vì đòi vẽ một màn chưa từng tồn tại.

Nguyên tắc dẫn đường cho toàn bộ thiết kế này:

> **Thanh dưới = việc hằng ngày. Drawer = mọi thứ còn lại. Không đích nào xuất
> hiện ở cả hai chỗ.**

## 3. Thanh dưới và nhánh router

Thanh dưới thành **Trang chủ · Phân tích · [+] · Sổ giao dịch · Cá nhân**.
Bốn `StatefulShellBranch` thành `/home`, `/analytics`, `/transactions`,
`/profile`. `/budget` **rời shell** thành route gốc.

Việc kéo `/budget` ra khỏi shell là sạch: `/budget/rules` và `/budget/detail/:id`
**vốn đã là route gốc** (`app_router.dart:226` và `:235`), không phải route con
của nhánh.

### ⚠️ 3.1 Quả mìn: `push` một route trong shell từ ngoài shell

Đây là chỗ nguy hiểm nhất của cả hạng mục, và nó **không hiện ra trong
`flutter test`** — đúng loại lỗi thứ 2 của mục "Ba loại lỗi `flutter test`
KHÔNG bắt được" trong `CLAUDE.md`.

Hiện `/transactions` là route **gốc**, nên `wallet_list_page.dart:253` và `:457`
gọi `context.push('/transactions?wallet=<id>')` an toàn — màn Quản lý ví nằm
**ngoài** shell (drawer `push` nó). Biến `/transactions` thành nhánh shell thì
chính lời gọi ấy thành *push một route nằm trong shell từ một trang ngoài shell*
và app **chết màn đỏ** (`!keyReservation.contains(key)`).

**Lối xử lý đã chốt (lối 1 trong ba lối đã cân nhắc):** một route duy nhất, ba
chỗ gọi đổi cách điều hướng.

| Tệp | Hiện tại | Sau |
|---|---|---|
| `wallet_list_page.dart:253` | `push('/transactions?wallet=…')` | `go(…)` |
| `wallet_list_page.dart:457` | `push('/transactions?wallet=…')` | `go(…)` |
| `home_page.dart:478` "Xem tất cả" | `push('/transactions')` | `go(…)` |
| `home_page.dart:617` thẻ ngân sách | `go('/budget')` | `push(…)` — nay là route gốc, cần nút Back |

**Đánh đổi đã biết và chấp nhận:** từ màn Quản lý ví bấm "Xem giao dịch" rồi
Back sẽ về **Trang chủ** chứ không về màn Ví, vì luật E3 (đặt cùng ngày) cho
Back ở tab khác quay về tab đầu. Hai lối còn lại đã bị loại: lối 2 (tab dùng
đường `/ledger` riêng, giữ `/transactions` gốc cho ca lọc) giữ được hành vi Back
nhưng đẻ **hai đường tới cùng một trang phải giữ đồng bộ mãi** — đúng kiểu lỗi
`/reports` vừa sửa sáng cùng ngày; lối 3 là bỏ hẳn D1.

### ⚠️ 3.2 `nhanhThanhTab` — mảnh thứ hai, quên là hỏng theo HAI chiều

Dự án **đã có sẵn** cơ chế cho đúng cái bẫy ở 3.1: hằng `nhanhThanhTab` trong
`core/notification/notification_deeplink.dart` liệt kê các route nằm trong shell,
và `main.dart:131` đọc nó để chọn `go` hay `push`:

```dart
thuocThanhTab(route) ? _router.go(route) : _router.push(route)
```

Hằng ấy đang là `{'/home', '/analytics', '/budget', '/profile'}` và **giữ đồng
bộ tay** với `app_router.dart` (go_router không phơi cây route ra). Thiết kế này
đổi nhánh thứ ba, nên hằng phải đổi thành:

```dart
{'/home', '/analytics', '/transactions', '/profile'}
```

**Quên đổi thì hỏng ở cả hai chiều, và một chiều là màn đỏ.** Bộ luật thông báo
sinh deeplink tới **cả hai** route đang đổi vai (`notification_rules.dart:302`,
`:325` → `/budget`; `:406` → `/transactions`):

| Deeplink | Nếu quên đổi hằng | Hậu quả |
|---|---|---|
| `/transactions` (luật *khoản chi lớn*) | `thuocThanhTab` = false → `push` từ `/notifications`, một trang **ngoài** shell | **Chết màn đỏ** — đúng sự cố đã xảy ra với thông báo ngân sách |
| `/budget` (luật *ngân sách*) | `thuocThanhTab` = true → `go` tới một route nay **ngoài** shell | Thay cả stack, **thanh tab biến mất**, không còn đường quay lại |

Sửa đúng một dòng hằng ấy thì **cả hai** đường tự đúng: `/transactions` chuyển
tab bằng `go`, `/budget` mở chồng bằng `push` và có nút Back.

`notification_deeplink_test.dart` đã canh hằng này; ca test phải cập nhật cùng
lúc, và nên thêm một ca đối chiếu `nhanhThanhTab` với **chính danh sách nhánh
trong `app_router.dart`** nếu làm được — hai nơi giữ tay là chỗ trôi lệch kinh
điển của dự án này.

### 3.3 Chỉ số tab

`MainShell._getUIIndex` và `_onItemTapped` lệch chỉ số để chừa chỗ cho FAB ở vị
trí 2. **Số nhánh không đổi** (vẫn bốn) nên phép lệch giữ nguyên. Nhánh thứ ba
(chỉ số 2, hiện UI ở vị trí 3) đổi **route** từ `/budget` sang `/transactions`,
cùng với nhãn và icon.

## 4. Drawer — còn sáu mục

```
Quản lý ví           /wallets
Mục tiêu tiết kiệm   /goals
Ngân sách            /budget        ◀ rời shell về đây
Hóa đơn & Dịch vụ    /bills
Xuất báo cáo         /export-report
Trợ lý AI            /ai-chat
─────────────────────
Đăng xuất
```

Bỏ ba mục **Thống kê**, **Cá nhân**, **Cài đặt** vì cả ba đã có ở thanh dưới.

**D4 tự tan:** drawer thôi có mục "Thống kê" nên không còn hai tên cho một đích.
Tên còn lại là "Phân tích" ở tab, và tiêu đề trang `AnalyticsPage` đổi theo cho
khớp.

**D9 tự tan:** "Trợ lý AI chỉ vào được từ drawer" đúng là thiết kế mong muốn
dưới lối B — drawer *là* menu.

`kMucDrawer` vẫn là hằng công khai để test đối chiếu **từng đường với router
thật**; đây là cơ chế đã bắt được lỗi `/reports` sáng cùng ngày.

## 5. Tab Cá nhân — gộp `/settings` vào

```
        ( Đ )  Đạt                    [✎]
        tadd1632004@gmail.com

  BẢO MẬT & TÙY CHỌN
    Thông tin cá nhân               ›
    Đổi mật khẩu                    ›

  CÀI ĐẶT
    Cài đặt thông báo               ›      ◀ D7: đổi tên từ "Thông báo"

  VÙNG NGUY HIỂM
    Xóa tài khoản
```

Nhóm **QUẢN LÝ TÀI KHOẢN** (Hóa đơn, Mục tiêu tiết kiệm, Ví, Danh mục tùy chỉnh)
bỏ hẳn — bốn mục ấy sống ở drawer.

**Route `/settings` GIỮ NGUYÊN.** Lý do đo được (không phải phỏng đoán): bốn
route con **khai báo bên trong nó** — `/settings/change-password`,
`/settings/delete-account`, `/settings/edit-profile`
(`app_router.dart:353`–`:359`) — cộng `/settings/notifications` khai riêng ở
`:329`. Xoá `/settings` là xoá luôn ba đường con, mà `vung_nguy_hiem_card.dart`
và chính thân trang đang `push` chúng. Cả bốn nằm **ngoài** shell, nên tab Cá
nhân (trong shell) `push` chúng là an toàn — bẫy 3.1 chỉ nổ theo chiều ngược.

⚠️ Đã kiểm: **không** bộ luật thông báo nào deeplink tới `/settings`; câu "thông
báo hệ điều hành đi qua đường ấy" trong bản nháp đầu là **phỏng đoán sai**, đã
gỡ.

**D7:** "Thông báo" → **"Cài đặt thông báo"**. Tên cũ lẫn với trung tâm thông
báo mà lối vào là chuông ở Trang chủ — hai thứ khác hẳn nhau.

**D8 tự tan:** xung đột icon heo đất (`Icons.savings` = Ngân sách ở drawer,
`Icons.savings_outlined` = Mục tiêu tiết kiệm ở tab Cá nhân) biến mất cùng nhóm
module. Không còn hai nghĩa cho một glyph.

## 6. Trang chủ

Bỏ ba thứ: **slogan hai dòng**, nút hero **"Thêm giao dịch"**, và nút
**"Xem báo cáo"**. Còn lại, từ trên xuống:

```
  ☰  FlowMoney                          🔔
  ┌──────────────────────────────────┐
  │ Tổng số dư ví     [Số dư thực tế]│
  │ 13.054.000 đ                     │
  └──────────────────────────────────┘
   ⬤ Thêm thu  ⬤ Thêm chi  ○ Chuyển  ○ Quét
  [Thu nhập] [Chi tiêu] [Thu net]
  GIAO DỊCH GẦN ĐÂY            Xem tất cả
  …
```

Lối vào màn Thêm giao dịch còn **bốn**: ba nút tròn (từ C4 chúng đã đặt sẵn
chiều Chi/Thu/Chuyển nên nhanh hơn hero) cộng FAB. Báo cáo vẫn vào được từ
drawer ("Xuất báo cáo") và từ tab Phân tích.

## 7. Stitch

Ba màn đã gửi ngày 2026-09-19, trước khi chạm mã:

| Màn | ID | Trạng thái |
|---|---|---|
| Drawer 6 mục | `250229e651a74a83a85c6e9e7091f321` | ✅ tạo xong |
| Cá nhân - gộp Cài đặt | `580ee88c6e81472297b523618137ba6a` | ✅ tạo xong |
| Trang chủ - thanh dưới 5 mục | `93501c8554934d15a773bd456a0160ba` | ✅ **hiện ra sau** lượt gọi timeout |

✅ **Xác nhận lại lần nữa ngay trong lượt này:** lượt gọi màn Trang chủ trả về
`timeout`, `list_screens` ngay sau đó **không thấy** nó (và cũng chưa thấy cả
hai màn mà API đã trả về ID đầy đủ), rồi chừng một tiếng sau **cả ba đều có**.
Tài liệu công cụ dặn *"DO NOT RETRY"* và điều đó đúng — gọi lại là dự án lãnh
thêm một màn trùng. Kiểm lại bằng `list_screens` sau, và hỏi người dùng nhìn
giúp trên canvas nếu còn nghi ngờ; đó là phép đo duy nhất đáng tin.

⚠️ Hai màn đã tạo trả về `deviceType: DESKTOP` dù lượt gọi truyền `MOBILE`. Đây
là nếp đã gặp nhiều lần; thân trang vẫn dựng trong khung một cột cỡ điện thoại
nên bố cục dùng được.

## 8. Kiểm chứng

**Test phải dựng `GoRouter` thật**, không `MaterialApp` trần — bẫy shell chỉ nổ
khi có cây route thật, và đây đúng là bài học `main_shell_back_test.dart` rút ra
sáng cùng ngày khi `PopScope` xanh trong test mà máy ảo vẫn thoát app.

Ca cần có:

1. Bốn tab chuyển được qua lại, mỗi tab dựng đúng trang của nó.
2. **Từ màn Quản lý ví bấm "Xem giao dịch" không làm app chết màn đỏ** — ca này
   là lý do chính của cả mục 3.1; phải đi qua router thật và đòi thấy nội dung
   sổ giao dịch, không chỉ `takeException() isNull`.
3. "Xem tất cả" ở Trang chủ chuyển sang tab Sổ giao dịch.
4. Thẻ ngân sách ở Trang chủ mở `/budget` **có nút Back**.
5. Mọi đường trong `kMucDrawer` khớp một route có thật (mở rộng ca đang có).
6. ⚠️ **`nhanhThanhTab` khớp đúng danh sách nhánh của `app_router.dart`**, cộng
   một ca dựng router thật rồi chạm vào thông báo *khoản chi lớn* (deeplink
   `/transactions`) từ trung tâm thông báo mà không chết màn đỏ.
7. Drawer **không** chứa đường nào trùng thanh dưới — canh bằng chính danh sách
   nhãn của thanh dưới, để thêm tab mới về sau là ca này đỏ.
8. Tab Cá nhân có đủ bốn khối và **không** còn nhóm QUẢN LÝ TÀI KHOẢN.
9. Trang chủ không còn slogan, nút hero, nút "Xem báo cáo".

**Nghiệm thu máy ảo bắt buộc** cho cả hạng mục: đây là vùng mà `flutter test`
mù ba lần (tràn bố cục ở 411dp, điều hướng shell, thứ tự bất đồng bộ). Riêng
bề rộng nhãn thanh dưới phải nhìn tận mắt — năm nhãn trên 411dp trừ 72dp cho
FAB là chỗ dễ cắt chữ.

## 9. Ngoài phạm vi

Giữ nguyên, không đụng trong hạng mục này: **A5** nút Quét, **A6** thẻ Insight
AI, **A11** hai nút Google/Apple ở màn Đăng nhập, **E1** skeleton Phân tích,
**E2** mục lục trang Phân tích, **E4** thay `SnackBar` bằng toast, **E6** nhắc
ví âm hằng ngày, **G2** cỡ chữ hệ thống lớn.

**Không đổi schema, không thêm trường đồng bộ.**
