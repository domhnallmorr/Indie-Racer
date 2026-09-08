# Retro city sky

Generated with the built-in imagegen tool. `skyline.png` is the original generated panorama; the city is part of the image. `sky.tres` is used by the main scene. Existing sun and ambient lighting are preserved.

The sky shader offsets the painted horizon and feathers the horizontal wrap seam. Adjust `horizon_offset` in `sky.tres` to move the skyline vertically (larger values raise it).

## Generation prompt

Use case: stylized-concept. Asset type: game sky texture, full 360 degree equirectangular panorama, 2:1 aspect ratio, 2048x1024. Create a late 1990s PC racing game skybox: cheerful blue sky with just a few soft white cumulus clouds and a distant generic American city skyline baked into the image. Correct spherical panorama layout: zenith at top, horizon exactly at 50% image height, nadir at bottom. Buildings confined to a narrow band from about 44% to 53% image height, varied modest blocky towers and low industrial buildings, muted blue-grey and warm grey, tiny simplified window marks, atmospheric distance. Sky brighter pale blue near horizon, medium blue overhead. Bottom half below city fades to uniform muted blue-grey ground colour, no roads or foreground objects. Understated low-resolution painted/pixel-textured 1995-1999 racing simulator aesthetic, restrained details, not photorealistic, no outlines. Flat unwrapped texture only, no mockup. Seamless horizontal wrap: far left and far right match in sky colour and skyline height; no obvious landmark at seam. Top and bottom edges uniform colours for pole safety. No text, logo, sun disk, mountains, cars, or separate 3D buildings.
