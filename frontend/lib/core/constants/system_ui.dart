import 'package:flutter/services.dart';

const appSystemBarColor = Color(0xFF101522);

const appSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: appSystemBarColor,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: appSystemBarColor,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarDividerColor: appSystemBarColor,
);
