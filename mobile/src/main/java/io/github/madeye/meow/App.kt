package io.github.madeye.meow

import android.app.Application
import io.github.madeye.meow.database.PrivateDatabase
import io.github.madeye.meow.editor.SoraTextMateBootstrap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import timber.log.Timber

class App : Application() {
    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onCreate() {
        super.onCreate()
        Timber.plant(Timber.DebugTree())
        Core.init(this)
        // Ensure database is created on first launch
        appScope.launch { PrivateDatabase.profileDao.getAll() }
        // Sora Editor TextMate registries are process-global; populate once.
        SoraTextMateBootstrap.init(this)
    }
}
