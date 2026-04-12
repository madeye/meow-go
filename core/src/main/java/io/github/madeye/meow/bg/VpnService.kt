package io.github.madeye.meow.bg

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Network
import android.os.Build
import android.os.ParcelFileDescriptor
import io.github.madeye.meow.Core
import io.github.madeye.meow.net.DefaultNetworkListener
import io.github.madeye.meow.preference.DataStore
import org.json.JSONArray
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import timber.log.Timber
import kotlin.coroutines.CoroutineContext
import java.io.File
import android.net.VpnService as BaseVpnService

class VpnService : BaseVpnService(), BaseService.Interface {
    private val job = SupervisorJob()
    override val coroutineContext: CoroutineContext = Dispatchers.Main.immediate + job

    companion object {
        private const val VPN_MTU = 1500
        private const val PRIVATE_VLAN4_CLIENT = "172.19.0.1"
        private const val PRIVATE_VLAN4_ROUTER = "172.19.0.2"
        private const val PRIVATE_VLAN6_CLIENT = "fdfe:dcba:9876::1"
        private const val PRIVATE_VLAN6_ROUTER = "fdfe:dcba:9876::2"
    }

    inner class NullConnectionException : NullPointerException(), BaseService.ExpectedException {
        override fun getLocalizedMessage() = "Reboot required"
    }

    override val data = BaseService.Data(this)
    override val tag: String get() = "MihomoVpnService"
    override fun createNotification(profileName: String): ServiceNotification =
        ServiceNotification(this, profileName, "service-vpn")

    private var conn: ParcelFileDescriptor? = null
    private var active = false
    private var metered = false
    @Volatile
    private var underlyingNetwork: Network? = null

    override fun onBind(intent: Intent) = when (intent.action) {
        SERVICE_INTERFACE -> super<BaseVpnService>.onBind(intent)
        else -> super<BaseService.Interface>.onBind(intent)
    }

    override fun onRevoke() = stopRunner()

    override fun killProcesses(scope: CoroutineScope) {
        super.killProcesses(scope)
        active = false
        scope.launch { DefaultNetworkListener.stop(this) }
        conn?.close()
        conn = null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int =
        super<BaseService.Interface>.onStartCommand(intent, flags, startId)

    override suspend fun preInit() {
        if (prepare(this) != null) throw NullConnectionException()
        DefaultNetworkListener.start(this) { underlyingNetwork = it }
    }

    override suspend fun startProcesses() {
        val configDir = File(Core.deviceStorage.noBackupFilesDir, "mihomo")
        configDir.mkdirs()
        // Establish the VPN (TUN) first so VpnService.protect() is live
        // before the mihomo engine boots. mihomo's hub.Parse triggers
        // synchronous provider fetches, which call the dialer protect
        // hook — if the hook fires before we've stored the VpnService
        // global ref, every proxy-bound socket routes back through the
        // TUN and the engine loops on itself.
        startVpn()
        data.mihomoInstance!!.start(configDir, this)
        data.mihomoInstance!!.startTun2Socks(this, conn!!.fd)
    }

    override val isVpnService get() = true

    private fun startVpn() {
        val builder = Builder()
            .setSession("Mihomo VPN")
            .setMtu(VPN_MTU)
            .addAddress(PRIVATE_VLAN4_CLIENT, 30)
            .addDnsServer(PRIVATE_VLAN4_ROUTER)
            .addAddress(PRIVATE_VLAN6_CLIENT, 126)
            .addRoute("0.0.0.0", 0)
            .addRoute("::", 0)

        // Per-app VPN routing
        val perAppPackages: Set<String> = try {
            JSONArray(DataStore.perAppPackages).let { arr ->
                (0 until arr.length()).map { arr.getString(it) }.toSet()
            }
        } catch (_: Exception) { emptySet() }

        if (perAppPackages.isEmpty()) {
            // Feature disabled — exclude self only (default behavior)
            try { builder.addDisallowedApplication(packageName) }
            catch (_: PackageManager.NameNotFoundException) { }
        } else when (DataStore.perAppMode) {
            "proxy" -> {
                // Only selected apps go through VPN (cannot mix with addDisallowedApplication)
                for (pkg in perAppPackages) {
                    if (pkg == packageName) continue
                    try { builder.addAllowedApplication(pkg) }
                    catch (_: PackageManager.NameNotFoundException) { }
                }
            }
            else -> {
                // "bypass" — all apps except selected + self
                try { builder.addDisallowedApplication(packageName) }
                catch (_: PackageManager.NameNotFoundException) { }
                for (pkg in perAppPackages) {
                    try { builder.addDisallowedApplication(pkg) }
                    catch (_: PackageManager.NameNotFoundException) { }
                }
            }
        }

        active = true
        if (Build.VERSION.SDK_INT >= 29) builder.setMetered(metered)

        val conn = builder.establish() ?: throw NullConnectionException()
        this.conn = conn
    }

    override fun onDestroy() {
        cancel()
        super.onDestroy()
        data.binder.close()
    }
}
