# pottery_wheel

https://github.com/user-attachments/assets/85b75cad-e3fc-4e83-a7d5-a96b45c92494

Throw a pot with your finger, glaze it while it spins, keep it on a shelf.

No 3D engine. The pot is a surface of revolution drawn with
`Canvas.drawVertices`, so the only dependency is `path_provider`.

## Running

```sh
flutter run
flutter test
```

## Controls

| | |
|---|---|
| drag on the clay | shape it, or pour glaze |
| drag beside the clay | turn the wheel by hand, flick to spin |
| top pill | shape / glaze |
| top right | current glaze, tap to open the rest |
| bottom left | undo, cut the motor |
| bottom right | save and open the shelf, long press for a fresh lump |

On the shelf: tap to put a piece back on the wheel, long press to delete,
`+` for a new one.

## How the pot is drawn

`lib/render/pot_painter.dart`

A pot is a radius profile of `kRows + 1` samples from base to rim, spun around
the vertical axis at `kCols` angles. Each frame:

1. Project `(r, y, theta)` to `x = cx + s*r*sin(theta)` and
   `y = baseY - s*y + tilt*s*r*cos(theta)`. The tilt term turns horizontal
   circles into ellipses, which is what puts the camera above the wheel.
2. Shade per vertex. The profile slope gives the normal in the `(r, y)` plane;
   spinning that around the axis gives the normal everywhere. Vertices facing
   away from the camera are the far wall seen through the mouth of the pot, so
   they get shadow and a little bounce instead of the key light.
3. Sort the quads back to front by `r*cos(theta)`. There is no depth buffer,
   and drawing the far half first so the near half covers it is what makes the
   pot read as hollow.
4. One `drawVertices` call, around 1700 vertices. The buffers in `_Mesh` are
   reused, so a spinning pot allocates nothing per frame.

Two details make the spin visible, since a surface of revolution in flat
colour looks the same at every angle:

- `_buildGrain` adds throwing marks, a spiral ridge plus hash noise for the
  tooth of the clay. The spiral climbs whole turns around the pot so the seam
  at `kCols - 1 -> 0` stays invisible.
- `kLean` tips the axis slightly, more the further it gets from the wheel head,
  so the rim orbits as the pot turns. Touch picking ignores it and stays inside
  the hit test slop.

## Glaze

`lib/model/pot.dart`

The glaze is a texture in `(height, angle)` space, one ARGB cell per vertex,
`kNoGlaze` for bare clay. `PotView.heightAt` and `columnAt` invert the
projection to find the cell under a touch, including undoing the wheel's
current angle, so marks land on the clay rather than on the screen. A held
finger therefore paints a spiral while the pot turns.

Splats blend about 90% toward the glaze colour, so going over the same spot
again deepens it.

Note that `Int32List` sign extends opaque colours, so read channels with a
mask rather than comparing raw values.

## Shaping

The horizontal part of a drag pushes or pulls the wall near the touched
height, with a gaussian falloff and a light relaxation pass so the wall
stretches instead of denting. Radii are clamped to
`[kMinRadius, kMaxRadius]`.

Where a drag starts decides what it does: `PotView.hitsPot` sends it to the
clay or to the wheel head.

## The wheel

`lib/model/wheel.dart`

A motor you can switch off and a head you can grab. A finger down overrides
the motor completely. Letting go hands the head back with whatever spin the
flick gave it, and the motor winds it back to throwing speed over about a
second. With the motor off it coasts to a stop. It only notifies on frames
where the angle changed, so a wheel at rest stops repainting.

## Layout

```
lib/
  model/pot.dart          profile, glaze, undo, json
  model/wheel.dart        motor, hand, momentum
  model/palette.dart      clay, backdrop, glazes
  render/pot_painter.dart projection, lighting, mesh
  screens/studio_screen.dart
  screens/gallery_screen.dart
  store/pot_store.dart    pots.json in the documents directory
  widgets/frost.dart
```
