# Đồng bộ PostgreSQL theo New_Database

## Mục tiêu

Đưa PostgreSQL, Prisma schema và bộ chuyển đổi sync của client về cùng một chuẩn với `New_Database.md`, trong đó phân loại danh mục chính thức là `Thu`, `Chi`, `Vay/nợ`.

## Phạm vi

- Migration tiến tới: chuẩn hóa dữ liệu hợp lệ trước khi thêm/sửa ràng buộc.
- Prisma mô tả đúng default, khóa ngoại và uniqueness mà Prisma hỗ trợ biểu diễn.
- Client chỉ chuyển đổi giá trị phân loại ở biên sync để SQLite cũ vẫn hoạt động.
- Không xóa vật lý dữ liệu người dùng.

## Quyết định

- `Vay/nợ` là giá trị duy nhất được backend chấp nhận; mọi `Vay/no` được đổi một lần trong migration.
- Ràng buộc `Day` được bổ sung cho các chu kỳ Budget/Bill/Goal.
- `Transaction.Provider` dùng chính xác chuỗi trong tài liệu: `Manual`, `BankSync`, `SMS`, `ORC`, `Bill`.
- Ràng buộc mới chỉ được thêm sau truy vấn preflight xác nhận dữ liệu có thể chuẩn hóa an toàn.

## Kiểm chứng

- `prisma migrate deploy`, `prisma validate`, `prisma migrate status` thành công.
- Truy vấn PostgreSQL xác nhận mọi CHECK/FK/index yêu cầu tồn tại và không có dữ liệu vi phạm.
- Unit test cho mapper phân loại xác nhận cả push và pull.
