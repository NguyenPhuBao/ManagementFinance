// lib/features/ai_edge/domain/nap_da_phuong_thuc.dart
/// Luật nạp mô hình theo thứ CẦN (C4 §4.3 — sửa luật `docAnh` của A5). Hàm thuần; `SlmRuntimeThat` áp nó.
///
/// A5 đo OnePlus 13R GPU: lần ĐÓNG mô hình thứ hai trong một tiến trình sập native. Nên bản đa phương thức nạp CẢ cờ ảnh
/// lẫn âm thanh và được GIỮ cho mọi đường sau (chữ dùng chung). ⚠️ RAM bản hai cờ chưa đo (ảnh riêng 2,93 GB, âm riêng
/// 2,53 GB — Realme CPU) — phần kiểm thử trên máy.
library;

enum CanMoHinh { chu, anh, am }

typedef QuyetDinhNap = ({bool dong, bool nap, bool anh, bool am});

QuyetDinhNap quyetDinhNap({required bool coMoHinh, required bool coAnh, required bool coAm, required CanMoHinh can}) {
  if (can == CanMoHinh.chu) {
    return coMoHinh ? (dong: false, nap: false, anh: coAnh, am: coAm) : (dong: false, nap: true, anh: false, am: false);
  }
  if (coMoHinh && coAnh && coAm) return (dong: false, nap: false, anh: true, am: true);
  return (dong: coMoHinh, nap: true, anh: true, am: true);
}
