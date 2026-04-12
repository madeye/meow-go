package io.github.madeye.meow.database

import androidx.room.*

@Entity(tableName = "daily_traffic")
data class DailyTraffic(
    @PrimaryKey var date: String = "", // yyyy-MM-dd
    var tx: Long = 0,
    var rx: Long = 0,
)

@Dao
interface DailyTrafficDao {
    @Query("SELECT * FROM daily_traffic ORDER BY date ASC")
    suspend fun getAll(): List<DailyTraffic>

    @Query("SELECT * FROM daily_traffic WHERE date >= :since ORDER BY date ASC")
    suspend fun getSince(since: String): List<DailyTraffic>

    @Query("SELECT * FROM daily_traffic WHERE date = :date")
    suspend fun getByDate(date: String): DailyTraffic?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entry: DailyTraffic)

    @Query("DELETE FROM daily_traffic WHERE date < :before")
    suspend fun deleteBefore(before: String)
}
