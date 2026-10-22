package dev.renance.renance

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * StreakWidgetProvider - the Renance home-screen streak tile (founder
 * 2026-10-22, the Duolingo widget pass). Dart (LearnController) saves
 * the numbers through home_widget's preference bridge; this provider
 * paints them. Tapping the tile opens renance.app - the desk lives in
 * the app, the glance lives here.
 */
class StreakWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val data = HomeWidgetPlugin.getData(context)
        val streak = data.getInt("streak_count", 0)
        val freezes = data.getInt("streak_freezes", 0)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.streak_widget).apply {
                setTextViewText(R.id.streak_count, streak.toString())
                setTextViewText(R.id.streak_label, "day streak")
                // The freeze marker rides the flame line (the founder's
                // blue freeze chips): a ❄ appears when freezes are stocked.
                setTextViewText(
                    R.id.streak_flame,
                    if (freezes > 0) "🔥❄" else "🔥"
                )
                // Tap = open the web desk (the deepest link a widget
                // needs; the app itself is the study surface).
                val open = Intent(Intent.ACTION_VIEW, Uri.parse("https://renance.app"))
                val pi = PendingIntent.getActivity(
                    context,
                    0,
                    open,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                setOnClickPendingIntent(R.id.streak_widget_root, pi)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
