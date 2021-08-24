import 'package:meta/meta.dart' show required;
//The logger.dart file is just a util function that prints with a tag like this: [AUTH] Something happened! on your log.
class Logger {
  static void log(String tag, {@required String message}) {
    assert(tag != null);
    print("[$tag] $message");
  }
}
