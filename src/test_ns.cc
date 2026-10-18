#include <benchmark/benchmark.h>
#include <chrono>

#if defined(_MSC_VER)
#define NOINLINE __declspec(noinline)
#else
#define NOINLINE __attribute__((noinline))
#endif

static std::size_t num = 30015155;

static void BM_TestStd(benchmark::State &state) {
  int count = state.range();

  int remain = count % state.threads() < state.thread_index() ? 1 : 0;

  int thread_count = count / state.threads() + remain;

  static std::array<char, 10> str{};

  for (auto _ : state) {
    for (int i = 0; i <= thread_count; i++) {
      auto x = std::to_chars(str.begin(), str.end(), num);
      benchmark::DoNotOptimize(x);
    }
  }
}
consteval std::array<std::array<char, 4>, 1000> GetTimeArr() {
  std::array<std::array<char, 4>, 1000> a{};
  for (int i = 0; i < 1000; ++i) {
    a[i][0] = char('0' + i / 100);
    a[i][1] = char('0' + (i / 10) % 10);
    a[i][2] = char('0' + i % 10);
    a[i][3] = '\0';
  }
  return a;
}

constexpr std::array<std::array<char, 4>, 1000> time_arr = GetTimeArr();

[[maybe_unused]] static std::array<char, 10> GetNs(std::size_t num) {
  std::array<char, 10> result;
  int count = num % 1000;
  std::array<char, 4> temp_arr = time_arr[count];
  result[6] = temp_arr[0];
  result[7] = temp_arr[1];
  result[8] = temp_arr[2];
  num /= 1000;
  count = num % 1000;
  temp_arr = time_arr[count];
  result[3] = temp_arr[0];
  result[4] = temp_arr[1];
  result[5] = temp_arr[2];
  num /= 1000;
  count = num % 1000;
  temp_arr = time_arr[count];
  result[0] = temp_arr[0];
  result[1] = temp_arr[1];
  result[2] = temp_arr[2];
  result[9] = '\0';
  return result;
}

static void BM_TestMy(benchmark::State &state) {
  int count = state.range();

  int remain = count % state.threads() < state.thread_index() ? 1 : 0;

  int thread_count = count / state.threads() + remain;

  for (auto _ : state) {
    for (int i = 0; i <= thread_count; i++) {
      auto x = GetNs(num);
      benchmark::DoNotOptimize(x);
    }
  }
}

NOINLINE int empty_fn_int() { return 0; }

static void BM_NoInline_Void(benchmark::State &state) {
  int count = state.range();

  int remain = count % state.threads() < state.thread_index() ? 1 : 0;

  int thread_count = count / state.threads() + remain;

  for (auto _ : state) {
    for (int i = 0; i <= thread_count; i++) {
      auto x = empty_fn_int();
      benchmark::DoNotOptimize(x);
    }
  }
}

BENCHMARK(BM_TestStd)
    ->Arg(10000000)
    ->Threads(1)
    ->Threads(2)
    ->Threads(4)
    ->Threads(8)
    ->UseRealTime()
    ->Iterations(100);
BENCHMARK(BM_TestMy)
    ->Arg(10000000)
    ->Threads(1)
    ->Threads(2)
    ->Threads(4)
    ->Threads(8)
    ->UseRealTime()
    ->Iterations(100);
BENCHMARK(BM_NoInline_Void)
    ->Arg(10000000)
    ->Threads(1)
    ->Threads(2)
    ->Threads(4)
    ->Threads(8)
    ->UseRealTime()
    ->Iterations(100);

BENCHMARK_MAIN();