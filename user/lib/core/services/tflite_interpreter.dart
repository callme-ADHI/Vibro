import 'tflite_interpreter_wrapper.dart';
import 'tflite_interpreter_stub.dart'
    if (dart.library.io) 'tflite_interpreter_io.dart'
    if (dart.library.html) 'tflite_interpreter_web.dart'
    if (dart.library.js_interop) 'tflite_interpreter_web.dart';

export 'tflite_interpreter_wrapper.dart';

TfliteInterpreterWrapper getInterpreterWrapper() => factoryGetInterpreter();
