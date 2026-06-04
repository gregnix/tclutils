# tclutils::tuimage

Pure-Tcl image **inspection**: detect format, MIME type and pixel dimensions
from an image's raw bytes, plus `data:` URI helpers. It does **no** decoding or
pixel processing -- that belongs to Tk's photo images or the `imgtools`
extension. Reuses `tclutils::tubase64`.

## API

```tcl
tuimage::type $bytes          ;# png | jpeg | gif | bmp | webp | ""
tuimage::mime $bytes          ;# image/png ...
tuimage::dimensions $bytes    ;# {width height}  (or {} if unknown)
tuimage::inspect $bytes       ;# {type .. mime .. width .. height ..}
tuimage::dataUri image/png $bytes   ;# -> "data:image/png;base64,...."
tuimage::fromDataUri $uri           ;# -> {mime image/png bytes <raw>}
```

Dimensions are read straight from the header (PNG IHDR, GIF screen descriptor,
BMP info header, JPEG SOFn scan, WEBP VP8/VP8L/VP8X). `$bytes` must be raw binary
(e.g. a file read from a binary channel, or `tubase64::decode` of an embedded
photo). Useful for vCard/CalDAV photos, thumbnails and validation without
loading a full image toolkit.
