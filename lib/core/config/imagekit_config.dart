/// Base URL ImageKit serves this account's card pictures from.
///
/// The private key is deliberately absent. It is a server secret held by the
/// upload-image Edge Function: a key that ships inside an APK is a key anyone
/// can extract, and it can spend the whole account.
const String imageKitUrlEndpoint = 'https://ik.imagekit.io/7sn';

/// Public key for this ImageKit account.
///
/// Uploads are signed server-side, so the app never signs anything itself.
/// The key identifies the account and is what a future client-side upload
/// (with a token endpoint) would be configured with.
const String imageKitPublicKey = 'public_Q1xx51QTQ5Osrfj3GnjGFZ3YIxk=';
