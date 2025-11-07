package com.example.toggletalk

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class ToggleTalkWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        // Handle appliance control actions
        when (intent.action) {
            "com.example.toggletalk.TOGGLE_LIGHT" -> {
                // Send broadcast to Flutter app to toggle light
                val broadcastIntent = Intent("com.example.toggletalk.TOGGLE_APPLIANCE").apply {
                    putExtra("appliance", "light")
                }
                context.sendBroadcast(broadcastIntent)
            }
            "com.example.toggletalk.TOGGLE_AC" -> {
                // Send broadcast to Flutter app to toggle AC
                val broadcastIntent = Intent("com.example.toggletalk.TOGGLE_APPLIANCE").apply {
                    putExtra("appliance", "ac")
                }
                context.sendBroadcast(broadcastIntent)
            }
            "com.example.toggletalk.TOGGLE_WASHING_MACHINE" -> {
                // Send broadcast to Flutter app to toggle washing machine
                val broadcastIntent = Intent("com.example.toggletalk.TOGGLE_APPLIANCE").apply {
                    putExtra("appliance", "washing_machine")
                }
                context.sendBroadcast(broadcastIntent)
            }
        }
    }

    companion object {
        private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            // Create an Intent to launch the main activity
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)

            // Get the layout for the App Widget and attach an on-click listener
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            views.setOnClickPendingIntent(R.id.widget_layout, pendingIntent)
            
            // Set up click listeners for individual appliance buttons
            val lightIntent = Intent(context, ToggleTalkWidgetProvider::class.java).apply {
                action = "com.example.toggletalk.TOGGLE_LIGHT"
            }
            val lightPendingIntent = PendingIntent.getBroadcast(context, 0, lightIntent, PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.btn_light, lightPendingIntent)
            
            val acIntent = Intent(context, ToggleTalkWidgetProvider::class.java).apply {
                action = "com.example.toggletalk.TOGGLE_AC"
            }
            val acPendingIntent = PendingIntent.getBroadcast(context, 0, acIntent, PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.btn_ac, acPendingIntent)
            
            val washingMachineIntent = Intent(context, ToggleTalkWidgetProvider::class.java).apply {
                action = "com.example.toggletalk.TOGGLE_WASHING_MACHINE"
            }
            val washingMachinePendingIntent = PendingIntent.getBroadcast(context, 0, washingMachineIntent, PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.btn_washing_machine, washingMachinePendingIntent)

            // Tell the AppWidgetManager to perform an update on the current app widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}