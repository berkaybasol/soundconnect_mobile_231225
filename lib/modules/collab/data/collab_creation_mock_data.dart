import '../domain/collab_discovery_models.dart';
import '../domain/collab_listing_draft.dart';

const collabPublisherMockProfiles = <CollabPublisherProfile>[
  CollabPublisherProfile(
    id: 'publisher-venue-kadikoy',
    name: 'SoundConnect Kadıköy',
    initials: 'SC',
    profileKind: CollabProfileKind.venue,
    subtitle: 'Mekan',
    avatarAsset: 'assets/logotransparent.png',
    rating: 4.8,
    reviewCount: 37,
    completedJobs: 128,
  ),
  CollabPublisherProfile(
    id: 'publisher-bugrasahin',
    name: 'bugrasahin',
    initials: 'BS',
    profileKind: CollabProfileKind.musician,
    subtitle: 'Müzisyen · Gitarist',
    rating: 4.9,
    reviewCount: 18,
    completedJobs: 32,
  ),
  CollabPublisherProfile(
    id: 'publisher-northline-studio',
    name: 'Northline Studio',
    initials: 'NS',
    profileKind: CollabProfileKind.studio,
    subtitle: 'Stüdyo',
    rating: 4.9,
    reviewCount: 42,
    completedJobs: 143,
  ),
];

const collabCreationLocations = <String, String>{
  'Kadıköy, İstanbul': 'İstanbul',
  'Beşiktaş, İstanbul': 'İstanbul',
  'Şişli, İstanbul': 'İstanbul',
  'Çankaya, Ankara': 'Ankara',
  'Konak, İzmir': 'İzmir',
};

const collabCreationRoles = <String>[
  'Vokal',
  'Gitar',
  'Bas Gitar',
  'Davul',
  'Klavye',
  'Ses Mühendisi',
  'Prodüktör',
  'Grup / Ekip',
  'Mekan',
  'Stüdyo',
  'Diğer',
];

const collabCreationGenres = <String>[
  'Rock',
  'Pop',
  'Alternatif',
  'Jazz',
  'Blues',
  'Funk',
  'Soul',
  'Akustik',
  'Elektronik',
  'Diğer',
];
