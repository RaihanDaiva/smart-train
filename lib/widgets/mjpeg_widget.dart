import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MjpegWidget extends StatefulWidget {
  final String stream;
  final BoxFit fit;
  final double width;
  final double height;

  const MjpegWidget({
    Key? key,
    required this.stream,
    this.fit = BoxFit.cover,
    this.width = double.infinity,
    this.height = double.infinity,
  }) : super(key: key);

  @override
  State<MjpegWidget> createState() => _MjpegWidgetState();
}

class _MjpegWidgetState extends State<MjpegWidget> {
  Uint8List? _currentFrame;
  bool _isLoading = true;
  bool _hasError = false;
  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _startStream() async {
    try {
      debugPrint("Connecting to: ${widget.stream}");
      final request = http.Request('GET', Uri.parse(widget.stream));
      final response = await request.send();

      if (response.statusCode == 200) {
        List<int> buffer = [];

        _streamSubscription = response.stream.listen(
          (List<int> chunk) {
            buffer.addAll(chunk);
            _processBuffer(buffer);
          },
          onError: (error) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          },
          onDone: () {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          },
        );
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _processBuffer(List<int> buffer) {
    // Find JPEG start marker (0xFF, 0xD8)
    int startIndex = -1;
    for (int i = 0; i < buffer.length - 1; i++) {
      if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
        startIndex = i;
        break;
      }
    }

    if (startIndex == -1) return;

    // Find JPEG end marker (0xFF, 0xD9)
    int endIndex = -1;
    for (int i = startIndex + 2; i < buffer.length - 1; i++) {
      if (buffer[i] == 0xFF && buffer[i + 1] == 0xD9) {
        endIndex = i + 2;
        break;
      }
    }

    if (endIndex == -1) return;

    // Extract frame
    final frame = buffer.sublist(startIndex, endIndex);

    setState(() {
      _currentFrame = Uint8List.fromList(frame);
      _isLoading = false;
      _hasError = false;
    });

    // Remove processed data from buffer
    buffer.removeRange(0, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 50,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Gagal memuat feed kamera',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading || _currentFrame == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'Menghubungkan ke kamera...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Image.memory(
      _currentFrame!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      gaplessPlayback: true,
    );
  }
}
