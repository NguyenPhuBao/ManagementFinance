/// Trạng thái nhà của tài khoản đang đăng nhập (spec gia đình 2026-10-23 mục 3.1, 5.8; `docs/Family/01` mục 4) — model của
/// `GET /households/me` và thân mọi thao tác trả trạng thái, kiêm hình dạng kho (`NhaStore`): một bộ đọc cho cả hai.
///
/// MỘT hình dạng: LỒNG `{household: {…}, myRole, members, formerMembers}` (`docs/Family/01` mục 4; backend từ PR #172, đo lại
/// trên `8e3b4e48`, 2026-10-31), cũng là hình dạng KHO.
library;

import '../../domain/vai_nha.dart';

class NhaEntity {
  const NhaEntity({
    required this.id,
    required this.ten,
    required this.trangThai,
    required this.toiDaThanhVien,
    this.idChuNha,
    this.taoLuc,
    this.toiDaViChung,
  });

  /// Id số nguyên server cấp (`SERIAL`).
  final int id;
  final String ten;
  final TrangThaiNha trangThai;

  /// Trần server đặt theo gói của chủ lúc lập nhà — client đọc ở đây, không đọc `limits` (kế hoạch lát 1, khác spec 5.7).
  final int toiDaThanhVien;
  final int? idChuNha;
  final DateTime? taoLuc;

  /// Trần số ví chung (`01` mục 4, `02A` mục 2) — server im → `null` (chưa biết; bịa 10 là màn 2a khoá nhầm).
  final int? toiDaViChung;
}

class ThanhVienNhaEntity {
  const ThanhVienNhaEntity({required this.idaccount, required this.tenHienThi, required this.vai, this.vaoLuc});

  final int idaccount;

  /// `user.Fullname`, thiếu thì `account.Username` (đơn 50 C) — server không trả email / số điện thoại.
  final String tenHienThi;
  final VaiNha vai;
  final DateTime? vaoLuc;
}

/// Thành viên đã rời / bị mời ra (`01` mục 4 `formerMembers`): dòng hoạt động và bảng góp (phần 2a) hiện tên kèm *"(đã rời)"*
/// — khoản của họ ở lại nhà (đơn 50 C.2).
class ThanhVienCuEntity {
  const ThanhVienCuEntity({required this.idaccount, required this.tenHienThi, this.roiLuc});

  final int idaccount;
  final String tenHienThi;
  final DateTime? roiLuc;
}

class NhaCuaToi {
  const NhaCuaToi({
    required this.nha,
    required this.vai,
    required this.thanhVien,
    required this.nhanLuc,
    this.thanhVienCu = const [],
  });

  NhaCuaToi.khongCo(this.nhanLuc)
      : nha = null,
        vai = null,
        thanhVien = const [],
        thanhVienCu = const [];

  /// `null` = chưa ở nhà nào (kể cả nhà đã giải tán).
  final NhaEntity? nha;
  final VaiNha? vai;
  final List<ThanhVienNhaEntity> thanhVien;
  final List<ThanhVienCuEntity> thanhVienCu;

  /// Lúc nhận từ server — cho phép giãn 5 phút ở `resumed`.
  final DateTime nhanLuc;

  bool get coNha => nha != null;

  /// Kho ghi cùng MỘT hình dạng lồng (`01` mục 4) mà `/me` trả.
  Map<String, Object?> toJson() {
    final n = nha;
    return {
      'household': n == null
          ? null
          : {
              'id': n.id,
              'name': n.ten,
              'status': khoaServerCuaTrangThai(n.trangThai),
              'maxMembers': n.toiDaThanhVien,
              'ownerId': n.idChuNha,
              'createAt': n.taoLuc?.toUtc().toIso8601String(),
              'maxSharedWallets': n.toiDaViChung,
            },
      'myRole': vai == null ? null : khoaServerCuaVai(vai!),
      'members': [
        for (final m in thanhVien)
          {
            'idaccount': m.idaccount,
            'displayName': m.tenHienThi,
            'role': khoaServerCuaVai(m.vai),
            'joinedAt': m.vaoLuc?.toUtc().toIso8601String(),
          },
      ],
      'formerMembers': [
        for (final m in thanhVienCu)
          {
            'idaccount': m.idaccount,
            'displayName': m.tenHienThi,
            'leftAt': m.roiLuc?.toUtc().toIso8601String(),
          },
      ],
      'nhanLuc': nhanLuc.toUtc().toIso8601String(),
    };
  }

  /// Đọc lại từ kho. Rác / thiếu `nhanLuc` → `null` (hàng hỏng, kho coi như trống).
  static NhaCuaToi? tuJsonKho(Object? json) {
    if (json is! Map) return null;
    final moc = _ngay(json['nhanLuc']);
    if (moc == null) return null;
    return nhaCuaToiTuJson(json.cast<String, Object?>(), nhanLuc: moc);
  }
}

/// Nhà của tài khoản [idaccount] ĐỔI: [tu] → [den] (`null` = không nhà). Phát bởi `NhaRepository.doiNha`, nghe bởi
/// bộ điều phối `DieuPhoiDoiNha` (rời → dọn trên máy, vào → kéo lại toàn bộ).
class DoiNha {
  const DoiNha({required this.idaccount, required this.tu, required this.den});

  final int idaccount;
  final int? tu;
  final int? den;
}

/// Thân trả về của một thao tác CÓ PHẢI trạng thái nhà không (`docs/Family/04` mục 2b): #1, #2, #7, #9, #11, #15 — có (#11 rời
/// nhà trả trạng thái lồng với `household: null`: "không nhà" là một trạng thái); #8 `{targetIdaccount, newRole}`, #10 `{removed: true}`, #12
/// `{dissolved: true}`, #16 `{declined: true}` — KHÔNG. Đọc thân không phải trạng thái bằng [nhaCuaToiTuJson] ra "chưa có nhà"
/// → `DoiNha(nhà → null)` → máy chủ nhà tự xoá sạch dữ liệu nhà ngay sau khi đổi vai một người (preflight 2026-10-28 #2).
/// Repository gặp `false` thì hỏi lại `/me` thay vì áp.
bool laThanTrangThaiNha(Map<String, Object?> json) => json.containsKey('household');

/// Không bao giờ ném: trường rác rơi về mặc định của đúng trường ấy; nhà thiếu id hoặc `Dissolved` → chưa có nhà.
NhaCuaToi nhaCuaToiTuJson(Map<String, Object?> json, {required DateTime nhanLuc}) {
  final long = json['household'];
  if (long is! Map) return NhaCuaToi.khongCo(nhanLuc);
  final h = long.cast<String, Object?>();
  final id = _soNguyen(h['id']);
  final trangThai = trangThaiNhaTuServer(h['status']?.toString());
  if (id == null || trangThai == TrangThaiNha.daGiaiTan) return NhaCuaToi.khongCo(nhanLuc);
  final ds = json['members'];
  final cu = json['formerMembers'];
  return NhaCuaToi(
    nha: NhaEntity(
      id: id,
      ten: h['name']?.toString() ?? '',
      trangThai: trangThai,
      toiDaThanhVien: _soNguyen(h['maxMembers']) ?? kToiDaThanhVienMacDinh,
      idChuNha: _soNguyen(h['ownerId']),
      taoLuc: _ngay(h['createAt']),
      toiDaViChung: _soNguyen(h['maxSharedWallets']),
    ),
    vai: vaiNhaTuServer(json['myRole']?.toString()),
    thanhVien: [
      for (final m in ds is List ? ds : const <Object?>[])
        if (m is Map && _soNguyen(m['idaccount']) != null)
          ThanhVienNhaEntity(
            idaccount: _soNguyen(m['idaccount'])!,
            tenHienThi: _tenHienThi(m),
            vai: vaiNhaTuServer(m['role']?.toString()),
            vaoLuc: _ngay(m['joinedAt']),
          ),
    ],
    thanhVienCu: [
      for (final m in cu is List ? cu : const <Object?>[])
        if (m is Map && _soNguyen(m['idaccount']) != null)
          ThanhVienCuEntity(
            idaccount: _soNguyen(m['idaccount'])!,
            tenHienThi: _tenHienThi(m),
            roiLuc: _ngay(m['leftAt']),
          ),
    ],
    nhanLuc: nhanLuc,
  );
}

String _tenHienThi(Map<Object?, Object?> m) => m['displayName']?.toString() ?? '';

int? _soNguyen(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

DateTime? _ngay(Object? v) => v is String ? DateTime.tryParse(v) : null;
