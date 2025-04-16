import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;

  const UserAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.blue.shade100,
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: TextStyle(
            color: textColor ?? Colors.blue.shade700,
            fontSize: size * 0.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
