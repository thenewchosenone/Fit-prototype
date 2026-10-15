import { useEffect, useState } from "react";
import { blobToDataUrl, profileMediaStore, profilePhotoUpdatedEvent } from "./profileMedia";
import type { UserProfile } from "./types";

export function useProfilePhoto(profileId: string) {
  const [source, setSource] = useState<string | null>(null);
  useEffect(() => {
    let active = true;
    const load = async () => {
      const blob = await profileMediaStore.get(profileId);
      if (active) setSource(blob ? await blobToDataUrl(blob) : null);
    };
    void load();
    const update = (event: Event) => {
      if ((event as CustomEvent<{ profileId: string }>).detail?.profileId === profileId) void load();
    };
    window.addEventListener(profilePhotoUpdatedEvent, update);
    return () => { active = false; window.removeEventListener(profilePhotoUpdatedEvent, update); };
  }, [profileId]);
  return source;
}

export function ProfileAvatar({ profile, className = "", size = "normal" }: { profile: UserProfile; className?: string; size?: "normal" | "large" }) {
  const source = useProfilePhoto(profile.id);
  const initials = profile.displayName.split(" ").map((part) => part[0]).join("").slice(0, 2);
  return <span className={`${className} profile-photo ${size}`.trim()}>{source ? <img src={source} alt={`${profile.displayName} profile`} /> : initials}</span>;
}
