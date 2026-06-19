const codeSigningIdentityKey = 'code-signing-identity';

/// Throwaway password for the intermediate OpenSSL bundle that is imported into
/// the keychain before re-export. macOS `security import` cannot read an
/// empty-password OpenSSL bundle, so the intermediate must use a non-empty
/// password; the final bundle's password is controlled by `--password`.
const intermediatePkcs12Password = 'csr-finalize-intermediate';
