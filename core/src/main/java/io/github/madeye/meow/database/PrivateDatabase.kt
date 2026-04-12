package io.github.madeye.meow.database

import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import io.github.madeye.meow.Core

val MIGRATION_4_5 = object : Migration(4, 5) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE clash_profile ADD COLUMN selected_proxies TEXT NOT NULL DEFAULT '{}'")
    }
}

@Database(entities = [ClashProfile::class, DailyTraffic::class], version = 5)
abstract class PrivateDatabase : RoomDatabase() {
    companion object {
        private val instance by lazy {
            Room.databaseBuilder(Core.deviceStorage, PrivateDatabase::class.java, "mihomo.db")
                .addMigrations(MIGRATION_4_5)
                .fallbackToDestructiveMigration()
                .build()
        }

        val profileDao get() = instance.profileDao()
        val dailyTrafficDao get() = instance.dailyTrafficDao()
    }

    abstract fun profileDao(): ProfileDao
    abstract fun dailyTrafficDao(): DailyTrafficDao
}
