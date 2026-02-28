# Unpacked Solution Layout Placeholder

This folder is reserved for the unpacked Dataverse solution contents.

## First-time setup
1. Export your Dev unmanaged solution zip (example name: `bcr_mvp_unmanaged.zip`).
2. Unpack it into the canonical solution source folder using Power Platform CLI:
   ```powershell
   pac solution unpack \
     --zipfile ./alm/solution/bcr_mvp_unmanaged.zip \
     --folder ./src/solution \
     --packagetype Unmanaged
   ```
3. Commit the unpacked files under `src/solution` to source control.

## Recommended committed structure
```
src/solution/
  Other/
  Workflows/
  CanvasApps/
  Customizations.xml
  solution.xml
```

## Ongoing ALM workflow
- After Dev changes:
  1. Export unmanaged solution.
  2. Re-unpack into `src/solution` (overwrite existing files).
  3. Review diff.
  4. Commit with associated docs/flow/app updates.
- For release pipeline:
  - Option A: Use exported zip artifact directly.
  - Option B: Repack from source on build agent:
    ```powershell
    pac solution pack \
      --folder ./src/solution \
      --zipfile ./alm/solution/bcr_mvp_unmanaged.zip \
      --packagetype Unmanaged
    ```

## Notes
- Keep this folder free of secrets.
- Connection references and environment variable values are environment-specific and should be set during deployment (pipeline/scripts), not hardcoded.
