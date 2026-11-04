import 'package:flutter/material.dart';

/// The person icon on a light-blue square. Used on several screens.
class AvatarBox extends StatelessWidget {
  final double size;
  const AvatarBox({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/avatar.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}