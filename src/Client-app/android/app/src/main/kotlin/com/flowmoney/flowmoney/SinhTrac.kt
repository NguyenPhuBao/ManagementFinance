package com.flowmoney.flowmoney

import android.app.Activity
import android.content.pm.PackageManager
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.hardware.fingerprint.FingerprintManager
import android.os.Build
import android.os.CancellationSignal
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.util.concurrent.atomic.AtomicBoolean
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Khoá ứng dụng — mở nhanh bằng vân tay (spec `docs/superpowers/specs/2026-10-24-khoa-app-pin-sinh-trac-design.md` mục 6).
 *
 * BiometricPrompt CỦA HỆ ĐIỀU HÀNH (API 28+), không androidx.biometric — không phải đổi MainActivity sang
 * FragmentActivity (G100). Mỗi lần dùng, khoá AES-GCM trong AndroidKeyStore chỉ mở được qua `CryptoObject` sau xác thực
 * sinh trắc MẠNH (MASVS-AUTH-2 / MASWE-0020); thêm vân tay mới → khoá vô hiệu (MASWE-0022); không rơi về mã máy
 * (MASWE-0021). Không ghi nhật ký gì. Trả kết quả bằng map — `{loi: MÃ}` khi hỏng (`docLoiSinhTrac` phía Dart).
 */
class SinhTrac(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val KENH = "flowmoney/sinh_trac"
        private const val TIEN_TO = "flowmoney_khoa_app_"
        private const val KHO = "AndroidKeyStore"
        private const val PHEP = "AES/GCM/NoPadding"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "trangThai" -> result.success(trangThai())
            "bat" -> {
                val id = call.argument<Int>("idaccount")
                val biMat = call.argument<String>("biMat")
                if (id == null || biMat == null) result.success(loi("LOI"))
                else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) result.success(loi("KHONG_HO_TRO"))
                else bat(id, biMat, result)
            }
            "mo" -> {
                val id = call.argument<Int>("idaccount")
                val banMa = call.argument<String>("banMa")
                val iv = call.argument<String>("iv")
                if (id == null || banMa == null || iv == null) result.success(loi("LOI"))
                else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) result.success(loi("KHONG_HO_TRO"))
                else mo(id, banMa, iv, result)
            }
            "xoaHet" -> {
                xoaHet()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun loi(ma: String): Map<String, String> = mapOf("loi" to ma)

    private fun trangThai(): Map<String, Boolean> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return mapOf("hoTro" to false, "daDangKy" to false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bm = activity.getSystemService(BiometricManager::class.java)
                ?: return mapOf("hoTro" to false, "daDangKy" to false)
            val kq = bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            val coPhanCung = kq == BiometricManager.BIOMETRIC_SUCCESS ||
                kq == BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED
            return mapOf("hoTro" to coPhanCung, "daDangKy" to (kq == BiometricManager.BIOMETRIC_SUCCESS))
        }
        // API 28–29: vân tay là sinh trắc mạnh duy nhất hệ điều hành bảo đảm cho CryptoObject.
        @Suppress("DEPRECATION")
        val fm = activity.getSystemService(FingerprintManager::class.java)
        @Suppress("DEPRECATION")
        val coPhanCung = activity.packageManager.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT) &&
            fm != null && fm.isHardwareDetected
        @Suppress("DEPRECATION")
        val daDangKy = coPhanCung && fm!!.hasEnrolledFingerprints()
        return mapOf("hoTro" to coPhanCung, "daDangKy" to daDangKy)
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun taoKhoa(alias: String): SecretKey {
        val b = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            b.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
        }
        val g = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KHO)
        g.init(b.build())
        return g.generateKey()
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun bat(id: Int, biMatB64: String, result: MethodChannel.Result) {
        val cipher = try {
            val alias = TIEN_TO + id
            KeyStore.getInstance(KHO).apply { load(null) }.deleteEntry(alias)
            Cipher.getInstance(PHEP).apply { init(Cipher.ENCRYPT_MODE, taoKhoa(alias)) }
        } catch (e: Exception) {
            result.success(loi("LOI"))
            return
        }
        hoi("Bật mở bằng vân tay", "Chạm vân tay để bật", "Huỷ", cipher, result) { c ->
            val banMa = c.doFinal(Base64.decode(biMatB64, Base64.NO_WRAP))
            mapOf(
                "banMa" to Base64.encodeToString(banMa, Base64.NO_WRAP),
                "iv" to Base64.encodeToString(c.iv, Base64.NO_WRAP),
            )
        }
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun mo(id: Int, banMaB64: String, ivB64: String, result: MethodChannel.Result) {
        val cipher = try {
            val khoa = KeyStore.getInstance(KHO).apply { load(null) }.getKey(TIEN_TO + id, null) as? SecretKey
            // Alias KHÔNG CÒN (đăng xuất xoá nó trước POST rồi bị cắt giữa chừng — M14) ≠ khoá bị vô hiệu (thêm vân tay mới):
            // hai câu báo khác nhau ở màn khoá.
            if (khoa == null) {
                result.success(loi("MAT_KHOA"))
                return
            }
            Cipher.getInstance(PHEP).apply {
                init(Cipher.DECRYPT_MODE, khoa, GCMParameterSpec(128, Base64.decode(ivB64, Base64.NO_WRAP)))
            }
        } catch (e: KeyPermanentlyInvalidatedException) {
            result.success(loi("VO_HIEU"))
            return
        } catch (e: Exception) {
            result.success(loi("LOI"))
            return
        }
        hoi("Mở FlowMoney", "Chạm vân tay để mở khoá", "Dùng mã PIN", cipher, result) { c ->
            mapOf("biMat" to Base64.encodeToString(c.doFinal(Base64.decode(banMaB64, Base64.NO_WRAP)), Base64.NO_WRAP))
        }
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun hoi(
        tieuDe: String,
        phu: String,
        nutPhu: String,
        cipher: Cipher,
        result: MethodChannel.Result,
        xong: (Cipher) -> Map<String, String>,
    ) {
        val daTra = AtomicBoolean(false)
        fun tra(v: Map<String, String>) {
            if (daTra.compareAndSet(false, true)) result.success(v)
        }
        val b = BiometricPrompt.Builder(activity)
            .setTitle(tieuDe)
            .setSubtitle(phu)
            .setNegativeButton(nutPhu, activity.mainExecutor) { _, _ -> tra(loi("HUY")) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            b.setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
        }
        b.build().authenticate(
            BiometricPrompt.CryptoObject(cipher),
            CancellationSignal(),
            activity.mainExecutor,
            @RequiresApi(Build.VERSION_CODES.P)
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult) {
                    val c = r.cryptoObject?.cipher
                    if (c == null) {
                        tra(loi("LOI"))
                        return
                    }
                    try {
                        tra(xong(c))
                    } catch (e: Exception) {
                        tra(loi("LOI"))
                    }
                }

                override fun onAuthenticationError(ma: Int, chu: CharSequence) {
                    tra(
                        loi(
                            when (ma) {
                                BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT,
                                BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT_PERMANENT -> "TAM_KHOA"
                                BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED,
                                BiometricPrompt.BIOMETRIC_ERROR_CANCELED -> "HUY"
                                BiometricPrompt.BIOMETRIC_ERROR_HW_NOT_PRESENT,
                                BiometricPrompt.BIOMETRIC_ERROR_HW_UNAVAILABLE,
                                BiometricPrompt.BIOMETRIC_ERROR_NO_BIOMETRICS -> "KHONG_HO_TRO"
                                else -> "LOI"
                            },
                        ),
                    )
                }
                // onAuthenticationFailed: một lần quét sai — hộp hệ thống tự cho thử lại, không trả gì.
            },
        )
    }

    private fun xoaHet() {
        try {
            val ks = KeyStore.getInstance(KHO).apply { load(null) }
            ks.aliases().toList().filter { it.startsWith(TIEN_TO) }.forEach { ks.deleteEntry(it) }
        } catch (e: Exception) {
            // Bỏ qua — alias sót chỉ là một khoá không ai dùng; lần bật sau xoá trước khi tạo.
        }
    }
}
