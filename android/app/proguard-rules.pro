# These JNI methods are looked up by their original names from Dart-generated
# bindings. R8 cannot see those calls while tracing Java/Kotlin references.
-keep,includedescriptorclasses class io.flutter.plugins.sharedpreferences.** { *; }
-keep,includedescriptorclasses class com.github.dart_lang.** { *; }
# Suspend methods contain this type in JNI signatures. Preserving only the
# method name is insufficient if R8 renames the signature's parameter class.
-keep,includedescriptorclasses class kotlin.coroutines.** { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.Result** { *; }
-keep class kotlin.ResultKt { *; }
-keep class kotlin.jvm.internal.DefaultConstructorMarker { *; }
-keep class com.ryanheise.audio_session.** { *; }
-keep class com.ryanheise.audioservice.** { *; }
-keep class kotlin.Result$* { *; }
-keep class kotlin.enums.** { *; }
-keep class com.yausername.** { *; }
-keep class com.fasterxml.jackson.** { *; }
-dontwarn org.slf4j.impl.StaticLoggerBinder
# Optional Jackson desktop JavaBeans/DOM integrations are absent on Android.
# Its Android JSON path detects their absence; the native bridge uses JSONObject.
-dontwarn java.beans.ConstructorProperties
-dontwarn java.beans.Transient
-dontwarn org.w3c.dom.bootstrap.DOMImplementationRegistry
# Commons Compress instantiates ZIP extra-field classes through reflection while
# unpacking Python/FFmpeg. Their constructors must survive R8 in release builds.
-keep class org.apache.commons.compress.archivers.zip.** { *; }
