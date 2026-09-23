package com.chengbo.chengbo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

/**
 * 第二个桌面 widget：待听（inbox 前 4 个未听单集）。
 *
 * 数据契约：
 *   - Dart 端 DeskWidgetLogic.episodesPayload() 把 List<InboxItem> 序列化为 JSON 字符串
 *     写入 widget_episodes key。
 *   - 本类解析 JSON，按行 setTextViewText；空数组显示「暂无未听单集」空态。
 *
 * 颜色复用 ChengboWidgetProvider 的着色逻辑（先内联；B1+B2 都合后抽 helper）。
 */
class ChengboWidgetEpisodesProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val data = HomeWidgetPlugin.getData(context)
        val raw = data.getString("widget_episodes", "[]")
        val rows = JSONArray(raw)

        // 着色：复用 B1 的动态色 / 深色变体逻辑（先内联）
        val useDynamic = data.getBoolean("widget_use_dynamic_color", false)
        val dynamicOk = useDynamic && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
        val bgRes = if (dynamicOk) android.R.color.system_accent1_600
                    else            R.color.widget_background
        val onRes = if (dynamicOk) android.R.color.system_accent1_0
                    else            R.color.widget_on_background

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.chengbo_widget_episodes)

            if (rows.length() == 0) {
                // 空态：隐藏 4 行，显示「暂无未听单集」
                views.setViewVisibility(R.id.widget_ep_empty, View.VISIBLE)
                for (i in 0 until 4) {
                    views.setViewVisibility(
                        context.resources.getIdentifier("widget_ep_row_$i", "id", context.packageName),
                        View.GONE,
                    )
                }
            } else {
                views.setViewVisibility(R.id.widget_ep_empty, View.GONE)
                for (i in 0 until 4) {
                    val rowId = context.resources.getIdentifier("widget_ep_row_$i", "id", context.packageName)
                    if (i < rows.length()) {
                        val row = rows.getJSONObject(i)
                        val title = row.optString("title", "")
                        val subtitle = row.optString("subtitle", "")
                        val guid = row.optString("guid", "")
                        views.setViewVisibility(rowId, View.VISIBLE)
                        views.setTextViewText(
                            context.resources.getIdentifier("widget_ep_row_${i}_title", "id", context.packageName),
                            title,
                        )
                        views.setTextViewText(
                            context.resources.getIdentifier("widget_ep_row_${i}_subtitle", "id", context.packageName),
                            subtitle,
                        )
                        views.setOnClickPendingIntent(
                            rowId,
                            ChengboWidgetProvider.buildLaunchPendingIntent(
                                context,
                                Uri.parse("chengbo://play?guid=$guid"),
                                // 每个 row 独立 requestCode，避免 PendingIntent 被 FLAG_UPDATE_CURRENT 覆盖
                                100 + i,
                            ),
                        )
                    } else {
                        views.setViewVisibility(rowId, View.GONE)
                    }
                }
            }

            // 整块点击 = open
            views.setOnClickPendingIntent(
                R.id.widget_ep_root,
                ChengboWidgetProvider.buildLaunchPendingIntent(
                    context,
                    Uri.parse("chengbo://open"),
                    0,
                ),
            )

            // 着色
            views.setInt(R.id.widget_ep_root, "setBackgroundColor", context.getColor(bgRes))
            val onColor = context.getColor(onRes)
            views.setTextColor(R.id.widget_ep_header, onColor)
            views.setTextColor(R.id.widget_ep_empty_title, onColor)
            views.setTextColor(R.id.widget_ep_empty_subtitle, onColor)
            for (i in 0 until 4) {
                views.setTextColor(
                    context.resources.getIdentifier("widget_ep_row_${i}_title", "id", context.packageName),
                    onColor,
                )
                views.setTextColor(
                    context.resources.getIdentifier("widget_ep_row_${i}_subtitle", "id", context.packageName),
                    onColor,
                )
            }

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}