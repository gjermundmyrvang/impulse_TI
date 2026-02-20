#include <Adafruit_NeoPixel.h>

#ifdef __AVR__
#include <avr/power.h>
#endif

constexpr uint8_t NEOPIXEL_PIN = 6;
constexpr int PIXEL_COUNT = 100;

constexpr uint8_t AUDIO_PIN = A0;

constexpr int FRAME_DELAY_MS = 5;

constexpr float BASELINE_ALPHA = 0.001f;
constexpr float ENVELOPE_ATTACK = 0.6f;
constexpr float ENVELOPE_RELEASE = 0.02f;

constexpr float OFF_THRESHOLD = 1.0f;
constexpr float ENVELOPE_MAX = 20.0f;
constexpr float SPIKE_DELTA = 3.0f;

constexpr int BLINK_FAST_MS = 25;
constexpr int BLINK_SLOW_MS = 220;

Adafruit_NeoPixel strip(PIXEL_COUNT, NEOPIXEL_PIN, NEO_GRB + NEO_KHZ800);

int rawInput = 0;
float baseline = 0.0f;
float envelope = 0.0f;

bool isGlitching = false;
float previousEnvelope = 0.0f;

unsigned long lastBlinkTimeMs = 0;
bool blinkPhaseOn = false;

float updateBaseline(int raw, float currentBaseline) {
  return currentBaseline + BASELINE_ALPHA * (raw - currentBaseline);
}

float updateEnvelope(float magnitude, float currentEnvelope) {
  const float alpha = (magnitude > currentEnvelope) ? ENVELOPE_ATTACK : ENVELOPE_RELEASE;
  return currentEnvelope + alpha * (magnitude - currentEnvelope);
}

float normalizeEnvelope(float env) {
  float norm = (env - OFF_THRESHOLD) / (ENVELOPE_MAX - OFF_THRESHOLD);
  return constrain(norm, 0.0f, 1.0f);
}

int glitchIntervalMs(float envNorm) {
  return (int)(BLINK_SLOW_MS - envNorm * (BLINK_SLOW_MS - BLINK_FAST_MS));
}

void renderGlitchFrame(float envNorm) {
  const int baseBrightness = constrain((int)(255 * envNorm), 0, 255);

  if (blinkPhaseOn) {
    const int activeChance = (int)(25 + 55 * envNorm);

    for (int i = 0; i < PIXEL_COUNT; i++) {
      if (random(100) < activeChance) {
        const int b = constrain(baseBrightness + (int)random(-120, 120), 0, 255);
        const uint8_t r = (uint8_t)random(0, b + 1);
        const uint8_t g = (uint8_t)random(0, b + 1);
        const uint8_t bl = (uint8_t)random(0, b + 1);
        strip.setPixelColor(i, strip.Color(r, g, bl));
      } else {
        strip.setPixelColor(i, 0);
      }
    }

    const int flashChance = (int)(10 + 80 * envNorm);
    if (random(1000) < flashChance) {
      const int flashBrightness = (int)(180 * envNorm);
      const uint32_t flash = strip.Color(flashBrightness, flashBrightness, flashBrightness);
      for (int i = 0; i < PIXEL_COUNT; i++) strip.setPixelColor(i, flash);
    }
  } else {
    const int dim = (int)(baseBrightness * 0.15f);
    const uint32_t glow = strip.Color(dim, 0, dim);
    for (int i = 0; i < PIXEL_COUNT; i++) strip.setPixelColor(i, glow);
  }

  strip.show();
}

void renderNormalFrame(float envNorm) {
  const int brightness = (int)(255 * envNorm);
  const uint32_t color = strip.Color(brightness, 0, 255 - brightness);

  for (int i = 0; i < PIXEL_COUNT; i++) strip.setPixelColor(i, color);
  strip.show();
}

void clearStrip() {
  strip.clear();
  strip.show();
}

void setup() {
  Serial.begin(9600);

  rawInput = analogRead(AUDIO_PIN);
  baseline = (float)rawInput;
  envelope = 0.0f;

#if defined(__AVR_ATtiny85__) && (F_CPU == 16000000)
  clock_prescale_set(clock_div_1);
#endif

  strip.begin();
}

void loop() {
  rawInput = analogRead(AUDIO_PIN);

  baseline = updateBaseline(rawInput, baseline);
  const float magnitude = abs(rawInput - baseline);
  envelope = updateEnvelope(magnitude, envelope);

  Serial.println((int)envelope); // Signal to processing

  if (envelope < OFF_THRESHOLD) {
    clearStrip();
    isGlitching = false;
    blinkPhaseOn = false;
    previousEnvelope = envelope;
    delay(FRAME_DELAY_MS);
    return;
  }

  const float envNorm = normalizeEnvelope(envelope);

  if ((envelope - previousEnvelope) > SPIKE_DELTA) isGlitching = true;
  previousEnvelope = envelope;

  if (isGlitching) {
    const int interval = glitchIntervalMs(envNorm);
    const unsigned long now = millis();
    if (now - lastBlinkTimeMs >= (unsigned long)interval) {
      lastBlinkTimeMs = now;
      blinkPhaseOn = !blinkPhaseOn;
    }

    renderGlitchFrame(envNorm);
    delay(FRAME_DELAY_MS);
    return;
  }

  renderNormalFrame(envNorm);
  delay(FRAME_DELAY_MS);
}