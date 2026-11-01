import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/colors.dart';
import '../../core/text.dart';
import '../auth/role_page.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/mic_button.dart';
import 'widgets/waveform.dart';

class VoicePage extends StatefulWidget {
  const VoicePage({super.key});

  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage> {
  bool listening = false;
  String userText = '';
  String aliceText = '';

  void _toggle() {
    setState(() {
      listening = !listening;
      if (listening) {
        userText = '...mendengarkan (suara)...';
        aliceText = '';
      } else {
        userText = 'Halo Alice, jadwal saya hari ini apa?';
        aliceText = 'Pagi ini ada jadwal istirahat dan konsultasi pukul 10:00.';
      }
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Akun'),
        content: const Text('Apakah Anda ingin keluar dan kembali ke pemilihan peran?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RolePage()),
      (_) => false,
    );
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
          child: const Text('ALICE', style: AliceText.logo),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Keluar dari akun',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 12),
              MicButton(listening: listening, onTap: _toggle),
              const SizedBox(height: 20),
              ExcludeSemantics(
                excluding: true,
                child: Waveform(active: listening),
              ),
              const SizedBox(height: 24),
              ChatBubble.user(
                label: 'Suara Anda',
                body: userText.isEmpty ? null : userText,
              ),
              const SizedBox(height: 12),
              ChatBubble.alice(
                label: 'Alice Menjawab',
                body: aliceText.isEmpty ? null : aliceText,
              ),
              const Spacer(),
              Semantics(
                label: listening
                    ? 'Mikrofon sedang mendengarkan. Ketuk tombol mikrofon untuk berhenti'
                    : 'Mikrofon siap. Ketuk tombol mikrofon untuk bicara',
                child: Text(
                  listening ? 'Ketuk mic untuk berhenti' : 'Ketuk mic untuk bicara',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
