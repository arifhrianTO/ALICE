import 'package:flutter/material.dart';

class Waveform extends StatelessWidget {
  final bool active;
  const Waveform({super.key, this.active = false});

  @override
  Widget build(BuildContext context) {
    final heights = <double>[14, 22, 30, 18, 34, 26, 40, 24, 30, 16, 28, 20, 32, 22, 14, 18];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: heights.map((h) => Container(
        width: 5,
        height: active ? h : 12,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      )).toList(),
    );
  }
}
