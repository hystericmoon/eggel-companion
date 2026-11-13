package com.eggelcompanion.eggel_companion

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque
import java.util.UUID

/**
 * Raw GATT access to the speaker's Tuya service (0xFD50) for the "eggel/ble"
 * channel, the same contract as windows/runner/ble_channel.cpp: connect,
 * write, disconnect, and poll() which drains queued events. The Tuya protocol
 * itself lives in Dart (lib/link).
 *
 * Events: {type: status, state: scanning|connecting|connected|disconnected|
 * failed, message}, {type: packetSize, value}, {type: data, data: bytes}.
 */
@SuppressLint("MissingPermission") // checked in hasPermissions() before use
class BleBridge(private val activity: Activity) {
    private val main = Handler(Looper.getMainLooper())
    private val events = ArrayList<Map<String, Any>>()
    private val writes = ArrayDeque<ByteArray>()
    private var writing = false

    private var gatt: BluetoothGatt? = null
    private var writeChar: BluetoothGattCharacteristic? = null
    private var scanning = false
    private var connected = false
    private var stopped = true
    private var mtu = 23

    private val adapter: BluetoothAdapter?
        get() = (activity.getSystemService(Activity.BLUETOOTH_SERVICE) as BluetoothManager).adapter

    private val scanTimeout = Runnable {
        if (scanning) {
            stopScan()
            status("failed", "Speaker not found. It must be on and not connected to a phone.")
        }
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> { connect(); result.success(null) }
            "disconnect" -> { disconnect(); result.success(null) }
            "write" -> {
                call.argument<ByteArray>("data")?.let { enqueue(it) }
                result.success(null)
            }
            "poll" -> result.success(drain())
            else -> result.notImplemented()
        }
    }

    // ---- events -----------------------------------------------------------

    private fun push(e: Map<String, Any>) = synchronized(events) { events.add(e); Unit }

    private fun status(state: String, message: String = "") =
        push(mapOf("type" to "status", "state" to state, "message" to message))

    private fun drain(): List<Map<String, Any>> = synchronized(events) {
        val out = ArrayList(events)
        events.clear()
        out
    }

    // ---- permissions ------------------------------------------------------

    private fun neededPermissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= 31) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    private fun hasPermissions() = neededPermissions().all {
        activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
    }

    fun onPermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_CODE) return
        if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            startScan()
        } else {
            status("failed", "Bluetooth permission was not granted")
        }
    }

    // ---- connect ----------------------------------------------------------

    private fun connect() {
        if (!stopped) return
        stopped = false
        connected = false
        synchronized(writes) { writes.clear(); writing = false }
        val a = adapter
        if (a == null || !a.isEnabled) {
            stopped = true
            status("failed", "Bluetooth is off")
            return
        }
        if (!hasPermissions()) {
            status("scanning", "Waiting for Bluetooth permission")
            activity.requestPermissions(neededPermissions(), REQUEST_CODE)
            return
        }
        startScan()
    }

    private fun startScan() {
        if (stopped || scanning) return
        val scanner = adapter?.bluetoothLeScanner
        if (scanner == null) {
            stopped = true
            status("failed", "Bluetooth is off")
            return
        }
        status("scanning", "Looking for the speaker")
        scanning = true
        scanner.startScan(null, ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(), scanCallback)
        main.postDelayed(scanTimeout, 20_000)
    }

    private fun stopScan() {
        if (!scanning) return
        scanning = false
        main.removeCallbacks(scanTimeout)
        try { adapter?.bluetoothLeScanner?.stopScan(scanCallback) } catch (_: Exception) {}
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, r: ScanResult) {
            val name = r.scanRecord?.deviceName ?: r.device.name ?: ""
            val hasService = r.scanRecord?.serviceUuids?.any { it.uuid == SERVICE } == true
            if (!scanning || !(hasService || name.startsWith("Eggel"))) return
            stopScan()
            status("connecting", "Connecting")
            gatt = r.device.connectGatt(activity, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        }

        override fun onScanFailed(errorCode: Int) {
            scanning = false
            main.removeCallbacks(scanTimeout)
            stopped = true
            status("failed", "Bluetooth scan failed ($errorCode)")
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, st: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED && st == BluetoothGatt.GATT_SUCCESS) {
                if (!g.requestMtu(247)) g.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED || st != BluetoothGatt.GATT_SUCCESS) {
                val wasConnected = connected
                val wasStopped = stopped
                cleanup()
                if (!wasStopped) {
                    if (wasConnected) status("disconnected", "Connection lost")
                    else status("failed", "Could not connect to the speaker (status $st). It may need a power cycle.")
                }
            }
        }

        override fun onMtuChanged(g: BluetoothGatt, newMtu: Int, st: Int) {
            if (st == BluetoothGatt.GATT_SUCCESS) mtu = newMtu
            g.discoverServices()
        }

        override fun onServicesDiscovered(g: BluetoothGatt, st: Int) {
            val service = g.getService(SERVICE)
            val w = service?.getCharacteristic(WRITE_CHAR)
            val n = service?.getCharacteristic(NOTIFY_CHAR)
            if (st != BluetoothGatt.GATT_SUCCESS || w == null || n == null) {
                fail("Speaker service not found")
                return
            }
            writeChar = w
            g.setCharacteristicNotification(n, true)
            val cccd = n.getDescriptor(CCCD)
            if (cccd == null) {
                fail("Could not subscribe")
                return
            }
            writeDescriptor(g, cccd, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
        }

        override fun onDescriptorWrite(g: BluetoothGatt, d: BluetoothGattDescriptor, st: Int) {
            if (st != BluetoothGatt.GATT_SUCCESS) {
                fail("Could not subscribe (the speaker may need a power cycle)")
                return
            }
            connected = true
            push(mapOf("type" to "packetSize", "value" to maxOf(20, mtu - 3)))
            status("connected")
        }

        @Deprecated("Used below API 33")
        override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic) {
            if (Build.VERSION.SDK_INT < 33) c.value?.let { push(mapOf("type" to "data", "data" to it.copyOf())) }
        }

        override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray) {
            push(mapOf("type" to "data", "data" to value.copyOf()))
        }

        override fun onCharacteristicWrite(g: BluetoothGatt, c: BluetoothGattCharacteristic, st: Int) {
            synchronized(writes) { writing = false }
            if (st != BluetoothGatt.GATT_SUCCESS) {
                fail("Write failed")
                return
            }
            pump()
        }
    }

    @Suppress("DEPRECATION")
    private fun writeDescriptor(g: BluetoothGatt, d: BluetoothGattDescriptor, value: ByteArray) {
        if (Build.VERSION.SDK_INT >= 33) {
            g.writeDescriptor(d, value)
        } else {
            d.value = value
            g.writeDescriptor(d)
        }
    }

    // ---- writes -----------------------------------------------------------

    private fun enqueue(data: ByteArray) {
        synchronized(writes) { writes.add(data) }
        pump()
    }

    @Suppress("DEPRECATION")
    private fun pump() {
        val g = gatt ?: return
        val c = writeChar ?: return
        if (!connected) return
        val next = synchronized(writes) {
            if (writing || writes.isEmpty()) return
            writing = true
            writes.poll()
        }
        val ok = if (Build.VERSION.SDK_INT >= 33) {
            g.writeCharacteristic(c, next, BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE) == 0
        } else {
            c.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            c.value = next
            g.writeCharacteristic(c)
        }
        if (!ok) {
            synchronized(writes) { writing = false }
            fail("Write failed")
        }
    }

    // ---- teardown ---------------------------------------------------------

    private fun fail(message: String) {
        val wasStopped = stopped
        cleanup()
        if (!wasStopped) status("failed", message)
    }

    private fun cleanup() {
        stopScan()
        stopped = true
        connected = false
        writeChar = null
        synchronized(writes) { writes.clear(); writing = false }
        gatt?.let {
            try { it.disconnect() } catch (_: Exception) {}
            try { it.close() } catch (_: Exception) {}
        }
        gatt = null
    }

    private fun disconnect() {
        cleanup() // marks stopped first, so no "failed" event is sent
    }

    companion object {
        private const val REQUEST_CODE = 4711
        private val SERVICE = UUID.fromString("0000fd50-0000-1000-8000-00805f9b34fb")
        private val WRITE_CHAR = UUID.fromString("00000001-0000-1001-8001-00805f9b07d0")
        private val NOTIFY_CHAR = UUID.fromString("00000002-0000-1001-8001-00805f9b07d0")
        private val CCCD = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }
}
