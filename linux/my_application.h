#ifndef MY_APPLICATION_H_
#define MY_APPLICATION_H_

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define MY_TYPE_APPLICATION (my_application_get_type())
G_DECLARE_FINAL_TYPE(MyApplication, my_application, MY, APPLICATION, GtkApplication)

MyApplication* my_application_new(void);

G_END_DECLS

#endif  // MY_APPLICATION_H_
