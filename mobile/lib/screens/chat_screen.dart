import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _Message {
  final String text;
  final bool isUser;
  final DateTime time;

  _Message({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_Message> _messages = [
    _Message(
      text: "Merhaba! Ben Expenza Yapay Zekâ Asistanınız. Harcamalarınız, bütçe limitleriniz ve tasarruf hedeflerinizle ilgili sorularınızı yanıtlayabilirim. Nasıl yardımcı olabilirim?",
      isUser: false,
      time: DateTime.now(),
    ),
  ];

  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add(_Message(text: text, isUser: true, time: DateTime.now()));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final reply = await ApiClient.instance.sendChatMessage(text);
      if (mounted) {
        setState(() {
          _messages.add(_Message(text: reply, isUser: false, time: DateTime.now()));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_Message(
            text: "Üzgünüm, asistan servisine bağlanırken bir hata oluştu. Lütfen tekrar deneyin.",
            isUser: false,
            time: DateTime.now(),
          ));
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeModeNotifier.value == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: AppColors.onSurface, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.psychology, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text(
              "Expenza AI",
              style: TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ],
        ),
        shape: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      body: Column(
        children: [
          // Mesaj listesi
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, idx) {
                final msg = _messages[idx];
                return _chatBubble(msg);
              },
            ),
          ),
          
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Asistan yanıt yazıyor...",
                      style: TextStyle(fontSize: 12, color: AppColors.outline),
                    ),
                  ],
                ),
              ),
            ),

          // Alt mesaj çubuğu
          _bottomBar(isDark),
        ],
      ),
    );
  }

  Widget _chatBubble(_Message msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: msg.isUser
                ? AppColors.primary
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
              bottomRight: Radius.circular(msg.isUser ? 4 : 18),
            ),
            border: msg.isUser
                ? null
                : Border.all(color: AppColors.glassBorder),
          ),
          child: Text(
            msg.text,
            style: TextStyle(
              color: msg.isUser ? AppColors.onPrimary : AppColors.onSurface,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.glassBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _textController,
                style: TextStyle(color: AppColors.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Asistana sorun...",
                  hintStyle: TextStyle(color: AppColors.outline, fontSize: 14),
                  border: InputBorder.none,
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                color: AppColors.onPrimary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
