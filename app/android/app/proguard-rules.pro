# Giữ nguyên các lớp mà Dart gọi qua JNI (phòng khi bật lại thu gọn mã R8).
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.k2fsa.sherpa.onnx.** { *; }
-keep class kotlin.coroutines.Continuation { *; }
-dontwarn io.flutter.embedding.**
