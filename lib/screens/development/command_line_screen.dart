import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CommandLineScreen extends StatefulWidget {
  const CommandLineScreen({super.key});

  @override
  State<CommandLineScreen> createState() => _CommandLineScreenState();
}

class _CommandLineScreenState extends State<CommandLineScreen> {
  final String command = 'python -m http.server -b 127.0.0.1 8081';
  final int portNumber = 8083;

  final List<String> _output = []; // Store the output from the command line
  Process? _serverProcess;

  StreamSubscription<String>? _outputSubscription;

  @override
  void initState() {
    super.initState();
    startWebUI(); // Start the server on initialization
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        primary: false,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Command Line Output:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Container(
              height: 300,
              width: double.infinity,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _output.join('\n'),
                  style:
                      TextStyle(color: Colors.greenAccent, fontFamily: 'Courier'),
                ),
              ),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Open the URL in the default browser
                    openWebPage('http://127.0.0.1:$portNumber');
                  },
                  child: Text("Open Web UI"),
                ),
                ElevatedButton(
                  onPressed: () {
                    stopWebUI();
                  },
                  child: Text("Stop Server"),
                ),
                ElevatedButton(
                  onPressed: () {
                    restartWebUI();
                  },
                  child: Text("Restart Server"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Function to start the Stable Diffusion Web UI and capture its output
  void startWebUI() async {
    if (Platform.isWindows) {
      try {
        var environment = {'SERVER_ID': 'flutter_server'};
        var process = await Process.start(
            'python', ['-m', 'http.server', '-b', '127.0.0.1', '$portNumber'],
            environment: environment);
        setState(() {
          _output.add(command);
          _output.add('Server started with PID: ${process.pid}');
          _serverProcess = process;
        });

        // Listen to stdout
        process.stdout.transform(utf8.decoder).listen((data) {
          setState(() {
            _output.add(data);
          });
        });

        // Listen to stderr
        process.stderr.transform(utf8.decoder).listen((data) {
          setState(() {
            _output.add(data);
          });
        });
      } catch (e) {
        setState(() {
          _output.add('Failed to start server: $e');
        });
      }
    }
  }

  void stopWebUI() {
    if (_serverProcess != null) {
      _serverProcess!.kill(ProcessSignal.sigkill);
      setState(() {
        _output.add('Server stopped.');
        _output.add('Server stopped (PID: ${_serverProcess!.pid}).');
        _serverProcess = null;
      });
    }
  }

  void restartWebUI() async {
    stopWebUI();
    await Future.delayed(Duration(seconds: 2)); // Delay to release the port

    startWebUI();
  }

  // Function to open the Web UI in the browser
  void openWebPage(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
