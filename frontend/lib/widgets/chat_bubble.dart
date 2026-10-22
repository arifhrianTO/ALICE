import 'package:flutter/material.dart';
import '../core/colors.dart';

class ChatBubble extends StatelessWidget {
  final String label;
  final String? body;
  final bool isUser;
  const ChatBubble.user({super.key, required this.label, this.body}) : isUser = true;
  const ChatBubble.alice({super.key, required this.label, this.body}) : isUser = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? Colors.white : AliceColors.blueChat,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isUser ? 20 : 4),
            topRight: const Radius.circular(20),
            bottomLeft: const Radius.circular(20),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser ? Icons.volume_up : Icons.change_history,
                  size: 16,
                  color: AliceColors.textPurple,
                ),
                const SizedBox(width: 6),
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
    );
  }
}
