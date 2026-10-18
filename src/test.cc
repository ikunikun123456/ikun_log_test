#define IKUN_LOG_QUEUE_CAPACITY 131072
#include "benchmark/benchmark.h"
#include "ikun_log/log.h"
#include "spdlog/async.h"
#include "spdlog/sinks/basic_file_sink.h"

static spdlog::logger &get_async_logger() {
  static auto logger = [] {
    spdlog::init_thread_pool(131072, 2);
    auto l = spdlog::basic_logger_mt<spdlog::async_factory>("async_file_logger",
                                                            "logs/async.log");
    l->set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%l] %v");
    return l;
  }();
  return *logger;
}

static void BM_TestSpdlog(benchmark::State &state) {
  auto async_file = get_async_logger();
  int count = state.range();
  int remain = count % state.threads() < state.thread_index() ? 1 : 0;

  int thread_count = count / state.threads() + remain;
  for (int i = 0; i <= 100; i++) {
    async_file.info(
        "This message is logged asynchronously!This message! "
        "This message is logged asynchronously!This message is logged ");
  }

  for (auto _ : state) {
    // auto begin = std::chrono::steady_clock::now();
    for (int i = 0; i <= thread_count; i++) {
      async_file.info("This message is logged asynchronously!This message is!"
                      "This message is logged asynchronously!This message is ");
    }
  }
}

static void BM_TestIkunlog(benchmark::State &state) {
  int count = state.range();

  int remain = count % state.threads() < state.thread_index() ? 1 : 0;

  int thread_count = count / state.threads() + remain;

  ikun::log::AsyncInfo("This message is logged asynchronously");
  for (int i = 0; i <= 100; i++) {
    ikun::log::AsyncInfo(
        "This message is logged asynchronously!This message! "
        "This message is logged asynchronously!This message is logged ");
  }

  for (auto _ : state) {
    for (int i = 0; i <= thread_count; i++) {
      ikun::log::AsyncInfo(
          "This message is logged asynchronously!This message! "
          "This message is logged asynchronously!This message is logged ");
    }
  }
}

// BENCHMARK(BM_TestIkunlog)
//     ->Arg(1000000)
//     ->Threads(1)
//     ->Threads(2)
//     ->Threads(4)
//     ->Threads(8)
//     ->UseRealTime()
//     ->Iterations(1);

// BENCHMARK(BM_TestSpdlog)
//     ->Arg(1000000)
//     ->Threads(1)
//     ->Threads(2)
//     ->Threads(4)
//     ->Threads(8)
//     ->UseRealTime()
//     ->Iterations(1);

BENCHMARK(BM_TestIkunlog)
    ->Arg(10000)
    ->Threads(1)
    ->Threads(2)
    ->Threads(4)
    ->Threads(8)
    ->UseRealTime()
    ->Iterations(1);

BENCHMARK(BM_TestSpdlog)
    ->Arg(10000)
    ->Threads(1)
    ->Threads(2)
    ->Threads(4)
    ->Threads(8)
    ->UseRealTime()
    ->Iterations(1);

BENCHMARK_MAIN();