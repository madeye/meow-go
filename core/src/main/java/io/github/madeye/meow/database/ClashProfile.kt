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
    /** Legacy single-selection field. New per-group selections are in [selectedProxies]. */
    @ColumnInfo(name = "selected_proxy") var selectedProxy: String = "",
    @ColumnInfo(name = "yaml_backup") var yamlBackup: String = "",
    @ColumnInfo(name = "selected_proxies") var selectedProxies: String = "{}",
)

@Dao
interface ProfileDao {
    @Query("SELECT * FROM clash_profile ORDER BY id ASC")
    suspend fun getAll(): List<ClashProfile>

    @Query("SELECT * FROM clash_profile WHERE selected = 1 LIMIT 1")
    suspend fun getSelected(): ClashProfile?

    @Query("SELECT * FROM clash_profile WHERE id = :id")
    suspend fun getById(id: Long): ClashProfile?

    @Insert
    suspend fun insert(profile: ClashProfile): Long

    @Update
    suspend fun update(profile: ClashProfile)

    @Delete
    suspend fun delete(profile: ClashProfile)

    @Query("UPDATE clash_profile SET selected = 0")
    suspend fun deselectAll()

    @Query("UPDATE clash_profile SET selected = 1 WHERE id = :id")
    suspend fun select(id: Long)

    @Query("UPDATE clash_profile SET tx = :tx, rx = :rx WHERE id = :id")
    suspend fun updateTraffic(id: Long, tx: Long, rx: Long)

    @Query("UPDATE clash_profile SET selected_proxy = :proxyName WHERE id = :id")
    suspend fun updateSelectedProxy(id: Long, proxyName: String)

    @Query("UPDATE clash_profile SET selected_proxies = :proxiesJson WHERE id = :id")
    suspend fun updateSelectedProxies(id: Long, proxiesJson: String)

    @Query("UPDATE clash_profile SET yaml_content = :yaml WHERE id = :id")
    suspend fun updateYamlContent(id: Long, yaml: String)

    @Query("UPDATE clash_profile SET yaml_content = yaml_backup WHERE id = :id")
    suspend fun revertYamlContent(id: Long)
}
