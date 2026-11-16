import '../datasources/ban_sao_du_lieu_api.dart';
import '../luu_tep_ban_sao.dart';
import '../models/yeu_cau_ban_sao.dart';
import 'ban_sao_du_lieu_repository.dart';

class BanSaoDuLieuRepositoryImpl implements BanSaoDuLieuRepository {
  BanSaoDuLieuRepositoryImpl({required this.api, this.luu = const LuuTepBanSao()});

  final BanSaoDuLieuApi api;
  final LuuTepBanSao luu;

  @override
  Future<YeuCauBanSao?> layMoiNhat() => api.layMoiNhat();

  @override
  Future<YeuCauBanSao> yeuCau() => api.yeuCau();

  @override
  Future<String?> taiVaLuu(String id, String dinhDang) async => luu.luu(await api.taiTep(id, dinhDang));
}
