# ĐẶC TẢ KỸ THUẬT: TÍNH NĂNG TỪ KHÓA AI NHẬN DIỆN DANH MỤC (CATEGORY KEYWORDS)

> **Trạng thái cập nhật 2026-08-22:** Phần mô tả `Categories.keywords` và các
> payload đồng bộ trong tài liệu cũ này không còn phản ánh Client-app hiện tại.
> Client dùng bảng local `category_keywords` với khóa
> `(account_id, category_id, normalized_keyword)`; nhóm danh mục và từ khóa vẫn
> local-only. Backend cần dùng
> [`CATEGORY_MANAGEMENT_BACKEND_HANDOFF.md`](CATEGORY_MANAGEMENT_BACKEND_HANDOFF.md)
> làm hợp đồng triển khai/sync mới, không thêm trường `keywords` vào payload
> category hiện hữu chỉ dựa trên tài liệu này.

> **Tài liệu tham chiếu thiết kế & hướng dẫn mở rộng cho Client-app và Backend về sau.**  
> **Phiên bản:** 1.0  
> **Ngày cập nhật:** 12/08/2026  

---

## 1. MỤC ĐÍCH & ỨNG DỤNG

Tính năng **Từ khóa nhận diện AI (`keywords`)** nhằm nâng cao trải nghiệm người dùng trong việc:
* **Tự động nhận diện danh mục khi Quét Hóa Đơn (OCR):** Khi ảnh hóa đơn được quét, hệ thống dựa trên văn bản trích xuất để tự động khớp với các từ khóa nhận diện của từng danh mục.
* **Tự động gợi ý khi Nhập Liệu Nhanh:** Khi người dùng nhập mô tả giao dịch (ví dụ: *"Trả tiền phở Thìn 50k"*), hệ thống tự động gán danh mục "Ăn uống".
* **Đồng bộ tùy biến cá nhân:** Giúp từ khóa do người dùng tự định nghĩa được sao lưu và lưu trữ nhất quán trên mọi thiết bị.

---

## 2. ĐẶC TẢ CSDL SQLITE LOCAL (CLIENT-APP)

### 2.1 Cập nhật Bảng `Categories` (`categories_table.dart`)

Bổ sung trường `keywords` vào cấu trúc bảng Drift SQLite:

```dart
class Categories extends Table {
  TextColumn get id => text()();
  IntColumn  get idaccount => integer()();
  TextColumn get name => text()();
  TextColumn get classify => text()(); // 'chi' | 'thu' | 'vay_no'
  TextColumn get icon => text().withDefault(const Constant('category'))();
  TextColumn get colour => text().withDefault(const Constant('#10B981'))();
  
  // 🆕 Trường từ khóa AI nhận diện
  TextColumn get keywords => text().nullable()(); 
  // Định dạng lưu trữ: Chuỗi các từ khóa phân cách bởi dấu phẩy, ví dụ: "phở, cafe, highland, grabfood"

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

---

## 3. HƯỚNG DẪN BỔ SUNG Ở BACKEND (POSTGRESQL & PRISMA)

### 3.1 Cập nhật Prisma Schema (`src/Backend/prisma/schema.prisma`)

Bổ sung trường `keywords` vào model `category`:

```prisma
model category {
  uuid         String         @id @db.VarChar(36)
  idcategory   Int            @unique @default(autoincrement())
  namecategory String         @db.VarChar(100)
  classify     String         @db.VarChar(10)
  
  // 🆕 Thêm cột keywords dạng Text (cho phép Null)
  keywords     String?        @db.Text
  
  is_default   Boolean?       @default(false)
  created_by   Int
  created_at   DateTime?      @default(now()) @db.Timestamp(6)
  updated_at   DateTime?      @default(now()) @db.Timestamp(6)
  account      account        @relation(fields: [created_by], references: [idaccount], onDelete: Cascade, onUpdate: NoAction, map: "fk_category_account")
  transaction  transaction[]
  budget       budget[]

  @@index([uuid], map: "idx_category_uuid")
}
```

### 3.2 Lệnh Migration Database (Backend)
```bash
npx prisma migrate dev --name add_category_keywords
```

### 3.3 Cập nhật Sync Repository (`src/Backend/modules/sync/sync.repository.js`)

Cập nhật các hàm xử lý dữ liệu `category`:

```javascript
// 1. Hàm upsertCategory
async upsertCategory(data) {
  const existing = await prisma.category.findUnique({ where: { uuid: data.id } });
  if (!existing) {
    return prisma.category.create({
      data: {
        uuid: data.id,
        namecategory: data.namecategory || data.name,
        classify: data.classify || 'chi',
        keywords: data.keywords || null, // 🆕 Thêm keywords
        is_default: data.is_default ?? false,
        created_by: data.idaccount,
      },
    });
  }
  
  if (existing.is_default && existing.created_by !== data.idaccount) {
    throw new Error('Cannot modify system default category');
  }
  
  if (new Date(data.updated_at) > new Date(existing.updated_at)) {
    return prisma.category.update({
      where: { uuid: data.id },
      data: {
        namecategory: data.namecategory || data.name,
        classify: data.classify,
        keywords: data.keywords, // 🆕 Cập nhật keywords
        is_default: data.is_default,
      },
    });
  }
  return null;
},

// 2. Hàm getCategoriesByAccount
async getCategoriesByAccount(idaccount, since) {
  return prisma.category.findMany({
    where: {
      OR: [
        { is_default: true },
        { created_by: idaccount },
      ],
      updated_at: since ? { gt: new Date(since) } : undefined,
    },
    select: {
      uuid: true,
      namecategory: true,
      classify: true,
      keywords: true, // 🆕 Trả về keywords
      is_default: true,
      created_by: true,
      updated_at: true,
    },
  });
}
```

---

## 4. QUY TRÌNH ĐỒNG BỘ 2 CHIỀU (SYNC ENGINE)

### 4.1 Payload Push từ Client-app lên Backend
```json
{
  "localId": "cat_1723456789000",
  "entity": "category",
  "operation": "update",
  "payload": {
    "id": "e3f812ab-4567-8901-abcd-ef1234567890",
    "namecategory": "Ăn uống",
    "classify": "chi",
    "keywords": "phở, cafe, highland, grabfood, shopeefood",
    "is_default": false,
    "idaccount": 2,
    "updated_at": "2026-08-12T09:50:00.000Z"
  }
}
```

### 4.2 Payload Pull từ Backend về Client-app
```json
{
  "uuid": "e3f812ab-4567-8901-abcd-ef1234567890",
  "namecategory": "Ăn uống",
  "classify": "chi",
  "keywords": "phở, cafe, highland, grabfood, shopeefood",
  "is_default": false,
  "created_by": 2,
  "updated_at": "2026-08-12T09:50:00.000Z"
}
```

---

## 5. THUẬT TOÁN PHÂN LOẠI DANH MỤC TỰ ĐỘNG KHHI QUÉT HÓA ĐƠN

```dart
/// Hàm gợi ý danh mục dựa trên từ khóa hóa đơn
Category? detectCategoryFromReceiptText({
  required String rawText,
  required List<Category> allCategories,
}) {
  final normalizedText = rawText.toLowerCase();
  Category? bestMatch;
  int maxHits = 0;

  for (final category in allCategories) {
    if (category.keywords == null || category.keywords!.isEmpty) continue;
    
    final keywordList = category.keywords!
        .split(',')
        .map((k) => k.trim().toLowerCase())
        .where((k) => k.isNotEmpty);

    int currentHits = 0;
    for (final kw in keywordList) {
      if (normalizedText.contains(kw)) {
        currentHits++;
      }
    }

    if (currentHits > maxHits) {
      maxHits = currentHits;
      bestMatch = category;
    }
  }

  return bestMatch;
}
```

---

## 6. TỔNG KẾT

Tài liệu này cung cấp đầy đủ thông số kỹ thuật, cấu trúc CSDL và mã nguồn mẫu để cả đội ngũ **Client-app** lẫn **Backend** có thể dễ dàng mở rộng và triển khai tính năng Từ khóa AI nhận diện danh mục bất kỳ lúc nào mà không gây phá vỡ kiến trúc hiện tại.
