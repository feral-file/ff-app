/// Base object model
abstract class BaseObject {
  /// Key of the object
  String get key;

  /// Value of the object
  String get value;

  /// Convert the object to a key-value pair
  Map<String, String> get toKeyValue => {
        'key': key,
        'value': value,
      };
}
