package com.nova.nova_hub

import android.content.Context
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import io.flutter.plugin.platform.PlatformView

/**
 * PlatformView que hospeda um [SurfaceView] e entrega sua Surface ao decoder
 * nativo (Arcadia Remote — Fase 2.2). O vídeo é renderizado pelo AMediaCodec
 * direto nesta Surface; o Flutter só posiciona a view e desenha o overlay.
 */
class ArcadiaSurfaceView(context: Context) : PlatformView, SurfaceHolder.Callback {

    private val surfaceView = SurfaceView(context)

    init {
        surfaceView.holder.addCallback(this)
    }

    override fun getView(): View = surfaceView

    override fun dispose() {
        surfaceView.holder.removeCallback(this)
        runCatching { ArcadiaDecoder.nativeClearSurface() }
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        ArcadiaDecoder.nativeSetSurface(holder.surface)
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        ArcadiaDecoder.nativeSetSurface(holder.surface)
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        ArcadiaDecoder.nativeClearSurface()
    }
}
