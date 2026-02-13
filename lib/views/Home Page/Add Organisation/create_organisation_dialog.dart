import 'dart:html' as html;

import 'package:accelerator_squared/blocs/organisations/organisations_bloc.dart';
import 'package:accelerator_squared/blocs/user/user_bloc.dart';
import 'package:accelerator_squared/util/util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateOrganisationDialog extends StatefulWidget {
  const CreateOrganisationDialog({super.key});

  @override
  State<CreateOrganisationDialog> createState() =>
      _CreateOrganisationDialogState();
}

class _CreateOrganisationDialogState extends State<CreateOrganisationDialog> {
  TextEditingController orgNameController = TextEditingController();
  TextEditingController orgDescController = TextEditingController();
  TextEditingController emailAddingController = TextEditingController();
  List<Map<String, dynamic>> orgMemberList =
      []; // Changed to store email and displayName
  bool isCreating = false;
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  String? _lastCreatedOrgName;

  @override
  Widget build(BuildContext context) {
    var userState = context.read<UserBloc>().state as UserLoggedIn;

    return BlocListener<OrganisationsBloc, OrganisationsState>(
      listener: (context, state) {
        if (state is OrganisationsLoaded && isCreating) {
          setState(() {
            isCreating = false;
          });
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Organisation "${_lastCreatedOrgName ?? orgNameController.text}" created successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else if (state is OrganisationsError && isCreating) {
          setState(() {
            isCreating = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width / 2.5,
          height: MediaQuery.of(context).size.height / 1.3,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                // Header with icon
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.business_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: 24),

                // Title
                Text(
                  "Create New Organisation",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 32),

                // Organisation name input
                TextField(
                  controller: orgNameController,
                  decoration: InputDecoration(
                    label: Text("Organisation Name"),
                    hintText: "Enter organisation name",
                    prefixIcon: Icon(Icons.business_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                  ),
                ),
                SizedBox(height: 16),

                // Organisation description input
                TextField(
                  controller: orgDescController,
                  minLines: 3,
                  maxLines: 4,
                  decoration: InputDecoration(
                    label: Text("Organisation Description"),
                    hintText: "Enter organisation description",
                    prefixIcon: Icon(Icons.description_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                  ),
                ),

                // Google Drive integration
                SizedBox(height: 24),

                // Member management section
                Row(
                  children: [
                    Icon(
                      Icons.people_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Add Members",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      onPressed: () async {
                        final userState =
                            context.read<UserBloc>().state as UserLoggedIn;

                        final uploadInput = html.FileUploadInputElement()
                          ..accept = '.csv,text/csv';
                        uploadInput.click();

                        uploadInput.onChange.listen((event) {
                          final file = uploadInput.files?.first;
                          if (file == null) return;

                          final reader = html.FileReader();
                          reader.onLoadEnd.listen((_) async {
                            final content = reader.result as String?;
                            if (content == null || content.isEmpty) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Selected CSV file is empty.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            await _importOrganisationFromCsv(
                              content,
                              userState,
                            );
                          });
                          reader.readAsText(file);
                        });
                      },
                        icon: Icon(Icons.file_upload_rounded),
                        label: Text("Upload from CSV"),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Add member input row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: emailAddingController,
                        decoration: InputDecoration(
                          hintText: "Enter member's email",
                          label: Text("Member Email"),
                          prefixIcon: Icon(Icons.email_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () async {
                        final email = emailAddingController.text.trim();
                        if (email.isNotEmpty) {
                          // Prevent adding self
                          if (email == userState.email) {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        color: Colors.red,
                                        size: 24,
                                      ),
                                      SizedBox(width: 8),
                                      Text("Cannot Add Yourself"),
                                    ],
                                  ),
                                  content: Text(
                                    "You will automatically be added as the creator. Please do not add your own email.",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text("OK"),
                                    ),
                                  ],
                                );
                              },
                            );
                            return;
                          }

                          // Check if email is already in list
                          if (orgMemberList.any(
                            (m) =>
                                (m['email'] as String).toLowerCase() ==
                                email.toLowerCase(),
                          )) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'This email is already in the list',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          // Look up display name for this email
                          String? displayName;
                          try {
                            displayName = await fetchUserDisplayNameByEmail(
                              firestore,
                              email,
                            );
                          } catch (e) {
                            // Continue even if lookup fails
                            print('Error fetching display name for $email: $e');
                          }

                          setState(() {
                            orgMemberList.add({
                              'email': email,
                              'displayName': displayName,
                            });
                          });
                          emailAddingController.clear();
                        } else {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: Colors.red,
                                      size: 24,
                                    ),
                                    SizedBox(width: 8),
                                    Text("Invalid Email"),
                                  ],
                                ),
                                content: Text(
                                  "Email field cannot be empty when adding a new member.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text("OK"),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      },
                      icon: Icon(Icons.add_rounded, size: 20),
                      label: Text("Invite"),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Members list
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height / 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      orgMemberList.isNotEmpty
                          ? ListView.builder(
                            padding: EdgeInsets.all(8),
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              return Card(
                                margin: EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                    child: Text(
                                      _getInitials(orgMemberList[index]),
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    _getDisplayName(orgMemberList[index]),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle:
                                      (orgMemberList[index]['displayName'] !=
                                                  null &&
                                              (orgMemberList[index]['displayName']
                                                      as String)
                                                  .isNotEmpty)
                                          ? Text(
                                            orgMemberList[index]['email'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                          )
                                          : null,
                                  trailing: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        orgMemberList.removeAt(index);
                                      });
                                    },
                                    icon: Icon(
                                      Icons.remove_circle_outline_rounded,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              );
                            },
                            itemCount: orgMemberList.length,
                          )
                          : Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline_rounded,
                                    size: 48,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "No members added yet",
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                ),
                SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
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
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed:
                            isCreating
                                ? null
                                : () {
                                  setState(() {
                                    _lastCreatedOrgName = orgNameController.text;
                                    isCreating = true;
                                  });
                                  context.read<OrganisationsBloc>().add(
                                    CreateOrganisationEvent(
                                      name: orgNameController.text,
                                      description: orgDescController.text,
                                      memberEmails:
                                          orgMemberList
                                              .map((m) => m['email'] as String)
                                              .toList(),
                                    ),
                                  );
                                },
                        child:
                            isCreating
                                ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                )
                                : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_business_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      "Create Organisation",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDisplayName(Map<String, dynamic> member) {
    final displayName = member['displayName'] as String?;
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    return member['email'] as String? ?? 'Unknown';
  }

  String _getInitials(Map<String, dynamic> member) {
    final displayName = member['displayName'] as String?;
    final email = member['email'] as String? ?? '';

    if (displayName != null && displayName.isNotEmpty) {
      final parts = displayName.trim().split(' ');
      if (parts.length >= 2) {
        return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
      } else if (parts.isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
    }

    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }

  Future<void> _importOrganisationFromCsv(
    String csvContent,
    UserLoggedIn userState,
  ) async {
    if (csvContent.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV file is empty.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final rows = _parseCsv(csvContent);
    if (rows.length <= 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV file does not contain any data rows.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final header = rows.first.map((h) => h.trim()).toList();
    int colIndex(String name) => header.indexWhere(
          (h) => h.toLowerCase() == name.toLowerCase(),
        );

    String cell(List<String> row, String name) {
      final idx = colIndex(name);
      if (idx < 0 || idx >= row.length) return '';
      return row[idx];
    }

    String orgNameFromCsv = '';
    final orgNameIdx = colIndex('organisationName');
    if (orgNameIdx != -1 && rows.length > 1) {
      orgNameFromCsv = rows[1][orgNameIdx];
    }

    final String finalOrgName =
        (orgNameFromCsv.isNotEmpty ? orgNameFromCsv : orgNameController.text)
            .trim();
    if (finalOrgName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Organisation name is missing in CSV and form.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String finalOrgDescription = orgDescController.text.trim();
    if (finalOrgDescription.isEmpty) {
      finalOrgDescription = 'Imported organisation from CSV';
    }

    // Append "-1" to the organisation name to avoid naming conflicts
    final String storedOrgName = '$finalOrgName-1';

    setState(() {
      isCreating = true;
    });

    try {
      // Create organisation document
      final orgRef = firestore.collection('organisations').doc();
      final orgId = orgRef.id;
      final joinCode = generateJoinCode();

      await orgRef.set({
        'name': storedOrgName,
        'description': finalOrgDescription,
        'joinCode': joinCode,
      });

      // Add creator as teacher member
      await orgRef.collection('members').doc(userState.userId).set({
        'role': 'teacher',
        'email': userState.email,
        'uid': userState.userId,
        'displayName': userState.displayName,
        'status': 'active',
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': userState.userId,
      });

      // Group data by project / milestone / task
      final Map<String, Map<String, dynamic>> projects = {};

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        final projectName = cell(row, 'projectName').trim();
        final projectDescription = cell(row, 'projectDescription').trim();
        if (projectName.isEmpty) {
          // Skip rows without a project name
          continue;
        }

        final projectKey = projectName;
        projects.putIfAbsent(projectKey, () {
          return {
            'name': projectName,
            'description': projectDescription,
            'milestones': <String, Map<String, dynamic>>{},
            'unlinkedTasks': <Map<String, dynamic>>[],
          };
        });

        final project = projects[projectKey]!;
        if (projectDescription.isNotEmpty &&
            (project['description'] as String).isEmpty) {
          project['description'] = projectDescription;
        }

        final milestoneName = cell(row, 'milestoneName').trim();
        final milestoneDescription = cell(row, 'milestoneDescription').trim();
        final milestoneDueDateRaw = cell(row, 'milestoneDueDate').trim();
        final milestoneIsCompletedStr = cell(row, 'milestoneIsCompleted').trim();
        final milestoneIsCompleted =
            milestoneIsCompletedStr.toLowerCase() == 'true';

        final taskName = cell(row, 'taskName').trim();
        final taskDescription = cell(row, 'taskDescription').trim();
        final taskDeadlineRaw = cell(row, 'taskDeadline').trim();
        final taskIsCompletedStr = cell(row, 'taskIsCompleted').trim();
        final taskIsCompleted = taskIsCompletedStr.toLowerCase() == 'true';

        if (milestoneName.isNotEmpty) {
          final milestoneKey = '$milestoneName|$milestoneDueDateRaw';
          final milestones =
              project['milestones'] as Map<String, Map<String, dynamic>>;
          milestones.putIfAbsent(milestoneKey, () {
            return {
              'name': milestoneName,
              'description': milestoneDescription,
              'dueDateRaw': milestoneDueDateRaw,
              'isCompleted': milestoneIsCompleted,
              'tasks': <Map<String, dynamic>>[],
            };
          });
          final milestone = milestones[milestoneKey]!;
          if (milestoneDescription.isNotEmpty &&
              (milestone['description'] as String).isEmpty) {
            milestone['description'] = milestoneDescription;
          }

          if (taskName.isNotEmpty) {
            final tasks = milestone['tasks'] as List<Map<String, dynamic>>;
            tasks.add({
              'name': taskName,
              'description': taskDescription,
              'deadlineRaw': taskDeadlineRaw,
              'isCompleted': taskIsCompleted,
            });
          }
        } else if (taskName.isNotEmpty) {
          final unlinkedTasks =
              project['unlinkedTasks'] as List<Map<String, dynamic>>;
          unlinkedTasks.add({
            'name': taskName,
            'description': taskDescription,
            'deadlineRaw': taskDeadlineRaw,
            'isCompleted': taskIsCompleted,
          });
        }
      }

      // Write projects, milestones and tasks to Firestore
      int createdProjects = 0;
      int createdMilestones = 0;
      int createdTasks = 0;

      DateTime? _parseDate(String raw) {
        if (raw.isEmpty) return null;
        try {
          return DateTime.parse(raw);
        } catch (_) {
          return null;
        }
      }

      for (final projectEntry in projects.entries) {
        final projectData = projectEntry.value;
        final projectName = projectData['name'] as String;
        final projectDescription = projectData['description'] as String;

        final projectRef =
            orgRef.collection('projects').doc(); // New project ID
        await projectRef.set({
          'title': projectName,
          'description': projectDescription,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdBy': userState.userId,
        });

        // Add creator as teacher to project members
        await projectRef.collection('members').doc(userState.userId).set({
          'role': 'teacher',
          'email': userState.email,
          'uid': userState.userId,
          'status': 'active',
          'addedAt': FieldValue.serverTimestamp(),
        });

        createdProjects++;

        final milestones =
            projectData['milestones'] as Map<String, Map<String, dynamic>>;

        // First create milestones and then their tasks
        for (final milestoneEntry in milestones.entries) {
          final milestoneData = milestoneEntry.value;
          final milestoneName = milestoneData['name'] as String;
          final milestoneDescription =
              milestoneData['description'] as String? ?? '';
          final milestoneDueDateRaw =
              milestoneData['dueDateRaw'] as String? ?? '';
          final milestoneIsCompleted =
              milestoneData['isCompleted'] as bool? ?? false;

          final DateTime? milestoneDueDate = _parseDate(milestoneDueDateRaw);

          final milestoneRef = projectRef.collection('milestones').doc();
          await milestoneRef.set({
            'name': milestoneName,
            'description': milestoneDescription,
            if (milestoneDueDate != null)
              'dueDate': Timestamp.fromDate(milestoneDueDate),
            'isCompleted': milestoneIsCompleted,
          });

          createdMilestones++;

          final tasks =
              milestoneData['tasks'] as List<Map<String, dynamic>>? ?? [];
          for (final task in tasks) {
            final taskName = task['name'] as String? ?? '';
            final taskDescription =
                task['description'] as String? ?? '';
            final taskDeadlineRaw = task['deadlineRaw'] as String? ?? '';
            final taskIsCompleted = task['isCompleted'] as bool? ?? false;

            final DateTime? taskDeadline = _parseDate(taskDeadlineRaw);

            await projectRef.collection('tasks').doc().set({
              'name': taskName,
              'content': taskDescription,
              if (taskDeadline != null)
                'deadline': Timestamp.fromDate(taskDeadline),
              'isCompleted': taskIsCompleted,
              'milestoneId': milestoneRef.id,
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': userState.userId,
            });
            createdTasks++;
          }
        }

        // Unlinked tasks (no milestone)
        final unlinkedTasks =
            projectData['unlinkedTasks'] as List<Map<String, dynamic>>;
        for (final task in unlinkedTasks) {
          final taskName = task['name'] as String? ?? '';
          final taskDescription = task['description'] as String? ?? '';
          final taskDeadlineRaw = task['deadlineRaw'] as String? ?? '';
          final taskIsCompleted = task['isCompleted'] as bool? ?? false;

          final DateTime? taskDeadline = _parseDate(taskDeadlineRaw);

          await projectRef.collection('tasks').doc().set({
            'name': taskName,
            'content': taskDescription,
            if (taskDeadline != null)
              'deadline': Timestamp.fromDate(taskDeadline),
            'isCompleted': taskIsCompleted,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': userState.userId,
          });
          createdTasks++;
        }
      }

      if (!mounted) return;

      // Refresh organisations list so the new one appears
      context.read<OrganisationsBloc>().add(FetchOrganisationsEvent());

      setState(() {
        isCreating = false;
      });

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Organisation "$storedOrgName" imported ($createdProjects projects, $createdMilestones milestones, $createdTasks tasks).',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isCreating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import organisation from CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<List<String>> _parseCsv(String input) {
    final List<List<String>> rows = [];
    final StringBuffer fieldBuffer = StringBuffer();
    final List<String> currentRow = [];
    bool inQuotes = false;

    void endField() {
      currentRow.add(fieldBuffer.toString());
      fieldBuffer.clear();
    }

    void endRow() {
      if (currentRow.isNotEmpty || fieldBuffer.isNotEmpty) {
        endField();
        rows.add(List<String>.from(currentRow));
        currentRow.clear();
      }
    }

    for (int i = 0; i < input.length; i++) {
      final char = input[i];

      if (inQuotes) {
        if (char == '"') {
          // Escaped quote
          if (i + 1 < input.length && input[i + 1] == '"') {
            fieldBuffer.write('"');
            i++; // Skip next quote
          } else {
            inQuotes = false;
          }
        } else {
          fieldBuffer.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          endField();
        } else if (char == '\r') {
          // Ignore, handle on '\n'
          continue;
        } else if (char == '\n') {
          endRow();
        } else {
          fieldBuffer.write(char);
        }
      }
    }

    // Flush last field/row
    if (inQuotes) {
      // Unclosed quote, still push whatever we have
      inQuotes = false;
    }
    if (fieldBuffer.isNotEmpty || currentRow.isNotEmpty) {
      endField();
      rows.add(List<String>.from(currentRow));
    }

    return rows;
  }
}
