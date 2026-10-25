export interface ProfileMediaStore {
  get(profileId: string): Promise<Blob | null>;
  save(profileId: string, image: Blob): Promise<void>;
  remove(profileId: string): Promise<void>;
  clear(): Promise<void>;
}

const DB_NAME = "liftrank-demo-media";
const STORE_NAME = "profile-photos";
export const profilePhotoUpdatedEvent = "liftrank-profile-photo-updated";

class MemoryProfileMediaStore implements ProfileMediaStore {
  private readonly photos = new Map<string, Blob>();
  async get(profileId: string) { return this.photos.get(profileId) ?? null; }
  async save(profileId: string, image: Blob) { this.photos.set(profileId, image); }
  async remove(profileId: string) { this.photos.delete(profileId); }
  async clear() { this.photos.clear(); }
}

class IndexedDbProfileMediaStore implements ProfileMediaStore {
  private open(): Promise<IDBDatabase> {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, 1);
      request.onupgradeneeded = () => {
        if (!request.result.objectStoreNames.contains(STORE_NAME)) request.result.createObjectStore(STORE_NAME);
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  private async request<T>(mode: IDBTransactionMode, operation: (store: IDBObjectStore) => IDBRequest<T>): Promise<T> {
    const database = await this.open();
    return new Promise((resolve, reject) => {
      const transaction = database.transaction(STORE_NAME, mode);
      const request = operation(transaction.objectStore(STORE_NAME));
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
      transaction.oncomplete = () => database.close();
      transaction.onerror = () => reject(transaction.error);
    });
  }

  async get(profileId: string) { return (await this.request("readonly", (store) => store.get(profileId))) as Blob | null ?? null; }
  async save(profileId: string, image: Blob) { await this.request("readwrite", (store) => store.put(image, profileId)); }
  async remove(profileId: string) { await this.request("readwrite", (store) => store.delete(profileId)); }
  async clear() { await this.request("readwrite", (store) => store.clear()); }
}

export const profileMediaStore: ProfileMediaStore = typeof indexedDB === "undefined"
  ? new MemoryProfileMediaStore()
  : new IndexedDbProfileMediaStore();

export function announceProfilePhotoUpdate(profileId: string) {
  window.dispatchEvent(new CustomEvent(profilePhotoUpdatedEvent, { detail: { profileId } }));
}

export function blobToDataUrl(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(blob);
  });
}

export async function clearProfileMedia() {
  await profileMediaStore.clear();
}

