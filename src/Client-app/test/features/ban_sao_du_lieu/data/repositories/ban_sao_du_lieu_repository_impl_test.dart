import 'dart:typed_data';

import 'package:flowmoney/features/ban_sao_du_lieu/data/datasources/ban_sao_du_lieu_api.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/data/luu_tep_ban_sao.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/data/models/yeu_cau_ban_sao.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/data/repositories/ban_sao_du_lieu_repository_impl.dart';
import 'package:flowmoney/features/ban_sao_du_lieu/domain/trang_thai_ban_sao.dart';
import 'package:flutter_test/flutter_test.dart';

class _ApiGia implements BanSaoDuLieuApi {
  String? idTai;
  String? dinhDangTai;
  @override
  Future<YeuCauBanSao?> layMoiNhat() async => null;
  @override
  Future<YeuCauBanSao> yeuCau() async => const YeuCauBanSao(id: 'x', trangThai: TrangThaiBanSao.dangTao);
  @override
  Future<TepTaiVe> taiTep(String id, String dinhDang) async {
    idTai = id;
    dinhDangTai = dinhDang;
    return TepTaiVe(ten: 't.$dinhDang', mime: 'x', bytes: Uint8List(0));
  }
}

void main() {
  test('taiVaLuu: tải đúng id + định dạng rồi lưu, trả đường dẫn của bộ lưu', () async {
    final api = _ApiGia();
    TepTaiVe? daLuu;
    final repo = BanSaoDuLieuRepositoryImpl(
      api: api,
      luu: _LuuGhi((t) => daLuu = t),
    );
    expect(await repo.taiVaLuu('id-9', 'json'), 'Tải về/t.json');
    expect((api.idTai, api.dinhDangTai), ('id-9', 'json'));
    expect(daLuu!.ten, 't.json');
  });
}

class _LuuGhi extends LuuTepBanSao {
  _LuuGhi(this.ghi);
  final void Function(TepTaiVe) ghi;
  @override
  Future<String?> luu(TepTaiVe tep) async {
    ghi(tep);
    return 'Tải về/${tep.ten}';
  }
}
