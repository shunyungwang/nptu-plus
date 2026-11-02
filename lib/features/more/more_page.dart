/// 「更多」分頁 — 次要功能入口。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_spacing.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('更多')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          ListTile(
            leading: const Icon(Icons.class_outlined),
            title: const Text('選課查詢'),
            subtitle: const Text('已選課程清單 / 選課結果'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(kRouteCourseSelection),
          ),
          ListTile(
            leading: const Icon(Icons.history_edu_outlined),
            title: const Text('出缺勤'),
            subtitle: const Text('曠課、請假紀錄查詢'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(kRouteAttendance),
          ),
          ListTile(
            leading: const Icon(Icons.event_busy_outlined),
            title: const Text('請假申請'),
            subtitle: const Text('新增與取消請假'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(kRouteLeaveApplication),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('個人資料'),
            subtitle: const Text('學籍 / 系所 / 班級'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(kRouteProfile),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('設定'),
            subtitle: const Text('主題 / 登出'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(kRouteSettings),
          ),
        ],
      ),
    );
  }
}
