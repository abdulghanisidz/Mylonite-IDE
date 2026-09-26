import 'dart:async';

import 'package:flutter/material.dart';

import '../../platform/channels/process_channel.dart';

/// ProcessTestScreen — Test harness for Phase 4 execution engine.
///
/// This screen provides a simple UI to test process spawning, output streaming,
/// stdin relay, and termination. Used for verification before building the
/// full RuntimeManager and Terminal UI.
///
/// Test scenarios:
/// 1. Echo test: sh -c "echo 'Hello, World!'" → stdout
/// 2. Error test: sh -c "echo 'Error!' >&2" → stderr
/// 3. Exit code test: sh -c "exit 42" → exit code 42
/// 4. Multi-line output: sh -c "for i in 1 2 3; do echo Line $i; sleep 0.5; done"
/// 5. Timeout test: sh -c "sleep 100" with 5s timeout → timeout
/// 6. Stdin test: cat (write lines to stdin, cat echoes them back)
///
/// Remove this file after Phase 4 testing is complete.
class ProcessTestScreen extends StatefulWidget {
  const ProcessTestScreen({super.key});

  @override
  State<ProcessTestScreen> createState() => _ProcessTestScreenState();
}

class _ProcessTestScreenState extends State<ProcessTestScreen> {
  final _processChannel = ProcessChannel.instance;
  final _outputController = TextEditingController();
  final _stdinController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<ProcessOutputEvent>? _outputSubscription;
  ProcessHandle? _currentProcess;
  bool _isRunning = false;

  final List<String> _outputLines = [];

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    _outputController.dispose();
    _stdinController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startListening() {
    _outputSubscription = _processChannel.outputStream.listen(
      (event) {
        setState(() {
          if (event.isOutput) {
            final prefix = event.type == ProcessOutputType.stderr
                ? '[ERR] '
                : '';
            _outputLines.add('$prefix${event.content}');
          } else if (event.isExit) {
            final flags = <String>[];
            if (event.timedOut) flags.add('TIMEOUT');
            if (event.oomKilled) flags.add('OOM');
            final flagStr = flags.isEmpty ? '' : ' (${flags.join(', ')})';
            _outputLines.add('');
            _outputLines.add('Process exited: code=${event.exitCode}$flagStr');
            _isRunning = false;
            _currentProcess = null;
          }
        });
        _scrollToBottom();
      },
      onError: (error) {
        _addOutput('ERROR: $error');
      },
    );
  }

  void _addOutput(String line) {
    setState(() {
      _outputLines.add(line);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _runCommand(List<String> argv, {int timeout = 30}) async {
    if (_isRunning) {
      _addOutput('ERROR: A process is already running');
      return;
    }

    setState(() {
      _isRunning = true;
      _outputLines.clear();
    });

    _addOutput('Running: ${argv.join(' ')}');
    _addOutput('');

    try {
      final handle = await _processChannel.spawnProcess(
        argv: argv,
        workingDirectory: '/data/data/com.offlinemobileide.aioide',
        timeoutSeconds: timeout,
      );

      setState(() {
        _currentProcess = handle;
      });

      _addOutput(
        'Process started: sessionId=${handle.sessionId}, pid=${handle.pid}',
      );
      _addOutput('');
    } catch (e) {
      _addOutput('SPAWN FAILED: $e');
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _terminateProcess() async {
    if (_currentProcess == null) {
      _addOutput('ERROR: No process running');
      return;
    }

    _addOutput('');
    _addOutput('Terminating process...');

    try {
      final success = await _processChannel.terminateProcess(
        _currentProcess!.sessionId,
      );
      _addOutput(success ? 'Terminate signal sent' : 'Terminate failed');
    } catch (e) {
      _addOutput('TERMINATE ERROR: $e');
    }
  }

  Future<void> _writeStdin() async {
    if (_currentProcess == null) {
      _addOutput('ERROR: No process running');
      return;
    }

    final data = _stdinController.text;
    if (data.isEmpty) return;

    try {
      final success = await _processChannel.writeStdin(
        _currentProcess!.sessionId,
        '$data\n',
      );
      _addOutput('[IN] $data');
      if (!success) {
        _addOutput('WARNING: writeStdin returned false');
      }
      _stdinController.clear();
    } catch (e) {
      _addOutput('STDIN ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Process Test'),
        actions: [
          if (_isRunning)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _terminateProcess,
              tooltip: 'Terminate',
            ),
        ],
      ),
      body: Column(
        children: [
          // Test buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isRunning
                      ? null
                      : () => _runCommand(['sh', '-c', 'echo "Hello, World!"']),
                  child: const Text('Echo Test'),
                ),
                ElevatedButton(
                  onPressed: _isRunning
                      ? null
                      : () => _runCommand(['sh', '-c', 'echo "Error!" >&2']),
                  child: const Text('Stderr Test'),
                ),
                ElevatedButton(
                  onPressed: _isRunning
                      ? null
                      : () => _runCommand(['sh', '-c', 'exit 42']),
                  child: const Text('Exit Code'),
                ),
                ElevatedButton(
                  onPressed: _isRunning
                      ? null
                      : () => _runCommand([
                          'sh',
                          '-c',
                          r'for i in 1 2 3 4 5; do echo Line $i; sleep 0.5; done',
                        ]),
                  child: const Text('Multi-line'),
                ),
                ElevatedButton(
                  onPressed: _isRunning
                      ? null
                      : () =>
                            _runCommand(['sh', '-c', 'sleep 100'], timeout: 5),
                  child: const Text('Timeout (5s)'),
                ),
                ElevatedButton(
                  onPressed: _isRunning ? null : () => _runCommand(['cat']),
                  child: const Text('Cat (stdin)'),
                ),
              ],
            ),
          ),

          const Divider(),

          // Output area
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(12),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _outputLines.length,
                itemBuilder: (context, index) {
                  final line = _outputLines[index];
                  final isError = line.startsWith('[ERR]');
                  final isInput = line.startsWith('[IN]');
                  final isSystem =
                      line.startsWith('Process') ||
                      line.startsWith('Running') ||
                      line.startsWith('Terminate');

                  Color textColor = Colors.white;
                  if (isError) textColor = Colors.red;
                  if (isInput) textColor = Colors.cyan;
                  if (isSystem) textColor = Colors.grey;

                  return Text(
                    line,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: textColor,
                    ),
                  );
                },
              ),
            ),
          ),

          // Stdin input
          if (_isRunning && _currentProcess != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(top: BorderSide(color: Colors.grey[700]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stdinController,
                      style: const TextStyle(fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText: 'Type input and press Enter...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _writeStdin(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _writeStdin,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
