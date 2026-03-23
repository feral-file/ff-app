import 'package:app/domain/models/ff1_connect_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for FF1 connect session factory (singleton).
///
/// Use this to create new sessions for FF1 connect attempts.
/// Example:
///   final session = ref.read(ff1ConnectSessionFactoryProvider)
///       .createSession();
final ff1ConnectSessionFactoryProvider =
    Provider<FF1ConnectSessionFactory>((ref) {
  return FF1ConnectSessionFactory();
});
