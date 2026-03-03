import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';

import '../../controllers/menu_app_controller.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/error_handler.dart';
import '../../widgets/file_rename_dialog.dart';
import 'providers/v2_session_provider.dart';
import 'widgets/v2_chat_history_sidebar.dart';
import 'widgets/v2_chat_panel.dart';
import 'widgets/v2_knowledge_board.dart';

class GameDesignAssistantV2Screen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const GameDesignAssistantV2Screen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<GameDesignAssistantV2Screen> createState() =>
      _GameDesignAssistantV2ScreenState();
}

class _GameDesignAssistantV2ScreenState
    extends State<GameDesignAssistantV2Screen> {
  late final V2SessionProvider _provider;
  bool _showChatHistory = true;
  bool _isSavingToKb = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    final auth = context.read<AuthProvider>();
    _provider = V2SessionProvider(
      projectId: widget.projectId,
      projectName: widget.projectName,
      settingsProvider: settings,
      authProvider: auth,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.loadSessions();
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  String _getFileNameFromMarkdown(String markdownContent) {
    final headingPattern = RegExp(r'^#{1,6}\s+(.+)$', multiLine: true);
    final match = headingPattern.firstMatch(markdownContent);

    if (match != null) {
      var title = match.group(1)?.trim() ?? '';
      title = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      if (title.length > 50) title = '${title.substring(0, 47)}...';
      return title.isNotEmpty ? title : 'game_design_document';
    }

    final lines =
        markdownContent.split('\n').where((line) => line.trim().isNotEmpty);
    if (lines.isNotEmpty) {
      var firstLine = lines.first.trim();
      firstLine = firstLine.replaceAll(RegExp(r'^#{1,6}\s*'), '');
      firstLine = firstLine.replaceAll(RegExp(r'^\*+\s*'), '');
      firstLine = firstLine.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      if (firstLine.length > 50) firstLine = '${firstLine.substring(0, 47)}...';
      return firstLine.isNotEmpty ? firstLine : 'game_design_document';
    }

    return 'game_design_document';
  }

  Future<void> _saveDocumentToKnowledgeBase() async {
    final provider = _provider;
    final markdownContent = provider.gddContent;
    if (markdownContent == null || markdownContent.trim().isEmpty) return;

    try {
      final cleanFileName = _getFileNameFromMarkdown(markdownContent);
      final fileName = '$cleanFileName.md';
      final markdownBytes = Uint8List.fromList(utf8.encode(markdownContent));

      Directory? tempDir;
      File? tempFile;
      if (!kIsWeb) {
        tempDir = await Directory.systemTemp.createTemp('arcane_forge_docs');
        tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(markdownBytes);
      }

      final fileForDialog = PlatformFile(
        name: fileName,
        path: tempFile?.path,
        bytes: kIsWeb ? markdownBytes : null,
        size: markdownBytes.length,
      );

      if (!mounted) return;
      final fileNames = await showDialog<List<String>>(
        context: context,
        builder: (context) => FileRenameDialog(files: [fileForDialog]),
      );

      if (fileNames == null) {
        try {
          await tempFile?.delete();
          await tempDir?.delete();
        } catch (_) {}
        return;
      }

      final finalFileName = fileNames.first;

      setState(() {
        _isSavingToKb = true;
      });

      final success = await provider.uploadFileToKnowledgeBase(
        finalFileName,
        filePath: kIsWeb ? null : tempFile?.path,
        bytes: kIsWeb ? markdownBytes : null,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "$finalFileName" to knowledge base'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                if (!mounted) return;
                Provider.of<MenuAppController>(context, listen: false)
                    .changeScreen(ScreenType.knowledgeBase);
              },
            ),
          ),
        );
      } else if (!success) {
        throw Exception('Failed to upload file to server');
      }

      try {
        await tempFile?.delete();
        await tempDir?.delete();
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error saving document: ${ErrorHandler.getErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingToKb = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ChangeNotifierProvider<V2SessionProvider>.value(
      value: _provider,
      child: Consumer<V2SessionProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showChatHistory = !_showChatHistory;
                            });
                          },
                          tooltip: _showChatHistory
                              ? 'Hide Chat History'
                              : 'Show Chat History',
                          icon: Icon(
                            _showChatHistory ? Icons.menu_open : Icons.menu,
                            color: colorScheme.primary,
                          ),
                        ),
                        Icon(Icons.psychology_alt, color: colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Flexible(
                                    child: Text(
                                      'Game Design Assistant v2',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.blue.withOpacity(0.4)),
                                    ),
                                    child: const Text(
                                      'BETA',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.blue),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                widget.projectName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if ((provider.currentSession?.currentStage ?? '')
                            .isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              provider.currentSession!.currentStage!,
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        IconButton(
                          tooltip: 'Save to Knowledge Base',
                          onPressed:
                              (provider.gddContent?.trim().isNotEmpty ??
                                          false) &&
                                      !_isSavingToKb
                                  ? _saveDocumentToKnowledgeBase
                                  : null,
                          icon: const Icon(Icons.save_alt_rounded),
                        ),
                        IconButton(
                          tooltip: 'New Chat',
                          onPressed: () =>
                              context.read<V2SessionProvider>().startNewChat(),
                          icon: const Icon(Icons.add_comment),
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: () async {
                            final sessionProvider =
                                context.read<V2SessionProvider>();
                            await sessionProvider.loadSessions();
                            await sessionProvider.refreshData(
                                reloadHistory: true);
                          },
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        if (_showChatHistory) const V2ChatHistorySidebar(),
                        if (_showChatHistory) const VerticalDivider(width: 1),
                        const Expanded(
                          child: Row(
                            children: [
                              Expanded(flex: 4, child: V2ChatPanel()),
                              VerticalDivider(width: 1),
                              Expanded(flex: 6, child: V2KnowledgeBoard()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
