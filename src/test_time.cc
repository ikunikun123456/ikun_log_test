#include <benchmark/benchmark.h>
#include <chrono>
#include <ikun_log/detail/tsc_to_ns.h>

static void BM_TestTscns(benchmark::State &state) {
  int count = state.range();

  int remain = count % state.threads() < state.thread_index() ? 1 : 0;

  int thread_count = count / state.threads() + remain;
  static thread_local ikun::log::detail::TscToNs tsc_to_ns =
      ikun::log::detail::TscToNs();

  for (auto _ : state) {
    for (int i = 0; i <= thread_count; i++) {
      auto x = tsc_to_ns.GetNs();
      benchmark::DoNotOptimize(x);
    }
  }
}

static void BM_TestSysns(benchmark::State &state) {
  int count = state.range();

  int remain = count % state.threads() < state.thread_index() ? 1 : 0;

  int thread_count = count / state.threads() + remain;

  for (auto _ : state) {
    for (int i = 0; i <= thread_count; i++) {
      auto x = std::chrono::system_clock::now();
      benchmark::DoNotOptimize(x);
    }
  }
}

BENCHMARK(BM_TestTscns)
    ->Arg(1000000)
    ->Threads(1)
    ->Threads(2)
    ->Threads(4)
    ->Threads(8)
    ->UseRealTime();
BENCHMARK(BM_TestSysns)
    ->Arg(1000000)
    ->Threads(1)
    ->Threads(2)
    ->Threads(4)
    ->Threads(8)
    ->UseRealTime();

BENCHMARK_MAIN();