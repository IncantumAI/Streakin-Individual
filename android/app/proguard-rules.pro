# Streakin R8 keep rules.
# flutter_local_notifications serialises scheduled notifications with Gson.
-keep class com.dexterous.** { *; }
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
# flutter_secure_storage / Tink
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.errorprone.annotations.**
# Flutter deferred components reference Play Core optionally.
-dontwarn com.google.android.play.core.**
