import {
  ArrowBigDown,
  ArrowBigUp,
  Building2,
  Check,
  ChevronRight,
  Dumbbell,
  Flag,
  Heart,
  Mail,
  MapPin,
  MessageCircle,
  MoreHorizontal,
  Plus,
  Save,
  Search,
  Send,
  Settings,
  ShieldCheck,
  Trash2,
  Trophy,
  UserPlus,
  Users,
  Weight,
  X
} from "lucide-react";
import { type FormEvent, type PropsWithChildren, useEffect, useMemo, useState } from "react";
import { Link, Navigate, useNavigate, useParams } from "react-router-dom";
import { makeId } from "./lib";
import {
  areFriends,
  computedLeaderboardEntries,
  currentProfile,
  dotsScore,
  formatRelativeTime,
  gymFor,
  kilogramsToPounds,
  nextLocalMidnight,
  plateLoadTotal,
  primaryMuscleForExercise,
  secondaryMusclesForExercise,
  weightClassFor
} from "./platform";
import { useTracker } from "./store";
import { BodyRegionGlyph } from "./ExerciseVisual";
import { DemoDataNotice } from "./DemoExperience";
export { BodyRegionGlyph, muscleVisualKey } from "./ExerciseVisual";
import type {
  CommunityPost,
  EquipmentType,
  Exercise,
  LiftVisibility,
  MessageReportReason,
  UserProfile,
  VerificationLevel
} from "./types";

const primaryLifts = ["Back Squat", "Barbell Bench Press", "Conventional Deadlift", "Overhead Press"];

function PageHeader({ eyebrow, title, description, action }: { eyebrow: string; title: string; description: string; action?: React.ReactNode }) {
  return <header className="page-header"><div><p className="eyebrow">{eyebrow}</p><h1>{title}</h1><p>{description}</p></div>{action}</header>;
}

function Card({ children, className = "" }: PropsWithChildren<{ className?: string }>) {
  return <div className={`card ${className}`}>{children}</div>;
}

function Avatar({ profile, size = "normal" }: { profile: UserProfile; size?: "normal" | "large" }) {
  return <span className={`social-avatar ${size}`}>{profile.displayName.split(" ").map((part) => part[0]).join("").slice(0, 2)}</span>;
}

function BubbleGroup<T extends string | number>({ label, values, value, onChange, format = String }: { label: string; values: readonly T[]; value: T; onChange: (value: T) => void; format?: (value: T) => string }) {
  return <fieldset className="bubble-group"><legend>{label}</legend><div>{values.map((item) => <button type="button" key={item} className={item === value ? "filter-chip active" : "filter-chip"} onClick={() => onChange(item)}>{format(item)}</button>)}</div></fieldset>;
}

export function SubmitLiftPage() {
  const { state, dispatch } = useTracker();
  useEffect(() => { document.documentElement.scrollTop = 0; document.body.scrollTop = 0; }, []);
  const profile = currentProfile(state);
  const available = state.exercises.filter((exercise) => primaryLifts.includes(exercise.name));
  const [exerciseId, setExerciseId] = useState(available.find((item) => item.id === "deadlift")?.id ?? available[0]?.id ?? "");
  const [unit, setUnit] = useState(profile.unitSystem);
  const [weight, setWeight] = useState("");
  const [reps, setReps] = useState(1);
  const [performedAt, setPerformedAt] = useState(new Date().toISOString().slice(0, 10));
  const [gymId, setGymId] = useState(state.joinedGymIds[0] ?? profile.primaryGymId);
  const [equipment, setEquipment] = useState<EquipmentType>("Raw");
  const [visibility, setVisibility] = useState<LiftVisibility>("Public");
  const [verification, setVerification] = useState<VerificationLevel>("Video Submitted");
  const [caption, setCaption] = useState("");
  const [barWeight, setBarWeight] = useState(45);
  const [plates, setPlates] = useState([45, 25, 10, 5, 2.5].map((plate) => ({ weight: plate, count: 0 })));
  const [submitted, setSubmitted] = useState(false);
  const exercise = state.exercises.find((item) => item.id === exerciseId);
  const joinedGyms = state.gyms.filter((gym) => state.joinedGymIds.includes(gym.id));
  const loadedWeight = plateLoadTotal(barWeight, plates);

  const submit = (event: FormEvent) => {
    event.preventDefault();
    const entered = Number(weight);
    if (!exercise || entered <= 0 || !state.joinedGymIds.includes(gymId)) return;
    dispatch({
      type: "SUBMIT_LIFT",
      lift: {
        userId: profile.id,
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        weight: entered,
        unit,
        normalizedWeight: unit === "kg" ? kilogramsToPounds(entered) : entered,
        reps,
        bodyweight: profile.bodyweight,
        performedAt: new Date(`${performedAt}T12:00:00`).toISOString(),
        gymId,
        equipment,
        visibility,
        verification,
        caption: caption.trim(),
        plateLoad: { barWeight, platesPerSide: plates }
      }
    });
    setSubmitted(true);
  };

  if (submitted) return (
    <div className="page narrow-page">
      <Card className="success-panel"><span className="success-icon"><Check /></span><h1>Lift submitted</h1><p>Your submission is saved locally and becomes leaderboard-eligible at {new Date(nextLocalMidnight()).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}.</p><div className="button-row"><Link className="primary-button" to="/profile">View profile</Link><button className="quiet-button" onClick={() => { setSubmitted(false); setWeight(""); }}>Submit another</button></div></Card>
    </div>
  );

  return (
    <div className="page narrow-page">
      <PageHeader eyebrow="Competition" title="Submit a lift" description="Log the performance first. Rankings update from eligible submissions at the next daily snapshot." />
      <DemoDataNotice>This submission updates only your browser-local demo rankings and profile.</DemoDataNotice>
      <form className="submission-form" onSubmit={submit}>
        <Card>
          <BubbleGroup label="Exercise" values={available.map((item) => item.id)} value={exerciseId} onChange={setExerciseId} format={(id) => state.exercises.find((item) => item.id === id)?.name ?? id} />
          <label className="form-field"><span>Date performed</span><input type="date" value={performedAt} onChange={(event) => setPerformedAt(event.target.value)} /></label>
          <BubbleGroup label="Weight unit" values={["lb", "kg"] as const} value={unit} onChange={setUnit} />
          <label className="form-field"><span>Weight lifted</span><input required inputMode="decimal" type="number" min="1" step="0.5" value={weight} onChange={(event) => setWeight(event.target.value)} placeholder={`Enter ${unit}`} /></label>
          <BubbleGroup label="Repetitions" values={[1, 3, 5, 8, 10]} value={reps} onChange={setReps} />
          <BubbleGroup label="Equipment" values={["Raw", "Wraps", "Equipped"] as const} value={equipment} onChange={setEquipment} />
          <BubbleGroup label="Visibility" values={["Public", "Friends", "Private"] as const} value={visibility} onChange={setVisibility} />
          <BubbleGroup label="Verification" values={["Self Reported", "Video Submitted"] as VerificationLevel[]} value={verification} onChange={setVerification} />
        </Card>

        <Card>
          <div className="section-title"><div><p className="eyebrow">Plate loading</p><h2>{loadedWeight} lb loaded</h2></div><button type="button" className="text-button" onClick={() => setWeight(String(loadedWeight))}>Use total</button></div>
          <label className="form-field compact-field"><span>Bar weight</span><input type="number" min="0" step="5" value={barWeight} onChange={(event) => setBarWeight(Number(event.target.value))} /></label>
          <div className="plate-grid">
            {plates.map((plate, index) => <label key={plate.weight}><span>{plate.weight} lb / side</span><input aria-label={`${plate.weight} pound plates per side`} type="number" min="0" max="10" value={plate.count} onChange={(event) => setPlates((current) => current.map((item, itemIndex) => itemIndex === index ? { ...item, count: Math.max(0, Number(event.target.value)) } : item))} /></label>)}
          </div>
        </Card>

        <Card>
          <label className="form-field"><span>Gym</span><select value={gymId} onChange={(event) => setGymId(event.target.value)}>{joinedGyms.map((gym) => <option key={gym.id} value={gym.id}>{gym.name}</option>)}</select></label>
          <label className="form-field"><span>Caption</span><textarea rows={3} value={caption} onChange={(event) => setCaption(event.target.value)} placeholder="Optional context about the lift" /></label>
          <p className="form-note"><ShieldCheck size={16} /> Only gyms you joined are available. Video submissions remain pending in this local prototype.</p>
        </Card>
        <div className="submit-action-bar">
          <div><strong>{exercise?.name ?? "Select an exercise"}</strong><small>{weight ? `${weight} ${unit}` : `Enter weight`} · {reps} {reps === 1 ? "rep" : "reps"} · {visibility}</small></div>
          <button className="primary-button large" type="submit" disabled={!exercise || Number(weight) <= 0}>Submit lift</button>
        </div>
      </form>
    </div>
  );
}

export function GymsPage() {
  const pageSize = 50;
  const { state, dispatch, gymCatalogStatus, gymCatalogError, ensureGymCatalog } = useTracker();
  const [query, setQuery] = useState("");
  const [brand, setBrand] = useState("All");
  const [stateFilter, setStateFilter] = useState("All");
  const [pageNumber, setPageNumber] = useState(1);
  useEffect(() => { void ensureGymCatalog(); }, [ensureGymCatalog]);
  const brands = useMemo(() => ["All", ...Array.from(new Set(state.gyms.map((gym) => gym.brand))).sort()], [state.gyms]);
  const states = useMemo(() => ["All", ...Array.from(new Set(state.gyms.map((gym) => gym.state))).sort()], [state.gyms]);
  const normalizedQuery = query.trim().toLowerCase();
  const filtered = useMemo(() => [...state.gyms]
    .filter((gym) =>
      (brand === "All" || gym.brand === brand) &&
      (stateFilter === "All" || gym.state === stateFilter) &&
      `${gym.brand} ${gym.name} ${gym.address} ${gym.city} ${gym.state} ${gym.postalCode}`.toLowerCase().includes(normalizedQuery)
    )
    .sort((a, b) => a.state.localeCompare(b.state) || a.city.localeCompare(b.city) || a.brand.localeCompare(b.brand) || a.name.localeCompare(b.name)), [brand, normalizedQuery, state.gyms, stateFilter]);
  const pageCount = Math.max(1, Math.ceil(filtered.length / pageSize));
  const currentPage = Math.min(pageNumber, pageCount);
  const pageStart = (currentPage - 1) * pageSize;
  const visibleGyms = filtered.slice(pageStart, pageStart + pageSize);
  const profile = currentProfile(state);
  const clearFilters = () => { setQuery(""); setBrand("All"); setStateFilter("All"); setPageNumber(1); };
  if (gymCatalogStatus !== "ready") return <div className="page"><PageHeader eyebrow="Official directory" title="Gyms" description="Verified chain locations for memberships, submissions, and gym rankings." /><Card className="catalog-loading" aria-live="polite">{gymCatalogStatus === "error" ? <><h2>Gym directory unavailable</h2><p>{gymCatalogError ?? "Unable to load the gym directory."}</p><button className="primary-button compact" onClick={() => void ensureGymCatalog()}>Try again</button></> : <><span className="loading-spinner" aria-hidden /><h2>Loading gym directory</h2><p>Preparing the complete official location catalog…</p></>}</Card></div>;
  return (
    <div className="page">
      <PageHeader eyebrow="Official directory" title="Gyms" description="Verified chain locations for memberships, submissions, and gym rankings." action={<span className="status-chip">{state.joinedGymIds.length}/3 joined</span>} />
      <DemoDataNotice>Joining or leaving a gym changes only this browser’s seeded membership list.</DemoDataNotice>
      <div className="gym-directory-toolbar">
        <label className="search-field"><Search size={19} /><input aria-label="Search gyms" value={query} onChange={(event) => { setQuery(event.target.value); setPageNumber(1); }} placeholder="Search gym, address, city, state, or ZIP..." /></label>
        <label className="filter-field"><span>Brand</span><select aria-label="Brand" value={brand} onChange={(event) => { setBrand(event.target.value); setPageNumber(1); }}>{brands.map((item) => <option key={item}>{item}</option>)}</select></label>
        <label className="filter-field"><span>State</span><select aria-label="State" value={stateFilter} onChange={(event) => { setStateFilter(event.target.value); setPageNumber(1); }}>{states.map((item) => <option key={item}>{item}</option>)}</select></label>
        {(query || brand !== "All" || stateFilter !== "All") && <button className="text-button" onClick={clearFilters}>Clear filters</button>}
      </div>
      <div className="directory-summary"><p className="directory-count">{filtered.length ? `Showing ${pageStart + 1}–${Math.min(pageStart + pageSize, filtered.length)} of ${filtered.length} gyms` : "0 gyms"}</p>{filtered.length > pageSize && <span>Page {currentPage} of {pageCount}</span>}</div>
      <div className="object-list gym-list">
        {visibleGyms.map((gym) => {
          const joined = state.joinedGymIds.includes(gym.id);
          const primary = profile.primaryGymId === gym.id;
          const hasDemoMetrics = gym.memberCount !== undefined && gym.verifiedLiftCount !== undefined;
          return <Card key={gym.id} className="object-row"><span className="icon-tile blue"><Building2 /></span><div className="object-copy"><Link to={`/gyms/${gym.id}`}>{gym.name}</Link><p className="gym-brand">{gym.brand}</p><p><MapPin size={14} /> {gym.address}, {gym.city}, {gym.state} {gym.postalCode}</p><small>{hasDemoMetrics ? `LiftRank demo: ${gym.memberCount} members · ${gym.verifiedLiftCount} verified lifts` : "No LiftRank activity yet"}</small></div><button className={joined ? "quiet-button" : "primary-button compact"} disabled={primary || (!joined && state.joinedGymIds.length >= 3)} onClick={() => dispatch({ type: joined ? "LEAVE_GYM" : "JOIN_GYM", gymId: gym.id })}>{primary ? "Primary" : joined ? "Leave" : "Join"}</button></Card>;
        })}
        {!filtered.length && <Card className="empty-state"><h2>No gyms found</h2><p>Try another brand, state, or search phrase.</p></Card>}
      </div>
      {filtered.length > pageSize && <nav className="directory-pagination" aria-label="Gym results pages"><button className="quiet-button compact" disabled={currentPage === 1} onClick={() => setPageNumber((page) => Math.max(1, page - 1))}>Previous</button><span>Page {currentPage} of {pageCount}</span><button className="quiet-button compact" disabled={currentPage === pageCount} onClick={() => setPageNumber((page) => Math.min(pageCount, page + 1))}>Next</button></nav>}
    </div>
  );
}

export function GymDetailPage() {
  const { gymId } = useParams();
  const { state, dispatch, gymCatalogStatus, gymCatalogError, ensureGymCatalog } = useTracker();
  useEffect(() => { void ensureGymCatalog(); }, [ensureGymCatalog]);
  const gym = state.gyms.find((item) => item.id === gymId);
  if (!gym && gymCatalogStatus !== "ready") return <div className="page"><Card className="catalog-loading" aria-live="polite">{gymCatalogStatus === "error" ? <><h2>Gym unavailable</h2><p>{gymCatalogError ?? "Unable to load this gym."}</p><button className="primary-button compact" onClick={() => void ensureGymCatalog()}>Try again</button></> : <><span className="loading-spinner" aria-hidden /><h2>Loading gym</h2></>}</Card></div>;
  if (!gym) return <Navigate to="/gyms" replace />;
  const profile = currentProfile(state);
  const joined = state.joinedGymIds.includes(gym.id);
  const entries = computedLeaderboardEntries(state, { rankingType: "Total", scope: "Selected gym", verification: "All", exercise: "All", gym: gym.name, city: "All", ageGroup: "All", experienceLevel: "All", weightClass: "All", repCount: null });
  return (
    <div className="page">
      <PageHeader
        eyebrow={gym.brand}
        title={gym.name}
        description={`${gym.address}, ${gym.city}, ${gym.state} ${gym.postalCode}`}
        action={<button className={joined ? "quiet-button" : "primary-button"} disabled={profile.primaryGymId === gym.id || (!joined && state.joinedGymIds.length >= 3)} onClick={() => dispatch({ type: joined ? "LEAVE_GYM" : "JOIN_GYM", gymId: gym.id })}>{profile.primaryGymId === gym.id ? "Primary gym" : joined ? "Leave gym" : "Join gym"}</button>}
      />
      <div className="stat-grid compact-stats">
        <Card><strong>{gym.memberCount ?? "—"}</strong><span>{gym.memberCount === undefined ? "No member data" : "LiftRank demo members"}</span></Card>
        <Card><strong>{gym.verifiedLiftCount ?? "—"}</strong><span>{gym.verifiedLiftCount === undefined ? "No lift data" : "Demo verified lifts"}</span></Card>
        <Card><strong>{entries.length}</strong><span>Ranked lifters</span></Card>
      </div>
      <Card><a className="text-button" href={gym.officialUrl} target="_blank" rel="noreferrer">Official site</a></Card>
      <Card>
        <div className="section-title"><h2>Gym leaderboard</h2><Link to="/leaderboards">Full leaderboard</Link></div>
        <div className="compact-ranking-list">{entries.slice(0, 10).map((entry) => <Link to={`/profile/${entry.userId}`} key={entry.id}><b>#{entry.rank}</b><span>{entry.athlete}</span><strong>{entry.total.toLocaleString()} lb</strong></Link>)}{!entries.length && <p className="muted">No eligible totals at this gym yet.</p>}</div>
      </Card>
    </div>
  );
}

function FriendAction({ profile }: { profile: UserProfile }) {
  const { state, dispatch } = useTracker();
  if (profile.id === state.currentUserId) return null;
  const request = state.friendRequests.find((item) => item.status !== "Declined" && ((item.senderId === state.currentUserId && item.recipientId === profile.id) || (item.senderId === profile.id && item.recipientId === state.currentUserId)));
  if (request?.status === "Accepted") return <Link className="quiet-button compact" to={`/messages?user=${profile.id}`}><Mail size={16} /> Message</Link>;
  if (request?.status === "Pending" && request.senderId === state.currentUserId) return <button className="quiet-button compact" onClick={() => dispatch({ type: "CANCEL_FRIEND_REQUEST", requestId: request.id })}>Cancel request</button>;
  if (request?.status === "Pending") return <button className="primary-button compact" onClick={() => dispatch({ type: "RESPOND_FRIEND_REQUEST", requestId: request.id, status: "Accepted" })}>Accept</button>;
  return <button className="primary-button compact" onClick={() => dispatch({ type: "SEND_FRIEND_REQUEST", recipientId: profile.id })}><UserPlus size={16} /> Add friend</button>;
}

export function CommunityPage() {
  const { state, dispatch } = useTracker();
  const { groupId } = useParams();
  const navigate = useNavigate();
  const [feed, setFeed] = useState("Hot");
  const [category, setCategory] = useState("All");
  const [composer, setComposer] = useState(false);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [postGroup, setPostGroup] = useState(groupId ?? "group-general-strength");
  const [postKind, setPostKind] = useState<CommunityPost["kind"]>("Discussion");
  const [mediaUrl, setMediaUrl] = useState("");
  useEffect(() => { document.documentElement.scrollTop = 0; document.body.scrollTop = 0; }, [groupId]);
  const selectedGroup = state.trainingGroups.find((group) => group.id === groupId);
  const communityMemberIds = [...new Set(state.trainingGroups.flatMap((group) => group.memberIds))];
  const communityModeratorIds = [...new Set(state.trainingGroups.flatMap((group) => group.moderatorIds))];
  const memberCount = selectedGroup?.memberIds.length ?? communityMemberIds.length;
  const moderatorCount = selectedGroup?.moderatorIds.length ?? communityModeratorIds.length;
  const categories = ["All", "Question", "Form Check", "Program Review", "Progress", "Nutrition", "Equipment", "Personal Record", "Discussion"];
  const postScores = useMemo(() => new Map(state.communityPosts.map((post) => [post.id, Object.values(post.votes).reduce<number>((sum, vote) => sum + vote, 0)])), [state.communityPosts]);
  const commentCounts = useMemo(() => state.comments.reduce((counts, comment) => counts.set(comment.postId, (counts.get(comment.postId) ?? 0) + 1), new Map<string, number>()), [state.comments]);
  const score = (post: CommunityPost) => postScores.get(post.id) ?? 0;
  const posts = useMemo(() => [...state.communityPosts].filter((post) => post.kind !== "Workout" && !post.removedAt && (!groupId || post.groupId === groupId) && (category === "All" || post.kind === category) && (feed !== "Following" || state.joinedGroupIds.includes(post.groupId)) && (feed !== "Unanswered" || !(commentCounts.get(post.id) ?? 0))).sort((a, b) => feed === "Top" ? score(b) - score(a) : feed === "Hot" ? score(b) + (commentCounts.get(b.id) ?? 0) - score(a) - (commentCounts.get(a.id) ?? 0) : b.createdAt.localeCompare(a.createdAt)), [category, commentCounts, feed, groupId, postScores, state.communityPosts, state.joinedGroupIds]);
  const visibleGroups = state.trainingGroups.filter((group) => state.joinedGroupIds.includes(group.id) || group.id === groupId).slice(0, 5);
  const moderators = state.profiles.filter((profile) =>
    (selectedGroup?.moderatorIds ?? communityModeratorIds).includes(profile.id) || profile.role === "Admin"
  );
  const trending = useMemo(() => [...state.communityPosts].filter((post) => !post.removedAt && (!groupId || post.groupId === groupId)).sort((a, b) => score(b) + (commentCounts.get(b.id) ?? 0) - score(a) - (commentCounts.get(a.id) ?? 0)).slice(0, 3), [commentCounts, groupId, postScores, state.communityPosts]);
  const submit = (event: FormEvent) => { event.preventDefault(); const url = mediaUrl.trim(); if (!title.trim() || !body.trim() || (url && !url.startsWith("https://"))) return; const video = /youtube\.com|youtu\.be|vimeo\.com/i.test(url); dispatch({ type: "CREATE_POST", post: { authorId: state.currentUserId, groupId: postGroup, kind: postKind, title: title.trim(), body: body.trim(), exerciseTags: [], goalTags: [], ...(url ? { mediaUrl: url, mediaType: video ? "Video" as const : "Image" as const } : {}) } }); setTitle(""); setBody(""); setMediaUrl(""); setComposer(false); };
  return (
    <div className="page community-page">
      <section className="community-hero"><div className="group-emblem"><Dumbbell /></div><div className="community-hero-copy"><p className="eyebrow">Training Group</p><h1>{selectedGroup?.name ?? "Strength community"}</h1><p>{selectedGroup?.description ?? "Useful, searchable discussions for stronger training."}</p><div className="group-meta"><span>{memberCount} members</span><span>{moderatorCount} moderator{moderatorCount === 1 ? "" : "s"}</span><span>Strength training</span></div></div><div className="community-hero-actions">{selectedGroup && <button className="quiet-button" onClick={() => dispatch({ type: state.joinedGroupIds.includes(selectedGroup.id) ? "LEAVE_GROUP" : "JOIN_GROUP", groupId: selectedGroup.id })}>{state.joinedGroupIds.includes(selectedGroup.id) ? "Following" : "Join group"}</button>}<button className="primary-button" onClick={() => setComposer(true)}><Plus size={18} /> New post</button></div></section>
      <DemoDataNotice>Posts, comments, votes, reports, and group memberships stay in this browser.</DemoDataNotice>
      <div className="group-navigation"><nav className="group-strip" aria-label="Joined Training Groups">{visibleGroups.map((group) => <Link className={group.id === groupId ? "active" : ""} to={`/community/groups/${group.id}`} key={group.id}>{group.name}</Link>)}</nav><label className="browse-groups"><span>Browse groups</span><select aria-label="Browse all Training Groups" value={groupId ?? ""} onChange={(event) => navigate(`/community/groups/${event.target.value}`)}><option value="" disabled>All groups</option>{state.trainingGroups.map((group) => <option value={group.id} key={group.id}>{group.name}</option>)}</select></label></div>
      <div className="community-filter-row"><div className="tab-rail" aria-label="Discussion sorting">{["Hot", "New", "Top", "Unanswered", "Following"].map((item) => <button key={item} className={feed === item ? "active" : ""} aria-pressed={feed === item} onClick={() => setFeed(item)}>{item}</button>)}</div><label className="category-filter"><span>Category</span><select aria-label="Post category" value={category} onChange={(event) => setCategory(event.target.value)}>{categories.map((item) => <option key={item}>{item}</option>)}</select></label></div>
      <div className="feed-layout"><main className="feed-list">{posts.map((post) => <CommunityCard key={post.id} post={post} />)}{!posts.length && <Card className="empty-state community-empty"><div className="empty-icon"><MessageCircle /></div><h2>No {selectedGroup?.name ?? "community"} discussions match</h2><p>{category !== "All" || feed === "Unanswered" || feed === "Following" ? "Try clearing the current feed filters, or start a focused discussion." : "Be the first to ask about programming, form, or meet preparation."}</p><div className="button-row"><button className="primary-button compact" onClick={() => setComposer(true)}>Start a discussion</button>{(category !== "All" || feed !== "Hot") && <button className="quiet-button compact" onClick={() => { setCategory("All"); setFeed("Hot"); }}>Clear filters</button>}</div></Card>}</main><aside className="community-aside"><Card className="about-group-card"><h3>{selectedGroup ? "About this group" : "About the community"}</h3><div className="sidebar-stats"><span><strong>{memberCount}</strong><small>Members</small></span><span><strong>{moderatorCount}</strong><small>Moderators</small></span></div>{moderators.length > 0 && <div className="expert-list"><h4>Verified team</h4>{moderators.map((profile) => <Link to={`/profile/${profile.id}`} key={profile.id}><Avatar profile={profile} /><span><strong>{profile.displayName}</strong><small>{profile.professionalCredential ?? profile.role}</small></span><ShieldCheck size={17} /></Link>)}</div>}</Card>{trending.length > 0 && <Card><h3>Trending this week</h3><div className="trending-list">{trending.map((post) => <Link to={`/community/${post.id}`} key={post.id}><strong>{post.title}</strong><small>{score(post)} points · {state.comments.filter((comment) => comment.postId === post.id).length} comments</small></Link>)}</div></Card>}{selectedGroup && <Card className="rules-card"><h3>Community rules</h3><ol>{selectedGroup.rules.map((rule) => <li key={rule}>{rule}</li>)}</ol></Card>}<Card className="safety-notice"><ShieldCheck /><div><h3>Train responsibly</h3><p>Posts are personal experience, not medical advice. Report dangerous recommendations.</p>{currentProfile(state).role !== "Member" && <Link to="/community/moderation">Open moderator queue</Link>}</div></Card></aside></div>
      {composer && <div className="modal-backdrop"><div className="modal"><header><div><p className="eyebrow">Training Groups</p><h2>Start a discussion</h2></div><button aria-label="Close" className="icon-button" onClick={() => setComposer(false)}><X /></button></header><form className="stack-form" onSubmit={submit}><label><span>Group</span><select value={postGroup} onChange={(event) => setPostGroup(event.target.value)}>{state.trainingGroups.map((group) => <option value={group.id} key={group.id}>{group.name}</option>)}</select></label><label><span>Category</span><select value={postKind} onChange={(event) => setPostKind(event.target.value as CommunityPost["kind"])}>{categories.slice(1).map((item) => <option key={item}>{item}</option>)}</select></label><label><span>Title</span><input required value={title} onChange={(event) => setTitle(event.target.value)} /></label><label><span>Post</span><textarea required rows={5} value={body} onChange={(event) => setBody(event.target.value)} /></label><label><span>Optional HTTPS image or YouTube/Vimeo URL</span><input type="url" value={mediaUrl} onChange={(event) => setMediaUrl(event.target.value)} /></label><button className="primary-button" type="submit">Publish post</button></form></div></div>}
    </div>
  );
}

function CommunityCard({ post }: { post: CommunityPost }) {
  const { state, dispatch } = useTracker();
  const profile = state.profiles.find((item) => item.id === post.authorId)!;
  const group = state.trainingGroups.find((item) => item.id === post.groupId);
  const comments = state.comments.filter((item) => item.postId === post.id);
  const score = Object.values(post.votes).reduce<number>((sum, vote) => sum + vote, 0);
  const commentLabel = `${comments.length} ${comments.length === 1 ? "comment" : "comments"}`;
  return (
    <article className="feed-card discussion-card">
      <div className="vote-control">
        <button aria-label="Upvote" className={post.votes[state.currentUserId] === 1 ? "active" : ""} onClick={() => dispatch({ type: "VOTE_POST", postId: post.id, vote: 1 })}><ArrowBigUp /></button>
        <strong>{score}</strong>
        <button aria-label="Downvote" className={post.votes[state.currentUserId] === -1 ? "active" : ""} onClick={() => dispatch({ type: "VOTE_POST", postId: post.id, vote: -1 })}><ArrowBigDown /></button>
      </div>
      <div className="discussion-content">
        <header><Link to={`/profile/${profile.id}`}><Avatar profile={profile} /><span><strong>{profile.displayName}{profile.credentialVerified ? " ✓" : ""}</strong><small>{profile.experienceLevel} · {formatRelativeTime(post.createdAt)}</small></span></Link></header>
        <Link className="feed-copy" to={`/community/${post.id}`}><small>{group?.name} · {post.kind}</small><h2>{post.title}</h2><p>{post.body}</p></Link>
        <div className="post-tags">{[...post.exerciseTags, ...post.goalTags].map((tag) => <span key={tag}>{tag}</span>)}</div>
        {post.mediaUrl && (post.mediaType === "Image" ? <img className="post-media" src={post.mediaUrl} alt={`${post.title} media`} /> : <a href={post.mediaUrl} target="_blank" rel="noreferrer">Watch form-check video</a>)}
        <footer>
          <Link aria-label={`View ${commentLabel}`} to={`/community/${post.id}`}><MessageCircle size={17} /> {commentLabel}</Link>
          <button aria-label="Save post" className={post.savedBy.includes(state.currentUserId) ? "active" : ""} onClick={() => dispatch({ type: "TOGGLE_POST_SAVE", postId: post.id })}><Save size={17} /> Save</button>
          <button aria-label="Report post" onClick={() => dispatch({ type: "REPORT_COMMUNITY", targetType: "Post", targetId: post.id, reason: "Other" })}><Flag size={17} /> Report</button>
          {post.isLocked && <span>Locked</span>}
        </footer>
      </div>
    </article>
  );
}

export function CommunityPostPage() {
  const { postId } = useParams();
  const { state, dispatch } = useTracker();
  const [body, setBody] = useState("");
  const post = state.communityPosts.find((item) => item.id === postId && item.kind !== "Workout");
  if (!post) return <Navigate to="/community" replace />;
  const comments = state.comments.filter((item) => item.postId === post.id);
  const renderThread = (parentCommentId: string | undefined, depth = 0): React.ReactNode => comments.filter((comment) => comment.parentCommentId === parentCommentId).map((comment) => { const author = state.profiles.find((item) => item.id === comment.authorId)!; const score = Object.values(comment.votes).reduce<number>((sum, vote) => sum + vote, 0); return <div className="thread-comment" style={{ marginLeft: `${Math.min(depth, 4) * 18}px` }} key={comment.id}><Avatar profile={author} /><div><strong>{author.displayName}</strong><p>{comment.deletedAt ? "Comment deleted" : comment.body}</p><small>{formatRelativeTime(comment.createdAt)} · {score} points</small><div className="comment-actions"><button onClick={() => dispatch({ type: "VOTE_COMMENT", commentId: comment.id, vote: 1 })}>Upvote</button><button onClick={() => { const reply = prompt("Write a reply"); if (reply?.trim()) dispatch({ type: "ADD_COMMENT", comment: { postId: post.id, parentCommentId: comment.id, body: reply.trim() } }); }}>Reply</button>{comment.authorId === state.currentUserId && !comment.deletedAt && <><button onClick={() => { const edit = prompt("Edit comment", comment.body); if (edit?.trim()) dispatch({ type: "EDIT_COMMENT", commentId: comment.id, body: edit }); }}>Edit</button><button onClick={() => dispatch({ type: "DELETE_COMMENT", commentId: comment.id })}>Delete</button></>}</div>{renderThread(comment.id, depth + 1)}</div></div>; });
  return <div className="page narrow-page"><CommunityCard post={post} /><Card><h2>Comments</h2><div className="comment-list">{renderThread(undefined)}</div>{post.isLocked ? <p className="empty-inline">This discussion is locked.</p> : <form className="comment-form" onSubmit={(event) => { event.preventDefault(); if (!body.trim()) return; dispatch({ type: "ADD_COMMENT", comment: { postId: post.id, body: body.trim() } }); setBody(""); }}><input aria-label="Write a comment" value={body} onChange={(event) => setBody(event.target.value)} placeholder="Write a comment..." /><button className="primary-button compact"><Send size={17} /> Post</button></form>}</Card></div>;
}

export function CommunityModerationPage() { const { state, dispatch } = useTracker(); const profile = currentProfile(state); if (profile.role === "Member") return <Navigate to="/community" replace />; const reports = state.communityReports.filter((report) => report.status === "Open"); return <div className="page"><PageHeader eyebrow="Safety" title="Moderator queue" description="Review local reports and apply group-scoped actions." /><div className="feed-list">{reports.map((report) => { const post = report.targetType === "Post" ? state.communityPosts.find((item) => item.id === report.targetId) : undefined; return <Card key={report.id}><span className="status-chip">{report.reason}</span><h2>{post?.title ?? "Reported comment"}</h2><p>{report.note || "No additional note."}</p><div className="button-row">{post && <><button className="quiet-button" onClick={() => dispatch({ type: "MODERATE_POST", postId: post.id, operation: post.isLocked ? "unlock" : "lock" })}>{post.isLocked ? "Unlock" : "Lock"}</button><button className="quiet-button" onClick={() => dispatch({ type: "MODERATE_POST", postId: post.id, operation: "remove", reason: report.reason })}>Remove</button></>}<button className="primary-button compact" onClick={() => dispatch({ type: "RESOLVE_COMMUNITY_REPORT", reportId: report.id })}>Resolve</button></div></Card>; })}{!reports.length && <Card className="empty-state"><h2>Queue clear</h2><p>No open community reports.</p></Card>}</div></div>; }

export function FriendsPage() {
  const { state, dispatch } = useTracker();
  const incoming = state.friendRequests.filter((item) => item.recipientId === state.currentUserId && item.status === "Pending");
  const outgoing = state.friendRequests.filter((item) => item.senderId === state.currentUserId && item.status === "Pending");
  const friends = state.profiles.filter((profile) => profile.id !== state.currentUserId && areFriends(state, state.currentUserId, profile.id));
  return <div className="page"><PageHeader eyebrow="Connections" title="Friends" description="Manage requests and start conversations with accepted friends." /><div className="social-columns"><section><h2>Incoming requests</h2>{incoming.map((request) => { const profile = state.profiles.find((item) => item.id === request.senderId)!; return <Card key={request.id} className="person-row"><Avatar profile={profile} /><div><Link to={`/profile/${profile.id}`}>{profile.displayName}</Link><small>{profile.handle}</small></div><div className="button-row"><button className="primary-button compact" onClick={() => dispatch({ type: "RESPOND_FRIEND_REQUEST", requestId: request.id, status: "Accepted" })}>Accept</button><button className="quiet-button compact" onClick={() => dispatch({ type: "RESPOND_FRIEND_REQUEST", requestId: request.id, status: "Declined" })}>Decline</button></div></Card>; })}{!incoming.length && <p className="empty-inline">No incoming requests.</p>}</section><section><h2>Sent requests</h2>{outgoing.map((request) => { const profile = state.profiles.find((item) => item.id === request.recipientId)!; return <Card key={request.id} className="person-row"><Avatar profile={profile} /><div><Link to={`/profile/${profile.id}`}>{profile.displayName}</Link><small>Pending</small></div><button className="quiet-button compact" onClick={() => dispatch({ type: "CANCEL_FRIEND_REQUEST", requestId: request.id })}>Cancel</button></Card>; })}{!outgoing.length && <p className="empty-inline">No pending requests.</p>}</section></div><section><h2>Your friends</h2><div className="person-grid">{friends.map((profile) => <Card key={profile.id} className="person-row"><Avatar profile={profile} /><div><Link to={`/profile/${profile.id}`}>{profile.displayName}</Link><small>{profile.handle}</small></div><Link className="quiet-button compact" to={`/messages?user=${profile.id}`}><Mail size={16} /> Message</Link></Card>)}</div></section></div>;
}

export function MessagesPage() {
  const { state } = useTracker();
  const query = new URLSearchParams(location.hash.split("?")[1] ?? "");
  const targetId = query.get("user");
  const threads = [...state.messageThreads].filter((thread) => thread.participantIds.includes(state.currentUserId)).sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  if (targetId) {
    const existing = threads.find((thread) => thread.participantIds.includes(targetId));
    if (existing) return <Navigate to={`/messages/${existing.id}`} replace />;
    return <NewConversation recipientId={targetId} />;
  }
  return <div className="page"><PageHeader eyebrow="Direct messages" title="Messages" description="Private conversations with accepted friends." action={<Link className="quiet-button" to="/friends"><Users size={17} /> Friends</Link>} /><DemoDataNotice>These seeded conversations and anything you type remain only in this browser.</DemoDataNotice><div className="inbox-list">{threads.map((thread) => { const otherId = thread.participantIds.find((id) => id !== state.currentUserId)!; const profile = state.profiles.find((item) => item.id === otherId)!; const last = state.messages.filter((message) => message.threadId === thread.id).at(-1); return <Link className="inbox-row" to={`/messages/${thread.id}`} key={thread.id}><Avatar profile={profile} /><span><strong>{profile.displayName}</strong><small>{last?.body ?? "Start the conversation"}</small></span><time>{formatRelativeTime(last?.createdAt ?? thread.updatedAt)}</time><ChevronRight /></Link>; })}{!threads.length && <p className="empty-inline">No conversations yet.</p>}</div></div>;
}

function NewConversation({ recipientId }: { recipientId: string }) {
  const { state, dispatch } = useTracker();
  const navigate = useNavigate();
  const profile = state.profiles.find((item) => item.id === recipientId);
  const [body, setBody] = useState("");
  if (!profile || !areFriends(state, state.currentUserId, profile.id)) return <Navigate to="/messages" replace />;
  return <div className="page narrow-page"><PageHeader eyebrow="New message" title={profile.displayName} description="Send the first message to create this conversation." /><form className="message-composer-card" onSubmit={(event) => { event.preventDefault(); if (!body.trim()) return; dispatch({ type: "SEND_MESSAGE", recipientId, body }); const id = state.messageThreads.find((thread) => thread.participantIds.includes(recipientId))?.id; setTimeout(() => navigate(id ? `/messages/${id}` : "/messages"), 0); }}><textarea aria-label="Message" rows={5} value={body} onChange={(event) => setBody(event.target.value)} placeholder="Write a message..." /><button className="primary-button">Send message</button></form></div>;
}

export function MessageThreadPage() {
  const { threadId } = useParams();
  const { state, dispatch } = useTracker();
  const navigate = useNavigate();
  const [body, setBody] = useState("");
  const [reporting, setReporting] = useState<string | null>(null);
  const thread = state.messageThreads.find((item) => item.id === threadId);
  if (!thread) return <Navigate to="/messages" replace />;
  const otherId = thread.participantIds.find((id) => id !== state.currentUserId)!;
  const profile = state.profiles.find((item) => item.id === otherId)!;
  const messages = state.messages.filter((message) => message.threadId === thread.id);
  return <div className="conversation-page"><header><Link to="/messages">Messages</Link><div><Avatar profile={profile} /><span><strong>{profile.displayName}</strong><small>{profile.handle}</small></span></div><button className="icon-button danger" aria-label="Delete conversation" onClick={() => { if (confirm("Delete this conversation?")) { dispatch({ type: "DELETE_MESSAGE_THREAD", threadId: thread.id }); navigate("/messages"); } }}><Trash2 /></button></header><main>{messages.map((message) => <div key={message.id} className={message.senderId === state.currentUserId ? "message-bubble own" : "message-bubble"}><p>{message.body}</p><small>{formatRelativeTime(message.createdAt)}</small><div className="message-actions"><button onClick={() => dispatch({ type: "DELETE_MESSAGE", messageId: message.id })}>Delete</button>{message.senderId !== state.currentUserId && <button onClick={() => setReporting(message.id)}>Report</button>}</div>{message.isReported && <span className="reported-label">Reported</span>}</div>)}</main><form onSubmit={(event) => { event.preventDefault(); if (!body.trim()) return; dispatch({ type: "SEND_MESSAGE", recipientId: otherId, body }); setBody(""); }}><textarea aria-label="Message" rows={1} value={body} onChange={(event) => setBody(event.target.value)} placeholder="Write a message..." /><button aria-label="Send message" className="primary-button compact"><Send size={18} /></button></form>{reporting && <ReportMessageModal messageId={reporting} onClose={() => setReporting(null)} />}</div>;
}

function ReportMessageModal({ messageId, onClose }: { messageId: string; onClose: () => void }) {
  const { dispatch } = useTracker();
  const [reason, setReason] = useState<MessageReportReason>("Spam");
  const [note, setNote] = useState("");
  return <div className="modal-backdrop"><div className="modal"><header><h2>Report message</h2><button aria-label="Close report dialog" className="icon-button" onClick={onClose}><X /></button></header><BubbleGroup label="Reason" values={["Spam", "Offensive", "Harassment", "Other"] as MessageReportReason[]} value={reason} onChange={setReason} /><label className="form-field"><span>Optional note</span><textarea rows={3} value={note} onChange={(event) => setNote(event.target.value)} /></label><button className="primary-button" onClick={() => { dispatch({ type: "REPORT_MESSAGE", messageId, reason, note }); onClose(); }}>Submit report</button></div></div>;
}

export function PlatformProfilePage() {
  const { userId } = useParams();
  const { state } = useTracker();
  const profile = state.profiles.find((item) => item.id === (userId ?? state.currentUserId));
  if (!profile) return <Navigate to="/profile" replace />;
  const own = profile.id === state.currentUserId;
  const [tab, setTab] = useState("Overview");
  const gym = gymFor(state, profile.primaryGymId);
  const lifts = state.liftSubmissions.filter((lift) => lift.userId === profile.id && (own || lift.visibility === "Public")).sort((a, b) => b.normalizedWeight - a.normalizedWeight);
  const best = [...new Map(lifts.map((lift) => [lift.exerciseId, lift])).values()].slice(0, 6);
  const total = ["back-squat", "barbell-bench", "deadlift"].reduce((sum, id) => sum + (lifts.filter((lift) => lift.exerciseId === id && lift.reps === 1).sort((a, b) => b.normalizedWeight - a.normalizedWeight)[0]?.normalizedWeight ?? 0), 0);
  const dots = dotsScore(total, profile.bodyweight, profile.sex);
  const achievements = [
    { title: "Total on file", detail: `${total.toLocaleString()} lb across the big three`, unlocked: total > 0 },
    { title: "Verified lifter", detail: "At least one reviewed submission", unlocked: best.some((lift) => !["Self Reported", "Video Submitted"].includes(lift.verification)) },
    { title: "Community member", detail: "Shared with the LiftRank community", unlocked: state.communityPosts.some((post) => post.authorId === profile.id && post.kind !== "Workout") }
  ];
  return (
    <div className="page">
      <section className="profile-hero">
        <Avatar profile={profile} size="large" />
        <div className="profile-hero-copy">
          <p className="eyebrow">Lifter profile</p><h1>{profile.displayName}</h1>
          <p>{profile.handle} · {profile.discipline} · {profile.experienceLevel}{profile.credentialVerified ? " · Verified professional" : ""}</p>
          <div className="profile-chip-row"><span className="status-chip">{weightClassFor(profile.bodyweight, profile.sex)} weight class</span><span className="status-chip">{profile.yearsTraining} years training</span>{!profile.hideGym && gym && <Link className="status-chip" to={`/gyms/${gym.id}`}>{gym.name}</Link>}{!profile.hideLocation && <span className="status-chip">{profile.city}, {profile.state}</span>}</div>
        </div>
        <div className="profile-hero-actions">{own ? <Link className="primary-button" to="/settings"><Settings size={18} /> Edit profile</Link> : <FriendAction profile={profile} />}</div>
      </section>
      <nav className="profile-tabs" aria-label="Profile sections">{["Overview", "Lifts", "Progress", "Posts", "Achievements"].map((item) => <button className={tab === item ? "active" : ""} key={item} onClick={() => setTab(item)}>{item}</button>)}</nav>
      <div className="stat-grid"><Card><strong>{total.toLocaleString()} lb</strong><span>Verified three-lift total</span></Card><Card><strong>{profile.bodyweight} lb</strong><span>Bodyweight</span></Card><Card><strong>{dots || "—"}</strong><span>DOTS score</span></Card><Card><strong>{best.filter((lift) => !["Self Reported", "Video Submitted"].includes(lift.verification)).length}</strong><span>Verified lifts</span></Card></div>
      <div className="profile-layout">
        <section className="profile-main">
          {(tab === "Overview" || tab === "Lifts") && <Card><div className="section-title"><h2>{tab === "Lifts" ? "Lift submissions" : "Strength snapshot"}</h2>{own && <Link to="/submit">Submit lift</Link>}</div><div className="profile-list">{(tab === "Lifts" ? lifts : best).map((lift) => <div className="profile-list-row" key={lift.id}><span className="icon-tile"><Trophy /></span><div><strong>{lift.exerciseName}</strong><small>{lift.equipment} · {lift.verification} · {new Date(lift.performedAt).toLocaleDateString()}</small></div><b>{lift.weight} {lift.unit} × {lift.reps}</b></div>)}</div></Card>}
          {tab === "Progress" && <Card><h2>Submission trends</h2><p className="muted">Built only from lift submissions and bodyweight records.</p><div className="trend-chart">{[...lifts].sort((a, b) => a.performedAt.localeCompare(b.performedAt)).slice(-12).map((lift) => <div key={lift.id}><span style={{ height: `${Math.max(12, lift.normalizedWeight / Math.max(...lifts.map((item) => item.normalizedWeight)) * 100)}%` }} /><small>{lift.exerciseName.split(" ")[0]}</small></div>)}</div><table><thead><tr><th>Date</th><th>Lift</th><th>Result</th></tr></thead><tbody>{lifts.slice(0, 8).map((lift) => <tr key={lift.id}><td>{new Date(lift.performedAt).toLocaleDateString()}</td><td>{lift.exerciseName}</td><td>{lift.weight} {lift.unit}</td></tr>)}</tbody></table></Card>}
          {tab === "Posts" && <Card><h2>Discussions</h2><div className="profile-list">{state.communityPosts.filter((post) => post.authorId === profile.id && post.kind !== "Workout").map((post) => <Link key={post.id} to={`/community/${post.id}`}><strong>{post.title}</strong><small>{post.kind}</small></Link>)}</div></Card>}
          {(tab === "Overview" || tab === "Achievements") && <Card><h2>Achievements</h2><div className="achievement-list">{achievements.map((item) => <div key={item.title} className={item.unlocked ? "unlocked" : ""}><span className="icon-tile"><Trophy /></span><span><strong>{item.title}</strong><small>{item.detail}</small></span></div>)}</div><p className="muted">Next total milestone: {Math.ceil((total + 1) / 100) * 100} lb</p></Card>}
        </section>
        <aside className="profile-side">
          <Card><h2>About</h2><p>{profile.bio || "No bio added yet."}</p><div className="profile-detail-list"><span><strong>Goal</strong><small>{profile.trainingGoal}</small></span><span><strong>Discipline</strong><small>{profile.discipline}</small></span>{!profile.hideAge && <span><strong>Age group</strong><small>{profile.ageGroup}</small></span>}<span><strong>Federation</strong><small>{profile.federation}</small></span><span><strong>Equipment</strong><small>{profile.preferredEquipment}</small></span>{profile.professionalCredential && <span><strong>Credential</strong><small>{profile.professionalCredential}{profile.credentialVerified ? " · Verified" : ""}</small></span>}</div></Card>
        </aside>
      </div>
    </div>
  );
}

export function SettingsPage() {
  const { state, dispatch, gymCatalogStatus, gymCatalogError, ensureGymCatalog } = useTracker();
  const original = currentProfile(state);
  const [draft, setDraft] = useState(original);
  const [saved, setSaved] = useState(false);
  useEffect(() => { void ensureGymCatalog(); }, [ensureGymCatalog]);
  if (gymCatalogStatus !== "ready") return <div className="page narrow-page"><PageHeader eyebrow="Account" title="Profile and settings" description="These preferences are stored only in this browser." /><Card className="catalog-loading" aria-live="polite">{gymCatalogStatus === "error" ? <><h2>Gym options unavailable</h2><p>{gymCatalogError ?? "Unable to load gym options."}</p><button className="primary-button compact" onClick={() => void ensureGymCatalog()}>Try again</button></> : <><span className="loading-spinner" aria-hidden /><h2>Loading settings</h2></>}</Card></div>;
  return <div className="page narrow-page"><PageHeader eyebrow="Account" title="Profile and settings" description="These preferences are stored only in this browser." /><form className="settings-form" onSubmit={(event) => { event.preventDefault(); dispatch({ type: "UPDATE_PROFILE", profile: draft }); setSaved(true); }}><Card><label className="form-field"><span>Display name</span><input value={draft.displayName} onChange={(event) => setDraft({ ...draft, displayName: event.target.value })} /></label><label className="form-field"><span>Handle</span><input value={draft.handle} onChange={(event) => setDraft({ ...draft, handle: event.target.value.startsWith("@") ? event.target.value : `@${event.target.value}` })} /></label><label className="form-field"><span>Bio</span><textarea rows={4} value={draft.bio} onChange={(event) => setDraft({ ...draft, bio: event.target.value })} /></label><div className="form-grid"><label className="form-field"><span>Discipline</span><input value={draft.discipline} onChange={(event) => setDraft({ ...draft, discipline: event.target.value })} /></label><label className="form-field"><span>Training goal</span><input value={draft.trainingGoal} onChange={(event) => setDraft({ ...draft, trainingGoal: event.target.value })} /></label><label className="form-field"><span>Years training</span><input type="number" min="0" value={draft.yearsTraining} onChange={(event) => setDraft({ ...draft, yearsTraining: Number(event.target.value) })} /></label><label className="form-field"><span>Federation</span><input value={draft.federation} onChange={(event) => setDraft({ ...draft, federation: event.target.value })} /></label><label className="form-field"><span>Age group</span><select value={draft.ageGroup} onChange={(event) => setDraft({ ...draft, ageGroup: event.target.value })}>{["Under 18", "18-24", "25-29", "30-34", "35-39", "40-44", "45-49", "50-54", "55-59", "60-64", "65-69", "70+"].map((value) => <option key={value}>{value}</option>)}</select></label><label className="form-field"><span>Experience</span><select value={draft.experienceLevel} onChange={(event) => setDraft({ ...draft, experienceLevel: event.target.value })}>{["Novice", "Intermediate", "Advanced", "Veteran"].map((value) => <option key={value}>{value}</option>)}</select></label><label className="form-field"><span>Preferred equipment</span><select value={draft.preferredEquipment} onChange={(event) => setDraft({ ...draft, preferredEquipment: event.target.value as EquipmentType })}>{["Raw", "Wraps", "Equipped"].map((value) => <option key={value}>{value}</option>)}</select></label><label className="form-field"><span>Bodyweight (lb)</span><input type="number" value={draft.bodyweight} onChange={(event) => setDraft({ ...draft, bodyweight: Number(event.target.value) })} /></label></div><label className="form-field"><span>Primary gym</span><select value={draft.primaryGymId} onChange={(event) => setDraft({ ...draft, primaryGymId: event.target.value, city: gymFor(state, event.target.value)?.city ?? draft.city, state: gymFor(state, event.target.value)?.state ?? draft.state })}>{state.gyms.map((gym) => <option key={gym.id} value={gym.id}>{gym.name}</option>)}</select></label>{[["hideGym", "Hide gym"], ["hideLocation", "Hide location"], ["hideAge", "Hide age group"]].map(([key, label]) => <label className="toggle-row" key={key}><input type="checkbox" checked={Boolean(draft[key as "hideGym" | "hideLocation" | "hideAge"])} onChange={(event) => setDraft({ ...draft, [key]: event.target.checked })} /><span><strong>{label}</strong><small>Keep this detail private on public profiles.</small></span></label>)}</Card><button className="primary-button large full-width">Save settings</button>{saved && <p className="saved-message"><Check size={17} /> Settings saved locally.</p>}</form></div>;
}

export function ExerciseDetailPage() {
  const { exerciseId } = useParams();
  const { state } = useTracker();
  const exercise = state.exercises.find((item) => item.id === exerciseId);
  if (!exercise) return <Navigate to="/library" replace />;
  const primaryMuscle = primaryMuscleForExercise(exercise);
  const secondaryMuscles = secondaryMusclesForExercise(exercise);
  return <div className="page"><PageHeader eyebrow={exercise.bodyPart} title={exercise.name} description={`${exercise.equipment} · ${exercise.movementType}`} action={<BodyRegionGlyph exercise={exercise} />} /><div className="stat-grid compact-stats"><Card><strong>{primaryMuscle}</strong><span>Primary muscle</span></Card><Card><strong>{exercise.equipment}</strong><span>Equipment</span></Card><Card><strong>{exercise.trackingType}</strong><span>Measurement</span></Card></div><Card><h2>Exercise details</h2><div className="profile-detail-list"><span><strong>Movement type</strong><small>{exercise.movementType}</small></span><span><strong>Body region</strong><small>{exercise.bodyPart}</small></span><span><strong>Secondary muscles</strong><small>{secondaryMuscles.length ? secondaryMuscles.join(", ") : "None listed"}</small></span></div></Card></div>;
}
