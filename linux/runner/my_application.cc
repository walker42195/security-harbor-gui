#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static void set_x11_dark_theme(GtkWindow* window) {
#ifdef GDK_WINDOWING_X11
  GdkWindow* gdk_win = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_win != NULL && GDK_IS_X11_WINDOW(gdk_win)) {
    Display* display = gdk_x11_display_get_xdisplay(gdk_window_get_display(gdk_win));
    Window xid = gdk_x11_window_get_xid(gdk_win);
    Atom net_wm_theme_variant = XInternAtom(display, "_GTK_THEME_VARIANT", False);
    Atom utf8_string = XInternAtom(display, "UTF8_STRING", False);
    const char* variant = "dark";
    XChangeProperty(display, xid, net_wm_theme_variant, utf8_string, 8,
                    PropModeReplace, (const unsigned char*)variant, strlen(variant));
  }
#endif
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  GtkWindow* window = GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  set_x11_dark_theme(window);
  gtk_widget_show(GTK_WIDGET(window));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Aktivera mörkt GTK-tema för hela fönstret
  GtkSettings* settings = gtk_settings_get_default();
  if (settings != NULL) {
    g_object_set(settings, "gtk-application-prefer-dark-theme", TRUE, NULL);
  }

  // Applicera ren och giltig GTK CSS för mörk Slate-färg (#1E293B)
  GtkCssProvider* css_provider = gtk_css_provider_new();
  gtk_css_provider_load_from_data(css_provider,
    "headerbar, .titlebar {\n"
    "  background: #1E293B;\n"
    "  background-color: #1E293B;\n"
    "  background-image: none;\n"
    "  color: #FFFFFF;\n"
    "  border-bottom: 1px solid #334155;\n"
    "}\n"
    "headerbar label, .titlebar label {\n"
    "  color: #FFFFFF;\n"
    "  font-weight: bold;\n"
    "}\n"
    "headerbar button, .titlebar button {\n"
    "  color: #FFFFFF;\n"
    "  background: transparent;\n"
    "  border: none;\n"
    "}\n"
    "headerbar button:hover, .titlebar button:hover {\n"
    "  background-color: #334155;\n"
    "}\n",
    -1, NULL);

  gtk_style_context_add_provider_for_screen(
    gdk_screen_get_default(),
    GTK_STYLE_PROVIDER(css_provider),
    GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);

  GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
  gtk_widget_show(GTK_WIDGET(header_bar));
  gtk_header_bar_set_title(header_bar, "Security Harbor – Firewall Management");
  gtk_header_bar_set_show_close_button(header_bar, TRUE);
  gtk_header_bar_set_decoration_layout(header_bar, "icon:minimize,maximize,close");

  gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));

  gtk_window_set_default_size(window, 1280, 720);
  gtk_window_set_icon_name(GTK_WINDOW(window), "security-harbor-gui");

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#0F172A");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(window));
  set_x11_dark_theme(window);

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
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

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
