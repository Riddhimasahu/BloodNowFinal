import 'package:flutter/material.dart';

Widget buildGoogleButton({required VoidCallback onPressed}) {
  return OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.g_mobiledata, size: 28),
    label: const Text('Continue with Google'),
  );
}
