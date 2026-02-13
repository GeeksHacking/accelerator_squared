import 'package:accelerator_squared/blocs/organisation/organisation_bloc.dart';
import 'package:accelerator_squared/models/organisation.dart';
import 'package:accelerator_squared/views/Home%20Page/invites.dart';
import 'package:accelerator_squared/views/Home%20Page/settings.dart';
import 'package:accelerator_squared/views/Home%20Page/Add%20Organisation/create_organisation_dialog.dart';
import 'package:accelerator_squared/views/Home%20Page/Add%20Organisation/join_organisation_dialog.dart';
import 'package:accelerator_squared/widgets/organisation_card.dart';
import 'package:accelerator_squared/views/Project/project_page.dart';
import 'package:accelerator_squared/util/snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:accelerator_squared/blocs/organisations/organisations_bloc.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html; // For user agent detection
import 'package:accelerator_squared/util/page_title.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _dialogShown = false;
  bool _tutorialChecked = false;
  final Set<String> _shownErrorMessages = {};
  bool _menuOpenedForTutorial = false;

  late TutorialCoachMark studentTutorialCoachMark;
  late TutorialCoachMark teacherTutorialCoachMark;
  final GlobalKey expandableFabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    context.read<OrganisationsBloc>().add(FetchOrganisationsEvent());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      createStudentTutorial();
      createTeacherTutorial();
    });
  }

  int _selectedIndex = 0;

  GlobalKey orgButtonKey = GlobalKey();
  GlobalKey createOrgButtonKey = GlobalKey();
  GlobalKey JoinOrgButtonKey = GlobalKey();
  GlobalKey orgNavKey = GlobalKey();
  GlobalKey inboxNavKey = GlobalKey();
  GlobalKey settingsNavKey = GlobalKey();

  Widget _coachText(String text) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.start,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  Future<void> _handleCreateOrganisationPressed() async {
    setPageTitle('Organisations - Create Organisation');
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, StateSetter setState) {
            return CreateOrganisationDialog();
          },
        );
      },
    );
    setPageTitle('Organisations');
  }

  Future<void> _handleJoinOrganisationPressed() async {
    setPageTitle('Organisations - Join Organisation');
    await showDialog(
      context: context,
      builder: (context) {
        TextEditingController orgcodecontroller = TextEditingController();
        return JoinOrganisationDialog(orgcodecontroller: orgcodecontroller);
      },
    );
    setPageTitle('Organisations');
  }

  void showTutorial() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Welcome to Accelerator^2"),
            content: SizedBox(
              width: MediaQuery.of(context).size.width / 2.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Are you a student or a teacher?"),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Reset menu flag and ensure we're on Organisations tab
                            _menuOpenedForTutorial = false;
                            setState(() {
                              _selectedIndex = 0;
                            });
                            setPageTitle('${_getPageTitle()}');
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              studentTutorialCoachMark.show(context: context);
                            });
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              "Student",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Reset menu flag and ensure we're on Organisations tab
                            _menuOpenedForTutorial = false;
                            setState(() {
                              _selectedIndex = 0;
                            });
                            setPageTitle('${_getPageTitle()}');
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              teacherTutorialCoachMark.show(context: context);
                            });
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              "Teacher",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _ensureMenuOpen() {
    final ctx = expandableFabKey.currentContext;
    if (ctx != null) {
      // Only toggle if we haven't already opened it for the tutorial
      // This prevents closing the menu if it's already open
      if (!_menuOpenedForTutorial) {
        ExpandableFab.of(ctx).toggle();
        _menuOpenedForTutorial = true;
      }
    }
  }

  void createStudentTutorial() {
    studentTutorialCoachMark = TutorialCoachMark(
      targets: _createStudentTargets(),
      colorShadow: Theme.of(context).colorScheme.primary,
      textSkip: "Skip tutorial",
      paddingFocus: 24,
      alignSkip: Alignment.topRight,
      opacityShadow: 0.5,
      onFinish: () async {
        print("finish");
        _menuOpenedForTutorial = false; // Reset flag when tutorial finishes
        await _saveTutorialFlag();
      },
      onClickTarget: (target) async {
        final id = target.identify;
        if (id == 'orgButton') {
          // Ensure menu is open (don't toggle, just open)
          _ensureMenuOpen();
        } else if (id == 'navOrganisations') {
          setState(() {
            _selectedIndex = 0;
          });
          setPageTitle('${_getPageTitle()}');
        } else if (id == 'navInbox') {
          setState(() {
            _selectedIndex = 1;
          });
          setPageTitle('${_getPageTitle()}');
        } else if (id == 'navSettings') {
          setState(() {
            _selectedIndex = 2;
          });
          setPageTitle('${_getPageTitle()}');
        } else if (id == 'joinOrgButton') {
          // Ensure menu is open and we're on Organisations tab before showing this target
          setState(() {
            _selectedIndex = 0;
          });
          setPageTitle('${_getPageTitle()}');
          _ensureMenuOpen();
          // Wait a bit for the menu to open before proceeding
          await Future.delayed(const Duration(milliseconds: 300));
          // Dismiss tutorial before opening dialog
          studentTutorialCoachMark.skip();
          await _handleJoinOrganisationPressed();
        } else if (id == 'createOrgButton') {
          // Ensure menu is open and we're on Organisations tab before showing this target
          setState(() {
            _selectedIndex = 0;
          });
          setPageTitle('${_getPageTitle()}');
          _ensureMenuOpen();
          // Wait a bit for the menu to open before proceeding
          await Future.delayed(const Duration(milliseconds: 300));
          // Dismiss tutorial before opening dialog
          studentTutorialCoachMark.skip();
          await _handleCreateOrganisationPressed();
        }
      },
      onClickOverlay: (target) {
        print('onClickOverlay: $target');
        // When overlay is shown (user is viewing a target), ensure menu is open for org buttons
        final id = target.identify;
        if (id == 'orgButton') {
          // Ensure menu is open when orgButton target is shown
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureMenuOpen();
          });
        } else if (id == 'joinOrgButton' || id == 'createOrgButton') {
          // Ensure we're on Organisations tab
          if (_selectedIndex != 0) {
            setState(() {
              _selectedIndex = 0;
            });
            setPageTitle('${_getPageTitle()}');
          }
          // Ensure menu is open
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureMenuOpen();
          });
        }
      },
      onClickTargetWithTapPosition: (target, tapDetails) {
        print("target: $target");
        print(
          "clicked at position local: ${tapDetails.localPosition} - global: ${tapDetails.globalPosition}",
        );
      },
      onSkip: () {
        print("skip");
        _menuOpenedForTutorial = false; // Reset flag when tutorial is skipped
        _saveTutorialFlag(); // Fire and forget
        return true;
      },
    );
  }

  void createTeacherTutorial() {
    teacherTutorialCoachMark = TutorialCoachMark(
      targets: _createTeacherTargets(),
      colorShadow: Theme.of(context).colorScheme.primary,
      textSkip: "Skip tutorial",
      paddingFocus: 24,
      alignSkip: Alignment.topRight,
      opacityShadow: 0.5,
      onFinish: () async {
        print("finish");
        _menuOpenedForTutorial = false; // Reset flag when tutorial finishes
        await _saveTutorialFlag();
      },
      onClickTarget: (target) async {
        final id = target.identify;
        if (id == 'orgButton') {
          // Ensure menu is open (don't toggle, just open)
          _ensureMenuOpen();
        } else if (id == 'navOrganisations') {
          setState(() {
            _selectedIndex = 0;
          });
          setPageTitle('${_getPageTitle()}');
        } else if (id == 'navInbox') {
          setState(() {
            _selectedIndex = 1;
          });
          setPageTitle('${_getPageTitle()}');
        } else if (id == 'navSettings') {
          setState(() {
            _selectedIndex = 2;
          });
          setPageTitle('${_getPageTitle()}');
        } else if (id == 'createOrgButton') {
          // Ensure menu is open and we're on Organisations tab before showing this target
          setState(() {
            _selectedIndex = 0;
          });
          setPageTitle('${_getPageTitle()}');
          _ensureMenuOpen();
          // Wait a bit for the menu to open before proceeding
          await Future.delayed(const Duration(milliseconds: 300));
          // Dismiss tutorial before opening dialog
          teacherTutorialCoachMark.skip();
          await _handleCreateOrganisationPressed();
        }
      },
      onClickOverlay: (target) {
        print('onClickOverlay: $target');
        // When overlay is shown (user is viewing a target), ensure menu is open for org buttons
        final id = target.identify;
        if (id == 'orgButton') {
          // Ensure menu is open when orgButton target is shown
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureMenuOpen();
          });
        } else if (id == 'joinOrgButton' || id == 'createOrgButton') {
          // Ensure we're on Organisations tab
          if (_selectedIndex != 0) {
            setState(() {
              _selectedIndex = 0;
            });
            setPageTitle('${_getPageTitle()}');
          }
          // Ensure menu is open
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureMenuOpen();
          });
        }
      },
      onClickTargetWithTapPosition: (target, tapDetails) {
        print("target: $target");
        print(
          "clicked at position local: ${tapDetails.localPosition} - global: ${tapDetails.globalPosition}",
        );
      },
      onSkip: () {
        print("skip");
        _menuOpenedForTutorial = false; // Reset flag when tutorial is skipped
        _saveTutorialFlag(); // Fire and forget
        return true;
      },
    );
  }

  List<TargetFocus> _createStudentTargets() {
    List<TargetFocus> targets = [];
    // NavigationRail items first in sequence
    targets.addAll([
      TargetFocus(
        identify: "navOrganisations",
        keyTarget: orgNavKey,
        enableOverlayTab: true,
        paddingFocus: 16,
        shape: ShapeLightFocus.RRect,
        radius: 14,
        contents: [
          TargetContent(
            align: ContentAlign.right,
            builder:
                (context, controller) =>
                    _coachText("This takes you to Organisations"),
          ),
        ],
      ),
      TargetFocus(
        identify: "navInbox",
        keyTarget: inboxNavKey,
        enableOverlayTab: true,
        paddingFocus: 16,
        shape: ShapeLightFocus.RRect,
        radius: 14,
        contents: [
          TargetContent(
            align: ContentAlign.right,
            builder:
                (context, controller) =>
                    _coachText("Your Inbox for invites and notifications"),
          ),
        ],
      ),
      TargetFocus(
        identify: "navSettings",
        keyTarget: settingsNavKey,
        enableOverlayTab: true,
        paddingFocus: 16,
        shape: ShapeLightFocus.RRect,
        radius: 14,
        contents: [
          TargetContent(
            align: ContentAlign.right,
            builder:
                (context, controller) =>
                    _coachText("Manage your app settings here"),
          ),
        ],
      ),
    ]);
    targets.add(
      TargetFocus(
        identify: "orgButton",
        keyTarget: orgButtonKey,
        enableOverlayTab: true,
        paddingFocus: 24,
        shape: ShapeLightFocus.RRect,
        radius: 28,
        contents: [
          TargetContent(
            align: ContentAlign.right,
            builder:
                (context, controller) =>
                    _coachText("Click here to open the organisations menu"),
          ),
        ],
      ),
    );
    targets.add(
      TargetFocus(
        identify: "joinOrgButton",
        keyTarget: JoinOrgButtonKey,
        enableOverlayTab: true,
        paddingFocus: 24,
        shape: ShapeLightFocus.RRect,
        radius: 28,
        contents: [
          TargetContent(
            align: ContentAlign.right,
            builder:
                (context, controller) =>
                    _coachText("Click here to join an organisation"),
          ),
        ],
      ),
    );
    return targets;
  }

  List<TargetFocus> _createTeacherTargets() {
    List<TargetFocus> targets = [];
    // NavigationRail items first in sequence
    targets.addAll([
      TargetFocus(
        identify: "navOrganisations",
        keyTarget: orgNavKey,
        enableOverlayTab: true,
        paddingFocus: 16,
        shape: ShapeLightFocus.RRect,
        radius: 14,
        contents: [
          TargetContent(
            align: ContentAlign.right,
            builder:
                (context, controller) =>
                    _coachText("This takes you to Organisations"),
          ),
        ],
      ),
      TargetFocus(
        identify: "navInbox",
        keyTarget: inboxNavKey,
        enableOverlayTab: true,
        paddingFocus: 16,
        shape: ShapeLightFocus.RRect,
        radius: 14,
        contents: [
          TargetContent(
            align: ContentAlign.right,
            builder:
                (context, controller) =>
                    _coachText("Your Inbox for invites and notifications"),
          ),
        ],
      ),
      TargetFocus(
        identify: "navSettings",
        keyTarget: settingsNavKey,
        enableOverlayTab: true,
        paddingFocus: 16,
        shape: ShapeLightFocus.RRect,
        radius: 14,
        contents: [
          TargetContent(
            align: ContentAlign.right,
            builder:
                (context, controller) =>
                    _coachText("Manage your app settings here"),
          ),
        ],
      ),
    ]);
    targets.add(
      TargetFocus(
        identify: "orgButton",
        keyTarget: orgButtonKey,
        enableOverlayTab: true,
        paddingFocus: 24,
        shape: ShapeLightFocus.RRect,
        radius: 28,
        contents: [
          TargetContent(
            align: ContentAlign.right,
            builder:
                (context, controller) =>
                    _coachText("Click here to open the organisations menu"),
          ),
        ],
      ),
    );
    targets.add(
      TargetFocus(
        identify: "createOrgButton",
        keyTarget: createOrgButtonKey,
        enableOverlayTab: true,
        paddingFocus: 24,
        shape: ShapeLightFocus.RRect,
        radius: 28,
        contents: [
          TargetContent(
            align: ContentAlign.right,
            builder:
                (context, controller) =>
                    _coachText("Click here to create an organisation"),
          ),
        ],
      ),
    );
    return targets;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showMobileAlertIfNeeded();
      setPageTitle('${_getPageTitle()}');
      // Show tutorial only on first visit (web) and only check once per session
      if (!_tutorialChecked) {
        _tutorialChecked = true;
        _checkAndShowTutorial();
      }
    });
  }

  Future<void> _saveTutorialFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_tutorial', true);
    } catch (e) {
      // Fallback to localStorage on web
      try {
        html.window.localStorage['flutter.has_seen_tutorial'] = 'true';
      } catch (_) {
        // If both fail, log but continue
        print('Failed to save tutorial flag: $e');
      }
    }
  }

  Future<void> _checkAndShowTutorial() async {
    try {
      // Add a small delay to ensure widget tree is fully built and keys are available
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      bool hasSeen = false;

      // Try SharedPreferences first
      try {
        final prefs = await SharedPreferences.getInstance();
        hasSeen = prefs.getBool('has_seen_tutorial') ?? false;
      } catch (e) {
        // If SharedPreferences fails, use localStorage directly (web fallback)
        // SharedPreferences on web stores keys with "flutter." prefix
        try {
          final stored = html.window.localStorage['flutter.has_seen_tutorial'];
          hasSeen = stored == 'true';
        } catch (_) {
          // If both fail, default to showing tutorial
          hasSeen = false;
        }
      }

      if (!hasSeen && mounted) {
        // Add another small delay to ensure all keys are ready
        await Future.delayed(const Duration(milliseconds: 200));

        if (mounted) {
          showTutorial();
          // Save the flag after showing tutorial dialog
          await _saveTutorialFlag();
        }
      }
    } catch (e) {
      // Log error but don't crash the app
      print('Error checking tutorial: $e');
    }
  }

  void showMobileAlertIfNeeded() {
    if (_dialogShown) return;
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    final isMobile =
        userAgent.contains('iphone') ||
        userAgent.contains('android') ||
        userAgent.contains('ipad') ||
        userAgent.contains('mobile');

    if (isMobile) {
      _dialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false, // Force user to acknowledge
        builder:
            (context) => AlertDialog(
              title: const Text(
                'Mobile Device Detected',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: const Text(
                'This web app is best experienced on a desktop or tablet screen. '
                'For the best performance and layout, please switch to a larger device.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Continue Anyway'),
                ),
              ],
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: FloatingActionButton.extended(
                  label: Text("Feedback"),
                  icon: Icon(Icons.feedback),
                  heroTag: 'home_info_fab',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Row(
                            children: [
                              Icon(
                                Icons.feedback,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Feedback",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 30,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          content: SizedBox(
                            width: MediaQuery.of(context).size.width / 2.5,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: QrImageView(
                                    data: "https://forms.gle/7RRCyrTkxStYx47A9",
                                    size: MediaQuery.of(context).size.width / 6,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0.5,
                                    ),
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: 20),
                                Text(
                                  "Scan the QR code to access the feedback form!",
                                ),
                                SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    launchUrl(
                                      Uri.parse(
                                        "https://forms.gle/7RRCyrTkxStYx47A9",
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.open_in_new),
                                  label: Padding(
                                    padding: EdgeInsetsGeometry.symmetric(
                                      vertical: 10,
                                      horizontal: 8,
                                    ),
                                    child: Text("Feedback form"),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onPrimary,
                                    elevation: 0,
                                  ),
                                ),
                                SizedBox(height: 20),
                                Text("Thank you for your feedback!"),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  elevation: 6,
                ),
              ),
              const SizedBox(width: 70),
            ],
          ),
          // Invisible keyed overlay to reference the unexpanded FAB position for tutorials
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomRight,
              child: IgnorePointer(
                child: SizedBox(key: orgButtonKey, width: 56, height: 56),
              ),
            ),
          ),
          ExpandableFab(
            distance: 70,
            type: ExpandableFabType.up,
            onOpen: () {},
            key: expandableFabKey,
            children: [
              Row(
                children: [
                  Text("Create organisation"),
                  SizedBox(width: 20),
                  FloatingActionButton(
                    key: createOrgButtonKey,
                    onPressed: _handleCreateOrganisationPressed,
                    child: Icon(Icons.add),
                  ),
                ],
              ),
              Row(
                children: [
                  Text("Join organisation"),
                  SizedBox(width: 20),
                  FloatingActionButton(
                    key: JoinOrgButtonKey,
                    onPressed: _handleJoinOrganisationPressed,
                    child: Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      appBar: AppBar(
        title: Text(
          _getPageTitle(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NavigationRail(
                backgroundColor: Colors.transparent,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (value) {
                  setState(() {
                    _selectedIndex = value;
                  });
                  setPageTitle('${_getPageTitle()}');
                },
                labelType: NavigationRailLabelType.all,
                destinations: [
                  NavigationRailDestination(
                    icon: Icon(Icons.business_outlined),
                    selectedIcon: Icon(Icons.business),
                    label: Text("Organisations", key: orgNavKey),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.mail_outline),
                    selectedIcon: Icon(Icons.mail),
                    label: Text("Inbox", key: inboxNavKey),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: Text("Settings", key: settingsNavKey),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  // color: Theme.of(context).colorScheme.surface,
                  child: Card(
                    color: Theme.of(context).colorScheme.surface,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _buildContent(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPageTitle() {
    if (_selectedIndex == 0) return "Organisations";
    if (_selectedIndex == 1) return "Invites";
    return "Settings";
  }

  Widget _buildContent() {
    if (_selectedIndex == 0) return _buildOrganisationsContent();
    if (_selectedIndex == 1) return OrgInvitesPage();
    return SettingsPage();
  }

  Widget _buildOrganisationsContent() {
    return BlocListener<OrganisationsBloc, OrganisationsState>(
      listener: (context, state) {
        // Clear shown errors when organisations load
        if (state is OrganisationsLoaded) {
          _shownErrorMessages.clear();
        }

        // Handle last-teacher block state (shown once)
        if (state is OrganisationsLeaveBlockedLastTeacher) {
          const msg =
              "Cannot leave organisation. You are the last teacher. Please assign another teacher before leaving.";
          if (_shownErrorMessages.contains(msg)) return;
          _shownErrorMessages.add(msg);

          showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (context) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Cannot Leave Organisation'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You are the last teacher in this organisation.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'To leave the organisation, you must first assign another member as a teacher.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _shownErrorMessages.remove(msg);
                      },
                      child: Text('OK'),
                    ),
                  ],
                ),
          );
        } else if (state is OrganisationsError) {
          // Show other errors as snackbar
          SnackBarHelper.showError(context, message: state.message);
        }
      },
      child: BlocBuilder<OrganisationsBloc, OrganisationsState>(
        builder: (context, state) {
          if (state is OrganisationsLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading organisations...',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          } else if (state is OrganisationsLoaded) {
            final organisations = state.organisations;
            if (organisations.isEmpty) {
              return _buildEmptyState();
            }
            return _buildOrganisationsGrid(organisations);
          } else {
            return _buildEmptyState();
          }
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.business_outlined,
                size: 60,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No organisations found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You are not a member of any organisations yet.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final baseTitle = _getPageTitle();
                    setPageTitle('Organisations - Create Organisation');
                    showDialog(
                      context: context,
                      builder: (context) {
                        return StatefulBuilder(
                          builder: (context, StateSetter setState) {
                            return CreateOrganisationDialog();
                          },
                        );
                      },
                    ).then((_) {
                      setPageTitle(baseTitle);
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Create Organisation"),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final baseTitle = _getPageTitle();
                    setPageTitle('Organisations - Join Organisation');
                    showDialog(
                      context: context,
                      builder: (context) {
                        TextEditingController orgcodecontroller =
                            TextEditingController();
                        return JoinOrganisationDialog(
                          orgcodecontroller: orgcodecontroller,
                        );
                      },
                    ).then((_) {
                      setPageTitle(baseTitle);
                    });
                  },
                  icon: const Icon(Icons.group_add),
                  label: const Text("Join Organisation"),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganisationsGrid(List<Organisation> organisations) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.business,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Your Organisations',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${organisations.length} organisation${organisations.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: GridView.builder(
              itemCount: organisations.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 500,
                childAspectRatio: 3 / 2,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
              ),
              itemBuilder:
                  (context, index) => OrganisationCard(
                    organisation: organisations[index],
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) => BlocProvider(
                                create:
                                    (context) => OrganisationBloc(
                                      organisationId: organisations[index].id,
                                      initialState: organisations[index],
                                    ),
                                child: ProjectsPage(),
                              ),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
