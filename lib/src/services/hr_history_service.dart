import 'package:heart_beat/src/bridge/api_generated.dart/api.dart' as generated;

/// Service for querying historical heart-rate samples from the Rust hr_store.
///
/// Wraps the FRB-generated API to provide a stable, service-layer interface:
/// - [samplesInRange] for time-bounded queries
/// - [rollingAvg] for windowed averages
/// - [latestSample] for the most recent sample
class HrHistoryService {
  HrHistoryService._();

  static final HrHistoryService _instance = HrHistoryService._();

  static HrHistoryService get instance => _instance;

  /// Returns all HR samples with timestamps in the given range (inclusive).
  ///
  /// [startMs] and [endMs] are Unix timestamps in milliseconds.
  /// Returns an empty list if no samples fall within the range.
  Future<List<generated.ApiSample>> samplesInRange({
    required int startMs,
    required int endMs,
  }) {
    return generated.samplesInRange(
      startMs: BigInt.from(startMs),
      endMs: BigInt.from(endMs),
    );
  }

  /// Computes the rolling average BPM over the given window (in seconds)
  /// ending at the latest sample.
  ///
  /// Returns `null` if the store is empty or no samples fall within the window.
  Future<double?> rollingAvg({required int windowSecs}) {
    return generated.rollingAvg(windowSecs: BigInt.from(windowSecs));
  }

  /// Returns the most recent HR sample, or `null` if the store is empty.
  Future<generated.ApiSample?> latestSample() {
    return generated.latestSample();
  }

  /// Returns the BPM of an HR sample.
  Future<int> apiSampleBpm({required generated.ApiSample sample}) {
    return generated.apiSampleBpm(sample: sample);
  }

  /// Returns the Unix timestamp in milliseconds of an HR sample.
  Future<BigInt> apiSampleTsMs({required generated.ApiSample sample}) {
    return generated.apiSampleTsMs(sample: sample);
  }
}
