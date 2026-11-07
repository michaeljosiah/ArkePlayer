/// Build-time catalogue authority and storage scope. A development serial never
/// competes with the shipped production catalogue (SPEC-058 R-31, Player #50).
enum CatalogueChannel {
  production,
  development;

  static CatalogueChannel parse(String value) => switch (value) {
    'production' => production,
    'development' => development,
    _ => throw ArgumentError.value(value, 'ARKE_CATALOGUE_CHANNEL', 'Unknown catalogue channel'),
  };

  Uri get url => Uri.parse(switch (this) {
    production => 'https://github.com/michaeljosiah/ArkeStudio/releases/download/arke-player-worlds/catalogue.json',
    development => 'https://aonik-dev-api.delightfulisland-9fd7c1e7.uksouth.azurecontainerapps.io/publishing/channels/arke-worlds-dev/catalogue.json',
  });

  String get bundledCatalogue => this == production ? 'assets/worlds/catalogue.json' : 'assets/worlds/catalogue-dev.json';
  String get storageFolder => this == production ? '' : 'arke-worlds-dev';
  String get preferencePrefix => this == production ? 'arke.' : 'arke.dev.';
  String get dailyCheck => this == production ? 'studio.arke.player.daily-check' : 'studio.arke.player.dev.daily-check';
}
