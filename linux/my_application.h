#ifndef FLUTTER_MY_APPLICATION_H_
#define FLUTTER_MY_APPLICATION_H_

#include <gtk/gtk.h>
#include <flutter_linux/flutter_linux.h>

/**
 * Dichiarazione del tipo MyApplication come tipo finale GObject.
 * G_DECLARE_FINAL_TYPE crea automaticamente le definizioni di tipo necessarie
 * e assicura che non ci siano conflitti di definizione.
 */
G_DECLARE_FINAL_TYPE(MyApplication, my_application, MY, APPLICATION, GtkApplication)

/**
 * my_application_new:
 *
 * Crea una nuova istanza dell'applicazione Flutter con supporto per
 * gestione permessi e audio.
 *
 * L'applicazione creata includerà:
 * - Integrazione con GTK3 per l'interfaccia utente
 * - Gestione permessi attraverso un canale di metodi Flutter
 * - Integrazione con PulseAudio per la gestione audio
 *
 * Returns: (transfer full): Un nuovo oggetto #MyApplication.
 *    Utilizzare g_object_unref() quando non più necessario.
 */
MyApplication* my_application_new(void);

#endif  // FLUTTER_MY_APPLICATION_H_