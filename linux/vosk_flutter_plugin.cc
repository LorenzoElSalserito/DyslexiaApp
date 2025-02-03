#include "vosk_flutter_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#define VOSK_FLUTTER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), vosk_flutter_plugin_get_type(), \
                             VoskFlutterPlugin))

struct _VoskFlutterPlugin {
  GObject parent_instance;

  FlPluginRegistrar* registrar;
  FlMethodChannel* channel;
  gchar* model_path;
  gboolean is_initialized;
};

G_DEFINE_TYPE(VoskFlutterPlugin, vosk_flutter_plugin, G_TYPE_OBJECT)

// Prototipi delle funzioni
static void vosk_flutter_plugin_dispose(GObject* object);
static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                          gpointer user_data);

static void vosk_flutter_plugin_class_init(VoskFlutterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = vosk_flutter_plugin_dispose;
}

static void vosk_flutter_plugin_init(VoskFlutterPlugin* self) {
  self->model_path = NULL;
  self->is_initialized = FALSE;
}

// Implementazione del gestore dei metodi
static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                          gpointer user_data) {
  VoskFlutterPlugin* self = VOSK_FLUTTER_PLUGIN(user_data);
  const gchar* method = fl_method_call_get_name(method_call);

  g_autoptr(FlMethodResponse) response = NULL;

  if (g_strcmp0(method, "speechService.init") == 0) {
    // Gestione dell'inizializzazione
    FlValue* args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* model_path_value = fl_value_lookup_string(args, "modelPath");
      if (model_path_value && fl_value_get_type(model_path_value) == FL_VALUE_TYPE_STRING) {
        g_free(self->model_path);
        self->model_path = g_strdup(fl_value_get_string(model_path_value));
        self->is_initialized = TRUE;

        // Creazione di una mappa vuota come risposta di successo
        g_autoptr(FlValue) result = fl_value_new_map();
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
      }
    }

    if (!response) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "INVALID_ARGUMENTS", "Model path not provided or invalid", NULL));
    }
  } else if (g_strcmp0(method, "speechService.start") == 0) {
    // Gestione dell'avvio del servizio
    if (self->is_initialized) {
      g_autoptr(FlValue) result = fl_value_new_map();
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    } else {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "NOT_INITIALIZED", "Speech service not initialized", NULL));
    }
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, NULL);
}

static void vosk_flutter_plugin_dispose(GObject* object) {
  VoskFlutterPlugin* self = VOSK_FLUTTER_PLUGIN(object);

  g_clear_pointer(&self->model_path, g_free);
  g_clear_object(&self->channel);

  G_OBJECT_CLASS(vosk_flutter_plugin_parent_class)->dispose(object);
}

VoskFlutterPlugin* vosk_flutter_plugin_new(void) {
  return VOSK_FLUTTER_PLUGIN(g_object_new(vosk_flutter_plugin_get_type(), NULL));
}

void vosk_flutter_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  VoskFlutterPlugin* plugin = vosk_flutter_plugin_new();
  plugin->registrar = registrar;

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "vosk_flutter",
      FL_METHOD_CODEC(codec));

  fl_method_channel_set_method_call_handler(plugin->channel, method_call_cb,
                                          g_object_ref(plugin),
                                          g_object_unref);
}