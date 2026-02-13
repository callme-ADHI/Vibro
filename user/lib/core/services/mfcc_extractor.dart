// VIBRO — Pure Dart MFCC Feature Extraction
// Matches librosa.feature.mfcc(y, sr=16000, n_mfcc=40) defaults
import 'dart:math';
import 'dart:typed_data';

class MfccExtractor {
  final int sampleRate;
  final int nFft;
  final int hopLength;
  final int nMels;
  final int nMfcc;
  final int maxPadLen;

  late final Float64List _window;
  late final List<Float64List> _melBasis;
  late final List<Float64List> _dctBasis;

  MfccExtractor({
    this.sampleRate = 16000,
    this.nFft = 2048,
    this.hopLength = 512,
    this.nMels = 128,
    this.nMfcc = 40,
    this.maxPadLen = 64,
  }) {
    _window = _hammingWindow(nFft);
    _melBasis = _createMelFilterbank();
    _dctBasis = _createDctMatrix();
  }

  // ═══════════════════════════════════════════
  //  PUBLIC API
  // ═══════════════════════════════════════════

  /// Extract MFCC from raw audio samples (float, range [-1, 1]).
  /// Returns a flat Float32List of length [nMfcc * maxPadLen] (e.g. 2560).
  Float32List extract(List<double> audio) {
    if (audio.isEmpty) return Float32List(nMfcc * maxPadLen);

    // Center-pad (matching librosa center=True)
    final pad = nFft ~/ 2;
    final padded = Float64List(audio.length + 2 * pad);
    // Reflect padding at edges (matching librosa 'reflect' mode)
    for (int i = 0; i < pad; i++) {
      padded[pad - 1 - i] = audio[min(i + 1, audio.length - 1)];
    }
    for (int i = 0; i < audio.length; i++) {
      padded[pad + i] = audio[i];
    }
    for (int i = 0; i < pad; i++) {
      padded[pad + audio.length + i] =
          audio[max(audio.length - 2 - i, 0)];
    }

    // Number of STFT frames
    final nFrames = max(1, ((padded.length - nFft) ~/ hopLength) + 1);
    final nBins = nFft ~/ 2 + 1;

    // Allocate MFCC matrix [nMfcc x maxPadLen]
    final mfcc = List.generate(nMfcc, (_) => Float64List(maxPadLen));
    final actualFrames = min(nFrames, maxPadLen);

    // Reusable frame buffer
    final frame = Float64List(nFft);

    for (int t = 0; t < actualFrames; t++) {
      final start = t * hopLength;

      // Apply window
      for (int i = 0; i < nFft; i++) {
        final idx = start + i;
        frame[i] = (idx < padded.length ? padded[idx] : 0.0) * _window[i];
      }

      // FFT → power spectrum
      final fft = _fft(frame);
      final power = Float64List(nBins);
      for (int i = 0; i < nBins; i++) {
        power[i] =
            (fft[0][i] * fft[0][i] + fft[1][i] * fft[1][i]) / nFft;
      }

      // Mel filterbank → log (dB Scale: 10 * log10)
      final melLog = Float64List(nMels);
      for (int m = 0; m < nMels; m++) {
        double sum = 0.0;
        final filter = _melBasis[m];
        for (int k = 0; k < nBins; k++) {
          sum += filter[k] * power[k];
        }
        // Librosa uses power_to_db -> 10 * log10(x) = 10 * ln(x) / ln10
        melLog[m] = 10.0 * log(max(sum, 1e-10)) / ln10;
      }

      // DCT → MFCC coefficients for this frame
      for (int c = 0; c < nMfcc; c++) {
        double sum = 0.0;
        final basis = _dctBasis[c];
        for (int m = 0; m < nMels; m++) {
          sum += basis[m] * melLog[m];
        }
        mfcc[c][t] = sum;
      }
    }

    // Flatten row-major [nMfcc, maxPadLen]
    final result = Float32List(nMfcc * maxPadLen);
    int idx = 0;
    for (int c = 0; c < nMfcc; c++) {
      for (int t = 0; t < maxPadLen; t++) {
        // REMOVED normalization to match Python script (raw MFCCs)
        result[idx++] = mfcc[c][t]; 
      }
    }
    return result;
  }

  /// Trim leading and trailing silence to match librosa.effects.trim behavior.
  /// Training uses trim on every sample; inference must do the same.
  /// topDb: threshold in dB below peak to consider as silence (default 60, matches librosa).
  static List<double> trimSilence(List<double> audio, {double topDb = 60}) {
    if (audio.isEmpty) return audio;
    double ref = 0.0;
    for (int i = 0; i < audio.length; i++) {
      final a = audio[i].abs();
      if (a > ref) ref = a;
    }
    if (ref < 1e-10) return audio;
    final threshold = ref * pow(10.0, -topDb / 20.0);
    int first = 0;
    for (; first < audio.length && audio[first].abs() <= threshold; first++) {}
    int last = audio.length - 1;
    for (; last >= first && audio[last].abs() <= threshold; last--) {}
    final len = last - first + 1;
    if (len < 512) return audio;
    return audio.sublist(first, last + 1);
  }

  /// Compute actual frame count for given audio length (for correct mean).
  static int actualFrameCount(int audioLength, int nFft, int hopLength, int maxPadLen) {
    final pad = nFft ~/ 2;
    final paddedLen = audioLength + 2 * pad;
    final n = ((paddedLen - nFft) ~/ hopLength) + 1;
    return min(max(1, n), maxPadLen);
  }

  /// Convert raw PCM bytes (16-bit LE signed) to normalised doubles.
  static List<double> pcmBytesToDoubles(Uint8List bytes) {
    final bd = ByteData.sublistView(bytes);
    final samples = List<double>.filled(bytes.length ~/ 2, 0.0);
    for (int i = 0; i < samples.length; i++) {
      samples[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }

  // ═══════════════════════════════════════════
  //  FFT — Radix-2 Cooley-Tukey
  // ═══════════════════════════════════════════

  /// Returns [realPart, imagPart] each of length n.
  List<Float64List> _fft(Float64List x) {
    final n = x.length;
    final logN = _log2(n);
    final real = Float64List(n);
    final imag = Float64List(n);

    // Bit-reversal permutation
    for (int i = 0; i < n; i++) {
      real[_bitReverse(i, logN)] = x[i];
    }

    // Butterfly stages
    for (int size = 2; size <= n; size *= 2) {
      final half = size ~/ 2;
      final angle = -2.0 * pi / size;
      for (int i = 0; i < n; i += size) {
        for (int j = 0; j < half; j++) {
          final wR = cos(angle * j);
          final wI = sin(angle * j);
          final idx = i + j + half;
          final tR = wR * real[idx] - wI * imag[idx];
          final tI = wR * imag[idx] + wI * real[idx];
          real[idx] = real[i + j] - tR;
          imag[idx] = imag[i + j] - tI;
          real[i + j] += tR;
          imag[i + j] += tI;
        }
      }
    }
    return [real, imag];
  }

  int _log2(int n) {
    int r = 0;
    int v = n;
    while (v > 1) {
      v >>= 1;
      r++;
    }
    return r;
  }

  int _bitReverse(int x, int bits) {
    int result = 0;
    for (int i = 0; i < bits; i++) {
      result = (result << 1) | (x & 1);
      x >>= 1;
    }
    return result;
  }

  // ═══════════════════════════════════════════
  //  Hamming Window
  // ═══════════════════════════════════════════

  Float64List _hammingWindow(int n) {
    final w = Float64List(n);
    for (int i = 0; i < n; i++) {
      w[i] = 0.54 - 0.46 * cos(2.0 * pi * i / (n - 1));
    }
    return w;
  }

  // ═══════════════════════════════════════════
  //  Mel Filterbank
  // ═══════════════════════════════════════════

  double _hzToMel(double hz) => 2595.0 * log(1.0 + hz / 700.0) / ln10;
  double _melToHz(double mel) => 700.0 * (pow(10.0, mel / 2595.0) - 1.0);

  List<Float64List> _createMelFilterbank() {
    final fMax = sampleRate / 2.0;
    final melMin = _hzToMel(0.0);
    final melMax = _hzToMel(fMax);

    // n_mels + 2 equally spaced mel points
    final melPoints = List<double>.generate(
      nMels + 2,
      (i) => melMin + i * (melMax - melMin) / (nMels + 1),
    );
    final hzPoints = melPoints.map(_melToHz).toList();

    // FFT bin indices
    final nBins = nFft ~/ 2 + 1;
    final bins = hzPoints
        .map((hz) => ((nFft + 1) * hz / sampleRate).floor())
        .toList();

    // Triangular filters
    final fb = List.generate(nMels, (_) => Float64List(nBins));
    for (int m = 0; m < nMels; m++) {
      // Rising slope
      for (int k = bins[m]; k < bins[m + 1] && k < nBins; k++) {
        if (k >= 0 && bins[m + 1] != bins[m]) {
          fb[m][k] = (k - bins[m]) / (bins[m + 1] - bins[m]);
        }
      }
      // Falling slope
      for (int k = bins[m + 1]; k < bins[m + 2] && k < nBins; k++) {
        if (k >= 0 && bins[m + 2] != bins[m + 1]) {
          fb[m][k] = (bins[m + 2] - k) / (bins[m + 2] - bins[m + 1]);
        }
      }
      // Slaney normalization (area = 1)
      final bandwidth = hzPoints[m + 2] - hzPoints[m];
      if (bandwidth > 0) {
        final norm = 2.0 / bandwidth;
        for (int k = 0; k < nBins; k++) {
          fb[m][k] *= norm;
        }
      }
    }
    return fb;
  }

  // ═══════════════════════════════════════════
  //  DCT-II (Orthonormal, matching scipy/librosa)
  // ═══════════════════════════════════════════

  List<Float64List> _createDctMatrix() {
    final m = List.generate(nMfcc, (_) => Float64List(nMels));
    for (int c = 0; c < nMfcc; c++) {
      for (int n = 0; n < nMels; n++) {
        m[c][n] = cos(pi * c * (2 * n + 1) / (2 * nMels));
      }
    }
    // Ortho normalization
    final scale0 = sqrt(1.0 / nMels);
    final scaleK = sqrt(2.0 / nMels);
    for (int n = 0; n < nMels; n++) {
      m[0][n] *= scale0;
    }
    for (int c = 1; c < nMfcc; c++) {
      for (int n = 0; n < nMels; n++) {
        m[c][n] *= scaleK;
      }
    }
    return m;
  }
}
