package io.github.madeye.meow

import android.app.Application
import android.content.Context
import io.github.madeye.meow.database.ClashProfile
import io.github.madeye.meow.database.PrivateDatabase

object Core {
    lateinit var app: Application
    val deviceStorage: Context get() = app

    fun init(app: Application) {
        this.app = app
    }

    suspend fun currentProfile(): ClashProfile? =
        PrivateDatabase.profileDao.getSelected()
}
