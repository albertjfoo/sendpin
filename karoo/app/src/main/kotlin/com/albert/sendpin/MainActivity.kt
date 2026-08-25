package com.albert.sendpin

import android.app.Activity
import android.app.AlertDialog
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.format.DateUtils
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.PopupMenu
import android.widget.Switch
import android.widget.TextView
import io.hammerhead.karooext.KarooSystemService
import io.hammerhead.karooext.models.LaunchPinDrop
import io.hammerhead.karooext.models.Symbol

class MainActivity : Activity() {

    private companion object {
        const val REQUEST_LOCATION = 1

        // Light-mode palette — matches the iOS app and website.
        val YELLOW  = Color.parseColor("#FFE800")
        val INK     = Color.parseColor("#111111")
        val BG      = Color.WHITE
        val CARD    = Color.parseColor("#F2F2F2")
        val GREEN   = Color.parseColor("#1A9E5C")   // deeper for light bg
        val RED_DOT = Color.parseColor("#E53935")
        val GREY_DOT= Color.parseColor("#BBBBBB")
        val SUBTEXT = Color.parseColor("#6A6A6A")
        val HINT    = Color.parseColor("#8A8A8A")
        val CLOSE_BG= Color.parseColor("#EBEBEB")   // ⋯ button circle
    }

    private val refresh = Handler(Looper.getMainLooper())

    private lateinit var toggle: Switch
    private lateinit var statusDot: View
    private lateinit var statusText: TextView
    private lateinit var cardSlot: LinearLayout
    private lateinit var moreButton: View

    private val tick = object : Runnable {
        override fun run() {
            render()
            refresh.postDelayed(this, 2_000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val frame = FrameLayout(this).apply { setBackgroundColor(BG) }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(6), dp(18), dp(80)) // bottom pad clears the back button
        }

        // --- Header: launcher icon + wordmark + ⋯ overflow ---
        root.addView(
            LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL

                // Foreground drawable + yellow bg: the adaptive-icon safe zone keeps the
                // glyph at ~66% of the frame, matching how it looks in the iPhone app.
                val mark = ImageView(this@MainActivity).apply {
                    setImageResource(R.drawable.ic_launcher_foreground)
                    scaleType = ImageView.ScaleType.FIT_CENTER
                    background = rounded(YELLOW, dp(6).toFloat())
                }
                addView(mark, LinearLayout.LayoutParams(dp(30), dp(30)).apply { rightMargin = dp(8) })

                val wordmark = TextView(this@MainActivity).apply {
                    setText(getString(R.string.extension_name))
                    textSize = 16f
                    setTypeface(typeface, android.graphics.Typeface.BOLD)
                    setTextColor(INK)
                }
                addView(wordmark, LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f))

                // ⋯ overflow — Forget iPhone lives here so it stays out of the way.
                moreButton = TextView(this@MainActivity).apply {
                    setText("⋯")
                    textSize = 16f
                    setTextColor(Color.parseColor("#555555"))
                    gravity = Gravity.CENTER
                    background = circle(CLOSE_BG)
                    setOnClickListener { showMoreMenu(it) }
                }
                addView(moreButton, LinearLayout.LayoutParams(dp(28), dp(28)))
            },
            LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { bottomMargin = dp(14) },
        )

        // --- Subtitle ---
        root.addView(
            TextView(this).apply {
                setText(getString(R.string.screen_subtitle))
                textSize = 12f
                setTextColor(SUBTEXT)
            },
        )

        // --- Toggle ---
        toggle = Switch(this).apply {
            setText(getString(R.string.toggle_label))
            textSize = 15f
            setTextColor(INK)
            isChecked = Prefs.isEnabled(this@MainActivity)
            setOnCheckedChangeListener { _, checked ->
                Prefs.setEnabled(this@MainActivity, checked)
                Prefs.setStatus(this@MainActivity, if (checked) "starting…" else "stopping…")
                render()
            }
        }
        root.addView(
            toggle,
            LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = dp(14) },
        )

        // --- Toggle hint ---
        root.addView(
            TextView(this).apply {
                setText(getString(R.string.toggle_hint))
                textSize = 11f
                setTextColor(HINT)
                setPadding(0, dp(4), 0, 0)
            },
        )

        // --- Status: dot + word ---
        statusDot = View(this).apply { background = circle(GREEN) }
        statusText = TextView(this).apply {
            textSize = 13f
            setTextColor(SUBTEXT)
        }
        root.addView(
            LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(0, dp(16), 0, 0)
                setOnClickListener { if (!hasLocationPermission()) ensureLocationPermission() }
                addView(statusDot, LinearLayout.LayoutParams(dp(8), dp(8)).apply { rightMargin = dp(8) })
                addView(statusText)
            },
        )

        // --- Card slot ---
        cardSlot = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(cardSlot, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))


        frame.addView(root, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))

        // Karoo-style back button — light blue-grey pill in the bottom-left corner.
        val backBtn = TextView(this).apply {
            setText("←")
            textSize = 22f
            setTextColor(Color.parseColor("#1E2D3D"))
            gravity = Gravity.CENTER
            background = rounded(Color.parseColor("#B8CCE4"), dp(26).toFloat())
            setOnClickListener { finish() }
        }
        val backLp = FrameLayout.LayoutParams(dp(72), dp(52), Gravity.BOTTOM or Gravity.START)
        backLp.setMargins(dp(16), 0, 0, dp(16))
        frame.addView(backBtn, backLp)

        setContentView(frame)
    }

    private fun render() {
        val enabled = Prefs.isEnabled(this)
        val located = hasLocationPermission()
        val paired  = Prefs.pairedPhone(this) != null

        when {
            !located -> {
                statusDot.background = circle(RED_DOT)
                statusText.setText(getString(R.string.status_location))
                statusText.setTextColor(RED_DOT)
            }
            enabled -> {
                statusDot.background = circle(GREEN)
                statusText.setText(getString(R.string.status_listening))
                statusText.setTextColor(SUBTEXT)
            }
            else -> {
                statusDot.background = circle(GREY_DOT)
                statusText.setText(getString(R.string.status_off))
                statusText.setTextColor(SUBTEXT)
            }
        }

        cardSlot.removeAllViews()
        val lastPin = Prefs.lastPin(this)
        when {
            enabled && located && lastPin != null -> cardSlot.addView(lastPinCard(lastPin))
            !enabled && paired                    -> cardSlot.addView(pairedCard())
        }

        // Show ⋯ only when there's something in the menu (i.e. a phone is paired).
        moreButton.visibility = if (paired) View.VISIBLE else View.INVISIBLE
    }

    // MARK: - Cards

    private fun lastPinCard(pin: Prefs.LastPin): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = rounded(CARD, dp(9).toFloat())
            setPadding(dp(11), dp(10), dp(11), dp(10))
        }

        val textCol = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        textCol.addView(
            TextView(this).apply {
                setText(getString(R.string.last_pin_label).uppercase())
                textSize = 8f
                setTextColor(HINT)
                letterSpacing = 0.05f
            },
        )
        textCol.addView(
            TextView(this).apply {
                setText(pin.name)
                textSize = 13f
                setTextColor(INK)
                maxLines = 1
            },
        )
        textCol.addView(
            TextView(this).apply {
                setText(DateUtils.getRelativeTimeSpanString(pin.at))
                textSize = 9f
                setTextColor(HINT)
            },
        )
        row.addView(textCol, LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f))

        val navigate = ImageView(this).apply {
            setImageResource(R.drawable.ic_send_glyph)
            setColorFilter(INK, android.graphics.PorterDuff.Mode.SRC_IN)
            scaleType = ImageView.ScaleType.FIT_CENTER
            background = circle(YELLOW)
            val pad = dp(8)
            setPadding(pad, pad, pad, pad)
            setOnClickListener { reopen(pin) }
        }
        row.addView(navigate, LinearLayout.LayoutParams(dp(30), dp(30)))

        return wrapWithTopMargin(row, dp(12))
    }

    private fun pairedCard(): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(12), 0, 0)
        }
        val avatar = ImageView(this).apply {
            setImageResource(R.drawable.ic_sendpin)
            setColorFilter(INK)
            background = rounded(CARD, dp(6).toFloat())
            val pad = dp(6)
            setPadding(pad, pad, pad, pad)
        }
        row.addView(avatar, LinearLayout.LayoutParams(dp(26), dp(26)).apply { rightMargin = dp(9) })

        val textCol = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        textCol.addView(
            TextView(this).apply {
                setText(getString(R.string.paired_label).uppercase())
                textSize = 8f
                setTextColor(HINT)
                letterSpacing = 0.05f
            },
        )
        textCol.addView(
            TextView(this).apply {
                setText(getString(R.string.paired_value))
                textSize = 12f
                setTextColor(INK)
            },
        )
        row.addView(textCol)
        return row
    }

    // MARK: - Actions

    private fun reopen(pin: Prefs.LastPin) {
        val system = KarooSystemService(applicationContext)
        system.connect { connected ->
            if (connected) {
                system.dispatch(
                    LaunchPinDrop(
                        Symbol.POI(
                            id = "sendpin-reopen-${System.currentTimeMillis()}",
                            lat = pin.lat,
                            lng = pin.lng,
                            name = pin.name,
                        ),
                    ),
                )
                refresh.postDelayed({ system.disconnect() }, 1_000)
            }
        }
    }

    private fun showMoreMenu(anchor: View) {
        val menu = PopupMenu(this, anchor)
        menu.menu.add(0, 0, 0, getString(R.string.forget_phone))
        menu.setOnMenuItemClickListener { item ->
            if (item.itemId == 0) { confirmForget(); true } else false
        }
        menu.show()
    }

    private fun confirmForget() {
        AlertDialog.Builder(this)
            .setTitle(R.string.forget_title)
            .setMessage(R.string.forget_message)
            .setPositiveButton(R.string.forget_confirm) { _, _ ->
                Prefs.clearPairedPhone(this)
                render()
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    // MARK: - Views

    private fun circle(color: Int) = GradientDrawable().apply {
        shape = GradientDrawable.OVAL
        setColor(color)
    }

    private fun rounded(color: Int, radius: Float) = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(color)
        cornerRadius = radius
    }

    private fun wrapWithTopMargin(view: View, margin: Int): View =
        LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(view, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply { topMargin = margin })
        }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    // MARK: - Permission

    private fun ensureLocationPermission() {
        if (checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(android.Manifest.permission.ACCESS_FINE_LOCATION),
                REQUEST_LOCATION,
            )
        }
    }

    private fun hasLocationPermission(): Boolean =
        checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        render()
    }

    override fun onResume() {
        super.onResume()
        ensureLocationPermission()
        refresh.post(tick)
    }

    override fun onPause() {
        super.onPause()
        refresh.removeCallbacks(tick)
    }
}
