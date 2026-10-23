const STORAGE_REMOVE_BATCH_SIZE = 1000;

export async function removeStoragePathsInBatches(storage, bucket, paths) {
  for (let start = 0; start < paths.length; start += STORAGE_REMOVE_BATCH_SIZE) {
    const { error } = await storage.from(bucket).remove(paths.slice(start, start + STORAGE_REMOVE_BATCH_SIZE));
    if (error) return error;
  }

  return null;
}
