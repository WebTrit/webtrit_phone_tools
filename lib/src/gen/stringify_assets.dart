// ignore_for_file: all

class StringifyAssets {
  static const String dartDefineTemplate = "{\n  \"WEBTRIT_APP_DEBUG_LEVEL\": \"ALL\",\n  \"WEBTRIT_APP_DATABASE_LOG_STATEMENTS\": false,\n  \"WEBTRIT_APP_PERIODIC_POLLING\": true,\n  \"WEBTRIT_APP_DEMO_CORE_URL\": \"{{ APP_DEMO_CORE_URL }}\",\n  \"WEBTRIT_APP_CORE_URL\": \"{{ APP_CORE_URL }}\",\n  \"WEBTRIT_APP_NAME\": \"{{ APP_NAME }}\",\n  \"WEBTRIT_APP_GREETING\": \"{{ APP_GREETING }}\",\n  \"WEBTRIT_APP_DESCRIPTION\": \"{{ APP_DESCRIPTION }}\",\n  \"WEBTRIT_APP_TERMS_AND_CONDITIONS_URL\": \"{{ APP_TERMS_AND_CONDITIONS_URL }}\",\n  \"WEBTRIT_APP_SALES_EMAIL\": \"{{ APP_SALES_EMAIL }}\",\n  \"WEBTRIT_ANDROID_RELEASE_UPLOAD_KEYSTORE_PATH\": \"{{ APP_ANDROID_KEYSTORE }}\",\n  \"WEBTRIT_APP_LINK_DOMAIN\": \"app.webtrit.com\"\n}\n";
  static const String flutterLauncherIconsTemplate = "flutter_launcher_icons:\n  android: true\n  image_path_android: \"assets/launcher_icons/android.png\"\n  min_sdk_android: 23\n  adaptive_icon_background: \"{{adaptive_icon_background}}\"\n  adaptive_icon_foreground: \"assets/launcher_icons/ic_foreground.png\"\n  ios: true\n  remove_alpha_ios: true\n  image_path_ios: \"assets/launcher_icons/ios.png\"\n  web:\n    generate: true\n    image_path: \"assets/launcher_icons/web.png\"\n    background_color: \"#FFFFFF\"\n    theme_color: \"{{theme_color}}\"\n";
  static const String flutterNativeSplashTemplate = "flutter_native_splash:\n  color: \"{{background}}\"\n  color_dark: \"{{background}}\"\n  android_12:\n    color: \"{{background}}\"\n    color_dark: \"{{background}}\"\n";
  static const String packageRenameConfigTemplate = "package_rename_config:\n  android:\n    app_name: {{ app_name }}\n    package_name: {{ android_package_name }}\n    override_old_package: {{override_old_package}}\n    lang: kotlin\n  ios:\n    app_name: {{ app_name }}\n    package_name: {{ ios_package_name }}\n";
  static const String readmeTemplate = "# webtrit_phone_keystores\n\n  Keystores for applications are organized by their application id (configurator).\n    An application keystore folder structure created by `keystore-generate` command\n    of [webtrit_phone_tools](https://github.com/WebTrit/webtrit_phone_tools) (KeystoreGenerator).\n  \n  ## Keystore folders\n  \n  { { LIST_OF_APPLICATIONS } }\"\n\n## Android\n\n**Transitioning to PKCS12 Format for KeyStore**\n\nUpgrade to PKCS12 format for KeyStore in Android to achieve better compatibility, security, and management across\ndifferent JDK versions and platforms.\n\n*Command to convert jks to PKCS12:*\n\npassword=\$(jq -r --arg password \"keyPassword\" '.[\$password]' \"upload-keystore-metadata.json\")\n    keytool -importkeystore -noprompt -srckeystore upload-keystore.jks -srcstorepass \$password -destkeystore\n    upload-keystore.p12 -deststoretype PKCS12 -deststorepass \$password\n  \n  ### Links\n  \n  [ Android Studio - Sign your app ](https://developer.android.com/studio/publish/app-signing)\n";
  static const String uploadStoreConnectMetadata = "{\n  \"bundleId\": \"{{ BUNDLE_ID }}\",\n  \"issuer-id\": \"\",\n  \"key_id\": \"\",\n  \"code-signing-identity\": \"\",\n  \"team-id\": \"\"\n}\n";
}