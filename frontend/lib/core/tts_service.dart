import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Bungkus widget dengan [NoSpeak] kalau teks di dalamnya TIDAK ingin
/// ikut dibacakan oleh [TtsService.speakPage] (contoh: teks tombol, logo).
class NoSpeak extends StatelessWidget {
  final Widget child;
  const NoSpeak({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String? _lang; // bahasa yang sedang aktif di engine

  Future<void> init() async {
    if (_ready) return;
    try {
      final langOk = await _tts.isLanguageAvailable('id-ID');
      debugPrint('TTS: id-ID tersedia = $langOk');
      final setLang = await _tts.setLanguage('id-ID');
      debugPrint('TTS: setLanguage hasil = $setLang');
      _lang = 'id-ID';
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _ready = true;
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  /// Membacakan string biasa. Tidak pernah melempar error.
  /// [language] contoh: 'id-ID' (Indonesia, default) atau 'en-US' (Inggris).
  Future<void> speak(String text, {String language = 'id-ID'}) async {
    try {
      await init();
      await _tts.stop();
      if (_lang != language) {
        final ok = await _tts.setLanguage(language);
        debugPrint('TTS: ganti bahasa ke $language, hasil = $ok');
        _lang = language;
      }
      final r = await _tts.speak(text);
      debugPrint('TTS: speak hasil = $r | teks = $text');
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Mengumpulkan semua widget Text di bawah [context], urut sesuai layar.
  List<String> extractTexts(BuildContext context) {
    final result = <String>[];

    void visit(Element element) {
      final widget = element.widget;
      if (widget is NoSpeak) return;
      if (widget is Offstage && widget.offstage) return;

      if (widget is Text) {
        final raw = widget.data ?? widget.textSpan?.toPlainText() ?? '';
        final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (clean.isNotEmpty) result.add(clean);
        return;
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    return result;
  }

  /// Membacakan semua teks pada halaman, dengan prefix/suffix opsional.
  Future<void> speakPage(
    BuildContext context, {
    String? prefix,
    String? suffix,
    String language = 'id-ID',
  }) async {
    final parts = <String>[
      if (prefix != null && prefix.trim().isNotEmpty) prefix,
      ...extractTexts(context),
      if (suffix != null && suffix.trim().isNotEmpty) suffix,
    ];

    final sentence = parts
        .map((t) => RegExp(r'[.!?]$').hasMatch(t) ? t : '$t.')
        .join(' ');

    if (sentence.isEmpty) return;
    await speak(sentence, language: language);
  }
}