import 'dart:async';

import 'package:flutter/material.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/models/support_message.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/services/support_chat_service.dart';
import 'package:slowride/widgets/app_background.dart';

const _chatPanelBlue = Color(0xF20A1F63);
const _chatChromeBlue = Color(0xE612429E);

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _sending = true);
    try {
      await SupportChatService.instance.sendMessage(
        body: message,
        languageCode: Localizations.localeOf(context).languageCode,
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.supportChatSendFailed)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppBackground(
      logoAsset: 'assets/CruizX_support_transparent.png',
      logoHeight: 170,
      centerLogo: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          forceMaterialTransparency: true,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Colors.white,
          title: Text(l10n.supportChatTitle),
        ),
        body: ValueListenableBuilder<bool>(
          valueListenable: AuthService.instance.isLoggedIn,
          builder: (context, loggedIn, _) {
            final chat = SupportChatService.instance;
            if (!chat.isAvailable) {
              return _SupportUnavailable(l10n: l10n);
            }
            return Column(
              children: [
                _ResponseTimeBanner(l10n: l10n),
                if (chat.isGuest) _GuestBanner(l10n: l10n),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    decoration: BoxDecoration(
                      color: _chatPanelBlue,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0x663AA8FF)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: StreamBuilder<List<SupportMessage>>(
                      key: ValueKey<bool>(loggedIn),
                      stream: chat.watchMessages(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                l10n.supportChatUnavailable,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF3AA8FF),
                            ),
                          );
                        }

                        final messages = snapshot.data!;
                        unawaited(
                          SupportChatService.instance.markSupportMessagesRead(),
                        );
                        _scrollToBottom();
                        if (messages.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(30),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.support_agent,
                                    color: Color(0xFF66D9FF),
                                    size: 48,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    l10n.supportChatWelcome,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                          itemCount: messages.length,
                          itemBuilder: (context, index) => _MessageBubble(
                            message: messages[index],
                            l10n: l10n,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                _MessageComposer(
                  controller: _messageController,
                  sending: _sending,
                  onSend: _send,
                  l10n: l10n,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ResponseTimeBanner extends StatelessWidget {
  const _ResponseTimeBanner({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: l10n.supportChatReplyTime,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.circle, color: Color(0xFF28C76F), size: 9),
            const SizedBox(width: 8),
            Text(
              l10n.supportChatReplyTime,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestBanner extends StatelessWidget {
  const _GuestBanner({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: _chatChromeBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x993AA8FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF66D9FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.supportChatGuestNotice,
              style: const TextStyle(color: Colors.white, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportUnavailable extends StatelessWidget {
  const _SupportUnavailable({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Color(0xFF66D9FF)),
            const SizedBox(height: 16),
            Text(
              l10n.supportChatUnavailable,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.l10n});

  final SupportMessage message;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final fromSupport = message.isFromSupport;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(message.createdAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final sender = fromSupport ? l10n.supportChatTeam : l10n.supportChatYou;

    return Semantics(
      label: '$sender, ${message.body}, $time',
      child: Align(
        alignment: fromSupport ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 310),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(13, 10, 13, 7),
          decoration: BoxDecoration(
            color: fromSupport ? const Color(0xFF10275A) : null,
            gradient: fromSupport
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF1554DB), Color(0xFF1E6BFF)],
                  ),
            border: Border.all(
              color: fromSupport
                  ? const Color(0x663AA8FF)
                  : const Color(0x883AA8FF),
            ),
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomLeft: fromSupport ? const Radius.circular(4) : null,
              bottomRight: fromSupport ? null : const Radius.circular(4),
            ),
          ),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sender,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message.body,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.l10n,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: const BoxDecoration(
          color: _chatChromeBlue,
          border: Border(top: BorderSide(color: Color(0x663AA8FF))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: l10n.supportChatMessageHint,
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: _chatPanelBlue,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0x663AA8FF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: Color(0xFF3AA8FF),
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: l10n.supportChatSend,
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
