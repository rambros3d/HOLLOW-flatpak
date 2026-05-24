#include "my_application.h"
#include <stdlib.h>

int main(int argc, char** argv) {
  // Force X11 backend — Wayland compositors (KDE/GNOME) override
  // gtk_window_set_decorated(FALSE), causing a double title bar.
  setenv("GDK_BACKEND", "x11", 0);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
