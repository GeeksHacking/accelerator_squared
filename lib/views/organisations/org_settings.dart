import 'package:accelerator_squared/blocs/organisation/organisation_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:accelerator_squared/blocs/organisations/organisations_bloc.dart';
import 'package:accelerator_squared/util/snackbar_helper.dart';

class OrganisationSettingsDialog extends StatefulWidget {
  final String organisationId;
  final String orgName;
  final String orgDescription;
  final String joinCode;
  final bool isTeacher;
  final OrganisationBloc? organisationBloc;
  final OrganisationsBloc? organisationsBloc;

  const OrganisationSettingsDialog({
    super.key,
    required this.organisationId,
    required this.orgName,
    required this.orgDescription,
    required this.joinCode,
    required this.isTeacher,
    this.organisationBloc,
    this.organisationsBloc,
  });

  @override
  State<OrganisationSettingsDialog> createState() =>
      _OrganisationSettingsDialogState();
}

class _OrganisationSettingsDialogState
    extends State<OrganisationSettingsDialog> {
  bool editing = false;
  bool isSaving = false;
  bool isRefreshingJoinCode = false;
  bool isLeaving = false;
  bool isDeleting = false;
  TextEditingController nameFieldController = TextEditingController();
  TextEditingController descriptionFieldController = TextEditingController();
  String currentJoinCode = '';

  @override
  void initState() {
    super.initState();
    nameFieldController.text = widget.orgName;
    descriptionFieldController.text = widget.orgDescription;
    currentJoinCode = widget.joinCode;
  }

  @override
  Widget build(BuildContext context) {
    // Resolve blocs from injected instances first, fallback to context
    final OrganisationBloc organisationBloc =
        widget.organisationBloc ?? context.read<OrganisationBloc>();
    final OrganisationsBloc organisationsBloc =
        widget.organisationsBloc ?? context.read<OrganisationsBloc>();

    final Widget dialog = MultiBlocListener(
      listeners: [
        BlocListener<OrganisationsBloc, OrganisationsState>(
          listener: (context, state) {
            if (state is OrganisationsLoaded) {
              if (isSaving) {
                setState(() {
                  isSaving = false;
                  editing = false;
                });
                SnackBarHelper.showSuccess(
                  context,
                  message:
                      'Organisation "${nameFieldController.text}" updated successfully',
                );
              } else if (isLeaving) {
                setState(() {
                  isLeaving = false;
                });
                Navigator.of(context).pop();

                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);

                SnackBarHelper.showSuccess(
                  context,
                  message: 'Successfully left organisation "${widget.orgName}"',
                );
              } else if (isDeleting) {
                setState(() {
                  isDeleting = false;
                });
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
                SnackBarHelper.showSuccess(
                  context,
                  message:
                      'Organisation "${widget.orgName}" deleted successfully',
                );
              }
            } else if (state is OrganisationsError) {
              if (isSaving) {
                setState(() {
                  isSaving = false;
                });
                SnackBarHelper.showError(context, message: state.message);
              } else if (isLeaving) {
                setState(() {
                  isLeaving = false;
                });
                SnackBarHelper.showError(context, message: state.message);
              } else if (isDeleting) {
                setState(() {
                  isDeleting = false;
                });
                SnackBarHelper.showError(context, message: state.message);
              }
            }
          },
        ),
        BlocListener<OrganisationBloc, OrganisationState>(
          listener: (context, state) {
            if (state is OrganisationLoaded) {
              // Update the join code when it's refreshed
              if (isRefreshingJoinCode) {
                setState(() {
                  isRefreshingJoinCode = false;
                  currentJoinCode = state.joinCode;
                });
                SnackBarHelper.showSuccess(
                  context,
                  message: 'Join code refreshed!',
                );
              }
              // Handle organisation info save completion
              if (isSaving) {
                setState(() {
                  isSaving = false;
                  editing = false;
                });
                SnackBarHelper.showSuccess(
                  context,
                  message:
                      'Organisation "${nameFieldController.text}" updated successfully',
                );
              }
              // Update text controllers when not editing (to reflect external changes)
              if (!editing && mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !editing) {
                    final updatedName = state.name;
                    final updatedDescription = state.description;
                    if (updatedName != nameFieldController.text) {
                      nameFieldController.text = updatedName;
                    }
                    if (updatedDescription != descriptionFieldController.text) {
                      descriptionFieldController.text = updatedDescription;
                    }
                  }
                });
              }
            } else if (state is OrganisationError) {
              if (isRefreshingJoinCode) {
                setState(() {
                  isRefreshingJoinCode = false;
                });
                SnackBarHelper.showError(context, message: state.message);
              }
              if (isSaving) {
                setState(() {
                  isSaving = false;
                });
                SnackBarHelper.showError(context, message: state.message);
              }
            }
          },
        ),
      ],
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.business, color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Organisation Info",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
              ),
            ),
            if (widget.isTeacher)
              editing
                  ? IconButton(
                    onPressed:
                        isSaving
                            ? null
                            : () {
                              setState(() {
                                isSaving = true;
                              });
                              organisationBloc.add(
                                UpdateOrganisationEvent(
                                  name: nameFieldController.text,
                                  description: descriptionFieldController.text,
                                ),
                              );
                            },
                    icon:
                        isSaving
                            ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            )
                            : Icon(
                              Icons.save,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                    tooltip: "Save changes",
                  )
                  : IconButton(
                    onPressed: () {
                      setState(() {
                        editing = true;
                      });
                    },
                    icon: Icon(Icons.edit, size: 20),
                    tooltip: "Edit name",
                  ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width / 2.5,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Organisation Name
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.label,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Organisation Name",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            Spacer(),
                          ],
                        ),
                        SizedBox(height: 8),
                        editing
                            ? Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: nameFieldController,
                                    decoration: InputDecoration(
                                      hintText: "Enter organisation name",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                            : BlocBuilder<OrganisationBloc, OrganisationState>(
                              builder: (context, state) {
                                String displayName = widget.orgName;
                                if (state is OrganisationLoaded) {
                                  displayName = state.name;
                                  // Update controller when not editing
                                  if (!editing &&
                                      displayName != nameFieldController.text) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted && !editing) {
                                            nameFieldController.text =
                                                displayName;
                                          }
                                        });
                                  }
                                }
                                return Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                );
                              },
                            ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // Description
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.description,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Description",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            Spacer(),
                          ],
                        ),
                        SizedBox(height: 8),
                        editing
                            ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: descriptionFieldController,
                                        minLines: 3,
                                        maxLines: 5,
                                        decoration: InputDecoration(
                                          hintText:
                                              "Enter organisation description",
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                            : BlocBuilder<OrganisationBloc, OrganisationState>(
                              builder: (context, state) {
                                String displayDescription =
                                    widget.orgDescription;
                                if (state is OrganisationLoaded) {
                                  displayDescription = state.description;
                                  // Update controller when not editing
                                  if (!editing &&
                                      displayDescription !=
                                          descriptionFieldController.text) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted && !editing) {
                                            descriptionFieldController.text =
                                                displayDescription;
                                          }
                                        });
                                  }
                                }
                                return Text(
                                  displayDescription.isEmpty
                                      ? "No description provided"
                                      : displayDescription,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        displayDescription.isEmpty
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6)
                                            : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                  ),
                                );
                              },
                            ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // Join Code (for teachers and student teachers)
                if (widget.isTeacher)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.key,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Join Code",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              Spacer(),
                              IconButton(
                                onPressed:
                                    isRefreshingJoinCode
                                        ? null
                                        : () {
                                          setState(() {
                                            isRefreshingJoinCode = true;
                                          });
                                          organisationBloc.add(
                                            RefreshJoinCodeEvent(),
                                          );
                                        },
                                icon:
                                    isRefreshingJoinCode
                                        ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                          ),
                                        )
                                        : Icon(Icons.refresh, size: 20),
                                tooltip: "Refresh join code",
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                if (currentJoinCode.isNotEmpty) {
                                  Clipboard.setData(
                                    ClipboardData(text: currentJoinCode),
                                  );
                                  SnackBarHelper.showSuccess(
                                    context,
                                    message: 'Join code copied to clipboard!',
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: BlocBuilder<
                                OrganisationBloc,
                                OrganisationState
                              >(
                                builder: (context, state) {
                                  // Get the latest join code from the bloc state
                                  String displayJoinCode = currentJoinCode;
                                  if (state is OrganisationLoaded) {
                                    displayJoinCode = state.joinCode;
                                    // Update local state to keep it in sync
                                    if (displayJoinCode != currentJoinCode) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (mounted) {
                                              setState(() {
                                                currentJoinCode =
                                                    displayJoinCode;
                                              });
                                            }
                                          });
                                    }
                                  }

                                  return Row(
                                    children: [
                                      Text(
                                        displayJoinCode.isNotEmpty
                                            ? displayJoinCode
                                            : 'No join code',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                          letterSpacing: 2,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Icon(
                                        Icons.copy,
                                        size: 20,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Share this code with others to let them join your organisation",
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Leave Organisation Section
                // SizedBox(height: 32),
                // Divider(color: Colors.orange.withValues(alpha: 0.3)),
                SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.exit_to_app_rounded,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Leave Organisation",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Leaving this organisation will remove you from all projects and member lists. You can rejoin later using the join code.",
                                style: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      isLeaving
                                          ? null
                                          : () {
                                            showDialog(
                                              context: context,
                                              builder:
                                                  (context) => AlertDialog(
                                                    title: Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .exit_to_app_rounded,
                                                          color: Colors.orange,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Leave Organisation',
                                                        ),
                                                      ],
                                                    ),
                                                    content: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Are you sure you want to leave "${widget.orgName}"?',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        SizedBox(height: 8),
                                                        Text(
                                                          'This will:',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        SizedBox(height: 4),
                                                        Text(
                                                          '• Remove you from the organisation',
                                                        ),
                                                        Text(
                                                          '• Remove you from all projects',
                                                        ),
                                                        Text(
                                                          '• Remove your access to organisation data',
                                                        ),
                                                        SizedBox(height: 16),
                                                        Text(
                                                          'You can rejoin later using the join code.',
                                                          style: TextStyle(
                                                            color:
                                                                Colors.orange,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed:
                                                            () =>
                                                                Navigator.of(
                                                                  context,
                                                                ).pop(),
                                                        child: Text('Cancel'),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed:
                                                            isLeaving
                                                                ? null
                                                                : () {
                                                                  setState(() {
                                                                    isLeaving =
                                                                        true;
                                                                  });
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop(); // Close confirmation dialog
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop(); // Close settings dialog
                                                                  organisationsBloc.add(
                                                                    LeaveOrganisationEvent(
                                                                      organisationId:
                                                                          widget
                                                                              .organisationId,
                                                                    ),
                                                                  );
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop();
                                                                  // Leave organization page
                                                                },
                                                        style:
                                                            ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.orange,
                                                              foregroundColor:
                                                                  Colors.white,
                                                            ),
                                                        child:
                                                            isLeaving
                                                                ? SizedBox(
                                                                  width: 16,
                                                                  height: 16,
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                    valueColor:
                                                                        AlwaysStoppedAnimation<
                                                                          Color
                                                                        >(
                                                                          Colors
                                                                              .white,
                                                                        ),
                                                                  ),
                                                                )
                                                                : Text(
                                                                  'Leave Organisation',
                                                                ),
                                                      ),
                                                    ],
                                                  ),
                                            );
                                          },
                                  icon: Icon(Icons.exit_to_app_rounded),
                                  label: Text('Leave Organisation'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (widget.isTeacher) ...[
                        // SizedBox(height: 32),
                        // Divider(color: Colors.red.withValues(alpha: 0.3)),
                        SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "Danger Zone",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Deleting this organisation will permanently remove all projects, members, and data. This action cannot be undone.",
                                  style: TextStyle(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        isDeleting
                                            ? null
                                            : () {
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (context) => AlertDialog(
                                                      title: Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .delete_forever,
                                                            color: Colors.red,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text(
                                                            'Delete Organisation',
                                                          ),
                                                        ],
                                                      ),
                                                      content: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Are you absolutely sure you want to delete "${widget.orgName}"?',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          SizedBox(height: 8),
                                                          Text(
                                                            'This will permanently delete:',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                          SizedBox(height: 4),
                                                          Text(
                                                            '• All projects and their data',
                                                          ),
                                                          Text(
                                                            '• All project requests',
                                                          ),
                                                          Text(
                                                            '• All member information',
                                                          ),
                                                          Text(
                                                            '• The organisation itself',
                                                          ),
                                                          SizedBox(height: 16),
                                                          Text(
                                                            'This action cannot be undone.',
                                                            style: TextStyle(
                                                              color: Colors.red,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed:
                                                              () =>
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop(),
                                                          child: Text('Cancel'),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed:
                                                              isDeleting
                                                                  ? null
                                                                  : () {
                                                                    setState(() {
                                                                      isDeleting =
                                                                          true;
                                                                    });
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(); // Close confirmation dialog
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(); // Close settings dialog
                                                                    organisationsBloc.add(
                                                                      DeleteOrganisationEvent(
                                                                        organisationId:
                                                                            widget.organisationId,
                                                                      ),
                                                                    );
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop();
                                                                  },
                                                          style:
                                                              ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    Colors.red,
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                          child:
                                                              isDeleting
                                                                  ? SizedBox(
                                                                    width: 16,
                                                                    height: 16,
                                                                    child: CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2,
                                                                      valueColor: AlwaysStoppedAnimation<
                                                                        Color
                                                                      >(
                                                                        Colors
                                                                            .white,
                                                                      ),
                                                                    ),
                                                                  )
                                                                  : Text(
                                                                    'Delete Organisation',
                                                                  ),
                                                        ),
                                                      ],
                                                    ),
                                              );
                                            },
                                    icon: Icon(Icons.delete_forever),
                                    label: Text('Delete Organisation'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // If blocs are passed explicitly, ensure they are provided above the dialog tree
    if (widget.organisationBloc != null || widget.organisationsBloc != null) {
      return MultiBlocProvider(
        providers: [
          if (widget.organisationBloc != null)
            BlocProvider<OrganisationBloc>.value(
              value: widget.organisationBloc!,
            ),
          if (widget.organisationsBloc != null)
            BlocProvider<OrganisationsBloc>.value(
              value: widget.organisationsBloc!,
            ),
        ],
        child: dialog,
      );
    }

    return dialog;
  }
}
