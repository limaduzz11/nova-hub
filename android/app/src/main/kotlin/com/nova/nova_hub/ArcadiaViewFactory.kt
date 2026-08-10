package com.nova.nova_hub

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** Fábrica do PlatformView de streaming (viewType "arcadia/surface"). */
class ArcadiaViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        ArcadiaSurfaceView(context)
}
