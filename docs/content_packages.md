# Content packages

Each immediate subfolder in `content/tracks` or `content/vehicles` is a package.
Use stable lowercase snake_case IDs. The folder name must match the manifest ID.

Example for `content/tracks/example_oval/manifest.json`:

```json
{
  "schema_version": 1,
  "type": "track",
  "id": "example_oval",
  "display_name": "Example Oval",
  "scene": "scenes/track.tscn"
}
```

Vehicle manifests use `"type": "vehicle"`. Scene paths use forward slashes and
are relative to the package directory. Leave `scene` empty while planning a
package; it is discovered but marked unavailable. A nonempty scene must exist as
a PackedScene resource. Invalid manifests are skipped with a warning.
Additional metadata is preserved, but only the fields above are currently validated.

`ContentCatalog.tracks` and `ContentCatalog.vehicles` are dictionaries keyed by ID.
Each entry includes the manifest fields plus computed `package_path`, `scene_path`,
and `available`. Future selection menus must filter by `available` before loading
an entry's scene. Refresh replaces both catalogs. Scene nodes are not instantiated
by discovery, and no vehicle or track node contract has been implemented yet.

## Asset conventions

- Use metres, kilograms, seconds, and radians for physics data.
- Godot world orientation: +Y up, vehicle forward along -Z, +X right.
- Apply model scale before exporting; export Blender assets as `.glb`.
- Keep editable `.blend` files under `source_art/tracks/<id>` or
  `source_art/vehicles/<id>`. Export runtime models into the matching content package.
- Keep package-specific dependencies inside that package. Common dependencies go
  in `shared/`; avoid dependencies on other track or vehicle packages.
- Reserve runtime saves, player settings, and results for Godot's `user://` directory.

## Scope of discovery

This first version discovers imported project content under `res://`. Drop new
packages into the project and allow Godot to import their assets before running.
It does not yet support loose GLB/texture mod folders beside an exported executable.
That will require a separate external-content loading or PCK mounting workflow.

When configuring exports, include `content/**/manifest.json` in the non-resource
export filter and include all content resources, including those only referenced
by manifests. JSON paths alone do not establish Godot resource dependencies.
Export presets and distributable mod support are intentionally future work.
