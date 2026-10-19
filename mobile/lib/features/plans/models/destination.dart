import 'package:finance_tracker/features/plans/widgets/plan_scene.dart';

/// A place to plan a trip to, from a built-in list (no network needed).
class Destination {
  const Destination(this.name, this.country, this.blurb, this.style);

  final String name;
  final String country;
  final String blurb;
  final SceneStyle style;

  /// How it's stored on a plan, e.g. "Tokyo, Japan".
  String get label => '$name, $country';

  /// The catalog entry for a plan's destination text, if it's one of ours.
  static Destination? find(String text) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return null;
    for (final d in all) {
      if (d.label.toLowerCase() == t || d.name.toLowerCase() == t) return d;
    }
    return null;
  }

  /// Best matches for what's typed: names first, then countries.
  static List<Destination> search(String query, {int limit = 6}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final byName = all.where((d) => d.name.toLowerCase().contains(q));
    final byCountry = all.where(
      (d) =>
          !d.name.toLowerCase().contains(q) &&
          d.country.toLowerCase().contains(q),
    );
    return [...byName, ...byCountry].take(limit).toList();
  }

  static const all = [
    // Philippines
    Destination(
      'Boracay',
      'Aklan',
      'White Beach, sunsets and island hopping.',
      SceneStyle.beach,
    ),
    Destination(
      'El Nido',
      'Palawan',
      'Lagoons, limestone cliffs and island tours.',
      SceneStyle.beach,
    ),
    Destination(
      'Coron',
      'Palawan',
      'Shipwreck dives, Kayangan Lake and hot springs.',
      SceneStyle.beach,
    ),
    Destination(
      'Puerto Princesa',
      'Palawan',
      'Underground river and Honda Bay.',
      SceneStyle.beach,
    ),
    Destination(
      'Siargao',
      'Surigao del Norte',
      'Surfing at Cloud 9 and island hopping.',
      SceneStyle.beach,
    ),
    Destination(
      'Bohol',
      'Philippines',
      'Chocolate Hills, tarsiers and Panglao beaches.',
      SceneStyle.beach,
    ),
    Destination(
      'Cebu City',
      'Cebu',
      'Lechon, Kawasan Falls and Oslob.',
      SceneStyle.city,
    ),
    Destination(
      'Baguio',
      'Benguet',
      'Cool weather, strawberries and pine trees.',
      SceneStyle.mountains,
    ),
    Destination(
      'Sagada',
      'Mountain Province',
      'Hanging coffins, caves and sunrise at Kiltepan.',
      SceneStyle.mountains,
    ),
    Destination(
      'Tagaytay',
      'Cavite',
      'Taal views, bulalo and a cool breeze.',
      SceneStyle.mountains,
    ),
    Destination(
      'Batanes',
      'Philippines',
      'Rolling hills, stone houses and sea cliffs.',
      SceneStyle.mountains,
    ),
    Destination(
      'La Union',
      'Philippines',
      'Surf town at San Juan and chill cafés.',
      SceneStyle.sunset,
    ),
    Destination(
      'Vigan',
      'Ilocos Sur',
      'Calle Crisologo, kalesa rides and empanada.',
      SceneStyle.city,
    ),
    Destination(
      'Manila',
      'Metro Manila',
      'Intramuros, food trips and the bay.',
      SceneStyle.city,
    ),
    Destination(
      'Davao City',
      'Davao del Sur',
      'Durian, Mt. Apo and Samal Island.',
      SceneStyle.city,
    ),
    Destination(
      'Dumaguete',
      'Negros Oriental',
      'Rizal Boulevard and Apo Island dives.',
      SceneStyle.sunset,
    ),
    Destination(
      'Siquijor',
      'Philippines',
      'Waterfalls, old trees and quiet beaches.',
      SceneStyle.beach,
    ),
    Destination(
      'Puerto Galera',
      'Oriental Mindoro',
      'White Beach and snorkeling spots.',
      SceneStyle.beach,
    ),
    Destination(
      'Camiguin',
      'Philippines',
      'Volcanoes, sandbar and hot springs.',
      SceneStyle.beach,
    ),
    Destination(
      'Iloilo City',
      'Iloilo',
      'Old churches, La Paz batchoy and Guimaras.',
      SceneStyle.city,
    ),
    // Abroad
    Destination(
      'Tokyo',
      'Japan',
      'Shibuya, sushi, temples and day trips to Fuji.',
      SceneStyle.city,
    ),
    Destination(
      'Osaka',
      'Japan',
      'Street food in Dotonbori and Universal Studios.',
      SceneStyle.city,
    ),
    Destination(
      'Kyoto',
      'Japan',
      'Temples, bamboo groves and tea houses.',
      SceneStyle.mountains,
    ),
    Destination(
      'Hokkaido',
      'Japan',
      'Snow, hot springs and fresh seafood.',
      SceneStyle.mountains,
    ),
    Destination(
      'Seoul',
      'South Korea',
      'Palaces, cafés, K-food and shopping.',
      SceneStyle.city,
    ),
    Destination(
      'Jeju',
      'South Korea',
      'Volcanic coast, tangerines and beaches.',
      SceneStyle.beach,
    ),
    Destination(
      'Taipei',
      'Taiwan',
      'Night markets, Taipei 101 and Jiufen.',
      SceneStyle.city,
    ),
    Destination(
      'Hong Kong',
      'China',
      'Skyline views, dim sum and Disneyland.',
      SceneStyle.city,
    ),
    Destination(
      'Singapore',
      'Singapore',
      'Gardens by the Bay, hawker food and Sentosa.',
      SceneStyle.city,
    ),
    Destination(
      'Bangkok',
      'Thailand',
      'Temples, markets and street food.',
      SceneStyle.city,
    ),
    Destination(
      'Phuket',
      'Thailand',
      'Beaches, island tours and night life.',
      SceneStyle.beach,
    ),
    Destination(
      'Bali',
      'Indonesia',
      'Beaches, rice terraces and temples.',
      SceneStyle.beach,
    ),
    Destination(
      'Da Nang',
      'Vietnam',
      'My Khe Beach, Ba Na Hills and Hoi An.',
      SceneStyle.beach,
    ),
    Destination(
      'Hanoi',
      'Vietnam',
      'Old Quarter, pho and Ha Long Bay trips.',
      SceneStyle.city,
    ),
    Destination(
      'Kuala Lumpur',
      'Malaysia',
      'Petronas Towers and Batu Caves.',
      SceneStyle.city,
    ),
    Destination(
      'Maldives',
      'Maldives',
      'Overwater villas and clear lagoons.',
      SceneStyle.beach,
    ),
    Destination(
      'Dubai',
      'UAE',
      'Burj Khalifa, desert safari and malls.',
      SceneStyle.sunset,
    ),
    Destination(
      'Sydney',
      'Australia',
      'Opera House, Bondi and harbour walks.',
      SceneStyle.sunset,
    ),
    Destination(
      'Paris',
      'France',
      'Eiffel Tower, museums and cafés.',
      SceneStyle.city,
    ),
    Destination(
      'London',
      'United Kingdom',
      'Museums, markets and the Thames.',
      SceneStyle.city,
    ),
    Destination(
      'New York',
      'USA',
      'Times Square, Central Park and Broadway.',
      SceneStyle.city,
    ),
    Destination(
      'Swiss Alps',
      'Switzerland',
      'Mountain trains, lakes and chocolate.',
      SceneStyle.mountains,
    ),
  ];
}
