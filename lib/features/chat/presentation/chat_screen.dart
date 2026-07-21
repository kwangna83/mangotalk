import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/chat_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/input_validators.dart';
import '../../auth/domain/app_user.dart';
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
  final _composerFocus = FocusNode();
  final _scroll = ScrollController();
  final _imagePicker = ImagePicker();
  final _initialFocusKey = GlobalKey();
  bool _positionedAfterLoad = false;
  bool _loadingOlderForScroll = false;
  String? _latestMessageId;
  double _previousKeyboardHeight = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels < 120) {
        _loadOlderPreservingPosition();
      }
    });
  }

  Future<void> _loadOlderPreservingPosition() async {
    if (_loadingOlderForScroll || !_scroll.hasClients) return;
    _loadingOlderForScroll = true;
    final previousPixels = _scroll.position.pixels;
    final previousMaxScrollExtent = _scroll.position.maxScrollExtent;
    try {
      await ref.read(chatControllerProvider.notifier).loadOlder();
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scroll.hasClients) return;
      final addedExtent =
          _scroll.position.maxScrollExtent - previousMaxScrollExtent;
      if (addedExtent <= 0) return;
      _scroll.jumpTo(
        (previousPixels + addedExtent).clamp(
          _scroll.position.minScrollExtent,
          _scroll.position.maxScrollExtent,
        ),
      );
    } catch (_) {
      // The controller keeps existing messages when loading older fails.
    } finally {
      _loadingOlderForScroll = false;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    if (chat.isLoading) {
      _positionedAfterLoad = false;
      _latestMessageId = null;
    }
    final me = ref.watch(authControllerProvider).value;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _followKeyboardIfNeeded(keyboardHeight);
    final loadedChat = chat.value;
    if (loadedChat != null && loadedChat.messages.isNotEmpty) {
      _scheduleInitialFocus(hasUnread: loadedChat.firstUnreadMessageId != null);
    }
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AnimatedPadding(
        padding: EdgeInsets.only(bottom: keyboardHeight),
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Column(
          children: [
            _Header(
              user: me,
              onRefresh: () => ref.invalidate(chatControllerProvider),
              onEditProfile: me == null ? null : () => _editProfile(me),
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
                            : ListView(
                              controller: _scroll,
                              cacheExtent: 0,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                20,
                                16,
                                12,
                              ),
                              children: [
                                for (final message in value.messages)
                                  _messageItem(
                                    message: message,
                                    value: value,
                                    myUserId: me?.id,
                                  ),
                              ],
                            ),
              ),
            ),
            _Composer(
              controller: _text,
              focusNode: _composerFocus,
              onSend: _send,
              onPickImage: _pickImage,
            ),
          ],
        ),
      ),
    );
  }

  void _send() {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    ref.read(chatControllerProvider.notifier).send(body);
    _text.clear();
    _composerFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
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

  void _followKeyboardIfNeeded(double keyboardHeight) {
    final keyboardOpened = keyboardHeight > 0 && _previousKeyboardHeight == 0;
    final wasNearBottom =
        !_scroll.hasClients ||
        _scroll.position.maxScrollExtent - _scroll.position.pixels <= 120;
    _previousKeyboardHeight = keyboardHeight;
    if (!keyboardOpened || !wasNearBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || MediaQuery.viewInsetsOf(context).bottom == 0) return;
        _scrollToLatest();
      });
    });
  }

  Widget _messageItem({
    required ChatMessage message,
    required ChatState value,
    required String? myUserId,
  }) {
    if (message.id == value.messages.last.id) {
      _handleLatestMessage(message.id, isMine: message.senderId == myUserId);
    }
    final focusMessageId = value.firstUnreadMessageId ?? value.messages.last.id;
    final isInitialFocus = message.id == focusMessageId;
    return KeyedSubtree(
      key: isInitialFocus ? _initialFocusKey : null,
      child: Column(
        children: [
          if (message.id == value.firstUnreadMessageId)
            _UnreadDivider(count: value.unreadCount),
          _MessageBubble(
            message: message,
            isMine: message.senderId == myUserId,
            onRetry:
                () => ref.read(chatControllerProvider.notifier).retry(message),
          ),
        ],
      ),
    );
  }

  void _scheduleInitialFocus({required bool hasUnread}) {
    if (_positionedAfterLoad) return;
    _positionedAfterLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!hasUnread) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
        return;
      }
      final targetContext = _initialFocusKey.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        alignment: .08,
        duration: Duration.zero,
      );
    });
  }

  void _handleLatestMessage(String messageId, {required bool isMine}) {
    if (_latestMessageId == null) {
      _latestMessageId = messageId;
      return;
    }
    if (_latestMessageId == messageId) return;
    final shouldFollow =
        isMine ||
        !_scroll.hasClients ||
        _scroll.position.maxScrollExtent - _scroll.position.pixels <= 120;
    _latestMessageId = messageId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (shouldFollow) {
        _scrollToLatest();
      } else {
        _showNewMessageNotice();
      }
    });
  }

  void _scrollToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration:
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _showNewMessageNotice() {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('새 메시지가 도착했어요.'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(label: '보기', onPressed: _scrollToLatest),
        ),
      );
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

  Future<void> _editProfile(AppUser user) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ProfileDialog(user: user),
    );
    if (changed == true) ref.invalidate(chatControllerProvider);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.onRefresh,
    required this.onEditProfile,
    required this.onSignOut,
  });
  final AppUser? user;
  final VoidCallback onRefresh;
  final VoidCallback? onEditProfile;
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
        _Avatar(
          nickname: user?.nickname ?? 'M',
          imageUrl: user?.avatarUrl,
          radius: 22,
          backgroundColor: Colors.white,
          onTap:
              user?.avatarUrl == null
                  ? onEditProfile
                  : () => _showAvatarViewer(
                    context,
                    user!.avatarUrl!,
                    user!.nickname,
                  ),
          tooltip: user?.avatarUrl == null ? '내 프로필 수정' : '프로필 사진 크게 보기',
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
          tooltip: '내 프로필 수정',
          onPressed: onEditProfile,
          icon: const Icon(Icons.manage_accounts_rounded),
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

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.nickname,
    required this.imageUrl,
    required this.radius,
    required this.backgroundColor,
    this.onTap,
    this.tooltip,
  });

  final String nickname;
  final String? imageUrl;
  final double radius;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      foregroundImage: imageUrl == null ? null : NetworkImage(imageUrl!),
      child:
          imageUrl == null
              ? Text(nickname.characters.first.toUpperCase())
              : null,
    );
    if (onTap == null) return avatar;
    final button = Semantics(
      button: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: avatar,
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

Future<void> _showAvatarViewer(
  BuildContext context,
  String imageUrl,
  String nickname,
) => showDialog<void>(
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
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    semanticLabel: '$nickname의 프로필 사진',
                    errorBuilder: (_, _, _) => const _ImageError(),
                  ),
                ),
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

class _ProfileDialog extends ConsumerStatefulWidget {
  const _ProfileDialog({required this.user});
  final AppUser user;

  @override
  ConsumerState<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<_ProfileDialog> {
  static const _maxAvatarBytes = 5 * 1024 * 1024;
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _nickname;
  Uint8List? _avatarBytes;
  String? _avatarMimeType;
  bool _deleteAvatar = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(text: widget.user.nickname);
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('내 프로필'),
    content: Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _preview(),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _saving ? null : _pickAvatar,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    widget.user.avatarUrl == null ? '사진 등록' : '사진 변경',
                  ),
                ),
                if (widget.user.avatarUrl != null || _avatarBytes != null)
                  TextButton.icon(
                    onPressed: _saving ? null : _removeAvatar,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('사진 삭제'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nickname,
              maxLength: 20,
              decoration: const InputDecoration(labelText: '닉네임'),
              validator: InputValidators.nickname,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child:
            _saving
                ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Text('저장'),
      ),
    ],
  );

  Widget _preview() {
    final provider =
        _avatarBytes != null
            ? MemoryImage(_avatarBytes!) as ImageProvider
            : (!_deleteAvatar && widget.user.avatarUrl != null
                ? NetworkImage(widget.user.avatarUrl!)
                : null);
    return CircleAvatar(
      radius: 52,
      backgroundColor: AppColors.purple.withValues(alpha: .14),
      foregroundImage: provider,
      child:
          provider == null
              ? Text(
                _nickname.text.trim().isEmpty
                    ? '?'
                    : _nickname.text.trim().characters.first.toUpperCase(),
                style: const TextStyle(fontSize: 32),
              )
              : null,
    );
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final mimeType = _avatarMime(file);
    if (mimeType == null || bytes.isEmpty || bytes.length > _maxAvatarBytes) {
      _showError(
        mimeType == null
            ? 'JPEG, PNG, WebP 이미지만 사용할 수 있어요.'
            : '사진은 5MB 이하만 사용할 수 있어요.',
      );
      return;
    }
    setState(() {
      _avatarBytes = bytes;
      _avatarMimeType = mimeType;
      _deleteAvatar = false;
    });
  }

  void _removeAvatar() => setState(() {
    _avatarBytes = null;
    _avatarMimeType = null;
    _deleteAvatar = true;
  });

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _saving = true);
    final success = await ref
        .read(authControllerProvider.notifier)
        .updateProfile(
          nickname: _nickname.text,
          avatarBytes: _avatarBytes,
          avatarMimeType: _avatarMimeType,
          deleteAvatar: _deleteAvatar,
        );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
      _showError('프로필을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  String? _avatarMime(XFile file) {
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

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        const Expanded(child: Divider(color: AppColors.purple)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '새 메시지 $count개',
            style: const TextStyle(
              color: AppColors.purple,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.purple)),
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
            if (!isMine) ...[_messageAvatar(context), const SizedBox(width: 8)],
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
            if (isMine) ...[const SizedBox(width: 8), _messageAvatar(context)],
          ],
        ),
      ),
    ),
  );

  Widget _messageAvatar(BuildContext context) => _Avatar(
    radius: 16,
    nickname: message.senderNickname,
    imageUrl: message.senderAvatarUrl,
    backgroundColor: AppColors.purple.withValues(alpha: .14),
    onTap:
        message.senderAvatarUrl == null
            ? null
            : () => _showAvatarViewer(
              context,
              message.senderAvatarUrl!,
              message.senderNickname,
            ),
    tooltip: message.senderAvatarUrl == null ? null : '프로필 사진 크게 보기',
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
    required this.focusNode,
    required this.onSend,
    required this.onPickImage,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
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
              focusNode: focusNode,
              minLines: 1,
              maxLines: 5,
              maxLength: ChatConstants.maxMessageLength,
              textInputAction: TextInputAction.send,
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
