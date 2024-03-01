import 'package:flutter/material.dart';

import '../helpers/constants.dart';
import '../components/cam_panel.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  createState() => MainViewState();
}

class MainViewState extends State<MainView> {
  Widget _camGrid() {
    return const SliverToBoxAdapter(
      child: SizedBox(
        width: 600,
        height: 600,
        child: Card(
          child: CamPanel(),
        ),
      ),
    );
  }

  //--------------------------------------------------------------------------//
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBgColor,
      appBar: AppBar(
        title: const Text("MyCAM"),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [_camGrid()],
          )
        ],
      ),
    );
  }
}
