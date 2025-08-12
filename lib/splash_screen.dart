import 'dart:async';
import 'package:flutter/material.dart';

void main() => runApp(const SplashApp());

class SplashApp extends StatelessWidget {
  const SplashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Duration of fade in/out combined
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Repeat fade in then fade out
    _controller.repeat(reverse: true);

    // Navigate to Home after 6 seconds (adjust as needed)
    Timer(const Duration(seconds: 6), () {
      _controller.stop();
      // Navigate to your main page and remove splash screen from stack
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
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
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/logo.png', // Your logo here
                width: 150,
              ),
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                ).createShader(bounds),
                child: const Text(
                  '24loops',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Replace with your actual main page widget
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Page'),
      ),
      body: const Center(
        child: Text('Your App Starts Here'),
      ),
    );
  }
}
