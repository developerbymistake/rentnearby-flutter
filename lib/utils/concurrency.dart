/// Runs `task(i)` for every index in `[0, length)`, at most [limit] running at
/// once — a small worker pool where each worker pulls the next unclaimed
/// index until exhausted. Use in place of an unbounded
/// `Future.wait(List.generate(...))` when the tasks are real network calls
/// (e.g. parallel photo uploads) that shouldn't all fire simultaneously.
///
/// NOT a drop-in equivalent of `Future.wait` for tasks that can throw: if
/// `task(i)` throws, that worker's loop stops pulling further indices —
/// other still-running workers keep draining the remaining queue, but if
/// every worker happens to die before the queue is empty, the leftover
/// indices are silently never attempted (no exception, no result). Every
/// current caller's `task` always catches its own errors and resolves to a
/// `bool` instead of rethrowing, so this can't happen today — but a future
/// caller whose task can throw must catch internally rather than relying on
/// this function to surface or retry failures.
Future<void> runIndexedWithLimit(int length, Future<void> Function(int i) task, {int limit = 2}) async {
  if (length == 0) return;
  var next = 0;
  Future<void> worker() async {
    while (next < length) {
      final i = next++;
      await task(i);
    }
  }
  await Future.wait(List.generate(limit.clamp(1, length), (_) => worker()));
}
