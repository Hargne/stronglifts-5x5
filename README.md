# FiveByFive Garmin Connect IQ App

A Garmin Connect IQ app for tracking 5x5 strength training workouts, inspired by popular barbell programs like StrongLifts.

### Prerequisites

- Garmin Connect IQ SDK installed
- `monkeyc` and `monkeydo` available in your PATH (or use full paths)
- A valid developer key (developer_key.der)
- (Optional) A physical Garmin device for installation

### Build

From the project root:

```bash
monkeyc -f monkey.jungle \
  -o bin/FiveByFive.prg \
  -y /path/to/developer_key.der
```

This generates the compiled app in the bin/ directory.

### Build Connect IQ Submission Package (.iq)

Use the helper script to generate a submission-ready `.iq` package:

```bash
scripts/build-iq-package.sh -s "/path/to/connectiq-sdk"
```

You can also set the SDK path via environment variable:

```bash
CONNECTIQ_SDK_HOME="/path/to/connectiq-sdk" scripts/build-iq-package.sh
```

Optional flags:

- `-k /path/to/key.der` to override signing key (default: `~/.ciq/developer_key.der`)
- `-o /path/to/output.iq` to override output path (default: `bin/FiveByFive.iq`)

### Runing in Simulator

#### 1. Start the Simulator

If the SDK tools are in your PATH:

```bash
simulator
```

Otherwise, run the `simulator` binary from your Connect IQ SDK installation directory.

#### 2. Deploy to Simulator

In a separate terminal

```bash
monkeydo bin/FiveByFive.prg <device-id>
```

Replace `<device-id>` with your target device (for example: `fr245`).

### Install on a Physical Device

1. Connect your Garmin device via USB.
2. Locate the mounted Garmin drive.
3. Copy the compiled .prg file to: `GARMIN/APPS/`

Example:

```bash
cp bin/FiveByFive.prg /Volumes/GARMIN/GARMIN/APPS/
```

4. Safely eject the device.
