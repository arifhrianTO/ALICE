import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Keluarkan akun Google dan Facebook dari HP supaya login berikutnya
/// menampilkan pilihan akun lagi. Tidak pernah melempar error dan tidak
/// menahan proses logout lebih dari 3 detik per layanan.
Future<void> signOutSocialAccounts() async {
  try {
    await GoogleSignIn().signOut().timeout(const Duration(seconds: 3));
  } catch (_) {}
  try {
    await FacebookAuth.instance.logOut().timeout(const Duration(seconds: 3));
  } catch (_) {}
}