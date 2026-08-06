import '../domain/collab_application_models.dart';
import '../domain/collab_discovery_models.dart';

const collabApplicantMockProfiles = <CollabApplicantProfile>[
  CollabApplicantProfile(
    id: 'profile-bugrasahin',
    name: 'bugrasahin',
    initials: 'BS',
    profileKind: CollabProfileKind.musician,
    specialty: 'Gitarist',
    rating: 4.9,
    reviewCount: 18,
    completedJobs: 32,
  ),
  CollabApplicantProfile(
    id: 'profile-acoustic-route',
    name: 'Acoustic Route',
    initials: 'AR',
    profileKind: CollabProfileKind.band,
    specialty: 'Akustik Grup',
    rating: 4.7,
    reviewCount: 11,
    completedJobs: 15,
  ),
];

const collabMockPhoneNumber = '+90 555 123 45 67';

const collabMockApplicationMessage =
    'Merhaba, ilanınızı gördüm ve ilgimi çekti. Uzun süredir sahne '
    'tecrübem var, repertuvarınıza kolayca uyum sağlayabilirim. Detayları '
    'konuşmak için sabırsızlanıyorum. İyi çalışmalar!';
