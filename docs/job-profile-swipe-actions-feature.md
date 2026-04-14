# Job Profile Swipe Actions Feature

## Feature Overview

This feature enables users to interact with job profiles using swipe gestures from the sidebar. Swiping right reveals an Edit button, and swiping left reveals a Delete button. These actions provide a convenient way to manage job profiles without requiring multiple taps or menu navigation. Deletion includes confirmation and automatically removes all associated work sessions from the database.

## User Experience

### Swipe gestures
- **Swipe right**: Reveals an Edit button (placeholder, nonfunctional for now)
- **Swipe left**: Reveals a Delete button with the job profile name

### Delete action workflow
1. User swipes left on a profile row
2. Delete button appears
3. User taps Delete
4. A confirmation dialog appears asking: "Delete "[profile name]" and all associated work sessions?"
5. User can cancel or confirm
6. If confirmed, the profile and all its work sessions are removed from the database
7. The sidebar refreshes and the profile list is updated
8. If another profile exists, it becomes the selected profile; if the deleted profile was selected, the next profile is selected

### Swipe guidance
- The sidebar header displays a helper message: "Swipe right to edit, left to delete"
- The message appears whenever at least one job profile exists
- The message appears alongside the reorder hint (when multiple profiles exist)

### Behavior with multiple swipe actions
- Only one swipe action can be open at a time
- Opening a new swipe action automatically closes any previously opened one
- Tapping elsewhere in the drawer closes the open swipe action

### Interaction with other features
- Swipe actions work alongside the existing drag-to-reorder functionality (drag handle still visible)
- Swipe actions work alongside profile selection (tapping the profile name still selects it and opens the long form)
- Creating a new profile adds it to the list and makes it immediately available for swipe actions

## Database behavior

### Delete action
- Calls `JobProfileDatabase.instance.deleteJobProfile(id)` 
- Removes the job profile from the `job_profiles` table
- Cascades to remove all associated entries in the `work_sessions` table via foreign key constraint with `ON DELETE CASCADE`
- Refreshes the profile list from the database to reflect the deletion

### Error handling
- If deletion fails, a snackbar shows: "Could not delete profile."
- The sidebar remains functional and allows retrying the delete action

## Implementation Notes

### Main sidebar changes
- The profile list uses `Slidable` widgets from the `flutter_slidable` package
- Each profile row has a right-swipe action pane (`startActionPane`) and a left-swipe action pane (`endActionPane`)
- Actions use `CustomSlidableAction` for precise control over button layout and sizing
- The actions are wrapped in `SlidableAutoCloseBehavior` to enforce single-open behavior
- Each action is a centered icon (24x24) with larger padding for safer tap targets

### Swipe action buttons
- **Edit button**: Blue (primary color), edit icon, 24x24
- **Delete button**: Red (error color), delete icon, 24x24
- Each button includes padding to prevent accidental adjacent taps
- Buttons auto-close when tapped (configured via `autoClose: true` in `CustomSlidableAction`)

### Delete confirmation dialog
- Uses `AlertDialog` with two options: Cancel and Delete
- Delete button is styled as a `FilledButton` (emphasizing the destructive action)
- The dialog shows the profile name in the message

## Files involved

- [lib/main.dart](../lib/main.dart): Sidebar UI, swipe action handling, delete confirmation dialog, profile refresh logic
- [lib/job_profile.dart](../lib/job_profile.dart): Job profile model used by the sidebar list
- [lib/job_profile_database.dart](../lib/job_profile_database.dart): `deleteJobProfile()` method removes profiles and cascades to work sessions
- [pubspec.yaml](../pubspec.yaml): `flutter_slidable: ^3.1.2` dependency for swipe gesture support
