class CloudinaryThumb {
  static const String _marker = '/image/upload/';
  static const String _transform = 'c_fill,w_480,h_360,q_auto,f_auto';

  static String? of(String? url) {
    if (url == null || url.isEmpty) return url;
    final host = Uri.tryParse(url)?.host ?? '';
    if (!host.endsWith('cloudinary.com')) return url;
    final i = url.indexOf(_marker);
    if (i < 0) return url;
    final at = i + _marker.length;
    final rest = url.substring(at);
    if (rest.startsWith('c_') || rest.startsWith('w_') || rest.startsWith('f_') || rest.startsWith('q_')) return url;
    return '${url.substring(0, at)}$_transform/$rest';
  }
}
