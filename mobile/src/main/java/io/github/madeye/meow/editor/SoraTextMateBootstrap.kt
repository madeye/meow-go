package io.github.madeye.meow.editor

import android.content.Context
import io.github.rosemoe.sora.langs.textmate.TextMateLanguage
import io.github.rosemoe.sora.langs.textmate.registry.FileProviderRegistry
import io.github.rosemoe.sora.langs.textmate.registry.GrammarRegistry
import io.github.rosemoe.sora.langs.textmate.registry.ThemeRegistry
import io.github.rosemoe.sora.langs.textmate.registry.model.ThemeModel
import io.github.rosemoe.sora.langs.textmate.registry.provider.AssetsFileResolver
import org.eclipse.tm4e.core.registry.IThemeSource

/**
 * Process-global initialization of the Sora Editor TextMate registries.
 *
 * Sora's grammar/theme/file-provider registries are singletons. They must be
 * populated exactly once before the first [io.github.rosemoe.sora.widget.CodeEditor]
 * instance is created. Call [init] from `Application.onCreate`.
 */
object SoraTextMateBootstrap {
    @Volatile private var initialized = false
    private const val THEME_NAME = "darcula"
    private const val THEME_PATH = "textmate/darcula.json"
    private const val LANGUAGES_REGISTRY = "textmate/languages.json"
    const val YAML_SCOPE = "source.yaml"

    fun init(context: Context) {
        if (initialized) return
        synchronized(this) {
            if (initialized) return

            FileProviderRegistry.getInstance().addFileProvider(
                AssetsFileResolver(context.applicationContext.assets)
            )

            val themeRegistry = ThemeRegistry.getInstance()
            val themeStream = FileProviderRegistry.getInstance().tryGetInputStream(THEME_PATH)
                ?: error("Missing TextMate theme asset: $THEME_PATH")
            themeRegistry.loadTheme(
                ThemeModel(
                    IThemeSource.fromInputStream(themeStream, THEME_PATH, null),
                    THEME_NAME,
                ).apply { isDark = true }
            )
            themeRegistry.setTheme(THEME_NAME)

            GrammarRegistry.getInstance().loadGrammars(LANGUAGES_REGISTRY)

            initialized = true
        }
    }

    /** Build a fresh [TextMateLanguage] bound to the YAML grammar. */
    fun yamlLanguage(): TextMateLanguage =
        TextMateLanguage.create(YAML_SCOPE, /* autoCompleteEnabled = */ false)
}
