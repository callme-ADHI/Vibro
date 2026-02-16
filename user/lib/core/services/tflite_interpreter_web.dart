import 'tflite_interpreter_wrapper.dart';

class TfliteInterpreterWeb implements TfliteInterpreterWrapper {
  @override
  Future<void> loadFromFile(String path) async {
    print('TFLite is not supported on Web in this version of Vibro.');
  }

  @override
  void run(Object input, Object output) {
    // No-op or throw
    print('Attempted to run TFLite inference on Web. This is a no-op.');
  }

  @override
  void close() {}

  @override
  List<int> getInputShape(int index) => [1, 13]; // Mocked as expected

  @override
  List<int> getOutputShape(int index) => [1, 5]; // Mocked for safety
}

TfliteInterpreterWrapper factoryGetInterpreter() => TfliteInterpreterWeb();
