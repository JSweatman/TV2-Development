package com.sundara.preview.tv2
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
object ContactEvidence {
 @Volatile var armed=false
 @Volatile var done=false
 val events=mutableListOf<Map<String,String>>()
}
class MainActivity: FlutterActivity() {
 override fun configureFlutterEngine(engine:FlutterEngine) {
  super.configureFlutterEngine(engine)
  MethodChannel(engine.dartExecutor.binaryMessenger,"qa/native-intents").setMethodCallHandler { call,result ->
   if(call.method=="done")ContactEvidence.done=true
   result.success(mapOf("armed" to ContactEvidence.armed,"events" to ContactEvidence.events.toList()))
  }
 }
}
