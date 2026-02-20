# Arduino Code

This Arduino project reads an analog audio signal and drives a NeoPixel strip.

## What it does

- Reads sound from an analog input (A0).
- Detects volume using a smoothed envelope.
- If sound is quiet → LEDs turn off.
- If sound is moderate → smooth color gradient across the strip.
- If a strong spike is detected → glitch mode starts:
  - Random pixels flash.
  - Blink speed increases with volume.
  - Brightness increases with volume.
  - Occasional white flashes at high intensity.

## How it works

1. A moving baseline removes DC offset.
2. An attack/release envelope tracks signal strength.
3. Envelope is normalized to 0–1.
4. Output mode is selected:
   - Below threshold → off
   - Above threshold → reactive
   - Sudden spike → glitch mode

## Hardware

- Arduino-compatible board  
- NeoPixel strip (100 LEDs, GRB, 800kHz)  
- Audio signal connected to A0  

## Adjustable Constants

Tune behavior by changing:

- `OFF_THRESHOLD` – silence cutoff  
- `ENVELOPE_MAX` – max expected signal  
- `SPIKE_DELTA` – how strong a spike must be  
- `BLINK_FAST_MS` / `BLINK_SLOW_MS` – glitch speed range 
