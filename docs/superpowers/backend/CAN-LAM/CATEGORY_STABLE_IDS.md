# ID danh mục mặc định đang sinh ngẫu nhiên — hãy đóng băng bộ hiện có

**Người nhận:** đội Backend
**Trạng thái:** cần backend sửa `prisma/seed.js`. Phía Client-app sẽ bám theo sau.
**Mức độ:** không gây lỗi lúc hệ thống chạy bình thường, nhưng **reset CSDL một lần là mọi máy client mất ánh xạ danh mục**, và nó là nguyên nhân gốc của bốn lỗi đã ghi trong `PROJECT_CONTEXT.md`.
**Ngày khảo sát:** 2026-09-03.

---

## 1. Vấn đề

`prisma/seed.js` tạo danh mục mặc định bằng:

```js
idcategory: crypto.randomUUID(),
```

Nghĩa là **ID không ổn định**: seed lại là ra một bộ UUID hoàn toàn khác. Client thì seed cùng bộ danh mục đó với id dạng slug (`cat_food`, `cat_transport`, …).

Hai phía không có một khoá chung nào, nên client buộc phải **nối bằng TÊN**:

```dart
// sync_engine.dart — _resolveCategoryId
final categoriesWithSameName = await _db.categoryDao.getByName(localCategory.name);
```

## 2. Cái giá của việc nối bằng tên

Toàn bộ cơ chế phức tạp và nhiều lỗi nhất của client tồn tại **chỉ vì** lý do này:

| Cơ chế | Sinh ra để làm gì |
|---|---|
| `_resolveCategoryId` dò theo tên | tìm UUID backend tương ứng với `cat_food` |
| `removeDuplicateLocalSeedCategories()` | dọn hàng seed sau khi bản UUID về |
| `repairPendingTransactionsCategoryId()` | sửa giao dịch còn trỏ vào `cat_food` |
| Ràng buộc thứ tự "repair TRƯỚC, dedup SAU" | vì đảo lại thì giao dịch kẹt vĩnh viễn |

Và bốn lỗi trong mục 11 của `PROJECT_CONTEXT.md` — **11.3, 11.4, 11.5, 11.6** — đều là biến thể của cùng một vấn đề đó.

Thêm hai hệ quả cụ thể:

- **Reset CSDL = mất ánh xạ toàn hệ thống.** Toàn bộ UUID đổi, giao dịch trên máy người dùng trỏ vào những UUID không còn tồn tại.
- **Đổi nhãn một danh mục là phá vỡ ánh xạ.** Ngày 2026-09-03 hai phía lệch nhau 8/13 mục vì đúng chuyện này (đã xử lý ở client, nhưng bằng cách đổi tên cho khớp — tức vẫn phụ thuộc vào tên).

## 3. Đề xuất: đóng băng đúng bộ UUID đang có

**Không sinh bộ mới.** Lấy đúng 13 UUID hiện nằm trong CSDL, đưa vào mã nguồn thành hằng số. Như vậy:

- **Không cần migration dữ liệu nào phía backend** — dữ liệu hiện tại đã đúng.
- Client seed đúng những UUID đó → hai phía có khoá chung ngay.
- Máy client đã cài thì bộ máy sẵn có tự chuyển đổi: 13/13 mục nay đã khớp tên nên `_resolveCategoryId` ánh xạ được, `repairPendingTransactionsCategoryId` sửa giao dịch, `removeDuplicateLocalSeedCategories` dọn hàng seed cũ.

### Bộ 13 UUID cần đóng băng

Đo trực tiếp từ CSDL ngày 2026-09-03:

```
8e06aaf6-4608-4cb3-8770-2c2c1eae25b6  Ăn uống    Chi
08639bd7-ef8f-4c58-ae8a-7f58198ad79b  Di chuyển  Chi
5c9b4699-59ab-4ade-9f8d-312db326b5c8  Giải trí   Chi
e6d26476-a546-48a9-bf45-716ba0264547  Giáo dục   Chi
d5fead3c-4b9a-4649-bd63-1019bc2c7fef  Hóa đơn    Chi
b84b02f4-72ad-42e0-9298-860efb5889b0  Mua sắm    Chi
3d2a54d2-eb45-41b4-ad18-0f4308791dea  Nhà cửa    Chi
ed724230-14e7-4bef-8620-03c52730d32c  Y tế       Chi
af5d9ad9-04b2-4df3-9634-b44fa0c9fef0  Đầu tư     Thu
f92ee650-47d7-42c3-a9cd-75fe2e5daa84  Lương      Thu
bfc1ef8d-d9af-4f8d-80bb-a7fac310891f  Thưởng     Thu
58839f91-9eec-4af7-b542-65d2a70e3e36  Cho vay    Vay/no
df489f3d-6ddf-44c6-be3c-2402259ec9cf  Đi vay     Vay/no
```

> ⚠️ **Chạy lại truy vấn này trước khi chốt.** Nếu CSDL đã bị reset kể từ 2026-09-03 thì bộ UUID trên đã khác, và phải lấy bộ mới — hoặc chính điều đó là bằng chứng cho vấn đề mà tài liệu này mô tả.
>
> ```sql
> SELECT "Idcategory", "NameCategory", "Classify"
> FROM "category" WHERE "Is_default" = TRUE AND "Delete_at" IS NULL
> ORDER BY "Classify", "NameCategory";
> ```

## 4. Thay đổi cần làm ở `prisma/seed.js`

1. Đưa `idcategory` vào chính `DEFAULT_CATEGORIES` thành hằng số, bỏ `crypto.randomUUID()`.
2. Đổi `createMany` sang **upsert theo `idcategory`**. Hiện seed bị chặn bởi `if (existingCat === 0)` nên chạy lại là không làm gì; với ID cố định thì upsert an toàn và giúp seed trở thành thao tác lặp lại được — thêm một danh mục mặc định mới sau này chỉ việc chạy lại seed.
3. **Không** đổi tên hay xoá mục nào trong lần này. Đổi nhãn cứ đổi thoải mái **sau khi** ID đã ổn định — đó chính là điều mà việc này mở ra.

## 5. Client-app sẽ làm gì sau đó

1. Seed 13 danh mục mặc định bằng **đúng bộ UUID trên**, thay cho id dạng `cat_food`.
2. Migration đổi id hàng cũ và repoint giao dịch/ngân sách/hoá đơn — **repoint trước, xoá sau**, theo đúng bài học của lỗi 11.6.
3. Sau khi ổn định, **gỡ bỏ được** nhánh dò theo tên trong `_resolveCategoryId` và hàm `removeDuplicateLocalSeedCategories()`. Đây mới là phần lãi thật: bớt hẳn một lớp mã mà lịch sử dự án cho thấy rất dễ sinh lỗi.
4. Khoá bộ ID vào `test/core/sync/sync_payload_contract_test.dart` — nó là hợp đồng giữa hai phía y như tên trường, và lệch thì cũng **hỏng âm thầm**.

## 6. Vì sao nên làm dù bước 3 đã xong

Ngày 2026-09-03 client đã chỉnh bộ mặc định cho khớp tên backend, nên ánh xạ **hiện đang chạy đúng**. Nhưng nó vẫn dựa vào tên, tức còn nguyên các rủi ro sau:

- Ai đó sửa một nhãn cho đẹp hơn (`Hóa đơn` → `Hoá đơn & Dịch vụ`) là ánh xạ đứt, **không có test hay lỗi nào bắt được**.
- Reset CSDL vẫn phá mọi thứ.
- Bốn lớp mã vá víu ở mục 2 vẫn phải nuôi.

Với ID cố định thì tên trở lại đúng vai trò của nó — **nhãn hiển thị** — và đổi lúc nào cũng được.

## 7. Cách kiểm chứng sau khi làm

```sql
-- 1. ID phải trùng đúng bộ hằng số trong mã nguồn
SELECT "Idcategory", "NameCategory" FROM "category" WHERE "Is_default" = TRUE;

-- 2. Chạy lại seed KHÔNG được sinh thêm dòng nào, cũng không đổi ID
--    (chạy `npm run seed` lần hai rồi so lại kết quả trên)
```

Phép thử thật sự: **xoá sạch bảng `category` rồi seed lại** — bộ ID phải y hệt trước đó. Hiện tại phép thử này chắc chắn thất bại.

## 8. Một điểm lệch nhỏ phát hiện kèm

Cột `Icon` của backend lưu slug (`food`, `transport`, `bill`), còn client lưu tên icon Material (`restaurant`, `directions_car`, `receipt`). Hai bên không dùng chung bảng mã, nên icon pull về không hiển thị đúng nếu client tin vào giá trị của backend.

Client hiện tránh được nhờ `CategoryIconRegistry` và nhánh "giữ icon cũ nếu backend trả giá trị vô nghĩa", nhưng đây là một hợp đồng nữa chưa ai viết ra. Không gấp; nêu ở đây để không rơi mất.

## 9. Ghi chú

Toàn bộ khảo sát chỉ **đọc** mã nguồn backend và **truy vấn chỉ đọc** vào CSDL. **Không có dòng mã backend nào bị thay đổi, không có dữ liệu nào bị sửa.**
