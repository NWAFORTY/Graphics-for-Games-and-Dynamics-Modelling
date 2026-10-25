/**
 * Marble Race — Processing 3D sketch using the SimObjects stack (Sim3DObjects, SimIntersections,
 * SimPhysics, SimCamera, optional SimUI). This tab owns the whole game: track build, HUD, race rules,
 * and custom marble physics/collisions. Other tabs define reusable primitives; read this file first
 * when learning the project.
 */

// --- Marbles (rendered as SimSpheres + SimPhysics snapshots) ----------------------------
int NUM_MARBLES = 8;
SimSphere[] marbles;
SimPhysics[] marblePhysics;
int[] marbleColors;

// Sky camera preset when flying mode is off (orbit-style overview).
SimCamera theCamera;
PVector SKY_CAM_POS = new PVector(-485, -335, 115);
PVector SKY_LOOK_AT = new PVector(0, 138, 55);

// --- Track solids: boxes for deck/walls; spheres for bumps; cylinders drawn + sphere chains for pillars --
ArrayList<SimBox> trackBoxes;
/** Fixed round obstacles sitting on the deck (physics + draw). */
ArrayList<SimSphere> roundObstacles;
/** Stacked spheres approximating each pillar cylinder for cheap collision response. */
ArrayList<SimSphere> pillarHullSpheres;
/** pillarHullSpheres[i] belongs to pillarObstacle index pillarHullOwners[i]. */
ArrayList<Integer> pillarHullOwners;
/** Authoring data for cylindrical pillars (visual cylinder + hull rebuild). */
ArrayList<PillarObstacle> pillarObstacles;
/** AABB per track box for broad-phase before triangle tests. */
SimExtents[] trackBoxExtents;
/** The thin floor box; used to map 2D deck coordinates (local X/Z) into tilted 3D space. */
SimBox trackDeck;
float RAMP_ANGLE = radians(5.0);
/** World-space deck normal (into the slope), downhill unit, sideways unit, origin at start stripe. */
PVector DECK_UP, RAMP_P0, RAMP_DOWN, RAMP_LAT;
/** Along-ramp progress in “dot metres”: FINISH_DOT = centreline of finish stripe; TRIGGER = first crossing detect. */
float FINISH_DOT, FINISH_LINE_TRIGGER_DOT, TRACK_ALONG_MAX;
/** Uniform scale hook if you widen the authored track numbers. */
float TRACK_SCALE = 1.0;
/** Half-width of playable corridor used for clamps and finishing row spacing. */
float TRACK_HALF_WIDTH = 93.0;
/** Uphill clamp so marbles cannot roll infinitely backward. */
float TRACK_ALONG_MIN = -92.0;
/** How far uphill (deck local Z) from the start line the spawn ledge sits. */
float LEDGE_LOCAL_Z_BEFORE_START = 20.0;
/** Extra lift above deck so marbles start in the air before the drop. */
float LEDGE_AIR_GAP = 40.0;
float TRACK_ALONG_MAX_EXTRA = 95.0;
float MARBLE_R = 10.0;
int CYLINDER_DRAW_DETAIL = 24;
float CHECKER_STRIPE_WIDTH_START = 200;
float CHECKER_STRIPE_ALONG_START = 17;
float CHECKER_STRIPE_WIDTH_FINISH = 230;
float CHECKER_STRIPE_ALONG_FINISH = 22;

float ts(float v) {
  return v * TRACK_SCALE;
}

float TRACK_START_Z_LOCAL = -318;
float TRACK_FINISH_Z_LOCAL = 318;

/** Map 0..1 along race length to deck local Z (before ramp rotation is applied elsewhere). */
float trackZ(float t01) {
  return lerp(TRACK_START_Z_LOCAL, TRACK_FINISH_Z_LOCAL, constrain(t01, 0, 1));
}

/** Per-track-segment RGB fill/stroke baked from wood-ish palette rows (loops last row if list short). */
int[][] TRACK_BOX_PALETTE = {
  {86, 128, 78, 48, 72, 44},
  {205, 152, 96, 118, 78, 42},
  {228, 198, 152, 130, 95, 58},
  {228, 198, 152, 130, 95, 58},
  {160, 118, 72, 88, 58, 34},
  {160, 118, 72, 88, 58, 34},
  {62, 42, 28, 32, 22, 14},
  {62, 42, 28, 32, 22, 14}
};


// --- Contact material tweaks (applied in box/sphere resolves) ----------------------------
float WALL_RESTITUTION = 0.22;
float DECK_RESTITUTION = 0.02;
float SPHERE_OBSTACLE_BOUNCE = 0.28;

// --- Integrator / solver tuning (marbles use manual sub-steps, not SimPhysics.update) ---
float GRAVITY = 0.20;
float AIR_FRICTION = 1.0;
float MAX_SPEED = 12.0;
/** Extra accel bias down the ramp to keep marbles rolling. */
float RAMP_DRIVE = 0.22;
int PHYS_COLLISION_PASSES = 16;
/** More substeps reduces tunneling at high speed through thin colliders. */
int PHYS_SUBSTEPS = 8;
int OBSTACLE_RESOLVE_ITERS = 3;
int MARBLE_PAIR_PASSES = 2;
/** Extra corridor passes because track resolve can wedge marbles slightly into bumps. */
int POST_TRACK_OBSTACLE_PASSES = 8;
PVector gravStep = new PVector();
PVector rampStep = new PVector();
PVector gravInc = new PVector();
PVector rampInc = new PVector();

/** 0..1 flash brightness when obstacles or marbles hit (decayed each frame). */
float[] roundObstacleFlash;
float[] pillarObstacleFlash;
float[] marbleObstacleHitFlash;
// --- Optional legacy UI toolkit (minimal use here; HUD is drawn manually). --------------
SimUI gameUI;
SimpleButton btnStart;
SimpleButton btnReset;
TextDisplayBox lblRaceStatus;
String lastRaceStatusText = "";
// --- Race state ----------------------------------------------------------------------------
boolean raceStarted = false;
boolean raceComplete = false;
/** Once true, marble is frozen for integration and parked in the finish row each frame. */
boolean[] marbleCrossed;
/** finishOrder[k] = marble index of k-th place (0 = first across line). */
int[] finishOrder;
int finishCount;
float raceClockStartMs;
float[] finishTimeSec;

String[] MARBLE_NAMES = {
  "Red", "Orange", "Green", "Cyan", "Purple", "White", "Pink", "Ice"
};
/** Full-window gradient PNG generated in software for the cheap background pass. */
PImage backdropImage;
/** HUD typography (bold / semibold); created in {@link #initHudFontsOnce}. */
PFont hudFontDisplay;
PFont hudFontHead;
PFont hudFontStrong;
PFont hudFontBody;
PFont hudFontCaption;
/** Reference UI palette — coral header, ink border/text, white cards. */
int HUD_INK = color(34, 34, 34);
int HUD_CORAL = color(255, 95, 82);
int HUD_PAPER = color(255, 255, 255);

void setup() {
  size(1000, 800, P3D);
  surface.setResizable(true);
  smooth(8);
  sphereDetail(14);

  marbleColors = new int[NUM_MARBLES];
  marbleColors[0] = color(230, 42, 48);
  marbleColors[1] = color(255, 152, 0);
  marbleColors[2] = color(0, 168, 72);
  marbleColors[3] = color(0, 145, 220);
  marbleColors[4] = color(160, 60, 210);
  marbleColors[5] = color(248, 248, 252);
  marbleColors[6] = color(255, 105, 180);
  marbleColors[7] = color(64, 196, 255);

  trackBoxes = new ArrayList<SimBox>();
  buildTrack();
  computeRampGeometry();
  addStartFinishPostColliders();
  buildRoundObstaclesOnDeck();
  buildBackdropImage();
  gravStep.set(0, GRAVITY, 0);

  marbles = new SimSphere[NUM_MARBLES];
  marbleCrossed = new boolean[NUM_MARBLES];
  finishOrder = new int[NUM_MARBLES];
  finishTimeSec = new float[NUM_MARBLES];
  marbleObstacleHitFlash = new float[NUM_MARBLES];

  marblePhysics = new SimPhysics[NUM_MARBLES];
  for (int i = 0; i < NUM_MARBLES; i++) {
    marbles[i] = new SimSphere(MARBLE_R);
    marblePhysics[i] = new SimPhysics(marbles[i], 1.0);
    marblePhysics[i].frictionAmount = 0;
    marblePhysics[i].radius = MARBLE_R;
  }

  resetRace();

  theCamera = new SimCamera();
  theCamera.setMoving(false);
  theCamera.forwardSpeed = 10.0;
  theCamera.setViewParameters(PI / 2.18, 5, 12000);
  theCamera.setPositionAndLookat(SKY_CAM_POS, SKY_LOOK_AT);
  
  gameUI = null;
  btnStart = null;
  btnReset = null;
  lblRaceStatus = null;

  initHudFontsOnce();
}


void layoutGameUiAndHud() {
  // Reserved hook if buttons are recreated on resize.
}

void windowResized() {
  buildBackdropImage();
  if (theCamera != null) {
    theCamera.setViewParameters(PI / 2.18, 5, 12000);
  }
  layoutGameUiAndHud();
}

void applyRampRotation(SimBox b) {
  /* Track pieces are authored in a flat Z-along runway; −X rotates them to match tilted gameplay. */
  b.setRotation(-RAMP_ANGLE, 0, 0);
}

void buildTrack() {
  // Order matters: thin floor `trackDeck` is second — pointOnDeck() depends on its transform.
  trackBoxes.clear();
  roundObstacles = new ArrayList<SimSphere>();
  pillarObstacles = new ArrayList<PillarObstacle>();

  float deckLen = 740 * 1.3f;
  float margin = 70 * 1.3f;
  TRACK_START_Z_LOCAL = -deckLen * 0.5f + margin;
  TRACK_FINISH_Z_LOCAL = deckLen * 0.5f - margin;

  float platW = 540;
  float floorW = 210;
  float wallX = 105;
  float railX = 93;

  SimBox platform = new SimBox(platW, 44, deckLen);
  platform.setTranslation(0, 46, 0);
  applyRampRotation(platform);
  trackBoxes.add(platform);

  SimBox floor = new SimBox(floorW, 24, deckLen);
  floor.setTranslation(0, 12, 0);
  applyRampRotation(floor);
  trackDeck = floor;
  trackBoxes.add(floor);

  SimBox wallL = new SimBox(14, 56, deckLen);
  wallL.setTranslation(-wallX, 28, 0);
  applyRampRotation(wallL);
  trackBoxes.add(wallL);

  SimBox wallR = new SimBox(14, 56, deckLen);
  wallR.setTranslation(wallX, 28, 0);
  applyRampRotation(wallR);
  trackBoxes.add(wallR);

  SimBox kerb1 = new SimBox(154, 8, 12);
  kerb1.setTranslation(0, 4, deckLen * -0.28f);
  applyRampRotation(kerb1);
  trackBoxes.add(kerb1);

  SimBox kerb2 = new SimBox(154, 8, 12);
  kerb2.setTranslation(0, 4, deckLen * 0.18f);
  applyRampRotation(kerb2);

  SimBox railL = new SimBox(6, 36, deckLen + 20);
  railL.setTranslation(-railX, 22, 0);
  applyRampRotation(railL);
  trackBoxes.add(railL);

  SimBox railR = new SimBox(6, 36, deckLen + 20);
  railR.setTranslation(railX, 22, 0);
  applyRampRotation(railR);
  trackBoxes.add(railR);

  recomputeTrackBoxExtents();
}

void recomputeTrackBoxExtents() {
  // Rebuild AABBs after track edits so broad-phase skips far boxes.
  trackBoxExtents = new SimExtents[trackBoxes.size()];
  for (int bi = 0; bi < trackBoxes.size(); bi++) {
    trackBoxExtents[bi] = trackBoxes.get(bi).getTransformedExtents();
  }
}

/** Deck “local”: lx along width, lz along length; Y fixed at box mid-height before tilt. */
PVector pointOnDeck(float lx, float lz) {
  return trackDeck.transform(vec(lx, -12, lz));
}

/** Thin posts at stripes — mostly visual but SimBoxes add side collision. */
void addStartFinishPostColliders() {
  float[] postX = { -98, 98 };
  float postH = 24;
  float postW = 6.0;
  float[] postZ = { TRACK_START_Z_LOCAL, TRACK_FINISH_Z_LOCAL };

  for (int zi = 0; zi < postZ.length; zi++) {
    float z = postZ[zi];
    for (int xi = 0; xi < postX.length; xi++) {
      float x = postX[xi];
      PVector onSurf = pointOnDeck(x, z);
      PVector centre = PVector.add(onSurf, PVector.mult(DECK_UP, postH * 0.5f));
      SimBox post = new SimBox(postW, postH, postW);
      applyRampRotation(post);
      post.setTranslation(centre.x, centre.y, centre.z);
      trackBoxes.add(post);
    }
  }

  
  recomputeTrackBoxExtents();
}


void addRoundObstacleOnDeck(float rad, float lx, float lz) {
  PVector onSurf = pointOnDeck(lx, lz);
  PVector centre = PVector.add(onSurf, PVector.mult(DECK_UP, rad));
  SimSphere s = new SimSphere(rad);
  s.setTranslation(centre);
  roundObstacles.add(s);
}


void addPillarObstacleOnDeck(float rad, float cylHeight, float lx, float lz) {
  PVector onSurf = pointOnDeck(lx, lz);
  pillarObstacles.add(new PillarObstacle(rad, cylHeight, onSurf));
}

void rebuildPillarHullCollisionSpheres() {
  /* Vertical stack of spheres inside each pillar hull — closer to cylinder feel than one big sphere. */
  pillarHullSpheres = new ArrayList<SimSphere>();
  pillarHullOwners = new ArrayList<Integer>();
  float inflate = 1.03f;
  for (int pi = 0; pi < pillarObstacles.size(); pi++) {
    PillarObstacle po = pillarObstacles.get(pi);
    float R = po.radius * inflate;
    float h = po.height;
    float step = max(R * 0.82f, 4.2f);
    if (h < R * 2.05f) {
      float along = constrain(h * 0.48f, R * 0.35f, h - R * 0.35f);
      SimSphere hull = new SimSphere(R);
      hull.setTranslation(PVector.add(po.base, PVector.mult(DECK_UP, along)));
      pillarHullSpheres.add(hull);
      pillarHullOwners.add(pi);
      continue;
    }
    for (float along = R; along <= h - R + step * 0.35f; along += step) {
      SimSphere hull = new SimSphere(R);
      hull.setTranslation(PVector.add(po.base, PVector.mult(DECK_UP, along)));
      pillarHullSpheres.add(hull);
      pillarHullOwners.add(pi);
    }
  }
}

void buildRoundObstaclesOnDeck() {
  // Pseudorandom layout along track fractions (trackZ(t)) — tweak radii/coords for level feel.
  roundObstacles.clear();
  pillarObstacles.clear();

  float OBST_SCALE = 0.85f;

  addRoundObstacleOnDeck(16 * OBST_SCALE, -48, trackZ(0.14f));
  addRoundObstacleOnDeck(14 * OBST_SCALE, 55, trackZ(0.27f));
  addRoundObstacleOnDeck(15 * OBST_SCALE, -40, trackZ(0.40f));
  addRoundObstacleOnDeck(13 * OBST_SCALE, 0, trackZ(0.53f));
  addRoundObstacleOnDeck(14 * OBST_SCALE, 50, trackZ(0.66f));
  addRoundObstacleOnDeck(15 * OBST_SCALE, -58, trackZ(0.79f));
  addRoundObstacleOnDeck(13 * OBST_SCALE, 44, trackZ(0.90f));

  addPillarObstacleOnDeck(11 * OBST_SCALE, 46 * OBST_SCALE, 0, trackZ(0.21f));
  addPillarObstacleOnDeck(12 * OBST_SCALE, 50 * OBST_SCALE, -42, trackZ(0.34f));
  addPillarObstacleOnDeck(13 * OBST_SCALE, 54 * OBST_SCALE, 46, trackZ(0.47f));
  addPillarObstacleOnDeck(11 * OBST_SCALE, 48 * OBST_SCALE, -52, trackZ(0.60f));
  addPillarObstacleOnDeck(12 * OBST_SCALE, 52 * OBST_SCALE, 38, trackZ(0.73f));
  addPillarObstacleOnDeck(12 * OBST_SCALE, 50 * OBST_SCALE, -36, trackZ(0.85f));

  roundObstacleFlash = new float[roundObstacles.size()];
  pillarObstacleFlash = new float[pillarObstacles.size()];
  rebuildPillarHullCollisionSpheres();
}

/**
 * Frames the race math: uphill origin RAMP_P0, downhill RAMP_DOWN, lateral RAMP_LAT, outward DECK_UP.
 * FINISH_LINE_TRIGGER_DOT is where a marble’s centre fires the timer; FINISH_DOT is stripe centreline
 * used to line up parked finishers across the lane.
 */
void computeRampGeometry() {
  PVector du = PVector.sub(pointOnDeck(40, 0), pointOnDeck(-40, 0));
  PVector dv = PVector.sub(pointOnDeck(0, 40), pointOnDeck(0, -40));
  DECK_UP = du.cross(dv);
  DECK_UP.normalize();
  if (DECK_UP.y > 0) {
    DECK_UP.mult(-1);
  }
  
  RAMP_P0 = pointOnDeck(0, TRACK_START_Z_LOCAL);
  PVector pDown = pointOnDeck(0, TRACK_FINISH_Z_LOCAL);
  RAMP_DOWN = PVector.sub(pDown, pointOnDeck(0, TRACK_START_Z_LOCAL - 40));
  RAMP_DOWN.normalize();
  PVector pFinish = pointOnDeck(0, TRACK_FINISH_Z_LOCAL);
  FINISH_DOT = PVector.sub(pFinish, RAMP_P0).dot(RAMP_DOWN);
  
  float halfStripeAlong = CHECKER_STRIPE_ALONG_FINISH * 0.5f;
  PVector pCheckerLead = pointOnDeck(0, TRACK_FINISH_Z_LOCAL - halfStripeAlong);
  float dotLead = PVector.sub(pCheckerLead, RAMP_P0).dot(RAMP_DOWN);
  FINISH_LINE_TRIGGER_DOT = dotLead - MARBLE_R;
  TRACK_ALONG_MAX = FINISH_DOT + TRACK_ALONG_MAX_EXTRA;
  RAMP_LAT = DECK_UP.cross(RAMP_DOWN);
  RAMP_LAT.normalize();
}

void draw() {
  background(125, 178, 228);
  drawBackdropLayer();
  applySceneLighting();

  if (raceStarted && !raceComplete) {
    updateMarblePhysics();
    checkFinishLine(); /* records order/times then reparks finishers across the stripe */
  }

  /* When flying camera is OFF, glue to the scenic overview preset. */
  if (!theCamera.isMoving) {
    updateSkyViewCamera();
  }

  theCamera.update();

  drawTrackBoxes();
  drawRoundObstacles();
  drawPillarObstacles();
  drawStartDropLedge();
  drawStartLineStripe3D();
  drawFinishLineStripe3D();
  drawMarbles();

  hint(DISABLE_DEPTH_TEST);
  pushMatrix();
  camera();
  drawHudOverlay();
  refreshRaceStatusLabel();
  if (gameUI != null) {
    gameUI.update();
  }
  popMatrix();
  hint(ENABLE_DEPTH_TEST);
}

void drawBackdropLayer() {
  hint(DISABLE_DEPTH_TEST);
  camera(); /* default ortho pixel space for full-window image behind the track */
  if (backdropImage != null) {
    image(backdropImage, 0, 0);
  }
  hint(ENABLE_DEPTH_TEST);
}

void applySceneLighting() {
  directionalLight(255, 244, 220, -0.22f, -0.78f, -0.38f);
  directionalLight(200, 220, 255, 0.42f, -0.42f, 0.28f);
  ambientLight(108, 102, 98);
  lightSpecular(255, 255, 255);
  specular(235, 228, 215);
  shininess(52);
  emissive(0, 0, 0);
}

void drawTrackBoxes() {
  for (int i = 0; i < trackBoxes.size(); i++) {
    int[] pal = TRACK_BOX_PALETTE[min(i, TRACK_BOX_PALETTE.length - 1)];
    fill(pal[0], pal[1], pal[2]);
    stroke(pal[3], pal[4], pal[5]);
    strokeWeight(1.0);
    trackBoxes.get(i).drawMe();
  }
}

void drawRoundObstacles() {
  int obstBaseFill = color(132, 78, 188);
  int obstHotFill = color(230, 198, 255);
  noStroke();
  for (int oi = 0; oi < roundObstacles.size(); oi++) {
    SimSphere s = roundObstacles.get(oi);
    float hitF = (roundObstacleFlash != null && oi < roundObstacleFlash.length) ? roundObstacleFlash[oi] : 0;
    fill(lerpColor(obstBaseFill, obstHotFill, hitF * 0.85));
    emissive(hitF * 26, hitF * 10, hitF * 36);
    s.drawMe();
    emissive(0, 0, 0);
  }
}


/** Rotates cylinder from Y-up mesh space onto the tilted deck normal (pillar visuals). */
void applyCylinderOrientation(PVector deckNorm) {
  PVector y = new PVector(0, 1, 0);
  PVector t = deckNorm.copy();
  if (t.magSq() < 1e-12) {
    return;
  }
  t.normalize();
  float dp = constrain(y.dot(t), -1, 1);
  if (dp > 0.999f) {
    return;
  }
  if (dp < -0.999f) {
    rotateX(PI);
    return;
  }
  PVector axis = y.cross(t);
  axis.normalize();
  rotate(acos(dp), axis.x, axis.y, axis.z);
}


void cylinder(float radius, float height, int detail) {
  int n = max(3, detail);
  float halfStep = TWO_PI / n;

  beginShape(QUAD_STRIP);
  for (int i = 0; i <= n; i++) {
    float a = i * halfStep;
    float x = cos(a) * radius;
    float z = sin(a) * radius;
    
    normal(cos(a), 0, sin(a));
    vertex(x, 0, z);
    vertex(x, height, z);
  }
  endShape();

  beginShape(TRIANGLE_FAN);
  normal(0, -1, 0);
  vertex(0, 0, 0);
  for (int i = 0; i <= n; i++) {
    float a = -i * halfStep;
    vertex(cos(a) * radius, 0, sin(a) * radius);
  }
  endShape();

  beginShape(TRIANGLE_FAN);
  normal(0, 1, 0);
  vertex(0, height, 0);
  for (int i = 0; i <= n; i++) {
    float a = i * halfStep;
    vertex(cos(a) * radius, height, sin(a) * radius);
  }
  endShape();
}

void drawPillarObstacles() {
  int obstBaseFill = color(132, 78, 188);
  int obstHotFill = color(230, 198, 255);
  noStroke();
  for (int i = 0; i < pillarObstacles.size(); i++) {
    PillarObstacle po = pillarObstacles.get(i);
    float hitF = (pillarObstacleFlash != null && i < pillarObstacleFlash.length) ? pillarObstacleFlash[i] : 0;
    fill(lerpColor(obstBaseFill, obstHotFill, hitF * 0.85));
    emissive(hitF * 26, hitF * 10, hitF * 36);
    pushMatrix();
    translate(po.base.x, po.base.y, po.base.z);
    applyCylinderOrientation(DECK_UP);
    cylinder(po.radius, po.height, CYLINDER_DRAW_DETAIL);
    popMatrix();
    emissive(0, 0, 0);
  }
}

void drawMarbles() {
  noStroke();
  specular(255, 252, 245);
  shininess(64);
  emissive(0, 0, 0);
  for (int i = 0; i < NUM_MARBLES; i++) {
    int mc = marbleColors[i];
    float mh = marbleObstacleHitFlash != null ? marbleObstacleHitFlash[i] : 0;
    float b = 1.0 + mh * 0.18;
    fill(constrain(red(mc) * b, 0, 255), constrain(green(mc) * b, 0, 255), constrain(blue(mc) * b, 0, 255));
    marbles[i].drawMe();
  }
}

void initHudFontsOnce() {
  hudFontDisplay = createFont("Segoe UI Bold", 32, true);
  hudFontHead = createFont("Segoe UI Bold", 22, true);
  hudFontStrong = createFont("Segoe UI Semibold", 17, true);
  hudFontBody = createFont("Segoe UI Semibold", 15, true);
  hudFontCaption = createFont("Segoe UI Semibold", 12, true);
  if (hudFontDisplay == null || hudFontHead == null) {
    hudFontDisplay = createFont("SansSerif", 32, true);
    hudFontHead = createFont("SansSerif", 22, true);
    hudFontStrong = createFont("SansSerif", 17, true);
    hudFontBody = createFont("SansSerif", 15, true);
    hudFontCaption = createFont("SansSerif", 12, true);
  }
}

void hudRoundedPanel(float x, float y, float w, float h, float radius, int fillCol, int strokeCol, float strokeWt) {
  rectMode(CORNER);
  noStroke();
  fill(fillCol);
  rect(x, y, w, h, radius);
  if (strokeWt > 0) {
    noFill();
    stroke(strokeCol);
    strokeWeight(strokeWt);
    rect(x + strokeWt * 0.35f, y + strokeWt * 0.35f, w - strokeWt * 0.7f, h - strokeWt * 0.7f, radius * 0.92f);
    noStroke();
  }
}

/** Vertical size of {@link #drawStartBanner()} (keep in sync when editing that layout). */
float hudIdleStartCardHeight() {
  float pad = 14;
  float bandH = 40;
  float descH = 46;
  float pillH = 34;
  float legH = 30;
  return pad + bandH + 12 + descH + 6 + pillH + 12 + legH + pad;
}

/** Top Y for a panel of height {@code panelH} stacked bottom-aligned above the shortcut footer. */
float hudPanelBottomY(float panelH) {
  textFont(hudFontStrong);
  float padY = 14;
  float fh = padY * 2 + textAscent() + textDescent();
  float footerInset = 14;
  float gapAboveFooter = 10;
  float footerTopY = height - fh - footerInset;
  return footerTopY - gapAboveFooter - panelH;
}

/** Flat reference-style card: white fill, heavy ink outline, rounded corners. */
void hudReferenceCard(float x, float y, float w, float h, float radius) {
  rectMode(CORNER);
  fill(HUD_PAPER);
  stroke(HUD_INK);
  strokeWeight(4);
  rect(x, y, w, h, radius);
  noStroke();
}

void drawHudFooterBar() {
  String line = "SPACE Start · R Reset · C Camera";
  textFont(hudFontStrong);
  textAlign(LEFT, TOP);
  float tw = textWidth(line);
  float padX = 18;
  float padY = 14;
  float textH = textAscent() + textDescent();
  float fh = padY * 2 + textH;
  float fw = tw + padX * 2;
  float fx = width - fw - 18;
  float fy = height - fh - 14;
  fill(HUD_INK);
  noStroke();
  rect(fx, fy, fw, fh, 14);
  fill(HUD_PAPER);
  textAlign(LEFT, CENTER);
  text(line, fx + padX, fy + fh * 0.5f);
  textAlign(LEFT, TOP);
}

void drawHudOverlay() {
  if (hudFontDisplay == null) {
    initHudFontsOnce();
  }
  if (!raceStarted) {
    drawStartBanner();
  }
  if (raceStarted && !raceComplete) {
    drawLiveRacePanel();
  } else if (raceComplete) {
    float m = 18;
    float wCard = min(520, width - m * 2);
    drawRaceLeaderboardCard(m, wCard);
  }
  drawHudFooterBar();
}

/** Single panel: status + live leaderboard while racing (bottom-aligned). */
void drawLiveRacePanel() {
  float m = 18;
  float rowH = 26;
  float pad = 14;
  float statusH = 38;
  float subH = 22;
  float lbTitleH = 26;
  float headBlock = statusH + subH;
  float rowBlock = finishCount > 0 ? finishCount * rowH : 22;
  float h = pad + headBlock + lbTitleH + rowBlock + pad + 6;
  float w = min(380, width * 0.42f);
  float maxH = height * 0.55f;
  h = min(h, maxH);
  float my = max(12, hudPanelBottomY(h));
  hudReferenceCard(m, my, w, h, 16);
  float tx = m + pad;
  float ty = my + pad;
  textAlign(LEFT, TOP);
  textFont(hudFontHead);
  fill(HUD_INK);
  text("RACING", tx, ty);
  textFont(hudFontStrong);
  fill(HUD_INK);
  float elapsed = (millis() - raceClockStartMs) / 1000.0;
  text(finishCount + " / " + NUM_MARBLES + " finished   ·   " + nf(elapsed, 1, 2) + " s", tx, ty + statusH);
  textFont(hudFontHead);
  fill(HUD_INK);
  text("Leaderboard", tx, ty + statusH + subH);
  textFont(hudFontBody);
  fill(HUD_INK);
  float ly = ty + statusH + subH + lbTitleH;
  if (finishCount == 0) {
    textFont(hudFontCaption);
    fill(110, 98, 86);
    text("Waiting for first finish…", tx, ly);
    return;
  }
  textFont(hudFontBody);
  for (int p = 0; p < finishCount; p++) {
    int idx = finishOrder[p];
    fill(248, 246, 242);
    noStroke();
    rect(tx - 4, ly - 2, w - pad * 2 + 8, rowH - 4, 8);
    fill(HUD_INK);
    textAlign(LEFT, TOP);
    text((p + 1) + ".  " + MARBLE_NAMES[idx], tx, ly);
    textAlign(RIGHT, TOP);
    fill(HUD_INK);
    text(nf(finishTimeSec[idx], 1, 2) + " s", m + w - pad, ly);
    textAlign(LEFT, TOP);
    ly += rowH;
  }
}

/** Race finished results card (bottom-aligned). Returns Y position just below panel. */
float drawRaceLeaderboardCard(float ox, float w) {
  float pad = 14;
  float rowH = 26;
  float titleBlock = 34;
  float h = pad + titleBlock + NUM_MARBLES * rowH + pad + 8;
  float maxH = height * 0.58f;
  h = min(h, maxH);
  float oyUse = max(12, hudPanelBottomY(h));
  hudReferenceCard(ox, oyUse, w, h, 16);
  float tx = ox + pad;
  float ty = oyUse + pad;
  textAlign(LEFT, TOP);
  textFont(hudFontHead);
  fill(HUD_INK);
  text("Race results", tx, ty);
  textFont(hudFontBody);
  float t0 = finishTimeSec[finishOrder[0]];
  float ly = ty + titleBlock + 6;
  for (int p = 0; p < NUM_MARBLES; p++) {
    int idx = finishOrder[p];
    float t = finishTimeSec[idx];
    String ts = t >= 0 ? nf(t, 1, 2) + " s" : "—";
    String gap = "";
    if (p > 0 && t >= 0 && t0 >= 0) {
      gap = "  (+" + nf(t - t0, 1, 2) + ")";
    }
    boolean hi = (p == 0);
    fill(hi ? lerpColor(HUD_PAPER, HUD_CORAL, 0.18f) : color(245, 244, 242));
    noStroke();
    rect(tx - 4, ly - 2, w - pad * 2 + 8, rowH - 4, 8);
    textFont(hudFontStrong);
    fill(hi ? color(180, 64, 48) : HUD_INK);
    textAlign(LEFT, TOP);
    text((p + 1) + ".", tx, ly);
    textFont(hudFontBody);
    fill(HUD_INK);
    text(MARBLE_NAMES[idx], tx + 28, ly);
    textAlign(RIGHT, TOP);
    fill(HUD_INK);
    text(ts + gap, ox + w - pad, ly);
    textAlign(LEFT, TOP);
    ly += rowH;
  }
  return oyUse + h + 6;
}

void drawStartBanner() {
  if (hudFontDisplay == null) {
    initHudFontsOnce();
  }
  float mx = 18;
  float cw = min(420, max(280, width - 36));
  float pad = 14;
  float rCard = 18;
  float bandH = 40;
  float descH = 46;
  float pillH = 34;
  float legH = 30;
  float ch = hudIdleStartCardHeight();
  float my = max(12, hudPanelBottomY(ch));

  hudReferenceCard(mx, my, cw, ch, rCard);

  float ix = mx + pad;
  float iw = cw - pad * 2;

  noStroke();
  fill(HUD_CORAL);
  rect(ix, my + pad, iw, bandH, 10);
  textFont(hudFontDisplay);
  textAlign(CENTER, CENTER);
  fill(HUD_INK);
  text("MARBLE RACE", ix + iw * 0.5f, my + pad + bandH * 0.5f);

  float yBody = my + pad + bandH + 12;
  textAlign(LEFT, TOP);
  textFont(hudFontBody);
  fill(HUD_INK);
  textLeading(22);
  text("Drop from the ledge, chase the stripes, beat the buzzer.", ix, yBody, iw, descH + 6);

  float pillY = yBody + descH + 6;
  fill(HUD_PAPER);
  stroke(HUD_INK);
  strokeWeight(2);
  rect(ix, pillY, iw, pillH, pillH * 0.5f);
  noStroke();
  textFont(hudFontStrong);
  textAlign(CENTER, CENTER);
  fill(HUD_INK);
  text("Press SPACE to start", ix + iw * 0.5f, pillY + pillH * 0.5f);

  float legY = pillY + pillH + 12;
  textFont(hudFontCaption);
  textAlign(LEFT, TOP);
  fill(HUD_INK);
  textLeading(18);
  text("R reset · C camera · WASD / arrows · RMB-drag to look", ix, legY, iw, legH + 10);

  textAlign(LEFT, TOP);
}

void buildBackdropImage() {
  // Soft vertical gradient — recomputed on resize for crisp pixels.
  backdropImage = createImage(width, height, RGB);
  backdropImage.loadPixels();
  int[] px = backdropImage.pixels;
  int c0 = color(255, 251, 238);
  int c1 = color(118, 172, 226);
  for (int y = 0; y < height; y++) {
    float t = pow(constrain(y / (float) height, 0, 1), 0.9);
    int c = lerpColor(c0, c1, t);
    int row = y * width;
    for (int x = 0; x < width; x++) {
      px[row + x] = c;
    }
  }
  backdropImage.updatePixels();
}

void drawStartDropLedge() {
  // Brown shelf marbles fall from before the race starts.
  pushMatrix();
  rotateX(-RAMP_ANGLE);
  float zCentre = TRACK_START_Z_LOCAL - LEDGE_LOCAL_Z_BEFORE_START;
  translate(0, -7.5f, zCentre);
  fill(148, 102, 64);
  noStroke();
  box(208, 3.8f, 24);
  popMatrix();
}

void drawCheckeredStripeAtLocalZ(float zLocal, boolean drawStartPosts, float stripeWidth, float stripeAlong) {
  // Ten cells across width; optional posts + “lights” only for the start stripe.
  pushMatrix();
  rotateX(-RAMP_ANGLE);
  translate(0, 2, zLocal);
  float totalW = stripeWidth;
  int n = 10;
  float cell = totalW / n;
  stroke(22);
  strokeWeight(0.55);
  for (int i = 0; i < n; i++) {
    boolean dark = ((i + (zLocal < 0 ? 0 : 1)) % 2) == 0;
    fill(dark ? 28 : 250);
    pushMatrix();
    translate(-totalW * 0.5f + cell * 0.5f + i * cell, 0, 0);
    box(cell - 0.4f, 4.2f, stripeAlong);
    popMatrix();
  }
  if (drawStartPosts) {
    noStroke();
    fill(48, 44, 40);
    pushMatrix();
    translate(-98, -11, 0);
    box(5.5, 24, 5.5);
    popMatrix();
    pushMatrix();
    translate(98, -11, 0);
    box(5.5, 24, 5.5);
    popMatrix();

    pushMatrix();
    translate(0, -24, 1.6f);
    fill(255, 214, 72);
    stroke(26, 22, 18);
    strokeWeight(1);
    box(188, 8.5f, 40);
    popMatrix();
    pushMatrix();
    translate(0, -36.5f, 1.8f);
    fill(246, 240, 228);
    stroke(40, 32, 24);
    strokeWeight(0.55f);
    box(154, 4.8f, 34);
    popMatrix();
  }
  popMatrix();
}

void drawStartLineStripe3D() {
  if (raceStarted) {
    return; /* hide clutter once race is running */
  }
  drawCheckeredStripeAtLocalZ(TRACK_START_Z_LOCAL, true, CHECKER_STRIPE_WIDTH_START, CHECKER_STRIPE_ALONG_START);
}

void drawFinishLineStripe3D() {
  drawCheckeredStripeAtLocalZ(TRACK_FINISH_Z_LOCAL, false, CHECKER_STRIPE_WIDTH_FINISH, CHECKER_STRIPE_ALONG_FINISH);
}
/**
 * Place every finished marble on the finish stripe plane in a centred row across the lane
 * (order = finish order left→right) so clustering does not wedge physics or HUD timing reads.
 */
void reparkFinishedMarblesInRow() {
  if (finishCount <= 0) {
    return;
  }
  float along = FINISH_DOT;
  float margin = MARBLE_R * 1.15f;
  float maxSpan = max(MARBLE_R * 2f, 2f * (TRACK_HALF_WIDTH - margin));
  float spacing = (finishCount <= 1) ? 0f
    : min(MARBLE_R * 2.3f, maxSpan / (float) (finishCount - 1));
  float span = spacing * (finishCount - 1);
  float left = -0.5f * span;
  for (int p = 0; p < finishCount; p++) {
    int idx = finishOrder[p];
    float side = left + p * spacing;
    PVector onPlane = PVector.add(RAMP_P0,
      PVector.add(PVector.mult(RAMP_DOWN, along), PVector.mult(RAMP_LAT, side)));
    PVector parked = PVector.add(onPlane, PVector.mult(DECK_UP, MARBLE_R));
    marbles[idx].setTranslation(parked);
    marblePhysics[idx].location.set(parked.x, parked.y, parked.z);
    marblePhysics[idx].velocity.set(0, 0, 0);
  }
}

void checkFinishLine() {
  /* Progress compares centre vs dot along RAMP_DOWN; triggering recentres all finished balls into one row. */
  for (int i = 0; i < NUM_MARBLES; i++) {
    if (marbleCrossed[i]) {
      continue;
    }
    float prog = PVector.sub(marbles[i].getTransformedCentre(), RAMP_P0).dot(RAMP_DOWN);
    if (prog >= FINISH_LINE_TRIGGER_DOT) {
      marbleCrossed[i] = true;
      finishOrder[finishCount++] = i;
      float t = (millis() - raceClockStartMs) / 1000.0;
      finishTimeSec[i] = t;
    }
  }
  if (finishCount > 0) {
    reparkFinishedMarblesInRow();
  }
  if (finishCount >= NUM_MARBLES) {
    raceComplete = true;
  }
}

void startRace() {
  if (raceStarted && !raceComplete) {
    return; /* avoid double-reset mid-run */
  }
  placeMarblesAtStart();
  raceClockStartMs = millis();
  for (int i = 0; i < NUM_MARBLES; i++) {
    finishTimeSec[i] = -1;
    // Tiny velocities so piles don’t start in perfect penetrating stacks.
    marblePhysics[i].velocity.set(random(-0.03, 0.03), random(-0.02, 0.02), random(-0.03, 0.03));
  }
  raceStarted = true;
  raceComplete = false;
  finishCount = 0;
  for (int i = 0; i < NUM_MARBLES; i++) {
    marbleCrossed[i] = false;
  }
}

void placeMarblesAtStart() {
  // Scatter along spawn ledge uphill of the start stripe, lifted by LEDGE_AIR_GAP.
  for (int i = 0; i < NUM_MARBLES; i++) {
    float lx = lerp(ts(-72), ts(72), i / (float) (NUM_MARBLES - 1));
    lx += random(-1.2, 1.2);
    float lz = TRACK_START_Z_LOCAL - LEDGE_LOCAL_Z_BEFORE_START + random(-1.2, 1.2);
    PVector onSurf = pointOnDeck(lx, lz);
    PVector centre = PVector.add(onSurf, PVector.mult(DECK_UP, MARBLE_R + LEDGE_AIR_GAP));
    marbles[i].setTranslation(centre);
    marblePhysics[i].velocity.set(0, 0, 0);
    marblePhysics[i].location.set(centre.x, centre.y, centre.z);
  }
}

void resetRace() {
  lastRaceStatusText = "";
  raceStarted = false;
  raceComplete = false;
  finishCount = 0;
  for (int i = 0; i < NUM_MARBLES; i++) {
    marbleCrossed[i] = false;
    finishOrder[i] = 0;
    finishTimeSec[i] = -1;
  }
  clearObstacleHitFlashes();
  placeMarblesAtStart();
}

void clearObstacleHitFlashes() {
  if (roundObstacleFlash != null) {
    for (int oi = 0; oi < roundObstacleFlash.length; oi++) {
      roundObstacleFlash[oi] = 0;
    }
  }
  if (pillarObstacleFlash != null) {
    for (int pi = 0; pi < pillarObstacleFlash.length; pi++) {
      pillarObstacleFlash[pi] = 0;
    }
  }
  if (marbleObstacleHitFlash != null) {
    for (int i = 0; i < NUM_MARBLES; i++) {
      marbleObstacleHitFlash[i] = 0;
    }
  }
}

void decayObstacleHitFlashes() {
  // Early-out when no channel has a non-zero flash (saves work most frames).
  boolean any = false;
  if (roundObstacleFlash != null) {
    for (int oi = 0; oi < roundObstacleFlash.length; oi++) {
      if (roundObstacleFlash[oi] > 0) {
        any = true;
        break;
      }
    }
  }
  if (!any && pillarObstacleFlash != null) {
    for (int pi = 0; pi < pillarObstacleFlash.length; pi++) {
      if (pillarObstacleFlash[pi] > 0) {
        any = true;
        break;
      }
    }
  }
  if (!any && marbleObstacleHitFlash != null) {
    for (int i = 0; i < NUM_MARBLES; i++) {
      if (marbleObstacleHitFlash[i] > 0) {
        any = true;
        break;
      }
    }
  }
  if (!any) {
    return;
  }
  if (roundObstacleFlash != null) {
    for (int oi = 0; oi < roundObstacleFlash.length; oi++) {
      roundObstacleFlash[oi] *= 0.84;
      if (roundObstacleFlash[oi] < 0.02) {
        roundObstacleFlash[oi] = 0;
      }
    }
  }
  if (pillarObstacleFlash != null) {
    for (int pi = 0; pi < pillarObstacleFlash.length; pi++) {
      pillarObstacleFlash[pi] *= 0.84;
      if (pillarObstacleFlash[pi] < 0.02) {
        pillarObstacleFlash[pi] = 0;
      }
    }
  }
  if (marbleObstacleHitFlash != null) {
    for (int i = 0; i < NUM_MARBLES; i++) {
      marbleObstacleHitFlash[i] *= 0.8;
      if (marbleObstacleHitFlash[i] < 0.025) {
        marbleObstacleHitFlash[i] = 0;
      }
    }
  }
}

void registerRoundObstacleHit(int obstIdx, int marbleIdx, float penetration, float contactSpan) {
  if (roundObstacleFlash != null && obstIdx >= 0 && obstIdx < roundObstacleFlash.length) {
    // Stronger flashes for harder contacts (normalized penetration).
    float bump = 0.38 + constrain(penetration / max(contactSpan, 1f), 0, 0.55);
    roundObstacleFlash[obstIdx] = min(1, roundObstacleFlash[obstIdx] + bump);
  }
  if (marbleObstacleHitFlash != null && marbleIdx >= 0 && marbleIdx < NUM_MARBLES) {
    marbleObstacleHitFlash[marbleIdx] = min(1, marbleObstacleHitFlash[marbleIdx] + 0.35);
  }
}

void registerPillarObstacleHit(int pillarIdx, int marbleIdx, float penetration, float contactSpan) {
  if (pillarObstacleFlash != null && pillarIdx >= 0 && pillarIdx < pillarObstacleFlash.length) {
    float bump = 0.38 + constrain(penetration / max(contactSpan, 1f), 0, 0.55);
    pillarObstacleFlash[pillarIdx] = min(1, pillarObstacleFlash[pillarIdx] + bump);
  }
  if (marbleObstacleHitFlash != null && marbleIdx >= 0 && marbleIdx < NUM_MARBLES) {
    marbleObstacleHitFlash[marbleIdx] = min(1, marbleObstacleHitFlash[marbleIdx] + 0.35);
  }
}

void keyReleased() {
  // SPACE starts; R resets idle or finished state (blocked mid-run in startRace/resetRace logic).
  if (key == 'r' || key == 'R') {
    resetRace();
  }
  if (key == ' ') {
    startRace();
  }
}

void handleSimUIEvent(SimUIEvent ev) {
  // Optional SimUI widget path — ignore canvas; route Start/Reset buttons if present.
  if (ev == null) {
    return;
  }
  if ("canvas".equals(ev.uiLabel)) {
    return;
  }
  if (!"SimpleButton".equals(ev.uiComponentType)) {
    return;
  }
  if ("Start".equals(ev.uiLabel)) {
    startRace();
  } else if ("Reset".equals(ev.uiLabel)) {
    resetRace();
  }
}

void refreshRaceStatusLabel() {
  if (lblRaceStatus == null) {
    return;
  }
  String next;
  if (theCamera != null && theCamera.isMoving) {
    next = "Camera: WASD · arrows · RMB look";
  } else if (!raceStarted) {
    next = "Ready — Start button or SPACE";
  } else if (!raceComplete) {
    float elapsed = (millis() - raceClockStartMs) / 1000.0;
    next = "Racing… " + finishCount + "/" + NUM_MARBLES + "  " + nf(elapsed, 1, 2) + "s";
  } else {
    next = "Finished — Reset or R";
  }
  if (!next.equals(lastRaceStatusText)) {
    lastRaceStatusText = next;
    lblRaceStatus.setText(next);
  }
}

void updateSkyViewCamera() {
  theCamera.setPositionAndLookat(SKY_CAM_POS, SKY_LOOK_AT);
}

void updateMarblePhysics() {
  /*
   * Custom integrator per sub-step: gravity + ramp bias + Euler move, then many constraint solves
   * (track facets, spheres, pillar hull spheres, marble–marble), then clamps and deck snap.
   * Finished racers skip dynamics but can still serve as collision targets via resolveMarbleMarble.
   */
  decayObstacleHitFlashes();
  rampStep.set(RAMP_DOWN.x * RAMP_DRIVE, RAMP_DOWN.y * RAMP_DRIVE, RAMP_DOWN.z * RAMP_DRIVE);

  int steps = max(1, PHYS_SUBSTEPS);
  float invSteps = 1.0 / steps;
  gravInc.set(gravStep.x * invSteps, gravStep.y * invSteps, gravStep.z * invSteps);
  rampInc.set(rampStep.x * invSteps, rampStep.y * invSteps, rampStep.z * invSteps);

  float air = pow(AIR_FRICTION, invSteps);

  for (int s = 0; s < steps; s++) {
    for (int i = 0; i < NUM_MARBLES; i++) {
      if (marbleCrossed != null && marbleCrossed[i]) {
        marblePhysics[i].velocity.set(0, 0, 0);
        continue;
      }

      marblePhysics[i].velocity.add(gravInc);
      marblePhysics[i].velocity.add(rampInc);

      marblePhysics[i].velocity.mult(air);

      marbles[i].tweakTranslation(
        marblePhysics[i].velocity.x * invSteps,
        marblePhysics[i].velocity.y * invSteps,
        marblePhysics[i].velocity.z * invSteps
        );
      PVector ci = marbles[i].getTransformedCentre();
      marblePhysics[i].location.set(ci.x, ci.y, ci.z);
    }

    for (int pass = 0; pass < PHYS_COLLISION_PASSES; pass++) {
      for (int i = 0; i < NUM_MARBLES; i++) {
        if (marbleCrossed != null && marbleCrossed[i]) {
          continue;
        }
        // Sandwich track between obstacle rounds so bumps don’t leave marbles inside walls.
        for (int oiRound = 0; oiRound < OBSTACLE_RESOLVE_ITERS; oiRound++) {
          resolveMarbleTrackBoxes(i);
          for (int oi = 0; oi < roundObstacles.size(); oi++) {
            resolveMarbleWithSphere(i, oi, roundObstacles.get(oi));
          }
          if (pillarHullSpheres != null) {
            for (int hi = 0; hi < pillarHullSpheres.size(); hi++) {

              resolveMarbleWithHullSphere(i, pillarHullSpheres.get(hi), pillarHullOwners.get(hi));
            }
          }
          resolveMarbleTrackBoxes(i);
        }
      }
      for (int mm = 0; mm < MARBLE_PAIR_PASSES; mm++) {
        resolveMarbleMarble();
      }
    }

    for (int i = 0; i < NUM_MARBLES; i++) {
      if (marbleCrossed != null && marbleCrossed[i]) {
        continue;
      }
      clampMarbleVelocity(i);
      keepMarbleOnTrack(i);
    }

    for (int ftp = 0; ftp < POST_TRACK_OBSTACLE_PASSES; ftp++) {
      for (int i = 0; i < NUM_MARBLES; i++) {
        if (marbleCrossed != null && marbleCrossed[i]) {
          continue;
        }
        resolveMarbleTrackBoxes(i);
        for (int oi = 0; oi < roundObstacles.size(); oi++) {

          resolveMarbleWithSphere(i, oi, roundObstacles.get(oi));
        }
        if (pillarHullSpheres != null) {
          for (int hi = 0; hi < pillarHullSpheres.size(); hi++) {

            resolveMarbleWithHullSphere(i, pillarHullSpheres.get(hi), pillarHullOwners.get(hi));
          }
        }
        resolveMarbleTrackBoxes(i);
      }
      resolveMarbleMarble();
    }
  }
}

void resolveMarbleTrackBoxes(int i) {
  // bi=0 is often the wide platform; floor/walls start at 1 for tighter collision set.
  for (int bi = 1; bi < trackBoxes.size(); bi++) {
    resolveMarbleWithBox(i, trackBoxes.get(bi), trackBoxExtents[bi]);
  }
}

void clampMarbleVelocity(int i) {
  PVector v = marblePhysics[i].velocity;
  if (!Float.isFinite(v.x) || !Float.isFinite(v.y) || !Float.isFinite(v.z)) {
    marblePhysics[i].velocity.set(0, 0, 0);
    return;
  }
  float spSq = v.x * v.x + v.y * v.y + v.z * v.z;
  float maxSp = MAX_SPEED;
  float maxSpSq = maxSp * maxSp;
  if (spSq > maxSpSq && spSq > 0) {
    float sp = sqrt(spSq);
    float s = maxSp / sp;
    v.x *= s;
    v.y *= s;
    v.z *= s;
  }
}

void keepMarbleOnTrack(int i) {
  // Clamp along/side on the ramp plane, then if very close to deck snap to rolling contact.
  PVector c = marbles[i].getTransformedCentre();
  if (!Float.isFinite(c.x) || !Float.isFinite(c.y) || !Float.isFinite(c.z)) {
    snapMarbleToSafeGrid(i);
    return;
  }

  PVector rel = PVector.sub(c, RAMP_P0);
  float along = rel.dot(RAMP_DOWN);
  float side = rel.dot(RAMP_LAT);

  boolean outsideCorridor = along < TRACK_ALONG_MIN || abs(side) > TRACK_HALF_WIDTH + 2;

  if (outsideCorridor) {
    float a = max(along, TRACK_ALONG_MIN);
    float b = constrain(side, -TRACK_HALF_WIDTH, TRACK_HALF_WIDTH);
    PVector onPlane = PVector.add(RAMP_P0, PVector.add(PVector.mult(RAMP_DOWN, a), PVector.mult(RAMP_LAT, b)));
    PVector target = PVector.add(onPlane, PVector.mult(DECK_UP, MARBLE_R));
    marbles[i].setTranslation(target);
    marblePhysics[i].location.set(target.x, target.y, target.z);
  }

  c = marbles[i].getTransformedCentre();
  rel = PVector.sub(c, RAMP_P0);
  along = rel.dot(RAMP_DOWN);
  side = rel.dot(RAMP_LAT);
  PVector onPlane = PVector.add(RAMP_P0, PVector.add(PVector.mult(RAMP_DOWN, along), PVector.mult(RAMP_LAT, side)));
  float h = PVector.sub(c, onPlane).dot(DECK_UP); 
  if (h < MARBLE_R * 0.35f) {
    PVector target = PVector.add(onPlane, PVector.mult(DECK_UP, MARBLE_R));
    marbles[i].setTranslation(target);
    marblePhysics[i].location.set(target.x, target.y, target.z);
    float vn = marblePhysics[i].velocity.dot(DECK_UP);
    if (vn < 0) {
      marblePhysics[i].velocity.sub(PVector.mult(DECK_UP, vn)); // remove into-deck normal only
    }
  }

  c = marbles[i].getTransformedCentre();
  if (!Float.isFinite(c.x) || abs(c.x) > 2000 || abs(c.y) > 2000 || abs(c.z) > 2000) {
    snapMarbleToSafeGrid(i);
  }
}

void snapMarbleToSafeGrid(int i) {
  // Last-resort recovery if coordinates blow up — drop near start grid with downhill nudge.
  float lx = lerp(-62, 62, i / (float) max(1, NUM_MARBLES - 1));
  float lz = TRACK_START_Z_LOCAL + 18;
  PVector onSurf = pointOnDeck(lx, lz);
  PVector safe = PVector.add(onSurf, PVector.mult(DECK_UP, MARBLE_R));
  marbles[i].setTranslation(safe);
  marblePhysics[i].location.set(safe.x, safe.y, safe.z);
  marblePhysics[i].velocity.set(RAMP_DOWN.x * 1.0, RAMP_DOWN.y * 1.0, RAMP_DOWN.z * 1.0);
}

void resolveMarbleMarble() {
  /*
   * Pairwise spheres: symmetric impulse for racing pairs; marble–finish pairs skip double-finished,
   * and treat parked finishers as immovable barriers (single-sided push + normal damp).
   * d unit vector points from sphere j toward i when centres overlap slightly.
   */
  float r = MARBLE_R;
  float minD = 2 * r;
  float tol = minD - 1e-5f;
  float tolSq = tol * tol;
  for (int i = 0; i < NUM_MARBLES; i++) {
    for (int j = i + 1; j < NUM_MARBLES; j++) {
      boolean ciDone = marbleCrossed != null && marbleCrossed[i];
      boolean cjDone = marbleCrossed != null && marbleCrossed[j];
      if (ciDone && cjDone) {
        continue;
      }
      PVector ci = marbles[i].getTransformedCentre();
      PVector cj = marbles[j].getTransformedCentre();
      PVector d = PVector.sub(ci, cj);
      float distSq = d.magSq();
      if (distSq >= tolSq || distSq < 1e-14f) {
        continue;
      }
      float dist = sqrt(distSq);
      d.mult(1.0 / dist);
      float push = (minD - dist) * 0.52f;
      PVector vi = marblePhysics[i].velocity;
      PVector vj = marblePhysics[j].velocity;
      if (ciDone && !cjDone) {
        marbles[j].tweakTranslation(-d.x * 2 * push, -d.y * 2 * push, -d.z * 2 * push);
        float vnJ = vj.x * d.x + vj.y * d.y + vj.z * d.z;
        if (vnJ > 0) {
          vj.x -= d.x * vnJ;
          vj.y -= d.y * vnJ;
          vj.z -= d.z * vnJ;
        }
      } else if (cjDone && !ciDone) {
        marbles[i].tweakTranslation(d.x * 2 * push, d.y * 2 * push, d.z * 2 * push);
        float vnI = vi.x * d.x + vi.y * d.y + vi.z * d.z;
        if (vnI < 0) {
          vi.x -= d.x * vnI;
          vi.y -= d.y * vnI;
          vi.z -= d.z * vnI;
        }
      } else {
        marbles[i].tweakTranslation(d.x * push, d.y * push, d.z * push);
        marbles[j].tweakTranslation(-d.x * push, -d.y * push, -d.z * push);
        float vnI = vi.x * d.x + vi.y * d.y + vi.z * d.z;
        float vnJ = vj.x * d.x + vj.y * d.y + vj.z * d.z;
        vi.x -= d.x * vnI;
        vi.y -= d.y * vnI;
        vi.z -= d.z * vnI;
        vj.x -= d.x * vnJ;
        vj.y -= d.y * vnJ;
        vj.z -= d.z * vnJ;
        vi.x += d.x * vnJ;
        vi.y += d.y * vnJ;
        vi.z += d.z * vnJ;
        vj.x += d.x * vnI;
        vj.y += d.y * vnI;
        vj.z += d.z * vnI;
      }
    }
  }
  for (int k = 0; k < NUM_MARBLES; k++) {
    PVector ck = marbles[k].getTransformedCentre();
    marblePhysics[k].location.set(ck.x, ck.y, ck.z);
  }
}

void resolveMarbleWithBox(int idx, SimBox box, SimExtents exForBroadphase) {
  resolveMarbleWithBox(idx, box, exForBroadphase, -1);
}

void resolveMarbleWithBox(int idx, SimBox box, SimExtents exForBroadphase, int pillarRegIdx) {
  /*
   * Find closest box facet triangle to sphere centre; if penetrating, reposition on surface with
   * radius offset, bounce along normal using deck vs wall restitution, pillarRegIdx flashes pillar hits.
   */
  PVector c = marbles[idx].getTransformedCentre();
  float r = marbles[idx].getTransformedRadius();

  // Broad-phase AABB vs cached extents.
  if (exForBroadphase != null && exForBroadphase.minExtents != null && exForBroadphase.maxExtents != null) {
    if (c.x + r < exForBroadphase.minExtents.x || c.x - r > exForBroadphase.maxExtents.x) {
      return;
    }
    if (c.y + r < exForBroadphase.minExtents.y || c.y - r > exForBroadphase.maxExtents.y) {
      return;
    }
    if (c.z + r < exForBroadphase.minExtents.z || c.z - r > exForBroadphase.maxExtents.z) {
      return;
    }
  }

  SimExtents ext = box.getTransformedExtents();

  PVector bestClose = null;
  SimTriangle bestTri = null;
  float bestDistSq = Float.MAX_VALUE;

  for (int fi = 0; fi < 6; fi++) {
    SimFacet f = box.getTransformedFacet(fi);
    SimTriangle t1 = f.getTriangle1();
    SimTriangle t2 = f.getTriangle2();
    PVector cp1 = t1.closestPointOnTriangle(c);
    PVector cp2 = t2.closestPointOnTriangle(c);
    float d1 = PVector.sub(c, cp1).magSq();
    float d2 = PVector.sub(c, cp2).magSq();
    if (d1 < bestDistSq) {
      bestDistSq = d1;
      bestClose = cp1;
      bestTri = t1;
    }
    if (d2 < bestDistSq) {
      bestDistSq = d2;
      bestClose = cp2;
      bestTri = t2;
    }
  }

  if (bestClose == null || bestTri == null) {
    return;
  }

  float dist = sqrt(bestDistSq);
  if (dist >= r - 1e-4) {
    return;
  }

  PVector toC = PVector.sub(c, bestClose);
  if (toC.magSq() < 1e-14) {
    toC = DECK_UP.copy();
    toC.mult(-1);
  }
  PVector d = toC.copy();
  d.normalize();

  PVector triN = bestTri.surfaceNormal();
  PVector nSep;
  if (triN.magSq() < 1e-12) {
    nSep = d;
  } else {
    triN.normalize();
    PVector outHint = PVector.sub(bestClose, ext.centrePoint);
    if (outHint.magSq() > 1e-12 && triN.dot(outHint) < 0) {
      triN.mult(-1);
    }
    nSep = (triN.dot(d) >= 0) ? d : PVector.mult(d, -1);
  }

  PVector newC = PVector.add(bestClose, PVector.mult(nSep, r));
  marbles[idx].setTranslation(newC);
  marblePhysics[idx].location.set(newC.x, newC.y, newC.z);

  float deckAlign = abs(nSep.dot(DECK_UP));
  float vn = marblePhysics[idx].velocity.dot(nSep);
  float rest = deckAlign > 0.38 ? DECK_RESTITUTION : WALL_RESTITUTION;
  if (vn < 0) {
    marblePhysics[idx].velocity.sub(PVector.mult(nSep, vn * (1 + rest)));
  }

  // Kill spurious tangential crawl from tiny numerical noise after normal resolve.
  PVector tang =
    PVector.sub(marblePhysics[idx].velocity, PVector.mult(nSep, marblePhysics[idx].velocity.dot(nSep)));
  marblePhysics[idx].velocity.set(
    PVector.add(PVector.mult(nSep, marblePhysics[idx].velocity.dot(nSep)), tang));

  if (pillarRegIdx >= 0) {
    float pen = max(0, r - dist);
    registerPillarObstacleHit(pillarRegIdx, idx, pen, max(r, 1f));
  }
}


/** One sphere in a pillar’s vertical collision chain (see rebuildPillarHullCollisionSpheres). */
void resolveMarbleWithHullSphere(int mIdx, SimSphere hull, int pillarIdx) {
  PVector cm = marbles[mIdx].getTransformedCentre();
  PVector co = hull.getTransformedCentre();
  float rm = marbles[mIdx].getTransformedRadius();
  float ro = hull.getTransformedRadius();
  PVector delta = PVector.sub(cm, co);
  float minD = rm + ro;
  float distSq = delta.magSq();
  float minDSq = minD * minD;
  if (distSq >= minDSq) {
    return;
  }
  float dist = sqrt(distSq);
  registerPillarObstacleHit(pillarIdx, mIdx, minD - dist, minD);
  PVector n;
  if (dist < 1e-5) {
    n = RAMP_DOWN.cross(DECK_UP);
    if (n.magSq() < 1e-8) {
      n = new PVector(1, 0, 0);
    }
    n.normalize();
  } else {
    n = delta.copy();
    n.normalize();
  }
  PVector placed = PVector.add(co, PVector.mult(n, minD));
  marbles[mIdx].setTranslation(placed);
  marblePhysics[mIdx].location.set(placed.x, placed.y, placed.z);
  float vn = marblePhysics[mIdx].velocity.dot(n);
  if (vn < 0) {
    marblePhysics[mIdx].velocity.sub(PVector.mult(n, vn * (1 + SPHERE_OBSTACLE_BOUNCE)));
  }
  PVector tang = PVector.sub(marblePhysics[mIdx].velocity, PVector.mult(n, marblePhysics[mIdx].velocity.dot(n)));
  tang.mult(0.99);
  marblePhysics[mIdx].velocity.set(PVector.add(PVector.mult(n, marblePhysics[mIdx].velocity.dot(n)), tang));
}

/** Round deck obstacle as a static sphere — similar response to hull spheres, different flash channel. */
void resolveMarbleWithSphere(int mIdx, int obstIdx, SimSphere obst) {
  PVector cm = marbles[mIdx].getTransformedCentre();
  PVector co = obst.getTransformedCentre();
  float rm = marbles[mIdx].getTransformedRadius();
  float ro = obst.getTransformedRadius();
  PVector delta = PVector.sub(cm, co);
  float minD = rm + ro;
  float distSq = delta.magSq();
  float minDSq = minD * minD;
  if (distSq >= minDSq) {
    return;
  }
  float dist = sqrt(distSq);
  registerRoundObstacleHit(obstIdx, mIdx, minD - dist, minD);
  PVector n;
  if (dist < 1e-5) {
    n = RAMP_DOWN.cross(DECK_UP);
    if (n.magSq() < 1e-8) {
      n = new PVector(1, 0, 0);
    }
    n.normalize();
  } else {
    n = delta.copy();
    n.normalize();
  }
  PVector placed = PVector.add(co, PVector.mult(n, minD));
  marbles[mIdx].setTranslation(placed);
  marblePhysics[mIdx].location.set(placed.x, placed.y, placed.z);
  float vn = marblePhysics[mIdx].velocity.dot(n);
  if (vn < 0) {
    marblePhysics[mIdx].velocity.sub(PVector.mult(n, vn * (1 + SPHERE_OBSTACLE_BOUNCE)));
  }
  PVector tang = PVector.sub(marblePhysics[mIdx].velocity, PVector.mult(n, marblePhysics[mIdx].velocity.dot(n)));
  tang.mult(0.99);
  marblePhysics[mIdx].velocity.set(PVector.add(PVector.mult(n, marblePhysics[mIdx].velocity.dot(n)), tang));
}

/** Authoring record: cylinder base on deck (tilted space), visual height, radius. */
class PillarObstacle {
  float radius;
  float height;
  PVector base;

  PillarObstacle(float r, float h, PVector baseOnDeck) {
    radius = r;
    height = h;
    base = baseOnDeck.copy();
  }
}
