import 'package:flutter/material.dart';

class TaskScaffold extends StatelessWidget {
  const TaskScaffold({super.key, required this.title, required this.child, this.actions = const []});
  final String title;
  final Widget child;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title), actions: actions), body: SafeArea(child: child));
}
