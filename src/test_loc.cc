#include <benchmark/benchmark.h>
#include <ikun_log/log.h>

template <int N> struct FixString {
  std::array<char, N> str;
  int size;
};

static std::string_view BaseName(std::string_view path) noexcept {
  auto pos = path.find_last_of("/\\");
  path = pos == std::string_view::npos ? path : path.substr(pos + 1);
  if (path.size() > 20) {
    return path.substr(0, 20);
  }
  return path;
}

static FixString<20> StringFromStdsize(std::size_t num) noexcept {
  std::array<char, 10> nums{'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'};
  std::array<char, 20> str{};
  int i = 0;
  while (true) {
    int count = num % 10;
    str[i] = nums.at(count);
    num = num / 10;
    if (num == 0) {
      break;
    }
    i++;
  }
  int temp = i;
  std::array<char, 20> new_str{};
  for (int j = 0; j <= temp; j++, i--) {
    new_str[j] = str[i];
  }
  temp++;
  if (temp >= 8) {
    temp = 7;
  }
  return {new_str, temp};
}

static FixString<30> StringFromLocation(const std::source_location &location) {
  std::string_view filename = BaseName(location.file_name());
  FixString<20> str = StringFromStdsize(location.line());
  std::array<char, 30> new_str{'\t'};
  int i = 1;
  for (; i <= static_cast<int>(filename.size()); i++) {
    new_str[i] = filename.at(i - 1);
  }
  new_str[i++] = ':';
  for (int j = 0; i < str.size + static_cast<int>(filename.size()) + 2;) {
    new_str[i++] = str.str[j++];
  }
  new_str[i++] = '\t';
  return {new_str, i};
};

static void BM_TestMy(benchmark::State &state) {
  int count = state.range();

  int remain = count % state.threads() < state.thread_index() ? 1 : 0;

  int thread_count = count / state.threads() + remain;

  for (auto _ : state) {
    for (int i = 0; i <= thread_count; i++) {
      auto a = std::source_location::current();
      auto x = StringFromLocation(a);
      benchmark::DoNotOptimize(x);
    }
  }
}

BENCHMARK(BM_TestMy)
    ->Arg(1000000)
    ->Threads(1)
    ->Threads(2)
    ->Threads(4)
    ->Threads(8)
    ->UseRealTime()
    ->Iterations(100);

BENCHMARK_MAIN();