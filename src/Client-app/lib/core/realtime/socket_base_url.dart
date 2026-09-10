/// Suy địa chỉ máy chủ Socket.io từ địa chỉ API.
///
/// `AppConstants.baseUrl` kết thúc bằng `/api` (`http://10.0.2.2:3000/api` trên
/// máy ảo Android, `http://127.0.0.1:3000/api` trên web/desktop) vì mọi endpoint
/// REST nằm dưới tiền tố ấy. Socket.io thì gắn vào **gốc** máy chủ, nên phải bỏ
/// hậu tố đó đi.
///
/// Tách thành hàm thuần có test thay vì cắt chuỗi tại chỗ: sai ở đây không ném
/// lỗi nào cả, chỉ là một chuỗi `connect_error` không ai đọc.
String socketBaseUrlFrom(String apiBaseUrl) {
  var s = apiBaseUrl.trim();
  s = _boGachCheoCuoi(s);
  // So theo ĐOẠN cuối, không phải theo chuỗi con: tên miền chứa "api" vẫn phải
  // nguyên vẹn.
  if (s.endsWith('/api')) {
    s = s.substring(0, s.length - '/api'.length);
  }
  return _boGachCheoCuoi(s);
}

String _boGachCheoCuoi(String s) {
  var out = s;
  while (out.endsWith('/')) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}
