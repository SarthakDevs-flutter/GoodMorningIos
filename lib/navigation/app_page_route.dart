import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Push routes with native iOS edge-swipe back; Material route elsewhere.
Route<T> appPageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool fullscreenDialog = false,
}) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return CupertinoPageRoute<T>(
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      builder: builder,
    );
  }
  return MaterialPageRoute<T>(
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    builder: builder,
  );
}

/// Live alarm UI — no swipe-to-dismiss; must finish prayer or Emergency.
Route<T> liveAlarmPageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return _NoSwipeCupertinoPageRoute<T>(
      settings: settings,
      fullscreenDialog: true,
      builder: builder,
    );
  }
  return MaterialPageRoute<T>(
    settings: settings,
    fullscreenDialog: true,
    builder: builder,
  );
}

class _NoSwipeCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  _NoSwipeCupertinoPageRoute({
    required super.builder,
    super.settings,
    super.fullscreenDialog,
  });

  @override
  bool get popGestureEnabled => false;
}
