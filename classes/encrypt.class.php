<?
/*************************************************************************|
|--------------- Encryption class ----------------------------------------|
|*************************************************************************|

This class handles encryption and decryption, that's all folks.

Hardened to use authenticated encryption (Encrypt-then-MAC): the ciphertext is
accompanied by an HMAC-SHA256 that is verified (in constant time) before the
ciphertext is ever decrypted. This prevents tampering / forgery of the data
this class protects (the login session cookie) and closes off padding/ciphertext
manipulation attacks against the unauthenticated CBC mode used previously.

|*************************************************************************/

if (!extension_loaded('mcrypt')) {
	die('Mcrypt Extension not loaded.');
}

class CRYPT {
	// MAC key, derived from ENCKEY so no additional configuration is required
	// and it stays distinct from the encryption key.
	private static function mac_key($Key) {
		return hash_hmac('sha256', 'gazelle-mac-v1', $Key, true);
	}

	public function encrypt($Str, $Key = ENCKEY) {
		srand();
		$Str = str_pad($Str, 32 - strlen($Str));
		$IVSize = mcrypt_get_iv_size(MCRYPT_RIJNDAEL_128, MCRYPT_MODE_CBC);
		$IV = mcrypt_create_iv($IVSize, MCRYPT_RAND);
		$CryptStr = mcrypt_encrypt(MCRYPT_RIJNDAEL_128, $Key, $Str, MCRYPT_MODE_CBC, $IV);
		$Payload = $IV.$CryptStr;
		// Encrypt-then-MAC: authenticate the IV and ciphertext together.
		$MAC = hash_hmac('sha256', $Payload, self::mac_key($Key), true);
		return base64_encode($MAC.$Payload);
	}

	public function decrypt($CryptStr, $Key = ENCKEY) {
		if ($CryptStr === '' || $CryptStr === null) {
			return '';
		}
		$Raw = base64_decode($CryptStr, true);
		// Need at least the 32-byte MAC + 16-byte IV + one cipher block.
		if ($Raw === false || strlen($Raw) <= 48) {
			return '';
		}
		$MAC = substr($Raw, 0, 32);
		$Payload = substr($Raw, 32);
		$Expected = hash_hmac('sha256', $Payload, self::mac_key($Key), true);
		if (!hash_equals($Expected, $MAC)) {
			// Tampered, forged, or an old pre-MAC cookie: treat as invalid.
			return '';
		}
		$IV = substr($Payload, 0, 16);
		$CryptStr = substr($Payload, 16);
		return trim(mcrypt_decrypt(MCRYPT_RIJNDAEL_128, $Key, $CryptStr, MCRYPT_MODE_CBC, $IV));
	}
} // class ENCRYPT()
?>
