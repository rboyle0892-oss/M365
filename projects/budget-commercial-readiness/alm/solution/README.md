# Unpacked Solution Layout Placeholder

This folder is reserved for the unpacked Dataverse solution contents.

## First-time setup
1. Export your Dev unmanaged solution zip (example name: `bcr_mvp_unmanaged.zip`).
2. Unpack it into this folder using Power Platform CLI:
   ```powershell
   pac solution unpack \
     --zipfile ./alm/solution/bcr_mvp_unmanaged.zip \
     --folder ./alm/solution/src \
     --packagetype Unmanaged
   ```
3. Commit the unpacked files under `alm/solution/src` to source control.

## Recommended committed structure
```
alm/solution/
  README.md
  src/
    Other/
    Workflows/
    CanvasApps/
    Customizations.xml
    solution.xml
```

## Ongoing ALM workflow
- After Dev changes:
  1. Export unmanaged solution.
  2. Re-unpack into `alm/solution/src` (overwrite existing files).
  3. Review diff.
  4. Commit with associated docs/flow/app updates.
- For release pipeline:
  - Option A: Use exported zip artifact directly.
  - Option B: Repack from source on build agent:
    ```powershell
    pac solution pack \
      --folder ./alm/solution/src \
      --zipfile ./alm/solution/bcr_mvp_unmanaged.zip \
      --packagetype Unmanaged
    ```

## Notes
- Keep this folder free of secrets.
- Connection references and environment variable values are environment-specific and should be set during deployment (pipeline/scripts), not hardcoded.
