import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

class TranscriptItem {
  final bool isUser;
  final String text;
  final DateTime time;

  const TranscriptItem({
    required this.isUser,
    required this.text,
    required this.time,
  });
}

/// Modal bảng Lịch sử hội thoại & dữ liệu đã đọc (Transcript History)
Future<void> showTranscriptSheet(
  BuildContext context,
  List<TranscriptItem> items, {
  VoidCallback? onClear,
  bool isEn = false,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TranscriptSheet(
        items: items,
        onClear: onClear,
        isEn: isEn,
      ),
    );

class _TranscriptSheet extends StatelessWidget {
  final List<TranscriptItem> items;
  final VoidCallback? onClear;
  final bool isEn;

  const _TranscriptSheet({
    required this.items,
    this.onClear,
    required this.isEn,
  });

  @override
  Widget build(BuildContext context) {
    final title = isEn ? 'Conversation History & Transcript' : 'Lịch sử hội thoại & Lời đọc';
    final emptyMsg = isEn
        ? 'No messages yet. Speak or type a command to see history here.'
        : 'Chưa có tin nhắn nào. Nói hoặc gõ lệnh để lưu lại lịch sử ở đây.';

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF20B151A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: const Color(0x66E4BB63), width: 1.5),
              ),
              child: Column(
                children: [
                  // Handle kéo
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: const Color(0x66E4BB63),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.forum_rounded, color: Color(0xFFE4BB63), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFFFBF4E4),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (items.isNotEmpty && onClear != null)
                          TextButton.icon(
                            icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFE2603F)),
                            label: Text(
                              isEn ? 'Clear' : 'Xoá',
                              style: const TextStyle(color: Color(0xFFE2603F), fontSize: 13),
                            ),
                            onPressed: () {
                              onClear?.call();
                              Navigator.pop(context);
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFFE4BB63)),
                          tooltip: isEn ? 'Close' : 'Đóng',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0x33E4BB63), height: 1),

                  // Danh sách tin nhắn
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                emptyMsg,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Color(0xFF9EA3A8), fontSize: 15),
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: controller,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final item = items[items.length - 1 - idx]; // mới nhất trên đầu
                              final timeStr =
                                  '${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}';

                              return Align(
                                alignment: item.isUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 580),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: item.isUser ? const Color(0x3343D8A0) : const Color(0x33E4BB63),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: item.isUser ? const Color(0x6643D8A0) : const Color(0x55E4BB63),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        item.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            item.isUser ? Icons.person_rounded : Icons.graphic_eq_rounded,
                                            size: 15,
                                            color: item.isUser ? const Color(0xFF43D8A0) : const Color(0xFFE4BB63),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            item.isUser ? (isEn ? 'You' : 'Bạn') : 'Lắng',
                                            style: TextStyle(
                                              color: item.isUser ? const Color(0xFF43D8A0) : const Color(0xFFE4BB63),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            timeStr,
                                            style: const TextStyle(color: Color(0x77FFFFFF), fontSize: 11),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.text,
                                        style: const TextStyle(
                                          color: Color(0xFFFBF4E4),
                                          fontSize: 15,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
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
      },
    );
  }
}
