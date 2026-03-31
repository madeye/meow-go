package io.github.madeye.meow

import android.app.Application
import io.github.madeye.meow.database.PrivateDatabase
import timber.log.Timber

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        Timber.plant(Timber.DebugTree())
        Core.init(this)
        // Ensure database is created on first launch
        PrivateDatabase.profileDao.getAll()
    }
}
