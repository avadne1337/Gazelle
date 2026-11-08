<?
/*************************************************************************|
|--------------- Encryption class ----------------------------------------|
|*************************************************************************|

This class handles encryption and decryption, that's all folks.

Uses authenticated encryption (Encrypt-then-MAC): AES-256-CBC for confidentiality
plus an HMAC-SHA256 that is verified in constant time BEFORE the ciphertext is
decrypted. Ported from the old mcrypt extension (removed in PHP 7.2/8.0) to
OpenSSL. The on-disk/cookie format changed with this port, so pre-existing
session cookies are treated as invalid (users simply log in again).

|*************************************************************************/

if (!extension_loaded('openssl')) {
	die('OpenSSL Extension not loaded.');
}

class CRYPT {
	const CIPHER = 'aes-256-cbc';

	// Derive a 32-byte AES-256 key and a separate MAC key from ENCKEY.
	private static function enc_key($Key) {
		return hash('sha256', 'gazelle-enc-v1'.$Key, true);
	}
	private static function mac_key($Key) {
		return hash_hmac('sha256', 'gazelle-mac-v1', $Key, true);
	}

	public function encrypt($Str, $Key = ENCKEY) {
		$IV = random_bytes(16);
		$CryptStr = openssl_encrypt($Str, self::CIPHER, self::enc_key($Key), OPENSSL_RAW_DATA, $IV);
		if ($CryptStr === false) {
			return '';
		}
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
			// Tampered, forged, or an old pre-port cookie: treat as invalid.
			return '';
		}
		$IV = substr($Payload, 0, 16);
		$CipherText = substr($Payload, 16);
		$Plain = openssl_decrypt($CipherText, self::CIPHER, self::enc_key($Key), OPENSSL_RAW_DATA, $IV);
		return $Plain === false ? '' : $Plain;
	}
} // class ENCRYPT()
?>
