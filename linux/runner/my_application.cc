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

static GtkCssProvider* global_css_provider = NULL;

static void update_window_css(const char* bg, const char* text, const char* border, const char* hover) {
  if (global_css_provider == NULL) return;
  gchar* css = g_strdup_printf(
    "headerbar, .titlebar, headerbar:backdrop, .titlebar:backdrop {\n"
    "  background-color: %s;\n"
    "  background-image: none;\n"
    "  color: %s;\n"
    "  border: none;\n"
    "  border-bottom: 1px solid %s;\n"
    "  box-shadow: none;\n"
    "  text-shadow: none;\n"
    "}\n"
    "headerbar label, .titlebar label {\n"
    "  color: %s;\n"
    "  font-weight: bold;\n"
    "}\n"
    "headerbar button, .titlebar button {\n"
    "  color: %s;\n"
    "  background: transparent;\n"
    "  border: none;\n"
    "}\n"
    "headerbar button:hover, .titlebar button:hover {\n"
    "  background-color: %s;\n"
    "}\n"
    "headerbar button.titlebutton, .titlebar button.titlebutton {\n"
    "  min-width: 28px;\n"
    "  min-height: 28px;\n"
    "  padding: 0;\n"
    "  font-family: monospace;\n"
    "  font-size: 13px;\n"
    "  font-weight: normal;\n"
    "}\n"
    "decoration, decoration:backdrop {\n"
    "  box-shadow: none;\n"
    "  border: none;\n"
    "  background-color: %s;\n"
    "}\n",
    bg, text, border, text, text, hover, bg
  );
  gtk_css_provider_load_from_data(global_css_provider, css, -1, NULL);
  g_free(css);
}

static void set_x11_window_theme(GtkWindow* window, gboolean is_dark) {
#ifdef GDK_WINDOWING_X11
  GdkWindow* gdk_win = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_win != NULL && GDK_IS_X11_WINDOW(gdk_win)) {
    Display* display = gdk_x11_display_get_xdisplay(gdk_window_get_display(gdk_win));
    Window xid = gdk_x11_window_get_xid(gdk_win);
    Atom net_wm_theme_variant = XInternAtom(display, "_GTK_THEME_VARIANT", False);
    Atom utf8_string = XInternAtom(display, "UTF8_STRING", False);
    const char* variant = is_dark ? "dark" : "light";
    XChangeProperty(display, xid, net_wm_theme_variant, utf8_string, 8,
                    PropModeReplace, (const unsigned char*)variant, strlen(variant));
  }
#endif
}

static void on_minimize_clicked(GtkButton* button, GtkWindow* window) {
  gtk_window_iconify(window);
}

static void on_maximize_clicked(GtkButton* button, GtkWindow* window) {
  if (gtk_window_is_maximized(window)) {
    gtk_window_unmaximize(window);
  } else {
    gtk_window_maximize(window);
  }
}

static void on_close_clicked(GtkButton* button, GtkWindow* window) {
  gtk_window_close(window);
}

// Skapar en fönsterknapp med en text-glyf istället för en tema-ikon.
static GtkWidget* make_titlebutton(const char* label) {
  GtkWidget* button = gtk_button_new_with_label(label);
  gtk_button_set_relief(GTK_BUTTON(button), GTK_RELIEF_NONE);
  gtk_widget_set_focus_on_click(button, FALSE);
  gtk_style_context_add_class(gtk_widget_get_style_context(button), "titlebutton");
  gtk_widget_show(button);
  return button;
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  GtkWindow* window = GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  set_x11_window_theme(window, TRUE);
}

static FlMethodResponse* window_theme_method_call(FlMethodCall* method_call, gpointer user_data) {
  const gchar* method = fl_method_call_get_name(method_call);
  if (strcmp(method, "setTheme") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* bg_val = fl_value_lookup_string(args, "bg");
      FlValue* text_val = fl_value_lookup_string(args, "text");
      FlValue* border_val = fl_value_lookup_string(args, "border");
      FlValue* hover_val = fl_value_lookup_string(args, "hover");
      FlValue* is_dark_val = fl_value_lookup_string(args, "isDark");

      const gchar* bg = bg_val ? fl_value_get_string(bg_val) : "#1E293B";
      const gchar* text = text_val ? fl_value_get_string(text_val) : "#FFFFFF";
      const gchar* border = border_val ? fl_value_get_string(border_val) : "#334155";
      const gchar* hover = hover_val ? fl_value_get_string(hover_val) : "#334155";
      gboolean is_dark = is_dark_val ? fl_value_get_bool(is_dark_val) : TRUE;

      update_window_css(bg, text, border, hover);

      GtkWindow* window = GTK_WINDOW(user_data);
      if (window != NULL) {
        GtkSettings* settings = gtk_settings_get_default();
        if (settings != NULL) {
          g_object_set(settings, "gtk-application-prefer-dark-theme", is_dark, NULL);
        }
        set_x11_window_theme(window, is_dark);
      }
    }
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  GtkSettings* settings = gtk_settings_get_default();
  if (settings != NULL) {
    g_object_set(settings, "gtk-application-prefer-dark-theme", TRUE, NULL);
    g_object_set(settings, "gtk-icon-theme-name", "Adwaita", NULL);
  }

  global_css_provider = gtk_css_provider_new();
  update_window_css("#1E293B", "#FFFFFF", "#334155", "#334155");

  gtk_style_context_add_provider_for_screen(
    gdk_screen_get_default(),
    GTK_STYLE_PROVIDER(global_css_provider),
    GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);

  GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
  gtk_widget_show(GTK_WIDGET(header_bar));
  gtk_header_bar_set_title(header_bar, "Security Harbor – Firewall Management");
  gtk_header_bar_set_show_close_button(header_bar, FALSE);
  gtk_header_bar_set_decoration_layout(header_bar, "");

  GtkWidget* close_btn = make_titlebutton("✕");
  g_signal_connect(close_btn, "clicked", G_CALLBACK(on_close_clicked), window);
  gtk_header_bar_pack_end(header_bar, close_btn);

  GtkWidget* maximize_btn = make_titlebutton("□");
  g_signal_connect(maximize_btn, "clicked", G_CALLBACK(on_maximize_clicked), window);
  gtk_header_bar_pack_end(header_bar, maximize_btn);

  GtkWidget* minimize_btn = make_titlebutton("−");
  g_signal_connect(minimize_btn, "clicked", G_CALLBACK(on_minimize_clicked), window);
  gtk_header_bar_pack_end(header_bar, minimize_btn);

  gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));

  gtk_window_set_default_size(window, 1280, 940);
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

  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb), self);

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Registrera temahanteringskanal mot Flutter
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlBinaryMessenger) messenger = fl_engine_get_binary_messenger(fl_view_get_engine(view));
  g_autoptr(FlMethodChannel) theme_channel = fl_method_channel_new(
      messenger,
      "security_harbor/window_theme",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      theme_channel,
      [](FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
        g_autoptr(FlMethodResponse) response = window_theme_method_call(method_call, user_data);
        g_autoptr(GError) error = nullptr;
        fl_method_call_respond(method_call, response, &error);
      },
      window,
      nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));

  gtk_widget_realize(GTK_WIDGET(window));
  set_x11_window_theme(window, TRUE);
  gtk_widget_show(GTK_WIDGET(window));
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
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     NULL));
}
