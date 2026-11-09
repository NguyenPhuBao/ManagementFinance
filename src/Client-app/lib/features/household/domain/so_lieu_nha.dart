/// Số liệu của nhà (`docs/Family/02A` mục 7.3). Biên `[tu, den)` như Sổ giao dịch.
library;

import '../../transaction/data/models/transaction_entity.dart';
import 'loai_khoan_nha.dart';

bool _trongKy(TransactionEntity t, DateTime? tu, DateTime? den) =>
    !t.isDeleted && t.deletedAt == null && (tu == null || !t.date.isBefore(tu)) && (den == null || t.date.isBefore(den));

double _tong(Iterable<TransactionEntity> ds, Set<LoaiKhoanNha> loai, DateTime? tu, DateTime? den) => ds
    .where((t) => _trongKy(t, tu, den) && loai.contains(phanLoaiKhoanNha(t)))
    .fold(0.0, (s, t) => s + t.amount);

double tienVaoQuy(Iterable<TransactionEntity> ds, {DateTime? tu, DateTime? den}) =>
    _tong(ds, const {LoaiKhoanNha.gopNha, LoaiKhoanNha.thuKhac}, tu, den);

double chiCuaNha(Iterable<TransactionEntity> ds, {DateTime? tu, DateTime? den}) =>
    _tong(ds, const {LoaiKhoanNha.chiNha}, tu, den);
