/// The prefix an administrator-minted API key carries, so that a leaked one is
/// recognisable at a glance and, here, so a caller can tell which kind of
/// credential it was handed.
const apiKeyPrefix = 'wtc_';

/// How a credential travels.
///
/// A key belongs to a machine and goes in its own header; a token belongs to a
/// person who signed in and goes as a bearer. Telling them apart by their shape
/// is what lets one command serve both, and it is written once here rather than
/// guessed at each call site - a request that presents a key as a bearer is not
/// refused with an explanation, it is simply not recognised.
Map<String, String> credentialHeader(String credential) {
  return credential.startsWith(apiKeyPrefix)
      ? {'X-Api-Key': credential}
      : {'Authorization': 'Bearer $credential'};
}
