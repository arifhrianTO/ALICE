
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const AliceApp());
}

class AliceApp extends StatelessWidget {
  const AliceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ALICE',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String message = 'Tekan tombol untuk menghubungkan server';

  Future<void> connectBackend() async {
    setState(() {
      message = 'Menghubungkan...';
    });

    // Untuk Web (Chrome) -> localhost.
    // Untuk Android Emulator -> 10.0.2.2.
    // Untuk HP fisik, ganti dengan IP komputer di jaringan lokal (mis. http://192.168.x.x:8080).
    const baseUrl = kIsWeb ? 'http://localhost:8080' : 'http://10.0.2.2:8080';

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/hello'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          message = '${data['app']}: ${data['message']}';
        });
      } else {
        setState(() {
          message = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        message = 'Gagal terhubung ke backend';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ALICE')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: connectBackend,
                child: const Text('Hubungkan ke Backend'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
