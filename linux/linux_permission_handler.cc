#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <pulse/pulseaudio.h>
#include <portaudio.h>

G_DECLARE_FINAL_TYPE(LinuxPermissionHandler, linux_permission_handler, LINUX, PERMISSION_HANDLER, GObject)

struct _LinuxPermissionHandler {
  GObject parent_instance;
  FlMethodChannel* channel;
};

G_DEFINE_TYPE(LinuxPermissionHandler, linux_permission_handler, G_TYPE_OBJECT)

static void linux_permission_handler_dispose(GObject* object) {
  LinuxPermissionHandler* self = LINUX_PERMISSION_HANDLER(object);
  g_clear_object(&self->channel);
  G_OBJECT_CLASS(linux_permission_handler_parent_class)->dispose(object);
}

static void linux_permission_handler_class_init(LinuxPermissionHandlerClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = linux_permission_handler_dispose;
}

static void check_audio_permission(FlMethodCall* method_call, FlMethodResult* result) {
  pa_context *context;
  pa_mainloop *mainloop;
  
  mainloop = pa_mainloop_new();
  context = pa_context_new(pa_mainloop_get_api(mainloop), "OpenDSA: Reading");

  if (!context) {
    g_autoptr(FlValue) response = fl_value_new_string("denied");
    fl_method_result_respond(result, response, nullptr);
    return;
  }

  pa_context_connect(context, nullptr, PA_CONTEXT_NOFLAGS, nullptr);
  
  if (pa_context_get_state(context) == PA_CONTEXT_READY) {
    g_autoptr(FlValue) response = fl_value_new_string("granted");
    fl_method_result_respond(result, response, nullptr);
  } else {
    g_autoptr(FlValue) response = fl_value_new_string("denied");
    fl_method_result_respond(result, response, nullptr);
  }

  pa_context_disconnect(context);
  pa_context_unref(context);
  pa_mainloop_free(mainloop);
}

static void request_audio_permission(FlMethodCall* method_call, FlMethodResult* result) {
  // Su Linux non c'è un vero sistema di permessi come su mobile
  // Verifichiamo solo se possiamo accedere al sistema audio
  PaError err = Pa_Initialize();
  if (err == paNoError) {
    g_autoptr(FlValue) response = fl_value_new_string("granted");
    fl_method_result_respond(result, response, nullptr);
    Pa_Terminate();
  } else {
    g_autoptr(FlValue) response = fl_value_new_string("denied");
    fl_method_result_respond(result, response, nullptr);
  }
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "checkPermissionStatus") == 0) {
    check_audio_permission(method_call, FL_METHOD_RESULT(result));
  } else if (strcmp(method, "requestPermissions") == 0) {
    request_audio_permission(method_call, FL_METHOD_RESULT(result));
  } else {
    fl_method_result_respond_not_implemented(FL_METHOD_RESULT(result));
  }
}

static void linux_permission_handler_init(LinuxPermissionHandler* self) {
  self->channel = fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                                      "flutter.baseflow.com/permissions/methods",
                                      FL_METHOD_CODEC(fl_standard_method_codec_new()));
  fl_method_channel_set_method_call_handler(self->channel, method_call_cb, self, nullptr);
}

void linux_permission_handler_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  g_autoptr(LinuxPermissionHandler) plugin = LINUX_PERMISSION_HANDLER(
      g_object_new(linux_permission_handler_get_type(), nullptr));
}
