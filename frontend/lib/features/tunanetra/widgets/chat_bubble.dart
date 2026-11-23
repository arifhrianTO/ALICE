import 'package:material_ui/material_ui.dart';

import '../../../core/colors.dart';

class ChatBubble extends StatelessWidget {
  final String label;
  final String? body;
  final bool isUser;
  const ChatBubble.user({super.key, required this.label, this.body})
    : isUser = true;
  const ChatBubble.alice({super.key, required this.label, this.body})
    : isUser = false;

  @override
  Widget build(BuildContext context) {
    final fullText = '$label: ${body ?? "belum ada percakapan"}';
    return Semantics(
      liveRegion: !isUser && body != null && body!.isNotEmpty,
      label: fullText,
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUser ? Colors.white : AliceColors.blueChat,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AliceColors.textPurple,
                    ),
                  ),
                ],
              ),
              if (body != null && body!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  body!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AliceColors.textPurple,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
