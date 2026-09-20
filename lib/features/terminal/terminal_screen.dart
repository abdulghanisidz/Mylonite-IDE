import 'package:flutter/material.dart';

import '../../ui/theme/app_theme.dart';

/// Terminal screen — interactive process I/O interface.
///
/// Phase 1: Shell with static placeholder output.
/// Phase 5: Wired to RuntimeManager / ProcessManager output streams.
/// Phase 7: Full interactive stdin, ANSI colour, scrollback.
///
/// Architecture: 04-RUNTIME-SYSTEM.md §9, FR-034–FR-042
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _stdinController = TextEditingController();
  final _scrollController = ScrollController();

  // Populated in initState after _OutputLine class is available
  late final List<_OutputLine> _placeholderOutput;

  @override
  void initState() {
    super.initState();
    _placeholderOutput = [
      _OutputLine(r'$ python3 main.py', color: AppColors.primary),
      _OutputLine('Hello, World!'),
      _OutputLine(''),
      _OutputLine('Process exited with code 0', color: AppColors.secondary),
    ];
  }

  @override
  void dispose() {
    _stdinController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal'),
        actions: [
          // Process status chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: const Text('IDLE'),
              labelStyle: const TextStyle(fontSize: 11),
              backgroundColor: AppColors.darkSurfaceVariant,
              side: const BorderSide(color: AppColors.darkBorder),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            tooltip: 'Stop process',
            color: AppColors.error,
            onPressed: null, // Phase 5/7
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear output',
            onPressed: null, // Phase 7
          ),
        ],
      ),
      body: Column(
        children: [
          // Output area
          Expanded(
            child: Container(
              color: AppColors.darkBackground,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _placeholderOutput.length,
                itemBuilder: (context, i) {
                  final line = _placeholderOutput[i];
                  return Text(
                    line.text,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                      color: line.color,
                      height: 1.6,
                    ),
                  );
                },
              ),
            ),
          ),

          // stdin input row
          const Divider(height: 1),
          _StdinInputBar(controller: _stdinController),
        ],
      ),
    );
  }
}

class _OutputLine {
  const _OutputLine(this.text, {this.color = AppColors.editorForeground});
  final String text;
  final Color color;
}

class _StdinInputBar extends StatelessWidget {
  const _StdinInputBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkSurface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text(
            '>',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              color: AppColors.primary,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                color: AppColors.editorForeground,
              ),
              decoration: const InputDecoration(
                hintText: 'Send input to process...',
                hintStyle: TextStyle(color: Color(0xFF555555), fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: null, // Phase 7: write to process stdin
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, size: 18),
            color: AppColors.primary,
            onPressed: null, // Phase 7
          ),
        ],
      ),
    );
  }
}
