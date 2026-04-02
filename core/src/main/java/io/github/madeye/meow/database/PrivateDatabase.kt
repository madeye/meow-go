package io.github.madeye.meow.database

import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import io.github.madeye.meow.Core

@Database(entities = [ClashProfile::class, DailyTraffic::class], version = 3)
abstract class PrivateDatabase : RoomDatabase() {
    companion object {
        private val instance by lazy {
            Room.databaseBuilder(Core.deviceStorage, PrivateDatabase::class.java, "mihomo.db")
                .allowMainThreadQueries()
                .fallbackToDestructiveMigration()
                .build()
        }

        val profileDao get() = instance.profileDao()
        val dailyTrafficDao get() = instance.dailyTrafficDao()
    }

    abstract fun profileDao(): ProfileDao
    abstract fun dailyTrafficDao(): DailyTrafficDao
}
