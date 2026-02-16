import 'dart:typed_data';

/// A wrapper around TFLite Interpreter to allow for platform-specific implementations.
abstract class TfliteInterpreterWrapper {
  Future<void> loadFromFile(String path);
  void run(Object input, Object output);
  void close();
  
  // Method to get tensor information if needed
  List<int> getInputShape(int index);
  List<int> getOutputShape(int index);
}


