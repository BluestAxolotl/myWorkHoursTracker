# Job Profile Reordering Feature

## Feature Overview

This feature lets users drag job profile entries in the sidebar to change their ordering. The order is preserved across app launches so the sidebar stays arranged the way the user left it.

## User Experience

### Sidebar ordering
- Job profiles appear in the sidebar as a draggable list.
- Each profile row includes a drag handle on the right side.
- Users can move a profile above or below other profiles to change the order.
- The selected profile still opens its long form in the main content area.

### Visual cue
- A helper message appears under the "Job Profiles" heading only when there is more than one job profile.
- The cue tells the user that the profile rows can be dragged to reorder.

### Delete and create behavior
- The delete button remains available on each profile row.
- The "Create Job Profile" entry remains at the bottom of the sidebar.
- Newly created profiles are added to the list and can be reordered immediately.

## Persistence

### Stored ordering
- Sidebar order is stored in SharedPreferences.
- The ordering key uses the job profile IDs in their current display order.
- On app startup, the saved order is applied after loading profiles from the database.
- If a saved profile no longer exists, it is ignored when rebuilding the list order.

### Refresh behavior
- After a profile is reordered, the new order is saved immediately.
- After profiles are refreshed from the database, the saved order is applied again so the sidebar stays consistent.
- If persistence fails, the sidebar still works in memory for the current session.

## Implementation Notes

### Main screen changes
- The sidebar profile list uses `ReorderableListView.builder`.
- Drag handles are shown using `ReorderableDragStartListener`.
- The sidebar header includes a conditional helper line when the list has more than one profile.

### Files involved
- [lib/main.dart](../lib/main.dart): Sidebar UI, reorder handling, and order persistence logic
- [lib/job_profile.dart](../lib/job_profile.dart): Job profile model used by the sidebar list
- [lib/job_profile_database.dart](../lib/job_profile_database.dart): Loads and deletes profiles from the local database
