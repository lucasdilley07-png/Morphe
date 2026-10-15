# Verification mode (simulator walkthroughs)

Debug builds accept the launch argument `-MorpheLocalMode`: the app runs on
the on-device account service (`LocalAuthService`) with every backend
service a no-op, so each screen can be walked in the simulator without the
live Firebase project. It is compiled out of Release builds.

```bash
xcrun simctl launch <simulator-udid> com.morpheapp.Morphe -MorpheLocalMode
```

Local mode signs its own test account in at launch (the simulator cannot
type reliably into iOS "new password" fields): Verify Athlete,
verify@morphe.test. It exists only inside that simulator's app data and only
in Debug builds.
Add `-MorpheLocalOnboarded` to skip onboarding with a fixed test athlete
(Verify, born 1998, Gain muscle + Get stronger, 4 days a week, terms agreed,
@verifyathlete) and land on the tour, then the app:

```bash
xcrun simctl launch <simulator-udid> com.morpheapp.Morphe -MorpheLocalMode -MorpheLocalOnboarded
```

Simulator notes: a tap that resigns a focused text field is spent on the
focus change, so tap once more before typing into the next field; and taps
within ~12 pt of the bottom edge land on the home indicator, not the app.
