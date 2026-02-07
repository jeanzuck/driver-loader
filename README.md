# Driver Loader Script

A simple Windows batch tool to load and unload a kernel-mode driver using the Service Control Manager (SCM). The script elevates itself to administrator, creates a kernel service on demand, starts/stops it, and removes the service when unloading.

## Features

- Self-elevates to Administrator when needed.
- Loads a driver by creating a kernel service with `sc create` and `sc start`.
- Unloads a driver by `sc stop` and `sc delete`.
- Status display (loaded/unloaded) in the menu.
- Uses the script name as the service name and `<scriptname>.sys` as the driver file.

## Requirements

- Windows with Administrator privileges.
- Driver file located in the same directory as the script.
- Driver filename must match the script name:
  - Script: `driver.bat`
  - Driver: `driver.sys`

## How It Works

- `SERVICE_NAME` is set to the batch file name (without extension).
- `DRIVER_FILE` is set to `SERVICE_NAME + .sys`.
- `DRIVER_PATH` points to the `.sys` file in the same folder.

## Usage

1. Copy your driver file next to the script and rename it to match the script name:
   - `driver.bat`
   - `driver.sys`
2. Run the script:
   - Double-click it, or run from an elevated terminal.
3. Choose an option:
   - `1` to load the driver
   - `2` to unload the driver
   - `3` to exit

## Notes

- If a load fails after service creation, the script deletes the service to avoid leftovers.
- The driver is started on demand (`start= demand`).
- Some drivers may require testsigning or proper signing depending on your Windows configuration.

## Troubleshooting

- **Driver file not found**: Ensure the `.sys` file is in the same directory and matches the script name.
- **Failed to create/start service**: Run as Administrator and verify the driver is compatible with your OS version.
- **Service already loaded**: Unload first, or choose the unload option to remove it.
