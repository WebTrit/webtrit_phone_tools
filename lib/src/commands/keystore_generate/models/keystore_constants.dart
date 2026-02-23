const commonName = 'KeystoreGenerator';

// Keystore files
const keystoreFiles = [
  firebaseServiceAccount,
  iosAuthKey,
  iosProvision,
  iosCertificates,
  iosCredentials,
  androidPlayServiceAccount,
  androidCredentials,
  androidUploadKeystoreJKS,
  androidUploadKeystoreP12,
];

// Firebase
const firebaseServiceAccount = 'firebase-service-account.json';

// IOS
const iosAuthKey = 'AuthKey_[key_id].p8';
const iosProvision = 'Provision.mobileprovision';
const iosCertificates = 'Certificates.p12';
const iosCredentials = 'upload-store-connect-metadata.json';

// Android
const androidPlayServiceAccount = 'google-play-service-account.json';
const androidCredentials = 'upload-keystore-metadata.json';
const androidUploadKeystoreJKS = 'upload-keystore.jks';
const androidUploadKeystoreP12 = 'upload-keystore.p12';
