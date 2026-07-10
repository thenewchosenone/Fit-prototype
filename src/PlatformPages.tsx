import {
  Bell,
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
import { type FormEvent, type PropsWithChildren, useMemo, useState } from "react";
import { Link, Navigate, useNavigate, useParams } from "react-router-dom";
import { makeId } from "./lib";
import {
  areFriends,
  computedLeaderboardEntries,
  currentProfile,
  formatRelativeTime,
  gymFor,
  kilogramsToPounds,
  nextLocalMidnight,
  plateLoadTotal,
  weightClassFor
} from "./platform";
import { useTracker } from "./store";
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

export function BodyRegionGlyph({ exercise }: { exercise: Exercise }) {
  const region = exercise.bodyRegions?.[0] ?? exercise.bodyPart;
  return (
    <span className={`body-region-glyph region-${region.toLowerCase().replace(/\s+/g, "-")}`} aria-label={`${region} exercise`}>
      <i className="body-head" /><i className="body-torso" /><i className="body-arms" /><i className="body-legs" />
    </span>
  );
}

function BubbleGroup<T extends string | number>({ label, values, value, onChange, format = String }: { label: string; values: readonly T[]; value: T; onChange: (value: T) => void; format?: (value: T) => string }) {
  return <fieldset className="bubble-group"><legend>{label}</legend><div>{values.map((item) => <button type="button" key={item} className={item === value ? "filter-chip active" : "filter-chip"} onClick={() => onChange(item)}>{format(item)}</button>)}</div></fieldset>;
}

export function SubmitLiftPage() {
  const { state, dispatch } = useTracker();
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
        <button className="primary-button large full-width" type="submit" disabled={!exercise || Number(weight) <= 0}>Submit lift</button>
      </form>
    </div>
  );
}

export function GymsPage() {
  const { state, dispatch } = useTracker();
  const [query, setQuery] = useState("");
  const filtered = state.gyms.filter((gym) => `${gym.name} ${gym.city} ${gym.state}`.toLowerCase().includes(query.trim().toLowerCase()));
  const profile = currentProfile(state);
  return (
    <div className="page">
      <PageHeader eyebrow="Official directory" title="Crunch gyms" description="Official Florida locations used for memberships, submissions, and gym rankings." action={<span className="status-chip">{state.joinedGymIds.length}/3 joined</span>} />
      <label className="search-field"><Search size={19} /><input aria-label="Search gyms" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search by gym or city..." /></label>
      <div className="object-list gym-list">
        {filtered.map((gym) => {
          const joined = state.joinedGymIds.includes(gym.id);
          const primary = profile.primaryGymId === gym.id;
          return <Card key={gym.id} className="object-row"><span className="icon-tile blue"><Building2 /></span><div className="object-copy"><Link to={`/gyms/${gym.id}`}>{gym.name}</Link><p><MapPin size={14} /> {gym.city}, {gym.state}</p><small>{gym.memberCount} members · {gym.verifiedLiftCount} verified lifts</small></div><button className={joined ? "quiet-button" : "primary-button compact"} disabled={primary || (!joined && state.joinedGymIds.length >= 3)} onClick={() => dispatch({ type: joined ? "LEAVE_GYM" : "JOIN_GYM", gymId: gym.id })}>{primary ? "Primary" : joined ? "Leave" : "Join"}</button></Card>;
        })}
      </div>
    </div>
  );
}

export function GymDetailPage() {
  const { gymId } = useParams();
  const { state, dispatch } = useTracker();
  const gym = state.gyms.find((item) => item.id === gymId);
  if (!gym) return <Navigate to="/gyms" replace />;
  const profile = currentProfile(state);
  const joined = state.joinedGymIds.includes(gym.id);
  const entries = computedLeaderboardEntries(state, { rankingType: "Total", scope: "Selected gym", verification: "All", exercise: "All", gym: gym.name, city: "All", ageGroup: "All", experienceLevel: "All", weightClass: "All", repCount: null });
  return <div className="page"><PageHeader eyebrow="Gym profile" title={gym.name} description={`${gym.city}, ${gym.state}`} action={<button className={joined ? "quiet-button" : "primary-button"} disabled={profile.primaryGymId === gym.id || (!joined && state.joinedGymIds.length >= 3)} onClick={() => dispatch({ type: joined ? "LEAVE_GYM" : "JOIN_GYM", gymId: gym.id })}>{profile.primaryGymId === gym.id ? "Primary gym" : joined ? "Leave gym" : "Join gym"}</button>} /><div className="stat-grid compact-stats"><Card><strong>{gym.memberCount}</strong><span>Members</span></Card><Card><strong>{gym.verifiedLiftCount}</strong><span>Verified lifts</span></Card><Card><strong>{entries.length}</strong><span>Ranked lifters</span></Card></div><Card><div className="section-title"><h2>Gym leaderboard</h2><Link to="/leaderboards">Full leaderboard</Link></div><div className="compact-ranking-list">{entries.slice(0, 10).map((entry) => <Link to={`/profile/${entry.userId}`} key={entry.id}><b>#{entry.rank}</b><span>{entry.athlete}</span><strong>{entry.total.toLocaleString()} lb</strong></Link>)}{!entries.length && <p className="muted">No eligible totals at this gym yet.</p>}</div></Card></div>;
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
  const [topic, setTopic] = useState("All");
  const [composer, setComposer] = useState(false);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const topics = ["All", "Bench", "Squat", "Deadlift", "PR", "Gym"];
  const posts = [...state.communityPosts].filter((post) => {
    if (topic === "All") return true;
    if (topic === "PR" || topic === "Gym") return post.kind === topic;
    const lift = state.liftSubmissions.find((item) => item.id === post.linkedLiftId);
    return `${post.title} ${post.body} ${lift?.exerciseName ?? ""}`.toLowerCase().includes(topic.toLowerCase());
  }).sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  const submit = (event: FormEvent) => { event.preventDefault(); if (!title.trim() || !body.trim()) return; dispatch({ type: "CREATE_POST", post: { authorId: state.currentUserId, kind: "Discussion", title: title.trim(), body: body.trim() } }); setTitle(""); setBody(""); setComposer(false); };
  return (
    <div className="page community-page">
      <PageHeader eyebrow="Lifting network" title="Community" description="Training updates, verified lifts, gym conversations, and people you actually train with." action={<button className="primary-button" onClick={() => setComposer(true)}><Plus size={18} /> New post</button>} />
      <div className="tab-rail">{topics.map((item) => <button key={item} className={topic === item ? "active" : ""} onClick={() => setTopic(item)}>{item}</button>)}</div>
      <div className="feed-layout"><main className="feed-list">{posts.map((post) => <CommunityCard key={post.id} post={post} />)}</main><aside className="community-aside"><Card><h3>Community tools</h3><Link to="/friends"><Users size={18} /> Friends and requests <ChevronRight size={17} /></Link><Link to="/messages"><Mail size={18} /> Messages <ChevronRight size={17} /></Link><Link to="/gyms"><Building2 size={18} /> Gym directory <ChevronRight size={17} /></Link></Card></aside></div>
      {composer && <div className="modal-backdrop"><div className="modal"><header><div><p className="eyebrow">Community</p><h2>Start a discussion</h2></div><button aria-label="Close" className="icon-button" onClick={() => setComposer(false)}><X /></button></header><form className="stack-form" onSubmit={submit}><label><span>Title</span><input value={title} onChange={(event) => setTitle(event.target.value)} /></label><label><span>Post</span><textarea rows={5} value={body} onChange={(event) => setBody(event.target.value)} /></label><button className="primary-button" type="submit">Publish post</button></form></div></div>}
    </div>
  );
}

function CommunityCard({ post }: { post: CommunityPost }) {
  const { state, dispatch } = useTracker();
  const profile = state.profiles.find((item) => item.id === post.authorId)!;
  const lift = state.liftSubmissions.find((item) => item.id === post.linkedLiftId);
  const gym = post.gymId ? gymFor(state, post.gymId) : undefined;
  const comments = state.comments.filter((item) => item.postId === post.id);
  return <article className="feed-card"><header><Link to={`/profile/${profile.id}`}><Avatar profile={profile} /><span><strong>{profile.displayName}</strong><small>{profile.handle} · {formatRelativeTime(post.createdAt)}</small></span></Link><FriendAction profile={profile} /></header><Link className="feed-copy" to={`/community/${post.id}`}><span className="status-chip">{post.kind}</span><h2>{post.title}</h2><p>{post.body}</p></Link>{lift && <div className="lift-summary"><span className="icon-tile blue"><Weight /></span><div><strong>{lift.weight} {lift.unit} × {lift.reps}</strong><small>{lift.exerciseName} · {lift.verification}</small></div>{gym && <span>{gym.name.replace("Crunch Fitness - ", "")}</span>}</div>}<footer><button aria-label={`Like post, ${post.likedBy.length} likes`} className={post.likedBy.includes(state.currentUserId) ? "active" : ""} onClick={() => dispatch({ type: "TOGGLE_POST_LIKE", postId: post.id })}><Heart size={17} fill={post.likedBy.includes(state.currentUserId) ? "currentColor" : "none"} /> {post.likedBy.length}</button><Link aria-label={`View ${comments.length} comments`} to={`/community/${post.id}`}><MessageCircle size={17} /> {comments.length}</Link><button aria-label="Save post" className={post.savedBy.includes(state.currentUserId) ? "active" : ""} onClick={() => dispatch({ type: "TOGGLE_POST_SAVE", postId: post.id })}><Save size={17} /> Save</button><button aria-label="Report post" onClick={() => alert("Post reported for review in this local prototype.")}><Flag size={17} /> Report</button></footer></article>;
}

export function CommunityPostPage() {
  const { postId } = useParams();
  const { state, dispatch } = useTracker();
  const [body, setBody] = useState("");
  const post = state.communityPosts.find((item) => item.id === postId);
  if (!post) return <Navigate to="/community" replace />;
  const comments = state.comments.filter((item) => item.postId === post.id);
  return <div className="page narrow-page"><CommunityCard post={post} /><Card><h2>Comments</h2><div className="comment-list">{comments.map((comment) => { const author = state.profiles.find((item) => item.id === comment.authorId)!; return <div key={comment.id}><Avatar profile={author} /><span><strong>{author.displayName}</strong><p>{comment.body}</p><small>{formatRelativeTime(comment.createdAt)}</small></span></div>; })}</div><form className="comment-form" onSubmit={(event) => { event.preventDefault(); if (!body.trim()) return; dispatch({ type: "ADD_COMMENT", comment: { postId: post.id, body: body.trim() } }); setBody(""); }}><input aria-label="Write a comment" value={body} onChange={(event) => setBody(event.target.value)} placeholder="Write a comment..." /><button className="primary-button compact"><Send size={17} /> Post</button></form></Card></div>;
}

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
  return <div className="page"><PageHeader eyebrow="Direct messages" title="Messages" description="Private conversations with accepted friends." action={<Link className="quiet-button" to="/friends"><Users size={17} /> Friends</Link>} /><div className="inbox-list">{threads.map((thread) => { const otherId = thread.participantIds.find((id) => id !== state.currentUserId)!; const profile = state.profiles.find((item) => item.id === otherId)!; const last = state.messages.filter((message) => message.threadId === thread.id).at(-1); return <Link className="inbox-row" to={`/messages/${thread.id}`} key={thread.id}><Avatar profile={profile} /><span><strong>{profile.displayName}</strong><small>{last?.body ?? "Start the conversation"}</small></span><time>{formatRelativeTime(last?.createdAt ?? thread.updatedAt)}</time><ChevronRight /></Link>; })}{!threads.length && <p className="empty-inline">No conversations yet.</p>}</div></div>;
}

function NewConversation({ recipientId }: { recipientId: string }) {
  const { state, dispatch } = useTracker();
  const navigate = useNavigate();
  const profile = state.profiles.find((item) => item.id === recipientId);
  const [body, setBody] = useState("");
  if (!profile || !areFriends(state, state.currentUserId, profile.id)) return <Navigate to="/messages" replace />;
  return <div className="page narrow-page"><PageHeader eyebrow="New message" title={profile.displayName} description="Send the first message to create this conversation." /><form className="message-composer-card" onSubmit={(event) => { event.preventDefault(); if (!body.trim()) return; dispatch({ type: "SEND_MESSAGE", recipientId, body }); const id = state.messageThreads.find((thread) => thread.participantIds.includes(recipientId))?.id; setTimeout(() => navigate(id ? `/messages/${id}` : "/messages"), 0); }}><textarea rows={5} value={body} onChange={(event) => setBody(event.target.value)} placeholder="Write a message..." /><button className="primary-button">Send message</button></form></div>;
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
  return <div className="conversation-page"><header><Link to="/messages">Messages</Link><div><Avatar profile={profile} /><span><strong>{profile.displayName}</strong><small>{profile.handle}</small></span></div><button className="icon-button danger" aria-label="Delete conversation" onClick={() => { if (confirm("Delete this conversation?")) { dispatch({ type: "DELETE_MESSAGE_THREAD", threadId: thread.id }); navigate("/messages"); } }}><Trash2 /></button></header><main>{messages.map((message) => <div key={message.id} className={message.senderId === state.currentUserId ? "message-bubble own" : "message-bubble"}><p>{message.body}</p><small>{formatRelativeTime(message.createdAt)}</small><div className="message-actions"><button onClick={() => dispatch({ type: "DELETE_MESSAGE", messageId: message.id })}>Delete</button>{message.senderId !== state.currentUserId && <button onClick={() => setReporting(message.id)}>Report</button>}</div>{message.isReported && <span className="reported-label">Reported</span>}</div>)}</main><form onSubmit={(event) => { event.preventDefault(); if (!body.trim()) return; dispatch({ type: "SEND_MESSAGE", recipientId: otherId, body }); setBody(""); }}><textarea aria-label="Message" rows={1} value={body} onChange={(event) => setBody(event.target.value)} placeholder="Write a message..." /><button className="primary-button compact"><Send size={18} /></button></form>{reporting && <ReportMessageModal messageId={reporting} onClose={() => setReporting(null)} />}</div>;
}

function ReportMessageModal({ messageId, onClose }: { messageId: string; onClose: () => void }) {
  const { dispatch } = useTracker();
  const [reason, setReason] = useState<MessageReportReason>("Spam");
  const [note, setNote] = useState("");
  return <div className="modal-backdrop"><div className="modal"><header><h2>Report message</h2><button className="icon-button" onClick={onClose}><X /></button></header><BubbleGroup label="Reason" values={["Spam", "Offensive", "Harassment", "Other"] as MessageReportReason[]} value={reason} onChange={setReason} /><label className="form-field"><span>Optional note</span><textarea rows={3} value={note} onChange={(event) => setNote(event.target.value)} /></label><button className="primary-button" onClick={() => { dispatch({ type: "REPORT_MESSAGE", messageId, reason, note }); onClose(); }}>Submit report</button></div></div>;
}

export function PlatformProfilePage() {
  const { userId } = useParams();
  const { state } = useTracker();
  const profile = state.profiles.find((item) => item.id === (userId ?? state.currentUserId));
  if (!profile) return <Navigate to="/profile" replace />;
  const own = profile.id === state.currentUserId;
  const gym = gymFor(state, profile.primaryGymId);
  const lifts = state.liftSubmissions.filter((lift) => lift.userId === profile.id).sort((a, b) => b.normalizedWeight - a.normalizedWeight);
  const best = [...new Map(lifts.map((lift) => [lift.exerciseId, lift])).values()].slice(0, 6);
  const total = ["back-squat", "barbell-bench", "deadlift"].reduce((sum, id) => sum + (lifts.filter((lift) => lift.exerciseId === id && lift.reps === 1).sort((a, b) => b.normalizedWeight - a.normalizedWeight)[0]?.normalizedWeight ?? 0), 0);
  const activePlan = state.plans.find((plan) => plan.id === state.activePlanId);
  const achievements = [
    { title: "Total on file", detail: `${total.toLocaleString()} lb across the big three`, unlocked: total > 0 },
    { title: "Verified lifter", detail: "At least one reviewed submission", unlocked: best.some((lift) => !["Self Reported", "Video Submitted"].includes(lift.verification)) },
    { title: "Community member", detail: "Shared training with LiftRank", unlocked: state.communityPosts.some((post) => post.authorId === profile.id) }
  ];
  return (
    <div className="page">
      <section className="profile-hero">
        <Avatar profile={profile} size="large" />
        <div className="profile-hero-copy">
          <p className="eyebrow">Lifter profile</p><h1>{profile.displayName}</h1>
          <p>{profile.handle} · {profile.ageGroup} · {profile.experienceLevel}</p>
          <div className="profile-chip-row"><span className="status-chip">{weightClassFor(profile.bodyweight, profile.sex)}</span>{!profile.hideGym && gym && <Link className="status-chip" to={`/gyms/${gym.id}`}>{gym.name}</Link>}{!profile.hideLocation && <span className="status-chip">{profile.city}, {profile.state}</span>}</div>
        </div>
        <div className="profile-hero-actions">{own ? <Link className="primary-button" to="/settings"><Settings size={18} /> Edit profile</Link> : <FriendAction profile={profile} />}</div>
      </section>
      <div className="stat-grid"><Card><strong>{total.toLocaleString()} lb</strong><span>Three-lift total</span></Card><Card><strong>{profile.bodyweight} lb</strong><span>Bodyweight</span></Card><Card><strong>{best.filter((lift) => !["Self Reported", "Video Submitted"].includes(lift.verification)).length}</strong><span>Verified lifts</span></Card><Card><strong>{state.communityPosts.filter((post) => post.authorId === profile.id).length}</strong><span>Community posts</span></Card></div>
      <div className="profile-layout">
        <section className="profile-main">
          <Card><div className="section-title"><h2>Strength snapshot</h2>{own && <Link to="/submit">Submit lift</Link>}</div><div className="profile-list">{best.map((lift) => <div className="profile-list-row" key={lift.id}><span className="icon-tile"><Trophy /></span><div><strong>{lift.exerciseName}</strong><small>{lift.verification} · {lift.reps} rep</small></div><b>{lift.weight} {lift.unit}</b></div>)}</div></Card>
          <Card><h2>Achievements</h2><div className="achievement-list">{achievements.map((item) => <div key={item.title} className={item.unlocked ? "unlocked" : ""}><span className="icon-tile"><Trophy /></span><span><strong>{item.title}</strong><small>{item.detail}</small></span></div>)}</div></Card>
        </section>
        <aside className="profile-side">
          <Card><h2>About</h2><p>{profile.bio || "No bio added yet."}</p><div className="profile-detail-list"><span><strong>Age group</strong><small>{profile.ageGroup}</small></span><span><strong>Experience</strong><small>{profile.experienceLevel}</small></span><span><strong>Units</strong><small>{profile.unitSystem}</small></span></div></Card>
          {own && <Card><div className="section-title"><h2>Active plan</h2><Link to="/plans">Manage</Link></div><div className="profile-detail-list"><span><strong>{activePlan?.name ?? "No active plan"}</strong><small>{activePlan?.goal ?? "Create a plan to get started."}</small></span><span><strong>{state.completedWorkouts.length} workouts</strong><small>Completed history</small></span></div></Card>}
        </aside>
      </div>
    </div>
  );
}

export function SettingsPage() {
  const { state, dispatch } = useTracker();
  const original = currentProfile(state);
  const [draft, setDraft] = useState(original);
  const [saved, setSaved] = useState(false);
  return <div className="page narrow-page"><PageHeader eyebrow="Account" title="Profile and settings" description="These preferences are stored only in this browser." /><form className="settings-form" onSubmit={(event) => { event.preventDefault(); dispatch({ type: "UPDATE_PROFILE", profile: draft }); setSaved(true); }}><Card><label className="form-field"><span>Display name</span><input value={draft.displayName} onChange={(event) => setDraft({ ...draft, displayName: event.target.value })} /></label><label className="form-field"><span>Handle</span><input value={draft.handle} onChange={(event) => setDraft({ ...draft, handle: event.target.value.startsWith("@") ? event.target.value : `@${event.target.value}` })} /></label><label className="form-field"><span>Bio</span><textarea rows={4} value={draft.bio} onChange={(event) => setDraft({ ...draft, bio: event.target.value })} /></label><div className="form-grid"><label className="form-field"><span>Age group</span><select value={draft.ageGroup} onChange={(event) => setDraft({ ...draft, ageGroup: event.target.value })}>{["Under 18", "18-24", "25-29", "30-34", "35-39", "40-44", "45-49", "50-54", "55-59", "60-64", "65-69", "70+"].map((value) => <option key={value}>{value}</option>)}</select></label><label className="form-field"><span>Experience</span><select value={draft.experienceLevel} onChange={(event) => setDraft({ ...draft, experienceLevel: event.target.value })}>{["Novice", "Intermediate", "Advanced", "Veteran"].map((value) => <option key={value}>{value}</option>)}</select></label><label className="form-field"><span>Units</span><select value={draft.unitSystem} onChange={(event) => setDraft({ ...draft, unitSystem: event.target.value as "lb" | "kg" })}><option>lb</option><option>kg</option></select></label><label className="form-field"><span>Bodyweight (lb)</span><input type="number" value={draft.bodyweight} onChange={(event) => setDraft({ ...draft, bodyweight: Number(event.target.value) })} /></label></div><label className="form-field"><span>Primary gym</span><select value={draft.primaryGymId} onChange={(event) => setDraft({ ...draft, primaryGymId: event.target.value, city: gymFor(state, event.target.value)?.city ?? draft.city, state: gymFor(state, event.target.value)?.state ?? draft.state })}>{state.gyms.map((gym) => <option key={gym.id} value={gym.id}>{gym.name}</option>)}</select></label><label className="toggle-row"><input type="checkbox" checked={draft.hideGym} onChange={(event) => setDraft({ ...draft, hideGym: event.target.checked })} /><span><strong>Hide gym</strong><small>Do not show your primary gym publicly.</small></span></label><label className="toggle-row"><input type="checkbox" checked={draft.hideLocation} onChange={(event) => setDraft({ ...draft, hideLocation: event.target.checked })} /><span><strong>Hide location</strong><small>Do not show your city publicly.</small></span></label></Card><button className="primary-button large full-width">Save settings</button>{saved && <p className="saved-message"><Check size={17} /> Settings saved locally.</p>}</form></div>;
}

export function ExerciseDetailPage() {
  const { exerciseId } = useParams();
  const { state } = useTracker();
  const exercise = state.exercises.find((item) => item.id === exerciseId);
  if (!exercise) return <Navigate to="/library" replace />;
  const history = state.completedWorkouts.flatMap((workout) => workout.setLogs.map((log) => ({ workout, log, prescription: workout.prescriptions.find((item) => item.id === log.prescriptionId) }))).filter((item) => item.prescription?.exerciseId === exercise.id && item.log.isComplete).sort((a, b) => b.workout.completedAt.localeCompare(a.workout.completedAt));
  const best = history.reduce((result, item) => (item.log.weight ?? 0) > (result?.log.weight ?? 0) ? item : result, history[0]);
  return <div className="page"><PageHeader eyebrow={exercise.bodyPart} title={exercise.name} description={`${exercise.equipment} · ${exercise.movementType} · ${exercise.trackingType}`} action={<BodyRegionGlyph exercise={exercise} />} /><div className="stat-grid"><Card><strong>{best ? `${best.log.weight} lb × ${best.log.reps}` : "—"}</strong><span>Best set</span></Card><Card><strong>{history.length}</strong><span>Completed sets</span></Card><Card><strong>{history.reduce((sum, item) => sum + (item.log.weight ?? 0) * (item.log.reps ?? 0), 0).toLocaleString()}</strong><span>Total volume</span></Card></div><Card><h2>Set history</h2><div className="history-table"><div><b>Date</b><b>Weight</b><b>Reps</b><b>RPE</b></div>{history.map((item) => <div key={item.log.id}><span>{new Date(item.workout.completedAt).toLocaleDateString()}</span><span>{item.log.weight ?? "—"} lb</span><span>{item.log.reps ?? "—"}</span><span>{item.log.rpe ?? "—"}</span></div>)}</div>{!history.length && <p className="empty-inline">Complete this exercise in a workout to build history.</p>}</Card></div>;
}

export function NotificationButton() {
  const { state, dispatch } = useTracker();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const unread = state.notifications.filter((item) => !item.isRead).length;
  return <div className="notification-control"><button className="icon-button" aria-label={`Notifications, ${unread} unread`} onClick={() => setOpen(!open)}><Bell />{unread > 0 && <span>{unread}</span>}</button>{open && <div className="notification-popover"><header><h3>Notifications</h3>{unread > 0 && <button onClick={() => dispatch({ type: "MARK_ALL_NOTIFICATIONS_READ" })}>Read all</button>}</header>{state.notifications.map((notification) => <button key={notification.id} className={notification.isRead ? "" : "unread"} onClick={() => { dispatch({ type: "MARK_NOTIFICATION_READ", notificationId: notification.id }); setOpen(false); navigate(notification.target); }}><span className="icon-tile"><Bell /></span><span><strong>{notification.title}</strong><small>{notification.body}</small><time>{formatRelativeTime(notification.createdAt)}</time></span></button>)}</div>}</div>;
}
