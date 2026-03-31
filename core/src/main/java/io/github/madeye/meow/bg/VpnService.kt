package io.github.madeye.meow.bg

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Network
import android.os.Build
import android.os.ParcelFileDescriptor
import io.github.madeye.meow.Core
import io.github.madeye.meow.net.DefaultNetworkListener
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import timber.log.Timber
import java.io.File
import android.net.VpnService as BaseVpnService

class VpnService : BaseVpnService(), BaseService.Interface {
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
        data.mihomoInstance!!.start(configDir)
        startVpn()
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

        // Per-socket VpnService.protect() via JNI callback handles proxy outbound.
        // Also exclude our own app as a safety net.
        try {
            builder.addDisallowedApplication(packageName)
        } catch (_: PackageManager.NameNotFoundException) { }

        active = true
        if (Build.VERSION.SDK_INT >= 29) builder.setMetered(metered)

        val conn = builder.establish() ?: throw NullConnectionException()
        this.conn = conn
        data.mihomoInstance!!.startTun2Socks(this, conn.fd)
    }

    override fun onDestroy() {
        super.onDestroy()
        data.binder.close()
    }
}
