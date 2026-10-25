/**
 * Lightweight motion record for demos: euler integrate velocity from acceleration/fiction.
 * Marble Race sketches usually bypass update() on marbles (custom sub-step solver) but still use the
 * same fields as the transform driver (velocity, radius, frictionAmount).
 */

class SimPhysics {

  Sim3DObject simObject = null;

  Timer timer = new Timer();
  
  PVector location = new PVector(width/2, height/2, 0);
  PVector velocity = new PVector(0, 0, 0);
  PVector acceleration = new PVector(0, 0, 0);
  private float mass = 1;
  float radius = 1;
  float frictionAmount = 0.3;


  SimPhysics() {
    setMass(1);
  }

  SimPhysics(Sim3DObject so, float mass) {
    simObject = so;
    radius = simObject.getTransformedRadius(); 
    location = simObject.translate.copy();
    setMass(mass);
  }


  
  
  
  
  
  
  
  void setMass(float m){
    
    mass=m;
    
    
  }
  
  void addForce(PVector f){
    
    PVector accelerationEffectOfForce = PVector.div(f, mass);
    acceleration.add(accelerationEffectOfForce);
  }

  
  
  void update() {
    /* Generic frame integrator — not wired for marbles while custom physics runs elsewhere. */
    float ellapsedTime = timer.getElapsedTime();
    
    applyFriction();
    
    
    PVector accelerationOverTime = PVector.mult(acceleration, ellapsedTime);
    velocity.add(accelerationOverTime);
    
    
    PVector distanceMoved = PVector.mult(velocity, ellapsedTime);
    location.add(distanceMoved);
    
    
    acceleration = new PVector(0, 0, 0);
    
    
  }
  
  
  
  void drawMe() {
    
    if(simObject == null){
      
      pushStyle();
        stroke(0);
        strokeWeight(2);
        fill(127);
        radius = 60 * sqrt( mass/ PI );
        ellipse(location.x, location.y, radius*2, radius*2);
      popStyle();
    } else {
      
      simObject.setTranslation(location.x, location.y, location.z);
      simObject.drawMe();
    }
    
  }
  
  
  
  
  void applyFriction(){
    
    
    
    PVector reverseForce = PVector.mult( velocity, -frictionAmount );
    addForce(reverseForce);
  }
  
  
  
  
  
  boolean collisionCheck(SimPhysics otherMover){
    
    if(simObject != null){
      return this.simObject.intersects( otherMover.simObject );
    }
    
    if(otherMover == this) return false; 
    
    float distance = otherMover.location.dist(this.location);
    float minDist = otherMover.radius + this.radius;
    if (distance < minDist)  return true;
    return false;
  }
  
  
  boolean intersects(SimPhysics otherMover){
    return this.simObject.intersects( otherMover.simObject );
  }
  
  
  boolean intersects(Sim3DObject otherSimObject){
    return this.simObject.intersects( otherSimObject );
  }
  
  
  void collisionResponse(SimPhysics otherMover) {
    
    
    
    
    
    
    
    if(otherMover == this) return; 
     
     
    PVector v1 = this.velocity;
    PVector v2 = otherMover.velocity;
    
    PVector cen1 = this.location;
    PVector cen2 = otherMover.location;
    
    
    float massPart1 = 2*otherMover.mass / (this.mass + otherMover.mass);
    PVector v1subv2 = PVector.sub(v1,v2);
    PVector cen1subCen2 = PVector.sub(cen1,cen2);
    float topBit1 = v1subv2.dot(cen1subCen2);
    float bottomBit1 = cen1subCen2.mag()*cen1subCen2.mag();
    if (bottomBit1 < 1e-8) return;
    
    float multiplyer1 = massPart1 * (topBit1/bottomBit1);
    PVector changeV1 = PVector.mult(cen1subCen2, multiplyer1);
    
    PVector v1New = PVector.sub(v1,changeV1);
    
    
    float massPart2 = 2*this.mass/(this.mass + otherMover.mass);
    PVector v2subv1 = PVector.sub(v2,v1);
    PVector cen2subCen1 = PVector.sub(cen2,cen1);
    float topBit2 = v2subv1.dot(cen2subCen1);
    float multiplyer2 = massPart2 * (topBit2/bottomBit1);
    PVector changeV2 = PVector.mult(cen2subCen1, multiplyer2);
    
    PVector v2New = PVector.sub(v2,changeV2);
    
    this.velocity = v1New;
    otherMover.velocity = v2New;
    ensureNoOverlap(otherMover);
  }
  
 
  void ensureNoOverlap(SimPhysics otherMover){
    
    
    
    
    
    PVector cen1 = this.location;
    PVector cen2 = otherMover.location;
    
    float cumulativeRadii = (this.radius + otherMover.radius)+2; 
    float distanceBetween = cen1.dist(cen2);
    
    float overlap = cumulativeRadii - distanceBetween;
    if(overlap > 0){
      
      PVector vectorAwayFromOtherNormalized = PVector.sub(cen1, cen2).normalize();
      PVector amountToMove = PVector.mult(vectorAwayFromOtherNormalized, overlap);
      this.location.add(amountToMove);
    }
  }

}


class Timer{
  
  int startMillis = 0;
  float lastNow;
  public Timer(){
    start();
  }
  
  
  void start(){
    startMillis = millis();
    
    lastNow = 0;
  }
  
  
  
  float getElapsedTime(){
    float now =  getTimeSinceStart();
    float elapsedTime = now - lastNow;
    lastNow = now;
    return elapsedTime;
    
  }
  
  
  
  float getTimeSinceStart(){
    return ((millis()-startMillis)/1000.0);
  }
  
  
}
