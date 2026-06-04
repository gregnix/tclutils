# tclutils::tuevent

A small publish/subscribe event bus. Create independent bus tokens, subscribe
command prefixes to named events, and emit events with arguments.

## API

```tcl
set bus [::tclutils::tuevent::create]
::tclutils::tuevent::subscribe $bus saved {apply {{id} {puts "saved $id"}}}
::tclutils::tuevent::emit      $bus saved 42      ;# -> handler runs, returns 1
```

Commands:

- `create` → bus token.
- `subscribe bus event handler` — idempotent per handler.
- `unsubscribe bus event handler`.
- `emit bus event ?arg ...?` — calls each handler at global level with the args
  appended (subscription order); returns the count. A handler error propagates.
- `handlers bus event` / `events bus`.
- `clear bus ?event?` — drop one event's handlers or all.
- `destroy bus`.

Unknown bus → `{TCLUTILS TUEVENT BUS}`.
