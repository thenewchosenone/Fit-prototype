import type {
  Comment,
  CommunityPost,
  FriendRequest,
  Gym,
  LiftSubmission,
  Message,
  MessageThread,
  NotificationItem,
  TrainingGroup,
  UserProfile
} from "./types";

const gymRows = `Altamonte Springs|Altamonte Springs
Apollo Beach|Apollo Beach
Apopka|Apopka
Belle Isle|Orlando
Bloomingdale|Valrico
Boy Scout|Fort Myers
Bradenton|Bradenton
Brandon|Brandon
Cape Coral|Cape Coral
Carrollwood|Tampa
Casselberry|Casselberry
Channelside|Tampa
Clermont|Clermont
Coral Ridge|Coral Springs
Coral Springs|Coral Springs
Countryside|Clearwater
Cutler Bay|Cutler Bay
Daytona Beach|Daytona Beach
Deltona|Deltona
Doral|Miami
Dr. Phillips|Orlando
East Colonial|Orlando
East Sarasota|Sarasota
Fort Myers|Fort Myers
Gainesville|Gainesville
Greenacres|Greenacres
Haines City|Haines City
Hallandale|Hallandale Beach
Harbour Village|Jacksonville
Hillsborough|Tampa
Homestead|Homestead
Kirkman|Orlando
Kissimmee|Kissimmee
Kissimmee West|Kissimmee
Lake Mary|Lake Mary
Lake Nona|Orlando
Lake Worth|Lake Worth
Lakeland|Lakeland
Lakewood Ranch|Bradenton
Land O'Lakes|Land O' Lakes
Maitland|Maitland
Miami Gardens|Miami Gardens
Naples|Naples
Oakland Park|Oakland Park
Ocoee|Ocoee
Orange Park|Orange Park
Orlando Park|Orlando
Palm Beach Gardens|Palm Beach Gardens
Palm Harbor|Palm Harbor
Parrish|Parrish
Pembroke Pines|Pembroke Pines
Pensacola|Pensacola
Plantation|Plantation
Poinciana|Kissimmee
Pompano Beach|Pompano Beach
Port St. Lucie|Port St. Lucie
Regency Park|Jacksonville
Riverview|Riverview
Sarasota Bee Ridge|Sarasota
Sarasota University|Sarasota
Seminole|Seminole
Six Mile|Fort Myers
South Beach|Miami Beach
South Tampa|Tampa
St Cloud FL|St. Cloud
St. Pete Northeast|St. Petersburg
Stuart|Stuart
Sunrise|Sunrise
Tallahassee|Tallahassee
Tamarac|Tamarac
Tampa Palms|Tampa
Trinity|New Port Richey
Tyrone|St. Petersburg
Wellington|Wellington
Wesley Chapel|Wesley Chapel
West Melbourne|Melbourne
West Pembroke|Pembroke Pines
Wickham|Melbourne
Winter Garden|Winter Garden
Winter Park|Winter Park
Winter Springs|Winter Springs`;

const slug = (value: string) => value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");

const demoMetrics = (index: number) => ({
  memberCount: 180 + ((index * 17) % 140),
  verifiedLiftCount: 260 + ((index * 31) % 520)
});

const legacyDemoMetrics = new Map<string, ReturnType<typeof demoMetrics>>(
  gymRows.split("\n").map((row, index) => {
    const [location] = row.split("|");
    return [`gym-${slug(location)}`, demoMetrics(index)] as const;
  })
);

const coreGymRows = [
  ["gym-brandon", "Crunch Fitness - Brandon", "1570 W Brandon Blvd", "Brandon", "33511", "brandon"],
  ["gym-coral-springs", "Crunch Fitness - Coral Springs", "910 N University Dr", "Coral Springs", "33071", "coral-springs"],
  ["gym-doral", "Crunch Fitness - Doral", "1970 NW 117 PL", "Miami", "33182", "doral"],
  ["gym-south-beach", "Crunch Fitness - South Beach", "1259 Washington Ave", "Miami Beach", "33139", "south-beach"],
  ["gym-oakland-park", "Crunch Fitness - Oakland Park", "3500 N Andrews Ave", "Oakland Park", "33309", "oakland-park"],
  ["gym-tampa-palms", "Crunch Fitness - Tampa Palms", "15313 Amberly Dr", "Tampa", "33647", "tampa-palms"],
  ["gym-wesley-chapel", "Crunch Fitness - Wesley Chapel", "5351 Village Market Drive", "Wesley Chapel", "33544", "wesley-chapel"],
  ["gym-winter-garden", "Crunch Fitness - Winter Garden", "14150 West Colonial Drive", "Winter Garden", "34787", "winter-garden"],
  ["gym-winter-park", "Crunch Fitness - Winter Park", "4270 Aloma Ave", "Winter Park", "32792", "winter-park"]
] as const;

export function withLegacyDemoMetrics(gym: Gym): Gym {
  return { ...gym, ...(legacyDemoMetrics.get(gym.id) ?? {}) };
}

export const gymSeed: Gym[] = coreGymRows.map(([id, name, address, city, postalCode, slug]) => withLegacyDemoMetrics({
  id,
  brand: "Crunch Fitness",
  name,
  address,
  city,
  state: "Florida",
  postalCode,
  countryCode: "US",
  officialUrl: `https://www.crunch.com/locations/${slug}`
}));

type ProfileSeed = [string, string, string, string, string, string, "Male" | "Female", number, string, string, string];

const profileRows: ProfileSeed[] = [
  ["user-robert", "Robert J.", "@rjrob23", "30-34", "Advanced", "gym-south-beach", "Male", 210, "Miami Beach", "Florida", "Powerbuilder chasing a bigger total."],
  ["user-evan", "Evan Cole", "@evancole", "30-34", "Advanced", "gym-south-beach", "Male", 218, "Miami Beach", "Florida", "Competition-tested strength athlete."],
  ["user-mia", "Mia Santos", "@miastrong", "25-29", "Advanced", "gym-doral", "Female", 154, "Miami", "Florida", "Squat specialist and meet-day volunteer."],
  ["user-darius", "Darius King", "@dariusking", "40-44", "Veteran", "gym-winter-garden", "Male", 232, "Winter Garden", "Florida", "Masters lifter building toward nationals."],
  ["user-marcus", "Marcus Bell", "@mbellstrong", "30-34", "Advanced", "gym-coral-springs", "Male", 198, "Coral Springs", "Florida", "Strength first, details always."],
  ["user-nico", "Nico Rivera", "@nicorivera", "25-29", "Intermediate", "gym-south-beach", "Male", 187, "Miami Beach", "Florida", "Training for a first powerlifting meet."],
  ["user-talia", "Talia Brooks", "@taliabrooks", "35-39", "Advanced", "gym-tampa-palms", "Female", 168, "Tampa", "Florida", "Consistent work and clean technique."],
  ["user-sofia", "Sofia Martin", "@sofiamartin", "25-29", "Advanced", "gym-winter-park", "Female", 142, "Winter Park", "Florida", "Bench and deadlift focused."],
  ["user-chris", "Chris Velez", "@chrisvelez", "20-24", "Intermediate", "gym-doral", "Male", 176, "Miami", "Florida", "Learning the platform one session at a time."],
  ["user-aisha", "Aisha Grant", "@aishalifts", "30-34", "Advanced", "gym-oakland-park", "Female", 160, "Oakland Park", "Florida", "Raw lifter and community moderator."],
  ["user-leo", "Leo Nguyen", "@leonguyen", "35-39", "Veteran", "gym-wesley-chapel", "Male", 205, "Wesley Chapel", "Florida", "Long-term strength, no shortcuts."],
  ["user-jordan", "Jordan Price", "@jprice", "25-29", "Intermediate", "gym-brandon", "Male", 190, "Brandon", "Florida", "Building all three lifts."],
];

export const profileSeed: UserProfile[] = profileRows.map((row) => ({
  id: row[0], displayName: row[1], handle: row[2], ageGroup: row[3], experienceLevel: row[4],
  primaryGymId: row[5], sex: row[6], bodyweight: row[7], city: row[8], state: row[9], bio: row[10],
  unitSystem: "lb", hideGym: false, hideLocation: false, hideAge: false,
  discipline: row[4] === "Veteran" ? "Powerlifting" : row[4] === "Intermediate" ? "General Strength" : "Powerlifting",
  trainingGoal: row[4] === "Intermediate" ? "Build a strong foundation" : "Increase competition total",
  yearsTraining: row[4] === "Veteran" ? 12 : row[4] === "Advanced" ? 6 : 2,
  federation: row[4] === "Intermediate" ? "Unaffiliated" : "USAPL",
  preferredEquipment: "Raw",
  role: row[0] === "user-robert" ? "Admin" : row[0] === "user-aisha" ? "Moderator" : "Member",
  professionalCredential: row[0] === "user-aisha" ? "Certified Strength Coach" : undefined,
  credentialVerified: row[0] === "user-aisha"
}));

export const trainingGroupSeed: TrainingGroup[] = [
  ["general-strength", "General Strength", "Practical training, programming, and progress for every strength athlete."],
  ["powerlifting", "Powerlifting", "Squat, bench press, deadlift, meet preparation, and competition strategy."],
  ["bodybuilding", "Bodybuilding", "Hypertrophy programming, posing, recovery, and physique development."],
  ["olympic-weightlifting", "Olympic Weightlifting", "Snatch, clean and jerk, technique, and weightlifting programming."],
  ["calisthenics", "Calisthenics", "Bodyweight strength, skills, progressions, and weighted calisthenics."],
  ["conditioning", "Conditioning", "Running, work capacity, circuits, and conditioning around lifting."],
  ["mobility-recovery", "Mobility & Recovery", "Mobility, fatigue management, sleep, and returning to training safely."],
  ["nutrition", "Nutrition", "Evidence-aware nutrition for performance, recovery, and body composition."],
  ["beginner-fitness", "Beginner Fitness", "Constructive answers and simple guidance for people starting out."],
  ["home-gym-equipment", "Home Gym & Equipment", "Equipment reviews, home-gym layouts, maintenance, and buying advice."]
].map(([id, name, description]) => ({
  id: `group-${id}`,
  name,
  description,
  rules: ["Be constructive and include useful training context.", "Do not diagnose injuries or present comments as medical advice.", "No harassment, steroid sourcing, spam, or dangerous recommendations."],
  memberIds: ["user-robert", ...(id === "powerlifting" ? ["user-aisha", "user-evan", "user-mia"] : [])],
  moderatorIds: id === "powerlifting" ? ["user-aisha"] : []
}));

const totals: Record<string, [number, number, number]> = {
  "user-evan": [525, 365, 585], "user-darius": [505, 355, 565], "user-mia": [525, 315, 495],
  "user-marcus": [505, 345, 540], "user-robert": [420, 315, 495], "user-nico": [485, 305, 515],
  "user-talia": [455, 285, 470], "user-sofia": [385, 315, 425], "user-chris": [435, 275, 455],
  "user-aisha": [440, 290, 460], "user-leo": [490, 335, 535], "user-jordan": [405, 285, 475]
};

const verificationByUser: Record<string, LiftSubmission["verification"]> = {
  "user-evan": "Competition Verified", "user-mia": "Moderator Verified", "user-robert": "Moderator Verified",
  "user-darius": "Video Submitted", "user-marcus": "Community Verified", "user-nico": "Community Verified",
  "user-talia": "Moderator Verified", "user-sofia": "Competition Verified", "user-chris": "Self Reported",
  "user-aisha": "Moderator Verified", "user-leo": "Competition Verified", "user-jordan": "Community Verified"
};

const exerciseNames = ["Back Squat", "Barbell Bench Press", "Conventional Deadlift"];
const exerciseIds = ["back-squat", "barbell-bench", "deadlift"];
const now = new Date();
const eligible = new Date(now.getTime() - 86_400_000).toISOString();

export const liftSeed: LiftSubmission[] = profileSeed.flatMap((profile, profileIndex) =>
  totals[profile.id].flatMap((weight, liftIndex) => {
    const current: LiftSubmission = {
      id: `lift-${profile.id}-${exerciseIds[liftIndex]}`,
      userId: profile.id,
      exerciseId: exerciseIds[liftIndex],
      exerciseName: exerciseNames[liftIndex],
      weight,
      unit: "lb",
      normalizedWeight: weight,
      reps: 1,
      bodyweight: profile.bodyweight,
      performedAt: new Date(now.getTime() - (profileIndex + liftIndex + 2) * 86_400_000).toISOString(),
      submittedAt: eligible,
      leaderboardEligibleAt: eligible,
      gymId: profile.primaryGymId,
      equipment: "Raw",
      visibility: "Public",
      verification: verificationByUser[profile.id],
      caption: `${exerciseNames[liftIndex]} PR`
    };
    const previous = { ...current, id: `${current.id}-previous`, weight: Math.max(45, weight - 20), normalizedWeight: Math.max(45, weight - 20), performedAt: new Date(now.getTime() - (profileIndex + 50) * 86_400_000).toISOString() };
    return [previous, current];
  })
);

export const communitySeed: CommunityPost[] = [
  { id: "post-1", authorId: "user-evan", groupId: "group-powerlifting", kind: "Personal Record", title: "585 moved clean", body: "Deadlift peaked exactly where it needed to. Keeping the next block conservative.", createdAt: new Date(now.getTime() - 3_600_000).toISOString(), linkedLiftId: "lift-user-evan-deadlift", gymId: "gym-south-beach", likedBy: ["user-robert", "user-mia"], votes: { "user-robert": 1, "user-mia": 1 }, savedBy: [], exerciseTags: ["Deadlift"], goalTags: ["Strength"], isLocked: false },
  { id: "post-2", authorId: "user-mia", groupId: "group-powerlifting", kind: "Form Check", title: "Squat depth checks", body: "What camera angle gives the clearest depth review without blocking the rack?", createdAt: new Date(now.getTime() - 7_200_000).toISOString(), likedBy: ["user-talia"], votes: { "user-talia": 1 }, savedBy: ["user-robert"], exerciseTags: ["Squat"], goalTags: ["Technique"], isLocked: false, trainingDetails: { exercise: "Back Squat", feedbackRequest: "Depth and camera angle" } },
  { id: "post-3", authorId: "user-nico", groupId: "group-general-strength", kind: "Discussion", title: "South Beach Saturday session", body: "Three of us are training the main lifts at 10 AM. Spots are welcome.", createdAt: new Date(now.getTime() - 18_000_000).toISOString(), gymId: "gym-south-beach", likedBy: [], votes: {}, savedBy: [], exerciseTags: [], goalTags: ["Community"], isLocked: false }
];

export const commentSeed: Comment[] = [
  { id: "comment-1", postId: "post-1", authorId: "user-robert", body: "Strong pull. The lockout looked decisive.", createdAt: new Date(now.getTime() - 2_700_000).toISOString(), votes: {} },
  { id: "comment-2", postId: "post-2", authorId: "user-aisha", body: "Hip height from a rear three-quarter angle usually works best.", createdAt: new Date(now.getTime() - 5_400_000).toISOString(), votes: { "user-robert": 1 } }
];

export const friendRequestSeed: FriendRequest[] = [
  { id: "friend-1", senderId: "user-mia", recipientId: "user-robert", status: "Pending", createdAt: eligible },
  { id: "friend-2", senderId: "user-robert", recipientId: "user-nico", status: "Pending", createdAt: eligible },
  { id: "friend-3", senderId: "user-robert", recipientId: "user-evan", status: "Accepted", createdAt: eligible }
];

export const messageThreadSeed: MessageThread[] = [
  { id: "thread-1", participantIds: ["user-robert", "user-evan"], createdAt: eligible, updatedAt: new Date(now.getTime() - 5_400_000).toISOString() }
];

export const messageSeed: Message[] = [
  { id: "message-1", threadId: "thread-1", senderId: "user-evan", body: "Your last deadlift setup looked much tighter.", createdAt: new Date(now.getTime() - 7_200_000).toISOString(), isRead: true, isReported: false },
  { id: "message-2", threadId: "thread-1", senderId: "user-robert", body: "Thanks. I moved the bar closer before the pull.", createdAt: new Date(now.getTime() - 5_400_000).toISOString(), isRead: true, isReported: false }
];

export const notificationSeed: NotificationItem[] = [
  { id: "notification-1", title: "Ranking increased", body: "You moved up on the South Beach total board.", kind: "Ranking", target: "/leaderboards", createdAt: new Date(now.getTime() - 3_600_000).toISOString(), isRead: false },
  { id: "notification-2", title: "Friend request", body: "Mia Santos sent you a friend request.", kind: "Friend", target: "/friends", createdAt: new Date(now.getTime() - 7_200_000).toISOString(), isRead: false }
];
