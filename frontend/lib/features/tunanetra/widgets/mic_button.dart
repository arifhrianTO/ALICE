import 'package:flutter/material.dart';

import '../../../core/colors.dart';

class MicButton extends StatelessWidget {
  final bool listening;
  final VoidCallback onTap;
  const MicButton({super.key, required this.listening, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: listening ? 'Berhenti mendengarkan' : 'Tekan untuk bicara',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AliceColors.primaryDark.withValues(alpha: 0.35),
          ),
          child: Center(
            child: Container(
              width: 164,
              height: 164,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AliceColors.primary.withValues(alpha: 0.5),
              ),
              child: Center(
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AliceColors.pinkMid,
                  ),
                  child: Icon(
                    Icons.mic,
                    size: 56,
                    color: listening ? Colors.red : AliceColors.textPurple,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
