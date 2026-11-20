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
  bool listening = false;
  bool processing = false;
  bool _speechAvailable = false;
  bool _greeted = false;
  bool _awaitingLogoutConfirmation = false;
  final List<_Conversation> _conversations = [];

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
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
  }

  Future<void> _greet() async {
    if (_greeted) return;
    _greeted = true;
    if (!mounted) return;
    if (MediaQuery.of(context).accessibleNavigation) return;
    await TtsService.instance.speak(
      'Halo, selamat datang di ALICE. Tekan tombol mikrofon lalu ucapkan pertanyaan Anda. '
      'Anda bisa bertanya tentang waktu, tanggal, atau cuaca. Ucapkan keluar untuk mengakhiri sesi.',
    );
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => listening = false);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() => listening = false);
            _showError(
              'Mikrofon tidak dapat digunakan. Periksa izin mikrofon.',
            );
          }
        },
      );
      if (mounted) setState(() => _speechAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  Future<String?> _pickLocale() async {
    try {
      final locales = await _speech.locales();
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase().replaceAll('-', '_');
        if (id == 'id_id' || id.startsWith('id_')) return locale.localeId;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _startListening() async {
    final locale = await _pickLocale();
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: locale,
        listenFor: const Duration(seconds: 30),
      ),
      onResult: (result) {
        if (result.finalResult) _handleFinal(result.recognizedWords);
      },
    );
  }

  Future<void> _toggle() async {
    if (listening) {
      await _speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable) {
        _showError('Pengenalan suara tidak tersedia di perangkat ini.');
        return;
      }
    }
    setState(() => listening = true);
    await _startListening();
  }

  Future<void> _handleFinal(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;

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
    await TtsService.instance.speak(prompt);

    if (!_speechAvailable) {
      await _handleLogoutConfirmation('ya');
      return;
    }
    if (!mounted) return;
    setState(() => listening = true);
    await _startListening();
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

    final message = saysNo
        ? 'Baik, saya batalkan. Ada lagi yang bisa saya bantu?'
        : 'Saya tidak yakin, jadi saya batalkan agar aman. Ada lagi yang bisa saya bantu?';
    if (_conversations.isNotEmpty) {
      setState(() {
        _conversations[0] = _conversations.first.copyWith(answer: message);
      });
    }
    await TtsService.instance.speak(message);
  }

  Future<void> _performLogout() async {
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
    setState(() {
      listening = false;
      processing = true;
      _conversations.insert(0, _Conversation(question: text));
    });
    try {
      final reply = await AssistantService.ask(text);
      if (!mounted) return;
      setState(() {
        _conversations[0] = _conversations.first.copyWith(answer: reply.answer);
      });
      await TtsService.instance.speak(reply.answer);
    } catch (error) {
      if (!mounted) return;
      final answer = _friendlyError(error);
      setState(() {
        _conversations[0] = _conversations.first.copyWith(answer: answer);
      });
      await TtsService.instance.speak(answer);
    } finally {
      if (mounted) setState(() => processing = false);
      if (mounted) {
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
    }
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
                child: MicButton(
                  listening: listening,
                  onTap: _toggle,
                  diameter: constraints.maxWidth.clamp(0.0, 360.0),
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
