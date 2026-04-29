/// Navigation intent emitted when the service needs the UI to navigate.
/// The app's navigation layer subscribes to [CoachingCueService.navigationIntentStream]
/// and handles the actual route pushing.
sealed class NavigationIntent {
  const NavigationIntent();
}

/// Intent to open the Health screen (e.g., from notification tap).
const NavigationIntent navigateToHealth = _NavigateToHealth();

class _NavigateToHealth extends NavigationIntent {
  const _NavigateToHealth();
}
