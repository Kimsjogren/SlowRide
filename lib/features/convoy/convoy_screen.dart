import 'package:flutter/material.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/features/auth/login_screen.dart';
import 'package:slowride/features/auth/register_screen.dart';
import 'package:slowride/features/convoy/convoy_controller.dart';
import 'package:slowride/features/convoy/convoy_room_screen.dart';
import 'package:slowride/models/convoy_model.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/widgets/app_background.dart';

class ConvoyScreen extends StatefulWidget {
  const ConvoyScreen({super.key});

  @override
  State<ConvoyScreen> createState() => _ConvoyScreenState();
}

class _ConvoyScreenState extends State<ConvoyScreen> {
  final ConvoyController _controller = ConvoyController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _signInEmailController = TextEditingController();
  final TextEditingController _signInCodeController = TextEditingController();
  bool _showOnlyMyConvoys = false;

  @override
  void dispose() {
    _nameController.dispose();
    _signInEmailController.dispose();
    _signInCodeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showCreateDialog(AppLocalizations l10n) async {
    _nameController.text = '';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.convoyNameDialogTitle),
          content: TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.convoyNameFieldLabel,
              hintText: l10n.convoyNameHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.convoyCreateCancel),
            ),
            FilledButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                await _controller.createConvoy(name: name);
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
              },
              child: Text(l10n.convoyCreateConfirm),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = AuthService.instance;

    return AppBackground(
      child: ValueListenableBuilder<bool>(
        valueListenable: authService.isLoggedIn,
        builder: (context, isLoggedIn, _) {
          if (!isLoggedIn) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.groups, size: 36, color: Colors.white70),
                      const SizedBox(height: 16),
                      Text(
                        l10n.convoyRequiresSignInTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.convoyRequiresSignInSubtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: () async {
                              await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.login),
                            label: Text(l10n.signIn),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_add_alt_1),
                            label: Text(l10n.signUp),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.convoyModeTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.convoyModeSubtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => _showCreateDialog(l10n),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.convoyCreateButton),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text(l10n.convoyFilterAll),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text(l10n.convoyFilterMine),
                    ),
                  ],
                  selected: <bool>{_showOnlyMyConvoys},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _showOnlyMyConvoys = selection.first;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (!authService.supportsRealtimeBackend)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    l10n.convoyRealtimeBackendMissing,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<ConvoyModel>>(
                  stream: _controller.watchConvoys(),
                  builder: (context, snapshot) {
                    final allConvoys = snapshot.data ?? const [];
                    final convoys = _showOnlyMyConvoys
                        ? allConvoys
                              .where((convoy) => convoy.isJoined)
                              .toList(growable: false)
                        : allConvoys;

                    if (convoys.isEmpty) {
                      return Center(
                        child: Text(
                          _showOnlyMyConvoys
                              ? l10n.convoyListEmptyMine
                              : l10n.convoyListEmpty,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: convoys.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final convoy = convoys[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      convoy.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${l10n.convoyCreatedBy(convoy.leaderId)} • ${l10n.convoyMembers(convoy.memberCount)}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.55,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton(
                                onPressed: () async {
                                  if (convoy.isJoined) {
                                    if (!convoy.isJoined) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.convoyJoinFirstHint,
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            ConvoyRoomScreen(convoy: convoy),
                                      ),
                                    );
                                    return;
                                  }
                                  await _controller.joinConvoy(convoy: convoy);
                                },
                                child: Text(
                                  convoy.isJoined
                                      ? l10n.convoyLeaveButton
                                      : l10n.convoyJoinButton,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
