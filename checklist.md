# Tiny Tasks Demo Checklist

## Authentication and startup

- [ ] App launch + session restore: open app and show login or automatic session restore.
- [ ] Create account (email/password): demonstrate sign-up flow.
- [ ] Sign in (email/password): log in and land on the main task screen.
- [ ] Google Sign-In: demonstrate Google login option.
- [ ] Initial cloud sync on login: mention tasks and big tasks sync from Firestore.

## Daily tasks flow

- [ ] Tasks screen overview: show date card, AM/PM/Full Day filters, refresh, history, settings, and add button.
- [ ] Add a task: create a task with title, description, time slot, optional time, and optional reminder.
- [ ] Task list behavior: show badges and date/time display.
- [ ] Complete task: check a task and show the temporary undo card.
- [ ] Edit task: swipe to edit title/description/time/slot/reminder.
- [ ] Delete task: swipe to delete and then undo restore.
- [ ] Date navigation: use previous/next arrows and calendar picker.
- [ ] Calendar markers: show dots on dates that contain tasks.
- [ ] Overdue auto-reschedule: mention incomplete past tasks move to today and are flagged.

## History

- [ ] Open History view from the top-left icon.
- [ ] Show completed-task timeline grouped by date (Today/Yesterday labels).
- [ ] Uncheck a completed task from history and show undo.

## Big Tasks and AI decomposition

- [ ] Switch to Big Tasks tab from bottom navigation.
- [ ] Create Big Task: enter title, description, priority, due date, and color.
- [ ] AI decomposition: run Create & Decompose.
- [ ] Review subtasks: check/uncheck suggested subtasks and edit suggested dates.
- [ ] Save selected subtasks and show they are added into the task system.
- [ ] Expand Big Task card and show progress (x/y subtasks) and due date.
- [ ] Edit Big Task metadata.
- [ ] Manage tiny tasks inside Big Task: toggle complete and edit title/date.
- [ ] Delete Big Task.

## Settings, integrations, and sign-out

- [ ] Notifications behavior: explain reminders schedule local notifications when enabled.
- [ ] Google Calendar integration: show tasks creating calendar events (Google-auth sessions).
- [ ] Settings screen: demo Notifications switch and Dark Mode toggle.
- [ ] Profile screen: show account email/UID and Sign Out.
- [ ] Sign out and sign back in to confirm data persistence and sync.
