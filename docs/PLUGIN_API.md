# Module API

Modules live under `modules/<name>/`. The default module entry point is:

```text
modules/<name>/<name>.tcl
```

During boot, `::dZSbot::ModuleManager::LoadDiscovered` finds those entry points
and loads them in isolation.

Before sourcing a module, the module manager loads:

```text
config/modules/<name>.conf
```

if that file exists.

## Registering A Module

A module may register itself:

```tcl
::dZSbot::ModuleManager::Register imdb [dict create \
    version 0.1.0 \
    description "IMDb lookup module"]
```

If a loaded module does not register itself, the module manager creates a basic
registration entry using the module name and path.

## Events

Modules can listen for core events:

```tcl
proc ::MyModule::OnReady {event payload} {
    ::dZSbot::Logger::Info "Core is ready"
}

::dZSbot::Transport::Subscribe core.ready ::MyModule::OnReady
```

Transport callback failures are logged and counted without stopping other
callbacks.
