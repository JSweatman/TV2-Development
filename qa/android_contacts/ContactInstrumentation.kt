package com.sundara.preview.tv2
import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.os.Bundle
import android.util.Log
class ContactInstrumentation: Instrumentation() {
 override fun onCreate(arguments:Bundle?) {
  super.onCreate(arguments)
  addMonitor(object:ActivityMonitor(){
   override fun onStartActivity(intent:Intent):ActivityResult? {
    if(intent.component?.className=="com.sundara.preview.tv2.MainActivity" && intent.action==Intent.ACTION_MAIN)return null
    val resolution=targetContext.packageManager.resolveActivity(intent,0)?.activityInfo
    val event=mapOf("action" to (intent.action?:""),"uri" to (intent.dataString?:""),"handler" to (resolution?.let{it.packageName+"/"+it.name}?:"none-visible"))
    ContactEvidence.events.add(event)
    Log.i("TV2_INTENT","BLOCKED "+event.toString())
    return ActivityResult(Activity.RESULT_CANCELED,null)
   }
  })
  ContactEvidence.armed=true
  Log.i("TV2_INTENT","MONITOR_ARMED_BEFORE_LAUNCH")
  start()
 }
 override fun onStart(){
  startActivitySync(Intent(Intent.ACTION_MAIN).setClassName(targetContext,"com.sundara.preview.tv2.MainActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
  val deadline=System.currentTimeMillis()+180000
  while(!ContactEvidence.done && System.currentTimeMillis()<deadline)Thread.sleep(250)
  val ok=ContactEvidence.done && ContactEvidence.events.size==3
  val result=Bundle();result.putString("stream",if(ok)"TV2_NATIVE_INTENTS_PASS" else "TV2_NATIVE_INTENTS_INCOMPLETE")
  finish(if(ok)Activity.RESULT_OK else Activity.RESULT_CANCELED,result)
 }
}
