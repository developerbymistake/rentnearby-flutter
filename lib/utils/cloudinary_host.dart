// Exact host rule shared by every Cloudinary URL helper: res.cloudinary.com or a subdomain of cloudinary.com.
bool isCloudinaryHost(String url) {
  final host = (Uri.tryParse(url)?.host ?? '').toLowerCase();
  return host == 'res.cloudinary.com' || host.endsWith('.cloudinary.com');
}
