/// Khoản **"Số dư ban đầu"** — điểm neo để số dư ví suy được từ sổ giao dịch.
///
/// ## Vì sao cần một khoản như thế
///
/// Số dư ví nay là **cache của một công thức**: tổng mọi giao dịch còn sống của
/// ví. Nhưng người dùng nhập số dư khi **tạo** ví, và con số ấy không có giao
/// dịch nào tương ứng — thiếu nó thì công thức trả về một số sai hẳn.
///
/// Chọn "neo là một giao dịch" thay vì "neo là một cột" vì giao dịch **đã đồng
/// bộ sẵn**: ví kéo về từ máy khác nhận luôn cả neo, không cần thêm trường nào
/// vào hợp đồng đồng bộ, không cần xin backend cột mới.
///
/// Thiết kế: `docs/superpowers/specs/2026-09-13-so-du-vi-suy-tu-so-giao-dich-design.md`.
library;

import 'package:uuid/uuid.dart';

/// Tiền tố của mọi ghi chú khoản mở sổ. Nơi ghi và nơi đọc dùng chung hằng số
/// này, nên chúng không lệch nhau được.
const String tienToMoSo = 'Số dư ban đầu';

/// Namespace UUID dùng cho [idKhoanMoSo].
///
/// Một hằng số tuỳ ý nhưng **bất biến**: đổi nó là mọi ví sinh thêm một neo thứ
/// hai mang id khác, tức số dư đột ngột nhân đôi phần neo.
///
/// ⚠️ Phải là UUID **hợp lệ** — gói `uuid` ném `FormatException` khi phân tích
/// namespace, và một GUID kiểu Microsoft cũ (bit biến thể sai) trượt qua mắt
/// người nhưng không qua được nó.
const String _namespaceMoSo = '3f2a7c18-9b4e-4d61-8a2f-1c5e7d90b4a6';

/// Ghi chú của khoản mở sổ.
String ghiChuMoSo() => tienToMoSo;

/// Id **tất định** của khoản mở sổ thuộc ví [walletId].
///
/// ⚠️ Tất định là **chốt chặn duy nhất** giữ cho hai máy cùng vá neo mà không
/// đẻ ra hai khoản mở sổ: cùng id thì `/sync/push` ghép làm một hàng thay vì
/// hai. Dùng UUID **v5** (băm từ namespace + tên) chứ không phải `v4` ngẫu
/// nhiên, và kết quả vẫn là UUID hợp lệ cho cột `VarChar(36)`.
String idKhoanMoSo(String walletId) => const Uuid().v5(_namespaceMoSo, walletId);

/// "Hàng này có phải khoản mở sổ không" — phép hỏi **duy nhất**.
///
/// Đòi đủ **cả ba**, cùng khuôn và cùng lý do với `laKhoanDieuChinh`: là
/// `thu`/`chi` (khoản chuyển đã có luật loại riêng, nhận nó ở đây là hai luật
/// cùng nói về một hàng), **không** danh mục, và ghi chú mở đầu bằng
/// [tienToMoSo].
///
/// Riêng chân ghi chú thì **không đủ**: `transaction.Note` sửa được, nên một
/// dấu hiệu chỉ nằm ở đó có thể mất — mà mất thì khoản mở sổ lặng lẽ trở thành
/// thu nhập thật trong báo cáo, tức sai một **con số** chứ không chỉ một nhãn.
/// Chân thứ hai là cấu trúc: giao diện thêm giao dịch **bắt buộc chọn danh mục**
/// cho mọi khoản `thu`/`chi`, nên một khoản thu/chi không danh mục là thứ giao
/// diện không tạo ra được.
bool laKhoanMoSo({
  required String loai,
  required String? categoryId,
  required String? ghiChu,
}) {
  if (loai != 'thu' && loai != 'chi') return false;
  if (categoryId != null) return false;
  return (ghiChu ?? '').trimLeft().startsWith(tienToMoSo);
}
