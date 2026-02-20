import processing.sound.*;
import processing.serial.*;

Serial myPort;   

SoundFile hola;

float holaAmp = 1.0;

boolean lowHeld = false;   // A - low pitch
boolean midHeld = false;   // S - shimmer
boolean highHeld = false;  // D - high pitch

float targetRate = 1.0;
float currentRate = 1.0;

float targetAmp = 1.0;
float currentAmp = 1.0;

float intensity = 0.0;
float attack = 0.08;
float release = 0.04;

float burst = 0;
float phase = 0;

float vPhase = 0;     
float vSpeed = 0.01;  // pulsating speed

float sensorValue = 0;        // latest raw value (0..~20)
float sensorSmooth = 0;       // smoothed value
float sensorNorm = 0;         // 0..1 mapped intensity

float SENSOR_MAX = 20.0;      // adjust if your real max differs
float TRIGGER_THRESH = 1.0;   // value above this counts as "held"
float SMOOTHING = 0.20;       // 0..1 (higher = snappier)

// Sparks
int sparkCount = 100;
float[] sx = new float[sparkCount];
float[] sy = new float[sparkCount];
float[] sv = new float[sparkCount];

// Stars
int starCount = 120;
float[] starX = new float[starCount];
float[] starY = new float[starCount];
float[] starZ = new float[starCount];

void setup() {
  size(1000, 720);
  
  myPort = new Serial(this, "/dev/cu.usbmodem2101", 9600);  
  myPort.bufferUntil('\n');

  hola = new SoundFile(this, "pulse.mp3");
  hola.loop();
  hola.amp(1.0);

  // Sparks init
  for (int i = 0; i < sparkCount; i++) {
    sx[i] = random(width);
    sy[i] = random(height);
    sv[i] = random(0.1, 2.0);
  }

  // Stars init
  for (int i = 0; i < starCount; i++) {
    starX[i] = random(width);
    starY[i] = random(height);
    starZ[i] = random(0.2, 1.0);
  }
}

void draw() {

  // Soft background with motion blur
  fill(5, 10, 18, 40);
  rect(0, 0, width, height);
  
  // Smooth the sensor (so it doesn't flicker)
  sensorSmooth = lerp(sensorSmooth, sensorValue, SMOOTHING);

  // Normalize to 0..1
  sensorNorm = constrain(sensorSmooth / SENSOR_MAX, 0, 1);

  // "A is held" when sensor is above threshold
  lowHeld = (sensorSmooth > TRIGGER_THRESH);

  // INTENSITY now comes from the sensor (acts like A)
  intensity = sensorNorm;
  float I = pow(intensity, 1.3);

  // Slow visual time
  vPhase += vSpeed * (0.3 + 0.7*(1.0 - I));

// === AUDIO PITCH / AMP CONTROL ===
// Default calm state
targetRate = 1.0;
targetAmp  = 1.0;

// Low (A)
if (lowHeld) {
  targetRate = 2.0 + random(3.0, 3.5); // sudden low glitch with tiny jitter
  targetAmp  = 1.0;
}

// Mid (S)
if (midHeld) {
  targetRate = 1.0 + random(1.5, 2.0);   // sudden mid shimmer
  targetAmp  = 1.0;
}

// High (D)
if (highHeld) {
  targetRate = 1.5 + random(2.0, 2.5);  // sudden high glitch
  targetAmp  = 0.9;
}

// Directly set sound properties (no smooth lerp)
hola.rate(targetRate);
hola.amp(targetAmp);


  // Smooth transitions
  currentRate = lerp(currentRate, targetRate, 0.08);
  currentAmp  = lerp(currentAmp, targetAmp, 0.08);

  // Optional jitter for glitch effect
  float jitter = 0;
  if (lowHeld || highHeld) {
    jitter = random(-0.02, 0.02);
  }

  hola.rate(currentRate + jitter);
  hola.amp(currentAmp);

  // === EXTREME GLITCH VISUALS ===
  if (I > 0.05) {

    // Screen shake / displacement
    float shakeX = random(-20, 20) * I;
    float shakeY = random(-20, 20) * I;
    copy(0, 0, width, height, int(shakeX), int(shakeY), width, height);

    // Horizontal tearing
    int tears = int(15 * I);
    for (int i = 0; i < tears; i++) {
      float y = random(height);
      float h = random(10, 40);
      float shift = random(-120, 120) * I;
      copy(0, int(y), width, int(h), int(shift), int(y), width, int(h));
    }

    // Glitch blocks
    for (int i = 0; i < 10 * I; i++) {
      float x = random(width);
      float y = random(height);
      float w = random(20, 120);
      float h = random(10, 60);
      fill(random(255), random(255), random(255), 180);
      rect(x, y, w, h);
    }

    // Static noise
    loadPixels();
    for (int i = 0; i < pixels.length; i++) {
      if (random(1) < 0.03 * I) {
        pixels[i] = color(random(255));
      }
    }
    updatePixels();

    // RGB channel split
    tint(255, 0, 0, 80 * I);
    image(get(), random(-10, 10) * I, 0);

    tint(0, 255, 255, 80 * I);
    image(get(), random(10, -10) * I, 0);

    noTint();

    // Burst flash
    if (burst > 0.65) {
      fill(255, 255 * burst);
      rect(0, 0, width, height);
    }
  }
  
  // Breathing orb
  float breathe = sin(vPhase) * 0.5 + 0.5;
  float sizePulse = 120 + breathe * 180;
  fill(80 + 175*breathe, 120 + 80*breathe, 255, 180);
  ellipse(width/2, height/2, sizePulse, sizePulse);

  // Stars
  stroke(150, 180, 255, 120);
  for (int i = 0; i < starCount; i++) {
    starY[i] += starZ[i] * 0.2 * (1.0 - I);
    if (starY[i] > height) {
      starY[i] = 0;
      starX[i] = random(width);
    }
    strokeWeight(random(1) < 0.02 ? 2 : 1);
    point(starX[i], starY[i]);
  }
  strokeWeight(1);

  // Sparks
  stroke(255, 120);
  for (int i = 0; i < sparkCount; i++) {
    sy[i] -= sv[i] * (0.3 + breathe);
    if (sy[i] < 0) {
      sy[i] = height;
      sx[i] = random(width);
    }
    if (random(1) < 0.02 + 0.08*(1.0 - I)) {
      point(sx[i], sy[i]);
    }
  }
  noStroke();

  // Scanlines
  stroke(255, 25);
  for (int y = 0; y < height; y += 3) {
    line(0, y, width, y);
  }
  noStroke();

  // Text
  fill(255);
  text("A = Low  |  S = Shimmer  |  D = High", 20, 30);
  text("Glitch intensity: " + nf(I, 1, 2), 20, 50);
}

void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line == null) return;

  line = trim(line);
  if (line.length() == 0) return;

  try {
    sensorValue = float(line);   // expects a single number per line
  } 
  catch (Exception e) {
    // ignore bad lines
  }
}


void keyPressed() {
  if (key == 'a') lowHeld = true;
  if (key == 's') midHeld = true;
  if (key == 'd') highHeld = true;
}

void keyReleased() {
  if (key == 'a') lowHeld = false;
  if (key == 's') midHeld = false;
  if (key == 'd') highHeld = false;
}
