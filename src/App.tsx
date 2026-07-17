import {
  Activity,
  ArrowLeft,
  ChevronDown,
  ChevronUp,
  BarChart3,
  Building2,
  CalendarDays,
  Check,
  CheckCircle2,
  ChevronRight,
  CirclePause,
  CirclePlay,
  Clock3,
  Copy,
  Dumbbell,
  Flame,
  Folder,
  Gauge,
  History,
  House,
  Columns3,
  LibraryBig,
  LogOut,
  Menu,
  MessageCircle,
  MoreHorizontal,
  Pencil,
  Play,
  Plus,
  RotateCcw,
  Search,
  Settings,
  ShieldCheck,
  SlidersHorizontal,
  Square,
  Eye,
  EyeOff,
  Trash2,
  TrendingUp,
  Trophy,
  UserRound,
  Users,
  Weight,
  X
} from "lucide-react";
import {
  type FormEvent,
  type PropsWithChildren,
  lazy,
  Suspense,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState
} from "react";
import { Link, NavLink, Navigate, Outlet, Route, Routes, useNavigate, useParams } from "react-router-dom";
import { leaderboardSeed } from "./data";
import { workoutProgramTemplates } from "./programTemplates";
import { exerciseMatchesFilters, searchExercises } from "./exerciseSearch";
import { BodyRegionGlyph } from "./ExerciseVisual";
import { NotificationButton } from "./NotificationButton";
import { RouteErrorBoundary } from "./RouteErrorBoundary";
import { DemoExperience } from "./DemoExperience";
import { ContactPage, DemoInfoPage, PrivacyPage, TermsPage } from "./DemoPages";
import { publicDemoMode } from "./demo";
import { ProfileAvatar } from "./ProfileAvatar";
import { AuthPage, ProtectedRoute } from "./AuthPages";
import { useAuth } from "./auth";
import { computedLeaderboardEntries, currentProfile, primaryMuscleForExercise, secondaryMusclesForExercise, weightClassFor } from "./platform";
import {
  exerciseHistory,
  formatDuration,
  formatWeight,
  makeId,
  personalRecords,
  recommendedNextWeight,
  volumeByBodyPart,
  weekCompletion,
  workoutDuration
} from "./lib";
import { useTracker } from "./store";
import type {
  Exercise,
  ExercisePrescription,
  LeaderboardEntry,
  LeaderboardScope,
  RankingType,
  TrackerState,
  TrackingType,
  WorkoutPlan,
  WorkoutSession,
  WorkoutWeek
} from "./types";

const navItems = [
  { to: "/home", label: "Home", icon: House },
  { to: "/leaderboards", label: "Leaderboards", icon: Trophy },
  { to: "/today", label: "Track", icon: Dumbbell },
  { to: "/submit", label: "Submit", icon: Plus },
  { to: "/library", label: "Library", icon: LibraryBig },
  { to: "/gyms", label: "Gyms", icon: Building2 },
  { to: "/community", label: "Community", icon: Users },
  { to: "/messages", label: "Messages", icon: MessageCircle },
  { to: "/profile", label: "Profile", icon: UserRound }
];

const mobileNavItems = navItems.filter((item) => ["/home", "/leaderboards", "/today", "/community", "/profile"].includes(item.to));

type LeaderboardColumnKey = "rank" | "athlete" | "exercise" | "gym" | "score" | "verification" | "trend";

type LeaderboardFiltersState = {
  rankingType: RankingType;
  scope: LeaderboardScope;
  verification: "All" | LeaderboardEntry["verification"];
  exercise: string;
  gym: string;
  city: string;
  ageGroup: string;
  experienceLevel: string;
  weightClass: string;
  repCount: number | null;
};

const leaderboardColumnConfig: Array<{
  key: LeaderboardColumnKey;
  label: string;
  description: string;
  defaultVisible: boolean;
}> = [
  { key: "rank", label: "Rank", description: "Leaderboard position", defaultVisible: true },
  { key: "athlete", label: "Athlete", description: "Name and handle", defaultVisible: true },
  { key: "exercise", label: "Exercise", description: "Lift being ranked", defaultVisible: true },
  { key: "gym", label: "Gym", description: "Primary gym", defaultVisible: true },
  { key: "score", label: "Score", description: "Rank score or max", defaultVisible: true },
  { key: "verification", label: "Verification", description: "Lift status", defaultVisible: true },
  { key: "trend", label: "Trend", description: "Recent movement", defaultVisible: true }
];

const defaultLeaderboardFilters: LeaderboardFiltersState = {
  rankingType: "Total",
  scope: "Global",
  verification: "All",
  exercise: "All",
  gym: "All",
  city: "All",
  ageGroup: "All",
  experienceLevel: "All",
  weightClass: "All",
  repCount: null
};

const defaultLeaderboardColumnOrder: LeaderboardColumnKey[] = [
  "rank",
  "athlete",
  "exercise",
  "gym",
  "score",
  "verification",
  "trend"
];

const SubmitLiftPage = lazy(() => import("./PlatformPages").then((module) => ({ default: module.SubmitLiftPage })));
const ExerciseDetailPage = lazy(() => import("./PlatformPages").then((module) => ({ default: module.ExerciseDetailPage })));
const GymsPage = lazy(() => import("./PlatformPages").then((module) => ({ default: module.GymsPage })));
const GymDetailPage = lazy(() => import("./PlatformPages").then((module) => ({ default: module.GymDetailPage })));
const CommunityPage = lazy(() => import("./PlatformPages").then((module) => ({ default: module.CommunityPage })));
const CommunityModerationPage = lazy(() => import("./PlatformPages").then((module) => ({ default: module.CommunityModerationPage })));
const CommunityPostPage = lazy(() => import("./PlatformPages").then((module) => ({ default: module.CommunityPostPage })));
const FriendsPage = lazy(() => import("./PlatformPages").then((module) => ({ default: module.FriendsPage })));
const MessagesPage = lazy(() => import("./PlatformPages").then((module) => ({ default: module.MessagesPage })));
const MessageThreadPage = lazy(() => import("./PlatformPages").then((module) => ({ default: module.MessageThreadPage })));
const PlatformProfilePage = lazy(() => import("./PlatformPages").then((module) => ({ default: module.PlatformProfilePage })));
const SettingsPage = lazy(() => import("./PlatformPages").then((module) => ({ default: module.SettingsPage })));
const OnboardingPage = lazy(() => import("./PlatformPages").then((module) => ({ default: module.OnboardingPage })));

function RouteLoading() {
  return <div className="page route-loading" role="status" aria-live="polite"><span className="loading-spinner" aria-hidden /><span>Loading page…</span></div>;
}

function App() {
  const authPage = (mode: "login" | "signup" | "forgot" | "reset") => publicDemoMode ? <Navigate to="/leaderboards" replace /> : <AuthPage mode={mode} />;
  return (
    <RouteErrorBoundary><Suspense fallback={<RouteLoading />}><Routes>
      <Route path="/login" element={authPage("login")} />
      <Route path="/signup" element={authPage("signup")} />
      <Route path="/forgot-password" element={authPage("forgot")} />
      <Route path="/reset-password" element={authPage("reset")} />
      <Route element={<AppShell />}>
      <Route path="/home" element={<ProtectedRoute><HomePage /></ProtectedRoute>} />
      <Route path="/today" element={<ProtectedRoute><TodayPage /></ProtectedRoute>} />
      <Route path="/plans" element={<ProtectedRoute><PlansPage /></ProtectedRoute>} />
      <Route path="/progress" element={<ProtectedRoute><ProgressPage /></ProtectedRoute>} />
      <Route path="/progress/workouts/:workoutId" element={<ProtectedRoute><WorkoutDetailPage /></ProtectedRoute>} />
      <Route path="/workout/:sessionId" element={<ProtectedRoute><WorkoutPage /></ProtectedRoute>} />
      <Route path="/library" element={<LibraryPage />} />
      <Route path="/library/:exerciseId" element={<ExerciseDetailPage />} />
      <Route path="/submit" element={<ProtectedRoute><SubmitLiftPage /></ProtectedRoute>} />
      <Route path="/leaderboards" element={<LeaderboardsPage />} />
      <Route path="/gyms" element={<GymsPage />} />
      <Route path="/gyms/:gymId" element={<GymDetailPage />} />
      <Route path="/community" element={<CommunityPage />} />
      <Route path="/community/groups/:groupId" element={<CommunityPage />} />
      <Route path="/community/moderation" element={<ProtectedRoute><CommunityModerationPage /></ProtectedRoute>} />
      <Route path="/community/:postId" element={<CommunityPostPage />} />
      <Route path="/friends" element={<FriendsPage />} />
      <Route path="/messages" element={<ProtectedRoute><MessagesPage /></ProtectedRoute>} />
      <Route path="/messages/:threadId" element={<ProtectedRoute><MessageThreadPage /></ProtectedRoute>} />
      <Route path="/profile" element={<PlatformProfilePage />} />
      <Route path="/profile/:userId" element={<PlatformProfilePage />} />
      <Route path="/settings" element={<ProtectedRoute><SettingsPage /></ProtectedRoute>} />
      <Route path="/onboarding" element={<ProtectedRoute><OnboardingPage /></ProtectedRoute>} />
      <Route path="/demo" element={<DemoInfoPage />} />
      <Route path="/privacy" element={<PrivacyPage />} />
      <Route path="/terms" element={<TermsPage />} />
      <Route path="/contact" element={<ContactPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/home" replace />} />
    </Routes></Suspense></RouteErrorBoundary>
  );
}

function AppShell() {
  return (
    <div className="app-layout">
      <aside className="sidebar">
        <Logo />
        <nav aria-label="Primary navigation">
          {navItems.map(({ to, label, icon: Icon }) => (
            <NavLink aria-label={label} title={label} key={to} to={to} className={({ isActive }) => (isActive ? "nav-link active" : "nav-link")}>
              <Icon size={20} aria-hidden />
              <span>{label}</span>
            </NavLink>
          ))}
        </nav>
      </aside>
      <main className="main-content">
        <TopBar />
        <DemoExperience />
        <div id="page-content"><Outlet /></div>
      </main>
      <nav className="mobile-nav" aria-label="Primary navigation">
        {mobileNavItems.map(({ to, label, icon: Icon }) => (
          <NavLink aria-label={label} key={to} to={to} className={({ isActive }) => (isActive ? "active" : "")}>
            <Icon size={21} aria-hidden />
            <span>{label}</span>
          </NavLink>
        ))}
      </nav>
    </div>
  );
}

function Logo() {
  return (
    <div className="logo" aria-label="LiftRank">
      <span className="logo-mark">LR</span>
      <span>LIFTRANK</span>
    </div>
  );
}

function TopBar() {
  const { state } = useTracker();
  const auth = useAuth();
  const profile = currentProfile(state);
  const navigate = useNavigate();
  const [query, setQuery] = useState("");
  const searchIndex = useMemo(() => [
    ...state.trainingGroups.map((item) => ({ label: item.name, detail: "Training Group", to: `/community/groups/${item.id}`, text: `${item.name} ${item.description}` })),
    ...state.communityPosts.filter((item) => item.kind !== "Workout").map((item) => ({ label: item.title, detail: item.kind, to: `/community/${item.id}`, text: `${item.title} ${item.body} ${item.trainingDetails?.programName ?? ""}` })),
    ...state.exercises.map((item) => ({ label: item.name, detail: "Exercise", to: `/library/${item.id}`, text: `${item.name} ${(item.searchAliases ?? []).join(" ")}` })),
    ...state.profiles.map((item) => ({ label: item.displayName, detail: item.discipline, to: `/profile/${item.id}`, text: `${item.displayName} ${item.handle} ${item.discipline}` }))
  ], [state.communityPosts, state.exercises, state.profiles, state.trainingGroups]);
  const results = query.trim().length < 2 ? [] : searchIndex.filter((item) => item.text.toLowerCase().includes(query.trim().toLowerCase())).slice(0, 8);
  return (
    <header className="topbar">
      <div className="mobile-logo"><Logo /></div>
      <div className="global-search"><Search size={18} /><input aria-label="Global search" placeholder="Search groups, posts, exercises, and members" value={query} onChange={(event) => setQuery(event.target.value)} onKeyDown={(event) => { if (event.key === "Escape") setQuery(""); if (event.key === "Enter" && results[0]) { navigate(results[0].to); setQuery(""); } }} />{results.length > 0 && <div className="global-search-results" role="listbox">{results.map((result) => <button key={`${result.to}-${result.label}`} onMouseDown={() => { navigate(result.to); setQuery(""); }}><strong>{result.label}</strong><small>{result.detail}</small></button>)}</div>}</div>
      <div className="topbar-actions">
        {auth.user ? <><NotificationButton />
        <NavLink to="/profile" className="profile-pill" aria-label="Open profile">
          <ProfileAvatar profile={profile} />
          <div><strong>{profile.displayName}</strong><small>{profile.experienceLevel}</small></div>
        </NavLink>{!publicDemoMode && <button className="icon-button logout-button" aria-label="Log out" title="Log out" onClick={() => void auth.signOut()}><LogOut size={18} /></button>}</> : <div className="guest-actions"><NavLink className="quiet-button compact" to="/login">Log in</NavLink><NavLink className="primary-button compact" to="/signup">Create account</NavLink></div>}
      </div>
    </header>
  );
}

function PageHeader({ eyebrow, title, description, action }: {
  eyebrow: string;
  title: string;
  description: string;
  action?: React.ReactNode;
}) {
  return (
    <header className="page-header">
      <div>
        <p className="eyebrow">{eyebrow}</p>
        <h1>{title}</h1>
        <p>{description}</p>
      </div>
      {action}
    </header>
  );
}

function TrackerTabs() {
  return (
    <nav className="tracker-tabs" aria-label="Workout tracking">
      <NavLink to="/today">Today</NavLink>
      <NavLink to="/plans">Plans</NavLink>
      <NavLink to="/progress">Progress</NavLink>
    </nav>
  );
}

function HomePage() {
  const { state } = useTracker();
  const profile = currentProfile(state);
  const activePlan = state.plans.find((plan) => plan.id === state.activePlanId);
  const activeSession = state.activeWorkout
    ? state.sessions.find((session) => session.id === state.activeWorkout?.sessionId)
    : undefined;
  const planWeeks = state.weeks
    .filter((week) => week.planId === state.activePlanId)
    .sort((left, right) => left.weekNumber - right.weekNumber);
  const currentWeek = planWeeks.find((week) => weekCompletion(state, week.id) < 1) ?? planWeeks[0];
  const sessions = state.sessions
    .filter((session) => session.weekId === currentWeek?.id)
    .sort((left, right) => left.order - right.order);
  const nextSession = sessions.find((session) =>
    state.prescriptions
      .filter((item) => item.sessionId === session.id)
      .some((item) => !state.setLogs.some((log) => log.prescriptionId === item.id && log.isComplete))
  ) ?? sessions[0];
  const completedThisWeek = state.completedWorkouts.filter(
    (workout) => Date.now() - new Date(workout.completedAt).getTime() <= 7 * 86400000
  ).length;
  const streak = calculateStreak(state.completedWorkouts.map((workout) => workout.completedAt));
  const recentLift = state.liftSubmissions
    .filter((lift) => lift.userId === state.currentUserId)
    .sort((left, right) => new Date(right.submittedAt).getTime() - new Date(left.submittedAt).getTime())[0];
  const bestCompetitionLifts = new Map<string, number>();
  state.liftSubmissions
    .filter((lift) => lift.userId === state.currentUserId && lift.reps === 1)
    .forEach((lift) => bestCompetitionLifts.set(
      lift.exerciseId,
      Math.max(bestCompetitionLifts.get(lift.exerciseId) ?? 0, lift.normalizedWeight)
    ));
  const total = ["back-squat", "barbell-bench", "deadlift"].reduce(
    (sum, id) => sum + (bestCompetitionLifts.get(id) ?? 0),
    0
  );
  const currentRank = computedLeaderboardEntries(state, defaultLeaderboardFilters).find((entry) => entry.userId === state.currentUserId);
  const unreadNotifications = state.notifications.filter((notification) => !notification.isRead);
  const communityHighlight = [...state.communityPosts]
    .filter((post) => !post.removedAt && post.kind !== "Workout")
    .sort((left, right) => {
      const leftScore = Object.values(left.votes).reduce((sum, vote) => sum + vote, 0) + state.comments.filter((comment) => comment.postId === left.id).length;
      const rightScore = Object.values(right.votes).reduce((sum, vote) => sum + vote, 0) + state.comments.filter((comment) => comment.postId === right.id).length;
      return rightScore - leftScore;
    })[0];

  return (
    <div className="page home-dashboard">
      <PageHeader
        eyebrow="Athlete dashboard"
        title={`Welcome back, ${profile.displayName.split(" ")[0]}`}
        description="Your training, strength, and community at a glance."
      />
      <section className="today-grid">
        <Card className="scheduled-card">
          <div className="card-topline">
            <span className="icon-tile blue"><Dumbbell size={22} /></span>
            <span className="status-chip">{activeSession ? "Workout in progress" : currentWeek?.title ?? "Training"}</span>
          </div>
          <div>
            <p className="muted">{activeSession ? "Resume where you stopped" : activePlan?.name ?? "No active plan"}</p>
            <h2>{activeSession?.name ?? nextSession?.name ?? "Choose your next workout"}</h2>
            <p className="muted">
              {activeSession
                ? "Your completed sets and timer are stored in this browser."
                : nextSession
                  ? `${nextSession.day} · ${state.prescriptions.filter((item) => item.sessionId === nextSession.id).length} exercises`
                  : "Build a plan or start a freestyle session."}
            </p>
          </div>
          <Link className="primary-button large" to={activeSession ? `/workout/${activeSession.id}` : "/today"}>
            <Play size={20} fill="currentColor" /> {activeSession ? "Resume workout" : "Open Track"}
          </Link>
        </Card>
        <div className="today-side">
          <Card>
            <div className="metric-heading"><Trophy size={19} /><span>Three-lift total</span></div>
            <strong className="big-number">{total ? `${formatWeight(total)} lb` : "—"}</strong>
            <p className="muted">best submitted one-rep squat, bench, and deadlift</p>
          </Card>
          <Card>
            <div className="metric-heading"><Flame size={19} className="orange" /><span>Training streak</span></div>
            <strong className="big-number">{streak}</strong>
            <p className="muted">days from completed workouts</p>
          </Card>
        </div>
      </section>
      <div className="stat-grid home-stat-grid">
        <Card><strong>{completedThisWeek}</strong><span>Workouts in the last 7 days</span></Card>
        <Card><strong>{state.completedWorkouts.length}</strong><span>Completed workouts</span></Card>
        <Card><strong>{state.joinedGymIds.length}/3</strong><span>Joined gyms</span></Card>
        <Card><strong>{state.joinedGroupIds.length}</strong><span>Training Groups followed</span></Card>
      </div>
      <div className="home-dashboard-grid">
        <Card>
          <SectionTitle title="Recent submitted PR" action={<Link to="/profile">View profile</Link>} />
          {recentLift
            ? <div className="home-highlight"><span className="icon-tile"><TrendingUp /></span><span><strong>{recentLift.exerciseName}</strong><small>{formatWeight(recentLift.weight)} {recentLift.unit} × {recentLift.reps} · {recentLift.verification}</small></span></div>
            : <p className="muted">Submit your first lift to create a strength record.</p>}
        </Card>
        <Card>
          <SectionTitle title="Quick actions" />
          <div className="home-quick-actions">
            <Link to="/today"><Dumbbell />Track workout</Link>
            <Link to="/submit"><Plus />Submit lift</Link>
            <Link to="/library"><LibraryBig />Exercise library</Link>
            <Link to="/community"><Users />Community</Link>
          </div>
        </Card>
        <Card>
          <SectionTitle title="Ranking summary" action={<Link to="/leaderboards">View rankings</Link>} />
          {currentRank ? <div className="home-highlight"><span className="icon-tile"><Trophy /></span><span><strong>#{currentRank.rank} · {currentRank.rankingType}</strong><small>{formatWeight(currentRank.score)} lb · browser-local demo board</small></span></div> : <p className="muted">Submit eligible lifts to appear in demo rankings.</p>}
        </Card>
        <Card>
          <SectionTitle title="Notifications" />
          {unreadNotifications.length ? <div className="home-highlight"><span className="icon-tile"><Activity /></span><span><strong>{unreadNotifications.length} unread</strong><small>{unreadNotifications[0].title} · {unreadNotifications[0].body}</small></span></div> : <p className="muted">You are caught up.</p>}
        </Card>
        <Card>
          <SectionTitle title="Community highlight" action={<Link to="/community">Browse groups</Link>} />
          {communityHighlight ? <Link className="home-highlight" to={`/community/${communityHighlight.id}`}><span className="icon-tile"><Users /></span><span><strong>{communityHighlight.title}</strong><small>{communityHighlight.kind} · {state.comments.filter((comment) => comment.postId === communityHighlight.id).length} comments</small></span></Link> : <p className="muted">Join a Training Group to see discussions here.</p>}
        </Card>
      </div>
    </div>
  );
}

function TodayPage() {
  const { state, dispatch } = useTracker();
  const navigate = useNavigate();
  const planWeeks = state.weeks
    .filter((week) => week.planId === state.activePlanId)
    .sort((a, b) => a.weekNumber - b.weekNumber);
  const currentWeek = planWeeks.find((week) => weekCompletion(state, week.id) < 1) ?? planWeeks[0];
  const sessions = state.sessions
    .filter((session) => session.weekId === currentWeek?.id)
    .sort((a, b) => a.order - b.order);
  const scheduled = sessions.find((session) => {
    const prescriptions = state.prescriptions.filter((item) => item.sessionId === session.id);
    return prescriptions.some((item) => !state.setLogs.some((log) => log.prescriptionId === item.id && log.isComplete));
  }) ?? sessions[0];
  const completed = state.completedWorkouts[0];
  const completion = currentWeek ? weekCompletion(state, currentWeek.id) : 0;

  const start = (session: WorkoutSession) => {
    dispatch({ type: "START_WORKOUT", sessionId: session.id });
    navigate(`/workout/${session.id}`);
  };

  const startFreestyle = () => {
    if (!currentWeek) return;
    const sessionId = makeId("session");
    dispatch({
      type: "ADD_SESSION",
      weekId: currentWeek.id,
      day: new Intl.DateTimeFormat("en-US", { weekday: "long" }).format(new Date()),
      name: "Freestyle Workout",
      freestyle: true
    });
    // The reducer owns generated IDs, so navigate after locating the new session on the next render.
    sessionStorage.setItem("liftrank-start-new-freestyle", currentWeek.id);
  };

  useEffect(() => {
    const weekId = sessionStorage.getItem("liftrank-start-new-freestyle");
    if (!weekId) return;
    const freestyle = [...state.sessions].reverse().find((session) => session.weekId === weekId && session.isFreestyle);
    if (!freestyle) return;
    sessionStorage.removeItem("liftrank-start-new-freestyle");
    dispatch({ type: "START_WORKOUT", sessionId: freestyle.id });
    navigate(`/workout/${freestyle.id}`);
  }, [state.sessions, dispatch, navigate]);

  return (
    <div className="page">
      <PageHeader eyebrow="Today" title="Ready to train?" description="Your next session and the signals that matter." />
      <TrackerTabs />
      <section className="today-grid">
        <Card className="scheduled-card">
          <div className="card-topline">
            <span className="icon-tile blue"><Dumbbell size={22} /></span>
            <span className="status-chip">{currentWeek?.title ?? "No week"}</span>
          </div>
          {scheduled ? (
            <>
              <div>
                <p className="muted">{scheduled.day}</p>
                <h2>{scheduled.name}</h2>
                <p className="muted">
                  {state.prescriptions.filter((item) => item.sessionId === scheduled.id).length} exercises planned
                </p>
              </div>
              <button className="primary-button large" onClick={() => start(scheduled)}>
                <Play size={20} fill="currentColor" /> Start workout
              </button>
            </>
          ) : (
            <EmptyState title="No workout scheduled" body="Add a workout day to your active plan." />
          )}
        </Card>
        <div className="today-side">
          <Card>
            <div className="metric-heading"><CalendarDays size={19} /><span>Current week</span></div>
            <strong className="big-number">{Math.round(completion * 100)}%</strong>
            <Progress value={completion} />
            <p className="muted">{sessions.length} workout days in {currentWeek?.title ?? "this week"}</p>
          </Card>
          <Card>
            <div className="metric-heading"><Flame size={19} className="orange" /><span>Training streak</span></div>
            <strong className="big-number">{calculateStreak(state.completedWorkouts.map((item) => item.completedAt))}</strong>
            <p className="muted">days with a completed workout</p>
          </Card>
        </div>
      </section>
      <button className="secondary-action" onClick={startFreestyle}>
        <Plus size={20} /> Start freestyle workout <ChevronRight size={18} />
      </button>
      <section>
        <SectionTitle title="Last workout" action={<NavLink to="/progress">View history</NavLink>} />
        {completed ? <WorkoutHistoryCard workout={completed} /> : <EmptyState title="No completed workouts" body="Your first finished session will appear here." />}
      </section>
    </div>
  );
}

function LeaderboardsPage() {
  const { state } = useTracker();
  const [filters, setFilters] = useState<LeaderboardFiltersState>(defaultLeaderboardFilters);
  const [query, setQuery] = useState("");
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [columnsOpen, setColumnsOpen] = useState(false);
  const [selectedEntry, setSelectedEntry] = useState<LeaderboardEntry | null>(null);
  const [pageNumber, setPageNumber] = useState(1);
  const [jumpRequested, setJumpRequested] = useState(false);
  const currentRowRef = useRef<HTMLDivElement | null>(null);
  const [columnOrder, setColumnOrder] = useState<LeaderboardColumnKey[]>(defaultLeaderboardColumnOrder);
  const [columnVisibility, setColumnVisibility] = useState<Record<LeaderboardColumnKey, boolean>>(
    () =>
      leaderboardColumnConfig.reduce((accumulator, column) => {
        accumulator[column.key] = column.defaultVisible;
        return accumulator;
      }, {} as Record<LeaderboardColumnKey, boolean>)
  );

  const rankedEntries = useMemo(
    () => computedLeaderboardEntries(state, filters).sort((left, right) => left.rank - right.rank),
    [state, filters]
  );
  const filteredEntries = useMemo(() => {
    const search = query.trim().toLowerCase();
    if (!search) return rankedEntries;
    return rankedEntries.filter((entry) =>
      [entry.athlete, entry.handle, entry.exercise, entry.gym, entry.city, entry.state]
        .join(" ")
        .toLowerCase()
        .includes(search)
    );
  }, [query, rankedEntries]);

  const rankedCurrent = rankedEntries.find((entry) => entry.isCurrentUser);

  const activeFilterCount = [
    filters.rankingType !== defaultLeaderboardFilters.rankingType,
    filters.scope !== defaultLeaderboardFilters.scope,
    filters.verification !== defaultLeaderboardFilters.verification,
    filters.exercise !== defaultLeaderboardFilters.exercise,
    filters.gym !== defaultLeaderboardFilters.gym,
    filters.city !== defaultLeaderboardFilters.city,
    filters.ageGroup !== defaultLeaderboardFilters.ageGroup,
    filters.experienceLevel !== defaultLeaderboardFilters.experienceLevel,
    filters.weightClass !== defaultLeaderboardFilters.weightClass,
    filters.repCount !== defaultLeaderboardFilters.repCount
  ].filter(Boolean).length;

  const pageSize = 25;
  const pageCount = Math.max(1, Math.ceil(filteredEntries.length / pageSize));
  const currentPage = Math.min(pageNumber, pageCount);
  const pageStart = (currentPage - 1) * pageSize;
  const visibleEntries = filteredEntries.slice(pageStart, pageStart + pageSize);

  useEffect(() => {
    if (!jumpRequested) setPageNumber(1);
  }, [filters, query]);
  useEffect(() => {
    if (!jumpRequested || !currentRowRef.current) return;
    currentRowRef.current.scrollIntoView?.({ behavior: "smooth", block: "center" });
    currentRowRef.current.focus({ preventScroll: true });
    setJumpRequested(false);
  }, [currentPage, jumpRequested, visibleEntries]);

  const visibleColumns = columnOrder.filter((key) => columnVisibility[key]);
  const tableTemplateColumns = visibleColumns.map((key) => leaderboardColumnWidth(key)).join(" ");
  const topEntry = rankedEntries[0] ?? null;
  const verifiedCount = filteredEntries.filter((entry) => ["Competition Verified", "Video Verified", "Community Verified"].includes(entry.verification)).length;
  const topScoreValue = topEntry ? formatLeaderboardScore(topEntry) : "No result";
  const topScoreDetail = topEntry
    ? `${topEntry.athlete} · ${topEntry.exercise}`
    : "No matching rankings for this view";
  const currentIndex = rankedEntries.findIndex((entry) => entry.isCurrentUser);
  const nextHigher = currentIndex > 0 ? rankedEntries[currentIndex - 1] : null;
  const gapValue = rankedCurrent && nextHigher ? formatLeaderboardGap(nextHigher.score - rankedCurrent.score, filters.rankingType) : rankedCurrent?.rank === 1 ? "Leading" : "—";
  const activeChips = leaderboardActiveChips(filters);
  const jumpToMyRank = () => {
    if (currentIndex < 0) return;
    setJumpRequested(true);
    setQuery("");
    setPageNumber(Math.floor(currentIndex / pageSize) + 1);
  };
  const removeChip = (key: keyof LeaderboardFiltersState) => setFilters((current) => normalizeLeaderboardFilters({ ...current, [key]: defaultLeaderboardFilters[key] } as LeaderboardFiltersState));

  return (
    <div className="page">
      <PageHeader
        eyebrow="Competition"
        title="Leaderboards"
        description="Compare verified strength results across athletes, gyms, and weight classes."
      />
      <div className="leaderboard-context" aria-label="Ranking context">{leaderboardContextLabels(filters, state).map((label) => <span key={label}>{label}</span>)}</div>
      <div className="leaderboard-summary-grid">
        <MetricCard icon={<Trophy />} label="Current rank and total" value={rankedCurrent ? `#${rankedCurrent.rank}` : "Unranked"} detail={rankedCurrent ? `${formatWeight(rankedCurrent.total)} lb total` : "Not included in this view"} />
        <MetricCard icon={<TrendingUp />} label="Gap to next rank" value={gapValue} detail={nextHigher ? `Behind ${nextHigher.athlete}` : rankedCurrent ? "Top of this ranking" : "Apply a broader scope"} />
        <MetricCard icon={<Activity />} label="Ranked athletes" value={`${rankedEntries.length}`} detail="In the current view" />
        <MetricCard icon={<ShieldCheck />} label="Leading result" value={topScoreValue} detail={topScoreDetail} />
      </div>

      <div className="leaderboard-toolbar">
        <label className="search-field leaderboard-search">
          <Search size={19} />
          <input
            aria-label="Search leaderboards"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search athletes, gyms, or lifts..."
          />
        </label>
        <div className="leaderboard-result-summary"><strong>{filteredEntries.length}</strong><span>athletes · {verifiedCount} verified</span></div>
        <div className="leaderboard-toolbar-actions">
          {rankedCurrent && <button className="quiet-button compact" onClick={jumpToMyRank}><Trophy size={16} /> Jump to my rank</button>}
          <button className="primary-button compact" onClick={() => setFiltersOpen(true)}>
            <SlidersHorizontal size={17} />
            Filters{activeFilterCount > 0 ? ` (${activeFilterCount})` : ""}
          </button>
          <button className="icon-button" aria-label="Table settings" title="Table settings" onClick={() => setColumnsOpen(true)}>
            <Columns3 size={17} />
          </button>
        </div>
      </div>
      {activeChips.length > 0 && <div className="leaderboard-filter-chips">{activeChips.map((chip) => <button key={chip.key} onClick={() => removeChip(chip.key)} aria-label={`Remove ${chip.label} filter`}>{chip.label}<X size={13} /></button>)}<button className="clear-all" onClick={() => setFilters(defaultLeaderboardFilters)}>Clear all</button></div>}

      <section className="leaderboard-table-card" aria-label="Rankings">
        <div className="leaderboard-table" role="table" aria-label="Leaderboard rankings">
          <div className="leaderboard-table-header" role="row" style={{ gridTemplateColumns: tableTemplateColumns }}>
            {visibleColumns.map((key) => (
              <div key={key} role="columnheader" className={`leaderboard-cell header ${key}`}>
                {leaderboardColumnLabel(key, filters.rankingType)}
              </div>
            ))}
          </div>
          <div className="leaderboard-table-body" role="rowgroup">
            {visibleEntries.map((entry) => (
              <div
                key={entry.id}
                role="row"
                tabIndex={0}
                className={entry.isCurrentUser ? "leaderboard-table-row current" : "leaderboard-table-row"}
                ref={entry.isCurrentUser ? currentRowRef : undefined}
                style={{ gridTemplateColumns: tableTemplateColumns }}
                onClick={() => setSelectedEntry(entry)}
                onKeyDown={(event) => {
                  if (event.key !== "Enter" && event.key !== " ") return;
                  event.preventDefault();
                  setSelectedEntry(entry);
                }}
                aria-label={`Open ranking details for ${entry.athlete}`}
              >
                {visibleColumns.map((key) => (
                  <div key={`${entry.id}-${key}`} role="cell" className={`leaderboard-cell ${key}`}>
                    {renderLeaderboardCell(entry, key)}
                  </div>
                ))}
                <ChevronRight className="row-disclosure" size={16} />
              </div>
            ))}
            {!filteredEntries.length && <EmptyState title="No matching rankings" body="Try a different scope, ranking type, or search term." />}
          </div>
        </div>
      </section>
      {filteredEntries.length > 0 && <nav className="leaderboard-pagination" aria-label="Leaderboard pages"><span>Showing {pageStart + 1}–{Math.min(pageStart + pageSize, filteredEntries.length)} of {filteredEntries.length}</span><div><button className="quiet-button compact" disabled={currentPage === 1} onClick={() => setPageNumber((page) => Math.max(1, page - 1))}>Previous</button><span>Page {currentPage} of {pageCount}</span><button className="quiet-button compact" disabled={currentPage === pageCount} onClick={() => setPageNumber((page) => Math.min(pageCount, page + 1))}>Next</button></div></nav>}

      {filtersOpen && (
        <LeaderboardFiltersDialog
          currentFilters={filters}
          query={query}
          onClose={() => setFiltersOpen(false)}
          onApply={(nextFilters) => {
            setFilters(normalizeLeaderboardFilters(nextFilters));
            setFiltersOpen(false);
          }}
        />
      )}

      {columnsOpen && (
        <LeaderboardColumnsDialog
          columnOrder={columnOrder}
          columnVisibility={columnVisibility}
          onClose={() => setColumnsOpen(false)}
          onApply={({ nextOrder, nextVisibility }) => {
            setColumnOrder(nextOrder);
            setColumnVisibility(nextVisibility);
            setColumnsOpen(false);
          }}
        />
      )}

      {selectedEntry && (
        <LeaderboardDetailDialog entry={selectedEntry} onClose={() => setSelectedEntry(null)} />
      )}
    </div>
  );
}

function PlansPage() {
  const { state, dispatch } = useTracker();
  const [selectedWeekId, setSelectedWeekId] = useState<string | null>(null);
  const [planDialog, setPlanDialog] = useState<"create" | "rename" | null>(null);
  const [sessionWeek, setSessionWeek] = useState<WorkoutWeek | null>(null);
  const [exerciseSession, setExerciseSession] = useState<WorkoutSession | null>(null);
  const activePlan = state.plans.find((plan) => plan.id === state.activePlanId)!;
  const weeks = state.weeks
    .filter((week) => week.planId === activePlan.id)
    .sort((a, b) => a.weekNumber - b.weekNumber);
  const selectedWeek = weeks.find((week) => week.id === selectedWeekId) ?? weeks[0];
  const sessions = state.sessions
    .filter((session) => session.weekId === selectedWeek?.id)
    .sort((a, b) => a.order - b.order);

  useEffect(() => {
    if (selectedWeek && selectedWeek.id !== selectedWeekId) setSelectedWeekId(selectedWeek.id);
  }, [selectedWeek, selectedWeekId]);

  return (
    <div className="page">
      <PageHeader
        eyebrow="Programming"
        title="Training plans"
        description="Build weeks and workout days around the way you train."
        action={<button className="primary-button" onClick={() => setPlanDialog("create")}><Plus size={18} /> Create plan</button>}
      />
      <TrackerTabs />
      <section className="program-library" aria-labelledby="program-library-title">
        <div className="section-row">
          <div>
            <h2 id="program-library-title">12-week program library</h2>
            <p className="muted">Start from a proven structure, then edit your personal copy.</p>
          </div>
          <span className="status-chip">{workoutProgramTemplates.length} programs</span>
        </div>
        <div className="program-template-grid">
          {workoutProgramTemplates.map((template) => (
            <Card key={template.id} className="program-template-card">
              <div className="card-topline">
                <span className="status-chip">{template.category}</span>
                <small>{template.level}</small>
              </div>
              <div>
                <h3>{template.name}</h3>
                <p>{template.summary}</p>
              </div>
              <div className="program-template-meta">
                <span><CalendarDays />12 weeks</span>
                <span><Dumbbell />{template.daysPerWeek} days/week</span>
                <span><TrendingUp />{template.progressionMethod}</span>
              </div>
              <button
                className="quiet-button"
                onClick={() => dispatch({ type: "INSTALL_PROGRAM_TEMPLATE", template })}
              >Use template</button>
            </Card>
          ))}
        </div>
      </section>
      <div className="plan-layout">
        <aside className="plan-list">
          {state.plans.map((plan) => (
            <button
              key={plan.id}
              className={plan.id === activePlan.id ? "plan-list-item active" : "plan-list-item"}
              onClick={() => {
                dispatch({ type: "SET_ACTIVE_PLAN", planId: plan.id });
                setSelectedWeekId(null);
              }}
            >
              <span><strong>{plan.name}</strong><small>{state.weeks.filter((week) => week.planId === plan.id).length} weeks</small></span>
              {plan.id === activePlan.id && <CheckCircle2 size={18} />}
            </button>
          ))}
        </aside>
        <section className="plan-detail">
          <Card className="plan-hero">
            <div>
              <p className="eyebrow">Active plan</p>
              <h2>{activePlan.name}</h2>
              <p>{activePlan.goal}</p>
            </div>
            <div className="inline-actions">
              <IconButton label="Rename plan" onClick={() => setPlanDialog("rename")}><Pencil size={18} /></IconButton>
              <IconButton label="Duplicate plan" onClick={() => dispatch({ type: "DUPLICATE_PLAN", planId: activePlan.id })}><Copy size={18} /></IconButton>
              <IconButton
                label="Delete plan"
                tone="danger"
                disabled={state.plans.length === 1}
                onClick={() => confirm(`Delete ${activePlan.name}?`) && dispatch({ type: "DELETE_PLAN", planId: activePlan.id })}
              ><Trash2 size={18} /></IconButton>
            </div>
          </Card>
          <div className="week-toolbar">
            <div className="week-tabs" role="tablist" aria-label="Plan weeks">
              {weeks.map((week) => (
                <button
                  role="tab"
                  aria-selected={week.id === selectedWeek?.id}
                  key={week.id}
                  onClick={() => setSelectedWeekId(week.id)}
                >
                  {week.title}
                </button>
              ))}
            </div>
            <div className="inline-actions">
              <button className="text-button" onClick={() => dispatch({ type: "ADD_WEEK", planId: activePlan.id })}><Plus size={17} /> Add week</button>
              {selectedWeek && <button className="text-button" onClick={() => dispatch({ type: "CLONE_WEEK", weekId: selectedWeek.id })}><Copy size={17} /> Clone</button>}
            </div>
          </div>
          {selectedWeek && (
            <>
              <div className="section-row">
                <div>
                  <h3>{selectedWeek.title}</h3>
                  <p className="muted">{Math.round(weekCompletion(state, selectedWeek.id) * 100)}% complete</p>
                </div>
                <div className="inline-actions">
                  <button className="text-button" onClick={() => setSessionWeek(selectedWeek)}><Plus size={17} /> Add workout day</button>
                  {weeks.length > 1 && (
                    <IconButton
                      label="Delete week"
                      tone="danger"
                      onClick={() => confirm(`Delete ${selectedWeek.title}?`) && dispatch({ type: "DELETE_WEEK", weekId: selectedWeek.id })}
                    ><Trash2 size={17} /></IconButton>
                  )}
                </div>
              </div>
              <div className="session-grid">
                {sessions.map((session) => (
                  <SessionCard
                    key={session.id}
                    session={session}
                    onAdd={() => setExerciseSession(session)}
                    onDelete={() => confirm(`Delete ${session.name}?`) && dispatch({ type: "DELETE_SESSION", sessionId: session.id })}
                  />
                ))}
                {!sessions.length && <EmptyState title="No workout days" body="Add a day, then choose exercises from the library." />}
              </div>
            </>
          )}
        </section>
      </div>
      {planDialog && (
        <PlanDialog
          mode={planDialog}
          plan={activePlan}
          onClose={() => setPlanDialog(null)}
        />
      )}
      {sessionWeek && <SessionDialog week={sessionWeek} onClose={() => setSessionWeek(null)} />}
      {exerciseSession && <ExercisePicker session={exerciseSession} onClose={() => setExerciseSession(null)} />}
    </div>
  );
}

function SessionCard({ session, onAdd, onDelete }: { session: WorkoutSession; onAdd: () => void; onDelete: () => void }) {
  const { state, dispatch } = useTracker();
  const navigate = useNavigate();
  const prescriptions = state.prescriptions
    .filter((item) => item.sessionId === session.id)
    .sort((a, b) => a.order - b.order);
  const start = () => {
    dispatch({ type: "START_WORKOUT", sessionId: session.id });
    navigate(`/workout/${session.id}`);
  };
  return (
    <Card className="session-card">
      <div className="session-heading">
        <div>
          <p className="eyebrow">{session.day}</p>
          <h3>{session.name}</h3>
        </div>
        <IconButton label={`Delete ${session.name}`} tone="danger" onClick={onDelete}><Trash2 size={17} /></IconButton>
      </div>
      <div className="exercise-preview">
        {prescriptions.map((item) => (
          <div key={item.id}>
            <span>{item.order + 1}</span>
            <p><strong>{item.exerciseName}</strong><small>{item.sets} sets · {item.reps} reps</small></p>
            <button aria-label={`Remove ${item.exerciseName}`} onClick={() => dispatch({ type: "DELETE_PRESCRIPTION", prescriptionId: item.id })}><X size={15} /></button>
          </div>
        ))}
        {!prescriptions.length && <p className="muted">No exercises yet.</p>}
      </div>
      <div className="session-actions">
        <button className="text-button" onClick={onAdd}><Plus size={17} /> Add exercise</button>
        <button className="primary-button compact" onClick={start}><Play size={16} fill="currentColor" /> Start</button>
      </div>
    </Card>
  );
}

function LibraryPage() {
  const { state } = useTracker();
  const [query, setQuery] = useState("");
  const [bodyRegions, setBodyRegions] = useState<string[]>([]);
  const [primaryMuscles, setPrimaryMuscles] = useState<string[]>([]);
  const [equipment, setEquipment] = useState<string[]>([]);
  const [movementTypes, setMovementTypes] = useState<string[]>([]);
  const [trackingTypes, setTrackingTypes] = useState<string[]>([]);
  const [customOpen, setCustomOpen] = useState(false);
  const regionOptions = useMemo(() => [...new Set(state.exercises.flatMap((item) => item.bodyRegions?.length ? item.bodyRegions : [item.bodyPart]))].sort(), [state.exercises]);
  const primaryOptions = useMemo(() => [...new Set(state.exercises.map(primaryMuscleForExercise))].sort(), [state.exercises]);
  const equipmentOptions = useMemo(() => [...new Set(state.exercises.map((item) => item.equipment))].sort(), [state.exercises]);
  const movementOptions = useMemo(() => [...new Set(state.exercises.map((item) => item.movementType))].sort(), [state.exercises]);
  const trackingOptions = useMemo(() => [...new Set(state.exercises.map((item) => item.trackingType))].sort(), [state.exercises]);
  const filtered = useMemo(() => searchExercises(state.exercises, query).filter(({ exercise }) => exerciseMatchesFilters(exercise, {
    bodyRegions,
    primaryMuscles,
    equipment,
    movementTypes,
    trackingTypes
  })), [bodyRegions, equipment, movementTypes, primaryMuscles, query, state.exercises, trackingTypes]);
  const hasActiveFilters = Boolean(query.trim()) || [bodyRegions, primaryMuscles, equipment, movementTypes, trackingTypes].some((values) => values.length);
  const clearFilters = () => {
    setQuery("");
    setBodyRegions([]);
    setPrimaryMuscles([]);
    setEquipment([]);
    setMovementTypes([]);
    setTrackingTypes([]);
  };
  return (
    <div className="page">
      <PageHeader
        eyebrow="Exercise catalog"
        title="Library"
        description="Search common movements or create the exercise your gym uses."
        action={<button className="primary-button" onClick={() => setCustomOpen(true)}><Plus size={18} /> Custom exercise</button>}
      />
      <div className="filter-panel library-filter-panel">
        <label className="search-field"><Search size={19} /><input aria-label="Search exercises" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search exercises..." /></label>
        <MultiSelectFilter label="Body region" values={bodyRegions} options={regionOptions} onChange={setBodyRegions} />
        <MultiSelectFilter label="Primary muscle" values={primaryMuscles} options={primaryOptions} onChange={setPrimaryMuscles} />
        <MultiSelectFilter label="Equipment" values={equipment} options={equipmentOptions} onChange={setEquipment} />
        <MultiSelectFilter label="Movement" values={movementTypes} options={movementOptions} onChange={setMovementTypes} />
        <MultiSelectFilter label="Tracking" values={trackingTypes} options={trackingOptions} onChange={setTrackingTypes} />
      </div>
      <div className="library-filter-summary"><div className="library-count" aria-live="polite">{filtered.length} exercises{query.trim() ? " · sorted by relevance" : ""}</div><button className="text-button" type="button" disabled={!hasActiveFilters} onClick={clearFilters}>Clear filters</button></div>
      <div className="exercise-grid">
        {filtered.map(({ exercise, reason }) => <ExerciseCard key={exercise.id} exercise={exercise} matchReason={query.trim() ? reason : null} />)}
      </div>
      {!filtered.length && <EmptyState title="No matching exercises" body="Clear a filter or create a custom exercise." />}
      {customOpen && <CustomExerciseDialog onClose={() => setCustomOpen(false)} />}
    </div>
  );
}

function ExerciseCard({ exercise, matchReason }: { exercise: Exercise; matchReason?: string | null }) {
  const primaryMuscle = primaryMuscleForExercise(exercise);
  const secondaryMuscles = secondaryMusclesForExercise(exercise);
  return (
    <Card className="exercise-card">
      <div className="card-topline">
        <BodyRegionGlyph exercise={exercise} />
        {exercise.isCustom && <span className="status-chip">Custom</span>}
      </div>
      <div>
        <h3><Link to={`/library/${exercise.id}`}>{exercise.name}</Link></h3>
        <p className="muted">{primaryMuscle} · {exercise.equipment}</p>
      </div>
      <div className="exercise-meta">
        <span>{exercise.movementType}</span>
        <span>{exercise.trackingType}</span>
      </div>
      {matchReason && <div className="exercise-match-reason"><Search size={13} /> {matchReason}</div>}
      <div className="best-line">
        <Dumbbell size={16} />
        <span>{secondaryMuscles.length ? `Also works ${secondaryMuscles.join(", ")}` : `${primaryMuscle} focus`}</span>
      </div>
    </Card>
  );
}

function ProgressPage() {
  const { state, dispatch } = useTracker();
  const [weightValue, setWeightValue] = useState("");
  const [editingWeightId, setEditingWeightId] = useState<string | null>(null);
  const volumes = volumeByBodyPart(state.completedWorkouts);
  const maxVolume = Math.max(1, ...Object.values(volumes));
  const latestBodyweight = state.bodyweight.at(-1);
  const totalVolume = state.completedWorkouts.reduce((sum, item) => sum + item.totalVolume, 0);
  const prRows = state.exercises
    .map((exercise) => ({ exercise, records: personalRecords(state, exercise.id) }))
    .filter((item) => item.records.heaviest)
    .slice(0, 5);
  return (
    <div className="page">
      <PageHeader eyebrow="Performance" title="Progress" description="Workout history, volume, bodyweight, and strength records." />
      <TrackerTabs />
      <div className="stat-grid">
        <MetricCard icon={<History />} label="Workouts" value={`${state.completedWorkouts.length}`} detail="completed sessions" />
        <MetricCard icon={<Weight />} label="Volume" value={formatWeight(totalVolume)} detail="total lb moved" />
        <MetricCard icon={<Gauge />} label="Bodyweight" value={latestBodyweight ? formatWeight(latestBodyweight.weight) : "—"} detail="current lb" />
        <MetricCard icon={<Trophy />} label="PR exercises" value={`${prRows.length}`} detail="with recorded bests" />
      </div>
      <Card>
        <SectionTitle title="Workout calendar" />
        <div className="workout-calendar">
          {Array.from({ length: 14 }, (_, index) => {
            const date = new Date();
            date.setDate(date.getDate() - (13 - index));
            const completed = state.completedWorkouts.some((workout) => new Date(workout.completedAt).toDateString() === date.toDateString());
            return <span key={date.toISOString()} className={completed ? "complete" : ""}><small>{date.toLocaleDateString(undefined, { weekday: "narrow" })}</small><b>{date.getDate()}</b></span>;
          })}
        </div>
      </Card>
      <div className="progress-layout">
        <section>
          <SectionTitle title="Workout history" />
          <div className="history-list">
            {state.completedWorkouts.map((workout) => <WorkoutHistoryCard key={workout.id} workout={workout} />)}
            {!state.completedWorkouts.length && <EmptyState title="History starts after your first workout" body="Finish a session to generate volume and PR data." />}
          </div>
        </section>
        <aside className="progress-aside">
          <Card>
            <SectionTitle title="Weekly volume" />
            <div className="volume-list">
              {Object.entries(volumes).map(([part, value]) => (
                <div key={part}>
                  <span><strong>{part}</strong><small>{formatWeight(value)} lb</small></span>
                  <Progress value={value / maxVolume} />
                </div>
              ))}
              {!Object.keys(volumes).length && <p className="muted">Complete sets to see body-part volume.</p>}
            </div>
          </Card>
          <Card>
            <SectionTitle title="Bodyweight" />
            <form
              className="bodyweight-form"
              onSubmit={(event) => {
                event.preventDefault();
                const value = Number(weightValue);
                if (value > 0) {
                  dispatch({ type: "ADD_BODYWEIGHT", weight: value });
                  setWeightValue("");
                }
              }}
            >
              <label><span>Current weight</span><input type="number" min="1" step="0.1" value={weightValue} onChange={(event) => setWeightValue(event.target.value)} placeholder={latestBodyweight ? String(latestBodyweight.weight) : "185"} /></label>
              <button className="primary-button compact">Log</button>
            </form>
            <div className="spark-bars" aria-label="Recent bodyweight entries">
              {state.bodyweight.slice(-8).map((entry) => {
                const values = state.bodyweight.slice(-8).map((item) => item.weight);
                const low = Math.min(...values) - 1;
                const high = Math.max(...values) + 1;
                return <i key={entry.id} style={{ height: `${20 + ((entry.weight - low) / (high - low)) * 70}%` }} title={`${entry.weight} lb`} />;
              })}
            </div>
            <div className="bodyweight-history">
              {[...state.bodyweight].reverse().slice(0, 6).map((entry) => <button key={entry.id} onClick={() => setEditingWeightId(entry.id)}><span><strong>{entry.weight} lb</strong><small>{new Date(entry.recordedAt).toLocaleDateString()}</small></span><Pencil size={15} /></button>)}
            </div>
          </Card>
          <Card>
            <SectionTitle title="Personal records" />
            <div className="pr-list">
              {prRows.map(({ exercise, records }) => (
                <div key={exercise.id}><span><strong>{exercise.name}</strong><small>Est. 1RM {records.estimated} lb</small></span><b>{formatWeight(records.heaviest?.weight ?? 0)} × {records.heaviest?.reps}</b></div>
              ))}
              {!prRows.length && <p className="muted">No personal records yet.</p>}
            </div>
          </Card>
        </aside>
      </div>
      {editingWeightId && <BodyweightEditor entryId={editingWeightId} onClose={() => setEditingWeightId(null)} />}
    </div>
  );
}

function BodyweightEditor({ entryId, onClose }: { entryId: string; onClose: () => void }) {
  const { state, dispatch } = useTracker();
  const entry = state.bodyweight.find((item) => item.id === entryId);
  const [weight, setWeight] = useState(entry?.weight.toString() ?? "");
  const [date, setDate] = useState(entry?.recordedAt.slice(0, 10) ?? new Date().toISOString().slice(0, 10));
  const [notes, setNotes] = useState(entry?.notes ?? "");
  if (!entry) return null;
  return <Modal title="Edit bodyweight" subtitle="Changes save only after you confirm." onClose={onClose}><form className="stack-form" onSubmit={(event) => { event.preventDefault(); const value = Number(weight); if (value <= 0) return; dispatch({ type: "UPDATE_BODYWEIGHT", entryId, weight: value, notes, recordedAt: new Date(`${date}T12:00:00`).toISOString() }); onClose(); }}><label><span>Weight (lb)</span><input type="number" min="1" step="0.1" value={weight} onChange={(event) => setWeight(event.target.value)} /></label><label><span>Date</span><input type="date" value={date} onChange={(event) => setDate(event.target.value)} /></label><label><span>Notes</span><textarea rows={3} value={notes} onChange={(event) => setNotes(event.target.value)} /></label><div className="dialog-actions"><button type="button" className="quiet-button" onClick={onClose}>Cancel</button><button className="primary-button">Save changes</button></div></form></Modal>;
}

function WorkoutDetailPage() {
  const { workoutId } = useParams();
  const { state } = useTracker();
  const workout = state.completedWorkouts.find((item) => item.id === workoutId);
  if (!workout) return <Navigate to="/progress" replace />;
  const feedback = state.workoutFeedback.find((item) => item.sessionId === workout.sessionId);
  const muscles = [...new Set(workout.prescriptions.filter((item) => workout.setLogs.some((log) => log.prescriptionId === item.id)).map((item) => item.bodyPart))];
  return (
    <div className="page">
      <PageHeader eyebrow="Completed workout" title={workout.name} description={`${new Date(workout.completedAt).toLocaleDateString(undefined, { month: "long", day: "numeric", year: "numeric" })} · ${formatDuration(workout.durationSeconds)}`} action={<Link className="quiet-button" to="/progress"><ArrowLeft size={17} /> Progress</Link>} />
      <div className="stat-grid">
        <Card><strong>{workout.completedExercises}/{workout.totalExercises}</strong><span>Exercises completed</span></Card>
        <Card><strong>{workout.totalSets}</strong><span>Completed sets</span></Card>
        <Card><strong>{formatWeight(workout.totalVolume)} lb</strong><span>Training volume</span></Card>
        <Card><strong>{feedback ? `${feedback.effort}/10` : "—"}</strong><span>Effort rating</span></Card>
      </div>
      <div className="workout-detail-layout">
        <section className="workout-detail-exercises">
          {[...workout.prescriptions].sort((left, right) => left.order - right.order).map((prescription) => {
            const logs = workout.setLogs.filter((log) => log.prescriptionId === prescription.id).sort((left, right) => left.setNumber - right.setNumber);
            return <Card key={prescription.id}><div className="section-title"><div><p className="eyebrow">{prescription.bodyPart} · {prescription.equipment}</p><h2>{prescription.exerciseName}</h2></div><span>{logs.length} sets</span></div>{prescription.notes && <p className="substitution-note">{prescription.notes}</p>}<div className="completed-set-list">{logs.map((log) => <div key={log.id}><strong>Set {log.setNumber}</strong><span>{formatWeight(log.weight ?? 0)} lb × {log.reps ?? 0}</span><small>{log.rpe ? `RPE ${log.rpe}` : "RPE not recorded"}</small></div>)}</div></Card>;
          })}
        </section>
        <aside className="workout-detail-aside">
          <Card><h2>Session summary</h2><div className="profile-detail-list"><span><strong>Muscles trained</strong><small>{muscles.join(", ") || "None recorded"}</small></span><span><strong>Best set</strong><small>{workout.bestSet ? `${formatWeight(workout.bestSet.weight ?? 0)} lb × ${workout.bestSet.reps}` : "None"}</small></span><span><strong>Community sharing</strong><small>{feedback?.shared ? "Shared by explicit choice" : "Not shared"}</small></span></div></Card>
          <Card><h2>Workout notes</h2><p className="muted">{feedback?.notes || "No notes were added."}</p></Card>
        </aside>
      </div>
    </div>
  );
}

function ProfilePage() {
  const { state } = useTracker();
  const activePlan = state.plans.find((plan) => plan.id === state.activePlanId);
  const activeWeeks = activePlan ? state.weeks.filter((week) => week.planId === activePlan.id) : [];
  const activeWeek = activeWeeks[0];
  const currentEntries = leaderboardSeed.filter((entry) => entry.isCurrentUser);
  const primaryEntry = currentEntries.find((entry) => entry.rankingType === "Absolute") ?? currentEntries[0] ?? leaderboardSeed[0];
  const absoluteEntry = currentEntries.find((entry) => entry.rankingType === "Absolute") ?? primaryEntry;
  const relativeEntry = currentEntries.find((entry) => entry.rankingType === "Relative total");
  const bestRank = Math.min(...currentEntries.map((entry) => entry.rank));
  const latestBodyweight = state.bodyweight.at(-1);
  const totalVolume = state.completedWorkouts.reduce((sum, workout) => sum + workout.totalVolume, 0);
  const completion = activeWeek ? weekCompletion(state, activeWeek.id) : 0;
  const latestWorkout = state.completedWorkouts.at(-1);
  const prRows = state.exercises
    .map((exercise) => ({ exercise, records: personalRecords(state, exercise.id) }))
    .filter((item) => item.records.heaviest)
    .slice(0, 3);
  const verifiedLifts = currentEntries
    .filter((entry) => entry.verification !== "Self Reported")
    .sort((left, right) => left.rank - right.rank);

  return (
    <div className="page">
      <section className="profile-hero">
        <div className="profile-avatar" aria-hidden>RJ</div>
        <div className="profile-hero-copy">
          <p className="eyebrow">Lifter profile</p>
          <h1>Robert J.</h1>
          <p>@rjrob23 · {primaryEntry.ageGroup} · {primaryEntry.experienceLevel}</p>
          <div className="profile-chip-row">
            <span className="status-chip">{primaryEntry.gym}</span>
            <span className="status-chip">{primaryEntry.city}, {primaryEntry.state}</span>
            <span className="status-chip">{primaryEntry.verification}</span>
          </div>
        </div>
        <div className="profile-hero-actions">
          <NavLink className="primary-button" to="/leaderboards"><Trophy size={18} /> Rankings</NavLink>
          <NavLink className="quiet-button" to="/progress"><History size={18} /> History</NavLink>
        </div>
      </section>

      <div className="stat-grid">
        <MetricCard icon={<Trophy />} label="Best rank" value={`#${bestRank}`} detail={`${absoluteEntry.exercise} leaderboard`} />
        <MetricCard icon={<Weight />} label="Bodyweight" value={latestBodyweight ? formatWeight(latestBodyweight.weight) : formatWeight(primaryEntry.bodyweight)} detail="latest logged" />
        <MetricCard icon={<Activity />} label="Verified total" value={formatWeight(primaryEntry.total)} detail="shown on profile" />
        <MetricCard icon={<History />} label="Workouts" value={`${state.completedWorkouts.length}`} detail={`${formatWeight(totalVolume)} lb volume`} />
      </div>

      <div className="profile-layout">
        <section className="profile-main">
          <Card className="profile-section-card">
            <SectionTitle title="Strength snapshot" action={<NavLink to="/leaderboards">Open board</NavLink>} />
            <div className="profile-lift-grid">
              <div>
                <span className="icon-tile blue"><Trophy size={20} /></span>
                <strong>{formatLeaderboardScore(absoluteEntry)}</strong>
                <small>{absoluteEntry.exercise} · {absoluteEntry.verification}</small>
              </div>
              <div>
                <span className="icon-tile green"><Activity size={20} /></span>
                <strong>{formatWeight(primaryEntry.total)}</strong>
                <small>Powerlifting total on file</small>
              </div>
              <div>
                <span className="icon-tile"><Gauge size={20} /></span>
                <strong>{relativeEntry ? formatLeaderboardScore(relativeEntry) : "—"}</strong>
                <small>Relative total ranking</small>
              </div>
            </div>
          </Card>

          <Card className="profile-section-card">
            <SectionTitle title="Verified lifts" />
            <div className="profile-list">
              {verifiedLifts.map((entry) => (
                <div key={entry.id} className="profile-list-row">
                  <span className="icon-tile"><ShieldCheck size={19} /></span>
                  <div>
                    <strong>{entry.exercise}</strong>
                    <small>#{entry.rank} · {entry.rankingType} · {entry.verification}</small>
                  </div>
                  <b>{formatLeaderboardScore(entry)}</b>
                </div>
              ))}
            </div>
          </Card>

          <Card className="profile-section-card">
            <SectionTitle title="Personal records" action={<NavLink to="/progress">View progress</NavLink>} />
            <div className="profile-list">
              {prRows.map(({ exercise, records }) => (
                <div key={exercise.id} className="profile-list-row">
                  <span className="icon-tile"><Dumbbell size={19} /></span>
                  <div>
                    <strong>{exercise.name}</strong>
                    <small>Estimated 1RM {records.estimated} lb</small>
                  </div>
                  <b>{formatWeight(records.heaviest?.weight ?? 0)} × {records.heaviest?.reps}</b>
                </div>
              ))}
              {!prRows.length && <EmptyState title="No logged PRs yet" body="Finish workouts to generate personal records from completed sets." />}
            </div>
          </Card>
        </section>

        <aside className="profile-side">
          <Card className="profile-section-card">
            <SectionTitle title="Active plan" action={<NavLink to="/plans">Manage</NavLink>} />
            <div className="profile-plan-card">
              <span className="icon-tile blue"><Folder size={20} /></span>
              <div>
                <strong>{activePlan?.name ?? "No active plan"}</strong>
                <small>{activePlan?.goal ?? "Create a plan to show it here."}</small>
              </div>
            </div>
            <div className="profile-plan-progress">
              <span><strong>{activeWeek?.title ?? "Current week"}</strong><small>{Math.round(completion * 100)}% complete</small></span>
              <Progress value={completion} />
            </div>
          </Card>

          <Card className="profile-section-card">
            <SectionTitle title="Last workout" />
            {latestWorkout ? (
              <div className="profile-list">
                <div className="profile-list-row">
                  <span className="icon-tile green"><CheckCircle2 size={19} /></span>
                  <div>
                    <strong>{latestWorkout.name}</strong>
                    <small>{new Date(latestWorkout.completedAt).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" })}</small>
                  </div>
                  <b>{formatWeight(latestWorkout.totalVolume)} lb</b>
                </div>
              </div>
            ) : (
              <EmptyState title="No workouts finished" body="Your latest completed session will appear here." />
            )}
          </Card>

          <Card className="profile-section-card">
            <SectionTitle title="Profile details" />
            <div className="profile-detail-list">
              <span><strong>Home gym</strong><small>{primaryEntry.gym}</small></span>
              <span><strong>Location</strong><small>{primaryEntry.city}, {primaryEntry.state}</small></span>
              <span><strong>Age group</strong><small>{primaryEntry.ageGroup}</small></span>
              <span><strong>Experience</strong><small>{primaryEntry.experienceLevel}</small></span>
            </div>
          </Card>
        </aside>
      </div>
    </div>
  );
}

function WorkoutPage() {
  const { sessionId } = useParams();
  const { state, dispatch } = useTracker();
  const navigate = useNavigate();
  const session = state.sessions.find((item) => item.id === sessionId);
  const week = session && state.weeks.find((item) => item.id === session.weekId);
  const basePrescriptions = state.prescriptions
    .filter((item) => item.sessionId === sessionId)
    .sort((a, b) => a.order - b.order);
  const activeWorkout = state.activeWorkout?.sessionId === sessionId ? state.activeWorkout : null;
  const activeOrder = activeWorkout?.exerciseOrder ?? [];
  const orderedIds = [...activeOrder, ...basePrescriptions.map((item) => item.id).filter((id) => !activeOrder.includes(id))];
  const prescriptions = basePrescriptions
    .sort((a, b) => orderedIds.indexOf(a.id) - orderedIds.indexOf(b.id))
    .map((item) => {
      const override = activeWorkout?.exerciseOverrides[item.id];
      return {
        ...item,
        ...(override ? {
          exerciseId: override.exerciseId,
          exerciseName: override.exerciseName,
          bodyPart: override.bodyPart,
          equipment: override.equipment
        } : {}),
        restSeconds: activeWorkout?.restOverrides[item.id] ?? item.restSeconds
      };
    });
  const [pickerOpen, setPickerOpen] = useState(false);
  const [summaryOpen, setSummaryOpen] = useState(false);
  const [cancelOpen, setCancelOpen] = useState(false);
  const [substituteId, setSubstituteId] = useState<string | null>(null);
  const [elapsed, setElapsed] = useState(() => workoutDuration(state.activeWorkout));
  const [restRemaining, setRestRemaining] = useState(0);

  useLayoutEffect(() => {
    if (!state.activeWorkout && session) dispatch({ type: "START_WORKOUT", sessionId: session.id });
  }, [state.activeWorkout, session, dispatch]);

  useEffect(() => {
    const interval = window.setInterval(() => setElapsed(workoutDuration(state.activeWorkout)), 1000);
    return () => window.clearInterval(interval);
  }, [state.activeWorkout]);

  useEffect(() => {
    if (restRemaining <= 0) return;
    const interval = window.setInterval(() => setRestRemaining((value) => Math.max(0, value - 1)), 1000);
    return () => window.clearInterval(interval);
  }, [restRemaining > 0]);

  useEffect(() => {
    prescriptions.forEach((item) =>
      dispatch({ type: "ENSURE_SET_LOGS", prescriptionId: item.id, count: item.sets })
    );
  }, [prescriptions.map((item) => `${item.id}:${item.sets}`).join("|"), dispatch]);

  if (!session || !week) return <Navigate to="/today" replace />;

  const finish = () => {
    const hasCompleted = state.setLogs.some(
      (log) => prescriptions.some((item) => item.id === log.prescriptionId) && log.isComplete
    );
    if (!hasCompleted) return;
    setSummaryOpen(true);
  };

  return (
    <div className="workout-shell">
      <header className="workout-header">
        <button className="workout-back" aria-label="Cancel workout" onClick={() => setCancelOpen(true)}><X size={21} /><span>Cancel</span></button>
        <div>
          <p>{week.title} · {session.day}</p>
          <h1>{session.name}</h1>
        </div>
        <button
          className="timer-control"
          onClick={() => dispatch({ type: state.activeWorkout?.pausedAt ? "RESUME_WORKOUT" : "PAUSE_WORKOUT" })}
        >
          {state.activeWorkout?.pausedAt ? <CirclePlay size={19} /> : <CirclePause size={19} />}
          <span>{formatDuration(elapsed)}</span>
        </button>
      </header>
      <main className="workout-content">
        {restRemaining > 0 && <div className="rest-timer"><Clock3 size={18} /><span>Rest timer</span><strong>{formatDuration(restRemaining)}</strong><button onClick={() => setRestRemaining(0)}>Skip</button></div>}
        {!prescriptions.length ? (
          <div className="workout-empty">
            <span><Dumbbell size={30} /></span>
            <h2>Add your first exercise</h2>
            <p>Choose from the library, then log weight and reps for each set.</p>
            <button className="primary-button large" onClick={() => setPickerOpen(true)}><Plus size={20} /> Add exercise</button>
          </div>
        ) : (
          <>
            <div className="workout-progress-row">
              <span>{prescriptions.filter((item) => {
                const logs = state.setLogs.filter((log) => log.prescriptionId === item.id);
                return logs.length > 0 && logs.every((log) => log.isComplete);
              }).length} of {prescriptions.length} exercises complete</span>
              <Progress value={prescriptions.filter((item) => {
                const logs = state.setLogs.filter((log) => log.prescriptionId === item.id);
                return logs.length > 0 && logs.every((log) => log.isComplete);
              }).length / prescriptions.length} />
            </div>
            <div className="track-list">
              {prescriptions.map((prescription, index) => <TrackExercise
                key={prescription.id}
                prescription={prescription}
                position={index}
                total={prescriptions.length}
                originalName={state.activeWorkout?.exerciseOverrides[prescription.id]?.originalExerciseName}
                onSubstitute={() => setSubstituteId(prescription.id)}
                onSetCompleted={() => setRestRemaining(prescription.restSeconds)}
              />)}
            </div>
            <button className="secondary-action workout-add" onClick={() => setPickerOpen(true)}><Plus size={20} /> Add another exercise</button>
          </>
        )}
      </main>
      <footer className="workout-footer">
        <div><Clock3 size={17} /><span>{formatDuration(elapsed)}</span></div>
        <button className="finish-button" onClick={finish}><Check size={19} /> Finish workout</button>
      </footer>
      {pickerOpen && <ExercisePicker session={session} onClose={() => setPickerOpen(false)} />}
      {substituteId && (
        <SubstituteExerciseDialog
          prescription={prescriptions.find((item) => item.id === substituteId) ?? basePrescriptions.find((item) => item.id === substituteId)!}
          usedExerciseIds={prescriptions.filter((item) => item.id !== substituteId).map((item) => item.exerciseId)}
          onClose={() => setSubstituteId(null)}
        />
      )}
      {cancelOpen && (
        <ConfirmDialog
          title="Cancel workout?"
          body="This attempt and its set entries will be discarded. Your plan remains unchanged."
          confirmLabel="Discard workout"
          onClose={() => setCancelOpen(false)}
          onConfirm={() => {
            dispatch({ type: "CANCEL_WORKOUT", sessionId: session.id });
            navigate("/today");
          }}
        />
      )}
      {summaryOpen && (
        <FinishDialog
          session={session}
          elapsed={elapsed}
          onClose={() => setSummaryOpen(false)}
          onFinish={() => {
            dispatch({ type: "FINISH_WORKOUT", sessionId: session.id });
            navigate("/progress");
          }}
        />
      )}
    </div>
  );
}

function TrackExercise({ prescription, position, total, originalName, onSubstitute, onSetCompleted }: {
  prescription: ExercisePrescription;
  position: number;
  total: number;
  originalName?: string;
  onSubstitute: () => void;
  onSetCompleted?: () => void;
}) {
  const { state, dispatch } = useTracker();
  const logs = state.setLogs
    .filter((log) => log.prescriptionId === prescription.id)
    .sort((a, b) => a.setNumber - b.setNumber);
  const history = exerciseHistory(state, prescription.exerciseId);
  const recommendation = recommendedNextWeight(state, prescription);
  const previousForSet = (setNumber: number) =>
    history.find((item) => item.log.setNumber === setNumber)?.log;
  const completeCount = logs.filter((log) => log.isComplete).length;
  const autoCandidate = logs.find((log) => {
    const previous = previousForSet(log.setNumber);
    return !log.isComplete && previous?.weight !== null && previous?.weight !== undefined && previous?.reps !== null && previous?.reps !== undefined;
  });
  const autoPrevious = autoCandidate ? previousForSet(autoCandidate.setNumber) : undefined;
  return (
    <article className={completeCount === logs.length && logs.length ? "track-exercise exercise-complete" : "track-exercise"}>
      <header>
        <div>
          <p className="eyebrow">{prescription.bodyPart} · {prescription.equipment}</p>
          <h2>{prescription.exerciseName}</h2>
          <p className="muted">{completeCount}/{logs.length} sets complete · {prescription.reps} reps</p>
          {originalName && <p className="substitution-note">Substituted for {originalName}</p>}
        </div>
        <div className="exercise-actions">
          <IconButton label={`Move ${prescription.exerciseName} up`} disabled={position === 0} onClick={() => dispatch({ type: "MOVE_WORKOUT_EXERCISE", prescriptionId: prescription.id, direction: "up" })}><ChevronUp size={18} /></IconButton>
          <IconButton label={`Move ${prescription.exerciseName} down`} disabled={position === total - 1} onClick={() => dispatch({ type: "MOVE_WORKOUT_EXERCISE", prescriptionId: prescription.id, direction: "down" })}><ChevronDown size={18} /></IconButton>
          <button className="exercise-text-action" onClick={onSubstitute}><RotateCcw size={15} /> Substitute</button>
          <IconButton
            label={`Remove ${prescription.exerciseName}`}
            tone="danger"
            onClick={() => confirm(`Remove ${prescription.exerciseName}?`) && dispatch({ type: "DELETE_PRESCRIPTION", prescriptionId: prescription.id })}
          ><Trash2 size={18} /></IconButton>
        </div>
      </header>
      <div className="exercise-settings-row">
        <label><span>Rest after each set</span><select aria-label={`${prescription.exerciseName} rest time`} value={prescription.restSeconds} onChange={(event) => dispatch({ type: "SET_WORKOUT_REST", prescriptionId: prescription.id, seconds: Number(event.target.value) })}>{[30, 45, 60, 90, 120, 180, 240, 300].map((seconds) => <option key={seconds} value={seconds}>{seconds < 60 ? `${seconds} sec` : `${seconds / 60} min`}</option>)}</select></label>
        <Progress value={logs.length ? completeCount / logs.length : 0} />
      </div>
      {recommendation && (
        <div className="recommendation"><TrendingUp size={17} /><span>Suggested working weight</span><strong>{formatWeight(recommendation)} lb</strong></div>
      )}
      {autoCandidate && autoPrevious && (
        <button className="previous-set-action" onClick={() => { dispatch({ type: "AUTO_COMPLETE_SET", logId: autoCandidate.id }); onSetCompleted?.(); }}>
          <History size={16} /> Use previous set {autoCandidate.setNumber}: {formatWeight(autoPrevious.weight ?? 0)} lb × {autoPrevious.reps} and complete
        </button>
      )}
      <div className="set-table">
        <div className="set-table-head"><span>Set</span><span>Weight (lb)</span><span>Reps</span><span>RPE</span><span>Done</span></div>
        {logs.map((log) => {
          const previous = previousForSet(log.setNumber);
          return (
            <div
              className={log.isComplete ? "set-row complete" : "set-row"}
              key={log.id}
              onKeyDown={(event) => {
                if (event.key !== "Enter" || !(event.target instanceof HTMLInputElement)) return;
                event.preventDefault();
                const inputs = Array.from(event.currentTarget.parentElement?.querySelectorAll<HTMLInputElement>("input") ?? []);
                inputs[inputs.indexOf(event.target) + 1]?.focus();
              }}
            >
              <strong>{log.setNumber}</strong>
              <NumberField
                label={`Set ${log.setNumber} weight`}
                value={log.weight}
                last={previous?.weight}
                onChange={(value) => dispatch({ type: "UPDATE_SET", logId: log.id, field: "weight", value })}
              />
              <NumberField
                label={`Set ${log.setNumber} reps`}
                value={log.reps}
                last={previous?.reps}
                integer
                onChange={(value) => dispatch({ type: "UPDATE_SET", logId: log.id, field: "reps", value })}
              />
              <NumberField
                label={`Set ${log.setNumber} RPE optional`}
                value={log.rpe}
                integer
                max={10}
                optional
                onChange={(value) => dispatch({ type: "UPDATE_SET", logId: log.id, field: "rpe", value })}
              />
              <button
                className="complete-set"
                aria-label={log.isComplete ? `Mark set ${log.setNumber} incomplete` : `Complete set ${log.setNumber}`}
                disabled={!log.isComplete && (log.weight === null || log.reps === null)}
                onClick={() => { dispatch({ type: "TOGGLE_SET", logId: log.id }); if (!log.isComplete) onSetCompleted?.(); }}
              >
                {log.isComplete ? <Check size={20} /> : <span />}
              </button>
              {logs.length > 1 && <button className="delete-set" aria-label={`Delete set ${log.setNumber}`} onClick={() => dispatch({ type: "DELETE_SET", logId: log.id })}><Trash2 size={15} /></button>}
            </div>
          );
        })}
      </div>
      <button className="add-set-button" onClick={() => dispatch({ type: "ADD_SET", prescriptionId: prescription.id })}><Plus size={17} /> Add set</button>
    </article>
  );
}

function NumberField({ label, value, last, integer, max, optional, onChange }: {
  label: string;
  value: number | null;
  last?: number | null;
  integer?: boolean;
  max?: number;
  optional?: boolean;
  onChange: (value: number | null) => void;
}) {
  return (
    <label className="number-field">
      <input
        aria-label={label}
        inputMode="decimal"
        type="number"
        min="0"
        max={max}
        step={integer ? 1 : 0.5}
        value={value ?? ""}
        placeholder="—"
        onChange={(event) => {
          if (!event.target.value) return onChange(null);
          const parsed = integer ? Number.parseInt(event.target.value, 10) : Number(event.target.value);
          onChange(Number.isFinite(parsed) ? parsed : null);
        }}
      />
      {last !== undefined && last !== null ? (
        <button type="button" onClick={() => onChange(last)}>Last: {last}</button>
      ) : <small>{optional ? "Optional" : "Required"}</small>}
    </label>
  );
}

function SubstituteExerciseDialog({ prescription, usedExerciseIds, onClose }: {
  prescription: ExercisePrescription;
  usedExerciseIds: string[];
  onClose: () => void;
}) {
  const { state, dispatch } = useTracker();
  const [query, setQuery] = useState("");
  const current = state.exercises.find((item) => item.id === prescription.exerciseId);
  const override = state.activeWorkout?.exerciseOverrides[prescription.id];
  const original = override && state.exercises.find((item) => item.id === override.originalExerciseId);
  const used = new Set(usedExerciseIds);
  const normalizedQuery = query.trim().toLowerCase();
  const options = state.exercises
    .filter((item) => !used.has(item.id) && item.id !== prescription.exerciseId)
    .map((exercise) => {
      const sameMovement = Boolean(current && exercise.movementType === current.movementType);
      const sameBodyPart = exercise.bodyPart === prescription.bodyPart;
      const sameEquipment = exercise.equipment === prescription.equipment;
      const score = Number(sameBodyPart) * 4 + Number(sameMovement) * 3 + Number(sameEquipment);
      const reason = sameBodyPart && sameMovement ? "Same muscles and movement" : sameBodyPart ? "Same primary area" : sameMovement ? "Same movement pattern" : "Other option";
      return { exercise, score, reason };
    })
    .filter(({ exercise }) => !normalizedQuery || [exercise.name, ...(exercise.searchAliases ?? []), exercise.bodyPart, exercise.equipment, exercise.movementType].join(" ").toLowerCase().includes(normalizedQuery))
    .sort((a, b) => b.score - a.score || a.exercise.name.localeCompare(b.exercise.name))
    .slice(0, 60);

  const select = (exercise: Exercise) => {
    dispatch({ type: "SUBSTITUTE_WORKOUT_EXERCISE", prescriptionId: prescription.id, exercise });
    onClose();
  };

  return (
    <Modal title={`Substitute ${prescription.exerciseName}`} subtitle="This change applies only to the current workout." onClose={onClose} size="large">
      <label className="search-field"><Search size={19} /><input autoFocus aria-label="Search compatible substitutions" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search compatible exercises..." /></label>
      {original && <button className="restore-exercise-action" onClick={() => select(original)}><RotateCcw size={17} /><span><strong>Restore {original.name}</strong><small>Original programmed exercise</small></span></button>}
      <div className="substitution-list">
        {options.map(({ exercise, score, reason }) => (
          <button key={exercise.id} onClick={() => select(exercise)}>
            <BodyRegionGlyph exercise={exercise} />
            <span><strong>{exercise.name}</strong><small>{exercise.bodyPart} · {exercise.equipment}</small></span>
            <em className={score >= 7 ? "best-match" : ""}>{reason}</em>
          </button>
        ))}
        {!options.length && <div className="empty-state compact"><h3>No matching exercises</h3><p>Try a broader name, muscle, equipment, or movement search.</p></div>}
      </div>
    </Modal>
  );
}

function ExercisePicker({ session, onClose }: { session: WorkoutSession; onClose: () => void }) {
  const { state, dispatch } = useTracker();
  const [query, setQuery] = useState("");
  const [bodyPart, setBodyPart] = useState("All");
  const [equipment, setEquipment] = useState("All");
  const [selected, setSelected] = useState<Exercise | null>(null);
  const [customOpen, setCustomOpen] = useState(false);
  const usedIds = new Set(state.prescriptions.filter((item) => item.sessionId === session.id).map((item) => item.exerciseId));
  const bodyParts = ["All", ...new Set(state.exercises.map((item) => item.bodyPart))];
  const equipmentOptions = ["All", ...new Set(state.exercises.map((item) => item.equipment))];
  const exercises = state.exercises.filter((item) => {
    const q = query.toLowerCase();
    return (
      !usedIds.has(item.id) &&
      (!q || [item.name, item.bodyPart, item.equipment, ...(item.searchAliases ?? [])].join(" ").toLowerCase().includes(q)) &&
      (bodyPart === "All" || item.bodyPart === bodyPart) &&
      (equipment === "All" || item.equipment === equipment)
    );
  });
  if (selected) {
    return <PrescriptionDialog exercise={selected} session={session} onBack={() => setSelected(null)} onClose={onClose} />;
  }
  return (
    <Modal title="Add Exercise" subtitle={`${session.day} · ${session.name}`} onClose={onClose} size="large">
      <div className="picker-sticky">
        <label className="search-field"><Search size={19} /><input autoFocus aria-label="Search exercises to add" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search exercises..." /></label>
        <div className="picker-filters">
          <Select label="Body part" value={bodyPart} options={bodyParts} onChange={setBodyPart} />
          <Select label="Equipment" value={equipment} options={equipmentOptions} onChange={setEquipment} />
        </div>
      </div>
      <div className="picker-list">
        {exercises.map((exercise) => (
          <button key={exercise.id} onClick={() => setSelected(exercise)}>
            <BodyRegionGlyph exercise={exercise} />
            <span><strong>{exercise.name}</strong><small>{exercise.bodyPart} · {exercise.equipment}</small></span>
            <Plus size={19} />
          </button>
        ))}
      </div>
      <button className="secondary-action" onClick={() => setCustomOpen(true)}><Plus size={18} /> Create custom exercise</button>
      {customOpen && <CustomExerciseDialog onClose={() => setCustomOpen(false)} onCreated={(exercise) => { setCustomOpen(false); setSelected(exercise); }} />}
    </Modal>
  );
}

function PrescriptionDialog({ exercise, session, onBack, onClose }: {
  exercise: Exercise;
  session: WorkoutSession;
  onBack: () => void;
  onClose: () => void;
}) {
  const { dispatch } = useTracker();
  const [sets, setSets] = useState(3);
  const [reps, setReps] = useState("8-12");
  const [rest, setRest] = useState(120);
  return (
    <Modal title={exercise.name} subtitle="Workout settings" onClose={onClose}>
      <button className="back-inline" onClick={onBack}><ArrowLeft size={17} /> Back to exercises</button>
      <div className="program-form">
        <label><span>Sets</span><input aria-label="Sets" type="number" min="1" max="12" value={sets} onChange={(event) => setSets(Number(event.target.value))} /></label>
        <ChipField label="Rep goal" values={["1-5", "6-8", "8-12", "12-15", "15-20"]} value={reps} onChange={setReps} />
        <ChipField label="Rest time" values={[60, 90, 120, 180]} value={rest} onChange={setRest} format={(value) => `${value} sec`} />
      </div>
      <button
        className="primary-button large modal-primary"
        onClick={() => {
          dispatch({ type: "ADD_PRESCRIPTION", sessionId: session.id, exercise, sets, reps, restSeconds: rest });
          onClose();
        }}
      ><Plus size={19} /> Add to workout</button>
    </Modal>
  );
}

function CustomExerciseDialog({ onClose, onCreated }: { onClose: () => void; onCreated?: (exercise: Exercise) => void }) {
  const { dispatch } = useTracker();
  const [name, setName] = useState("");
  const [bodyPart, setBodyPart] = useState("Chest");
  const [equipment, setEquipment] = useState("Dumbbells");
  const [trackingType, setTrackingType] = useState<TrackingType>("Weight + Reps");
  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (!name.trim()) return;
    const exercise: Exercise = {
      id: makeId("exercise"),
      name: name.trim(),
      bodyPart,
      secondaryMuscles: [],
      equipment,
      movementType: "Strength",
      trackingType,
      isCustom: true
    };
    dispatch({ type: "ADD_EXERCISE", exercise });
    onCreated?.(exercise);
    if (!onCreated) onClose();
  };
  return (
    <Modal title="Create Custom Exercise" subtitle="Add a movement that is not already in the catalog." onClose={onClose}>
      <form className="stack-form" onSubmit={submit}>
        <label><span>Exercise name</span><input autoFocus value={name} onChange={(event) => setName(event.target.value)} placeholder="Exercise name" /></label>
        <Select label="Muscle group" value={bodyPart} options={["Chest", "Back", "Shoulders", "Arms", "Quads", "Hamstrings", "Glutes", "Calves", "Core", "Full Body"]} onChange={setBodyPart} />
        <Select label="Equipment" value={equipment} options={["Barbell", "Dumbbells", "Cable", "Machine", "Bodyweight", "Kettlebell", "Bands", "Other"]} onChange={setEquipment} />
        <ChipField label="Measurement" values={["Weight + Reps", "Reps Only", "Time"] as TrackingType[]} value={trackingType} onChange={setTrackingType} />
        <button className="primary-button large" disabled={!name.trim()}>Save exercise</button>
      </form>
    </Modal>
  );
}

function PlanDialog({ mode, plan, onClose }: { mode: "create" | "rename"; plan: WorkoutPlan; onClose: () => void }) {
  const { dispatch } = useTracker();
  const [name, setName] = useState(mode === "rename" ? plan.name : "");
  const [goal, setGoal] = useState(mode === "rename" ? plan.goal : "");
  return (
    <Modal title={mode === "create" ? "Create Plan" : "Rename Plan"} onClose={onClose}>
      <form
        className="stack-form"
        onSubmit={(event) => {
          event.preventDefault();
          if (mode === "create") dispatch({ type: "CREATE_PLAN", name, goal });
          else dispatch({ type: "RENAME_PLAN", planId: plan.id, name });
          onClose();
        }}
      >
        <label><span>Plan name</span><input autoFocus value={name} onChange={(event) => setName(event.target.value)} placeholder="Strength block" /></label>
        {mode === "create" && <label><span>Goal</span><textarea value={goal} onChange={(event) => setGoal(event.target.value)} placeholder="Build strength and muscle" /></label>}
        <button className="primary-button large" disabled={!name.trim()}>{mode === "create" ? "Create plan" : "Save name"}</button>
      </form>
    </Modal>
  );
}

function SessionDialog({ week, onClose }: { week: WorkoutWeek; onClose: () => void }) {
  const { dispatch } = useTracker();
  const [day, setDay] = useState("Monday");
  const [name, setName] = useState("");
  return (
    <Modal title="Add Workout Day" subtitle={week.title} onClose={onClose}>
      <form className="stack-form" onSubmit={(event) => {
        event.preventDefault();
        dispatch({ type: "ADD_SESSION", weekId: week.id, day, name });
        onClose();
      }}>
        <Select label="Day" value={day} options={["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]} onChange={setDay} />
        <label><span>Workout name</span><input autoFocus value={name} onChange={(event) => setName(event.target.value)} placeholder="Push, Pull, Legs..." /></label>
        <button className="primary-button large" disabled={!name.trim()}>Add workout day</button>
      </form>
    </Modal>
  );
}

function FinishDialog({ session, elapsed, onClose, onFinish }: { session: WorkoutSession; elapsed: number; onClose: () => void; onFinish: () => void }) {
  const { state, dispatch } = useTracker();
  const [effort, setEffort] = useState(5);
  const [notes, setNotes] = useState("");
  const [shared, setShared] = useState(false);
  const prescriptions = state.prescriptions.filter((item) => item.sessionId === session.id).map((item) => {
    const override = state.activeWorkout?.exerciseOverrides[item.id];
    return override ? { ...item, exerciseId: override.exerciseId, exerciseName: override.exerciseName, bodyPart: override.bodyPart, equipment: override.equipment } : item;
  });
  const logs = state.setLogs.filter((log) => prescriptions.some((item) => item.id === log.prescriptionId) && log.isComplete);
  const allSessionLogs = state.setLogs.filter((log) => prescriptions.some((item) => item.id === log.prescriptionId));
  const incompleteSets = allSessionLogs.filter((log) => !log.isComplete).length;
  const completedExercises = new Set(logs.map((item) => item.prescriptionId)).size;
  const volume = logs.reduce((sum, log) => sum + (log.weight ?? 0) * (log.reps ?? 0), 0);
  const best = logs.reduce<typeof logs[number] | null>((result, log) => !result || (log.weight ?? 0) > (result.weight ?? 0) ? log : result, null);
  const muscles = [...new Set(prescriptions.filter((item) => logs.some((log) => log.prescriptionId === item.id)).map((item) => item.bodyPart))];
  const prCandidates = prescriptions.filter((prescription) => {
    const currentBest = Math.max(0, ...logs.filter((log) => log.prescriptionId === prescription.id).map((log) => log.weight ?? 0));
    const previousBest = personalRecords(state, prescription.exerciseId).heaviest?.weight ?? 0;
    return currentBest > previousBest;
  });
  return (
    <Modal title="Finish Workout" subtitle={session.name} onClose={onClose}>
      <div className="summary-hero"><CheckCircle2 size={34} /><h2>Session complete</h2><p>{formatDuration(elapsed)} of focused training</p></div>
      <div className="summary-grid">
        <div><strong>{completedExercises}/{prescriptions.length}</strong><span>Exercises</span></div>
        <div><strong>{logs.length}</strong><span>Sets</span></div>
        <div><strong>{formatWeight(volume)}</strong><span>Volume lb</span></div>
        <div><strong>{best ? `${best.weight} × ${best.reps}` : "—"}</strong><span>Best set</span></div>
      </div>
      <div className="workout-insights">
        <div><span>Muscles trained</span><strong>{muscles.join(", ") || "None yet"}</strong></div>
        <div><span>PR candidates</span><strong>{prCandidates.length ? prCandidates.map((item) => item.exerciseName).join(", ") : "No new candidates"}</strong></div>
      </div>
      {incompleteSets > 0 && <div className="incomplete-warning"><ShieldCheck size={18} /><span><strong>{incompleteSets} incomplete set{incompleteSets === 1 ? "" : "s"}</strong> will be left out of history and volume.</span></div>}
      <ChipField label="Workout difficulty" values={[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]} value={effort} onChange={setEffort} />
      <label className="form-field"><span>Workout notes</span><textarea rows={3} value={notes} onChange={(event) => setNotes(event.target.value)} placeholder="Optional notes about the session" /></label>
      <label className="toggle-row"><input type="checkbox" checked={shared} onChange={(event) => setShared(event.target.checked)} /><span><strong>Share to Community</strong><small>Create a workout activity after saving.</small></span></label>
      <button className="primary-button large modal-primary" onClick={() => { dispatch({ type: "SAVE_WORKOUT_FEEDBACK", sessionId: session.id, effort, notes, shared }); onFinish(); }}><Check size={19} /> {incompleteSets ? `Finish with ${incompleteSets} incomplete` : "Save workout"}</button>
    </Modal>
  );
}

function ConfirmDialog({ title, body, confirmLabel, onClose, onConfirm }: {
  title: string; body: string; confirmLabel: string; onClose: () => void; onConfirm: () => void;
}) {
  return (
    <Modal title={title} onClose={onClose}>
      <p className="dialog-body">{body}</p>
      <div className="dialog-actions">
        <button className="quiet-button" onClick={onClose}>Keep workout</button>
        <button className="danger-button" onClick={onConfirm}>{confirmLabel}</button>
      </div>
    </Modal>
  );
}

function WorkoutHistoryCard({ workout }: { workout: ReturnType<typeof useTracker>["state"]["completedWorkouts"][number] }) {
  return (
    <Link className="card history-card" to={`/progress/workouts/${workout.id}`} aria-label={`Open ${workout.name} workout details`}>
      <span className="icon-tile green"><CheckCircle2 size={21} /></span>
      <div>
        <h3>{workout.name}</h3>
        <p className="muted">{new Date(workout.completedAt).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" })}</p>
      </div>
      <div className="history-metrics"><span><strong>{workout.totalSets}</strong> sets</span><span><strong>{formatWeight(workout.totalVolume)}</strong> lb</span><span><strong>{formatDuration(workout.durationSeconds)}</strong></span></div>
      <ChevronRight size={18} />
    </Link>
  );
}

function renderLeaderboardCell(entry: LeaderboardEntry, key: LeaderboardColumnKey): React.ReactNode {
  switch (key) {
    case "rank":
      return (
        <div className="leaderboard-rank-cell">
          <strong>#{entry.rank}</strong>
        </div>
      );
    case "athlete":
      return (
        <div className="leaderboard-identity-cell">
          <div className="leaderboard-name-row">
            <strong>{entry.athlete}</strong>
            {entry.isCurrentUser && <span className="status-chip">You</span>}
          </div>
          <small>@{entry.handle.replace(/^@/, "")} · {entry.ageGroup}</small>
        </div>
      );
    case "exercise":
      return (
        <div className="leaderboard-text-cell">
          <strong>{entry.exercise}</strong>
          <small>{entry.rankingType}</small>
        </div>
      );
    case "gym":
      return (
        <div className="leaderboard-text-cell">
          <strong>{entry.gym}</strong>
          <small>{entry.city}, {entry.state}</small>
        </div>
      );
    case "score":
      return (
        <div className="leaderboard-score-cell">
          <strong>{formatLeaderboardScore(entry)}</strong>
          <small>{leaderboardScoreSubtitle(entry)}</small>
        </div>
      );
    case "verification": {
      const description = verificationDescription(entry.verification);
      return <span className={`status-chip verification-${entry.verification.toLowerCase().replace(/\s+/g, "-")}`} title={description} aria-label={`${entry.verification}: ${description}`} tabIndex={0}>{entry.verification}</span>;
    }
    case "trend": {
      const trendLabel = entry.rankChange > 0 ? `Up ${entry.rankChange} ${entry.rankChange === 1 ? "place" : "places"}` : entry.rankChange < 0 ? `Down ${Math.abs(entry.rankChange)} ${entry.rankChange === -1 ? "place" : "places"}` : "No change";
      return (
        <span className={entry.rankChange > 0 ? "trend-pill positive" : entry.rankChange < 0 ? "trend-pill negative" : "trend-pill"} aria-label={trendLabel} title={trendLabel}>
          {entry.rankChange > 0 ? `↑ ${entry.rankChange}` : entry.rankChange < 0 ? `↓ ${Math.abs(entry.rankChange)}` : "—"}
        </span>
      );
    }
  }
}

function LeaderboardFiltersDialog({
  currentFilters,
  query,
  onClose,
  onApply
}: {
  currentFilters: LeaderboardFiltersState;
  query: string;
  onClose: () => void;
  onApply: (filters: LeaderboardFiltersState) => void;
}) {
  const { state } = useTracker();
  const [draft, setDraft] = useState(currentFilters);
  const exerciseOptions = useMemo(() => withAllOption(state.liftSubmissions.map((lift) => lift.exerciseName)), [state.liftSubmissions]);
  const gymOptions = useMemo(() => withAllOption(state.gyms.map((gym) => gym.name)), [state.gyms]);
  const ageGroupOptions = useMemo(() => withAllOption(state.profiles.map((profile) => profile.ageGroup)), [state.profiles]);
  const experienceOptions = useMemo(() => withAllOption(state.profiles.map((profile) => profile.experienceLevel)), [state.profiles]);
  const weightClassOptions = useMemo(() => withAllOption(state.profiles.map((profile) => weightClassFor(profile.bodyweight, profile.sex))), [state.profiles]);

  useEffect(() => {
    setDraft((current) => ({
      ...current,
      exercise: exerciseOptions.includes(current.exercise) ? current.exercise : "All",
      gym: gymOptions.includes(current.gym) ? current.gym : "All",
      city: "All",
      ageGroup: ageGroupOptions.includes(current.ageGroup) ? current.ageGroup : "All",
      experienceLevel: experienceOptions.includes(current.experienceLevel) ? current.experienceLevel : "All",
      weightClass: weightClassOptions.includes(current.weightClass) ? current.weightClass : "All"
    }));
  }, [ageGroupOptions, exerciseOptions, experienceOptions, gymOptions, weightClassOptions]);

  const normalizedDraft = normalizeLeaderboardFilters(draft);
  const pendingChanges = (Object.keys(currentFilters) as Array<keyof LeaderboardFiltersState>).filter((key) => currentFilters[key] !== normalizedDraft[key]).length;
  const previewCount = useMemo(() => {
    const search = query.trim().toLowerCase();
    return computedLeaderboardEntries(state, normalizedDraft).filter((entry) => !search || [entry.athlete, entry.handle, entry.exercise, entry.gym, entry.city, entry.state].join(" ").toLowerCase().includes(search)).length;
  }, [normalizedDraft, query, state]);
  const showExercise = !["Total", "Relative total"].includes(draft.rankingType);
  const needsGymSelection = draft.scope === "Selected gym" && draft.gym === "All";

  return (
    <Modal title="Filters" subtitle="Refine the leaderboard scope and ranking mode." onClose={onClose} size="large">
      <form
        className="leaderboard-dialog-form leaderboard-filter-form"
        onSubmit={(event) => {
          event.preventDefault();
          if (pendingChanges === 0 || needsGymSelection) return;
          onApply(normalizedDraft);
        }}
      >
        <section className="filter-section"><div className="filter-section-heading"><span>1</span><div><h3>Rank by</h3><p>Choose how athlete results are compared.</p></div></div>
          <ChipField
            label="Rank by"
            values={["Total", "Absolute", "Pound-for-pound", "Relative total", "Most improved"] as RankingType[]}
            value={draft.rankingType}
            onChange={(rankingType) =>
              setDraft((current) => ({
                ...current,
                rankingType, ...(["Total", "Relative total"].includes(rankingType) ? { exercise: "All", repCount: null } : {})
              }))
            }
          />
          <p className="ranking-explanation">{leaderboardRankingExplanation(draft.rankingType)}</p>
        </section>
        <section className="filter-section"><div className="filter-section-heading"><span>2</span><div><h3>Scope</h3><p>Choose the community used for this ranking.</p></div></div>
          <ChipField
            label="Scope"
            values={["Global", "My gym", "My city", "My weight class", "Selected gym"] as LeaderboardScope[]}
            value={draft.scope}
            format={(scope) => scope === "Selected gym" ? "Choose a gym" : scope}
            onChange={(scope) =>
              setDraft((current) => ({
                ...current,
                scope,
                gym: "All",
                city: "All",
                ...(scope === "My weight class" ? { weightClass: "All" } : {})
              }))
            }
          />
          {draft.scope === "Selected gym" && <Select label="Gym" value={draft.gym} options={gymOptions} onChange={(gym) => setDraft((current) => ({ ...current, gym }))} />}
        </section>
        <section className="filter-section"><div className="filter-section-heading"><span>3</span><div><h3>Performance</h3><p>Narrow the qualifying submissions.</p></div></div><div className="filter-fields-grid">
          {showExercise && <Select label="Exercise" value={draft.exercise} options={exerciseOptions} onChange={(exercise) => setDraft((current) => ({ ...current, exercise, repCount: exercise === "All" ? null : current.repCount }))} />}
          <Select label="Verification level" value={draft.verification} options={["All", "Self Reported", "Video Submitted", "Video Verified", "Community Verified", "Competition Verified"]} onChange={(verification) => setDraft((current) => ({ ...current, verification: verification as LeaderboardFiltersState["verification"] }))} />
          {showExercise && draft.exercise !== "All" && <Select label="Repetitions" value={draft.repCount?.toString() ?? "All"} options={["All", "1", "3", "5", "8", "10"]} onChange={(repetitions) => setDraft((current) => ({ ...current, repCount: repetitions === "All" ? null : Number(repetitions) }))} />}
        </div></section>
        <section className="filter-section"><div className="filter-section-heading"><span>4</span><div><h3>Athlete</h3><p>Filter by athlete category.</p></div></div><div className="filter-fields-grid athlete-fields">
          {draft.scope !== "My weight class" && <Select label="Weight class" value={draft.weightClass} options={weightClassOptions} onChange={(weightClass) => setDraft((current) => ({ ...current, weightClass }))} />}
          <Select label="Age group" value={draft.ageGroup} options={ageGroupOptions} onChange={(ageGroup) => setDraft((current) => ({ ...current, ageGroup }))} />
          <Select
            label="Training experience"
            value={draft.experienceLevel}
            options={experienceOptions}
            onChange={(experienceLevel) => setDraft((current) => ({ ...current, experienceLevel }))}
          />
        </div></section>
        <div className="filter-dialog-footer">
          <div><strong>{pendingChanges} pending {pendingChanges === 1 ? "change" : "changes"}</strong><small>{needsGymSelection ? "Choose a gym to apply this scope" : `${previewCount} matching athletes`}</small></div>
          <button
            type="button"
            className="quiet-button"
            onClick={() => setDraft(defaultLeaderboardFilters)}
          >
            Clear all
          </button>
          <button className="primary-button" type="submit" disabled={pendingChanges === 0 || needsGymSelection}>
            Show {previewCount} athletes
          </button>
        </div>
      </form>
    </Modal>
  );
}

function LeaderboardColumnsDialog({
  columnOrder,
  columnVisibility,
  onClose,
  onApply
}: {
  columnOrder: LeaderboardColumnKey[];
  columnVisibility: Record<LeaderboardColumnKey, boolean>;
  onClose: () => void;
  onApply: (value: {
    nextOrder: LeaderboardColumnKey[];
    nextVisibility: Record<LeaderboardColumnKey, boolean>;
  }) => void;
}) {
  const [draftOrder, setDraftOrder] = useState(columnOrder);
  const [draftVisibility, setDraftVisibility] = useState(columnVisibility);

  const moveColumn = (index: number, offset: number) => {
    setDraftOrder((current) => {
      const nextIndex = index + offset;
      if (nextIndex < 0 || nextIndex >= current.length) return current;
      const next = [...current];
      [next[index], next[nextIndex]] = [next[nextIndex], next[index]];
      return next;
    });
  };

  const toggleColumn = (key: LeaderboardColumnKey) => {
    setDraftVisibility((current) => {
      const next = { ...current, [key]: !current[key] };
      if (!Object.values(next).some(Boolean)) return current;
      return next;
    });
  };

  return (
    <Modal title="Columns" subtitle="Choose which ranking columns stay visible and how they are ordered." onClose={onClose} size="large">
      <div className="leaderboard-column-editor">
        <div className="leaderboard-column-header">
          <span>Visible columns</span>
          <small>{draftOrder.filter((key) => draftVisibility[key]).length} shown</small>
        </div>
        <div className="leaderboard-column-list">
          {draftOrder.map((key, index) => {
            const config = leaderboardColumnConfig.find((column) => column.key === key)!;
            const visible = draftVisibility[key];
            return (
              <div key={key} className={visible ? "leaderboard-column-row" : "leaderboard-column-row muted"}>
                <button
                  type="button"
                  className="column-visibility-button"
                  aria-label={visible ? `Hide ${config.label}` : `Show ${config.label}`}
                  onClick={() => toggleColumn(key)}
                >
                  {visible ? <Eye size={16} /> : <EyeOff size={16} />}
                </button>
                <div className="leaderboard-column-copy">
                  <strong>{config.label}</strong>
                  <small>{config.description}</small>
                </div>
                <div className="column-reorder">
                  <button type="button" onClick={() => moveColumn(index, -1)} disabled={index === 0} aria-label={`Move ${config.label} up`}>
                    <ChevronUp size={15} />
                  </button>
                  <button
                    type="button"
                    onClick={() => moveColumn(index, 1)}
                    disabled={index === draftOrder.length - 1}
                    aria-label={`Move ${config.label} down`}
                  >
                    <ChevronDown size={15} />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      </div>
      <div className="dialog-actions dialog-actions-spread">
        <button
          type="button"
          className="quiet-button"
          onClick={() => {
            setDraftOrder(defaultLeaderboardColumnOrder);
            setDraftVisibility(
              leaderboardColumnConfig.reduce((accumulator, column) => {
                accumulator[column.key] = column.defaultVisible;
                return accumulator;
              }, {} as Record<LeaderboardColumnKey, boolean>)
            );
          }}
        >
          Reset
        </button>
        <button
          className="primary-button"
          type="button"
          onClick={() => onApply({ nextOrder: draftOrder, nextVisibility: draftVisibility })}
        >
          Apply changes
        </button>
      </div>
    </Modal>
  );
}

function LeaderboardDetailDialog({ entry, onClose }: { entry: LeaderboardEntry; onClose: () => void }) {
  return (
    <Modal title={entry.athlete} subtitle={`${entry.exercise} · ${entry.rankingType}`} onClose={onClose} size="large">
      <div className="leaderboard-detail">
        <div className="summary-grid leaderboard-detail-grid">
          <div><strong>#{entry.rank}</strong><span>Current rank</span></div>
          <div><strong>{formatLeaderboardScore(entry)}</strong><span>Score</span></div>
          <div><strong>{entry.verification}</strong><span>Verification</span></div>
          <div><strong>{entry.rankChange > 0 ? `+${entry.rankChange}` : `${entry.rankChange}`}</strong><span>Rank change</span></div>
        </div>
        <Card className="leaderboard-detail-card">
          <div className="leaderboard-detail-copy">
            <p className="eyebrow">{entry.handle}</p>
            <h3>{entry.gym}</h3>
            <p className="muted">{entry.city}, {entry.state}</p>
          </div>
          <div className="leaderboard-detail-meta">
            <span><strong>{formatWeight(entry.bodyweight)}</strong><small>Bodyweight</small></span>
            <span><strong>{formatWeight(entry.total)}</strong><small>Total</small></span>
            <span><strong>{entry.ageGroup}</strong><small>Age group</small></span>
            <span><strong>{entry.experienceLevel}</strong><small>Experience</small></span>
          </div>
        </Card>
        {entry.userId && <Link className="primary-button" to={`/profile/${entry.userId}`} onClick={onClose}>View athlete profile</Link>}
      </div>
    </Modal>
  );
}

function MetricCard({ icon, label, value, detail }: { icon: React.ReactNode; label: string; value: string; detail: string }) {
  return (
    <Card className="metric-card">
      <span className="icon-tile blue">{icon}</span>
      <div className="metric-card-copy">
        <p>{label}</p>
        <strong>{value}</strong>
        <small>{detail}</small>
      </div>
    </Card>
  );
}

function Card({ children, className = "" }: PropsWithChildren<{ className?: string }>) {
  return <div className={`card ${className}`}>{children}</div>;
}

function Progress({ value }: { value: number }) {
  return <div className="progress-track" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(value * 100)}><i style={{ width: `${Math.max(0, Math.min(100, value * 100))}%` }} /></div>;
}

function SectionTitle({ title, action }: { title: string; action?: React.ReactNode }) {
  return <div className="section-title"><h2>{title}</h2>{action}</div>;
}

function EmptyState({ title, body }: { title: string; body: string }) {
  return <div className="empty-state"><span><Dumbbell size={22} /></span><h3>{title}</h3><p>{body}</p></div>;
}

function IconButton({ label, children, onClick, tone = "normal", disabled }: PropsWithChildren<{ label: string; onClick: () => void; tone?: "normal" | "danger"; disabled?: boolean }>) {
  return <button className={`icon-button ${tone}`} aria-label={label} title={label} onClick={onClick} disabled={disabled}>{children}</button>;
}

function Select({ label, value, options, onChange }: { label: string; value: string; options: string[]; onChange: (value: string) => void }) {
  return <label className="select-field"><span>{label}</span><select aria-label={label} value={value} onChange={(event) => onChange(event.target.value)}>{options.map((option) => <option key={option}>{option}</option>)}</select></label>;
}

function MultiSelectFilter({ label, values, options, onChange }: {
  label: string;
  values: string[];
  options: string[];
  onChange: (values: string[]) => void;
}) {
  return (
    <details className="multi-filter" name="library-filter-group">
      <summary><span>{label}</span><strong>{values.length ? `${values.length} selected` : "All"}</strong><ChevronDown size={16} /></summary>
      <fieldset>
        <legend className="sr-only">{label}</legend>
        {options.map((option) => (
          <label key={option}>
            <input
              type="checkbox"
              checked={values.includes(option)}
              onChange={() => onChange(values.includes(option) ? values.filter((item) => item !== option) : [...values, option])}
            />
            <span>{option}</span>
          </label>
        ))}
        {values.length > 0 && <button type="button" onClick={() => onChange([])}>Clear {label.toLowerCase()}</button>}
      </fieldset>
    </details>
  );
}

function ChipField<T extends string | number>({ label, values, value, onChange, format = String }: { label: string; values: readonly T[]; value: T; onChange: (value: T) => void; format?: (value: T) => string }) {
  return <fieldset className="chip-field"><legend>{label}</legend><div>{values.map((item) => <button type="button" className={item === value ? "active" : ""} aria-pressed={item === value} key={item} onClick={() => onChange(item)}>{format(item)}</button>)}</div></fieldset>;
}

function Modal({ title, subtitle, children, onClose, size = "normal" }: PropsWithChildren<{ title: string; subtitle?: string; onClose: () => void; size?: "normal" | "large" }>) {
  const dialogRef = useRef<HTMLElement | null>(null);
  const closeRef = useRef(onClose);
  closeRef.current = onClose;
  useEffect(() => {
    const previousFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const dialog = dialogRef.current;
    dialog?.focus();
    const handler = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        closeRef.current();
        return;
      }
      if (event.key !== "Tab" || !dialog) return;
      const focusable = Array.from(dialog.querySelectorAll<HTMLElement>('button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'));
      if (!focusable.length) {
        event.preventDefault();
        dialog.focus();
        return;
      }
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    document.addEventListener("keydown", handler);
    return () => {
      document.removeEventListener("keydown", handler);
      previousFocus?.focus();
    };
  }, []);
  return (
    <div className="modal-backdrop" role="presentation" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section ref={dialogRef} tabIndex={-1} className={`modal ${size}`} role="dialog" aria-modal="true" aria-labelledby="modal-title" aria-describedby={subtitle ? "modal-subtitle" : undefined}>
        <header><div><h2 id="modal-title">{title}</h2>{subtitle && <p id="modal-subtitle">{subtitle}</p>}</div><IconButton label="Close" onClick={onClose}><X size={20} /></IconButton></header>
        <div className="modal-content">{children}</div>
      </section>
    </div>
  );
}

function formatLeaderboardScore(entry: LeaderboardEntry): string {
  switch (entry.rankingType) {
    case "Absolute":
    case "Total":
      return `${formatWeight(entry.score)} lb`;
    case "Pound-for-pound":
    case "Relative total":
      return `${entry.score.toFixed(2)}x`;
    case "Most improved":
      return `+${entry.score.toFixed(0)}%`;
  }
  return `${formatWeight(entry.score)} lb`;
}

function leaderboardColumnLabel(key: LeaderboardColumnKey, rankingType: RankingType): string | undefined {
  if (key !== "score") return leaderboardColumnConfig.find((column) => column.key === key)?.label;
  switch (rankingType) {
    case "Absolute":
      return "Top lift";
    case "Total":
      return "Top total";
    case "Pound-for-pound":
      return "Relative lift";
    case "Relative total":
      return "Relative total";
    case "Most improved":
      return "Improvement";
  }
}

function leaderboardScoreSubtitle(entry: LeaderboardEntry): string {
  switch (entry.rankingType) {
    case "Absolute":
      return `${entry.exercise} · Absolute`;
    case "Total":
      return `${formatWeight(entry.total)} total`;
    case "Pound-for-pound":
      return `${entry.exercise} · pound-for-pound`;
    case "Relative total":
      return `${formatWeight(entry.total)} total`;
    case "Most improved":
      return `${entry.exercise} · PR growth`;
  }
}

function leaderboardRankingExplanation(rankingType: RankingType): string {
  switch (rankingType) {
    case "Total": return "Best squat + bench + deadlift.";
    case "Absolute": return "Highest submitted weight for one exercise.";
    case "Pound-for-pound": return "Exercise result divided by bodyweight.";
    case "Relative total": return "Three-lift total divided by bodyweight.";
    case "Most improved": return "Percentage gain across eligible submissions.";
  }
}

function verificationDescription(level: LeaderboardEntry["verification"]): string {
  switch (level) {
    case "Competition Verified": return "Recorded in an approved competition result.";
    case "Video Verified": return "Video evidence was reviewed and approved.";
    case "Community Verified": return "Reviewed by eligible community members.";
    case "Video Submitted": return "Video evidence submitted and awaiting stronger verification.";
    case "Self Reported": return "Entered by the athlete without independent verification.";
  }
}

function withAllOption(values: string[]): string[] {
  return ["All", ...[...new Set(values)].sort((left, right) => left.localeCompare(right))];
}

function normalizeLeaderboardFilters(filters: LeaderboardFiltersState): LeaderboardFiltersState {
  const next = { ...filters, city: "All" };
  if (["Total", "Relative total"].includes(next.rankingType)) {
    next.exercise = "All";
    next.repCount = null;
  }
  if (next.exercise === "All") next.repCount = null;
  if (next.scope !== "Selected gym") next.gym = "All";
  if (next.scope === "My weight class") next.weightClass = "All";
  return next;
}

function leaderboardContextLabels(filters: LeaderboardFiltersState, state: TrackerState): string[] {
  const profile = currentProfile(state);
  const scope = filters.scope === "My gym" ? `Scope: My gym · ${state.gyms.find((gym) => gym.id === profile.primaryGymId)?.name ?? "Primary gym"}`
    : filters.scope === "My city" ? `Scope: My city · ${profile.city}, ${profile.state}`
    : filters.scope === "My weight class" ? `Scope: My weight class · ${weightClassFor(profile.bodyweight, profile.sex)}`
    : filters.scope === "Selected gym" ? `Scope: ${filters.gym === "All" ? "Choose a gym" : filters.gym}` : "Scope: Global";
  return [
    `Rank by: ${filters.rankingType}`,
    scope,
    `Exercise: ${["Total", "Relative total"].includes(filters.rankingType) ? "Three-lift total" : filters.exercise}`,
    `Verification: ${filters.verification}`,
    ...(filters.weightClass !== "All" ? [`Class: ${filters.weightClass}`] : []),
    ...(filters.ageGroup !== "All" ? [`Age: ${filters.ageGroup}`] : []),
    ...(filters.experienceLevel !== "All" ? [`Experience: ${filters.experienceLevel}`] : [])
  ];
}

function leaderboardActiveChips(filters: LeaderboardFiltersState): Array<{ key: keyof LeaderboardFiltersState; label: string }> {
  const chips: Array<{ key: keyof LeaderboardFiltersState; label: string }> = [];
  if (filters.rankingType !== "Total") chips.push({ key: "rankingType", label: filters.rankingType });
  if (filters.scope !== "Global") chips.push({ key: "scope", label: filters.scope === "Selected gym" && filters.gym !== "All" ? filters.gym : filters.scope });
  if (filters.verification !== "All") chips.push({ key: "verification", label: filters.verification });
  if (filters.exercise !== "All") chips.push({ key: "exercise", label: filters.exercise });
  if (filters.weightClass !== "All") chips.push({ key: "weightClass", label: filters.weightClass });
  if (filters.ageGroup !== "All") chips.push({ key: "ageGroup", label: filters.ageGroup });
  if (filters.experienceLevel !== "All") chips.push({ key: "experienceLevel", label: filters.experienceLevel });
  if (filters.repCount !== null) chips.push({ key: "repCount", label: `${filters.repCount} reps` });
  return chips;
}

function formatLeaderboardGap(gap: number, rankingType: RankingType): string {
  if (rankingType === "Absolute" || rankingType === "Total") return `${formatWeight(Math.max(0, gap))} lb`;
  if (rankingType === "Most improved") return `${Math.max(0, gap).toFixed(0)}%`;
  return `${Math.max(0, gap).toFixed(2)}x`;
}

function leaderboardColumnWidth(key: LeaderboardColumnKey): string {
  switch (key) {
    case "rank":
      return "72px";
    case "athlete":
      return "minmax(165px, 1.35fr)";
    case "exercise":
      return "minmax(145px, 1.1fr)";
    case "gym":
      return "minmax(170px, 1.25fr)";
    case "score":
      return "118px";
    case "verification":
      return "140px";
    case "trend":
      return "76px";
  }
}

function calculateStreak(dates: string[]): number {
  const unique = [...new Set(dates.map((date) => new Date(date).toDateString()))];
  if (!unique.length) return 0;
  let streak = 0;
  const cursor = new Date();
  for (;;) {
    if (unique.includes(cursor.toDateString())) streak += 1;
    else if (streak > 0) break;
    cursor.setDate(cursor.getDate() - 1);
    if (streak === 0 && Date.now() - cursor.getTime() > 86400000) break;
  }
  return streak;
}

export default App;
