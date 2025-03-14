# vr_stopwatch

a small stopwatch for use in wlxoverlay-s

this provides xsoverlay's functionality i wanted to have, which is its timer
for how long a specific VR session has been running for rather than xr appplication
specific session (e.g vrchat's session timer which won't work if vrchat crashes but
my runtime doesn't lol).

NOTE:

vr_stopwatch does not use openxr to hook to the runtime to find out when it ended,
right now the heuristic is "15 minutes without any calls to the binary" which should
work for 99.99% of my cases.

![](./screenie.png)

## how

```
# get zig 0.14.0: https://ziglang.org
zig build
```

then configure your wlxoverlay-s' `watch.yaml` accordingly, something like this:
```yaml
  - type: Label
    rect: [120, 115, 3, 3]
    font_size: 11
    fg_color: "#cad3f5"
    bg_color: "#5b6078"
    source: Exec
    command: [ "/path/to/your/vr_stopwatch" ]
    interval: 1
```
