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

typedef struct wire_cst_record_i_64_u_16 {
  int64_t field0;
  uint16_t field1;
} wire_cst_record_i_64_u_16;

typedef struct wire_cst_list_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionSummaryPreview {
  uintptr_t *ptr;
  int32_t len;
} wire_cst_list_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionSummaryPreview;

typedef struct wire_cst_list_String {
  struct wire_cst_list_prim_u_8_strict **ptr;
  int32_t len;
} wire_cst_list_String;

typedef struct wire_cst_discovered_device {
  struct wire_cst_list_prim_u_8_strict *id;
  struct wire_cst_list_prim_u_8_strict *name;
  int16_t rssi;
} wire_cst_discovered_device;

typedef struct wire_cst_list_discovered_device {
  struct wire_cst_discovered_device *ptr;
  int32_t len;
} wire_cst_list_discovered_device;

typedef struct wire_cst_list_prim_u_32_strict {
  uint32_t *ptr;
  int32_t len;
} wire_cst_list_prim_u_32_strict;

typedef struct wire_cst_log_message {
  struct wire_cst_list_prim_u_8_strict *level;
  struct wire_cst_list_prim_u_8_strict *target;
  uint64_t timestamp;
  struct wire_cst_list_prim_u_8_strict *message;
} wire_cst_log_message;

void frbgen_heart_beat_wire__crate__api__connect_device(int64_t port_,
                                                        struct wire_cst_list_prim_u_8_strict *device_id);

void frbgen_heart_beat_wire__crate__api__create_battery_stream(int64_t port_,
                                                               struct wire_cst_list_prim_u_8_strict *sink);

void frbgen_heart_beat_wire__crate__api__create_hr_stream(int64_t port_,
                                                          struct wire_cst_list_prim_u_8_strict *sink);

void frbgen_heart_beat_wire__crate__api__create_session_progress_stream(int64_t port_,
                                                                        struct wire_cst_list_prim_u_8_strict *sink);

void frbgen_heart_beat_wire__crate__api__delete_session(int64_t port_,
                                                        struct wire_cst_list_prim_u_8_strict *id);

void frbgen_heart_beat_wire__crate__api__disconnect(int64_t port_);

void frbgen_heart_beat_wire__crate__api__dummy_battery_level_for_codegen(int64_t port_);

void frbgen_heart_beat_wire__crate__api__emit_battery_data(int64_t port_,
                                                           struct wire_cst_api_battery_level *data);

void frbgen_heart_beat_wire__crate__api__emit_hr_data(int64_t port_, uintptr_t data);

void frbgen_heart_beat_wire__crate__api__emit_session_progress(int64_t port_, uintptr_t data);

void frbgen_heart_beat_wire__crate__api__export_session(int64_t port_,
                                                        struct wire_cst_list_prim_u_8_strict *id,
                                                        int32_t format);

void frbgen_heart_beat_wire__crate__api__get_session(int64_t port_,
                                                     struct wire_cst_list_prim_u_8_strict *id);

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

void frbgen_heart_beat_wire__crate__api__list_plans(int64_t port_);

void frbgen_heart_beat_wire__crate__api__list_sessions(int64_t port_);

void frbgen_heart_beat_wire__crate__api__pause_workout(int64_t port_);

void frbgen_heart_beat_wire__crate__api__phase_progress_elapsed_secs(int64_t port_,
                                                                     uintptr_t progress);

void frbgen_heart_beat_wire__crate__api__phase_progress_phase_index(int64_t port_,
                                                                    uintptr_t progress);

void frbgen_heart_beat_wire__crate__api__phase_progress_phase_name(int64_t port_,
                                                                   uintptr_t progress);

void frbgen_heart_beat_wire__crate__api__phase_progress_remaining_secs(int64_t port_,
                                                                       uintptr_t progress);

void frbgen_heart_beat_wire__crate__api__phase_progress_target_zone(int64_t port_,
                                                                    uintptr_t progress);

void frbgen_heart_beat_wire__crate__api__resume_workout(int64_t port_);

void frbgen_heart_beat_wire__crate__api__scan_devices(int64_t port_);

void frbgen_heart_beat_wire__crate__api__session_end_time(int64_t port_, uintptr_t session);

void frbgen_heart_beat_wire__crate__api__session_hr_sample_at(int64_t port_,
                                                              uintptr_t session,
                                                              uintptr_t index);

void frbgen_heart_beat_wire__crate__api__session_hr_samples_count(int64_t port_, uintptr_t session);

void frbgen_heart_beat_wire__crate__api__session_id(int64_t port_, uintptr_t session);

void frbgen_heart_beat_wire__crate__api__session_phases_completed(int64_t port_, uintptr_t session);

void frbgen_heart_beat_wire__crate__api__session_plan_name(int64_t port_, uintptr_t session);

void frbgen_heart_beat_wire__crate__api__session_preview_avg_hr(int64_t port_, uintptr_t preview);

void frbgen_heart_beat_wire__crate__api__session_preview_duration_secs(int64_t port_,
                                                                       uintptr_t preview);

void frbgen_heart_beat_wire__crate__api__session_preview_id(int64_t port_, uintptr_t preview);

void frbgen_heart_beat_wire__crate__api__session_preview_plan_name(int64_t port_,
                                                                   uintptr_t preview);

void frbgen_heart_beat_wire__crate__api__session_preview_start_time(int64_t port_,
                                                                    uintptr_t preview);

void frbgen_heart_beat_wire__crate__api__session_preview_status(int64_t port_, uintptr_t preview);

void frbgen_heart_beat_wire__crate__api__session_progress_current_bpm(int64_t port_,
                                                                      uintptr_t progress);

void frbgen_heart_beat_wire__crate__api__session_progress_current_phase(int64_t port_,
                                                                        uintptr_t progress);

void frbgen_heart_beat_wire__crate__api__session_progress_phase_progress(int64_t port_,
                                                                         uintptr_t progress);

void frbgen_heart_beat_wire__crate__api__session_progress_state(int64_t port_, uintptr_t progress);

void frbgen_heart_beat_wire__crate__api__session_progress_total_elapsed_secs(int64_t port_,
                                                                             uintptr_t progress);

void frbgen_heart_beat_wire__crate__api__session_progress_total_remaining_secs(int64_t port_,
                                                                               uintptr_t progress);

void frbgen_heart_beat_wire__crate__api__session_progress_zone_status(int64_t port_,
                                                                      uintptr_t progress);

void frbgen_heart_beat_wire__crate__api__session_start_time(int64_t port_, uintptr_t session);

void frbgen_heart_beat_wire__crate__api__session_state_is_completed(int64_t port_, uintptr_t state);

void frbgen_heart_beat_wire__crate__api__session_state_is_paused(int64_t port_, uintptr_t state);

void frbgen_heart_beat_wire__crate__api__session_state_is_running(int64_t port_, uintptr_t state);

void frbgen_heart_beat_wire__crate__api__session_state_is_stopped(int64_t port_, uintptr_t state);

void frbgen_heart_beat_wire__crate__api__session_state_to_string(int64_t port_, uintptr_t state);

void frbgen_heart_beat_wire__crate__api__session_status(int64_t port_, uintptr_t session);

void frbgen_heart_beat_wire__crate__api__session_summary_avg_hr(int64_t port_, uintptr_t session);

void frbgen_heart_beat_wire__crate__api__session_summary_duration_secs(int64_t port_,
                                                                       uintptr_t session);

void frbgen_heart_beat_wire__crate__api__session_summary_max_hr(int64_t port_, uintptr_t session);

void frbgen_heart_beat_wire__crate__api__session_summary_min_hr(int64_t port_, uintptr_t session);

void frbgen_heart_beat_wire__crate__api__session_summary_time_in_zone(int64_t port_,
                                                                      uintptr_t session);

void frbgen_heart_beat_wire__crate__api__start_mock_mode(int64_t port_);

void frbgen_heart_beat_wire__crate__api__start_workout(int64_t port_,
                                                       struct wire_cst_list_prim_u_8_strict *plan_name);

void frbgen_heart_beat_wire__crate__api__stop_workout(int64_t port_);

void frbgen_heart_beat_wire__crate__api__zone_status_is_in_zone(int64_t port_, uintptr_t status);

void frbgen_heart_beat_wire__crate__api__zone_status_is_too_high(int64_t port_, uintptr_t status);

void frbgen_heart_beat_wire__crate__api__zone_status_is_too_low(int64_t port_, uintptr_t status);

void frbgen_heart_beat_wire__crate__api__zone_status_to_string(int64_t port_, uintptr_t status);

void frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiCompletedSession(const void *ptr);

void frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiCompletedSession(const void *ptr);

void frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiFilteredHeartRate(const void *ptr);

void frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiFilteredHeartRate(const void *ptr);

void frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiPhaseProgress(const void *ptr);

void frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiPhaseProgress(const void *ptr);

void frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionProgress(const void *ptr);

void frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionProgress(const void *ptr);

void frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionState(const void *ptr);

void frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionState(const void *ptr);

void frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionSummaryPreview(const void *ptr);

void frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionSummaryPreview(const void *ptr);

void frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiZoneStatus(const void *ptr);

void frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiZoneStatus(const void *ptr);

uintptr_t *frbgen_heart_beat_cst_new_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiCompletedSession(uintptr_t value);

struct wire_cst_api_battery_level *frbgen_heart_beat_cst_new_box_autoadd_api_battery_level(void);

double *frbgen_heart_beat_cst_new_box_autoadd_f_64(double value);

struct wire_cst_record_i_64_u_16 *frbgen_heart_beat_cst_new_box_autoadd_record_i_64_u_16(void);

uint8_t *frbgen_heart_beat_cst_new_box_autoadd_u_8(uint8_t value);

struct wire_cst_list_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionSummaryPreview *frbgen_heart_beat_cst_new_list_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionSummaryPreview(int32_t len);

struct wire_cst_list_String *frbgen_heart_beat_cst_new_list_String(int32_t len);

struct wire_cst_list_discovered_device *frbgen_heart_beat_cst_new_list_discovered_device(int32_t len);

struct wire_cst_list_prim_u_32_strict *frbgen_heart_beat_cst_new_list_prim_u_32_strict(int32_t len);

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
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiCompletedSession);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_box_autoadd_api_battery_level);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_box_autoadd_f_64);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_box_autoadd_record_i_64_u_16);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_box_autoadd_u_8);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_list_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionSummaryPreview);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_list_String);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_list_discovered_device);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_list_prim_u_32_strict);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_cst_new_list_prim_u_8_strict);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiCompletedSession);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiFilteredHeartRate);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiPhaseProgress);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionProgress);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionState);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionSummaryPreview);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiZoneStatus);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiCompletedSession);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiFilteredHeartRate);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiPhaseProgress);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionProgress);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionState);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiSessionSummaryPreview);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerApiZoneStatus);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__connect_device);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__create_battery_stream);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__create_hr_stream);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__create_session_progress_stream);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__delete_session);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__disconnect);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__dummy_battery_level_for_codegen);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__emit_battery_data);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__emit_hr_data);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__emit_session_progress);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__export_session);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__get_session);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__hr_battery_level);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__hr_filtered_bpm);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__hr_raw_bpm);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__hr_rmssd);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__hr_timestamp);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__hr_zone);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__init_logging);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__init_panic_handler);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__init_platform);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__list_plans);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__list_sessions);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__pause_workout);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__phase_progress_elapsed_secs);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__phase_progress_phase_index);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__phase_progress_phase_name);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__phase_progress_remaining_secs);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__phase_progress_target_zone);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__resume_workout);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__scan_devices);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_end_time);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_hr_sample_at);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_hr_samples_count);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_id);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_phases_completed);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_plan_name);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_preview_avg_hr);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_preview_duration_secs);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_preview_id);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_preview_plan_name);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_preview_start_time);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_preview_status);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_progress_current_bpm);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_progress_current_phase);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_progress_phase_progress);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_progress_state);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_progress_total_elapsed_secs);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_progress_total_remaining_secs);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_progress_zone_status);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_start_time);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_state_is_completed);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_state_is_paused);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_state_is_running);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_state_is_stopped);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_state_to_string);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_status);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_summary_avg_hr);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_summary_duration_secs);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_summary_max_hr);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_summary_min_hr);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__session_summary_time_in_zone);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__start_mock_mode);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__start_workout);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__stop_workout);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__zone_status_is_in_zone);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__zone_status_is_too_high);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__zone_status_is_too_low);
    dummy_var ^= ((int64_t) (void*) frbgen_heart_beat_wire__crate__api__zone_status_to_string);
    dummy_var ^= ((int64_t) (void*) store_dart_post_cobject);
    return dummy_var;
}
