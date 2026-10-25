/**
 * First-person style “flying camera” for P3D: WASD/arrows/strafe on the tilted runway, RMB look,
 * toggle with C vs a fixed scenic viewpoint. Provides startDraw2D/endDraw2D to paint HUD in screen space
 * after 3D (see Marble Race sketch draw()).
 */

class SimCamera {

  PVector initialCameraPosition;
  PVector restoreCameraPosition;
  PVector restoreCameraLookat;
  
  PVector cameraUpVector = new PVector(0,-1,0);
  PVector cameraPos;
  PVector cameraLookat;

  float forwardSpeed = 3.0;
  float rotationAmount = 1;
  char cameraMotionToggleKey = 'c';

  /** Last clip planes from setViewParameters — reapplied after HUD ortho so 3D keeps perspective(). */
  float clipFov = PI / 3.0;
  float clipNear = 1;
  float clipFar = 100000;
  boolean clipPerspective = true;

  boolean isMoving = true;

  /** If set via setHUDArea, startDraw2D can dim a HUD rectangle behind widgets (often unused). */
  PVector hudAreaTL, hudAreaBR;

  public SimCamera() {

    setViewParameters(PI/3.0, 1,100000);
    cameraPos = discoverCameraPosition();
    initialCameraPosition = cameraPos.copy();
    
    cameraLookat = PVector.add(cameraPos, vec(0, 0, -1));
  }
  
  void update() {
    /* Note: Uses global key/keyPressed — only one coded key reliably processed per frame in Processing. */
    if(key == cameraMotionToggleKey && keyPressed) { 
      toggleCameraMotion();
      delay(200);
      }
      
    if( isMoving == false) return;
    
    update_FlyingCamera();
    updateCameraPosition();
  }
  
  
  
   void setPositionAndLookat(PVector pos, PVector lookat) {
    cameraPos = pos.copy();
    cameraLookat = lookat.copy();
    updateCameraPosition();
  }
  
  void setViewParameters(float fov, float nearClip, float farClip) {
    clipNear = nearClip;
    clipFar = farClip;
    if (fov != 0) {
      clipFov = fov;
      clipPerspective = true;
      perspective(fov, float(width) / max(1f, (float) height), nearClip, farClip);
    } else {
      clipPerspective = false;
      ortho();
    }
  }
  
  
  
  
  

  PVector getPosition() { 
    return cameraPos;
  }
  PVector getLookat() { 
    return cameraLookat;
  }
  
  PVector getForwardVector() {
    return PVector.sub(cameraLookat, cameraPos).normalize();
  }
  
  void setMoving(boolean b){
    isMoving = b;
  }
  
  void setForwardSpeed(float moreOrLess){
    forwardSpeed = constrain(forwardSpeed + moreOrLess, 0.5,15);
  }
  
  
  
  void setRotationSpeed(float r){
    rotationAmount = r;
  }
  
  
  
 
  /**
   * Screen-space HUD for P3D: default camera() then ortho() matches Processing’s usual “2D on top of 3D”
   * recipe (resetMatrix()+ortho alone often leaves text invisible).
   */
  void startDraw2D() {
    restoreCameraPosition = getPosition().copy();
    restoreCameraLookat = getLookat().copy();

    hint(DISABLE_DEPTH_TEST);
    pushMatrix();
    camera();
    ortho(0, width, height, 0, -200, 200);
    lights();
    ambientLight(255, 255, 255);
    directionalLight(240, 240, 240, 0, 0, -1);
    shininess(1);
    specular(0, 0, 0);
    emissive(0, 0, 0);

    if (hudAreaTL != null) {
      fill(255, 255, 255, 100);
      rect(hudAreaTL.x, hudAreaTL.y, hudAreaBR.x - hudAreaTL.x, hudAreaBR.y - hudAreaTL.y);
    }
  }

  void endDraw2D() {
    popMatrix();
    hint(ENABLE_DEPTH_TEST);
    // startDraw2D used ortho() on the projection stack — restore P3D perspective before next frame.
    if (clipPerspective) {
      perspective(clipFov, float(width) / max(1f, (float) height), clipNear, clipFar);
    } else {
      ortho();
    }
    setPositionAndLookat(restoreCameraPosition, restoreCameraLookat);
    updateCameraPosition();
  }
  
  void setHUDArea(int left, int top, int w, int h){
    hudAreaTL = new PVector(left,top);
    hudAreaBR = new PVector(left+w,top+h);
  }
  
  
  
  
  
  
  SimRay getMouseRay(){
    return getWindowRay(getMousePos());
  }
  
  SimRay getWindowRay(PVector winPos){
    
    PVector mp = projectWindowPosInto3D(winPos);
    PVector cameraPos = this.getPosition();
    SimRay mouseRay = new SimRay();
    mouseRay.setWithOriginAndSecondPoint(cameraPos,mp);
    return mouseRay;
  }

  
  
  
  
  
  void updateCameraPosition(){
    camera(cameraPos.x, cameraPos.y, cameraPos.z, cameraLookat.x, cameraLookat.y, cameraLookat.z, 0, 1, 0);
  }


  boolean mouseInHUDArea(){
    if(hudAreaTL == null) return false;
    float x = mouseX;
    float y = mouseY;
    return ( isBetweenInc(x, hudAreaTL.x, hudAreaBR.x) && isBetweenInc(y, hudAreaTL.y, hudAreaBR.y) );
  }

  PVector getMousePos() {
    return new PVector(mouseX, mouseY, 0);
  }

  
  PVector discoverCameraPosition() {
    PMatrix3D mat = (PMatrix3D)getMatrix(); 
    
    mat.invert();
    return new PVector( mat.m03, mat.m13, mat.m23 );
  }

  
  void update_FlyingCamera () {
    
    if( mouseInHUDArea() ) return;
    
    
 
    if(key == 'w' && keyPressed) moveCameraForward(forwardSpeed);
    if(key == 's' && keyPressed) moveCameraForward(-forwardSpeed);
    
    if(((key == 'a' || key == 'A') || arrowKeyPressed(LEFT)) && keyPressed) strafe( LEFT );
    if(((key == 'd' || key == 'D') || arrowKeyPressed(RIGHT)) && keyPressed) strafe( RIGHT );
    
    if(arrowKeyPressed(UP)) strafe( UP );
    if(arrowKeyPressed(DOWN)) strafe( DOWN );
    
    if (mousePressed && mouseButton == RIGHT) {
      PVector mqv = getMouseQuadrantVector();
      
      if(mqv.mag()>0){
        rotatecameraLeftRight(rotationAmount*mqv.x);
        rotatecameraUpDown(rotationAmount*-mqv.y);
      }
      
    }

  }
  
  void toggleCameraMotion(){
    isMoving = !isMoving;
  }
  
  void strafe(int dir){
    PVector cameraForwardVector = getForwardVector();
    PVector sideVector = cameraForwardVector.cross(cameraUpVector);
    sideVector.mult(forwardSpeed);
    if(dir == LEFT){
      cameraPos = PVector.add(cameraPos, sideVector);
      cameraLookat = PVector.add(cameraLookat, sideVector);
    }
    if(dir == RIGHT){
      cameraPos = PVector.sub(cameraPos, sideVector);
      cameraLookat = PVector.sub(cameraLookat, sideVector);
    }
    
    if(dir == UP){
      PVector cameraUpScaled = PVector.mult(cameraUpVector, forwardSpeed);
      cameraPos = PVector.add(cameraPos, cameraUpScaled);
      cameraLookat = PVector.add(cameraLookat, cameraUpScaled);
    }
    if(dir == DOWN){
      PVector cameraUpScaled = PVector.mult(cameraUpVector, forwardSpeed);
      cameraPos = PVector.sub(cameraPos, cameraUpScaled);
      cameraLookat = PVector.sub(cameraLookat, cameraUpScaled);
    }
    
  }
  
  boolean arrowKeyPressed(int dir){
    if(keyPressed && key == CODED){
      if(keyCode == dir){
        return true;
      }
    }
    return false;
  }
  
  PVector getMouseQuadrantVector(){
    
    
    PVector centre = getCentre3DWindow();
    PVector mousePos = getMousePos();
    
    float dx = (mousePos.x - centre.x)/centre.x;
    float dy = (mousePos.y - centre.y)/centre.y;
    if(abs(dx) < 0.1) dx = 0;
    if(abs(dy) < 0.1) dy = 0;
    
    
    return new PVector(dx,dy);
  }
  
  

  void moveCameraForward(float amt) {
    PVector cameraForwardVector = getForwardVector();
    PVector movement = PVector.mult(cameraForwardVector, amt);
    
    cameraPos = PVector.add(cameraPos, movement);
    cameraLookat = PVector.add(cameraPos, cameraForwardVector);
    setPositionAndLookat(cameraPos, cameraLookat);
  }


  void rotatecameraLeftRight(float degs) {
    PVector cameraForwardVector = getForwardVector();
    cameraForwardVector =  rotateVectorRoundAxis(cameraForwardVector, cameraUpVector, degs);
    cameraLookat = PVector.add(cameraPos, cameraForwardVector);
    setPositionAndLookat(cameraPos, cameraLookat);
  }
  
  void rotatecameraUpDown(float degs) {
    PVector cameraForwardVector = getForwardVector();
    PVector sideVector = cameraForwardVector.cross(cameraUpVector);
    cameraForwardVector =  rotateVectorRoundAxis(cameraForwardVector, sideVector, degs);
    cameraLookat = PVector.add(cameraPos, cameraForwardVector);
    setPositionAndLookat(cameraPos, cameraLookat);
  }
  
  
  PVector getCentre3DWindow(){
    
    float xc = width*0.5;
    float yc = height*0.5;
    return new PVector(xc,yc);
  }
  
 
    
    
  
  
  
  
  
  PVector projectWindowPosInto3D(PVector winPos){
    PVector pos3d = this.unProject(winPos.x, winPos.y, 0);
    
    return pos3d;
  }
  
  
  PVector unProject(float winX, float winY, float winZ) {
    PMatrix3D mat = getMatrixLocalToWindow();  
    mat.invert();
   
    float[] in = {winX, winY, winZ, 1.0f};
    float[] out = new float[4];
    mat.mult(in, out);  
   
    if (out[3] == 0 ) {
      return null;
    }
   
    PVector result = new PVector(out[0]/out[3], out[1]/out[3], out[2]/out[3]);  
    return result;
  }
  
  
  
  
  PMatrix3D getMatrixLocalToWindow() {
    PMatrix3D projection = ((PGraphics3D)g).projection; 
    PMatrix3D modelview = ((PGraphics3D)g).modelview;   
   
    
    PMatrix3D viewport = new PMatrix3D();
    viewport.m00 = viewport.m03 = width/2;
    viewport.m11 = -height/2;
    viewport.m13 =  height/2;
   
    
    
    viewport.apply(projection);
    viewport.apply(modelview);
    return viewport;
}
  
  PVector rotateVectorRoundAxis(PVector vec, PVector axis, float degs){
    
    float theta = radians(degs);
    float x, y, z;
    float u, v, w;
    x=vec.x;
    y=vec.y;
    z=vec.z;
    
    u=axis.x;
    v=axis.y;
    w=axis.z;
    
    float xrot = u*(u*x + v*y + w*z)*(1.0 - cos(theta)) + x* cos(theta) + (-w*y + v*z)* sin(theta);
    float yrot = v*(u*x + v*y + w*z)*(1.0 - cos(theta)) + y* cos(theta) + ( w*x - u*z)* sin(theta);
    float zrot = w*(u*x + v*y + w*z)*(1.0 - cos(theta)) + z* cos(theta) + (-v*x + u*y)* sin(theta);
    return new PVector(xrot, yrot, zrot);
  }
  

  
}
