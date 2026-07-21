/// Shared cache-freshness check used by every TTL-caching repository — previously hand-copied
/// as a near-identical private helper in each one. Each repository keeps its own cache storage,
/// TTL value(s), and invalidation API exactly as they are; only this one comparison is shared.
bool isCacheValid(DateTime? cachedAt, Duration ttl) =>
    cachedAt != null && DateTime.now().difference(cachedAt) < ttl;
