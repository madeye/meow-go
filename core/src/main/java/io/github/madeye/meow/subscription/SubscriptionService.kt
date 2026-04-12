package io.github.madeye.meow.subscription

import io.github.madeye.meow.core.MihomoEngine
import io.github.madeye.meow.database.ClashProfile
import io.github.madeye.meow.database.PrivateDatabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.URL

object SubscriptionService {
    suspend fun fetchSubscription(profile: ClashProfile): ClashProfile = withContext(Dispatchers.IO) {
        val url = URL(profile.url)
        val connection = url.openConnection()
        connection.connectTimeout = 10_000
        connection.readTimeout = 10_000
        val raw = connection.getInputStream().use { it.readBytes() }

        val yaml = if (SubscriptionFormat.isClashYaml(raw)) {
            raw.toString(Charsets.UTF_8)
        } else {
            MihomoEngine.nativeConvertSubscription(raw)
                ?: throw IllegalStateException(
                    "Failed to convert nodelist subscription: ${MihomoEngine.nativeGetLastError()}",
                )
        }

        profile.copy(
            yamlContent = yaml,
            yamlBackup = yaml,
            lastUpdated = System.currentTimeMillis(),
        )
    }

    suspend fun addSubscription(name: String, url: String): ClashProfile = withContext(Dispatchers.IO) {
        val profile = ClashProfile(name = name, url = url)
        val fetched = fetchSubscription(profile)
        val id = PrivateDatabase.profileDao.insert(fetched)
        fetched.copy(id = id)
    }

    suspend fun refreshAll() = withContext(Dispatchers.IO) {
        val profiles = PrivateDatabase.profileDao.getAll().filter { it.url.isNotEmpty() }
        for (profile in profiles) {
            try {
                val updated = fetchSubscription(profile)
                PrivateDatabase.profileDao.update(updated)
            } catch (_: Exception) { }
        }
    }
}
