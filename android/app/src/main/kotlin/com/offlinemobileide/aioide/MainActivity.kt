package com.offlinemobileide.aioide

import android.os.Bundle
import com.offlinemobileide.aioide.channels.ProcessChannel
import com.offlinemobileide.aioide.channels.SecretsChannel
import com.offlinemobileide.aioide.channels.StorageChannel
import com.offlinemobileide.aioide.channels.SystemChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * MainActivity
 *
 * Registers all Platform Channels with the Flutter engine.
 * StorageChannel uses ActivityResultLauncher, which must be registered
 * before onCreate — FlutterActivity calls configureFlutterEngine before
 * onCreate, so registration order is correct.
 *
 * Architecture: 02-ARCHITECTURE.md §11.1
 */
class MainActivity : FlutterActivity() {

    private lateinit var processChannel: ProcessChannel
    private lateinit var storageChannel: StorageChannel
    private lateinit var systemChannel: SystemChannel
    private lateinit var secretsChannel: SecretsChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        processChannel = ProcessChannel(this, messenger)
        // StorageChannel requires ComponentActivity (this) for
        // ActivityResultLauncher registration — must be called here,
        // before onCreate fires, so launchers are registered in time.
        storageChannel = StorageChannel(this as androidx.fragment.app.FragmentActivity, messenger)
        systemChannel = SystemChannel(this, messenger)
        secretsChannel = SecretsChannel(this, messenger)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        if (::processChannel.isInitialized) {
            processChannel.cleanup()
        }
        super.onDestroy()
    }
}
