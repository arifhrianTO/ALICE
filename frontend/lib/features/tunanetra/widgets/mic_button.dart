import 'package:material_ui/material_ui.dart';

class MicButton extends StatelessWidget {
  final bool listening;
  final bool speaking;
  final VoidCallback onTap;
  final double diameter;
  const MicButton({
    super.key,
    required this.listening,
    this.speaking = false,
    required this.onTap,
    this.diameter = 360,
  });

  @override
  Widget build(BuildContext context) {
    final active = speaking || listening;
    return Semantics(
      button: true,
      onTap: onTap,
      label: speaking
          ? 'Hentikan suara ALICE'
          : listening
          ? 'Berhenti mendengarkan suara'
          : 'Mulai bicara dengan ALICE',
      hint: speaking
          ? 'Ketuk dua kali untuk menghentikan suara ALICE'
          : listening
          ? 'Ketuk dua kali untuk menghentikan rekaman suara'
          : 'Ketuk dua kali untuk mulai merekam suara Anda',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _circle(diameter, const Color(0xFF6A5B9D)),
              _circle(diameter * 0.873, const Color(0xFF887CB1)),
              _circle(diameter * 0.696, Colors.white),
              Icon(
                speaking ? Icons.stop_rounded : Icons.mic,
                size: diameter * 0.17,
                color: active ? Colors.red : const Color(0xFF46467A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) => SizedBox(
    width: size,
    height: size,
    child: DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    ),
  );
}
