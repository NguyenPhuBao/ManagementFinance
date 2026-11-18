import 'dart:async';

import 'package:flowmoney/features/ban_sao_du_lieu/data/models/yeu_cau_ban_sao.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/data/repositories/ban_sao_du_lieu_repository.dart';

/// Repo giả cho cubit / trang "Dữ liệu của tôi": mỗi lời gọi lấy kết quả (hoặc lỗi) đặt sẵn và đếm số lần.
class BanSaoRepoGia implements BanSaoDuLieuRepository {
  YeuCauBanSao? moiNhat;
  Object? loiDoc;
  YeuCauBanSao? ketQuaYeuCau;
  Object? loiYeuCau;
  String? noiLuu = 'Tải về/tep';
  Object? loiTai;
  Completer<void>? khoaYeuCau;

  int soLanDoc = 0;
  int soLanYeuCau = 0;
  final List<(String, String)> daTai = [];

  @override
  Future<YeuCauBanSao?> layMoiNhat() async {
    soLanDoc++;
    if (loiDoc != null) throw loiDoc!;
    return moiNhat;
  }

  @override
  Future<YeuCauBanSao> yeuCau() async {
    soLanYeuCau++;
    if (khoaYeuCau != null) await khoaYeuCau!.future;
    if (loiYeuCau != null) throw loiYeuCau!;
    return ketQuaYeuCau!;
  }

  @override
  Future<String?> taiVaLuu(String id, String dinhDang) async {
    daTai.add((id, dinhDang));
    if (loiTai != null) throw loiTai!;
    return noiLuu;
  }
}
