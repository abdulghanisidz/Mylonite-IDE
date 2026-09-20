import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../ui/theme/app_theme.dart';

/// AI Agent screen — the primary interface for the autonomous agent.
///
/// Phase 1: Shell with static placeholder conversation.
/// Phase 11: Full AgentLoop integration.
///
/// Architecture: 03-AI-AGENT.md §2, FR-056–FR-075
class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  AgentSessionStatus _status = AgentSessionStatus.idle;

  static const _placeholderMessages = [
    _ChatMessage(
      role: MessageRole.user,
      content:
          'Create a simple calculator with add, subtract, multiply, divide.',
    ),
    _ChatMessage(
      role: MessageRole.assistant,
      content:
          'I\'ll create a calculator in main.py.\n\n'
          '✓ Inspected project structure\n'
          '✓ Created main.py with calculator functions\n'
          '✓ Ran main.py → exit code 0\n\n'
          'Task complete.',
    ),
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Agent'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              avatar: const Icon(Icons.memory, size: 14),
              label: const Text(
                'Local · No model',
                style: TextStyle(fontSize: 11),
              ),
              backgroundColor: AppColors.darkSurfaceVariant,
              side: const BorderSide(color: AppColors.darkBorder),
            ),
          ),
          if (_status.isActive)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              tooltip: 'Stop agent',
              color: AppColors.error,
              onPressed: () =>
                  setState(() => _status = AgentSessionStatus.cancelled),
            ),
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'Session history',
            onPressed: null,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_status.isActive) _AgentStatusBanner(status: _status),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _placeholderMessages.length,
              itemBuilder: (context, i) =>
                  _MessageBubble(message: _placeholderMessages[i]),
            ),
          ),
          const Divider(height: 1),
          _AgentInputBar(
            controller: _inputController,
            isAgentActive: _status.isActive,
            onSubmit: (_) {},
          ),
        ],
      ),
    );
  }
}

class _AgentStatusBanner extends StatelessWidget {
  const _AgentStatusBanner({required this.status});
  final AgentSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AgentSessionStatus.waitingConfirmation => AppColors.warning,
      AgentSessionStatus.error => AppColors.error,
      _ => AppColors.primary,
    };
    final label = switch (status) {
      AgentSessionStatus.analyzing => 'Analyzing project...',
      AgentSessionStatus.planning => 'Planning steps...',
      AgentSessionStatus.acting => 'Executing tools...',
      AgentSessionStatus.waitingConfirmation => 'Waiting for confirmation',
      AgentSessionStatus.observing => 'Reading results...',
      AgentSessionStatus.evaluating => 'Evaluating...',
      AgentSessionStatus.fixing => 'Fixing error...',
      AgentSessionStatus.validating => 'Validating...',
      _ => 'Working...',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.15),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.role, required this.content});
  final MessageRole role;
  final String content;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: const Icon(
                Icons.memory,
                size: 14,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isUser ? 12 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 12),
                ),
              ),
              child: Text(
                message.content,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.editorForeground,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withValues(alpha: 0.3),
              child: const Icon(
                Icons.person,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgentInputBar extends StatelessWidget {
  const _AgentInputBar({
    required this.controller,
    required this.isAgentActive,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isAgentActive;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isAgentActive,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: isAgentActive
                    ? 'Agent is working...'
                    : 'Ask the agent anything...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.4),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
              ),
              onSubmitted: isAgentActive ? null : onSubmit,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.send),
            color: AppColors.primary,
            onPressed: isAgentActive
                ? null
                : () {
                    if (controller.text.trim().isNotEmpty) {
                      onSubmit(controller.text.trim());
                      controller.clear();
                    }
                  },
          ),
        ],
      ),
    );
  }
}
