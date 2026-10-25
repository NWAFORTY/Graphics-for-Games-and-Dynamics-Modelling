/**
 * Small vector/math helpers plus geometry utilities shared by intersections and demos.
 */

PVector vec(float x, float y, float z) {
  return new PVector(x, y, z);
}


PVector addV(PVector a, PVector b) {
  return PVector.add(a, b);
}


PVector subV(PVector a, PVector b) {
  return PVector.sub(a, b);
}


PVector crossV(PVector v1, PVector v2) {
  return v1.cross(v2);
}


PVector multV(PVector v, float f) {
  return PVector.mult(v, f);
}


float dotV(PVector v1, PVector v2) {
  return v1.dot(v2);
}


static float sqr(float a) {
  return a*a;
}


boolean isBetweenInc(float v, float lo, float hi) {

  float sortedLo = min(lo, hi);
  float sortedHi = max(lo, hi);

  if (v >= sortedLo && v <= sortedHi) return true;
  return false;
}


boolean nearZero(float v) {

  if ( abs(v) <= EPSILON ) return true;
  return false;
}


float min3(float a, float b, float c) {
  return  min( min(a, b), c);
}


float max3(float a, float b, float c) {
  return  max( max(a, b), c);
}


void drawPoint(PVector p, color c, float size) {
  pushStyle();
  strokeWeight(size);
  stroke(c);
  point(p.x, p.y, p.z);
  popStyle();
}


void drawMajorAxis(PVector p, float len) {

  PVector topOfLine = new PVector(p.x, p.y+len, p.z);
  PVector intoScene = new PVector(p.x, p.y, p.z+len);
  PVector sideways  = new PVector(p.x+len, p.y, p.z);

  hint(DISABLE_DEPTH_TEST);
  
  stroke(255, 0, 0);
  line(p.x, p.y, p.z, sideways.x, sideways.y, sideways.z);

  
  stroke(0, 255, 0);
  line(p.x, p.y, p.z, topOfLine.x, topOfLine.y, topOfLine.z);

  
  stroke(0, 0, 255);
  line(p.x, p.y, p.z, intoScene.x, intoScene.y, intoScene.z);
  hint(ENABLE_DEPTH_TEST);
}


class SimExtents {
  PVector minExtents;
  PVector maxExtents;
  PVector centrePoint;
  PVector furthestPointFromCentre;

  public SimExtents() {
    
  }

  public SimExtents(PVector[] points) {
    calculateExtents(points);
  }
  

  void calculateExtents(PVector[] points) {


    float minx = Float.MAX_VALUE;
    float miny = Float.MAX_VALUE;
    float minz = Float.MAX_VALUE;

    float maxx = -Float.MAX_VALUE;
    float maxy = -Float.MAX_VALUE;
    float maxz = -Float.MAX_VALUE;
    for (PVector p : points) {
      if (p.x < minx) minx = p.x;
      if (p.y < miny) miny = p.y;
      if (p.z < minz) minz = p.z;
      if (p.x > maxx) maxx = p.x;
      if (p.y > maxy) maxy = p.y;
      if (p.z > maxz) maxz = p.z;
    }
    minExtents = new PVector(minx, miny, minz);
    maxExtents = new PVector(maxx, maxy, maxz);

    centrePoint = minExtents.copy();
    centrePoint.lerp(maxExtents, 0.5);

    
    PVector furthest = centrePoint.copy();
    for (PVector p : points) {
      if (centrePoint.dist(p) > centrePoint.dist(furthest)) {
        furthestPointFromCentre = p.copy();
      }
    }
  }
  
  PVector getMin(){
    return minExtents;
  }
  
  PVector getMax(){
    return maxExtents;
  }
  
  PVector getCentre(){
    return centrePoint;
  }

  PVector getFurthestPoint() {
    return furthestPointFromCentre;
  }
  
  float getRadius() {
    return furthestPointFromCentre.dist(centrePoint);
  }

  void drawMe() {
    SimBox bb = new SimBox();
    bb.setWithExtents(minExtents, maxExtents);
    bb.drawMe();
  }
  
  SimBox getSimBox(){
    SimBox bb = new SimBox();
    bb.setWithExtents(minExtents, maxExtents);
    return bb;
  }

  
  
  
  
}


class SimRay {

  
  PVector origin = vec(0, 0, 0);
  PVector direction = vec(0, 0, -1);


  
  
  
  boolean intersectionFound = false;

  
  private Sim3DObject intersectionSim3DObject = null;

  
  private PVector intersectionPoint;

  
  private PVector intersectionNormal;

  
  SimTriangle nearestIntersectingTriangle = null;
  ArrayList<SimTriangle> intersectingTriangleList = new ArrayList<SimTriangle>();


  public SimRay() {
  }

  public SimRay(PVector pOrig, PVector v2) {
    origin = pOrig.copy();
    direction = v2.copy();
    direction.normalize();
  }

  void setWithOriginAndSecondPoint(PVector pOrig, PVector v2) {
    origin = pOrig.copy();
    direction = PVector.sub(v2, pOrig);
    direction.normalize();
  }

  PVector getDirection(){
    return direction.copy();
  }
  
  PVector getStartPoint(){
    return origin.copy();
  }

  
  
  

  boolean isIntersection() {
    return intersectionFound;
  }

  public PVector getIntersectionPoint() {
    
    return this.intersectionPoint;
  }

  public PVector getIntersectionNormal() {
    return this.intersectionNormal;
  }

  public Sim3DObject getIntersectionSim3DObject() {
    return intersectionSim3DObject;
  }

  int getNumIntersections() {
    
    return intersectingTriangleList.size();
  }


  PVector getPointAtDistance(float d) {
    
    PVector p1 = PVector.mult(direction, d);
    return PVector.add(p1, origin);
  }

  
  SimRay copy() {
    SimRay sr =  new SimRay();
    sr.origin = this.origin.copy();
    sr.direction = this.direction.copy();

    return sr;
  }
  
  void drawMe(float len) {
    pushStyle();
    PVector farPoint = getPointAtDistance(len);
    strokeWeight(g.strokeWeight);
    stroke(g.strokeColor);
    line(origin.x, origin.y, origin.z, farPoint.x, farPoint.y, farPoint.z);
    popStyle();
  }


  
  
  
  
  
  
  void setIntersectionNormal(PVector n) {
    this.intersectionNormal = n.copy();
    this.intersectionNormal.normalize();
  }


  public boolean addIntersectingTriangle(SimTriangle t) {
    boolean intersects = intersections_TriangleRay(t, this);


    if ( intersects ) {
      intersectingTriangleList.add(t);
      return true;
    }
    return false;
  }

  public void clearIntersectingTriangles() {
    intersectingTriangleList.clear();
  }

  PVector getNearestTriangleIntersectionPoint() {
    PVector nearestIntersectionPoint = vec(0, 0, 0);
    float nearestIntersectionDistance = 10000000000.0;
    PVector nearestSurfaceNormal = vec(0, 0, 0);
    for (SimTriangle t : intersectingTriangleList) {

      if ( intersections_TriangleRay(t, this) ) {
        PVector rayIntersectionPoint = getIntersectionPoint();
        PVector rayOrigin = origin.copy();
        float thisPointDistToRayOrigin = PVector.dist(rayIntersectionPoint, rayOrigin);
        if (thisPointDistToRayOrigin < nearestIntersectionDistance) {
          nearestIntersectionDistance = thisPointDistToRayOrigin;
          nearestIntersectionPoint = rayIntersectionPoint;
          nearestSurfaceNormal = t.surfaceNormal();
          nearestIntersectingTriangle = t;
        }
      }
    }
    this.intersectionPoint = nearestIntersectionPoint;
    this.setIntersectionNormal(nearestSurfaceNormal);
    return nearestIntersectionPoint;
  }
}


class SimTriangle {
  public PVector p1, p2, p3;
  SimExtents cachedExtents;
  public SimTriangle(PVector p1, PVector p2, PVector p3) {
    this.p1 = p1;
    this.p2 = p2;
    this.p3 = p3;
    cacheExtents();
  }

  public SimTriangle() {
    
    this.p1 = new PVector(0, 0, 0);
    this.p2 = new PVector(1, 0, 0);
    this.p3 = new PVector(0, 0, 1);
    cacheExtents();
  }
  
  public SimTriangle copy(){
    return new SimTriangle(p1.copy(), p2.copy(), p3.copy());
  }

  void flip() {
    
    
    PVector oldP2 = this.p2.copy();
    PVector oldP3 = this.p3.copy();
    this.p2 = oldP3;
    this.p3 = oldP2;
    cacheExtents();
    
  }

  
  void drawMe() {
    beginShape(TRIANGLE);
    vertex(this.p1.x, this.p1.y, this.p1.z);
    vertex(this.p2.x, this.p2.y, this.p2.z);
    vertex(this.p3.x, this.p3.y, this.p3.z);
    endShape(CLOSE);
  }


  PVector surfaceNormal() {
    PVector edgep1p2 = PVector.sub(p2, p1);
    PVector edgep1p3 = PVector.sub(p3, p1);
    PVector cross = edgep1p2.cross(edgep1p3);
    cross.y *= -1;
    return cross;
  }

  SimExtents getExtents() {
    
    if( cachedExtents != null ) return cachedExtents;
    
    PVector[] points =  {p1,p2,p3};
    cachedExtents = new SimExtents(points);
    
    return cachedExtents;
  }
  
  void cacheExtents(){
    cachedExtents = null;
    getExtents();
  }

  PVector closestPointOnTriangle(PVector p)
  {
    PVector a = p1.copy();
    PVector b = p2.copy();
    PVector c = p3.copy();

    PVector ab = subV(b, a);
    PVector ac = subV(c, a);
    PVector ap = subV(p, a);

    float d1 = dotV(ab, ap);
    float d2 = dotV(ac, ap);
    if (d1 <= 0.f && d2 <= 0.f) return a; 

    PVector bp = subV(p, b);
    float d3 = dotV(ab, bp);
    float d4 = dotV(ac, bp);
    if (d3 >= 0.f && d4 <= d3) return b; 

    PVector cp = subV(p, c);
    float d5 = dotV(ab, cp);
    float d6 = dotV(ac, cp);
    if (d6 >= 0.f && d5 <= d6) return c; 

    float vc = d1 * d4 - d3 * d2;
    if (vc <= 0.f && d1 >= 0.f && d3 <= 0.f)
    {
      float v = d1 / (d1 - d3);
      return addV(a, multV(ab, v)); 
    }

    float vb = d5 * d2 - d1 * d6;
    if (vb <= 0.f && d2 >= 0.f && d6 <= 0.f)
    {
      float v = d2 / (d2 - d6);
      return addV(a, multV(ac, v)); 
    }

    float va = d3 * d6 - d5 * d4;
    if (va <= 0.f && (d4 - d3) >= 0.f && (d5 - d6) >= 0.f)
    {
      float v = (d4 - d3) / ((d4 - d3) + (d5 - d6));
      PVector cb = subV(c, b);
      return addV(b, multV( cb, v )); 
    }

    float denom = 1.f / (va + vb + vc);
    float v = vb * denom;
    float w = vc * denom;

    PVector aPlusVMultAB = addV(a, multV(ab, v) );
    PVector acMultW = multV(ac, w);

    return addV( aPlusVMultAB, acMultW);
    
  }
  
  
  void applyTransform(Sim3DObject simObj){
    
    PVector[] points =  {p1,p2,p3};
    PVector[] transformedPoints = simObj.transformVertices(points);
    p1 = transformedPoints[0];
    p2 = transformedPoints[1];
    p3 = transformedPoints[2];
    cacheExtents();
  }
  
  
}


class SimFacet {
  
  private SimTriangle tri1;
  private SimTriangle tri2;

  public SimFacet() {
    setVertices( vec(0,0,0), vec(1,0,0), vec(1,0,1), vec(0,1,0) );
  }

  
  public SimFacet(PVector p1, PVector p2, PVector p3, PVector p4) {
    setVertices(p1, p2, p3, p4);
  }

  void setVertices( PVector p1, PVector p2, PVector p3, PVector p4) {
    
    
    tri1 = new SimTriangle(p1, p2, p3);
    tri2 = new SimTriangle(p1, p3, p4);
  }

  PVector[] getVertices() {
    PVector[] verts = new PVector[4];
    verts[0] = tri1.p1.copy();
    verts[1] = tri1.p2.copy();
    verts[2] = tri1.p3.copy();
    verts[3] = tri2.p3.copy();
    return verts;
  }
  
  SimTriangle getTriangle1(){
    return tri1.copy(); 
  }
  
  SimTriangle getTriangle2(){
    return tri2.copy(); 
  }
  
  SimExtents getExtents() {
    return new SimExtents(getVertices());
  }
  
  void applyTransform(Sim3DObject simObj){
    
    PVector[] transformedPoints = simObj.transformVertices(getVertices());
    setVertices(  transformedPoints[0],transformedPoints[1],transformedPoints[2],transformedPoints[3]);
  }
  
  void drawMe(){
    tri1.drawMe();
    tri2.drawMe();
  }
  
}
