// lib/features/auth/onboarding_page.dart
//
// Halaman onboarding ALICE (3 halaman, auto-slide per halaman).
// Semua kode ada dalam 1 file ini.
//
// Aset yang dibutuhkan (daftarkan di pubspec.yaml):
//   flutter:
//     assets:
//       - assets/icons/onboarding_2.png
//       - assets/icons/onboarding_3.png
//       - assets/icons/logo+text.png

import 'dart:async' show TimeoutException;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tts_service.dart'; // TTS
import 'role_page.dart'; // tujuan setelah onboarding selesai

// Warna mengikuti desain. Jika ingin memakai core/colors.dart,
// ganti _kDeep dengan kPurple.
const Color _kDeep = Color(0xFF453284);
const Color _kAccent = Color(0xFF5A45B0);

// Lokasi gambar ilustrasi (ubah di sini jika nama file berbeda).
const String _kImgPage2 = 'assets/icons/onboarding_2.png';
const String _kImgPage3 = 'assets/icons/onboarding_3.png';

// Logo halaman 1 (logo + teks). Ubah ekstensi jika bukan .png
const String _kLogo = 'assets/icons/logo+text.png';

// Lebar logo terhadap lebar layar (0.6 = 60%).
const double _kLogoWidthFactor = 0.9;

const Duration _kPageDuration = Duration(seconds: 10);

// TTS: kalimat yang dibacakan di halaman 1 (halaman logo tidak punya teks).
// Halaman 1 memakai bahasa Inggris, halaman 2 & 3 bahasa Indonesia.
const String _kGreeting =
    'Welcome to ALICE! '
    'Assistant for Living, Information and Companion Every Day.';
const String _kLangEn = 'en-US'; // bahasa suara halaman 1
const String _kLangId = 'id-ID'; // bahasa suara halaman 2 & 3

// TTS: batas tunggu maksimal suara selesai sebelum auto-slide dipaksa lanjut
// (pengaman kalau engine TTS bermasalah).
const Duration _kSpeechMaxWait = Duration(seconds: 20);

class OnboardingPage extends StatefulWidget {
  /// Dipanggil saat tombol Next di halaman terakhir ditekan atau
  /// timer halaman terakhir selesai. Jika null, otomatis pindah
  /// ke RolePage.
  final VoidCallback? onFinish;

  const OnboardingPage({super.key, this.onFinish});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  static const int _total = 3;

  final PageController _pageController = PageController();
  late final AnimationController _progress;
  int _page = 0;

  // TTS: satu key per halaman agar teks di halaman itu bisa dibaca.
  final List<GlobalKey> _pageKeys = List.generate(_total, (_) => GlobalKey());

  // TTS: suara yang sedang/terakhir dibacakan (dipakai agar auto-slide
  // menunggu suara selesai).
  Future<void>? _speech;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: _kPageDuration)
      ..addStatusListener((status) async {
        if (status == AnimationStatus.completed) {
          // TTS: kalau timer habis tapi suara belum selesai, tunggu dulu.
          final int pageAtEnd = _page;
          await _waitSpeech();
          // Batal kalau pengguna sudah pindah halaman sendiri (tombol Next).
          if (!mounted || _page != pageAtEnd) return;
          _next();
        }
      })
      ..forward();

    // TTS: bacakan halaman 1 setelah layar selesai digambar.
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak(0));
  }

  @override
  void dispose() {
    TtsService.instance.stop(); // TTS
    _progress.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  //  TTS
  // ------------------------------------------------------------------

  /// Membacakan halaman [index]:
  ///  - halaman 1 : kalimat greeting tetap
  ///  - halaman 2 & 3 : semua Text yang ada di halaman tersebut
  ///    (tombol Next tidak ikut karena berada di luar halaman)
  void _speak(int index) {
    if (index == 0) {
      _speech = TtsService.instance.speak(_kGreeting, language: _kLangEn);
      return;
    }
    // Tunggu frame selesai supaya widget halaman sudah terbangun.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _pageKeys[index].currentContext;
      if (ctx == null) return;
      _speech = TtsService.instance.speakPage(ctx, language: _kLangId);
    });
  }

  /// Menunggu suara selesai (dengan batas waktu supaya tidak macet).
  Future<void> _waitSpeech() async {
    final s = _speech;
    if (s == null) return;
    try {
      await s.timeout(_kSpeechMaxWait);
    } on TimeoutException {
      // lanjut saja
    } catch (_) {
      // TTS error -> jangan menghalangi auto-slide
    }
  }

  void _next() {
    if (!mounted) return;
    if (_page < _total - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _progress.stop();
      TtsService.instance.stop(); // TTS
      if (widget.onFinish != null) {
        widget.onFinish!();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RolePage()),
        );
      }
    }
  }

  void _onPageChanged(int i) {
    setState(() => _page = i);
    _progress.forward(from: 0); // timer diulang tiap halaman
    _speak(i); // TTS: baca otomatis tiap pindah halaman
  }

  @override
  Widget build(BuildContext context) {
    final bool lightTop = _page == 2; // halaman 3: bagian atas putih
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lightTop ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kDeep,
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                KeyedSubtree(
                  key: _pageKeys[0],
                  child: const _LogoPage(),
                ),

                // ============ HALAMAN 2 ============
                KeyedSubtree(
                  key: _pageKeys[1],
                  child: const _InfoPage(
                    title: 'Dapatkan Informasi\ndengan Mudah',
                    subtitle:
                        'Tanyakan informasi sehari-hari dan atur jadwalmu melalui suara.',
                    image: _kImgPage2,
                    topColor: _kDeep,
                    stageColor: Colors.white,
                    titleColor: Colors.white,
                    subtitleColor: Colors.white,
                    // --- Pengaturan gambar & latar HALAMAN 2 ---
                    imageScale: 5, // ukuran gambar
                    imageOffsetX: 20, // geser kanan (+) / kiri (-)
                    imageOffsetY: 290, // geser bawah (+) / atas (-)
                    imageTopGap: -250, // batas tinggi gambar dari lengkungan
                    curveHeight: 120, // kebulatan lengkungan
                    stageTop: 20, // jarak teks ke lengkungan
                  ),
                ),

                // ============ HALAMAN 3 ============
                KeyedSubtree(
                  key: _pageKeys[2],
                  child: const _InfoPage(
                    title: 'Pantau Tunanetra\nyang kamu dampingi',
                    subtitle:
                        'Ketahui lokasi dan kondisi secara real time dengan mudah dan aman.',
                    image: _kImgPage3,
                    topColor: Colors.white,
                    stageColor: _kDeep,
                    titleColor: _kAccent,
                    subtitleColor: _kAccent,
                    // --- Pengaturan gambar & latar HALAMAN 3 ---
                    imageScale: 1.3, // ukuran gambar
                    imageOffsetX: 40, // geser kanan (+) / kiri (-)
                    imageOffsetY: 150, // geser bawah (+) / atas (-)
                    imageTopGap: -250, // batas tinggi gambar dari lengkungan
                    curveHeight: 120, // kebulatan lengkungan
                    stageTop: 20, // jarak teks ke lengkungan
                  ),
                ),
              ],
            ),

            // ---- Garis progres di atas ----
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: AnimatedBuilder(
                  animation: _progress,
                  builder: (context, _) {
                    return Row(
                      children: List.generate(_total, (i) {
                        final double value = i < _page
                            ? 1
                            : (i == _page ? _progress.value : 0);
                        return Expanded(
                          child: Padding(
                            padding:
                                EdgeInsets.only(right: i == _total - 1 ? 0 : 6),
                            child: _ProgressBar(value: value, onLight: lightTop),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ),

            // ---- Tombol Next ----
            Positioned(
              left: 24,
              right: 24,
              bottom: 32 + bottomInset,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    // Halaman 2: tombol ungu tua. Halaman 1 & 3: tombol putih.
                    backgroundColor: _page == 1 ? _kDeep : Colors.white,
                    foregroundColor: _page == 1 ? Colors.white : _kDeep,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
//  GARIS PROGRES
// =====================================================================
class _ProgressBar extends StatelessWidget {
  final double value;
  final bool onLight;

  const _ProgressBar({required this.value, required this.onLight});

  @override
  Widget build(BuildContext context) {
    final Color track = onLight
        ? _kDeep.withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.35);
    final Color fill = onLight ? _kDeep : Colors.white;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0.0, 1.0),
                child: ColoredBox(color: fill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
//  HALAMAN 1 - LOGO
// =====================================================================
class _LogoPage extends StatelessWidget {
  const _LogoPage();

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return Container(
      color: _kDeep,
      alignment: Alignment.center,
      child: Image.asset(
        _kLogo,
        width: width * _kLogoWidthFactor,
        fit: BoxFit.contain,
      ),
    );
  }
}

// =====================================================================
//  HALAMAN 2 & 3 - JUDUL + ILUSTRASI
//  Semua pengaturan gambar diisi per halaman (lihat PageView di atas).
// =====================================================================
class _InfoPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final String image;
  final Color topColor;
  final Color stageColor;
  final Color titleColor;
  final Color subtitleColor;

  /// Skala lebar gambar terhadap lebar layar (>1 = lebih besar, tepi terpotong).
  final double imageScale;

  /// Geser gambar ke kanan (positif) / kiri (negatif), dalam piksel.
  final double imageOffsetX;

  /// Geser gambar ke bawah (positif) / atas (negatif), dalam piksel.
  final double imageOffsetY;

  /// Pengurang tinggi gambar dari tinggi area ilustrasi. Positif = gambar
  /// lebih pendek (atas aman), negatif = gambar boleh lebih tinggi.
  final double imageTopGap;

  /// Tinggi lengkungan atas area ilustrasi. Makin besar makin bulat;
  /// setengah lebar layar = setengah lingkaran sempurna.
  final double curveHeight;

  /// Jarak dari teks ke atas lengkungan (makin besar = area turun).
  final double stageTop;

  const _InfoPage({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.topColor,
    required this.stageColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.imageScale,
    required this.imageOffsetX,
    required this.imageOffsetY,
    required this.imageTopGap,
    required this.curveHeight,
    required this.stageTop,
  });

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double topInset = MediaQuery.of(context).padding.top;
    return Container(
      color: topColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, topInset + 56, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 35,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 20,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: stageTop),
          Expanded(
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: stageColor,
                // Lengkung elips di sisi atas area ilustrasi
                borderRadius: BorderRadius.vertical(
                  top: Radius.elliptical(width / 2, curveHeight),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final double maxH = c.maxHeight - imageTopGap;
                  final double imgW = width * imageScale;
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        // kiri = tengah layar + geser kanan (X)
                        left: (width - imgW) / 2 + imageOffsetX,
                        // bawah negatif = gambar turun (Y)
                        bottom: -imageOffsetY,
                        width: imgW,
                        height: maxH,
                        // Tombol Next menimpa bagian bawah gambar.
                        child: Image.asset(
                          image,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}