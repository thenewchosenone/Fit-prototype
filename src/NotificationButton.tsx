import { Bell } from "lucide-react";
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { formatRelativeTime } from "./platform";
import { webFeatures } from "./featureAvailability";
import { useTracker } from "./store";

export function NotificationButton() {
  const { state, dispatch } = useTracker();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const notifications = state.notifications.filter((item) => {
    if (!webFeatures.community && (item.kind === "Forum" || item.target.startsWith("/community"))) return false;
    if (!webFeatures.messaging && (item.kind === "Message" || item.target.startsWith("/messages"))) return false;
    return true;
  });
  const unread = notifications.filter((item) => !item.isRead).length;
  return <div className="notification-control"><button className="icon-button" aria-label={`Notifications, ${unread} unread`} onClick={() => setOpen(!open)}><Bell />{unread > 0 && <span>{unread}</span>}</button>{open && <div className="notification-popover"><header><h3>Notifications</h3>{unread > 0 && <button onClick={() => dispatch({ type: "MARK_ALL_NOTIFICATIONS_READ" })}>Read all</button>}</header>{notifications.map((notification) => <button key={notification.id} className={notification.isRead ? "" : "unread"} onClick={() => { dispatch({ type: "MARK_NOTIFICATION_READ", notificationId: notification.id }); setOpen(false); navigate(notification.target); }}><span className="icon-tile"><Bell /></span><span><strong>{notification.title}</strong><small>{notification.body}</small><time>{formatRelativeTime(notification.createdAt)}</time></span></button>)}</div>}</div>;
}
