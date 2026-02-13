import 'package:flutter/foundation.dart';

/// Notifier used by the keyboard control screen to coordinate keyboard
/// visibility with global tap-to-hide behavior. When the screen is open,
/// this is set to false; when the keyboard is dismissed and the user hasn't
/// navigated to another route, it is set back to true and the screen pops.
final ValueNotifier<bool> shouldHideKeyboardOnTap = ValueNotifier<bool>(true);
