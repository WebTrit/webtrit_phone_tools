const appStoreConnectApiUrl = 'https://api.appstoreconnect.apple.com/v1';

const appleDistributionCertificateType = 'DISTRIBUTION';
const appStoreProfileType = 'IOS_APP_STORE';

const activeProfileState = 'ACTIVE';

const bundleIdMetadataKey = 'bundleId';
const issuerIdMetadataKey = 'issuer-id';
const keyIdMetadataKey = 'key_id';
const codeSigningIdentityMetadataKey = 'code-signing-identity';
const teamIdMetadataKey = 'team-id';

String authKeyFileName(String keyId) => 'AuthKey_$keyId.p8';
