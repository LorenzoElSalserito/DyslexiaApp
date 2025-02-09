// linux/include/vosk_flutter/vosk_flutter_plugin.h

#ifndef FLUTTER_PLUGIN_VOSK_FLUTTER_PLUGIN_H_
#define FLUTTER_PLUGIN_VOSK_FLUTTER_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#define VOSK_FLUTTER_TYPE_PLUGIN (vosk_flutter_plugin_get_type())

G_DECLARE_FINAL_TYPE(VoskFlutterPlugin, vosk_flutter_plugin, VOSK, FLUTTER_PLUGIN,
                     GObject)

/**
 * vosk_flutter_plugin_new:
 *
 * Creates a new instance of the VOSK Flutter plugin.
 *
 * Returns: A new #VoskFlutterPlugin.
 */
VoskFlutterPlugin* vosk_flutter_plugin_new(void);

/**
 * vosk_flutter_plugin_register_with_registrar:
 * @registrar: A #FlPluginRegistrar.
 *
 * Registers the plugin with the Flutter Engine.
 */
void vosk_flutter_plugin_register_with_registrar(FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_VOSK_FLUTTER_PLUGIN_H_