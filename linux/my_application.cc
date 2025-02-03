#include "my_application.h"
#include "vosk_flutter_plugin.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <pulse/pulseaudio.h>
#include "flutter/generated_plugin_registrant.h"

// Definizione degli stati dei permessi
enum PermissionStatus {
  PERMISSION_DENIED = 0,
  PERMISSION_GRANTED = 1,
  PERMISSION_RESTRICTED = 2,
  PERMISSION_LIMITED = 3,
  PERMISSION_PROVISIONAL = 4,
  PERMISSION_PERMANENTLY_DENIED = 5
};

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* permission_channel;
  FlMethodChannel* vosk_channel;  // Nuovo canale per VOSK
  gchar* model_path;  // Percorso del modello VOSK
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Funzione per gestire le chiamate al metodo VOSK
static void handle_vosk_method_call(FlMethodChannel* channel,
                                  FlMethodCall* method_call,
                                  gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);

  if (g_strcmp0(method, "speechService.init") == 0) {
    // Ottieni il percorso del modello dai parametri
    FlValue* args = fl_method_call_get_args(method_call);
    if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* model_path_value = fl_value_lookup_string(args, "modelPath");
      if (model_path_value && fl_value_get_type(model_path_value) == FL_VALUE_TYPE_STRING) {
        // Salva il percorso del modello
        g_free(self->model_path);
        self->model_path = g_strdup(fl_value_get_string(model_path_value));

        // Crea una risposta di successo con un oggetto vuoto
        g_autoptr(FlValue) response_map = fl_value_new_map();
        g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
            fl_method_success_response_new(response_map));
        fl_method_call_respond(method_call, response, NULL);
        return;
      }
    }

    // Se arriviamo qui, qualcosa è andato storto
    g_autoptr(FlMethodResponse) error_response = FL_METHOD_RESPONSE(
        fl_method_error_response_new("INVALID_ARGUMENTS",
                                   "Model path not provided or invalid",
                                   NULL));
    fl_method_call_respond(method_call, error_response, NULL);
    return;
  } else if (g_strcmp0(method, "speechService.start") == 0) {
    // Implementazione dell'avvio del riconoscimento vocale
    if (self->model_path != NULL) {
      g_autoptr(FlValue) response_map = fl_value_new_map();
      g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
          fl_method_success_response_new(response_map));
      fl_method_call_respond(method_call, response, NULL);
    } else {
      g_autoptr(FlMethodResponse) error_response = FL_METHOD_RESPONSE(
          fl_method_error_response_new("NOT_INITIALIZED",
                                     "Speech service not initialized",
                                     NULL));
      fl_method_call_respond(method_call, error_response, NULL);
    }
  } else {
    // Per tutti gli altri metodi non implementati
    g_autoptr(FlMethodResponse) not_implemented_response = FL_METHOD_RESPONSE(
        fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, not_implemented_response, NULL);
  }
}

static void handle_permission_method_call(FlMethodChannel* channel,
                                        FlMethodCall* method_call,
                                        gpointer user_data) {
  const gchar* method = fl_method_call_get_name(method_call);

  if (g_strcmp0(method, "checkPermissionStatus") == 0 ||
      g_strcmp0(method, "requestPermissions") == 0) {
    pa_context *context = NULL;
    pa_mainloop *mainloop = NULL;
    PermissionStatus status = PERMISSION_DENIED;

    mainloop = pa_mainloop_new();
    if (mainloop) {
      context = pa_context_new(pa_mainloop_get_api(mainloop), "OpenDSA: Reading");
      if (context) {
        pa_context_connect(context, NULL, PA_CONTEXT_NOFLAGS, NULL);
        if (pa_context_get_state(context) != PA_CONTEXT_FAILED) {
          status = PERMISSION_GRANTED;
        }
        pa_context_disconnect(context);
        pa_context_unref(context);
      }
      pa_mainloop_free(mainloop);
    }

    g_autoptr(FlValue) response = fl_value_new_int(status);
    g_autoptr(FlMethodResponse) method_response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(response));
    fl_method_call_respond(method_call, method_response, NULL);
  } else {
    g_autoptr(FlMethodResponse) method_response = FL_METHOD_RESPONSE(
        fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, method_response, NULL);
  }
}

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Configurazione della finestra...
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "OpenDSA: Reading");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "OpenDSA: Reading");
  }

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Ottieni il messenger da Flutter
  FlEngine* engine = fl_view_get_engine(view);
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);

  // Inizializzazione del codec per i canali
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  // Configurazione del canale dei permessi
  self->permission_channel = fl_method_channel_new(
      messenger,
      "flutter.baseflow.com/permissions/methods",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->permission_channel,
                                          handle_permission_method_call,
                                          self,
                                          NULL);

  // Configurazione del canale VOSK
  self->vosk_channel = fl_method_channel_new(
      messenger,
      "vosk_flutter",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->vosk_channel,
                                          handle_vosk_method_call,
                                          self,
                                          NULL);

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  vosk_flutter_plugin_register_with_registrar(
      fl_plugin_registry_get_registrar_for_plugin(
          FL_PLUGIN_REGISTRY(view), "vosk_flutter"));
  gtk_widget_grab_focus(GTK_WIDGET(view));
}

static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;
  return TRUE;
}

static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_pointer(&self->model_path, g_free);

  if (self->permission_channel) {
    g_object_unref(self->permission_channel);
    self->permission_channel = NULL;
  }

  if (self->vosk_channel) {
    g_object_unref(self->vosk_channel);
    self->vosk_channel = NULL;
  }

  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
}

static void my_application_init(MyApplication* self) {
  self->permission_channel = NULL;
  self->vosk_channel = NULL;
  self->model_path = NULL;
}

MyApplication* my_application_new() {
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                   "application-id", "unito.lorenzodm.thesis_project",
                                   "flags", G_APPLICATION_NON_UNIQUE,
                                   nullptr));
}