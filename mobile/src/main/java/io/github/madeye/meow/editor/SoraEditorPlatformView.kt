package io.github.madeye.meow.editor

import android.content.Context
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.github.rosemoe.sora.event.ContentChangeEvent
import io.github.rosemoe.sora.langs.textmate.TextMateColorScheme
import io.github.rosemoe.sora.langs.textmate.registry.ThemeRegistry
import io.github.rosemoe.sora.widget.CodeEditor
import io.github.rosemoe.sora.widget.subscribeAlways

/** Channel + view-type identifiers shared between Kotlin and Dart. */
object SoraEditorViewType {
    const val VIEW_TYPE = "io.github.madeye.meow/sora_editor"
    fun channelName(viewId: Int) = "io.github.madeye.meow/sora_editor_$viewId"
}

class SoraEditorViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = (args as? Map<String, Any?>) ?: emptyMap()
        return SoraEditorPlatformView(context, messenger, viewId, params)
    }
}

private class SoraEditorPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    creationParams: Map<String, Any?>,
) : PlatformView {

    private val editor: CodeEditor = CodeEditor(context)
    private val channel = MethodChannel(messenger, SoraEditorViewType.channelName(viewId))

    init {
        SoraTextMateBootstrap.init(context.applicationContext)

        editor.colorScheme = TextMateColorScheme.create(ThemeRegistry.getInstance())
        editor.setEditorLanguage(SoraTextMateBootstrap.yamlLanguage())

        val initial = creationParams["initialText"] as? String ?: ""
        editor.setText(initial)

        val readOnly = creationParams["readOnly"] as? Boolean ?: false
        editor.isEditable = !readOnly

        (creationParams["textSizeSp"] as? Number)?.let { editor.setTextSize(it.toFloat()) }

        editor.subscribeAlways<ContentChangeEvent> { _ ->
            channel.invokeMethod("onTextChanged", mapOf("text" to editor.text.toString()))
        }

        channel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "getText" -> result.success(editor.text.toString())
                "setText" -> {
                    val text = call.argument<String>("text") ?: ""
                    editor.setText(text)
                    result.success(null)
                }
                "undo" -> { editor.undo(); result.success(null) }
                "redo" -> { editor.redo(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    override fun getView(): View = editor

    override fun dispose() {
        channel.setMethodCallHandler(null)
        editor.release()
    }
}
