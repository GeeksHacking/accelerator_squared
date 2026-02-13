import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:accelerator_squared/blocs/organisation/organisation_bloc.dart';
import 'package:accelerator_squared/blocs/organisations/organisations_bloc.dart';
import 'package:accelerator_squared/blocs/projects/projects_bloc.dart';
import 'package:accelerator_squared/views/Project/create_new_project.dart';
import 'package:accelerator_squared/views/Project/project_card.dart';
import 'package:accelerator_squared/views/Project/project_details.dart';
import 'package:accelerator_squared/views/organisations/org_members.dart';
import 'package:accelerator_squared/views/organisations/org_milestones.dart';
import 'package:accelerator_squared/views/organisations/org_settings.dart';
import 'package:accelerator_squared/views/organisations/org_stats.dart';
import 'package:accelerator_squared/views/organisations/org_requests.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:accelerator_squared/util/page_title.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:accelerator_squared/models/projects.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  OrganisationLoaded? organisationStateLoaded;
  bool isRefreshing = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _orgTutorialChecked = false;
  late TutorialCoachMark _orgTutorial;
  final GlobalKey _createProjectFabKey = GlobalKey();

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

  Future<void> _maybeShowOrganisationTutorial() async {
    if (_orgTutorialChecked) return;
    _orgTutorialChecked = true;
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_org_tutorial') ?? false;
    if (hasSeen) return;

    final appBarHeight = Scaffold.maybeOf(context)?.appBarMaxHeight ?? 64.0;
    final railFocus = TargetFocus(
      identify: 'org_nav',
      targetPosition: TargetPosition(
        const Size(140, 280),
        Offset(0, appBarHeight + 80),
      ),
      shape: ShapeLightFocus.RRect,
      radius: 16,
      paddingFocus: 16,
      contents: [
        TargetContent(
          align: ContentAlign.right,
          builder:
              (context, controller) => Padding(
                padding: const EdgeInsets.only(top: 200),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(12),
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
                        'Use these tabs to navigate organisation sections.',
                        textAlign: TextAlign.start,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ],
    );

    final fabFocus = TargetFocus(
      identify: 'org_fab',
      keyTarget: _createProjectFabKey,
      shape: ShapeLightFocus.Circle,
      paddingFocus: 16,
      contents: [
        TargetContent(
          align: ContentAlign.left,
          builder:
              (context, controller) => _coachText('Create a new project here.'),
        ),
      ],
    );

    _orgTutorial = TutorialCoachMark(
      targets: [railFocus, fabFocus],
      colorShadow: Theme.of(context).colorScheme.primary,
      opacityShadow: 0.5,
      paddingFocus: 16,
      alignSkip: Alignment.topRight,
      textSkip: 'Skip tutorial',
      onFinish: () async {
        await prefs.setBool('has_seen_org_tutorial', true);
      },
      onSkip: () {
        prefs.setBool('has_seen_org_tutorial', true);
        return true;
      },
    );

    _orgTutorial.show(context: context);
  }

  /// Creates a stream of filtered projects based on user role and membership
  /// Members can only see projects they're part of
  /// Teachers and student_teachers can see all projects
  Stream<List<Project>> _getFilteredProjectsStream(
    String organisationId,
    String userRole,
  ) {
    // Create stream of all projects
    final projectsStream = _firestore
        .collection('organisations')
        .doc(organisationId)
        .collection('projects')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final projectData = doc.data();
            projectData['id'] = doc.id;
            return Project.fromJson(projectData);
          }).toList();
        });

    // Teachers and student_teachers can see all projects
    if (userRole != 'member') {
      return projectsStream;
    }

    // For members, filter projects based on membership
    final String uid = _auth.currentUser?.uid ?? '';
    final String userEmail = _auth.currentUser?.email ?? '';

    if (uid.isEmpty && userEmail.isEmpty) {
      return Stream.value([]); // Not authenticated, return empty stream
    }

    // For each project in the stream, check if user is a member
    return projectsStream.asyncMap((projects) async {
      List<Project> accessibleProjects = [];

      for (var project in projects) {
        try {
          // Check if user is a member of this project
          QuerySnapshot memberSnapshot = await _firestore
              .collection('organisations')
              .doc(organisationId)
              .collection('projects')
              .doc(project.id)
              .collection('members')
              .where('uid', isEqualTo: uid)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 5));

          // If not found by UID, try by email
          if (memberSnapshot.docs.isEmpty && userEmail.isNotEmpty) {
            memberSnapshot = await _firestore
                .collection('organisations')
                .doc(organisationId)
                .collection('projects')
                .doc(project.id)
                .collection('members')
                .where('email', isEqualTo: userEmail)
                .limit(1)
                .get()
                .timeout(const Duration(seconds: 5));
          }

          // If user is found in project members, add project to accessible list
          if (memberSnapshot.docs.isNotEmpty) {
            accessibleProjects.add(project);
          }
        } catch (e) {
          // If there's an error checking membership, skip this project
          // (better to hide than show incorrectly)
          print('Error checking membership for project ${project.id}: $e');
        }
      }

      return accessibleProjects;
    });
  }

  /// Exports all organisation data (projects, milestones, tasks) as a CSV file.
  Future<void> _exportOrganisationData() async {
    final org = organisationStateLoaded;
    if (org == null) return;

    try {
      final orgId = org.id;
      final orgName = org.name;

      // Fetch all projects for this organisation
      final projectsSnapshot = await _firestore
          .collection('organisations')
          .doc(orgId)
          .collection('projects')
          .get();

      if (projectsSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No projects found to export.'),
            ),
          );
        }
        return;
      }

      int totalProjects = 0;
      int totalMilestones = 0;
      int totalTasks = 0;

      final buffer = StringBuffer();

      // CSV header
      buffer.writeln(
        [
          'organisationId',
          'organisationName',
          'projectId',
          'projectName',
          'projectDescription',
          'projectCreatedAt',
          'projectUpdatedAt',
          'milestoneId',
          'milestoneName',
          'milestoneDescription',
          'milestoneDueDate',
          'milestoneIsCompleted',
          'taskId',
          'taskName',
          'taskDescription',
          'taskDeadline',
          'taskIsCompleted',
        ].map(_escapeCsvField).join(','),
      );

      for (final projectDoc in projectsSnapshot.docs) {
        totalProjects++;
        final projectId = projectDoc.id;
        final projectData = projectDoc.data();
        final projectName =
            projectData['title'] as String? ?? projectData['name'] as String? ?? '';
        final projectDescription = projectData['description'] as String? ?? '';
        final createdAtRaw = projectData['createdAt'];
        final updatedAtRaw = projectData['updatedAt'];

        String formatTimestamp(dynamic value) {
          if (value == null) return '';
          if (value is DateTime) return value.toIso8601String();
          if (value is Timestamp) return value.toDate().toIso8601String();
          if (value is String) return value;
          return value.toString();
        }

        final createdAtStr = formatTimestamp(createdAtRaw);
        final updatedAtStr = formatTimestamp(updatedAtRaw);

        // Fetch milestones and tasks for this project
        final milestonesSnapshot = await _firestore
            .collection('organisations')
            .doc(orgId)
            .collection('projects')
            .doc(projectId)
            .collection('milestones')
            .get();

        final tasksSnapshot = await _firestore
            .collection('organisations')
            .doc(orgId)
            .collection('projects')
            .doc(projectId)
            .collection('tasks')
            .get();

        final milestones = milestonesSnapshot.docs
            .map((m) => {...m.data(), 'id': m.id})
            .toList();
        final tasks = tasksSnapshot.docs
            .map((t) => {...t.data(), 'id': t.id})
            .toList();

        totalMilestones += milestones.length;
        totalTasks += tasks.length;

        // If there are no milestones or tasks, still export the project row
        if (milestones.isEmpty && tasks.isEmpty) {
          buffer.writeln(
            [
              orgId,
              orgName,
              projectId,
              projectName,
              projectDescription,
              createdAtStr,
              updatedAtStr,
              '', // milestoneId
              '', // milestoneName
              '', // milestoneDescription
              '', // milestoneDueDate
              '', // milestoneIsCompleted
              '', // taskId
              '', // taskName
              '', // taskDescription
              '', // taskDeadline
              '', // taskIsCompleted
            ].map(_escapeCsvField).join(','),
          );
          continue;
        }

        for (final milestone in milestones) {
          final milestoneId = milestone['id'] as String? ?? '';
          final milestoneName = milestone['name'] as String? ?? '';
          final milestoneDescription =
              milestone['description'] as String? ?? '';
          final milestoneDueDate = milestone['dueDate'];
          final milestoneIsCompleted = milestone['isCompleted'] == true;

          final milestoneDueDateStr = formatTimestamp(milestoneDueDate);

          final milestoneTasks = tasks
              .where((t) => t['milestoneId'] == milestoneId)
              .toList();

          if (milestoneTasks.isEmpty) {
            buffer.writeln(
              [
                orgId,
                orgName,
                projectId,
                projectName,
                projectDescription,
                createdAtStr,
                updatedAtStr,
                milestoneId,
                milestoneName,
                milestoneDescription,
                milestoneDueDateStr,
                milestoneIsCompleted ? 'true' : 'false',
                '', // taskId
                '', // taskName
                '', // taskDescription
                '', // taskDeadline
                '', // taskIsCompleted
              ].map(_escapeCsvField).join(','),
            );
          } else {
            for (final task in milestoneTasks) {
              final taskId = task['id'] as String? ?? '';
              final taskName = task['name'] as String? ?? '';
              final taskDescription = task['content'] as String? ?? '';
              final taskDeadline = task['deadline'];
              final taskIsCompleted = task['isCompleted'] == true;

              final taskDeadlineStr = formatTimestamp(taskDeadline);

              buffer.writeln(
                [
                  orgId,
                  orgName,
                  projectId,
                  projectName,
                  projectDescription,
                  createdAtStr,
                  updatedAtStr,
                  milestoneId,
                  milestoneName,
                  milestoneDescription,
                  milestoneDueDateStr,
                  milestoneIsCompleted ? 'true' : 'false',
                  taskId,
                  taskName,
                  taskDescription,
                  taskDeadlineStr,
                  taskIsCompleted ? 'true' : 'false',
                ].map(_escapeCsvField).join(','),
              );
            }
          }
        }

        // Tasks that are not linked to any milestone
        final unlinkedTasks =
            tasks.where((t) => t['milestoneId'] == null || t['milestoneId'] == '').toList();
        for (final task in unlinkedTasks) {
          final taskId = task['id'] as String? ?? '';
          final taskName = task['name'] as String? ?? '';
          final taskDescription = task['content'] as String? ?? '';
          final taskDeadline = task['deadline'];
          final taskIsCompleted = task['isCompleted'] == true;
          final taskDeadlineStr = formatTimestamp(taskDeadline);

          buffer.writeln(
            [
              orgId,
              orgName,
              projectId,
              projectName,
              projectDescription,
              createdAtStr,
              updatedAtStr,
              '', // milestoneId
              '', // milestoneName
              '', // milestoneDescription
              '', // milestoneDueDate
              '', // milestoneIsCompleted
              taskId,
              taskName,
              taskDescription,
              taskDeadlineStr,
              taskIsCompleted ? 'true' : 'false',
            ].map(_escapeCsvField).join(','),
          );
        }
      }

      final csvContent = buffer.toString();
      final bytes = utf8.encode(csvContent);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute(
          'download',
          'organisation_${orgId}_export.csv',
        )
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported $totalProjects projects, $totalMilestones milestones, $totalTasks tasks.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export organisation data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _escapeCsvField(Object? value) {
    final text = value?.toString() ?? '';
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      final escaped = text.replaceAll('"', '""');
      return '"$escaped"';
    }
    return text;
  }

  String _sectionTitleForIndex(OrganisationLoaded state) {
    final isMember = state.userRole == 'member';
    if (isMember) {
      switch (_selectedIndex) {
        case 0:
          return 'Projects';
        case 1:
          return 'Milestones';
        case 2:
          return 'Members';
        default:
          return 'Projects';
      }
    } else {
      switch (_selectedIndex) {
        case 0:
          return 'Projects';
        case 1:
          return 'Statistics';
        case 2:
          return 'Requests';
        case 3:
          return 'Milestones';
        case 4:
          return 'Members';
        default:
          return 'Projects';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    OrganisationBloc organisationBloc = context.watch<OrganisationBloc>();

    return BlocListener<OrganisationBloc, OrganisationState>(
      listener: (context, state) {
        if (state is OrganisationLoaded || state is OrganisationError) {
          if (mounted && isRefreshing) {
            setState(() {
              isRefreshing = false;
            });
          }
        } else if (state is OrganisationLoading) {
          if (mounted) {
            setState(() {
              isRefreshing = true;
            });
          }
        } else if (state is OrganisationDeleted) {
          // Organisation deleted elsewhere; navigate back to home and refresh
          if (mounted) {
            final orgsBloc = context.read<OrganisationsBloc>();
            orgsBloc.add(FetchOrganisationsEvent());
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/', (route) => false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Organisation was deleted'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      },
      child: BlocBuilder<OrganisationBloc, OrganisationState>(
        builder: (context, state) {
          if (state is OrganisationLoading) {
            return Scaffold(
              appBar: AppBar(title: Text('Loading...')),
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is OrganisationDeleted) {
            // Safety: if UI rebuilds before navigation, show empty scaffold
            return Scaffold(
              appBar: AppBar(title: Text('Organisation')),
              body: Center(child: Text('This organisation was deleted.')),
            );
          }

          if (state is OrganisationError) {
            return Scaffold(
              appBar: AppBar(title: Text('Error')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Error loading organisation',
                      style: TextStyle(fontSize: 18, color: Colors.red),
                    ),
                    SizedBox(height: 8),
                    Text(state.message),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<OrganisationBloc>().add(
                          FetchOrganisationEvent(),
                        );
                      },
                      child: Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is OrganisationLoaded) {
            organisationStateLoaded = state;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final section = _sectionTitleForIndex(organisationStateLoaded!);
              setPageTitle('Organisation - $section');
              _maybeShowOrganisationTutorial();
            });

            return Scaffold(
              floatingActionButton: FloatingActionButton(
                key: _createProjectFabKey,
                onPressed: () {
                  final section = _sectionTitleForIndex(
                    organisationStateLoaded!,
                  );
                  setPageTitle('Organisation - Create Project');
                  showDialog(
                    context: context,
                    builder: (context) {
                      return BlocProvider.value(
                        value: organisationBloc,
                        child: NewProjectDialog(
                          organisationId: organisationStateLoaded!.id,
                          isTeacher:
                              organisationStateLoaded!.userRole == 'teacher' ||
                              organisationStateLoaded!.userRole ==
                                  'student_teacher',
                        ),
                      );
                    },
                  ).then((_) {
                    setPageTitle('Organisation - $section');
                  });
                },
                child: Icon(Icons.add),
              ),
              appBar: AppBar(
                title: Row(
                  children: [
                    Text(
                      organisationStateLoaded!.name,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: IconButton(
                        onPressed: () {
                          // Read blocs from the current page context BEFORE opening the dialog.
                          // The dialog's builder gets a new context that may not have these providers.
                          final orgBloc = context.read<OrganisationBloc>();
                          final orgsBloc = context.read<OrganisationsBloc>();
                          showDialog(
                            context: context,
                            builder: (_) {
                              return OrganisationSettingsDialog(
                                orgDescription:
                                    organisationStateLoaded!.description,
                                orgName: organisationStateLoaded!.name,
                                isTeacher:
                                    organisationStateLoaded!.userRole ==
                                        'teacher' ||
                                    organisationStateLoaded!.userRole ==
                                        'student_teacher',
                                organisationId: organisationStateLoaded!.id,
                                joinCode: organisationStateLoaded!.joinCode,
                                organisationBloc: orgBloc,
                                organisationsBloc: orgsBloc,
                              );
                            },
                          );
                        },
                        icon: Icon(Icons.info_outline),
                      ),
                    ),
                    if (organisationStateLoaded!.userRole == 'teacher')
                      Container(
                        margin: EdgeInsets.only(left: 10),
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Teacher',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      )
                    else if (organisationStateLoaded!.userRole ==
                        'student_teacher')
                      Container(
                        margin: EdgeInsets.only(left: 10),
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Student Teacher',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      )
                    else
                      Container(
                        margin: EdgeInsets.only(left: 10),
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Member',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                  onPressed: _exportOrganisationData,
                    child: Text(
                      "Export organisation data",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (!(organisationStateLoaded!.userRole != 'member' &&
                      _selectedIndex == 2))
                    IconButton(
                      tooltip: 'Refresh data',
                      onPressed:
                          isRefreshing
                              ? null
                              : () {
                                setState(() => isRefreshing = true);
                                context.read<OrganisationBloc>().add(
                                  FetchOrganisationEvent(),
                                );
                              },
                      icon:
                          isRefreshing
                              ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              )
                              : Icon(Icons.refresh),
                    ),
                  SizedBox(width: 10),
                ],
              ),
              body: Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 0, 8),
                child: MultiBlocProvider(
                  providers: [
                    BlocProvider.value(value: context.read<OrganisationBloc>()),
                    BlocProvider.value(
                      value: context.read<OrganisationsBloc>(),
                    ),
                  ],
                  child:
                      organisationStateLoaded!.userRole == 'member'
                          ? Row(
                            children: [
                              NavigationRail(
                                backgroundColor: Colors.transparent,
                                onDestinationSelected: (value) {
                                  setState(() {
                                    _selectedIndex = value;
                                  });
                                  final section = _sectionTitleForIndex(
                                    organisationStateLoaded!,
                                  );
                                  setPageTitle('Organisation - $section');
                                },
                                labelType: NavigationRailLabelType.all,
                                destinations: [
                                  NavigationRailDestination(
                                    icon: Icon(Icons.list),
                                    label: Text("Projects"),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.flag),
                                    label: Text("Milestones"),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.groups),
                                    label: Text("Members"),
                                  ),
                                ],

                                selectedIndex: _selectedIndex,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    right: 8,
                                    left: 0,
                                    bottom: 8,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                                    child: Card(
                                      color:
                                          Theme.of(context).colorScheme.surface,
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child:
                                            _selectedIndex == 0
                                                ? SafeArea(
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                        ),
                                                    child: StreamBuilder<
                                                      List<Project>
                                                    >(
                                                      stream: _getFilteredProjectsStream(
                                                        organisationStateLoaded!
                                                            .id,
                                                        organisationStateLoaded!
                                                            .userRole,
                                                      ),
                                                      builder: (
                                                        context,
                                                        snapshot,
                                                      ) {
                                                        if (snapshot
                                                                .connectionState ==
                                                            ConnectionState
                                                                .waiting) {
                                                          return Center(
                                                            child:
                                                                CircularProgressIndicator(),
                                                          );
                                                        }

                                                        if (snapshot.hasError) {
                                                          return Center(
                                                            child: Column(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .error_outline,
                                                                  size: 64,
                                                                  color:
                                                                      Colors
                                                                          .red,
                                                                ),
                                                                SizedBox(
                                                                  height: 16,
                                                                ),
                                                                Text(
                                                                  'Error loading projects',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        18,
                                                                    color:
                                                                        Colors
                                                                            .red,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        }

                                                        final filteredProjects =
                                                            snapshot.data ?? [];

                                                        if (filteredProjects
                                                            .isEmpty) {
                                                          return Center(
                                                            child: Column(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .folder_off,
                                                                  size: 64,
                                                                  color:
                                                                      Colors
                                                                          .grey,
                                                                ),
                                                                SizedBox(
                                                                  height: 16,
                                                                ),
                                                                Text(
                                                                  'No projects found',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        18,
                                                                    color:
                                                                        Colors
                                                                            .grey,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  height: 8,
                                                                ),
                                                                Text(
                                                                  organisationStateLoaded!
                                                                              .userRole ==
                                                                          'member'
                                                                      ? 'You are not part of any projects yet.'
                                                                      : 'There are no projects in this organisation yet.',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    color:
                                                                        Colors
                                                                            .grey
                                                                            .shade600,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        }

                                                        return Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Expanded(
                                                              child: GridView.count(
                                                                childAspectRatio:
                                                                    1.5,
                                                                crossAxisCount:
                                                                    3,
                                                                crossAxisSpacing:
                                                                    10,
                                                                mainAxisSpacing:
                                                                    10,
                                                                children:
                                                                    filteredProjects.map((
                                                                      project,
                                                                    ) {
                                                                      return ProjectCard(
                                                                        project:
                                                                            project,
                                                                        organisationId:
                                                                            organisationStateLoaded!.id,
                                                                        isTeacher:
                                                                            organisationStateLoaded!.userRole ==
                                                                                'teacher' ||
                                                                            organisationStateLoaded!.userRole ==
                                                                                'student_teacher',
                                                                        onTap: () {
                                                                          Navigator.of(
                                                                                context,
                                                                              )
                                                                              .push(
                                                                                MaterialPageRoute(
                                                                                  builder:
                                                                                      (
                                                                                        context,
                                                                                      ) => BlocProvider(
                                                                                        create:
                                                                                            (
                                                                                              _,
                                                                                            ) =>
                                                                                                ProjectsBloc(),
                                                                                        child: ProjectDetails(
                                                                                          organisationId:
                                                                                              organisationStateLoaded!.id,
                                                                                          project:
                                                                                              project,
                                                                                          isTeacher:
                                                                                              organisationStateLoaded!.userRole !=
                                                                                              "member",
                                                                                          key: ValueKey(
                                                                                            project.id,
                                                                                          ),
                                                                                        ),
                                                                                      ),
                                                                                ),
                                                                              )
                                                                              .then((
                                                                                _,
                                                                              ) {
                                                                                context
                                                                                    .read<
                                                                                      ProjectsBloc
                                                                                    >()
                                                                                    .add(
                                                                                      FetchProjectsEvent(
                                                                                        organisationStateLoaded!.id,
                                                                                      ),
                                                                                    );
                                                                                context
                                                                                    .read<
                                                                                      OrganisationsBloc
                                                                                    >()
                                                                                    .add(
                                                                                      FetchOrganisationsEvent(),
                                                                                    );
                                                                              });
                                                                        },
                                                                      );
                                                                    }).toList(),
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                )
                                                : _selectedIndex == 1
                                                ? Align(
                                                  alignment:
                                                      Alignment.topCenter,
                                                  child: OrgMilestones(
                                                    isTeacher:
                                                        organisationStateLoaded!
                                                            .userRole !=
                                                        'member',
                                                    organisationId:
                                                        organisationStateLoaded!
                                                            .id,
                                                  ),
                                                )
                                                : Align(
                                                  alignment:
                                                      Alignment.topCenter,
                                                  child: OrgMembers(
                                                    teacherView: false,
                                                    organisationId:
                                                        organisationStateLoaded!
                                                            .id,
                                                    organisationName:
                                                        organisationStateLoaded!
                                                            .name,
                                                  ),
                                                ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                          : Row(
                            children: [
                              NavigationRail(
                                backgroundColor: Colors.transparent,
                                onDestinationSelected: (value) {
                                  setState(() {
                                    _selectedIndex = value;
                                  });
                                  final section = _sectionTitleForIndex(
                                    organisationStateLoaded!,
                                  );
                                  setPageTitle('Organisation - $section');
                                },
                                labelType: NavigationRailLabelType.all,
                                destinations: [
                                  NavigationRailDestination(
                                    icon: Icon(Icons.list),
                                    label: Text("Projects"),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.auto_graph_rounded),
                                    label: Text("Statistics"),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.check_box_outlined),
                                    label: Text("Requests"),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.flag),
                                    label: Text("Milestones"),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.groups),
                                    label: Text("Members"),
                                  ),
                                ],
                                selectedIndex: _selectedIndex,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                  child: Card(
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Builder(
                                        builder: (context) {
                                          switch (_selectedIndex) {
                                            case 0:
                                              return Padding(
                                                padding: EdgeInsets.all(24),
                                                child: StreamBuilder<
                                                  List<Project>
                                                >(
                                                  stream:
                                                      _getFilteredProjectsStream(
                                                        organisationStateLoaded!
                                                            .id,
                                                        organisationStateLoaded!
                                                            .userRole,
                                                      ),
                                                  builder: (context, snapshot) {
                                                    if (snapshot
                                                            .connectionState ==
                                                        ConnectionState
                                                            .waiting) {
                                                      return Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      );
                                                    }

                                                    if (snapshot.hasError) {
                                                      return Center(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .error_outline,
                                                              size: 64,
                                                              color: Colors.red,
                                                            ),
                                                            SizedBox(
                                                              height: 16,
                                                            ),
                                                            Text(
                                                              'Error loading projects',
                                                              style: TextStyle(
                                                                fontSize: 18,
                                                                color:
                                                                    Colors.red,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }

                                                    final filteredProjects =
                                                        snapshot.data ?? [];

                                                    if (filteredProjects
                                                        .isEmpty) {
                                                      return Center(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(
                                                              Icons.folder_off,
                                                              size: 64,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                            SizedBox(
                                                              height: 16,
                                                            ),
                                                            Text(
                                                              'No projects found',
                                                              style: TextStyle(
                                                                fontSize: 18,
                                                                color:
                                                                    Colors.grey,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                            SizedBox(height: 8),
                                                            Text(
                                                              organisationStateLoaded!
                                                                          .userRole ==
                                                                      'member'
                                                                  ? 'You are not part of any projects yet.'
                                                                  : 'There are no projects in this organisation yet.',
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                color:
                                                                    Colors
                                                                        .grey
                                                                        .shade600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }

                                                    return Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      children: [
                                                        Expanded(
                                                          child: GridView.count(
                                                            childAspectRatio:
                                                                1.5,
                                                            crossAxisCount: 3,
                                                            crossAxisSpacing:
                                                                10,
                                                            mainAxisSpacing: 10,
                                                            children:
                                                                filteredProjects.map((
                                                                  project,
                                                                ) {
                                                                  return ProjectCard(
                                                                    project:
                                                                        project,
                                                                    organisationId:
                                                                        organisationStateLoaded!
                                                                            .id,
                                                                    isTeacher:
                                                                        organisationStateLoaded!.userRole ==
                                                                            'teacher' ||
                                                                        organisationStateLoaded!.userRole ==
                                                                            'student_teacher',
                                                                    onTap: () {
                                                                      Navigator.of(
                                                                            context,
                                                                          )
                                                                          .push(
                                                                            MaterialPageRoute(
                                                                              builder:
                                                                                  (
                                                                                    context,
                                                                                  ) => BlocProvider(
                                                                                    create:
                                                                                        (
                                                                                          _,
                                                                                        ) =>
                                                                                            ProjectsBloc(),
                                                                                    child: ProjectDetails(
                                                                                      organisationId:
                                                                                          organisationStateLoaded!.id,
                                                                                      project:
                                                                                          project,
                                                                                      isTeacher:
                                                                                          organisationStateLoaded!.userRole !=
                                                                                          "member",
                                                                                      key: ValueKey(
                                                                                        project.id,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                            ),
                                                                          )
                                                                          .then((
                                                                            _,
                                                                          ) {
                                                                            context
                                                                                .read<
                                                                                  ProjectsBloc
                                                                                >()
                                                                                .add(
                                                                                  FetchProjectsEvent(
                                                                                    organisationStateLoaded!.id,
                                                                                  ),
                                                                                );
                                                                            context
                                                                                .read<
                                                                                  OrganisationsBloc
                                                                                >()
                                                                                .add(
                                                                                  FetchOrganisationsEvent(),
                                                                                );
                                                                          });
                                                                    },
                                                                  );
                                                                }).toList(),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              );
                                            case 1:
                                              // For member: Milestones, for teacher/student_teacher: Statistics
                                              if (organisationStateLoaded!
                                                      .userRole ==
                                                  'member') {
                                                return Align(
                                                  alignment:
                                                      Alignment.topCenter,
                                                  child: OrgMilestones(
                                                    isTeacher: false,
                                                    organisationId:
                                                        organisationStateLoaded!
                                                            .id,
                                                  ),
                                                );
                                              } else {
                                                return Align(
                                                  alignment:
                                                      Alignment.topCenter,
                                                  child: OrgStatistics(
                                                    organisationId:
                                                        organisationStateLoaded!
                                                            .id,
                                                    projects:
                                                        organisationStateLoaded!
                                                            .projects,
                                                  ),
                                                );
                                              }
                                            case 2:
                                              // For member: Members, for teacher/student_teacher: Requests
                                              if (organisationStateLoaded!
                                                      .userRole ==
                                                  'member') {
                                                return Align(
                                                  alignment:
                                                      Alignment.topCenter,
                                                  child: OrgMembers(
                                                    teacherView: false,
                                                    organisationId:
                                                        organisationStateLoaded!
                                                            .id,
                                                    organisationName:
                                                        organisationStateLoaded!
                                                            .name,
                                                  ),
                                                );
                                              } else {
                                                return Align(
                                                  alignment:
                                                      Alignment.topCenter,
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                        ),
                                                    child: ProjectRequests(
                                                      organisationId:
                                                          organisationStateLoaded!
                                                              .id,
                                                      projectRequests:
                                                          organisationStateLoaded!
                                                              .projectRequests,
                                                    ),
                                                  ),
                                                );
                                              }
                                            case 3:
                                              // Only for teacher/student_teacher: Milestones
                                              return Align(
                                                alignment: Alignment.topCenter,
                                                child: OrgMilestones(
                                                  isTeacher:
                                                      organisationStateLoaded!
                                                          .userRole !=
                                                      'member',
                                                  organisationId:
                                                      organisationStateLoaded!
                                                          .id,
                                                ),
                                              );
                                            case 4:
                                              // Only for teacher/student_teacher: Members
                                              return Align(
                                                alignment: Alignment.topCenter,
                                                child: OrgMembers(
                                                  teacherView: true,
                                                  organisationId:
                                                      organisationStateLoaded!
                                                          .id,
                                                  organisationName:
                                                      organisationStateLoaded!
                                                          .name,
                                                ),
                                              );
                                            default:
                                              return SizedBox.shrink();
                                          }
                                        },
                                      ),
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

          // Fallback for any other state
          return Scaffold(
            appBar: AppBar(title: Text('Unknown State')),
            body: Center(child: Text('Unknown state')),
          );
        },
      ),
    );
  }
}
