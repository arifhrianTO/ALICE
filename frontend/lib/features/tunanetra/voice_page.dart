import 'dart:async';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/api_config.dart';
import '../../core/colors.dart';
import '../../core/tts_service.dart';
import '../auth/role_page.dart';
import '../pendamping/jadwal/jadwal_data.dart';
import 'assistant_service.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/mic_button.dart';

class VoicePage extends StatefulWidget {
  const VoicePage({super.key});

  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage> {
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
  int _noMatchRetries = 0;

  Timer? _wakeRestartTimer;
  Timer? _hapticTimer;
  Timer? _listenTimer;
  VoidCallback? _afterSpeak;

  static const int _maxNoMatchRetries = 2;
  static const Duration _wakeListenFor = Duration(minutes: 5);
  static const Duration _wakePauseFor = Duration(seconds: 15);
  static const Duration _commandListenFor = Duration(seconds: 30);
  static const Duration _commandPauseFor = Duration(seconds: 6);
  static const Duration _micSettleDelay = Duration(milliseconds: 800);
  static const Duration _commandHardTimeout = Duration(seconds: 10);
  static const Duration _wakeHardTimeout = Duration(seconds: 20);
  static const bool _wakeEnabled = false;

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

  @override
  void initState() {
    super.initState();
    TtsService.instance.speaking.addListener(_onSpeakingChanged);
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
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
    if (_disposed) return;
    _noMatchRetries = 0;
    await _speak(
      'Pengenalan suara sedang bermasalah. Silakan coba lagi sebentar lagi.',
      then: _resumeWake,
    );
  }

  void _onSpeechStatus(String status) {
    if (_disposed) return;
    if (status != 'done' && status != 'notListening') return;
    debugPrint('Speech status: $status');
    final wasCommandListening = !_listeningWake && listening;
    _listeningWake = false;
    if (mounted && wasCommandListening) setState(() => listening = false);
    if (TtsService.instance.isSpeaking || processing) return;
    if (_awaitingLogoutConfirmation) {
      _awaitingLogoutConfirmation = false;
      _resumeWake();
      return;
    }
    if (_wakeActive) _scheduleWakeRestart();
  }

  void _onSpeakingChanged() {
    if (_disposed) return;
    if (TtsService.instance.isSpeaking) {
      _stopHaptics();
      _startHaptics();
      _listeningWake = false;
      _listenTimer?.cancel();
      _speech.cancel();
      if (mounted && listening) setState(() => listening = false);
      return;
    }

    _stopHaptics();
    _completionHaptics();
    final action = _afterSpeak;
    _afterSpeak = null;
    if (action != null) {
      action();
    } else if (_wakeActive) {
      _scheduleWakeRestart();
    }
  }

  void _startHaptics() {
    _hapticTimer?.cancel();
    HapticFeedback.mediumImpact();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (TtsService.instance.isSpeaking) HapticFeedback.selectionClick();
    });
  }

  void _stopHaptics() {
    _hapticTimer?.cancel();
    _hapticTimer = null;
  }

  Future<void> _completionHaptics() async {
    await HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.lightImpact();
  }

  Future<void> _speak(String text, {VoidCallback? then}) async {
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
      await _speech.cancel();
      await _waitMicReleased();
      final locale = await _pickLocale();
      debugPrint('Speech beginListen($wake): starting, locale=$locale');
      _listeningWake = wake;
      if (!wake && mounted) {
        setState(() => listening = true);
        HapticFeedback.mediumImpact();
        await SystemSound.play(SystemSoundType.click);
      }
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: locale,
          listenFor: wake ? _wakeListenFor : _commandListenFor,
          pauseFor: wake ? _wakePauseFor : _commandPauseFor,
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.confirmation,
        ),
        onResult: (result) {
          if (_disposed) return;
          debugPrint(
            'Speech recognized: "${result.recognizedWords}" '
            'final=${result.finalResult}',
          );
          if (wake) {
            _maybeWake(result.recognizedWords);
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
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    await Future<void>.delayed(_micSettleDelay);
  }

  void _scheduleListenRetry({required bool wake, int attempts = 0}) {
    if (_disposed || TtsService.instance.isSpeaking) return;
    if (attempts >= 5) {
      debugPrint('Speech listenRetry: give up after 5 attempts');
      return;
    }
    _wakeRestartTimer?.cancel();
    _wakeRestartTimer = Timer(const Duration(milliseconds: 800), () {
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
    if (_disposed) return;
    _wakeActive = true;
    _beginListen(wake: false);
  }

  Future<void> _handleCommandNoMatch() async {
    if (_disposed) return;
    if (_awaitingLogoutConfirmation) {
      _awaitingLogoutConfirmation = false;
      _resumeWake();
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
    final normalized = text
        .toLowerCase()
        .replaceAll(_nonWord, ' ')
        .replaceAll(_spaces, ' ')
        .trim();
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
    if (TtsService.instance.isSpeaking) {
      HapticFeedback.lightImpact();
      await TtsService.instance.stop();
      return;
    }
    if (listening) {
      _wakeActive = true;
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
    await _speech.cancel();
    await _waitMicReleased();
    await _beginListen(wake: false);
  }

  Future<void> _handleFinal(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _disposed) return;

    _noMatchRetries = 0;
    _wakeActive = false;
    _listeningWake = false;
    _wakeRestartTimer?.cancel();
    if (mounted) setState(() => listening = false);
    await _speech.cancel();

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

  bool _isLogoutCommand(String text) {
    final normalized = text.toLowerCase();
    return _logoutWords.any(normalized.contains);
  }

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
    final normalized = text.toLowerCase();
    final saysNo = _noWords.any(normalized.contains);
    final saysYes = _yesWords.any(normalized.contains);
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

  Future<void> _performLogout() async {
    _wakeActive = false;
    _wakeRestartTimer?.cancel();
    await _speech.cancel();
    await TtsService.instance.speak('Baik, sampai jumpa.');
    await TtsService.instance.stop();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token') ?? '';
    if (token.isNotEmpty) {
      try {
        await http
            .post(
              Uri.parse('${ApiConfig.baseUrl}/api/auth/logout'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Keluar tetap dilanjutkan walau server tidak bisa dihubungi.
      }
    }

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
    TtsService.instance.speaking.removeListener(_onSpeakingChanged);
    _wakeRestartTimer?.cancel();
    _hapticTimer?.cancel();
    _listenTimer?.cancel();
    _speech.cancel();
    _scrollController.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          child: CircularProgressIndicator(color: Colors.white),
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
