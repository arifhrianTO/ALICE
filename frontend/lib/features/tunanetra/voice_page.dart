import 'dart:async';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/schedule_service.dart';

import '../../core/api_config.dart';
import '../../core/colors.dart';
import '../../core/notification_service.dart';
import '../../core/social_signout.dart';
import '../../core/tts_service.dart';
import '../auth/role_page.dart';
import '../pendamping/jadwal/jadwal_data.dart';
import 'assistant_service.dart';
import 'incoming_request_data.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/mic_button.dart';

class VoicePage extends StatefulWidget {
  const VoicePage({super.key});

  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage> with WidgetsBindingObserver {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ScrollController _scrollController = ScrollController();
  final List<_Conversation> _conversations = [];

  bool listening = false;
  bool processing = false;
  bool _speechAvailable = false;
  bool _greeted = false;
  bool _disposed = false;
  bool _wakeActive = false;
  bool _listeningWake = false;
  bool _startingListen = false;
  bool _awaitingLogoutConfirmation = false;

  /// True begitu proses keluar akun dimulai. Dipakai untuk mematikan semua
  /// aktivitas lain (mikrofon, pemeriksaan permintaan, dialog) supaya tidak
  /// ada yang berjalan di tengah proses keluar.
  bool _loggingOut = false;
  int _noMatchRetries = 0;

  Timer? _wakeRestartTimer;
  Timer? _listenTimer;
  Timer? _endOfSpeechTimer;
  VoidCallback? _afterSpeak;

  /// Kapan terakhir kali ada aktivitas audio (TTS selesai, sesi mikrofon
  /// berakhir). Jeda penyesuaian mikrofon hanya diberikan kalau aktivitas
  /// itu baru saja terjadi, jadi menekan tombol mikrofon saat sepi langsung
  /// diproses tanpa menunggu.
  DateTime _lastAudioActivity = DateTime.fromMillisecondsSinceEpoch(0);

  /// Level suara paling sepi pada sesi mendengar yang sedang berjalan.
  double? _levelBaseline;
  int _levelLogCount = 0;

  /// Bahasa pengenalan suara disimpan setelah dicari sekali, karena
  /// `_speech.locales()` memanggil platform dan bisa memakan waktu.
  String? _speechLocale;
  bool _localeResolved = false;

  /// Waktu getaran terakhir saat pengguna berbicara. Dipakai membatasi
  /// jarak antar-getaran supaya tidak bergetar terus-menerus.
  DateTime _lastUserSpeechHaptic = DateTime.fromMillisecondsSinceEpoch(0);

  /// Ucapan final terakhir. Dipakai membuang hasil final ganda yang kadang
  /// dikirim dua kali oleh recognizer Android.
  String _lastFinalText = '';
  DateTime _lastFinalAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Pendengar notifikasi push. Dipakai supaya dialog permintaan muncul
  /// seketika saat notifikasi tiba, tanpa menunggu pemeriksaan berkala.
  StreamSubscription<Map<String, String>>? _pushSubscription;

  // --- Pemantauan permintaan tautan masuk dari pendamping ---
  Timer? _requestPollTimer;
  Timer? _requestRepromptTimer;
  IncomingRequest? _incomingRequest;
  ScheduleRequestRecord? _incomingSchedule;
  bool _requestCheckInFlight = false;
  bool _appResumed = true;

  /// Tahap dialog permintaan tautan yang sedang berjalan.
  /// idle = tidak ada dialog, decide = menanyakan setuju/tolak.
  _RequestStage _requestStage = _RequestStage.idle;

  /// Pilihan dari pertanyaan pertama; dipakai saat konfirmasi kedua.
  bool? _requestAccept;

  /// Sedang mengirim jawaban ke server (tombol diganti indikator).
  bool _requestSubmitting = false;

  /// Ucapan terakhir yang tertangkap saat dialog permintaan. Boleh masih
  /// hasil sementara (belum final). Disimpan karena recognizer Android
  /// sering mengirim jawaban pendek seperti "ya" hanya sebagai hasil
  /// sementara, lalu menutup sesi dengan error tanpa hasil final.
  String _lastRequestHeard = '';

  /// Penjaga agar satu jawaban tidak diproses dua kali (mis. hasil sementara
  /// yang lalu diikuti error atau status selesai).
  bool _requestAnswerHandled = false;

  /// Prompt terakhir yang dibacakan. Dipakai membuang hasil pengenalan yang
  /// sebenarnya gema suara TTS perangkat sendiri.
  String _lastSpokenPrompt = '';

  static const int _maxNoMatchRetries = 2;
  static const Duration _wakeListenFor = Duration(minutes: 5);
  static const Duration _wakePauseFor = Duration(seconds: 15);
  static const Duration _commandListenFor = Duration(seconds: 30);

  /// Lama diam sebelum ucapan dianggap selesai. Dulu 6 detik, sehingga
  /// jawaban baru diproses lama setelah pengguna berhenti bicara.
  /// Naikkan sedikit (mis. 4 detik) kalau ucapan sering terpotong.
  static const Duration _commandPauseFor = Duration(seconds: 2);

  /// Jika tidak ada kata baru selama ini setelah pengguna mulai bicara,
  /// ucapan dianggap selesai dan mikrofon dimatikan sendiri (tidak menunggu
  /// recognizer Android yang kadang lama menutup sesi). Naikkan (mis. 2
  /// detik) kalau kalimat sering terpotong saat pengguna berhenti sejenak.
  static const Duration _endOfSpeechSilence = Duration(milliseconds: 700);

  /// Jeda singkat agar mikrofon benar-benar lepas sebelum dipakai lagi.
  /// Dulu 800 ms. Kalau muncul error "busy" atau mikrofon gagal menyala,
  /// naikkan lagi ke 500 ms.
  static const Duration _micSettleDelay = Duration(milliseconds: 300);

  static const Duration _commandHardTimeout = Duration(seconds: 10);
  static const Duration _wakeHardTimeout = Duration(seconds: 20);
  static const bool _wakeEnabled = false;

  /// Jeda setelah TTS selesai sebelum mikrofon dinyalakan di dialog
  /// permintaan. Dulu 600 ms.
  ///
  /// Tanpa jeda ini, mikrofon langsung menangkap ekor suara TTS perangkat
  /// sendiri ("gema") dan bisa salah mengira itu jawaban pengguna.
  static const Duration _postSpeechDelay = Duration(milliseconds: 200);

  /// Jarak minimum antar-getaran saat pengguna berbicara.
  static const Duration _userSpeechHapticGap = Duration(milliseconds: 350);

  /// Seberapa jauh level suara harus naik dari level paling sepi pada sesi
  /// itu supaya dianggap pengguna sedang berbicara. Pada Android levelnya
  /// kira-kira -2 (sepi) sampai 10 (keras). Turunkan (mis. 2.5) kalau
  /// bicara pelan tidak bergetar; naikkan (mis. 5) kalau suara sekitar
  /// ikut membuatnya bergetar.
  static const double _voiceLevelRise = 3.5;

  /// Selang antar-pemeriksaan permintaan tautan masuk.
  static const Duration _requestPollInterval = Duration(seconds: 5);

  static final RegExp _wakePattern = RegExp(r'\b(hi|hai|hei)\s+alice\b');
  static final RegExp _nonWord = RegExp(r'[^a-z0-9\s]');
  static final RegExp _spaces = RegExp(r'\s+');

  static const _logoutWords = [
    'keluar',
    'logout',
    'log out',
    'logud',
    'keluar aplikasi',
    'keluar akun',
  ];
  static const _yesWords = ['ya', 'iya', 'yakin', 'betul', 'benar'];
  static const _noWords = [
    'tidak',
    'batal',
    'jangan',
    'nggak',
    'gak',
    'enggak',
  ];

  /// Merapikan teks: huruf kecil, tanpa tanda baca, spasi tunggal.
  static String _normalize(String text) => text
      .toLowerCase()
      .replaceAll(_nonWord, ' ')
      .replaceAll(_spaces, ' ')
      .trim();

  /// Apakah [text] memuat salah satu kata/frasa sebagai KATA UTUH.
  ///
  /// Berbeda dengan `contains` biasa: "saya" tidak lagi dianggap memuat "ya".
  static bool _hasAnyPhrase(String text, List<String> phrases) {
    final padded = ' ${_normalize(text)} ';
    return phrases.any((p) => padded.contains(' $p '));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TtsService.instance.speaking.addListener(_onSpeakingChanged);
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
    _startRequestPolling();
    _listenToPushNotifications();
  }

  /// Berlangganan notifikasi push pengajuan tautan.
  ///
  /// Begitu notifikasi datang (aplikasi sedang di depan, atau baru diketuk
  /// dari latar belakang), permintaan langsung diperiksa. Pemeriksaan
  /// berkala tetap berjalan sebagai jaring pengaman kalau notifikasi tidak
  /// sampai.
  void _listenToPushNotifications() {
    _pushSubscription = NotificationService.messages.listen(_onPushMessage);

    // Aplikasi yang baru saja dibuka dari notifikasi: aliran di atas belum
    // sempat mendengarnya. Periksa sekarang juga supaya tidak menunggu
    // interval berkala. (Pemeriksaan juga aman dijalankan dua kali.)
    if (NotificationService.consumePendingMessage() != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _checkIncomingRequest(),
      );
    }
  }

  /// Menanggapi notifikasi push. Pemeriksaan server menjadi sumber data
  /// utama, sehingga payload cukup menjadi pemicu untuk memuat ulang daftar
  /// permintaan tautan maupun permintaan jadwal.
  void _onPushMessage(Map<String, String> data) {
    if (_disposed || _loggingOut) return;
    _checkIncomingRequest();
  }

  Future<void> _greet() async {
    if (_greeted || !mounted) return;
    _greeted = true;
    if (MediaQuery.of(context).accessibleNavigation) {
      _resumeWake();
      return;
    }
    await _speak(
      'Halo, selamat datang di ALICE. Tekan tombol mikrofon lalu ucapkan pertanyaan Anda. '
      'Anda bisa bertanya tentang waktu, tanggal, cuaca, atau lokasi Anda. '
      'Ucapkan keluar untuk mengakhiri sesi.',
      then: _resumeWake,
    );
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        debugLogging: true,
        onStatus: _onSpeechStatus,
        onError: (error) {
          if (_disposed) return;
          debugPrint('Speech error: ${error.errorMsg}');
          _touchAudio();
          _endOfSpeechTimer?.cancel();
          final fromWake = _listeningWake;
          _listeningWake = false;
          if (mounted && listening) setState(() => listening = false);
          if (fromWake) {
            if (_wakeActive &&
                !TtsService.instance.isSpeaking &&
                !processing) {
              final infra = _isSpeechInfraError(error.errorMsg);
              _scheduleWakeRestart(
                delay: infra
                    ? const Duration(milliseconds: 2500)
                    : const Duration(milliseconds: 1200),
              );
            }
          } else if (_requestStage != _RequestStage.idle) {
            // Dialog permintaan aktif: coba pakai ucapan yang sempat
            // tertangkap dulu sebelum menyerah dan mengulang pertanyaan.
            _handleRequestSpeechEnded(errorCode: error.errorMsg);
          } else {
            if (_isSpeechInfraError(error.errorMsg)) {
              _handleCommandFailure();
            } else {
              _handleCommandNoMatch();
            }
          }
        },
      );
      if (!mounted) return;
      setState(() => _speechAvailable = available);
      if (available && !_localeResolved) {
        _speechLocale = await _pickLocale();
        _localeResolved = true;
      }
      debugPrint('Speech init: available = $available, wakeActive = $_wakeActive');
      if (available && _wakeActive) _scheduleWakeRestart();
    } catch (_) {
      debugPrint('Speech init: error');
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  bool _isSpeechInfraError(String code) =>
      code == 'error_server_disconnected' ||
      code == 'error_network' ||
      code == 'error_busy' ||
      code == 'error_client';

  Future<void> _handleCommandFailure() async {
    if (_disposed || _loggingOut) return;
    _noMatchRetries = 0;
    if (_requestStage != _RequestStage.idle) {
      // Mikrofon bermasalah saat dialog permintaan: arahkan ke tombol.
      await _speak(
        'Pengenalan suara sedang bermasalah. Silakan tekan tombol setuju atau tolak.',
      );
      return;
    }
    await _speak(
      'Pengenalan suara sedang bermasalah. Silakan coba lagi sebentar lagi.',
      then: _resumeWake,
    );
  }

  void _onSpeechStatus(String status) {
    if (_disposed) return;
    if (status == 'listening') {
      // Mikrofon benar-benar sudah aktif: bunyi klik sebagai tanda
      // "silakan bicara".
      if (!_listeningWake && listening) {
        unawaited(SystemSound.play(SystemSoundType.click));
      }
      return;
    }
    if (status != 'done' && status != 'notListening') return;
    debugPrint('Speech status: $status');
    _touchAudio();
    _endOfSpeechTimer?.cancel();
    final wasCommandListening = !_listeningWake && listening;
    _listeningWake = false;
    if (mounted && wasCommandListening) setState(() => listening = false);
    if (TtsService.instance.isSpeaking || processing) return;

    // CATATAN: status konfirmasi keluar sengaja TIDAK direset di sini.
    // Status "done/notListening" juga dikirim oleh setiap `_speech.cancel()`
    // (yang dipanggil tepat sebelum pertanyaan konfirmasi dibacakan), jadi
    // dulu penanda konfirmasi ikut terhapus dan jawaban "ya" malah dianggap
    // pertanyaan biasa. Kalau pengguna diam, error "no match" dari recognizer
    // yang membatalkan konfirmasi (lihat [_handleCommandNoMatch]).

    if (_requestStage != _RequestStage.idle) {
      // Dialog permintaan aktif: pakai ucapan terakhir kalau memang memuat
      // pilihan; kalau tidak, dengarkan lagi (tombol tetap bisa dipakai).
      _handleRequestSpeechEnded();
      return;
    }
    if (_wakeActive) _scheduleWakeRestart();
  }

  /// Dipanggil setiap status TTS berubah.
  ///
  /// Tidak ada getaran di sini: getaran sekarang hanya aktif saat PENGGUNA
  /// berbicara (lihat [_hapticForUserSpeech]), bukan saat ALICE berbicara.
  void _onSpeakingChanged() {
    if (_disposed || _loggingOut) return;
    if (TtsService.instance.isSpeaking) {
      _listeningWake = false;
      _listenTimer?.cancel();
      _endOfSpeechTimer?.cancel();
      _speech.cancel();
      if (mounted && listening) setState(() => listening = false);
      return;
    }

    _touchAudio();
    final action = _afterSpeak;
    _afterSpeak = null;
    if (action != null) {
      action();
    } else if (_wakeActive) {
      _scheduleWakeRestart();
    }
  }

  /// Getaran singkat selama pengguna berbicara.
  ///
  /// Dipicu dari dua sumber, supaya tetap terasa walaupun recognizer jarang
  /// mengirim hasil sementara:
  ///   1. level suara mikrofon ([_onSoundLevel]), terus-menerus selama
  ///      pengguna bersuara;
  ///   2. kata baru yang tertangkap ([_hapticForUserSpeech]).
  /// Keduanya dibatasi [_userSpeechHapticGap] supaya tidak bergetar rapat.
  void _pulseForUserSpeech() {
    if (_disposed ||
        _loggingOut ||
        !listening ||
        TtsService.instance.isSpeaking) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastUserSpeechHaptic) < _userSpeechHapticGap) return;
    _lastUserSpeechHaptic = now;
    HapticFeedback.mediumImpact();
  }

  /// Getaran saat ada kata baru yang tertangkap.
  void _hapticForUserSpeech(String words) {
    final text = words.trim();
    if (text.isEmpty || _looksLikePromptEcho(text)) return;
    _pulseForUserSpeech();
  }

  /// Dipanggil terus-menerus oleh mikrofon dengan level suara saat ini.
  /// Bergetar kalau levelnya naik jelas di atas level paling sepi sesi ini.
  void _onSoundLevel(double level) {
    if (_disposed || !listening || _listeningWake) return;

    // Catatan untuk menyetel [_voiceLevelRise]: level dicetak berkala.
    if (_levelLogCount++ % 20 == 0) {
      debugPrint(
        'Speech level: ${level.toStringAsFixed(1)} '
        '(sepi: ${_levelBaseline?.toStringAsFixed(1)})',
      );
    }

    final base = _levelBaseline;
    if (base == null || level < base) {
      _levelBaseline = level;
      return;
    }
    if (level - base >= _voiceLevelRise) _pulseForUserSpeech();
  }

  void _touchAudio() => _lastAudioActivity = DateTime.now();

  /// Mematikan mikrofon sendiri kalau pengguna sudah berhenti bicara.
  ///
  /// Dipanggil tiap ada hasil (sementara/final). Selama kata terus bertambah,
  /// timer diulang. Begitu tidak ada kata baru selama [_endOfSpeechSilence],
  /// mikrofon dihentikan dan hasil dikirim, tanpa menunggu recognizer
  /// menutup sesi sendiri.
  void _armEndOfSpeechTimer(String words, bool isFinal) {
    _endOfSpeechTimer?.cancel();
    if (isFinal || words.trim().isEmpty) return;
    _endOfSpeechTimer = Timer(_endOfSpeechSilence, () {
      if (_disposed || _loggingOut || !_speech.isListening) return;
      debugPrint('Speech: tidak ada kata baru, hentikan mendengar');
      if (mounted && listening) setState(() => listening = false);
      _speech.stop();
    });
  }

  Future<void> _speak(String text, {VoidCallback? then}) async {
    // Disimpan supaya hasil pengenalan yang sebenarnya gema suara TTS
    // perangkat sendiri bisa dibuang (lihat [_looksLikePromptEcho]).
    _lastSpokenPrompt = text;
    _afterSpeak = then;
    await TtsService.instance.speak(text);
  }

  Future<String?> _pickLocale() async {
    try {
      final locales = await _speech.locales();
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase().replaceAll('-', '_');
        if (id == 'id_id' ||
            id == 'in_id' ||
            id.startsWith('id_') ||
            id.startsWith('in_')) {
          return locale.localeId;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _beginListen({required bool wake}) async {
    if (!_speechAvailable ||
        _startingListen ||
        _disposed ||
        _loggingOut ||
        TtsService.instance.isSpeaking) {
      debugPrint(
        'Speech beginListen($wake): skipped (available=$_speechAvailable, '
        'starting=$_startingListen, disposed=$_disposed, '
        'speaking=${TtsService.instance.isSpeaking})',
      );
      return;
    }
    if (_speech.isListening) {
      debugPrint('Speech beginListen($wake): still listening, retrying later');
      _scheduleListenRetry(wake: wake);
      return;
    }
    _startingListen = true;
    try {
      // Tampilan langsung berubah (mikrofon merah + satu getaran) begitu
      // tombol ditekan, tanpa menunggu mikrofon siap. Bunyi klik menyusul
      // saat mikrofon benar-benar aktif (lihat status 'listening').
      _listeningWake = wake;
      if (!wake && mounted) {
        setState(() => listening = true);
        HapticFeedback.mediumImpact();
      }
      await _waitMicReleased();
      if (!_localeResolved) {
        _speechLocale = await _pickLocale();
        _localeResolved = true;
      }
      final locale = _speechLocale;
      _levelBaseline = null;
      debugPrint('Speech beginListen($wake): starting, locale=$locale');
      if (_disposed || _loggingOut) return;
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: locale,
          listenFor: wake ? _wakeListenFor : _commandListenFor,
          pauseFor: wake ? _wakePauseFor : _commandPauseFor,
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.confirmation,
        ),
        onSoundLevelChange: _onSoundLevel,
        onResult: (result) {
          if (_disposed) return;
          debugPrint(
            'Speech recognized: "${result.recognizedWords}" '
            'final=${result.finalResult}',
          );
          if (wake) {
            _maybeWake(result.recognizedWords);
            return;
          }

          // Pengguna sedang berbicara: bergetar, dan pantau kapan berhenti.
          _hapticForUserSpeech(result.recognizedWords);
          _armEndOfSpeechTimer(result.recognizedWords, result.finalResult);

          if (_requestStage != _RequestStage.idle) {
            // Dialog permintaan: pakai juga hasil sementara, karena jawaban
            // pendek seperti "ya" sering tidak pernah menjadi hasil final.
            _onRequestSpeech(result.recognizedWords);
          } else if (result.finalResult) {
            final text = result.recognizedWords.trim();
            if (text.isEmpty) {
              _handleCommandNoMatch();
            } else {
              _handleFinal(text);
            }
          }
        },
      );
      _listenTimer?.cancel();
      final hardTimeout = wake ? _wakeHardTimeout : _commandHardTimeout;
      _listenTimer = Timer(hardTimeout, () {
        if (_disposed) return;
        debugPrint('Speech hard timeout ($wake): forcing stop');
        if (_speech.isListening) {
          if (wake) _listeningWake = false;
          if (mounted && listening) setState(() => listening = false);
          _speech.stop();
        }
      });
    } catch (error) {
      debugPrint('Speech listen error: $error');
      _listeningWake = false;
      if (mounted && listening) setState(() => listening = false);
      if (wake) {
        _scheduleWakeRestart(delay: const Duration(milliseconds: 1200));
      } else {
        _handleCommandFailure();
      }
    } finally {
      _startingListen = false;
    }
  }

  Future<void> _waitMicReleased() async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (_speech.isListening && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    // Jeda hanya sisa waktu sejak aktivitas audio terakhir. Kalau sudah
    // lama sepi (mis. pengguna baru menekan tombol), langsung lanjut.
    final remaining = _micSettleDelay - DateTime.now().difference(_lastAudioActivity);
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
  }

  void _scheduleListenRetry({required bool wake, int attempts = 0}) {
    if (_disposed || TtsService.instance.isSpeaking) return;
    if (attempts >= 5) {
      debugPrint('Speech listenRetry: give up after 5 attempts');
      return;
    }
    _wakeRestartTimer?.cancel();
    _wakeRestartTimer = Timer(const Duration(milliseconds: 500), () {
      if (_disposed || TtsService.instance.isSpeaking) return;
      if (_startingListen || _speech.isListening) {
        _scheduleListenRetry(wake: wake, attempts: attempts + 1);
        return;
      }
      if (wake) {
        if (_wakeActive && !listening) _beginListen(wake: true);
      } else {
        _beginListen(wake: false);
      }
    });
  }

  void _scheduleWakeRestart({
    Duration delay = const Duration(milliseconds: 1500),
  }) {
    if (_disposed ||
        !_wakeEnabled ||
        !_wakeActive ||
        listening ||
        TtsService.instance.isSpeaking) {
      return;
    }
    _wakeRestartTimer?.cancel();
    _wakeRestartTimer = Timer(delay, () {
      if (_disposed ||
          !_wakeActive ||
          listening ||
          TtsService.instance.isSpeaking ||
          _startingListen) {
        return;
      }
      _beginListen(wake: true);
    });
  }

  void _resumeWake() {
    if (_disposed) return;
    _wakeActive = _wakeEnabled;
    _listeningWake = false;
    if (_wakeEnabled) _scheduleWakeRestart();
  }

  void _listenForCommand() {
    if (_disposed || _loggingOut) return;
    _wakeActive = true;
    _beginListen(wake: false);
  }

  Future<void> _handleCommandNoMatch() async {
    if (_disposed || _loggingOut) return;
    if (_awaitingLogoutConfirmation) {
      _awaitingLogoutConfirmation = false;
      _resumeWake();
      return;
    }
    if (_requestStage != _RequestStage.idle) {
      await _repeatUnclearAnswer();
      return;
    }
    if (_noMatchRetries < _maxNoMatchRetries) {
      _noMatchRetries++;
      HapticFeedback.heavyImpact();
      await _speak(
        'Maaf, saya tidak mendengar dengan jelas. Silakan ucapkan ulang.',
        then: _listenForCommand,
      );
      return;
    }
    _noMatchRetries = 0;
    await _speak(
      'Saya belum mendengar ucapan Anda. Silakan tekan tombol mikrofon lalu ucapkan pertanyaan Anda.',
      then: _resumeWake,
    );
  }

  void _maybeWake(String text) {
    if (!_wakeActive || _disposed) return;
    final normalized = _normalize(text);
    final match = _wakePattern.firstMatch(normalized);
    if (match == null) return;

    _wakeActive = false;
    _listeningWake = false;
    _speech.cancel();
    HapticFeedback.heavyImpact();

    final command = normalized.substring(match.end).trim();
    if (command.isNotEmpty) {
      _handleFinal(command);
      return;
    }
    if (mounted) setState(() => listening = true);
    _speak('Ya, ada yang bisa saya bantu?', then: _listenForCommand);
  }

  Future<void> _toggle() async {
    if (_loggingOut) return;
    if (TtsService.instance.isSpeaking) {
      HapticFeedback.lightImpact();
      await TtsService.instance.stop();
      return;
    }
    if (listening) {
      _wakeActive = true;
      _endOfSpeechTimer?.cancel();
      await _speech.stop();
      if (mounted) setState(() => listening = false);
      _scheduleWakeRestart();
      return;
    }
    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable) {
        _showError('Pengenalan suara tidak tersedia di perangkat ini.');
        HapticFeedback.heavyImpact();
        await _speak(
          'Maaf, mikrofon tidak dapat digunakan. Periksa izin mikrofon pada pengaturan perangkat.',
          then: _resumeWake,
        );
        return;
      }
    }
    _wakeActive = true;
    _noMatchRetries = 0;
    _wakeRestartTimer?.cancel();
    // _beginListen sudah membatalkan sesi lama dan menunggu mikrofon lepas,
    // jadi tidak perlu diulang di sini (dulu menambah jeda dua kali lipat).
    await _beginListen(wake: false);
  }

  /// True kalau [text] sama dengan ucapan final yang baru saja diproses.
  /// Recognizer Android kadang mengirim hasil final dua kali; tanpa ini
  /// "keluar" yang kedua dianggap jawaban konfirmasi dan membatalkan keluar.
  bool _isDuplicateFinal(String text) {
    final now = DateTime.now();
    final duplicate = text == _lastFinalText &&
        now.difference(_lastFinalAt) < const Duration(seconds: 2);
    _lastFinalText = text;
    _lastFinalAt = now;
    return duplicate;
  }

  Future<void> _handleFinal(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _disposed || _loggingOut) return;
    if (_isDuplicateFinal(text)) {
      debugPrint('Speech final ganda diabaikan: "$text"');
      return;
    }

    _noMatchRetries = 0;
    _wakeActive = false;
    _listeningWake = false;
    _wakeRestartTimer?.cancel();
    _endOfSpeechTimer?.cancel();
    if (mounted) setState(() => listening = false);
    await _speech.cancel();

    if (_requestStage != _RequestStage.idle) {
      await _handleRequestAnswer(text);
      return;
    }
    if (_awaitingLogoutConfirmation) {
      await _handleLogoutConfirmation(text);
      return;
    }
    if (_isLogoutCommand(text)) {
      await _beginLogoutConfirmation(text);
      return;
    }
    await _submitQuestion(text);
  }

  bool _isLogoutCommand(String text) => _hasAnyPhrase(text, _logoutWords);

  Future<void> _beginLogoutConfirmation(String question) async {
    const prompt =
        'Apakah Anda yakin ingin keluar dari akun? Katakan ya untuk keluar, atau tidak untuk membatalkan.';
    setState(() {
      listening = false;
      _awaitingLogoutConfirmation = true;
      processing = false;
      _conversations.insert(
        0,
        _Conversation(question: question, answer: prompt),
      );
    });
    await _speech.cancel();

    if (!_speechAvailable) {
      await _handleLogoutConfirmation('ya');
      return;
    }
    await _speak(prompt, then: _listenForCommand);
  }

  Future<void> _handleLogoutConfirmation(String text) async {
    final saysNo = _hasAnyPhrase(text, _noWords);
    final saysYes = _hasAnyPhrase(text, _yesWords);
    setState(() {
      listening = false;
      _awaitingLogoutConfirmation = false;
    });

    if (saysYes && !saysNo) {
      await _performLogout();
      return;
    }

    _wakeActive = true;
    final message = saysNo
        ? 'Baik, saya batalkan. Ada lagi yang bisa saya bantu?'
        : 'Saya tidak yakin, jadi saya batalkan agar aman. Ada lagi yang bisa saya bantu?';
    if (_conversations.isNotEmpty) {
      setState(() {
        _conversations[0] = _conversations.first.copyWith(answer: message);
      });
    }
    await _speak(message, then: _resumeWake);
  }

  /// Menjalankan [action] dan menelan semua error. Dipakai pada langkah
  /// pembersihan saat keluar: kegagalan satu langkah tidak boleh
  /// menghentikan proses keluar.
  Future<void> _safely(Future<dynamic> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Sengaja diabaikan.
    }
  }

  /// Mengucapkan salam perpisahan lalu menunggu selesai (maksimal 3 detik).
  /// Sebagian mesin TTS mengembalikan Future sebelum suara selesai, jadi
  /// status "sedang bicara" ikut dipantau supaya ucapan tidak terpotong.
  Future<void> _sayGoodbye() async {
    await _safely(() => TtsService.instance.speak('Baik, sampai jumpa.'));
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (TtsService.instance.isSpeaking && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await _safely(() => TtsService.instance.stop());
  }

  Future<void> _performLogout() async {
    if (_loggingOut) return;
    _loggingOut = true;

    // Hentikan semua aktivitas lain lebih dulu.
    _wakeActive = false;
    _awaitingLogoutConfirmation = false;
    _wakeRestartTimer?.cancel();
    _listenTimer?.cancel();
    _endOfSpeechTimer?.cancel();
    _requestPollTimer?.cancel();
    _requestPollTimer = null;
    _requestRepromptTimer?.cancel();
    _afterSpeak = null;
    if (mounted && listening) setState(() => listening = false);
    await _safely(() => _speech.cancel());

    await _sayGoodbye();

    // Lepaskan HP ini dari akun dulu, selagi token sesi masih tersimpan.
    // Dibatasi 3 detik supaya keluar tidak tertahan kalau server mati.
        await _safely(
      () => NotificationService.unregisterCurrentDevice().timeout(
        const Duration(seconds: 3),
      ),
    );

    // Keluarkan akun Google/Facebook dari HP supaya login berikutnya
    // menampilkan pilihan akun lagi.
    await signOutSocialAccounts();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token') ?? '';

    for (final key in const [
      'isLoggedIn',
      'session_token',
      'user_id',
      'user_role',
      'user_name',
      'user_email',
      'user_phone',
      'user_address',
    ]) {
      await prefs.remove(key);
    }
    scheduleStore.reset();

    // Beri tahu server di latar belakang. Tidak ditunggu, supaya perpindahan
    // halaman tidak tertahan; keluar tetap berlaku di HP walau server gagal.
    if (token.isNotEmpty) {
      unawaited(
        _safely(
          () => http
              .post(
                Uri.parse('${ApiConfig.baseUrl}/api/auth/logout'),
                headers: {'Authorization': 'Bearer $token'},
              )
              .timeout(const Duration(seconds: 5)),
        ),
      );
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RolePage()),
      (_) => false,
    );
  }

  Future<void> _submitQuestion(String question) async {
    final text = question.trim();
    if (text.isEmpty || processing) return;

    _wakeActive = false;
    _wakeRestartTimer?.cancel();
    setState(() {
      listening = false;
      processing = true;
      _conversations.insert(0, _Conversation(question: text));
    });

    String answer;
    try {
      final reply = await AssistantService.ask(text);
      answer = reply.answer;
    } catch (error) {
      answer = _friendlyError(error);
    }

    if (mounted) {
      setState(() {
        _conversations[0] = _conversations.first.copyWith(answer: answer);
        processing = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
    await _speak(answer, then: _resumeWake);
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('TimeoutException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection refused')) {
      return 'ALICE tidak dapat terhubung ke server. Periksa koneksi internet dan pastikan server ALICE sedang berjalan.';
    }
    return text.replaceFirst('Exception: ', '');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _requestPollTimer?.cancel();
    _requestRepromptTimer?.cancel();
    _pushSubscription?.cancel();
    TtsService.instance.speaking.removeListener(_onSpeakingChanged);
    _wakeRestartTimer?.cancel();
    _listenTimer?.cancel();
    _endOfSpeechTimer?.cancel();
    _speech.cancel();
    _scrollController.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  // -----------------------------------------------------------------
  //  Permintaan tautan masuk (dipantau berkala)
  // -----------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _appResumed) return;
    _appResumed = resumed;
    if (resumed) {
      if (!_loggingOut) _startRequestPolling();
    } else {
      // Berhenti memeriksa saat aplikasi tidak di depan, supaya tidak
      // membuang kuota saat tunanetra pindah ke aplikasi lain.
      _requestPollTimer?.cancel();
      _requestPollTimer = null;
    }
  }

  void _startRequestPolling() {
    _requestPollTimer?.cancel();
    _requestPollTimer = Timer.periodic(
      _requestPollInterval,
      (_) => _checkIncomingRequest(),
    );
    // Jangan tunggu satu interval penuh untuk pemeriksaan pertama.
    _checkIncomingRequest();
  }

  /// Mengambil permintaan tautan dan jadwal yang masih menunggu.
  /// Permintaan tautan diprioritaskan; setelah selesai, pemeriksaan berkala
  /// berikutnya akan menampilkan permintaan jadwal yang masih tertunda.
  Future<void> _checkIncomingRequest() async {
    if (_disposed || _loggingOut || _requestCheckInFlight || !_appResumed) {
      return;
    }
    if (_requestStage != _RequestStage.idle) return;
    _requestCheckInFlight = true;
    try {
      final linkRequests = await IncomingRequestService.fetchIncoming();
      if (_disposed || _loggingOut) return;

      List<ScheduleRequestRecord> scheduleRequests = [];
      try {
        scheduleRequests = await ScheduleService.fetchIncoming();
      } catch (error) {
        // Kegagalan endpoint jadwal tidak boleh menghalangi permintaan tautan.
        debugPrint('[jadwal] gagal memeriksa permintaan: $error');
      }
      if (_disposed || _loggingOut) return;

      final linkPending = linkRequests.isEmpty ? null : linkRequests.first;
      final schedulePending = scheduleRequests.isEmpty
          ? null
          : scheduleRequests.first;

      if (linkPending != null) {
        if (_incomingRequest?.id == linkPending.id &&
            _incomingSchedule == null) {
          return;
        }
        setState(() {
          _incomingRequest = linkPending;
          _incomingSchedule = null;
        });
        debugPrint(
          '[permintaan] tautan dari ${linkPending.companionName} '
          '(id=${linkPending.id})',
        );
        await _startRequestFlow(linkPending);
        return;
      }

      if (schedulePending != null) {
        if (_incomingSchedule?.id == schedulePending.id &&
            _incomingRequest == null) {
          return;
        }
        setState(() {
          _incomingRequest = null;
          _incomingSchedule = schedulePending;
        });
        debugPrint(
          '[permintaan] jadwal dari ${schedulePending.companionName} '
          '(id=${schedulePending.id}, action=${schedulePending.action})',
        );
        await _startRequestFlow(schedulePending);
        return;
      }

      if (_incomingRequest != null || _incomingSchedule != null) {
        setState(() {
          _incomingRequest = null;
          _incomingSchedule = null;
        });
      }
    } catch (error) {
      debugPrint('[permintaan] gagal memeriksa: $error');
    } finally {
      _requestCheckInFlight = false;
    }
  }

  // -----------------------------------------------------------------
  //  Dialog permintaan tautan: pertanyaan pertama (setuju / tolak)
  // -----------------------------------------------------------------

  Future<void> _startRequestFlow(Object request) async {
    if (_disposed || _loggingOut || _requestStage != _RequestStage.idle) return;

    // Hentikan aktivitas suara yang sedang berjalan supaya dialog bisa
    // memakai mikrofon dan pengeras suara tanpa tabrakan.
    _wakeActive = false;
    _wakeRestartTimer?.cancel();
    _listenTimer?.cancel();
    _requestRepromptTimer?.cancel();
    _afterSpeak = null;
    await _speech.cancel();
    if (!mounted) return;

    setState(() {
      _requestStage = _RequestStage.decide;
      _requestAccept = null;
      _requestSubmitting = false;
      _lastRequestHeard = '';
      _requestAnswerHandled = false;
      listening = false;
      processing = false;
    });
    HapticFeedback.heavyImpact();
    await _askRequestDecision();
  }

  String get _activeCompanionName =>
      _incomingSchedule?.companionName ?? _incomingRequest?.companionName ?? 'pendamping';

  String _scheduleActionLabel(String action) {
    switch (action.toLowerCase()) {
      case 'add':
      case 'create':
      case 'tambah':
        return 'menambahkan';
      case 'edit':
      case 'update':
      case 'ubah':
        return 'mengubah';
      case 'delete':
      case 'remove':
      case 'hapus':
        return 'menghapus';
      default:
        return 'mengajukan';
    }
  }

  String _scheduleRepeatSpeech(String repeatType) {
    switch (repeatType.toLowerCase()) {
      case 'daily':
      case 'every_day':
      case 'harian':
        return 'setiap hari';
      case 'weekly':
      case 'every_week':
      case 'mingguan':
        return 'setiap minggu';
      case 'monthly':
      case 'every_month':
      case 'bulanan':
        return 'setiap bulan';
      case 'none':
      case 'never':
      case 'once':
      case 'tidak_berulang':
      case '':
        return 'tidak berulang';
      default:
        return repeatType;
    }
  }

  String _scheduleSpeech(ScheduleRequestRecord request) {
    final action = _scheduleActionLabel(request.action);

    final titleValue = (request.title ?? '').trim();
    final title = titleValue.isEmpty ? 'jadwal' : titleValue;

    final parts = <String>[
      '$_activeCompanionName ingin $action jadwal $title',
    ];

    final time = (request.time ?? '').trim();
    if (time.isNotEmpty) parts.add('pukul $time');

    final day = (request.day ?? '').trim();
    if (day.isNotEmpty) parts.add('hari $day');

    final startDate = (request.startDate ?? '').trim();
    if (startDate.isNotEmpty) {
      parts.add('mulai tanggal $startDate');
    }

    final repeat = _scheduleRepeatSpeech(request.repeatType ?? '');
    if (repeat.isNotEmpty) parts.add('pengulangan $repeat');

    final reminderMinutes = request.reminderMinutes ?? 0;
    if (reminderMinutes > 0) {
      parts.add('pengingat $reminderMinutes menit sebelumnya');
    }

    return '${parts.join(', ')}.';
  }

  String? get _activeScheduleSummary {
    final request = _incomingSchedule;
    if (request == null) return null;

    final titleValue = (request.title ?? '').trim();
    final title = titleValue.isEmpty ? 'Jadwal' : titleValue;

    final parts = <String>[
      '${_scheduleActionLabel(request.action)}: $title',
    ];

    final time = (request.time ?? '').trim();
    if (time.isNotEmpty) parts.add('Waktu $time');

    final day = (request.day ?? '').trim();
    if (day.isNotEmpty) parts.add('Hari $day');

    final startDate = (request.startDate ?? '').trim();
    if (startDate.isNotEmpty) {
      parts.add('Mulai $startDate');
    }

    final repeat = _scheduleRepeatSpeech(request.repeatType ?? '');
    if (repeat.isNotEmpty) parts.add('Pengulangan $repeat');

    final reminderMinutes = request.reminderMinutes ?? 0;
    if (reminderMinutes > 0) {
      parts.add('Pengingat $reminderMinutes menit sebelumnya');
    }

    return parts.join(' • ');
  }

  Future<void> _askRequestDecision() async {
    if (_disposed) return;
    final schedule = _incomingSchedule;
    final prompt = schedule != null
        ? 'Ada permintaan jadwal dari ${schedule.companionName}. '
            '${_scheduleSpeech(schedule)} '
            'Katakan setuju untuk menerima, atau tolak untuk menolak.'
        : _incomingRequest == null
            ? ''
            : 'Ada permintaan tautan dari ${_incomingRequest!.companionName}. '
                'Katakan setuju untuk menerima, atau tolak untuk menolak.';
    if (prompt.isEmpty) return;
    await _speak(prompt, then: _listenForRequestAnswer);
  }

  void _listenForRequestAnswer() {
    if (_disposed ||
        _requestStage == _RequestStage.idle ||
        _requestSubmitting) {
      return;
    }
    // Jeda dulu supaya ekor suara TTS tidak ikut tertangkap mikrofon.
    _scheduleRequestListen(_postSpeechDelay);
  }

  void _scheduleRequestReprompt() {
    // Sedikit jeda supaya sesi mikrofon sebelumnya benar-benar lepas.
    _scheduleRequestListen(const Duration(milliseconds: 300));
  }

  /// Menjadwalkan satu sesi mendengar untuk dialog permintaan.
  void _scheduleRequestListen(Duration delay) {
    _requestRepromptTimer?.cancel();
    _requestRepromptTimer = Timer(delay, () {
      if (_disposed ||
          _requestStage == _RequestStage.idle ||
          _requestSubmitting ||
          TtsService.instance.isSpeaking ||
          listening ||
          _startingListen) {
        return;
      }
      // Sesi baru: bersihkan sisa ucapan sesi sebelumnya supaya jawaban
      // lama tidak menjawab pertanyaan berikutnya.
      _lastRequestHeard = '';
      _requestAnswerHandled = false;
      _beginListen(wake: false);
    });
  }

  /// Menangani ucapan selama dialog permintaan (termasuk hasil sementara).
  ///
  /// Hasil sementara dipakai supaya jawaban pendek seperti "ya" langsung
  /// ditanggapi, tanpa menunggu hasil final yang sering tidak datang.
  Future<void> _onRequestSpeech(String raw) async {
    if (_disposed ||
        _requestSubmitting ||
        _requestAnswerHandled ||
        _requestStage == _RequestStage.idle) {
      return;
    }
    final text = raw.trim();
    if (text.isEmpty) return;
    if (_looksLikePromptEcho(text)) {
      debugPrint('[permintaan] abaikan gema prompt: "$text"');
      return;
    }

    _lastRequestHeard = text;
    if (parseRequestDecision(text) == null) {
      // Belum jelas: biarkan recognizer melanjutkan. Kalau sesi berakhir,
      // teks terakhir ini dipakai lagi oleh [_handleRequestSpeechEnded].
      return;
    }

    _requestAnswerHandled = true;
    _requestRepromptTimer?.cancel();
    await _handleRequestAnswer(text);
  }

  /// Dipanggil saat sesi mendengar dialog berakhir (status selesai/error).
  ///
  /// Kalau sempat tertangkap ucapan yang memuat pilihan, pakai itu dulu.
  /// Kalau tidak, baru minta ulang — atau arahkan ke tombol bila error.
  Future<void> _handleRequestSpeechEnded({String? errorCode}) async {
    if (_disposed || _requestStage == _RequestStage.idle) return;
    if (_requestAnswerHandled) return;

    if (_lastRequestHeard.isNotEmpty &&
        parseRequestDecision(_lastRequestHeard) != null) {
      await _onRequestSpeech(_lastRequestHeard);
      return;
    }

    if (errorCode != null) {
      // Error menimpa rencana "dengarkan lagi" dari status selesai.
      _requestRepromptTimer?.cancel();
      if (_isSpeechInfraError(errorCode)) {
        await _handleCommandFailure();
      } else {
        await _handleCommandNoMatch();
      }
      return;
    }

    if (!TtsService.instance.isSpeaking) _scheduleRequestReprompt();
  }

  /// Apakah [text] tampak sebagai gema prompt yang baru dibacakan?
  ///
  /// Gema biasanya panjang dan hampir sama dengan prompt. Jawaban pengguna
  /// (misalnya "ya") pendek, jadi sengaja tidak dianggap gema.
  bool _looksLikePromptEcho(String text) {
    if (_lastSpokenPrompt.isEmpty) return false;
    final said = _normalize(text);
    final prompt = _normalize(_lastSpokenPrompt);
    if (said.isEmpty || prompt.isEmpty) return false;
    if (said.split(' ').length < 3) return false;
    return prompt.contains(said) || said.contains(prompt);
  }

  /// Menafsirkan jawaban suara lalu meneruskannya sesuai tahap dialog.
  ///
  /// Tahap "decide"  : setuju/tolak -> lanjut ke konfirmasi.
  /// Tahap "confirm" : ya = kirim jawaban, tidak = kembali ke pertanyaan awal.
  Future<void> _handleRequestAnswer(String text) async {
    final choice = parseRequestDecision(text);
    if (choice == null) {
      await _repeatUnclearAnswer();
      return;
    }

    if (_requestStage == _RequestStage.decide) {
      await _goToConfirmation(choice);
    } else if (_requestStage == _RequestStage.confirm) {
      if (choice) {
        await _submitRequestResponse();
      } else {
        await _backToDecision();
      }
    }
  }

  /// Ucapan tidak dikenali: minta ulang sesuai tahap yang sedang berjalan.
  Future<void> _repeatUnclearAnswer() async {
    if (_requestStage == _RequestStage.confirm) {
      await _speak(
        'Maaf, saya belum paham. Katakan ya untuk melanjutkan, atau tidak untuk membatalkan.',
        then: _listenForRequestAnswer,
      );
      return;
    }
    await _speak(
      'Maaf, saya belum paham. Katakan setuju untuk menerima, atau tolak untuk menolak.',
      then: _listenForRequestAnswer,
    );
  }

  /// Pindah dari pertanyaan pertama ke konfirmasi kedua.
  Future<void> _goToConfirmation(bool accept) async {
    if (_disposed) return;
    _requestRepromptTimer?.cancel();
    await _speech.cancel();
    if (!mounted) return;
    setState(() {
      _requestAccept = accept;
      _requestStage = _RequestStage.confirm;
      listening = false;
    });
    HapticFeedback.mediumImpact();
    await _askRequestConfirmation();
  }

  /// Membatalkan pilihan dan kembali ke pertanyaan pertama.
  Future<void> _backToDecision() async {
    if (_disposed) return;
    _requestRepromptTimer?.cancel();
    await _speech.cancel();
    if (!mounted) return;
    setState(() {
      _requestAccept = null;
      _requestStage = _RequestStage.decide;
      listening = false;
    });
    HapticFeedback.mediumImpact();
    await _askRequestDecision();
  }

  Future<void> _askRequestConfirmation() async {
    final accept = _requestAccept;
    if (accept == null || _disposed ||
        (_incomingRequest == null && _incomingSchedule == null)) {
      return;
    }
    final option = accept ? 'menerima' : 'menolak';
    final kind = _incomingSchedule == null ? 'tautan' : 'permintaan jadwal';
    final prompt =
        'Anda memilih $option $kind dari $_activeCompanionName. '
        'Yakin? Katakan ya untuk melanjutkan, atau tidak untuk membatalkan.';
    await _speak(prompt, then: _listenForRequestAnswer);
  }

  /// Mengirim jawaban akhir ke server lalu membacakan hasilnya.
  Future<void> _submitRequestResponse() async {
    final linkRequest = _incomingRequest;
    final scheduleRequest = _incomingSchedule;
    final accept = _requestAccept;
    if ((linkRequest == null && scheduleRequest == null) ||
        accept == null || _disposed) {
      return;
    }

    _requestRepromptTimer?.cancel();
    _listenTimer?.cancel();
    await _speech.cancel();
    if (!mounted) return;
    setState(() {
      _requestSubmitting = true;
      listening = false;
    });
    HapticFeedback.heavyImpact();

    try {
      if (scheduleRequest != null) {
        await ScheduleService.respond(scheduleRequest.id, accept: accept);
      } else {
        await IncomingRequestService.respond(linkRequest!.id, accept: accept);
      }
      if (_disposed) return;

      final kind = scheduleRequest == null ? 'tautan' : 'permintaan jadwal';
      debugPrint(
        '[permintaan] jawaban $kind terkirim: ${accept ? 'terima' : 'tolak'}',
      );
      _closeRequestDialog();
      final message = scheduleRequest == null
          ? accept
              ? 'Baik, Anda menerima tautan dari ${linkRequest!.companionName}. Sekarang Anda sudah terhubung.'
              : 'Baik, Anda menolak tautan dari ${linkRequest!.companionName}.'
          : accept
              ? 'Baik, Anda menerima permintaan jadwal dari ${scheduleRequest.companionName}.'
              : 'Baik, Anda menolak permintaan jadwal dari ${scheduleRequest.companionName}.';
      await _speak(message, then: _resumeWake);
    } on RequestRespondException catch (error) {
      if (_disposed) return;
      debugPrint('[permintaan] gagal mengirim: $error (gone=${error.gone})');
      if (error.gone) {
        _closeRequestDialog();
        await _speak(
          'Pengajuan ini sudah tidak berlaku lagi.',
          then: _resumeWake,
        );
        return;
      }
      if (!mounted) return;
      setState(() => _requestSubmitting = false);
      await _speak(
        'Maaf, jawaban belum terkirim. Kita coba sekali lagi.',
        then: _askRequestConfirmation,
      );
    } catch (error) {
      if (_disposed) return;
      debugPrint('[permintaan] gagal mengirim: $error');
      if (!mounted) return;
      setState(() => _requestSubmitting = false);
      await _speak(
        'Maaf, jawaban belum terkirim. Kita coba sekali lagi.',
        then: _askRequestConfirmation,
      );
    }
  }

  /// Menutup dialog permintaan dan mengembalikan state ke normal.
  void _closeRequestDialog() {
    setState(() {
      _requestSubmitting = false;
      _requestStage = _RequestStage.idle;
      _requestAccept = null;
      _incomingRequest = null;
      _incomingSchedule = null;
      _lastRequestHeard = '';
      _requestAnswerHandled = false;
      listening = false;
    });
  }

  /// Dipanggil tombol pada dialog. [primary] = tombol utama
  /// (Setuju / Ya), false = tombol kedua (Tolak / Batal).
  Future<void> _onRequestButton(bool primary) async {
    if (_requestSubmitting || _requestStage == _RequestStage.idle) return;

    _wakeRestartTimer?.cancel();
    _listenTimer?.cancel();
    _requestRepromptTimer?.cancel();
    _afterSpeak = null;
    // Tombol sudah menentukan jawaban; cegah hasil suara yang datang
    // telat ikut menjawab.
    _requestAnswerHandled = true;
    await TtsService.instance.stop();
    if (!mounted) return;
    setState(() => listening = false);

    if (_requestStage == _RequestStage.decide) {
      await _goToConfirmation(primary);
      return;
    }
    if (primary) {
      await _submitRequestResponse();
    } else {
      await _backToDecision();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AliceColors.primaryDark,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Semantics(
              header: true,
              label: 'Halaman Suara ALICE',
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Image.asset(
                  'assets/icons/logo_full.png',
                  width: 142,
                  height: 48,
                  fit: BoxFit.contain,
                  semanticLabel: 'Logo ALICE',
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: TtsService.instance.speaking,
                      builder: (context, speaking, _) => MicButton(
                        listening: listening,
                        speaking: speaking,
                        onTap: _toggle,
                        diameter: constraints.maxWidth.clamp(0.0, 360.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      itemCount: _conversations.length + (processing ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (processing && index == 0) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          );
                        }
                        final conversation =
                            _conversations[processing ? index - 1 : index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            children: [
                              ChatBubble.user(
                                label: 'Suara Anda',
                                body: conversation.question,
                              ),
                              const SizedBox(height: 12),
                              ChatBubble.alice(
                                label: 'Respon Sistem',
                                body:
                                    conversation.answer ??
                                    'Sedang menyiapkan jawaban...',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_requestStage != _RequestStage.idle &&
            (_incomingRequest != null || _incomingSchedule != null))
          Positioned.fill(
            child: _RequestOverlay(
              companionName: _activeCompanionName,
              scheduleSummary: _activeScheduleSummary,
              confirmation: _requestStage == _RequestStage.confirm,
              accepting: _requestAccept ?? false,
              busy: _requestSubmitting,
              onPrimary: () => _onRequestButton(true),
              onSecondary: () => _onRequestButton(false),
            ),
          ),
      ],
    );
  }
}

class _Conversation {
  final String question;
  final String? answer;

  const _Conversation({required this.question, this.answer});

  _Conversation copyWith({String? answer}) =>
      _Conversation(question: question, answer: answer ?? this.answer);
}

/// Tahap dialog permintaan tautan yang sedang berjalan.
///
/// idle    = tidak ada dialog.
/// decide  = menanyakan "setuju" atau "tolak".
/// confirm = menanyakan "yakin?" sebelum jawaban dikirim.
enum _RequestStage { idle, decide, confirm }

/// Overlay layar penuh untuk dialog permintaan tautan.
///
/// Menangani dua tahap:
///   - [confirmation] false -> menanyakan "Setuju / Tolak".
///   - [confirmation] true  -> menanyakan "Yakin?" sebelum jawaban dikirim.
///
/// Sengaja dibuat besar dan kontras tinggi supaya ramah pembaca layar
/// (TalkBack) dan mudah ditekan. Lapisan gelap di belakang menahan
/// sentuhan agar pengguna tidak tanpa sengaja menekan halaman di baliknya.
class _RequestOverlay extends StatelessWidget {
  final String companionName;
  final String? scheduleSummary;
  final bool confirmation;
  final bool accepting;
  final bool busy;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _RequestOverlay({
    required this.companionName,
    this.scheduleSummary,
    required this.confirmation,
    required this.accepting,
    required this.busy,
    required this.onPrimary,
    required this.onSecondary,
  });

  bool get _isSchedule => scheduleSummary != null;

  String get _title => confirmation
      ? 'Konfirmasi Jawaban'
      : _isSchedule
          ? 'Permintaan Jadwal Baru'
          : 'Permintaan Tautan Baru';

  String get _message {
    if (!confirmation) {
      if (_isSchedule) {
        return '$companionName mengajukan permintaan jadwal: $scheduleSummary';
      }
      return '$companionName ingin menautkan akun dengan Anda.';
    }
    final kind = _isSchedule ? 'permintaan jadwal' : 'tautan';
    return accepting
        ? 'Yakin ingin MENERIMA $kind dari $companionName?'
        : 'Yakin ingin MENOLAK $kind dari $companionName?';
  }

  String get _hint {
    if (!confirmation) {
      return 'Anda bisa menjawab dengan suara: "setuju" atau "tolak".';
    }
    return 'Jawab dengan suara: "ya" untuk melanjutkan, atau "tidak" untuk membatalkan.';
  }

  String get _primaryLabel {
    if (!confirmation) return 'Setuju';
    return accepting ? 'Ya, Terima' : 'Ya, Tolak';
  }

  String get _secondaryLabel => confirmation ? 'Batal' : 'Tolak';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: confirmation
          ? 'Konfirmasi jawaban untuk permintaan dari $companionName'
          : 'Konfirmasi permintaan tautan dari $companionName',
      child: Stack(
        children: [
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.65)),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          color: kLightPurple,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          confirmation
                              ? Icons.help_outline_rounded
                              : Icons.link_rounded,
                          color: kDarkPurple,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: kTextPurple,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: Color(0xFF444455),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _hint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF777788),
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (busy)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: kPurple),
                              SizedBox(height: 12),
                              Text(
                                'Mengirim jawaban...',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: kTextPurple,
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        _RequestOverlayButton(
                          label: _primaryLabel,
                          icon: Icons.check_rounded,
                          background: kPurple,
                          foreground: Colors.white,
                          onTap: onPrimary,
                        ),
                        const SizedBox(height: 12),
                        _RequestOverlayButton(
                          label: _secondaryLabel,
                          icon: Icons.close_rounded,
                          background: kLightPurple,
                          foreground: kDarkPurple,
                          onTap: onSecondary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol besar pada overlay permintaan tautan.
class _RequestOverlayButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _RequestOverlayButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      hint: 'Ketuk dua kali untuk $label',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            height: 58,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foreground, size: 24),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}