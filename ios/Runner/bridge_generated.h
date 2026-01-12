#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
// EXTRA BEGIN
typedef struct DartCObject *WireSyncRust2DartDco;
typedef struct WireSyncRust2DartSse {
  uint8_t *ptr;
  int32_t len;
} WireSyncRust2DartSse;

typedef int64_t DartPort;
typedef bool (*DartPostCObjectFnType)(DartPort port_id, void *message);
void store_dart_post_cobject(DartPostCObjectFnType ptr);
// EXTRA END
typedef struct _Dart_Handle* Dart_Handle;

typedef struct wire_cst_list_prim_u_8_strict {
  uint8_t *ptr;
  int32_t len;
} wire_cst_list_prim_u_8_strict;

typedef struct wire_cst_api_battery_level {
  uint8_t *level;
  bool is_charging;
  uint64_t timestamp;
} wire_cst_api_battery_level;

typedef struct wire_cst_discovered_device {
  struct wire_cst_list_prim_u_8_strict *id;
  struct wire_cst_list_prim_u_8_strict *name;
  int16_t rssi;
} wire_cst_discovered_device;

typedef struct wire_cst_list_discovered_device {
  struct wire_cst_discovered_device *ptr;
  int32_t len;
} wire_cst_list_discovered_device;

typedef struct wire_cst_log_message {
  struct wire_cst_list_prim_u_8_strict *level;
  struct wire_cst_list_prim_u_8_strict *target;
  uint64_t timestamp;
  struct wire_cst_list_prim_u_8_strict *message;
} wire_cst_log_message;

void frbgen_heart_beat_wire__crate__api__connect_device(int64_t port_,
                                                        struct wire_cst_list_prim_u_8_strict *device_id);

void frbgen_heart_beat_wire__crate__api__create_hr_stream(int64_t port_,
                                                          struct wire_cst_list_prim_u_8_strict *sink);

void frbgen_heart_beat_wire__crate__api__disconnect(int64_t port_);

void frbgen_heart_beat_wire__crate__api__dummy_battery_level_for_codegen(int64_t port_);

void frbgen_heart_beat_wire__crate__api__emit_battery_data(int64_t port_,
                                                           struct wire_cst_api_battery_level *data);

void frbgen_heart_beat_wire__crate__api__emit_hr_data(int64_t port_, uintptr_t data);

void frbgen_heart_beat_wire__crate__api__hr_battery_level(int64_t port_, uintptr_t data);

void frbgen_heart_beat_wire__crate__api__hr_filtered_bpm(int64_t port_, uintptr_t data);

void frbgen_heart_beat_wire__crate__api__hr_raw_bpm(int64_t port_, uintptr_t data);

void frbgen_heart_beat_wire__crate__api__hr_rmssd(int64_t port_, uintptr_t data);

void frbgen_heart_beat_wire__crate__api__hr_timestamp(int64_t port_, uintptr_t data);

void frbgen_heart_beat_wire__crate__api__hr_zone(int64_t port_, uintptr_t data, uint16_t max_hr);

void frbgen_heart_beat_wire__crate__api__init_logging(int64_t port_,
                                                      struct wire_cst_list_prim_u_8_strict *sink);

void frbgen_heart_beat_wire__crate__api__init_panic_handler(int64_t port_);

void frbgen_heart_beat_wire__crate__api__init_platform(int64_t port_);

void frbgen_heart_beat_wire__crate__api__scan_devices(int64_t port_);

void frbgen_heart_beat_wire__crate__api__start_mock_mode(int64_t port_);

void frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiFilteredHeartRate(const void *ptr);

void frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiFilteredHeartRate(const void *ptr);

struct wire_cst_api_battery_level *frbgen_heart_beat_cst_new_box_autoadd_api_battery_level(void);

double *frbgen_heart_beat_cst_new_box_autoadd_f_64(double value);

uint8_t *frbgen_heart_beat_cst_new_box_autoadd_u_8(uint8_t value);

struct wire_cst_list_discovered_device *frbgen_heart_beat_cst_new_list_discovered_device(int32_t len);

struct wire_cst_list_prim_u_8_strict *frbgen_heart_beat_cst_new_list_prim_u_8_strict(int32_t len);

/**
 * JNI_OnLoad - Initialize Android context and btleplug for JNI operations
 *
 * This function is called by the Android runtime when the native library is loaded.
 * It initializes the ndk-context and btleplug while we have access to the app's classloader.
 */
jint JNI_OnLoad(JavaVM vm, void *_res);
static int64_t dummy_method_to_enforce_bundling(void) {
    int64_t dummy_var = 0;
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_box_autoadd_api_battery_level);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_box_autoadd_f_64);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_box_autoadd_u_8);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_list_discovered_device);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_list_prim_u_8_strict);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiFilteredHeartRate);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiFilteredHeartRate);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__connect_device);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__create_hr_stream);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__disconnect);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__dummy_battery_level_for_codegen);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__emit_battery_data);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__emit_hr_data);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__hr_battery_level);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__hr_filtered_bpm);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__hr_raw_bpm);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__hr_rmssd);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__hr_timestamp);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__hr_zone);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__init_logging);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__init_panic_handler);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__init_platform);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__scan_devices);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__start_mock_mode);
    dummy_var ^= ((int64_t) (void*) store_dart_post_cobject);
    return dummy_var;
}
