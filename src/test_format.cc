#include "benchmark/benchmark.h"
#include "ikun_log/log.h"
#include "spdlog/async.h"
#include "spdlog/sinks/basic_file_sink.h"
#include <thread>

static spdlog::logger &get_async_logger() {
  static auto logger = [] {
    spdlog::init_thread_pool(16384, 1);
    auto l = spdlog::basic_logger_mt<spdlog::async_factory>("async_file_logger",
                                                            "logs/async.log");
    l->set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%l] %v");
    return l;
  }();
  return *logger;
}

static void BM_TestSpdlog(benchmark::State &state) {

  // 2. 创建异步文件 Logger
  auto async_file = get_async_logger();

  int count = state.range();

  int remain = count % state.threads() < state.thread_index() ? 1 : 0;

  int thread_count = count / state.threads() + remain;

  std::string msg = "hello";
  std::size_t num = 100;

  for (auto _ : state) {
    for (int i = 0; i <= thread_count; i++) {
      async_file.info(
          "{},{},This message is logged asynchronously!This message is ", msg,
          num);
    }
    using namespace std::chrono;
    state.PauseTiming();
    std::this_thread::sleep_for(10ms);
    state.ResumeTiming();
  }
}

static void BM_TestIkunlog(benchmark::State &state) {
  int count = state.range();

  int remain = count % state.threads() < state.thread_index() ? 1 : 0;

  int thread_count = count / state.threads() + remain;

  ikun::log::AsyncInfo("This message is logged asynchronously");
  std::string msg = "hello";
  std::size_t num = 100;

  for (auto _ : state) {
    for (int i = 0; i <= thread_count; i++) {
      ikun::log::AsyncInfo(
          "{},{},This message is logged asynchronously!This message ", msg,
          num);
    }
    using namespace std::chrono;
    state.PauseTiming();
    std::this_thread::sleep_for(10ms);
    state.ResumeTiming();
  }
}

static void BM_TestSpace(benchmark::State &state) {
  int count = state.range();

  int remain = count % state.threads() < state.thread_index() ? 1 : 0;

  int thread_count = count / state.threads() + remain;

  for (auto _ : state) {
    for (int i = 0; i <= thread_count; i++) {
      benchmark::DoNotOptimize(i);
    }
    using namespace std::chrono;
    state.PauseTiming();
    std::this_thread::sleep_for(10ms);
    state.ResumeTiming();
  }
}

BENCHMARK(BM_TestSpdlog)
    ->Arg(50000)
    ->Threads(1)
    ->Threads(2)
    ->Threads(4)
    ->Threads(8)
    ->UseRealTime()
    ->Iterations(100);
BENCHMARK(BM_TestIkunlog)
    ->Arg(50000)
    ->Threads(1)
    ->Threads(2)
    ->Threads(4)
    ->Threads(8)
    ->UseRealTime()
    ->Iterations(100);
;

BENCHMARK(BM_TestSpace)
    ->Arg(50000)
    ->Threads(1)
    ->Threads(2)
    ->Threads(4)
    ->Threads(8)
    ->UseRealTime()
    ->Iterations(100);
;

BENCHMARK_MAIN();