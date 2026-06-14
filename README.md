# Morphe Demo App

Morphe is a demo-first SwiftUI app for AI-guided fitness, personal training, and sports coaching. It is designed to feel polished enough for investor demos, coach walkthroughs, and early user testing without requiring a production backend.

## How to run

1. Open `Morphe.xcodeproj` in Xcode.
2. Select the `Morphe` scheme.
3. Run on an iPhone simulator or a connected iPhone.

## What was built

### App foundation

- App shell with launch sequence
- First-open landing page with Morphe welcome copy and a clear Start action
- Athlete / Coach account selection during onboarding
- Gender selection during onboarding
- Account type switching from the profile component
- Bottom navigation with left-to-right swipe between top-level client and coach sections
- A cleaner top app chrome with profile-first identity, a real quick-add launcher, and universal search
- A floating Morphe AI launcher inspired by assistant-style in-app shortcuts, with quick intents and role-aware replies
- Client layout with 5 tabs: Home, Train, Network, Progress, More
- Coach layout with 5 tabs: Home, Athletes, Build, Library, Inbox
- Shared premium card system, badges, banners, avatar visuals, progress bars, toast feedback, celebration overlays, accent color personalization, and a more social/feed-first layout rhythm
- Full mock data layer for users, athletes, coaches, workouts, sessions, drills, notifications, reports, profile identity, and subscription previews

### Client features

- Onboarding flow with multi-select sports, training styles, and goals (up to 5 each), experience, pain, equipment, schedule, coaching tone, confidence, obstacle, theme, accent color, avatar, generated plan preview, and a welcome handoff
- Onboarding flow with:
  - Morphe landing page
  - gender selection
  - account type
  - goals
  - equipment access
  - sports and training styles
  - coaching tone
  - full profile review
  - AI personalized-plan loading handoff
- Today command center with a clearer next-session-first flow:
  - hero identity card with greeting, motivation, plan context, and score snapshot
  - a stronger next-move card for starting the day
  - one adaptive "Adjust My Day" card that combines quick check-in, confidence, and fallback options
  - Done For Today state with share / recovery / progress actions
  - quick check-in + confidence rating
  - Plan B and Minimum Win Mode
  - AI coach insight
  - streak protection
  - simplified daily plan with a clearer stopping point
  - partner workout pairing
  - progress entry point
- Train flow with:
  - workout layout toggle: cards / compact
  - current program card
  - workout flow tracker
  - active in-session workout tracker with current exercise, set progress, and next-step controls
  - session card
  - partner session mode with ready check
  - rest timer
  - exercise cards
  - drill cards
  - exercise swap flow
  - pain/injury flagging
  - workout feedback
  - workout history
- Progress with:
  - weekly AI summary
  - progress snapshot
  - weekly report
  - program compliance
  - Morphe Score trend
  - weekly consistency
  - weight trend
  - pattern insights
  - transformation roadmap
  - photo progress + AI scan
  - badges
  - recent wins
- More with:
  - scores + levels
  - quick tools
  - anatomy + exercise library
  - nutrition basics
  - lessons + quizzes
- Community with:
  - professional-style coach + athlete network feed
  - feed / support split inside one network surface
  - posts with comments, ranks, and quick reactions
  - story/status rail for coaches, partners, and challenges
  - groups
  - challenges
  - leaderboards
  - suggested connections
  - partner workout activity
  - privacy guidance
- Universal search with:
  - accounts
  - workouts / plans
  - exercise + drill library
  - posts
  - recommended connections
  - real account preview destinations for coaches and athletes
- Quick add with role-aware shortcuts for athletes and coaches, including a workout action that respects the real train -> finish -> log flow
- Floating Morphe AI agent with:
  - athlete quick intents that change based on Home, Train, Network, Progress, or More
  - coach quick intents that change based on Home, Athletes, Build, Library, or Inbox
  - context-aware replies that reference the current screen, selected athlete, and active workout state
  - a compact launcher during live workouts so it stays helpful without competing for focus
  - persistent bottom-corner access above the main navigation
- Profile sheet with:
  - free Premium Profile presentation
  - account type switcher
  - social resume / athletic resume summary
  - multi-sport and multi-goal identity mix
  - multi-training-style identity mix
  - athlete workout plan by coach card
  - coach CRM database preview
  - avatar customization
  - banner customization
  - theme presets
  - accent color palette selector
  - coaching tone selector
  - badges and milestones
  - transformation timeline
  - personal records
  - featured workouts and videos
  - AI performance bio
  - shareable profile card
  - nutrition summary
  - lessons and quizzes
  - subscription preview

### Coach features

- Dashboard / command center with:
  - premium hero summary
  - launchpad for fast jumps into athletes, build, and inbox
  - athlete metrics
  - intervention queue
  - readiness view
  - alerts
  - wins
  - upcoming sessions
- Athletes with:
  - sport filters
  - athlete cards
  - athlete profile modal
  - availability/constraints
  - coach notes
  - compliance
  - recovery and load context
- Programs with:
  - sport program builder
  - session builder
  - training block planner
  - workout templates
  - assign-to-athlete flow
- Library with:
  - coach playbooks
  - skill drill library
  - exercise references
  - video review hub
  - sport testing snapshot
  - coach quality analytics
- Messages with:
  - 1:1 threads
  - network view for coach posts and comments
  - CRM section for leads and outreach
  - smart outreach suggestions
  - message templates
  - group coaching
  - attendance tracking
  - broadcast composer
  - outreach CRM

## Client demo flow

1. Launch the app and complete onboarding.
2. See the Morphe landing page and tap `Start`.
3. Pick gender, account type, goals, equipment, training style, coaching style, and the rest of the profile details.
4. Review the finished profile and tap `Create My Plan`.
5. Watch the AI loading screen build the first personalized plan.
6. See the welcome sheet after profile creation.
7. Land on `Home`.
8. Use the bottom nav or swipe between Home, Train, Network, Progress, and More.
6. Turn on `Train With a Partner`, choose a partner, and pick a session mode.
7. Tap `Need a Plan B?` and choose `I'm tired`.
8. Complete one Minimum Win task.
9. See the streak protection state flip to momentum protected.
10. Open `Train`.
11. Switch between `Cards` and `Compact` view.
12. Start the workout, send a ready check, open an exercise, and swap one movement.
13. Finish the session, submit workout feedback, then log the workout from the completed flow.
14. Open `Network` and review the coach + athlete network feed, comments, ranks, suggested connections, and story/status rail.
15. Open `Progress` and review the weekly AI summary, roadmap, reports, pattern insights, photo progress, badges, and recent wins.
16. Open `More` and review scores, quick tools, exercise library, nutrition basics, and learning tools.
17. Open the profile from the avatar button in the header.
18. Switch account type, change avatar, banner, theme, accent color, coaching tone, and your sport/training/goal mix, then preview the free Premium Profile card.

## Coach demo flow

1. Create or switch into a `Coach Account` from Profile.
2. Open `Home` and review the intervention queue, hero summary, and launchpad.
3. Swipe left or right between Home, Athletes, Build, Library, and Inbox.
4. Filter athletes by sport.
5. Open Lucas from `Athletes`.
6. Review readiness, compliance, notes, and AI summary in the athlete profile.
7. Open `Programs` and build or select a boxing session.
8. Assign a program to an athlete.
9. Open `Library` and review playbooks, drills, exercise references, testing, and video feedback.
10. Open `Messages`, switch between Inbox, Network, and CRM, then send a smart outreach message or group announcement.
11. Mark attendance for a selected group and advance a lead in the CRM section.

## Mock / demo only

Everything below is mock or local-state-only:

- onboarding output
- AI coach replies
- AI summaries
- plan adjustments
- profile sharing preview
- workout analytics
- readiness logic
- pain routing
- nutrition guidance
- community feed
- coach + athlete network reactions/comments
- leaderboards
- coach interventions
- report cards
- video review thumbnails and comments
- attendance
- subscription preview
- premium app chrome, feed layout, and bottom navigation structure
- partner workout pairing and buddy XP bonus
- compact train view
- welcome sheet after onboarding

This app does **not** include:

- real authentication
- real AI APIs
- payment APIs
- wearables
- production messaging
- calendar sync
- secure media storage
- real video analysis
- real physique scan

## Premium Profile launch strategy

Premium Profile is intentionally free at launch.

That includes:

- custom avatar
- custom banner
- theme presets
- athletic profile identity
- badges and milestones
- shareable profile card
- profile credibility / showcase sections

The paywall preview only applies to future advanced coaching and analytics features, not profile personalization.

## Recommended next production steps

1. Move mock content into a repository layer with persistence.
2. Add auth and role-based account routing.
3. Add real coach messaging, push notifications, and scheduling sync.
4. Add secure uploads for progress photos and video review.
5. Add production AI flows with human-reviewable prompts and safety guardrails.
6. Add HealthKit / wearable integrations where relevant.
7. Add UI tests for the client and coach demo journeys.
