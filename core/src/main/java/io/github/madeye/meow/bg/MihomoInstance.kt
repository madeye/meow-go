package io.github.madeye.meow.bg

import io.github.madeye.meow.aidl.TrafficStats
import io.github.madeye.meow.core.MihomoEngine
import io.github.madeye.meow.core.Tun2SocksCore
import io.github.madeye.meow.database.ClashProfile
import timber.log.Timber
import java.io.File

class MihomoInstance(val profile: ClashProfile) {
    val profileName: String get() = profile.name

    private var prevTx: Long = 0
    private var prevRx: Long = 0
    private var lastUpdate: Long = 0

    fun start(configDir: File, vpnService: android.net.VpnService) {
        // Seed the mihomo home dir with bundled GeoX files so the engine
        // doesn't have to download them on first start. Each file is only
        // copied if it doesn't already exist — users who've run an auto-
        // update or who have newer data on disk keep their version.
        copyGeoxAssets(vpnService, configDir)

        val configFile = File(configDir, "config.yaml")
        // Strip sections handled by the app, not mihomo:
        // - subscriptions: refresh is done by the app
        // - dns: DNS is handled by the tun2socks DoH forwarder; mihomo's
        //   own resolver is left disabled so the two paths don't race.
        val yaml = profile.yamlContent
            .replace(Regex("(?m)^subscriptions:.*?(?=^[a-z]|\\Z)", RegexOption.DOT_MATCHES_ALL), "")
            .replace(Regex("(?m)^dns:.*?(?=^[a-z]|\\Z)", RegexOption.DOT_MATCHES_ALL), "dns:\n  enable: false\n")
            .replace(Regex("(?m)^port:.*\n?"), "")
            .replace(Regex("(?m)^socks-port:.*\n?"), "")
            .replace(Regex("(?m)^mixed-port:.*\n?"), "")
            .let { "mixed-port: 7890\n$it" }
            .let { injectGeoxUrl(it) }
        configFile.writeText(yaml)
        MihomoEngine.nativeSetHomeDir(configDir.absolutePath)
        // The Rust tun2socks side also needs the home dir so its DoH
        // client can read DoH URLs out of config.yaml.
        Tun2SocksCore.nativeSetHomeDir(configDir.absolutePath)
        // Register the VpnService with the Go engine BEFORE starting it.
        // hub.Parse triggers synchronous provider fetches whose outbound
        // sockets hit the dialer protect hook — the hook must already be
        // able to reach VpnService.protect() by then, or those sockets
        // route back through the TUN and the engine loops.
        MihomoEngine.nativeSetProtect(vpnService)
        val result = MihomoEngine.nativeStartEngine("127.0.0.1:9090", "")
        if (result != 0) {
            throw RuntimeException("Failed to start engine: ${MihomoEngine.nativeGetLastError()}")
        }
        Timber.d("MihomoInstance: engine started")
    }

    fun startTun2Socks(vpnService: android.net.VpnService, fd: Int) {
        val result = Tun2SocksCore.nativeStartTun2Socks(vpnService, fd, 7890, 1053)
        if (result != 0) {
            throw RuntimeException("Failed to start tun2socks: ${Tun2SocksCore.nativeGetLastError()}")
        }
        Timber.d("MihomoInstance: tun2socks started")
    }

    fun stop() {
        // Shut tun2socks down first so no more packets are flowing into
        // mihomo's mixed listener, then stop the engine, then clear the
        // protect ref.
        Tun2SocksCore.nativeStopTun2Socks()
        MihomoEngine.nativeStopEngine()
        MihomoEngine.nativeSetProtect(null)
        Timber.d("MihomoInstance: engine stopped")
    }

    // Copy bundled GeoX data (geoip.metadb, geosite.dat, country.mmdb,
    // GeoLite2-ASN.mmdb) from assets/geox into the mihomo home dir on
    // first start. Files that already exist are left alone so the user
    // can update them via mihomo's auto-update path without us clobbering
    // the newer copy every connect.
    private fun copyGeoxAssets(context: android.content.Context, configDir: File) {
        val files = listOf(
            "geoip.metadb",
            "geosite.dat",
            "country.mmdb",
            "GeoLite2-ASN.mmdb",
        )
        for (name in files) {
            val target = File(configDir, name)
            if (target.exists() && target.length() > 0) continue
            try {
                context.assets.open("geox/$name").use { input ->
                    target.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
                Timber.d("MihomoInstance: seeded $name from assets (${target.length()} bytes)")
            } catch (e: Exception) {
                Timber.w(e, "MihomoInstance: failed to seed $name from assets")
            }
        }
    }

    // Force mihomo's GeoIP/Geosite download URLs to a jsDelivr-backed CDN.
    // The upstream defaults point at github.com/MetaCubeX/meta-rules-dat
    // release assets, which fail in regions where github is unreachable
    // (e.g. China on first connect). jsDelivr mirrors the repo's `release`
    // branch, which contains the same files as the releases. Only inject
    // when the user hasn't already set their own geox-url block.
    private fun injectGeoxUrl(yaml: String): String {
        if (Regex("(?m)^geox-url:").containsMatchIn(yaml)) return yaml
        val base = "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release"
        val block = buildString {
            appendLine("geox-url:")
            appendLine("  geoip: \"$base/geoip.metadb\"")
            appendLine("  geosite: \"$base/geosite.dat\"")
            appendLine("  mmdb: \"$base/country.mmdb\"")
            appendLine("  asn: \"$base/GeoLite2-ASN.mmdb\"")
        }
        return block + yaml
    }

    fun requestTrafficUpdate(): TrafficStats {
        val tx = MihomoEngine.nativeGetUploadTraffic()
        val rx = MihomoEngine.nativeGetDownloadTraffic()
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
