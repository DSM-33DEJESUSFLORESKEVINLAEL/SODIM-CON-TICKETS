package com.example.sodim

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.OutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {

    private val CHANNEL = "star_bt_channel"
    private val REQUEST_BT_PERMISSIONS = 200

    private val SPP_UUID: UUID =
        UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    private var discoveredDevices = mutableListOf<Map<String, String>>()
    private var isReceiverRegistered = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {

                    "scan" -> {
                        requestBluetoothPermissions()
                        scanBluetooth(result)
                    }

                    "printStarBluetooth" -> {
                        val text = call.argument<String>("text") ?: ""
                        val mac = call.argument<String>("mac") ?: ""
                        val ok = printViaBluetooth(text, mac)
                        result.success(ok)
                    }
                }
            }
    }

    // -------------------------
    // 1. PERMISOS BLUETOOTH
    // -------------------------
    private fun requestBluetoothPermissions() {
        val permissions = arrayOf(
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_CONNECT
        )

        val missing = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), REQUEST_BT_PERMISSIONS)
        }
    }

    // -------------------------
    // 2. ESCANEO DE DISPOSITIVOS
    // -------------------------
    private fun scanBluetooth(result: MethodChannel.Result) {

        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("NO_ADAPTER", "No Bluetooth adapter found", null)
            return
        }

        // Asegurar Bluetooth activado
        if (!adapter.isEnabled) adapter.enable()

        // Limpiar lista previa
        discoveredDevices.clear()

        // Registrar receiver SIN duplicados
        if (!isReceiverRegistered) {
            val filter = IntentFilter(BluetoothDevice.ACTION_FOUND)
            registerReceiver(receiver, filter)
            isReceiverRegistered = true
        }

        // Iniciar búsqueda
        try {
            adapter.startDiscovery()
        } catch (e: SecurityException) {
            result.error("NO_PERMISSION", "Bluetooth Scan permission missing", null)
            return
        }

        // Regresar resultado después de 3 segundos
        window.decorView.postDelayed({
            result.success(discoveredDevices)

            if (isReceiverRegistered) {
                unregisterReceiver(receiver)
                isReceiverRegistered = false
            }

        }, 3000)
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {

            if (intent?.action == BluetoothDevice.ACTION_FOUND) {

                val device: BluetoothDevice? =
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)

                if (device != null && device.name != null) {
                    discoveredDevices.add(
                        mapOf(
                            "name" to device.name,
                            "mac" to device.address
                        )
                    )
                }
            }
        }
    }

    // -------------------------
    // 3. IMPRIMIR
    // -------------------------
  private fun printViaBluetooth(text: String, mac: String): Boolean {
    return try {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        val device: BluetoothDevice = adapter.getRemoteDevice(mac)

        adapter.cancelDiscovery()
        Thread.sleep(300)

        // Buscar canal RFCOMM real de la impresora
        val method = device.javaClass.getMethod("createRfcommSocket", Int::class.java)
        
        // ⭐ Star Micronics normalmente usa canal 1 o 2
        val socket: BluetoothSocket = method.invoke(device, 1) as BluetoothSocket

        socket.connect()

        val os: OutputStream = socket.outputStream
        os.write(text.toByteArray(Charsets.UTF_8))
        os.flush()

        os.close()
        socket.close()

        true
    } catch (e: Exception) {
        e.printStackTrace()
        false
    }
}

}