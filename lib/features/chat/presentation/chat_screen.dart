import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/chat_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/chat_message.dart';
import 'chat_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels < 120) {
        ref.read(chatControllerProvider.notifier).loadOlder();
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final me = ref.watch(authControllerProvider).value;
    return Scaffold(
      body: Column(
        children: [
          _Header(
            onSignOut: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
          Expanded(
            child: chat.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: FilledButton(
                  onPressed: () => ref.invalidate(chatControllerProvider),
                  child: const Text('다시 연결하기'),
                ),
              ),
              data: (value) => value.messages.isEmpty
                  ? const _EmptyChat()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      itemCount: value.messages.length,
                      itemBuilder: (context, index) {
                        final message = value.messages[index];
                        return _MessageBubble(
                          message: message,
                          isMine: message.senderId == me?.id,
                          onRetry: () => ref
                              .read(chatControllerProvider.notifier)
                              .retry(message),
                        );
                      },
                    ),
            ),
          ),
          _Composer(controller: _text, onSend: _send),
        ],
      ),
    );
  }

  void _send() {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    ref.read(chatControllerProvider.notifier).send(body);
    _text.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      20,
      MediaQuery.paddingOf(context).top + 14,
      12,
      18,
    ),
    decoration: const BoxDecoration(
      color: AppColors.mango,
      borderRadius: BorderRadius.vertical(bottom: Radius.elliptical(220, 28)),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.forum_rounded, color: AppColors.leaf),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MangoTalk', style: Theme.of(context).textTheme.titleLarge),
              const Text('함께 이야기하는 중', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          tooltip: '로그아웃',
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onRetry,
  });
  final ChatMessage message;
  final bool isMine;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${message.senderNickname}의 메시지: ${message.body}',
    child: Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.purple.withValues(alpha: .14),
                child: Text(
                  message.senderNickname.characters.first.toUpperCase(),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text(
                        message.senderNickname,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 310),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isMine ? AppColors.leaf : Colors.white,
                      borderRadius: BorderRadius.circular(20).copyWith(
                        bottomRight: isMine ? const Radius.circular(5) : null,
                        bottomLeft: isMine ? null : const Radius.circular(5),
                      ),
                    ),
                    child: Text(
                      message.body,
                      style: TextStyle(
                        color: isMine ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                  if (message.status != MessageSendStatus.sent)
                    TextButton.icon(
                      onPressed: message.status == MessageSendStatus.failed
                          ? onRetry
                          : null,
                      icon: Icon(
                        message.status == MessageSendStatus.failed
                            ? Icons.refresh_rounded
                            : Icons.schedule_rounded,
                      ),
                      label: Text(
                        message.status == MessageSendStatus.failed
                            ? '재시도'
                            : '전송 중',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              maxLength: ChatConstants.maxMessageLength,
              decoration: const InputDecoration(
                hintText: '메시지를 입력하세요',
                counterText: '',
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: '메시지 보내기',
            onPressed: onSend,
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    ),
  );
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.waving_hand_rounded, size: 48, color: AppColors.mango),
        SizedBox(height: 12),
        Text('첫 인사를 건네보세요!'),
      ],
    ),
  );
}
