'use client';

import { QueryClient } from '@tanstack/react-query';
import { PersistQueryClientProvider } from '@tanstack/react-query-persist-client';
import type { Persister } from '@tanstack/react-query-persist-client';
import { useState } from 'react';
import { get, set, del } from 'idb-keyval';

/**
 * Bump this when deploying breaking data-shape changes.
 * Old caches with a different buster are automatically discarded.
 */
const CACHE_BUSTER = 'v1';

/** IndexedDB-backed persister for React Query cache */
function createIDBPersister(): Persister {
  const idbKey = `careerforge-rq-cache-${CACHE_BUSTER}`;
  
  // Sanitize client data to remove non-serializable properties (functions, promises)
  const sanitizeClient = (client: unknown): unknown => {
    if (client === null || client === undefined) return client;
    if (typeof client === 'function') return undefined;
    if (typeof client === 'object') {
      if (Array.isArray(client)) {
        return client.map(sanitizeClient);
      }
      const sanitized: Record<string, unknown> = {};
      for (const [key, value] of Object.entries(client)) {
        const sanitizedValue = sanitizeClient(value);
        if (sanitizedValue !== undefined) {
          sanitized[key] = sanitizedValue;
        }
      }
      return sanitized;
    }
    return client;
  };
  
  return {
    persistClient: async (client) => {
      try {
        const sanitized = sanitizeClient(client);
        await set(idbKey, sanitized);
      } catch (error) {
        console.warn('Failed to persist query cache:', error);
      }
    },
    restoreClient: async () => {
      try {
        return await get(idbKey);
      } catch {
        return undefined;
      }
    },
    removeClient: async () => {
      await del(idbKey);
    },
  };
}

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 2 * 60 * 1000,   // 2 min default (overridden per-query)
            gcTime: 15 * 60 * 1000,     // 15 min garbage collection
            refetchOnWindowFocus: false,
          },
        },
      })
  );

  const [persister] = useState(() => createIDBPersister());

  return (
    <PersistQueryClientProvider
      client={queryClient}
      persistOptions={{
        persister,
        maxAge: 24 * 60 * 60 * 1000,  // discard cache older than 24 hours
        buster: CACHE_BUSTER,
      }}
    >
      {children}
    </PersistQueryClientProvider>
  );
}
