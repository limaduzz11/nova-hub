package com.nova.nova_hub

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity do Arcadia Remote.
 *
 * - Registra o PlatformView de vídeo (SurfaceView nativa, Fase 2.2).
 * - Captura controles físicos conectados ao Android (Fase 3.5) e repassa ao
 *   Flutter via MethodChannel `arcadia/gamepad`, que por sua vez chama o
 *   wrapper nativo `arcadia_send_gamepad` (LiSendMultiControllerEvent).
 */
class MainActivity : FlutterActivity() {

    private var gamepadChannel: MethodChannel? = null
    private val forwarder = GamepadForwarder()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry
            .registerViewFactory("arcadia/surface", ArcadiaViewFactory())

        gamepadChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "arcadia/gamepad")
        forwarder.channel = gamepadChannel

        // Channel para lançar apps externos (ex: Moonlight)
        val launchChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "nova/launch")
        launchChannel.setMethodCallHandler { call, result ->
            if (call.method == "launchPackage") {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                    if (launchIntent != null) {
                        startActivity(launchIntent)
                        result.success(true)
                    } else {
                        result.error("NOT_FOUND", "App não instalado: $packageName", null)
                    }
                } else {
                    result.error("INVALID_ARGS", "packageName é obrigatório", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
        if (event != null && forwarder.handleKey(event)) {
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent?): Boolean {
        if (event != null && forwarder.handleMotion(event)) {
            return true
        }
        return super.dispatchGenericMotionEvent(event)
    }
}

/**
 * Acumula o estado do controle (botões + eixos) e envia ao Flutter sempre que
 * algo muda. São aceitos eventos cuja fonte é gamepad/joystick/dpad.
 */
class GamepadForwarder {
    var channel: MethodChannel? = null

    private var buttonFlags = 0
    private var leftTrigger = 0
    private var rightTrigger = 0
    private var lx = 0
    private var ly = 0
    private var rx = 0
    private var ry = 0

    companion object {
        // Android KeyEvent.keyCode -> flag moonlight (LI_*_FLAG).
        private val KEY_TO_FLAG = mapOf(
            96 to 0x1000,   // BUTTON_A
            97 to 0x2000,   // BUTTON_B
            99 to 0x4000,   // BUTTON_X
            100 to 0x8000,  // BUTTON_Y
            19 to 0x0001,   // DPAD_UP
            20 to 0x0002,   // DPAD_DOWN
            21 to 0x0004,   // DPAD_LEFT
            22 to 0x0008,   // DPAD_RIGHT
            102 to 0x0100,  // BUTTON_L1
            103 to 0x0200,  // BUTTON_R1
            108 to 0x0010,  // BUTTON_START (PLAY)
            109 to 0x0020,  // BUTTON_SELECT (BACK)
            110 to 0x0400,  // BUTTON_MODE (GUIDE)
            106 to 0x0040,  // BUTTON_THUMBL (LS)
            107 to 0x0080,  // BUTTON_THUMBR (RS)
            // 104/105 (L2/R2) são tratados como eixos de gatilho.
        )
    }

    private fun isGamepad(event: InputDevice?): Boolean {
        val src = event?.sources ?: 0
        return (src and (InputDevice.SOURCE_GAMEPAD
                or InputDevice.SOURCE_JOYSTICK
                or InputDevice.SOURCE_DPAD)) != 0
    }

    fun handleKey(event: KeyEvent): Boolean {
        val dev = event.device
        if (dev == null || !isGamepad(dev)) return false
        val flag = KEY_TO_FLAG[event.keyCode] ?: return false
        val down = event.action == KeyEvent.ACTION_DOWN
        buttonFlags = if (down) buttonFlags or flag else buttonFlags and flag.inv()
        send()
        return true
    }

    fun handleMotion(event: MotionEvent): Boolean {
        val dev = event.device
        if (dev == null || !isGamepad(dev)) return false
        if (event.action != MotionEvent.ACTION_MOVE) return false

        // Sticks (eixos -1..1) -> short -32768..32767.
        // O protocolo Moonlight espera Y positivo "para cima", mas o Android
        // reporta Y positivo "para baixo"; por isso negamos só o Y de cada
        // stick. O eixo X fica sem inversão (positivo = direita).
        lx = (event.getAxisValue(MotionEvent.AXIS_X) * 32767f).toInt().coerceIn(-32768, 32767)
        ly = -(event.getAxisValue(MotionEvent.AXIS_Y) * 32767f).toInt().coerceIn(-32768, 32767)
        rx = (event.getAxisValue(MotionEvent.AXIS_Z) * 32767f).toInt().coerceIn(-32768, 32767)
        ry = -(event.getAxisValue(MotionEvent.AXIS_RZ) * 32767f).toInt().coerceIn(-32768, 32767)

        // Gatilhos (eixos 0..1) -> 0..255.
        leftTrigger = (event.getAxisValue(MotionEvent.AXIS_LTRIGGER) * 255f).toInt().coerceIn(0, 255)
        rightTrigger = (event.getAxisValue(MotionEvent.AXIS_RTRIGGER) * 255f).toInt().coerceIn(0, 255)

        // Hat (dpad analógico) -> flags de dpad.
        val hatX = event.getAxisValue(MotionEvent.AXIS_HAT_X)
        val hatY = event.getAxisValue(MotionEvent.AXIS_HAT_Y)
        buttonFlags = if (hatX < -0.5f) buttonFlags or 0x0004 else buttonFlags and 0x0004.inv()
        buttonFlags = if (hatX > 0.5f) buttonFlags or 0x0008 else buttonFlags and 0x0008.inv()
        buttonFlags = if (hatY < -0.5f) buttonFlags or 0x0001 else buttonFlags and 0x0001.inv()
        buttonFlags = if (hatY > 0.5f) buttonFlags or 0x0002 else buttonFlags and 0x0002.inv()

        send()
        return true
    }

    private fun send() {
        channel?.invokeMethod(
            "gamepadEvent",
            mapOf(
                "controller" to 0,
                "mask" to 1,
                "buttons" to buttonFlags,
                "lt" to leftTrigger,
                "rt" to rightTrigger,
                "lx" to lx,
                "ly" to ly,
                "rx" to rx,
                "ry" to ry
            )
        )
    }
}
