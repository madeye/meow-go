package io.github.madeye.meow.database

import androidx.room.*

@Entity(tableName = "clash_profile")
data class ClashProfile(
    @PrimaryKey(autoGenerate = true) var id: Long = 0,
    var name: String = "",
    var url: String = "",
    @ColumnInfo(name = "yaml_content") var yamlContent: String = "",
    var selected: Boolean = false,
    @ColumnInfo(name = "last_updated") var lastUpdated: Long = 0,
    var tx: Long = 0,
    var rx: Long = 0,
)

@Dao
interface ProfileDao {
    @Query("SELECT * FROM clash_profile ORDER BY id ASC")
    fun getAll(): List<ClashProfile>

    @Query("SELECT * FROM clash_profile WHERE selected = 1 LIMIT 1")
    fun getSelected(): ClashProfile?

    @Query("SELECT * FROM clash_profile WHERE id = :id")
    fun getById(id: Long): ClashProfile?

    @Insert
    fun insert(profile: ClashProfile): Long

    @Update
    fun update(profile: ClashProfile)

    @Delete
    fun delete(profile: ClashProfile)

    @Query("UPDATE clash_profile SET selected = 0")
    fun deselectAll()

    @Query("UPDATE clash_profile SET selected = 1 WHERE id = :id")
    fun select(id: Long)

    @Query("UPDATE clash_profile SET tx = :tx, rx = :rx WHERE id = :id")
    fun updateTraffic(id: Long, tx: Long, rx: Long)
}
