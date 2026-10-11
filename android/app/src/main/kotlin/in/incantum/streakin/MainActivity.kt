package `in`.incantum.streakin

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // We have migrated to a custom sharedPreferencesName ('biometric_storage_v2').
        // However, flutter_secure_storage internally attempts to migrate old keys from the
        // default 'FlutterSecureStorage.xml' file if it exists. If that old file is corrupted
        // (Tink master key invalidated), the plugin crashes during this migration check.
        // Since we no longer use the default file, we unconditionally delete it here to
        // guarantee a clean initialization.
        deleteObsoleteCorruptedPrefs()
        super.onCreate(savedInstanceState)
    }

    private fun deleteObsoleteCorruptedPrefs() {
        try {
            val prefsDir = applicationContext.filesDir.parentFile?.let {
                java.io.File(it, "shared_prefs")
            } ?: return
            
            val prefName = "FlutterSecureStorage"
            val prefsFile = java.io.File(prefsDir, "$prefName.xml")
            if (prefsFile.exists()) {
                val deleted = prefsFile.delete()
                Log.i("Streakin.MainActivity", "Deleted obsolete secure storage file: $deleted")
            }
            
            val backupFile = java.io.File(prefsDir, "$prefName.xml.bak")
            if (backupFile.exists()) {
                backupFile.delete()
            }
        } catch (e: Exception) {
            Log.e("Streakin.MainActivity", "Failed to delete obsolete secure storage file: $e")
        }
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "streakin.native")
            .setMethodCallHandler { call, result ->
                if (call.method == "clearCorruptedBiometrics") {
                    try {
                        val prefsDir = applicationContext.filesDir.parentFile?.let {
                            java.io.File(it, "shared_prefs")
                        }
                        if (prefsDir != null) {
                            val prefsFile = java.io.File(prefsDir, "biometric_storage_v2.xml")
                            val backupFile = java.io.File(prefsDir, "biometric_storage_v2.xml.bak")
                            val deleted1 = if (prefsFile.exists()) prefsFile.delete() else false
                            val deleted2 = if (backupFile.exists()) backupFile.delete() else false
                            Log.i("Streakin.MainActivity", "Cleared corrupted biometrics: $deleted1, $deleted2")
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("Streakin.MainActivity", "Failed to clear biometrics: $e")
                        result.error("DELETE_FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
