import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String filePath;
  final VoidCallback onPlayPause;
  final Function(VideoPlayerController)? onControllerCreated;
  final bool hideSlider; 

  const VideoPlayerWidget({
    required this.filePath,
    required this.onPlayPause,
    required this.onControllerCreated,
    this.hideSlider = false,
    Key? key,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _isIconVisible = true;
  double _currentPosition = 0.0;
  double _totalDuration = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.filePath))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _totalDuration = _controller.value.duration.inMilliseconds.toDouble();
          });
        }
      }).catchError((e) {
        print('Error initializing video: $e');
      });

    _controller.addListener(_videoPlayerListener);
  }

  void _videoPlayerListener() {
    if (!mounted) return;

    setState(() {
      _currentPosition = _controller.value.position.inMilliseconds.toDouble();
      if (_controller.value.position >= _controller.value.duration) {
        _isPlaying = false;
        _isIconVisible = true;
      }
    });
  }

  void _togglePlayPause() {
    if (!mounted) return;

    setState(() {
      if (_isPlaying) {
        _controller.pause();
        _isIconVisible = true;
      } else {
        if (_controller.value.position >= _controller.value.duration) {
          _controller.seekTo(Duration.zero);
        }
        _controller.play();
        _isIconVisible = false;
      }
      _isPlaying = !_isPlaying;
    });

    widget.onPlayPause();
  }

  void _seekTo(double value) {
    final position = Duration(milliseconds: value.toInt());
    _controller.seekTo(position);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : Center(child: CircularProgressIndicator()),

          AnimatedOpacity(
            opacity: _isIconVisible ? 1.0 : 0.0,
            duration: Duration(milliseconds: 300),
            child: Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 50,
            ),
          ),

  
          if (!widget.hideSlider)
            Positioned(
              bottom: 0,
              left: 20,
              right: 20,
              child: Slider(
                value: _currentPosition,
                min: 0.0,
                max: _totalDuration,
                onChanged: (value) {
                  _seekTo(value);
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_videoPlayerListener);
    _controller.dispose();
    super.dispose();
  }
}

