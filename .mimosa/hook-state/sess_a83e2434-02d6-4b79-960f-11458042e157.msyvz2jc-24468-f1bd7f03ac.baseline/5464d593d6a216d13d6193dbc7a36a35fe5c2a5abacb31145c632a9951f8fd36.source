package com.chengbo.chengbo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class ChengboWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val data = HomeWidgetPlugin.getData(context)
        val title = data.getString("widget_title", "澄波")
        val subtitle = data.getString("widget_subtitle", "点此打开")
        val playing = data.getBoolean("widget_playing", false)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.chengbo_widget)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_subtitle, subtitle)
            views.setImageViewResource(
                R.id.widget_toggle,
                if (playing) android.R.drawable.ic_media_pause
                else android.R.drawable.ic_media_play
            )
            views.setOnClickPendingIntent(
                R.id.widget_root,
                launch(context, "chengbo://open", 0)
            )
            views.setOnClickPendingIntent(
                R.id.widget_toggle,
                launch(context, "chengbo://toggle", 1)
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun launch(context: Context, uri: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            data = Uri.parse(uri)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
