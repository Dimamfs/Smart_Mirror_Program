package com.smartmirror.smart_mirror_app

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import io.flutter.plugin.common.MethodChannel

class HotspotPlugin(private val context: Context) {

    private val cm: ConnectivityManager by lazy {
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }
    private var callback: ConnectivityManager.NetworkCallback? = null

    fun onMethodCall(method: String, args: Map<String, Any?>?, result: MethodChannel.Result) {
        when (method) {
            "canAutoJoin" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            "join" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    result.success(false)
                    return
                }
                val ssid = args?.get("ssid") as? String
                val passphrase = args?.get("passphrase") as? String
                if (ssid == null || passphrase == null) { result.success(false); return }
                join(ssid, passphrase, result)
            }
            "leave" -> { leave(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun join(ssid: String, passphrase: String, result: MethodChannel.Result) {
        leave() // tear down any previous request

        val specifier = WifiNetworkSpecifier.Builder()
            .setSsid(ssid)
            .setWpa2Passphrase(passphrase)
            .build()

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifier)
            .build()

        var settled = false

        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                if (settled) return
                settled = true
                // Bind process so HTTP to 192.168.42.1 routes over the AP, not cellular.
                cm.bindProcessToNetwork(network)
                result.success(true)
            }

            override fun onUnavailable() {
                if (settled) return
                settled = true
                result.success(false)
            }
        }
        callback = cb
        cm.requestNetwork(request, cb)
    }

    fun leave() {
        callback?.let {
            try { cm.unregisterNetworkCallback(it) } catch (_: Exception) {}
            callback = null
        }
        cm.bindProcessToNetwork(null)
    }
}
