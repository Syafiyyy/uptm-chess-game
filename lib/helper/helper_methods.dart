import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uptm_chess/providers/game_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:squares/squares.dart';

Widget buildGameType({
  required String lable,
  String? gameTime,
  IconData? icon,
  required Function() onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4A91FF),
            const Color(0xFF1565C0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
          if (icon != null) const SizedBox(height: 8),
          Text(
            lable,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          if (gameTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                gameTime,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    ),
  );
}

String getTimerToDisplay({
  required GameProvider gameProvider,
  required bool isUser,
}) {
  String timer = '';
  // check if is user
  if (isUser) {
    if (gameProvider.player == Squares.white) {
      timer = gameProvider.whitesTime.toString().substring(2, 7);
    }
    if (gameProvider.player == Squares.black) {
      timer = gameProvider.blacksTime.toString().substring(2, 7);
    }
  } else {
    // if its not user do the opposite
    if (gameProvider.player == Squares.white) {
      timer = gameProvider.blacksTime.toString().substring(2, 7);
    }
    if (gameProvider.player == Squares.black) {
      timer = gameProvider.whitesTime.toString().substring(2, 7);
    }
  }

  return timer;
}

// method to display the correct time below the board, if user is white then display white time
// if user is black then display black time

final List<String> gameTimes = [
  'Bullet 1+0',
  'Bullet 2+1',
  'Bullet 3+0',
  'Bullet 3+2',
  'Bullet 5+0',
  'Bullet 5+3',
  'Rapid 10+0',
  'Rapid 10+5',
  'Rapid 15+10',
  'Classical 30+0',
  'Classical 30+20',
  'Custom 60+0',
];

var textFormDecoration = InputDecoration(
  labelStyle: const TextStyle(color: Colors.black87),
  hintStyle: const TextStyle(color: Colors.grey),
  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
  ),
  enabledBorder: OutlineInputBorder(
    borderSide: const BorderSide(color: Colors.grey, width: 1),
    borderRadius: BorderRadius.circular(10),
  ),
  focusedBorder: OutlineInputBorder(
    borderSide: const BorderSide(color: Colors.blue, width: 2),
    borderRadius: BorderRadius.circular(10),
  ),
  errorBorder: OutlineInputBorder(
    borderSide: const BorderSide(color: Colors.red, width: 1),
    borderRadius: BorderRadius.circular(10),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderSide: const BorderSide(color: Colors.red, width: 2),
    borderRadius: BorderRadius.circular(10),
  ),
  filled: true,
  fillColor: Colors.white,
);

// pick an image
Future<File?> pickImage({
  required bool fromCamera,
  required Function(String) onFail,
}) async {
  File? fileImage;
  if (fromCamera) {
    try {
      final takenPhoto =
          await ImagePicker().pickImage(source: ImageSource.camera);

      if (takenPhoto != null) {
        fileImage = File(takenPhoto.path);
      }
    } catch (e) {
      onFail(e.toString());
    }
  } else {
    try {
      final choosenImage =
          await ImagePicker().pickImage(source: ImageSource.gallery);

      if (choosenImage != null) {
        fileImage = File(choosenImage.path);
      }
    } catch (e) {
      onFail(e.toString());
    }
  }

  return fileImage;
}

// validate email method
bool validateEmail(String email) {
  // Regular expression for email validation
  final RegExp emailRegex =
      RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$');

  // Check if the email matches the regular expression
  return emailRegex.hasMatch(email);
}
