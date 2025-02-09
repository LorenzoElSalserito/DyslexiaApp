// linux/vosk_flutter_plugin.cc

#include "vosk_flutter/vosk_flutter_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#define VOSK_FLUTTER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), vosk_flutter_plugin_get_type(), \
                             VoskFlutterPlugin))

struct _VoskFlutterPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
};

G_DEFINE_TYPE(VoskFlutterPlugin, vosk_flutter_plugin, G_TYPE_OBJECT)

// Chiamato quando il plugin viene inizializzato
static void vosk_flutter_plugin_init(VoskFlutterPlugin* self) {}

// Chiamato quando il plugin viene distrutto
static void vosk_flutter_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(vosk_flutter_plugin_parent_class)->dispose(object);
}

// Chiamato quando una classe plugin viene inizializzata
static void vosk_flutter_plugin_class_init(VoskFlutterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = vosk_flutter_plugin_dispose;
}

// Costruttore pubblico
VoskFlutterPlugin* vosk_flutter_plugin_new(void) {
  return VOSK_FLUTTER_PLUGIN(g_object_new(vosk_flutter_plugin_get_type(), nullptr));
}

// Registra il plugin con il runtime Flutter
void vosk_flutter_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  VoskFlutterPlugin* plugin = vosk_flutter_plugin_new();
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                           "vosk_flutter",
                           FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, nullptr,
                                          g_object_ref(plugin),
                                          g_object_unref);
  g_object_unref(plugin);
}