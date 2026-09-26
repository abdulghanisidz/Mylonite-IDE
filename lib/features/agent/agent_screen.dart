import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/agent_task.dart';
import '../../core/models/enums.dart';
import '../../core/services/agent/agent_service.dart';
import '../../core/services/ai/inference_service.dart';
import '../../core/services/logging_service.dart';
import '../../core/services/runtime/python_runtime.dart';
import '../../ui/theme/app_theme.dart';

/// AI Agent screen — the primary interface for the autonomous agent.
///
/// Phase 1: Shell with static placeholder conversation.
/// Phase 9: Integrated with InferenceService for AI code generation. ✅ DONE
/// Phase 11: Full AgentLoop integration with SENSE→DECIDE→ACT→CHECK→RECOVER. ✅ DONE
///
/// Architecture: 03-AI-AGENT.md §2, FR-056–FR-075
class AgentScreen extends ConsumerStatefulWidget {
  const AgentScreen({super.key});

  @override
  ConsumerState<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends ConsumerState<AgentScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inferenceService = InferenceService.instance;
  final _pythonRuntime = PythonRuntime.instance;

  late final AgentService _agentService;
  StreamSubscription<AgentTask>? _taskSubscription;

  AgentSessionStatus _status = AgentSessionStatus.idle;
  final List<_ChatMessage> _messages = [];
  AgentTask? _currentTask;

  @override
  void initState() {
    super.initState();
    _initializeAgent();
  }

  Future<void> _initializeAgent() async {
    await _inferenceService.initialize();

    // Initialize AgentService
    _agentService = AgentService(
      inferenceService: _inferenceService,
      pythonRuntime: _pythonRuntime,
    );

    // Listen to task updates
    _taskSubscription = _agentService.taskUpdates.listen(_handleTaskUpdate);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _taskSubscription?.cancel();
    _agentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modelName = _inferenceService.currentModel?.name ?? 'No model';
    final isModelLoaded = _inferenceService.isModelLoaded;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Agent'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              avatar: Icon(
                isModelLoaded ? Icons.check_circle : Icons.memory,
                size: 14,
                color: isModelLoaded ? Colors.green : null,
              ),
              label: Text(
                'Local · $modelName',
                style: const TextStyle(fontSize: 11),
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
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear conversation',
            onPressed: _messages.isEmpty
                ? null
                : () {
                    setState(() {
                      _messages.clear();
                    });
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_status.isActive) _AgentStatusBanner(status: _status),

          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(isModelLoaded)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) =>
                        _MessageBubble(message: _messages[i]),
                  ),
          ),

          const Divider(height: 1),
          _AgentInputBar(
            controller: _inputController,
            isAgentActive: _status.isActive,
            isModelLoaded: isModelLoaded,
            onSubmit: _handleUserMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isModelLoaded) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy_outlined, size: 64, color: AppColors.darkBorder),
          const SizedBox(height: 16),
          Text(
            'AI Agent',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.editorForeground,
            ),
          ),
          const SizedBox(height: 8),
          if (!isModelLoaded) ...[
            Text(
              'No model loaded',
              style: TextStyle(fontSize: 14, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Go to Model Manager'),
              onPressed: () {
                // Navigate to model manager (index 3)
                DefaultTabController.of(context).animateTo(3);
              },
            ),
          ] else ...[
            Text(
              'Ready to help with Python coding',
              style: TextStyle(fontSize: 14, color: AppColors.secondary),
            ),
            const SizedBox(height: 24),
            Text(
              'Try asking:',
              style: TextStyle(fontSize: 12, color: AppColors.darkBorder),
            ),
            const SizedBox(height: 8),
            ...[
              'Write a fibonacci function',
              'Create a calculator program',
              'Write a bubble sort algorithm',
            ].map(
              (example) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: OutlinedButton(
                  onPressed: () {
                    _inputController.text = example;
                    _handleUserMessage(example);
                  },
                  child: Text(example),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Handle user message submission with autonomous agent loop.
  Future<void> _handleUserMessage(String message) async {
    if (message.trim().isEmpty) return;

    if (!_inferenceService.isModelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please load a model first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Add user message to chat
    setState(() {
      _messages.add(
        _ChatMessage(
          role: MessageRole.user,
          content: message,
          isUserMessage: true,
        ),
      );
      _status = AgentSessionStatus.analyzing;
    });

    // Auto-scroll
    _autoScroll();

    try {
      log.info(LogSubsystem.ai, 'Starting autonomous agent task: $message');

      // Create autonomous agent task
      final taskId = await _agentService.executeTask(
        userRequest: message,
        maxRetries: 3,
      );

      _currentTask = _agentService.getTask(taskId);

      // Add task tracking message
      setState(() {
        _messages.add(
          _ChatMessage(
            role: MessageRole.assistant,
            content: '🤖 Agent task started...',
            isSystemMessage: true,
            task: _currentTask,
          ),
        );
      });

      _autoScroll();
    } catch (e) {
      log.error(LogSubsystem.ai, 'Agent error: $e');

      setState(() {
        _messages.add(
          _ChatMessage(
            role: MessageRole.assistant,
            content: '❌ Error: $e\n\nPlease try again.',
            isSystemMessage: true,
          ),
        );
        _status = AgentSessionStatus.error;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _status = AgentSessionStatus.idle;
          });
        }
      });
    }
  }

  /// Handle task updates from AgentService.
  void _handleTaskUpdate(AgentTask task) {
    if (!mounted) return;

    setState(() {
      _currentTask = task;

      // Update status based on task status
      _status = _mapTaskStatusToSessionStatus(task.status);

      // Update the task tracking message
      final taskMessageIndex = _messages.indexWhere(
        (msg) => msg.task?.id == task.id,
      );

      if (taskMessageIndex != -1) {
        _messages[taskMessageIndex] = _ChatMessage(
          role: MessageRole.assistant,
          content: _buildTaskProgressMessage(task),
          isSystemMessage: true,
          task: task,
        );
      }

      // If task completed, add final code
      if (task.isTerminal && task.latestVersion != null) {
        // Remove task tracking message
        _messages.removeWhere((msg) => msg.task?.id == task.id);

        // Add final result
        _messages.add(
          _ChatMessage(
            role: MessageRole.assistant,
            content: _buildFinalMessage(task),
            isSystemMessage: false,
            task: task,
          ),
        );

        _status = task.isSuccessful
            ? AgentSessionStatus.idle
            : AgentSessionStatus.error;
      }
    });

    _autoScroll();
  }

  /// Build progress message for task.
  String _buildTaskProgressMessage(AgentTask task) {
    final buffer = StringBuffer();
    buffer.writeln('🤖 **Autonomous Agent**');
    buffer.writeln();
    buffer.writeln('**Status:** ${task.statusText}');
    buffer.writeln('**Attempt:** ${task.retryCount + 1} / ${task.maxRetries}');
    buffer.writeln('**Elapsed:** ${task.elapsed.inSeconds}s');
    buffer.writeln();

    if (task.loopMessages.isNotEmpty) {
      buffer.writeln('**Progress:**');
      // Show last 5 messages
      final recentMessages = task.loopMessages.length > 5
          ? task.loopMessages.sublist(task.loopMessages.length - 5)
          : task.loopMessages;

      for (final msg in recentMessages) {
        buffer.writeln('• ${msg.split('] ').last}');
      }
    }

    return buffer.toString();
  }

  /// Build final message with results.
  String _buildFinalMessage(AgentTask task) {
    final buffer = StringBuffer();

    if (task.isSuccessful) {
      buffer.writeln('✅ **Task Completed Successfully!**');
      buffer.writeln();

      final version = task.successfulVersion;
      if (version != null) {
        buffer.writeln('**Generated Code:**');
        buffer.writeln('```python');
        buffer.writeln(version.code);
        buffer.writeln('```');
        buffer.writeln();

        if (version.executionResult != null) {
          buffer.writeln('**Execution Result:**');
          buffer.writeln('Exit code: ${version.executionResult!.exitCode}');

          if (version.executionResult!.stdout.isNotEmpty) {
            buffer.writeln();
            buffer.writeln('**Output:**');
            buffer.writeln('```');
            buffer.writeln(version.executionResult!.stdout);
            buffer.writeln('```');
          }
        }

        buffer.writeln();
        buffer.writeln('⏱️ Completed in ${task.elapsed.inSeconds}s');
        if (task.codeVersions.length > 1) {
          buffer.writeln('🔄 Required ${task.codeVersions.length} iterations');
        }
      }
    } else {
      buffer.writeln('❌ **Task Failed**');
      buffer.writeln();
      buffer.writeln(task.resultMessage ?? 'Unknown error');
      buffer.writeln();

      if (task.latestVersion != null) {
        buffer.writeln('**Last Attempt:**');
        buffer.writeln('```python');
        buffer.writeln(task.latestVersion!.code);
        buffer.writeln('```');

        if (task.latestVersion!.executionResult != null) {
          buffer.writeln();
          buffer.writeln('**Error:**');
          buffer.writeln('```');
          buffer.writeln(task.latestVersion!.executionResult!.stderr);
          buffer.writeln('```');
        }
      }

      buffer.writeln();
      buffer.writeln('⏱️ Failed after ${task.elapsed.inSeconds}s');
      buffer.writeln('🔄 Tried ${task.codeVersions.length} iteration(s)');
    }

    return buffer.toString();
  }

  /// Map AgentTaskStatus to AgentSessionStatus.
  AgentSessionStatus _mapTaskStatusToSessionStatus(AgentTaskStatus taskStatus) {
    switch (taskStatus) {
      case AgentTaskStatus.pending:
        return AgentSessionStatus.idle;
      case AgentTaskStatus.sensing:
        return AgentSessionStatus.analyzing;
      case AgentTaskStatus.deciding:
        return AgentSessionStatus.planning;
      case AgentTaskStatus.generating:
        return AgentSessionStatus.acting;
      case AgentTaskStatus.executing:
        return AgentSessionStatus.observing;
      case AgentTaskStatus.validating:
        return AgentSessionStatus.evaluating;
      case AgentTaskStatus.analyzing:
        return AgentSessionStatus.evaluating;
      case AgentTaskStatus.fixing:
        return AgentSessionStatus.fixing;
      case AgentTaskStatus.completed:
        return AgentSessionStatus.idle;
      case AgentTaskStatus.failed:
        return AgentSessionStatus.error;
      case AgentTaskStatus.cancelled:
        return AgentSessionStatus.cancelled;
    }
  }

  /// Auto-scroll to bottom.
  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
      AgentSessionStatus.analyzing => 'Analyzing request...',
      AgentSessionStatus.planning => 'Planning approach...',
      AgentSessionStatus.acting => 'Generating code...',
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
  const _ChatMessage({
    required this.role,
    required this.content,
    this.isUserMessage = false,
    this.isSystemMessage = false,
    this.task,
  });

  final MessageRole role;
  final String content;
  final bool isUserMessage;
  final bool isSystemMessage;
  final AgentTask? task;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final isSystem = message.isSystemMessage;

    // System messages (task progress) - full width with special styling
    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: message.task?.isTerminal == true
                  ? (message.task!.isSuccessful
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3))
                  : AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.task != null && !message.task!.isTerminal)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Processing...',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              SelectableText(
                message.content,
                style: TextStyle(
                  color: AppColors.editorForeground,
                  fontSize: 12,
                  height: 1.5,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Regular user/assistant messages
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
              child: SelectableText(
                message.content,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.editorForeground,
                  fontSize: 13,
                  height: 1.5,
                  fontFamily: message.content.contains('```')
                      ? 'JetBrains Mono'
                      : null,
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
    required this.isModelLoaded,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isAgentActive;
  final bool isModelLoaded;
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
              enabled: !isAgentActive && isModelLoaded,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: isAgentActive
                    ? 'Agent is working...'
                    : !isModelLoaded
                    ? 'Load a model first...'
                    : 'Ask the agent to write code...',
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
              onSubmitted: isAgentActive || !isModelLoaded ? null : onSubmit,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.send),
            color: AppColors.primary,
            onPressed: isAgentActive || !isModelLoaded
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
