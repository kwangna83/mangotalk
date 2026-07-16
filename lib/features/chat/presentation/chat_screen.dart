import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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
  static const _maxImageBytes = 10 * 1024 * 1024;
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _imagePicker = ImagePicker();

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
            onRefresh: () => ref.invalidate(chatControllerProvider),
            onSignOut:
                () => ref.read(authControllerProvider.notifier).signOut(),
          ),
          Expanded(
            child: chat.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (_, _) => Center(
                    child: FilledButton(
                      onPressed: () => ref.invalidate(chatControllerProvider),
                      child: const Text('다시 연결하기'),
                    ),
                  ),
              data:
                  (value) =>
                      value.messages.isEmpty
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
                                onRetry:
                                    () => ref
                                        .read(chatControllerProvider.notifier)
                                        .retry(message),
                              );
                            },
                          ),
            ),
          ),
          _Composer(controller: _text, onSend: _send, onPickImage: _pickImage),
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
          duration:
              MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final mimeType = _imageMimeType(file);
    if (mimeType == null) {
      _showImageError('JPEG, PNG, WebP 이미지만 올릴 수 있어요.');
      return;
    }
    if (bytes.isEmpty || bytes.length > _maxImageBytes) {
      _showImageError('이미지는 10MB 이하만 올릴 수 있어요.');
      return;
    }
    await ref
        .read(chatControllerProvider.notifier)
        .sendImage(bytes: bytes, fileName: file.name, mimeType: mimeType);
  }

  String? _imageMimeType(XFile file) {
    final declared = file.mimeType?.toLowerCase();
    if (const {'image/jpeg', 'image/png', 'image/webp'}.contains(declared)) {
      return declared;
    }
    final name = file.name.toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return null;
  }

  void _showImageError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh, required this.onSignOut});
  final VoidCallback onRefresh;
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
          tooltip: '채팅 새로고침',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
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
    label:
        message.type == ChatMessageType.image
            ? '${message.senderNickname}의 이미지 메시지'
            : '${message.senderNickname}의 메시지: ${message.body}',
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
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                    padding:
                        message.type == ChatMessageType.image
                            ? const EdgeInsets.all(4)
                            : const EdgeInsets.symmetric(
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
                    child:
                        message.type == ChatMessageType.image
                            ? _MessageImage(message: message)
                            : Text(
                              message.body,
                              style: TextStyle(
                                color: isMine ? Colors.white : AppColors.ink,
                              ),
                            ),
                  ),
                  if (message.status != MessageSendStatus.sent)
                    TextButton.icon(
                      onPressed:
                          message.status == MessageSendStatus.failed
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

class _MessageImage extends StatelessWidget {
  const _MessageImage({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '크게 보기',
      child: Semantics(
        button: true,
        label: '이미지 크게 보기',
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap:
              message.localImageBytes != null || message.imageUrl != null
                  ? () => _showImageViewer(context)
                  : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 120,
                maxWidth: 260,
                minHeight: 80,
                maxHeight: 320,
              ),
              child: _image(fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _image({required BoxFit fit}) {
    final bytes = message.localImageBytes;
    final imageUrl = message.imageUrl;
    if (bytes != null) return Image.memory(bytes, fit: fit);
    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: fit,
        loadingBuilder:
            (context, child, progress) =>
                progress == null
                    ? child
                    : const SizedBox(
                      width: 120,
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    ),
        errorBuilder:
            (_, _, _) =>
                const SizedBox(width: 240, height: 160, child: _ImageError()),
      );
    }
    return const SizedBox(width: 240, height: 160, child: _ImageError());
  }

  Future<void> _showImageViewer(BuildContext context) => showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .92),
    builder:
        (context) => Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: .5,
                  maxScale: 5,
                  child: Center(child: _image(fit: BoxFit.contain)),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                right: 12,
                child: IconButton.filledTonal(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
  );
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFF1ECFF),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: AppColors.purple),
          SizedBox(height: 6),
          Text('이미지를 불러올 수 없어요'),
        ],
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onPickImage,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: '이미지 올리기',
            onPressed: onPickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
          const SizedBox(width: 4),
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
