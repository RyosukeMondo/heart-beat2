//! Android JNI entry point.
//!
//! Lives outside `crate::api` so flutter_rust_bridge codegen does not pick it up
//! and emit `jint` / `JavaVM` references into the iOS C bridge header.

#![cfg(target_os = "android")]

use log::LevelFilter;

/// JNI_OnLoad - Initialize Android context and btleplug for JNI operations.
///
/// Called by the Android runtime when the native library is loaded. Initializes
/// ndk-context and btleplug while we have access to the app's classloader.
///
/// cbindgen:ignore
#[no_mangle]
pub extern "C" fn JNI_OnLoad(vm: jni::JavaVM, _res: *mut std::os::raw::c_void) -> jni::sys::jint {
    use std::ffi::c_void;

    android_logger::init_once(
        android_logger::Config::default()
            .with_max_level(LevelFilter::Debug)
            .with_tag("heart_beat"),
    );

    log::info!("JNI_OnLoad: Starting initialization");

    let vm_ptr = vm.get_java_vm_pointer() as *mut c_void;
    unsafe {
        ndk_context::initialize_android_context(vm_ptr, _res);
    }
    log::info!("JNI_OnLoad: NDK context initialized");

    match vm.get_env() {
        Ok(mut env) => {
            log::info!("JNI_OnLoad: Got JNI environment");

            log::info!("JNI_OnLoad: Initializing jni-utils");
            if let Err(e) = jni_utils::init(&mut env) {
                log::error!("JNI_OnLoad: jni-utils init failed: {:?}", e);
            } else {
                log::info!("JNI_OnLoad: jni-utils initialized successfully");
            }

            log::info!("JNI_OnLoad: Initializing btleplug");
            match btleplug::platform::init(&mut env) {
                Ok(()) => {
                    log::info!("JNI_OnLoad: btleplug initialized successfully");
                }
                Err(e) => {
                    log::error!("JNI_OnLoad: btleplug init failed: {}", e);
                }
            }
        }
        Err(e) => {
            log::error!("JNI_OnLoad: Failed to get JNI environment: {:?}", e);
        }
    }

    log::info!("JNI_OnLoad: Initialization complete");
    jni::JNIVersion::V6.into()
}
