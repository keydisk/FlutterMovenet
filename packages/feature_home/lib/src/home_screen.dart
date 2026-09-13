import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movenet_core/movenet_core.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('MoveNet Coach'),
      actions: [
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'AI 자세 분석',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('풀업 · 스쿼트 · 푸쉬업의 반복 횟수와 자세를 기기 안에서 분석합니다.'),
              const SizedBox(height: 28),
              _ActionCard(
                icon: Icons.videocam_outlined,
                title: '실시간 카메라 분석',
                subtitle: '스켈레톤, 운동 종류, 전체 반복 횟수와 코칭',
                onTap: () => context.push('/camera'),
              ),
              const SizedBox(height: 16),
              _ActionCard(
                icon: Icons.video_library_outlined,
                title: '앨범에서 영상 분석',
                subtitle: '영상 전체 프레임을 샘플링해 최종 보고서 생성',
                onTap: () => context.push('/video'),
              ),
              const SizedBox(height: 28),
              const SectionCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.privacy_tip_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('분석은 온디바이스에서 처리됩니다. 의료 진단이 아닌 운동 참고용입니다.'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SectionCard(
        child: Row(
          children: [
            CircleAvatar(radius: 30, child: Icon(icon, size: 30)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
