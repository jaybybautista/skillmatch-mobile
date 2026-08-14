import '../core/api_client.dart';
import '../models/skill_roadmap.dart';

/// Talks to Api\RoadmapController, which reuses the exact same
/// SkillRoadmapService (and so the exact same suggestions) as the web's
/// Skill Roadmap page.
class SkillRoadmapService {
  final ApiClient _client = ApiClient.instance;

  Future<SkillRoadmap> fetch() async {
    final response = await _client.get('/student/roadmap', authenticated: true);
    return SkillRoadmap.fromJson(response);
  }
}
