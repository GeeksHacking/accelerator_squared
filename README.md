<img src="web/favicon.png" width="50%" height="50%">

# Accelerator²

A project management web app designed for schools. It provides a structured workspace where teachers and students can collaborate on projects within organisations, track milestones, manage tasks, and monitor progress.

---

## Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
  - [lib/main.dart](#libmaindart)
  - [lib/theme.dart](#libthemedart)
  - [lib/blocs/](#libblocs)
  - [lib/models/](#libmodels)
  - [lib/views/](#libviews)
  - [lib/widgets/](#libwidgets)
  - [lib/util/](#libutil)
- [Firestore Data Model](#firestore-data-model)
- [User Roles](#user-roles)
- [State Management](#state-management)
- [Theming](#theming)
- [Responsive Layout](#responsive-layout)
- [Setup](#setup)
- [Deployment](#deployment)

---

## Overview

Accelerator² is a Flutter web application that models a school accelerator programme. The core concepts are:

- **Organisations** — groups of students and teachers (e.g. a club or class cohort)
- **Projects** — individual student/team projects within an organisation
- **Milestones** — checkpoints that track progress; can be organisation-wide or project-specific
- **Tasks** — actionable items scoped to a milestone
- **Comments** — threaded discussion on milestones
- **Files / Links** — resource attachments on projects

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI framework | Flutter (Material 3) |
| State management | `flutter_bloc` + `provider` |
| Backend / database | Firebase (Firestore, Auth, Analytics) |
| Hosting | Firebase Hosting |
| Font | IBM Plex Sans (variable) |
| Responsive layout | `responsive_framework` |

Key packages: `cloud_firestore`, `firebase_auth`, `firebase_analytics`, `bloc`, `flutter_bloc`, `provider`, `equatable`, `uuid`, `url_launcher`, `qr_flutter`, `tutorial_coach_mark`, `shared_preferences`, `page_transition`, `awesome_side_sheet`, `metadata_fetch`.

---

## Architecture

The app follows a **layered BLoC architecture**:

```
┌─────────────────────────────────────────────────────┐
│                     Views (UI)                      │
│  Login  │  Home  │  Projects Page  │  Project Details│
└────────────────────┬────────────────────────────────┘
                     │ events / state
┌────────────────────▼────────────────────────────────┐
│                BLoCs (Business Logic)               │
│  UserBloc │ OrganisationsBloc │ ProjectsBloc        │
│           │ OrganisationBloc  │                     │
└────────────────────┬────────────────────────────────┘
                     │ Firestore reads/writes
┌────────────────────▼────────────────────────────────┐
│              Firebase (Firestore + Auth)             │
└─────────────────────────────────────────────────────┘
```

`Provider` is used alongside BLoC for cross-cutting concerns that don't require event-driven updates: `ThemeProvider` (light/dark/system) and `InvitesPageProvider` (navigation state for the invites tab).

**Auth flow**: `AuthWrapper` listens to `UserBloc`. On `UserLoading` it shows a loading screen; on `UserInitial`/`UserError` it shows `LoginPage`; on `UserLoggedIn`/`UserCreated` it shows `HomePage`.

---

## Project Structure

```
lib/
├── main.dart              # App entry point
├── theme.dart             # Theme definitions and ThemeProvider
├── deploy_info.dart       # Deployment metadata
├── firebase_options.dart  # Firebase platform configuration
├── blocs/
│   ├── user/              # Auth state
│   ├── organisations/     # Organisation list state
│   ├── organisation/      # Single organisation detail state
│   └── projects/          # Project & milestone state
├── models/
│   ├── organisation.dart  # Organisation, Student, role types
│   ├── projects.dart      # Project, ProjectRequest, MilestoneReviewRequest
│   └── user.dart          # User model
├── views/
│   ├── auth_wrapper.dart  # Auth-aware routing
│   ├── loading_screen.dart
│   ├── Login Page/
│   ├── Home Page/
│   ├── Project/
│   └── organisations/
├── widgets/
│   └── organisation_card.dart
└── util/
    ├── util.dart           # Firestore helpers, join code generator
    ├── page_title.dart     # Platform-adaptive browser tab title
    ├── page_title_impl_io.dart
    ├── page_title_impl_web.dart
    └── snackbar_helper.dart
```

---

### lib/main.dart

Bootstraps the app. Firebase is initialised asynchronously; a `LoadingScreen` is shown until ready. Once Firebase is ready, the widget tree is wrapped with:

- `MultiBlocProvider` — provides `UserBloc`, `OrganisationsBloc`, and `ProjectsBloc` to the entire tree
- `MultiProvider` — provides `ThemeProvider` and `InvitesPageProvider`
- `MaterialApp` — themed via `ThemeProvider`, home set to `AuthWrapper`

---

### lib/theme.dart

Defines the complete Material 3 design system for the app:

- **`lightColorScheme` / `darkColorScheme`** — colour tokens generated with FlexColorScheme v8, using a navy-blue primary palette
- **`AppTheme.lightTheme` / `AppTheme.darkTheme`** — full `ThemeData` objects covering app bar, cards, buttons, inputs, navigation rail, dialogs, tabs, and FAB
- **`ThemeProvider`** — a `ChangeNotifier` with `AppThemeMode` (`system`, `light`, `dark`) that the settings page writes to
- **`InvitesPageProvider`** — tracks whether the invites tab is currently shown in the home navigation rail

Font family: **IBM Plex Sans** (variable font, supports weight and width axes).

---

### lib/blocs/

Each BLoC follows the standard `bloc` pattern: an `event` file, a `state` file, and a `bloc` file.

#### `user/`
Manages Firebase Auth state.

| Event | Description |
|---|---|
| `CheckIfUserIsLoggedInEvent` | Fired on startup to restore session |
| `UserLogsInWithGoogleEvent` | Google Sign-In via popup |
| `UserRegisterEvent` | Email/password registration |
| `UserLogoutEvent` | Signs out |

**First-sign-in onboarding**: on the first login, `UserBloc` creates a sample organisation ("Sample App Dev Club") with two sample projects and organisation-wide milestones, giving new users a pre-populated environment to explore.

States: `UserLoading`, `UserInitial`, `UserLoggedIn`, `UserCreated`, `UserError`.

#### `organisations/`
Manages the list of organisations the current user belongs to.

Key events: `FetchOrganisationsEvent`, `CreateOrganisationEvent`, `JoinOrganisationEvent`, `JoinOrganisationByCodeEvent`, `LeaveOrganisationEvent`, `DeleteOrganisationEvent`.

After the initial fetch, real-time Firestore stream subscriptions (`_uidMembershipsSubscription`, `_emailMembershipsSubscription`, per-org document streams) keep the list up to date without full page reloads.

Membership is queried by both UID and email to handle invited members who accept invitations.

#### `organisation/`
Manages the state of a single, currently-selected organisation (used within the projects page for detail views such as members, settings, and milestone review requests).

#### `projects/`
Manages projects and all their nested data (milestones, tasks, comments, file links) for the currently-selected organisation or project.

Key events: `FetchProjectsEvent`, `CreateProjectEvent`, `UpdateProjectEvent`, `DeleteProjectEvent`, `AddMilestoneEvent`, `UpdateMilestoneEvent`, `DeleteMilestoneEvent`, `CompleteMilestoneEvent`, `AddTaskEvent`, `UpdateTaskEvent`, `DeleteTaskEvent`, `AddCommentEvent`, `UpdateCommentEvent`, `DeleteCommentEvent`, `CreateFileLinkEvent`, `DeleteFileLinkEvent`.

When a specific project is selected, three real-time listeners are set up (project document, milestones sub-collection, files sub-collection).

---

### lib/models/

#### `organisation.dart`
- **`Organisation`** — top-level org model with id, name, description, member list, project list, project requests, milestone review requests, member count, current user's role, and join code.
- **`Student`** / **`StudentInOrganisation`** — member representation with name, email, photo URL, and org role type.
- **`UserInOrganisationType`** — enum: `student`, `teacher`, `studentTeacher`.

#### `projects.dart`
- **`Project`** — core project model (id, title, description, timestamps). Serialises to/from Firestore `Timestamp` or ISO-8601 strings.
- **`ProjectRequest`** — a pending request to create a project, submitted by a member and approved by a teacher.
- **`MilestoneReviewRequest`** — a request to have a milestone reviewed at org level.

---

### lib/views/

#### `auth_wrapper.dart`
Listens to `UserBloc` state and renders the correct top-level screen. Uses `responsive_framework` to wrap both `LoginPage` and `HomePage` with responsive breakpoints (Mobile ≤450, Tablet ≤800, Desktop ≤1920, 4K).

#### `loading_screen.dart`
Shown while Firebase initialises or while `UserBloc` emits `UserLoading`.

#### `Login Page/login.dart`
Animated login screen with fade, slide, and scale entry animations. Displays the Accelerator² branding and a single "Sign in with Google" button that dispatches `UserLogsInWithGoogleEvent`. Handles popup-cancellation silently.

#### `Home Page/`

| File | Purpose |
|---|---|
| `home.dart` | Main shell. Uses a `NavigationRail` sidebar (or bottom bar on mobile) with three tabs: organisations list, invites, and settings. Manages the tutorial coach-mark walkthrough (stored in `SharedPreferences`). |
| `invites.dart` | `OrgInvitesPage` — streams pending organisation invitations from a Firestore `collectionGroup` query filtered by the current user's UID and email. Accept/decline actions update the member document and invite document. |
| `settings.dart` | `SettingsPage` — displays the signed-in user's profile (avatar, name, email). Provides sign-out, theme mode selection, and a button to reset the tutorial walkthrough. Reads the last deployment date from `app_info/deployment` in Firestore. |
| `Add Organisation/add_organisation_button.dart` | Expandable FAB that surfaces create/join options. |
| `Add Organisation/create_organisation_dialog.dart` | Form dialog to create a new organisation with a name, description, and initial member email list. |
| `Add Organisation/join_organisation_dialog.dart` | Form dialog to join an organisation using a 6-character join code. |

#### `Project/`

| File | Purpose |
|---|---|
| `project_page.dart` | `ProjectsPage` — the main page shown after selecting an organisation. Contains a secondary `NavigationRail` for org-level sections: Projects, Members, Milestones, Requests, Stats, and Settings. Shows the project list and handles selection. Includes an org-level tutorial walkthrough. |
| `project_details.dart` | `ProjectDetails` — detailed view of a single project. Shows the milestone list (with toggle for completed milestones), file/URL links with metadata previews, a project-settings FAB, and member management. Dispatches `FetchProjectsEvent` to start real-time listening. Includes a project-level tutorial. |
| `project_card.dart` | Card widget summarising a project in the projects list. |
| `create_new_project.dart` | Form to create a project within an organisation, with title, description, and optional member emails. |
| `project_settings.dart` | Inline settings sheet for editing a project's title and description. |
| `project_members.dart` | Dialog for managing project-level members (add/remove). |
| `milestone_sheet.dart` | Side sheet (using `awesome_side_sheet`) showing full milestone details including tasks and comments. |
| `tasks/create_task_dialog.dart` | Dialog for creating a task within a milestone. |
| `comments/comments_dialog.dart` | Dialog-based comments view. |
| `comments/comments_sheet.dart` | Sheet-based comments view. |
| `teacher_ui/create_milestone_dialog.dart` | Teacher-only dialog for creating milestones, with support for org-wide milestones (shared across projects via `sharedId`). |

#### `organisations/`

These views appear as tabs within `ProjectsPage`'s secondary navigation rail when an organisation is selected.

| File | Purpose |
|---|---|
| `org_members.dart` | View and manage all members of the organisation. Supports inviting by email (creates a member doc + invite doc), removing members, and changing roles. |
| `org_milestones.dart` | Organisation-wide milestone overview showing milestone status across all projects. Teachers can create org-wide milestones from here. |
| `org_requests.dart` | Lists pending `ProjectRequest` and `MilestoneReviewRequest` items. Teachers can approve or decline. |
| `org_settings.dart` | Edit organisation name/description, view/regenerate the join code, and delete or leave the organisation. |
| `org_stats.dart` | `OrgStatistics` dashboard — aggregates milestone completion percentages across all projects, using data from `ProjectsBloc`. |
| `decline_milestone_dialog.dart` | Confirmation dialog when a teacher declines a milestone review request. |
| `join_organization_dialog.dart` | Alternative join-by-code dialog surfaced from within an org context. |

---

### lib/widgets/

#### `organisation_card.dart`
Card widget displayed in the Home Page organisations list. Shows the organisation name, description, member count, the current user's role badge, and navigates to `ProjectsPage` on tap.

---

### lib/util/

#### `util.dart`
Shared Firestore helper functions used across BLoCs and views:

- `fetchUserDisplayNameByUid` / `fetchUserDisplayNameByEmail` — single-user name lookup
- `fetchUserDataByUid` / `fetchUserDataByEmail` — full user data lookup
- `batchFetchUserDisplayNamesByUids` — chunked batch lookup (respects Firestore's `whereIn` limit of 10)
- `generateJoinCode` — generates a random 6-character alphanumeric join code
- `loadOrganisationDataById` — loads a complete `Organisation` object including sub-collections (projects, project requests, members, milestone review requests); handles both UID and email-based membership lookups

#### `page_title.dart`
Conditional export that selects `page_title_impl_web.dart` on web (updates the browser tab title via `dart:html`) or `page_title_impl_io.dart` on other platforms (no-op).

#### `snackbar_helper.dart`
`SnackBarHelper.showSuccess` / `SnackBarHelper.showError` — convenience wrappers for displaying styled snack bars.

---

## Firestore Data Model

```
users/
  {uid}/
    email, displayName, photoUrl, updatedAt

organisations/
  {orgId}/
    name, description, joinCode
    members/
      {uid or email}/
        role, email, uid, displayName, status, addedAt, addedBy
    invites/
      {inviteId}/
        orgId, orgName, toEmail, toUid, fromUid, status, memberDocId
    projects/
      {projectId}/
        title, description, createdAt, updatedAt, createdBy
        members/
          {uid}/  role, email, uid, status
        milestones/
          {milestoneId}/
            name, description, sharedId, isCompleted, dueDate, ...
            tasks/
              {taskId}/  ...
            comments/
              {commentId}/  ...
        files/
          {fileId}/  url, title, metadata, ...
    projectRequests/
      {requestId}/
        title, description, requestedBy, requesterEmail, requestedAt, memberEmails
    milestoneReviewRequests/
      {requestId}/
        milestoneId, milestoneName, projectId, projectName, isOrgWide, dueDate, sentForReviewAt

app_info/
  deployment/
    last_deploy_date (Timestamp)
```

---

## User Roles

| Role | Capabilities |
|---|---|
| `teacher` | Full access: create/delete projects, manage members, approve/decline requests and milestone reviews, delete organisation |
| `student_teacher` | Elevated student with some teacher privileges |
| `member` (student) | Create project requests, submit milestones for review, add tasks and comments |

Role is stored per-organisation in the `members` sub-collection and also per-project in the project's `members` sub-collection.

---

## State Management

The app uses two complementary state management approaches:

**BLoC** (for async, event-driven data):
- `UserBloc` — singleton, lives for the app lifetime
- `OrganisationsBloc` — singleton, manages org list with real-time streams
- `OrganisationBloc` — scoped to the currently selected org
- `ProjectsBloc` — singleton, scoped to the currently selected org/project

**Provider** (for synchronous, UI-level state):
- `ThemeProvider` — current theme mode
- `InvitesPageProvider` — whether the invites tab is active in the nav rail

---

## Theming

The app uses **Material 3** with a custom colour scheme generated via FlexColorScheme:

- Primary: Navy blue (`#223A5E` light / `#748BAC` dark)
- Secondary: Teal (`#144955` light / `#539EAF` dark)
- Full light and dark colour schemes defined as `const ColorScheme` values
- Users can choose **System**, **Light**, or **Dark** mode from the Settings page
- The preference is held in memory (via `ThemeProvider`) and resets on refresh; a persistence layer can be added via `SharedPreferences` if needed

---

## Responsive Layout

`responsive_framework` is used to define four named breakpoints:

| Name | Width range |
|---|---|
| `MOBILE` | 0 – 450 px |
| `TABLET` | 451 – 800 px |
| `DESKTOP` | 801 – 1920 px |
| `4K` | 1921 px+ |

Layouts adapt at the widget level by checking `ResponsiveBreakpoints.of(context)`.

---

## Setup

### Prerequisites

- Flutter SDK ≥ 3.7.0
- Firebase project (`accelerator-squared-9e24e` or your own)
- Node.js (for deployment date script)

### 1. Configure Firebase

```bash
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project=accelerator-squared-9e24e
```

This generates `lib/firebase_options.dart`.

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Run the app

```bash
flutter run -d chrome
```

---

## Deployment

The app is deployed to Firebase Hosting.

```bash
flutter build web
firebase deploy
```

After deploying, update the deployment date shown in the Settings page:

```bash
npm install           # first time only
npm run update-deploy-date
```

This runs `update_deploy_date_simple.js`, which writes a server timestamp to `app_info/deployment` in Firestore. See [DEPLOYMENT_SETUP.md](DEPLOYMENT_SETUP.md) for full details and alternative approaches.