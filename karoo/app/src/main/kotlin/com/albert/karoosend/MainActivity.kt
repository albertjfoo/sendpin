package com.albert.karoosend

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.format.DateUtils
import android.view.Gravity
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Switch
import android.widget.TextView

/**
 * The extension's only screen: is it listening, and a switch to stop it.
 *
 * Built with plain views rather than Compose or AppCompat deliberately — this
 * is four widgets on a 3.2" screen, and every dependency added here is one more
 * thing that has to work on Android 8.1.
 *
 * Its real purpose is that an extension with no launcher activity is invisible:
 * it binds at boot and runs with no way to see it or stop it from the head unit.
 */
class MainActivity : Activity() {

    private val refresh = Handler(Looper.getMainLooper())
    private lateinit var statusLine: TextView
    private lateinit var lastLine: TextView

    private val tick = object : Runnable {
        override fun run() {
            render()
            refresh.postDelayed(this, 2_000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.BLACK)
            setPadding(32, 32, 32, 32)
        }

        root.addView(
            TextView(this).apply {
                text = getString(R.string.extension_name)
                textSize = 26f
                setTextColor(Color.WHITE)
            },
        )

        root.addView(
            TextView(this).apply {
                text = getString(R.string.screen_subtitle)
                textSize = 13f
                setTextColor(Color.GRAY)
                setPadding(0, 8, 0, 24)
            },
        )

        val toggle = Switch(this).apply {
            text = getString(R.string.toggle_label)
            textSize = 18f
            setTextColor(Color.WHITE)
            isChecked = Prefs.isEnabled(this@MainActivity)
            setOnCheckedChangeListener { _, checked ->
                Prefs.setEnabled(this@MainActivity, checked)
                // The watcher polls the flag, so it may take a few seconds to
                // notice. Say so rather than letting the screen look stuck.
                Prefs.setStatus(
                    this@MainActivity,
                    if (checked) "starting…" else "stopping…",
                )
                render()
            }
        }
        root.addView(toggle, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))

        statusLine = TextView(this).apply {
            textSize = 16f
            setTextColor(Color.LTGRAY)
            setPadding(0, 28, 0, 0)
        }
        root.addView(statusLine)

        lastLine = TextView(this).apply {
            textSize = 14f
            setTextColor(Color.GRAY)
            setPadding(0, 12, 0, 0)
        }
        root.addView(lastLine)

        root.addView(
            TextView(this).apply {
                text = getString(R.string.screen_hint)
                textSize = 12f
                setTextColor(Color.DKGRAY)
                setPadding(0, 32, 0, 0)
                gravity = Gravity.START
            },
        )

        setContentView(ScrollView(this).apply { addView(root) })
    }

    private fun render() {
        statusLine.text = getString(R.string.status_prefix, Prefs.status(this))
        val last = Prefs.lastDestination(this)
        lastLine.text = if (last == null) {
            getString(R.string.no_destination_yet)
        } else {
            val ago = DateUtils.getRelativeTimeSpanString(last.second)
            getString(R.string.last_destination, last.first, ago)
        }
    }

    override fun onResume() {
        super.onResume()
        refresh.post(tick)
    }

    override fun onPause() {
        super.onPause()
        refresh.removeCallbacks(tick)
    }
}
