import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'tflite_interpreter_wrapper.dart';

class TfliteInterpreterIo implements TfliteInterpreterWrapper {
  Interpreter? _interpreter;

  @override
  Future<void> loadFromFile(String path) async {
    _interpreter?.close();
    _interpreter = Interpreter.fromFile(File(path));
  }

  @override
  void run(Object input, Object output) {
    if (_interpreter == null) throw Exception('Interpreter not loaded');
    _interpreter!.run(input, output);
  }

  @override
  void close() {
    _interpreter?.close();
    _interpreter = null;
  }

  @override
  List<int> getInputShape(int index) {
    return _interpreter?.getInputTensor(index).shape ?? [];
  }

  @override
  List<int> getOutputShape(int index) {
    return _interpreter?.getOutputTensor(index).shape ?? [];
  }
}

TfliteInterpreterWrapper factoryGetInterpreter() => TfliteInterpreterIo();
