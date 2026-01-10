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

typedef struct wire_cst_discovered_device {
  struct wire_cst_list_prim_u_8_strict *id;
  struct wire_cst_list_prim_u_8_strict *name;
  int16_t rssi;
} wire_cst_discovered_device;

typedef struct wire_cst_list_discovered_device {
  struct wire_cst_discovered_device *ptr;
  int32_t len;
} wire_cst_list_discovered_device;

void frbgen_heart_beat_wire__crate__api__connect_device(int64_t port_,
                                                        struct wire_cst_list_prim_u_8_strict *device_id);

void frbgen_heart_beat_wire__crate__api__create_hr_stream(int64_t port_,
                                                          struct wire_cst_list_prim_u_8_strict *sink);

void frbgen_heart_beat_wire__crate__api__disconnect(int64_t port_);

void frbgen_heart_beat_wire__crate__api__emit_hr_data(int64_t port_, uintptr_t data);

void frbgen_heart_beat_wire__crate__api__scan_devices(int64_t port_);

void frbgen_heart_beat_wire__crate__api__start_mock_mode(int64_t port_);

void frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiFilteredHeartRate(const void *ptr);

void frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiFilteredHeartRate(const void *ptr);

struct wire_cst_list_discovered_device *frbgen_heart_beat_cst_new_list_discovered_device(int32_t len);

struct wire_cst_list_prim_u_8_strict *frbgen_heart_beat_cst_new_list_prim_u_8_strict(int32_t len);
static int64_t dummy_method_to_enforce_bundling(void) {
    int64_t dummy_var = 0;
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_list_discovered_device);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_list_prim_u_8_strict);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiFilteredHeartRate);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiFilteredHeartRate);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__connect_device);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__create_hr_stream);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__disconnect);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__emit_hr_data);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__scan_devices);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__start_mock_mode);
    dummy_var ^= ((int64_t) (void*) store_dart_post_cobject);
    return dummy_var;
}
