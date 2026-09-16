# CoreAudio Real-Time & Process Tap Rules

When implementing or modifying CoreAudio code in SoundLab, especially real-time audio taps and IO callbacks (`AudioDeviceIOProc`), adhere strictly to these rules:

## 1. Real-Time Thread Constraints (`AudioDeviceIOProc`)
The callback passed to `AudioDeviceCreateIOProcIDWithBlock` executes directly on a CoreAudio high-priority real-time kernel thread. Any delay will cause audible glitches, audio dropouts, or watchdog kernel panics.

Inside the IOProc callback:
- **ZERO Heap Allocations**: Never call `malloc`, `free`, allocate Swift classes, allocate arrays, or instantiate objects.
- **ZERO Blocking/Locks**: Never acquire `NSLock`, `pthread_mutex`, `os_unfair_lock`, dispatch semaphores, or condition variables. Priority inversion will cause thread stalls.
- **ZERO Swift Runtime Calls**: Avoid String interpolation, boxing/unboxing, Swift concurrency (`Task {}`, `AsyncStream`), or reflection.
- **ZERO Logging/I/O**: Never call `print`, `NSLog`, `os_log`, or perform disk/network I/O.
- **Atomic State Access**: Share scalar parameters (such as volume gain or mute state) from the main thread to the real-time callback via `UnsafeMutablePointer<Float>` using atomic reads (`atomic_load` / memory ordering relaxed) or preallocated buffers.

## 2. Process Audio Tap (`CATapDescription`) Availability
- Process Audio Tap APIs require **macOS 14.2+**.
- Always annotate process tap classes, controllers, and tests with `@available(macOS 14.2, *)`.
- Guard runtime execution so users on macOS 11.0–14.1 retain full system-wide device switching and master volume control, while per-app UI gracefully hides or indicates macOS 14.2+ requirement.
- Info.plist must declare `NSAudioCaptureUsageDescription` for TCC system audio recording authorization.

## 3. Aggregate Device Lifecycle & Clock Stability
- When tapping an app stream, wrap the tap in a private aggregate device (`kAudioAggregateDeviceIsPrivateKey = true`).
- Enable drift compensation: `kAudioSubTapDriftCompensationKey = true`.
- When the default physical output device changes, teardown and recreate aggregate devices against the new output device UID to prevent clock stalls.
- Teardown tap and aggregate device immediately when the target process terminates via `NSWorkspace.didTerminateApplicationNotification`.

## 4. Concurrency & Isolation
- Keep CoreAudio HAL wrappers nonisolated or actor-isolated appropriately.
- Ensure audio hardware callbacks dispatch state changes to `@MainActor` before triggering UI menu or slider updates.
