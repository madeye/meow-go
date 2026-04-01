package io.github.madeye.meow.bg

import io.github.madeye.meow.aidl.TrafficStats
import io.github.madeye.meow.core.MihomoCore
import io.github.madeye.meow.database.ClashProfile
import timber.log.Timber
import java.io.File

class MihomoInstance(val profile: ClashProfile) {
    val profileName: String get() = profile.name

    private var prevTx: Long = 0
    private var prevRx: Long = 0
    private var lastUpdate: Long = 0

    fun start(configDir: File) {
        val configFile = File(configDir, "config.yaml")
        // Strip sections handled by the app, not mihomo:
        // - subscriptions: refresh is done by the app
        // - dns: DNS is handled by tun2socks DoH forwarder
        val yaml = profile.yamlContent
            .replace(Regex("(?m)^subscriptions:.*?(?=^[a-z]|\\Z)", RegexOption.DOT_MATCHES_ALL), "")
            .replace(Regex("(?m)^dns:.*?(?=^[a-z]|\\Z)", RegexOption.DOT_MATCHES_ALL), "dns:\n  enable: false\n")
            .replace(Regex("(?m)^port:.*\n?"), "")
            .replace(Regex("(?m)^socks-port:.*\n?"), "")
            .replace(Regex("(?m)^mixed-port:.*\n?"), "")
            .let { "mixed-port: 7890\n$it" }
        configFile.writeText(yaml)
        MihomoCore.nativeSetHomeDir(configDir.absolutePath)
        val result = MihomoCore.nativeStartEngine("127.0.0.1:9090", "")
        if (result != 0) {
            throw RuntimeException("Failed to start engine: ${MihomoCore.nativeGetLastError()}")
        }
        Timber.d("MihomoInstance: engine started")
    }

    fun startTun2Socks(vpnService: android.net.VpnService, fd: Int) {
        val result = MihomoCore.nativeStartTun2Socks(vpnService, fd, 7890, 1053)
        if (result != 0) {
            throw RuntimeException("Failed to start tun2socks: ${MihomoCore.nativeGetLastError()}")
        }
        Timber.d("MihomoInstance: tun2socks started")
    }

    fun stop() {
        MihomoCore.nativeStopEngine()
        Timber.d("MihomoInstance: engine stopped")
    }

    fun requestTrafficUpdate(): TrafficStats {
        val tx = MihomoCore.nativeGetUploadTraffic()
        val rx = MihomoCore.nativeGetDownloadTraffic()
        val now = System.currentTimeMillis()
        val elapsed = if (lastUpdate > 0) now - lastUpdate else 1000L
        val stats = TrafficStats(
            txRate = if (elapsed > 0) (tx - prevTx) * 1000 / elapsed else 0,
            rxRate = if (elapsed > 0) (rx - prevRx) * 1000 / elapsed else 0,
            txTotal = tx,
            rxTotal = rx,
        )
        prevTx = tx
        prevRx = rx
        lastUpdate = now
        return stats
    }
}
