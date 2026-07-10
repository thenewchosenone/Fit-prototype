import {
  Activity,
  ArrowLeft,
  ArrowDownRight,
  ArrowUpRight,
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
  useEffect,
  useMemo,
  useState
} from "react";
import { Link, NavLink, Navigate, Outlet, Route, Routes, useNavigate, useParams } from "react-router-dom";
import { leaderboardSeed } from "./data";
import {
  BodyRegionGlyph,
  CommunityPage,
  CommunityPostPage,
  ExerciseDetailPage,
  FriendsPage,
  GymDetailPage,
  GymsPage,
  MessageThreadPage,
  MessagesPage,
  NotificationButton,
  PlatformProfilePage,
  SettingsPage,
  SubmitLiftPage
} from "./PlatformPages";
import { computedLeaderboardEntries, currentProfile, nextLocalMidnight, weightClassFor } from "./platform";
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
  TrackingType,
  WorkoutPlan,
  WorkoutSession,
  WorkoutWeek
} from "./types";

const navItems = [
  { to: "/today", label: "Today", icon: House },
  { to: "/plans", label: "Plans", icon: Folder },
  { to: "/library", label: "Library", icon: LibraryBig },
  { to: "/submit", label: "Submit", icon: Plus },
  { to: "/leaderboards", label: "Leaderboards", icon: Trophy },
  { to: "/progress", label: "Progress", icon: BarChart3 },
  { to: "/gyms", label: "Gyms", icon: Building2 },
  { to: "/community", label: "Community", icon: Users },
  { to: "/messages", label: "Messages", icon: MessageCircle },
  { to: "/profile", label: "Profile", icon: UserRound }
];

const mobileNavItems = navItems.filter((item) => ["/today", "/plans", "/submit", "/leaderboards", "/community", "/profile"].includes(item.to));

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

function App() {
  return (
    <Routes>
      <Route element={<AppShell />}>
      <Route path="/today" element={<TodayPage />} />
      <Route path="/plans" element={<PlansPage />} />
      <Route path="/library" element={<LibraryPage />} />
      <Route path="/library/:exerciseId" element={<ExerciseDetailPage />} />
      <Route path="/submit" element={<SubmitLiftPage />} />
      <Route path="/leaderboards" element={<LeaderboardsPage />} />
      <Route path="/progress" element={<ProgressPage />} />
      <Route path="/gyms" element={<GymsPage />} />
      <Route path="/gyms/:gymId" element={<GymDetailPage />} />
      <Route path="/community" element={<CommunityPage />} />
      <Route path="/community/:postId" element={<CommunityPostPage />} />
      <Route path="/friends" element={<FriendsPage />} />
      <Route path="/messages" element={<MessagesPage />} />
      <Route path="/messages/:threadId" element={<MessageThreadPage />} />
      <Route path="/profile" element={<PlatformProfilePage />} />
      <Route path="/profile/:userId" element={<PlatformProfilePage />} />
      <Route path="/settings" element={<SettingsPage />} />
      </Route>
      <Route path="/workout/:sessionId" element={<WorkoutPage />} />
      <Route path="*" element={<Navigate to="/today" replace />} />
    </Routes>
  );
}

function AppShell() {
  const { state, dispatch } = useTracker();
  const activePlan = state.plans.find((plan) => plan.id === state.activePlanId);
  return (
    <div className="app-layout">
      <aside className="sidebar">
        <Logo />
        <nav aria-label="Tracker navigation">
          {navItems.map(({ to, label, icon: Icon }) => (
            <NavLink key={to} to={to} className={({ isActive }) => (isActive ? "nav-link active" : "nav-link")}>
              <Icon size={20} aria-hidden />
              <span>{label}</span>
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-plan">
          <p className="eyebrow">Active plan</p>
          <strong>{activePlan?.name}</strong>
          <span>{activePlan?.goal}</span>
        </div>
        <button className="quiet-button" onClick={() => dispatch({ type: "RESET_DEMO" })}>
          <RotateCcw size={17} /> Reset demo
        </button>
      </aside>
      <main className="main-content">
        <TopBar />
        <div id="page-content"><Outlet /></div>
      </main>
      <nav className="mobile-nav" aria-label="Tracker navigation">
        {mobileNavItems.map(({ to, label, icon: Icon }) => (
          <NavLink key={to} to={to} className={({ isActive }) => (isActive ? "active" : "")}>
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
  const profile = currentProfile(state);
  return (
    <header className="topbar">
      <div className="mobile-logo"><Logo /></div>
      <div className="topbar-copy">
        <p className="eyebrow">Training workspace</p>
        <strong>{state.plans.find((plan) => plan.id === state.activePlanId)?.name}</strong>
      </div>
      <div className="topbar-actions">
        <NotificationButton />
        <NavLink to="/profile" className="profile-pill" aria-label="Open profile">
          <span>{profile.displayName.split(" ").map((part) => part[0]).join("").slice(0, 2)}</span>
          <div><strong>{profile.displayName}</strong><small>{profile.experienceLevel}</small></div>
        </NavLink>
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
  const [columnOrder, setColumnOrder] = useState<LeaderboardColumnKey[]>(defaultLeaderboardColumnOrder);
  const [columnVisibility, setColumnVisibility] = useState<Record<LeaderboardColumnKey, boolean>>(
    () =>
      leaderboardColumnConfig.reduce((accumulator, column) => {
        accumulator[column.key] = column.defaultVisible;
        return accumulator;
      }, {} as Record<LeaderboardColumnKey, boolean>)
  );

  const filteredEntries = useMemo(() => {
    const search = query.trim().toLowerCase();
    return computedLeaderboardEntries(state, filters)
      .filter((entry) => {
        if (!search) return true;
        return [entry.athlete, entry.handle, entry.exercise, entry.gym, entry.city, entry.state]
          .join(" ")
          .toLowerCase()
          .includes(search);
      })
      .sort((left, right) => left.rank - right.rank);
  }, [state, filters, query]);

  const filteredCurrent = filteredEntries.find((entry) => entry.isCurrentUser);
  const fallbackCurrent = computedLeaderboardEntries(state, defaultLeaderboardFilters).find((entry) => entry.isCurrentUser);
  const currentUser = filteredCurrent ?? fallbackCurrent ?? filteredEntries[0];

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
    filters.repCount !== defaultLeaderboardFilters.repCount,
    query.trim().length > 0
  ].filter(Boolean).length;

  const visibleColumns = columnOrder.filter((key) => columnVisibility[key]);
  const tableTemplateColumns = visibleColumns.map((key) => leaderboardColumnWidth(key)).join(" ");
  const topEntry = filteredEntries[0] ?? null;
  const verifiedCount = filteredEntries.filter((entry) => entry.verification !== "Self Reported").length;
  const topRankingLabel = leaderboardRankingLabel(filters.rankingType);
  const topScoreValue = topEntry ? formatLeaderboardScore(topEntry) : "No result";
  const topScoreDetail = topEntry
    ? `${topEntry.exercise} · ${topEntry.athlete} · ${leaderboardRankingDescription(filters.rankingType)}`
    : "No matching rankings for this view";

  return (
    <div className="page">
      <PageHeader
        eyebrow="Competition"
        title="Leaderboards"
        description="Dense, table-first ranking view with reusable filters and column controls."
        action={currentUser && <button className="primary-button" onClick={() => setSelectedEntry(currentUser)}><Trophy size={18} /> Your rank</button>}
      />
      <div className="leaderboard-summary-grid">
        <MetricCard icon={<Trophy />} label="Current rank" value={filteredCurrent ? `#${filteredCurrent.rank}` : "Unranked"} detail={filteredCurrent ? `${filteredCurrent.exercise} in ${filteredCurrent.gym}` : "Not included in this view"} />
        <MetricCard icon={<Activity />} label="Visible rows" value={`${filteredEntries.length}`} detail={`${activeFilterCount} active filters`} />
        <MetricCard icon={<ShieldCheck />} label="Verified rows" value={`${verifiedCount}`} detail={`updates ${new Date(nextLocalMidnight()).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}`} />
        <MetricCard icon={<TrendingUp />} label={topRankingLabel} value={topScoreValue} detail={topScoreDetail} />
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
        <div className="leaderboard-toolbar-actions">
          <button className="text-button" onClick={() => setFiltersOpen(true)}>
            <SlidersHorizontal size={17} />
            Filters{activeFilterCount > 0 ? ` (${activeFilterCount})` : ""}
          </button>
          <button className="text-button" onClick={() => setColumnsOpen(true)}>
            <Columns3 size={17} />
            Columns
          </button>
        </div>
      </div>

      <section className="leaderboard-table-card" aria-label="Rankings">
        <div className="leaderboard-table" role="table" aria-label="Leaderboard rankings">
          <div className="leaderboard-table-header" style={{ gridTemplateColumns: tableTemplateColumns }}>
            {visibleColumns.map((key) => (
              <div key={key} className={`leaderboard-cell header ${key}`}>
                {leaderboardColumnLabel(key, filters.rankingType)}
              </div>
            ))}
          </div>
          <div className="leaderboard-table-body">
            {filteredEntries.map((entry) => (
              <button
                key={entry.id}
                className={entry.isCurrentUser ? "leaderboard-table-row current" : "leaderboard-table-row"}
                style={{ gridTemplateColumns: tableTemplateColumns }}
                onClick={() => setSelectedEntry(entry)}
              >
                {visibleColumns.map((key) => (
                  <div key={`${entry.id}-${key}`} className={`leaderboard-cell ${key}`}>
                    {renderLeaderboardCell(entry, key)}
                  </div>
                ))}
              </button>
            ))}
            {!filteredEntries.length && <EmptyState title="No matching rankings" body="Try a different scope, ranking type, or search term." />}
          </div>
        </div>
      </section>

      {filtersOpen && (
        <LeaderboardFiltersDialog
          currentFilters={filters}
          onClose={() => setFiltersOpen(false)}
          onApply={(nextFilters) => {
            setFilters(nextFilters);
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
  const [bodyPart, setBodyPart] = useState("All");
  const [equipment, setEquipment] = useState("All");
  const [customOpen, setCustomOpen] = useState(false);
  const bodyParts = ["All", ...new Set(state.exercises.map((item) => item.bodyPart))];
  const equipmentOptions = ["All", ...new Set(state.exercises.map((item) => item.equipment))];
  const filtered = state.exercises.filter((item) => {
    const q = query.trim().toLowerCase();
    return (
      (!q || [item.name, item.bodyPart, item.equipment, item.movementType, ...(item.searchAliases ?? [])].join(" ").toLowerCase().includes(q)) &&
      (bodyPart === "All" || item.bodyPart === bodyPart) &&
      (equipment === "All" || item.equipment === equipment)
    );
  });
  return (
    <div className="page">
      <PageHeader
        eyebrow="Exercise catalog"
        title="Library"
        description="Search common movements or create the exercise your gym uses."
        action={<button className="primary-button" onClick={() => setCustomOpen(true)}><Plus size={18} /> Custom exercise</button>}
      />
      <div className="filter-panel">
        <label className="search-field"><Search size={19} /><input aria-label="Search exercises" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search exercises..." /></label>
        <Select label="Body part" value={bodyPart} options={bodyParts} onChange={setBodyPart} />
        <Select label="Equipment" value={equipment} options={equipmentOptions} onChange={setEquipment} />
      </div>
      <div className="library-count">{filtered.length} exercises</div>
      <div className="exercise-grid">
        {filtered.map((exercise) => <ExerciseCard key={exercise.id} exercise={exercise} />)}
      </div>
      {!filtered.length && <EmptyState title="No matching exercises" body="Clear a filter or create a custom exercise." />}
      {customOpen && <CustomExerciseDialog onClose={() => setCustomOpen(false)} />}
    </div>
  );
}

function ExerciseCard({ exercise }: { exercise: Exercise }) {
  const { state } = useTracker();
  const records = personalRecords(state, exercise.id);
  return (
    <Card className="exercise-card">
      <div className="card-topline">
        <BodyRegionGlyph exercise={exercise} />
        {exercise.isCustom && <span className="status-chip">Custom</span>}
      </div>
      <div>
        <h3><Link to={`/library/${exercise.id}`}>{exercise.name}</Link></h3>
        <p className="muted">{exercise.bodyPart} · {exercise.equipment}</p>
      </div>
      <div className="exercise-meta">
        <span>{exercise.movementType}</span>
        <span>{exercise.trackingType}</span>
      </div>
      <div className="best-line">
        <Trophy size={16} />
        <span>{records.heaviest ? `Best ${formatWeight(records.heaviest.weight ?? 0)} lb × ${records.heaviest.reps}` : "No history yet"}</span>
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
  const prescriptions = state.prescriptions
    .filter((item) => item.sessionId === sessionId)
    .sort((a, b) => a.order - b.order);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [summaryOpen, setSummaryOpen] = useState(false);
  const [cancelOpen, setCancelOpen] = useState(false);
  const [elapsed, setElapsed] = useState(() => workoutDuration(state.activeWorkout));
  const [restRemaining, setRestRemaining] = useState(0);

  useEffect(() => {
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
              <span>{prescriptions.filter((item) => state.setLogs.some((log) => log.prescriptionId === item.id && log.isComplete)).length} of {prescriptions.length} exercises started</span>
              <Progress value={prescriptions.filter((item) => state.setLogs.some((log) => log.prescriptionId === item.id && log.isComplete)).length / prescriptions.length} />
            </div>
            <div className="track-list">
              {prescriptions.map((prescription) => <TrackExercise key={prescription.id} prescription={prescription} onSetCompleted={() => setRestRemaining(prescription.restSeconds)} />)}
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

function TrackExercise({ prescription, onSetCompleted }: { prescription: ExercisePrescription; onSetCompleted?: () => void }) {
  const { state, dispatch } = useTracker();
  const logs = state.setLogs
    .filter((log) => log.prescriptionId === prescription.id)
    .sort((a, b) => a.setNumber - b.setNumber);
  const history = exerciseHistory(state, prescription.exerciseId);
  const recommendation = recommendedNextWeight(state, prescription);
  const previousForSet = (setNumber: number) =>
    history.find((item) => item.log.setNumber === setNumber)?.log;
  return (
    <article className="track-exercise">
      <header>
        <div>
          <p className="eyebrow">{prescription.bodyPart} · {prescription.equipment}</p>
          <h2>{prescription.exerciseName}</h2>
          <p className="muted">{prescription.sets} sets · {prescription.reps} reps · {prescription.restSeconds}s rest</p>
        </div>
        <IconButton
          label={`Remove ${prescription.exerciseName}`}
          tone="danger"
          onClick={() => confirm(`Remove ${prescription.exerciseName}?`) && dispatch({ type: "DELETE_PRESCRIPTION", prescriptionId: prescription.id })}
        ><Trash2 size={18} /></IconButton>
      </header>
      {recommendation && (
        <div className="recommendation"><TrendingUp size={17} /><span>Suggested working weight</span><strong>{formatWeight(recommendation)} lb</strong></div>
      )}
      <div className="set-table">
        <div className="set-table-head"><span>Set</span><span>Weight (lb)</span><span>Reps</span><span>RPE</span><span>Done</span></div>
        {logs.map((log) => {
          const previous = previousForSet(log.setNumber);
          return (
            <div className={log.isComplete ? "set-row complete" : "set-row"} key={log.id}>
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
    <Modal title="Create Custom Exercise" subtitle="Create the movement first. Programming is added separately." onClose={onClose}>
      <form className="stack-form" onSubmit={submit}>
        <label><span>Exercise name</span><input autoFocus value={name} onChange={(event) => setName(event.target.value)} placeholder="Exercise name" /></label>
        <Select label="Muscle group" value={bodyPart} options={["Chest", "Back", "Shoulders", "Arms", "Quads", "Hamstrings", "Glutes", "Core", "Full Body"]} onChange={setBodyPart} />
        <Select label="Equipment" value={equipment} options={["Barbell", "Dumbbells", "Cable", "Machine", "Bodyweight", "Kettlebell", "Bands", "Other"]} onChange={setEquipment} />
        <ChipField label="Tracking type" values={["Weight + Reps", "Reps Only", "Time"] as TrackingType[]} value={trackingType} onChange={setTrackingType} />
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
  const prescriptions = state.prescriptions.filter((item) => item.sessionId === session.id);
  const logs = state.setLogs.filter((log) => prescriptions.some((item) => item.id === log.prescriptionId) && log.isComplete);
  const completedExercises = new Set(logs.map((item) => item.prescriptionId)).size;
  const volume = logs.reduce((sum, log) => sum + (log.weight ?? 0) * (log.reps ?? 0), 0);
  const best = logs.reduce<typeof logs[number] | null>((result, log) => !result || (log.weight ?? 0) > (result.weight ?? 0) ? log : result, null);
  return (
    <Modal title="Finish Workout" subtitle={session.name} onClose={onClose}>
      <div className="summary-hero"><CheckCircle2 size={34} /><h2>Session complete</h2><p>{formatDuration(elapsed)} of focused training</p></div>
      <div className="summary-grid">
        <div><strong>{completedExercises}/{prescriptions.length}</strong><span>Exercises</span></div>
        <div><strong>{logs.length}</strong><span>Sets</span></div>
        <div><strong>{formatWeight(volume)}</strong><span>Volume lb</span></div>
        <div><strong>{best ? `${best.weight} × ${best.reps}` : "—"}</strong><span>Best set</span></div>
      </div>
      <ChipField label="Workout difficulty" values={[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]} value={effort} onChange={setEffort} />
      <label className="form-field"><span>Workout notes</span><textarea rows={3} value={notes} onChange={(event) => setNotes(event.target.value)} placeholder="Optional notes about the session" /></label>
      <label className="toggle-row"><input type="checkbox" checked={shared} onChange={(event) => setShared(event.target.checked)} /><span><strong>Share to Community</strong><small>Create a workout activity after saving.</small></span></label>
      <button className="primary-button large modal-primary" onClick={() => { dispatch({ type: "SAVE_WORKOUT_FEEDBACK", sessionId: session.id, effort, notes, shared }); if (shared) dispatch({ type: "CREATE_POST", post: { authorId: state.currentUserId, kind: "Workout", title: `${session.name} complete`, body: notes || `${logs.length} sets and ${formatWeight(volume)} lb of volume.`, linkedWorkoutId: session.id } }); onFinish(); }}><Check size={19} /> Save workout</button>
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
    <Card className="history-card">
      <span className="icon-tile green"><CheckCircle2 size={21} /></span>
      <div>
        <h3>{workout.name}</h3>
        <p className="muted">{new Date(workout.completedAt).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" })}</p>
      </div>
      <div className="history-metrics"><span><strong>{workout.totalSets}</strong> sets</span><span><strong>{formatWeight(workout.totalVolume)}</strong> lb</span><span><strong>{formatDuration(workout.durationSeconds)}</strong></span></div>
    </Card>
  );
}

function renderLeaderboardCell(entry: LeaderboardEntry, key: LeaderboardColumnKey): React.ReactNode {
  switch (key) {
    case "rank":
      return (
        <div className="leaderboard-rank-cell">
          <strong>#{entry.rank}</strong>
          <small className={entry.rankChange >= 0 ? "positive" : "negative"}>
            {entry.rankChange >= 0 ? <ArrowUpRight size={12} /> : <ArrowDownRight size={12} />}
            {Math.abs(entry.rankChange)}
          </small>
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
    case "verification":
      return <span className="status-chip">{entry.verification}</span>;
    case "trend":
      return (
        <span className={entry.rankChange >= 0 ? "trend-pill positive" : "trend-pill negative"}>
          {entry.rankChange >= 0 ? <ArrowUpRight size={12} /> : <ArrowDownRight size={12} />}
          {entry.rankChange >= 0 ? "+" : ""}
          {entry.rankChange}
        </span>
      );
  }
}

function LeaderboardFiltersDialog({
  currentFilters,
  onClose,
  onApply
}: {
  currentFilters: LeaderboardFiltersState;
  onClose: () => void;
  onApply: (filters: LeaderboardFiltersState) => void;
}) {
  const { state } = useTracker();
  const [draft, setDraft] = useState(currentFilters);
  const exerciseOptions = useMemo(() => withAllOption(state.liftSubmissions.map((lift) => lift.exerciseName)), [state.liftSubmissions]);
  const gymOptions = useMemo(() => withAllOption(state.gyms.map((gym) => gym.name)), [state.gyms]);
  const cityOptions = useMemo(() => withAllOption(state.gyms.map((gym) => `${gym.city}, ${gym.state}`)), [state.gyms]);
  const ageGroupOptions = useMemo(() => withAllOption(state.profiles.map((profile) => profile.ageGroup)), [state.profiles]);
  const experienceOptions = useMemo(() => withAllOption(state.profiles.map((profile) => profile.experienceLevel)), [state.profiles]);
  const weightClassOptions = useMemo(() => withAllOption(state.profiles.map((profile) => weightClassFor(profile.bodyweight, profile.sex))), [state.profiles]);

  useEffect(() => {
    setDraft((current) => ({
      ...current,
      exercise: exerciseOptions.includes(current.exercise) ? current.exercise : "All",
      gym: gymOptions.includes(current.gym) ? current.gym : "All",
      city: cityOptions.includes(current.city) ? current.city : "All",
      ageGroup: ageGroupOptions.includes(current.ageGroup) ? current.ageGroup : "All",
      experienceLevel: experienceOptions.includes(current.experienceLevel) ? current.experienceLevel : "All",
      weightClass: weightClassOptions.includes(current.weightClass) ? current.weightClass : "All"
    }));
  }, [ageGroupOptions, cityOptions, exerciseOptions, experienceOptions, gymOptions, weightClassOptions]);

  return (
    <Modal title="Filters" subtitle="Refine the leaderboard scope and ranking mode." onClose={onClose} size="large">
      <form
        className="leaderboard-dialog-form"
        onSubmit={(event) => {
          event.preventDefault();
          onApply(draft);
        }}
      >
        <div className="leaderboard-dialog-grid">
          <ChipField
            label="Ranking type"
            values={["Absolute", "Pound-for-pound", "Total", "Relative total", "Most improved"] as RankingType[]}
            value={draft.rankingType}
            onChange={(rankingType) =>
              setDraft((current) => ({
                ...current,
                rankingType,
                exercise: "All",
                gym: "All",
                city: "All",
                ageGroup: "All",
                experienceLevel: "All",
                weightClass: "All",
                repCount: null
              }))
            }
          />
          <ChipField
            label="Scope"
            values={["Global", "My gym", "My city", "My weight class", "Selected gym"] as LeaderboardScope[]}
            value={draft.scope}
            onChange={(scope) =>
              setDraft((current) => ({
                ...current,
                scope,
                exercise: "All",
                gym: "All",
                city: "All",
                ageGroup: "All",
                experienceLevel: "All",
                weightClass: "All",
                repCount: null
              }))
            }
          />
          <Select
            label="Verification"
            value={draft.verification}
            options={["All", "Self Reported", "Video Submitted", "Community Verified", "Moderator Verified", "Competition Verified"]}
            onChange={(verification) =>
              setDraft((current) => ({ ...current, verification: verification as LeaderboardFiltersState["verification"] }))
            }
          />
          <Select label="Exercise" value={draft.exercise} options={exerciseOptions} onChange={(exercise) => setDraft((current) => ({ ...current, exercise, rankingType: exercise === "All" ? (current.exercise === "All" ? current.rankingType : "Total") : (["Total", "Relative total"].includes(current.rankingType) ? "Absolute" : current.rankingType) }))} />
          <Select label="Gym" value={draft.gym} options={gymOptions} onChange={(gym) => setDraft((current) => ({ ...current, gym }))} />
          <Select label="City" value={draft.city} options={cityOptions} onChange={(city) => setDraft((current) => ({ ...current, city }))} />
          <Select label="Age group" value={draft.ageGroup} options={ageGroupOptions} onChange={(ageGroup) => setDraft((current) => ({ ...current, ageGroup }))} />
          <Select
            label="Experience"
            value={draft.experienceLevel}
            options={experienceOptions}
            onChange={(experienceLevel) => setDraft((current) => ({ ...current, experienceLevel }))}
          />
          <Select label="Weight class" value={draft.weightClass} options={weightClassOptions} onChange={(weightClass) => setDraft((current) => ({ ...current, weightClass }))} />
          {draft.exercise !== "All" && <Select label="Repetitions" value={draft.repCount?.toString() ?? "All"} options={["All", "1", "3", "5", "8", "10"]} onChange={(repetitions) => setDraft((current) => ({ ...current, repCount: repetitions === "All" ? null : Number(repetitions) }))} />}
        </div>
        <div className="dialog-actions dialog-actions-spread">
          <button
            type="button"
            className="quiet-button"
            onClick={() => setDraft(defaultLeaderboardFilters)}
          >
            Reset
          </button>
          <button className="primary-button" type="submit">
            Apply filters
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

function ChipField<T extends string | number>({ label, values, value, onChange, format = String }: { label: string; values: readonly T[]; value: T; onChange: (value: T) => void; format?: (value: T) => string }) {
  return <fieldset className="chip-field"><legend>{label}</legend><div>{values.map((item) => <button type="button" className={item === value ? "active" : ""} key={item} onClick={() => onChange(item)}>{format(item)}</button>)}</div></fieldset>;
}

function Modal({ title, subtitle, children, onClose, size = "normal" }: PropsWithChildren<{ title: string; subtitle?: string; onClose: () => void; size?: "normal" | "large" }>) {
  useEffect(() => {
    const handler = (event: KeyboardEvent) => event.key === "Escape" && onClose();
    document.addEventListener("keydown", handler);
    return () => document.removeEventListener("keydown", handler);
  }, [onClose]);
  return (
    <div className="modal-backdrop" role="presentation" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section className={`modal ${size}`} role="dialog" aria-modal="true" aria-labelledby="modal-title">
        <header><div><h2 id="modal-title">{title}</h2>{subtitle && <p>{subtitle}</p>}</div><IconButton label="Close" onClick={onClose}><X size={20} /></IconButton></header>
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

function leaderboardRankingLabel(rankingType: RankingType): string {
  switch (rankingType) {
    case "Absolute":
      return "Top lift";
    case "Pound-for-pound":
      return "Top relative lift";
    case "Total":
      return "Top total";
    case "Relative total":
      return "Top relative total";
    case "Most improved":
      return "Biggest improvement";
  }
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

function leaderboardRankingDescription(rankingType: RankingType): string {
  switch (rankingType) {
    case "Absolute":
      return "absolute ranking";
    case "Pound-for-pound":
      return "pound-for-pound ranking";
    case "Total":
      return "total ranking";
    case "Relative total":
      return "relative total ranking";
    case "Most improved":
      return "most improved ranking";
  }
}

function withAllOption(values: string[]): string[] {
  return ["All", ...[...new Set(values)].sort((left, right) => left.localeCompare(right))];
}

function leaderboardColumnWidth(key: LeaderboardColumnKey): string {
  switch (key) {
    case "rank":
      return "88px";
    case "athlete":
      return "minmax(210px, 1.5fr)";
    case "exercise":
      return "minmax(180px, 1.2fr)";
    case "gym":
      return "minmax(190px, 1.35fr)";
    case "score":
      return "128px";
    case "verification":
      return "160px";
    case "trend":
      return "96px";
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
