/// A single HR sample with resolved BPM and timestamp for synchronous access.
class HrSample {
  final int bpm;
  final int tsMs;

  HrSample({required this.bpm, required this.tsMs});
}