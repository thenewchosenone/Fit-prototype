export async function clearCompletedLiftRemovalPayload(database, requestID) {
  const { data, error } = await database.from("lift_removal_requests")
    .update({ lift_snapshot: {}, storage_objects: [] })
    .eq("id", requestID)
    .eq("status", "completed")
    .select("id")
    .maybeSingle();

  if (error) return error;
  return data?.id === requestID ? null : new Error("Completed lift removal request was not found");
}
