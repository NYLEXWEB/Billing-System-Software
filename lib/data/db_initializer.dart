import 'db_initializer_stub.dart'
    if (dart.library.js_interop) 'db_initializer_web.dart' as impl;

Future<void> initializeDatabaseFactory() async {
  await impl.initializeDatabaseFactory();
}
