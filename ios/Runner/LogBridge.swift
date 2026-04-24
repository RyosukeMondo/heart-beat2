import Flutter
import UIKit

#if DEBUG

/// DEBUG-only log bridge that captures stdout/stderr and forwards them
/// over a Flutter MethodChannel so they can be written to the native-ios
/// log file alongside rust and dart logs.
final class LogBridge {
    private let channel: FlutterMethodChannel
    private var pipeReadFd: Int32 = -1
    private var backgroundThread: Thread?

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "heart_beat/native_log",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            // Handlers can be added here if Dart needs to query bridge state.
            result(FlutterMethodNotImplemented)
        }

        startCapture()
    }

    private func startCapture() {
        // Create a pipe for stdout and stderr.
        var pipefd = [Int32](repeating: 0, count: 2)
        guard pipe(pipefd) == 0 else {
            print("[LogBridge] pipe() failed: \(errno)")
            return
        }

        let readFd = pipefd[0]
        let writeFd = pipefd[1]

        // Dup the write end to both stdout and stderr.
        guard dup2(writeFd, STDOUT_FILENO) != -1,
              dup2(writeFd, STDERR_FILENO) != -1 else {
            print("[LogBridge] dup2() failed: \(errno)")
            close(pipefd[0])
            close(pipefd[1])
            return
        }

        // Close the original writeFd — we've already duplicated it.
        close(writeFd)

        pipeReadFd = readFd

        // Spawn a background thread to drain the pipe.
        backgroundThread = Thread { [weak self] in
            self?.readLoop(readFd: readFd)
        }
        backgroundThread?.name = "LogBridge.readLoop"
        backgroundThread?.qualityOfService = .utility
        backgroundThread?.start()
    }

    private func readLoop(readFd: Int32) {
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while true {
            let n = read(readFd, &buffer, bufferSize)
            if n <= 0 {
                break
            }

            // Convert to String, split on newlines, send each line.
            let data = Data(bytes: buffer, count: n)
            if let text = String(data: data, encoding: .utf8) {
                let lines = text.components(separatedBy: "\n")
                for line in lines where !line.isEmpty {
                    DispatchQueue.main.async { [weak self] in
                        self?.channel.invokeMethod("onNativeLog", arguments: line)
                    }
                }
            }
        }

        close(readFd)
    }

    func dispose() {
        // Closing the read end will cause readLoop to exit.
        if pipeReadFd != -1 {
            close(pipeReadFd)
            pipeReadFd = -1
        }
        backgroundThread?.cancel()
        backgroundThread = nil
    }

    deinit {
        dispose()
    }
}

#endif