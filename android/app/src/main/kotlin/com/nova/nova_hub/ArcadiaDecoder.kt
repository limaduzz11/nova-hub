package com.nova.nova_hub

import android.view.Surface

/**
 * Ponte JNI para o decoder de vídeo nativo (libarcadia / arcadia_video.c).
 *
 * Entrega a [Surface] do SurfaceView ao motor C, que renderiza os frames
 * decodificados (AMediaCodec) direto nela. A mesma `libarcadia.so` também é
 * carregada pelo dart:ffi; `System.loadLibrary` aqui é idempotente.
 */
object ArcadiaDecoder {
    init {
        System.loadLibrary("arcadia")
    }

    external fun nativeSetSurface(surface: Surface)

    external fun nativeClearSurface()
}
