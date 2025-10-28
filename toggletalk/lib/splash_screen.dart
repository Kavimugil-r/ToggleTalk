import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onSplashFinished;

  const SplashScreen({super.key, required this.onSplashFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  bool _animationError = false;

  @override
  void initState() {
    super.initState();

    // Create animation controller for the Lottie animation
    _controller = AnimationController(vsync: this);

    // Delay to show the splash screen for a few seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onSplashFinished();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie animation with error handling
            if (!_animationError)
              SizedBox(
                width: 200,
                height: 200,
                child: FutureBuilder(
                  future: _loadAnimation(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      // Show fallback image if animation fails
                      return Image.asset(
                        'assets/icons/ToggleTalk.png',
                        width: 200,
                        height: 200,
                      );
                    }
                    if (snapshot.hasData) {
                      return snapshot.data!;
                    }
                    // Show loading indicator while loading animation
                    return const CircularProgressIndicator();
                  },
                ),
              )
            else
              // Fallback to static image if Lottie fails
              Image.asset(
                'assets/icons/ToggleTalk.png',
                width: 200,
                height: 200,
              ),
            const SizedBox(height: 20),
            const Text(
              'ToggleTalk',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Home Automation System',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<Widget> _loadAnimation() async {
    try {
      return Lottie.asset(
        'assets/json/Home.json',
        controller: _controller,
        onLoaded: (composition) {
          // Configure the AnimationController with the duration of the
          // Lottie file, then repeat the animation
          _controller
            ..duration = composition.duration
            ..repeat();
        },
      );
    } catch (e) {
      // Handle animation loading error
      print('Error loading Lottie animation: $e');
      setState(() {
        _animationError = true;
      });
      // Return fallback widget
      return Image.asset(
        'assets/icons/ToggleTalk.png',
        width: 200,
        height: 200,
      );
    }
  }
}
