# Third-party notices

morphnext includes adapted behavior and source structures from the projects
below. No upstream icon artwork or binary font fixtures are redistributed.

## Morphicons

Upstream: <https://github.com/guillermolg00/morphicons>

Revision: `2cdc9292c2b6165274d34ea16909a941cf550cab`

Referenced files:

```text
src/core/resample.ts
src/core/plan.ts
src/core/interpolate.ts
src/core/spring.ts
test/resample.test.ts
test/closed.test.ts
test/invariants.test.ts
```

Local modifications include a Dart/Flutter implementation, filled-outline
topology and hole-aware matching, collapsed unmatched contours instead of
stroke duplication, guarded numeric inputs, and reusable interpolation buffers.

### Morphicons MIT license

```text
MIT License

Copyright (c) 2026 Guillermo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## icon_font_generator 4.1.0

Upstream: <https://github.com/ScerIO/icon_font_generator>

Revision: `498965ac0c0c34f73ecfccd3e8fc02cfdf8ea874`

Referenced reader files, relative to the upstream OpenType source directories:

```text
reader.dart
otf.dart
table/cmap.dart
table/glyf.dart
table/glyph/header.dart
table/glyph/simple.dart
table/cff.dart
table/cff1.dart
cff/index.dart
cff/dict.dart
cff/operand.dart
cff/char_string.dart
common/outline.dart
```

Local modifications include a runtime-only reader, explicit bounds and count
checks, cycle and recursion limits, expanded TrueType composite support, Type 2
local/global subroutines, CID Font DICT selection, typed failures, and removal
of generation, SVG, YAML, XML, and writing code.

### icon_font_generator MIT license

```text
MIT License

Copyright (c) 2019 Serge Shkurko, Igor Kharakhordin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
