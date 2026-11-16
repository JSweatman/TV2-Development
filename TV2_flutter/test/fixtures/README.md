# Controlled player fixture

`tutorial_test_pattern.mp4` is an original one-second silent blue test pattern,
160×90 H.264/yuv420p (1,880 bytes). Generated locally without source footage:

```sh
ffmpeg -f lavfi -i color=c=blue:s=160x90:r=10 -t 1 -an \
  -c:v libx264 -pix_fmt yuv420p tutorial_test_pattern.mp4
```

Only tests refer to it. It is **not** declared in `flutter.assets`, used by the
production entry point, or approved tutorial content. Widget tests fake platform
events and verify controller commands; they do not decode video. A separate local
web harness can point the real controller to this clip for codec/playback checks.
No tutorial review cut, narration, phone capture or personal data is included.
