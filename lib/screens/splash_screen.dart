import 'package:flutter/material.dart';

/// The branded launch screen, shown while the saved session and the profile
/// setup state are resolved.
///
/// [minimumDuration] stops it flashing on and off when everything resolves
/// instantly — the logo should be seen deliberately, not as a flicker.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const Duration minimumDuration = Duration(milliseconds: 900);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(image: AssetImage('assets/logo.png'), width: 108),
            SizedBox(height: 14),
            Image(image: AssetImage('assets/letter-skillmatch.png'), width: 190),
          ],
        ),
      ),
    );
  }
}
