import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

Widget buildGoogleButton({required VoidCallback onPressed}) {
  return SizedBox(
    height: 48,
    child: web.renderButton(), // Let GIS handle the click entirely on Web
  );
}
