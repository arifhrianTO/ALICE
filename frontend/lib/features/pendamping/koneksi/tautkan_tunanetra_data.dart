// =====================================================================
//  DATA TUNANETRA
// =====================================================================

/// Calon tunanetra yang bisa ditautkan ke pendamping.
class Tunanetra {
  final String name;
  final String email;

  const Tunanetra({required this.name, required this.email});
}

/// Data contoh (placeholder) supaya pagination punya beberapa halaman.
/// Ganti isi list ini dengan data dari backend saat sudah tersedia.
final List<Tunanetra> dummyTunanetra = List.generate(
  25,
  (_) => const Tunanetra(
    name: 'Budi Santoso',
    email: 'BudiSantoso@gmail.com',
  ),
);