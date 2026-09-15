# flutter_local_notifications icin gerekli kurallar
-keep class com.dexterous.** { *; }
-keepclassmembers class com.dexterous.** { *; }

# Gson - TypeToken generic tip bilgisini koru (Missing type parameter hatasini onler)
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Generic tip imzalarini koru
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn sun.misc.**
