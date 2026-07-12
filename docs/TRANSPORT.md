# Transport

The transport layer is a small internal event bus for communication between the
core and modules.

## Subscribe

```tcl
::dZSbot::Transport::Subscribe core.ready ::MyModule::OnReady
```

Callbacks receive two arguments:

```tcl
proc ::MyModule::OnReady {event payload} {
    # event   = core.ready
    # payload = Tcl dict
}
```

## Publish

```tcl
::dZSbot::Transport::Publish core.ready [dict create loadedModules 2]
```

`Publish` returns the number of callbacks that were delivered successfully.
Callback errors are logged and counted in `transport.errors`.
