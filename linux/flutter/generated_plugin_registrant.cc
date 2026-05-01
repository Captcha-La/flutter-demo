//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <captchala/captchala_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) captchala_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "CaptchalaPlugin");
  captchala_plugin_register_with_registrar(captchala_registrar);
}
