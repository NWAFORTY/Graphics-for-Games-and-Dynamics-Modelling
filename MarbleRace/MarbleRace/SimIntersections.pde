/**
 * Broad/narrow phase intersection tests between Sim3DObject kinds. Entry points resolve SimModel to a
 * bounding primitive, then dispatch to sphere–sphere, sphere–box, mesh cases, etc.
 */

boolean intersections_Sim3DObjectSim3DObject(Sim3DObject thisObj, Sim3DObject otherObj){
  
  
  if( thisObj == otherObj) return false;
  
  
  String thisObjectType = thisObj.getClassName();
  String otherObjectType = otherObj.getClassName();
  
  
  if( thisObjectType.equals("SimModel")) {
    thisObj = ((SimModel)thisObj).getTransformedBoundingVolume();
    thisObjectType = thisObj.getClassName();
  }
  if( otherObjectType.equals("SimModel")) {
    otherObj = ((SimModel)otherObj).getTransformedBoundingVolume();
    otherObjectType = otherObj.getClassName();
  }
  
  
  
  if( thisObjectType.equals("SimSphere") ){
    if( otherObjectType.equals("SimSphere")) return intersections_SphereSphere((SimSphere)thisObj, (SimSphere)otherObj);
    if( otherObjectType.equals("SimBox")) return intersections_SphereBox((SimSphere)thisObj, (SimBox)otherObj);
    if( otherObjectType.equals("SimSurfaceMesh")) return intersections_MeshSphere((SimSurfaceMesh)otherObj, (SimSphere)thisObj);
  }
  
  if( thisObjectType.equals("SimBox") ){
    if( otherObjectType.equals("SimSphere")) return intersections_SphereBox((SimSphere)otherObj, (SimBox)thisObj);
    if( otherObjectType.equals("SimBox")) return intersections_BoxBox((SimBox)thisObj, (SimBox)otherObj);
    if( otherObjectType.equals("SimSurfaceMesh")) return intersections_MeshBox((SimSurfaceMesh)otherObj, (SimBox)thisObj);
  }
  
  if( thisObjectType.equals("SimSurfaceMesh") ){ 
    if( otherObjectType.equals("SimSphere")) return intersections_MeshSphere((SimSurfaceMesh)thisObj, (SimSphere)otherObj);
    if( otherObjectType.equals("SimBox")) return intersections_MeshBox((SimSurfaceMesh)thisObj, (SimBox)otherObj);
    if( otherObjectType.equals("SimSurfaceMesh")) return intersections_MeshMesh((SimSurfaceMesh)thisObj, (SimSurfaceMesh)otherObj);
  }

  
  return false;
}


boolean intersections_Sim3DObjectRay(Sim3DObject Sim3DObject, SimRay ray){
  String objectType = Sim3DObject.getClassName();
  
  
  if( objectType.equals("SimModel")) {
    Sim3DObject = ((SimModel)Sim3DObject).getTransformedBoundingVolume();
    objectType = Sim3DObject.getClassName();
  }
  
  
  if( objectType.equals("SimSphere") ){
    return intersections_SphereRay((SimSphere)Sim3DObject,  ray);
  }
  
  if( objectType.contains("SimBox") ){
    return intersections_BoxRay((SimBox)Sim3DObject, ray);
  }
  
  if( objectType.equals("SimSurfaceMesh") ){
    return intersections_MeshRay((SimSurfaceMesh)Sim3DObject, ray);
  }
  

  
  return intersections_notCateredForYet(objectType, "Ray");
}


boolean intersections_Sim3DObjectPoint(Sim3DObject Sim3DObject, PVector point){
  String objectType = Sim3DObject.getClassName();
  
  
  if( objectType.equals("SimModel")) {
    Sim3DObject = ((SimModel)Sim3DObject).getTransformedBoundingVolume();
    objectType = Sim3DObject.getClassName();
  }
  
  
  if( objectType.equals("SimSphere") ){
    return intersections_SpherePoint((SimSphere)Sim3DObject, point);
  }
  
  if( objectType.equals("SimBox") ){
    return intersections_BoxPoint((SimBox) Sim3DObject, point);
  }
  
  if( objectType.equals("SimSurfaceMesh") ){
    
    
    return false;
  }

  
  return false;
}

boolean intersections_notCateredForYet(String thisType, String otherType){
  println("Intersection between a ", thisType, " and ", otherType, " is not catered for yet ");
  return false;
}


public boolean intersections_SpherePoint(SimSphere sphere, PVector p) {
    PVector transCen = sphere.getTransformedCentre();
    float transRad = sphere.getTransformedRadius();
    float distP_Cen = transCen.dist(p);
    if (distP_Cen < transRad) return true;
    return false;
  }

public  boolean intersections_SphereSphere(SimSphere sphereA, SimSphere sphereB) {
  
    PVector cenB = sphereB.getTransformedCentre();
    PVector cenA = sphereA.getTransformedCentre();
    float radiusB = sphereB.getTransformedRadius();
    float radiusA = sphereA.getTransformedRadius();
    if ( cenB.dist(cenA) < radiusA+radiusB ) return true;
    
    return false;
  }
  
public boolean intersections_SphereRay(SimSphere sphere, SimRay ray) {
    
    ray.intersectionFound = false;
    PVector sphereCen = sphere.getTransformedCentre();
    
    float sphereRad = sphere.getTransformedRadius();
    PVector sphereCenToRayOrigin = PVector.sub(ray.origin, sphereCen); 
    float b = PVector.dot(sphereCenToRayOrigin, ray.direction);
    float c = PVector.dot(sphereCenToRayOrigin, sphereCenToRayOrigin) - (sphereRad*sphereRad);

    if (c > 0 && b > 0) return false;
    
    float discr = b*b - c;

    
    if (discr < 0) return false;

    
    float t = -b - sqrt(discr);

    
    if (t < 0) { 
      t = 0;
      
    }
    

    PVector dirMult = PVector.mult(ray.direction, t);
    ray.intersectionPoint = PVector.add(ray.origin, dirMult );
    ray.setIntersectionNormal(  PVector.sub(ray.intersectionPoint, sphereCen) );
    ray.intersectionFound = true;
    ray.intersectionSim3DObject = sphere;
    return true;
  }
  
  
  boolean intersections_SphereBox(SimSphere sphere, SimBox box) {
    if ( box.isOriented() == true ) {
      return intersections_SphereOrientedBox( sphere,  box);
    }
    return intersections_SphereAABox( sphere,  box);
  }
  
  boolean intersections_SphereAABox(SimSphere sphere, SimBox box) {
    
    if ( box.isOriented() == true ) {
      
      println("isSphereAABoxIntersection:: this is not an AA Box! Please use isSphereBoxIntersection(...) ");
      return intersections_SphereOrientedBox( sphere,  box);
    }
    
    
      SimExtents exts = box.getTransformedExtents();
      PVector bmin = exts.minExtents;
      PVector bmax = exts.maxExtents;
      PVector c = sphere.getTransformedCentre();
      float r = sphere.getTransformedRadius();
      float r2 = r * r;
      float dmin = 0;

      if ( c.x < bmin.x ) {
        dmin += sqr( c.x - bmin.x );
      } else {
        if ( c.x > bmax.x ) {
          dmin += sqr( c.x - bmax.x );
        }
      }

      if ( c.y < bmin.y ) {
        dmin += sqr( c.y - bmin.y );
      } else {
        if ( c.y > bmax.y ) {
          dmin += sqr( c.y - bmax.y );
        }
      }

      if ( c.z < bmin.z ) {
        dmin += sqr( c.z - bmin.z );
      } else {
        if ( c.z > bmax.z ) {
          dmin += sqr( c.z - bmax.z );
        }
      }

      boolean intersects = dmin <= r2;
      return intersects;
  

    
  }
  
  
  boolean intersections_SphereOrientedBox(SimSphere sphere, SimBox box){
    
    
    
    
    PVector sphereCentre =  sphere.getTransformedCentre();
    float sphereRadius = sphere.getTransformedRadius();
    
    
    if( intersections_BoxPoint(box, sphereCentre) == true) return true;
    
    
    for (int i = 0; i < 6; i++) {

      SimFacet f = box.getTransformedFacet(i);
      SimTriangle t1 = f.tri1;
      SimTriangle t2 = f.tri2;
      
      PVector p1 = t1.closestPointOnTriangle(sphereCentre);
      if(p1.dist( sphereCentre ) < sphereRadius) return true;
      PVector p2 = t2.closestPointOnTriangle(sphereCentre);
      if(p2.dist( sphereCentre ) < sphereRadius) return true;
    }

    return false;
  } 
  
  
  boolean intersections_SphereTriangle(SimSphere sphere, SimTriangle tri){
    
    
    
    
    PVector sphereCentre =  sphere.getTransformedCentre();
    float sphereRadius = sphere.getTransformedRadius();
    
    PVector nearestPointOnTriangle = tri.closestPointOnTriangle(sphereCentre);
    float distanceSphereCenetreToClosestPointOnMesh  = sphereCentre.dist(nearestPointOnTriangle);
    if( distanceSphereCenetreToClosestPointOnMesh > sphereRadius) return false;
    return true;
  } 
  


boolean intersections_BoxBox(SimBox box1, SimBox box2){
  
  if( box1.isOriented()==false && box2.isOriented()==false){
    return intersections_AABoxAABox( box1,  box2);
  }
  
  return intersections_OrientedBoxOrientedBox( box1,  box2);
}


boolean intersections_AABoxAABox(SimBox box1, SimBox box2){
   
  if( box1.isOriented() || box2.isOriented()){
    
    println("isAABoxAABoxIntersection - boxes are oriented, please use isBoxBoxIntersection(SimBox box1, SimBox box2)");
    return intersections_OrientedBoxOrientedBox( box1,  box2);
  }
  
  
  SimExtents thisExts = box1.getTransformedExtents();
  SimExtents otherExts = box2.getTransformedExtents();
  

  return  intersections_ExtentsExtents(thisExts, otherExts);
}

boolean intersections_OrientedBoxOrientedBox(SimBox box1, SimBox box2){
  
  OrientedBox ob1 = new OrientedBox(box1);
  OrientedBox ob2 = new OrientedBox(box2);
  return  ob1.getOBOBCollision(ob2);
}


boolean intersections_BoxPoint(SimBox box, PVector p){
  
  
  if( box.isOriented() ){
      
      
      SimRay sr = new SimRay(p, vec(1,1,1) );
      box.intersects(sr);
      if( sr.getNumIntersections() == 1) return true;
      return false;
    }
      
    
    
    SimExtents extents = box.getTransformedExtents();
    
    return intersections_ExtentsPoint(extents,p);
}


  
  
  
  
  
  
  
  
  
  public boolean intersections_BoxRay(SimBox box, SimRay sr) {
    
    boolean intersectionFound = false;

    sr.clearIntersectingTriangles();
    for (int i = 0; i < 6; i++) {

      SimFacet f = box.getTransformedFacet(i);
      SimTriangle t1 = f.tri1;
      SimTriangle t2 = f.tri2;
      
      
      
      if ( sr.addIntersectingTriangle(t1) ) intersectionFound = true;
      if ( sr.addIntersectingTriangle(t2) ) intersectionFound = true;
    }

    if (intersectionFound) {
      sr.intersectionSim3DObject = box;
      sr.getNearestTriangleIntersectionPoint();
    }
    
    return intersectionFound;
  } 
  
  
  boolean intersections_BoxTriangle(SimBox box, SimTriangle tri){
    boolean intersectionFound = false;

    
    for (int i = 0; i < 6; i++) {

      SimFacet f = box.getTransformedFacet(i);
      intersectionFound = intersections_TriangleTriangle(f.tri1, tri);
      if(intersectionFound) break;
      intersectionFound = intersections_TriangleTriangle(f.tri2, tri);
      if(intersectionFound) break;
    }

    
    return intersectionFound;
  }
  


  
boolean intersections_MeshSphere(SimSurfaceMesh mesh, SimSphere sphere){
    
    
    
    
    PVector sphereCentre =  sphere.getTransformedCentre();
    float sphereRadius = sphere.getTransformedRadius();
    
    PVector nearestPointOnMesh = mesh.getClosestPointOnTransformedSurface(sphereCentre);
    float distanceSphereCenetreToClosestPointOnMesh  = sphereCentre.dist(nearestPointOnMesh);
    if( distanceSphereCenetreToClosestPointOnMesh > sphereRadius) return false;
    return true;
  } 
  
  boolean intersections_MeshBox(SimSurfaceMesh mesh, SimBox box){
    
    
    
    
    
    SimExtents boxExtents = box.getTransformedExtents();
   
    
    
    
    SimTriangle[] meshTriangles = mesh.getTransformedTriangles();
    boolean intersectionFound = false;
    
    for(int i = 0; i < meshTriangles.length; i++){
      
      SimTriangle thisMeshTriangle = meshTriangles[i];
      
      if( intersections_ExtentsExtents( boxExtents, thisMeshTriangle.getExtents() )) {
        intersectionFound = intersections_BoxTriangle( box, thisMeshTriangle);
      }
      
      if(intersectionFound) break;
      
    }
    
    return intersectionFound;
  } 
  
  

public boolean intersections_MeshRay(SimSurfaceMesh mesh, SimRay sr){
    boolean intersectionFound = false;
    
    int numFacets = mesh.getNumFacets();
    sr.clearIntersectingTriangles();
    for (int i = 0; i < numFacets; i++) {
          
          SimFacet f = mesh.getTransformedFacet(i);
          SimTriangle t1 = f.tri1;
          SimTriangle t2 = f.tri2;

          
          
          if( sr.addIntersectingTriangle(t1) ) intersectionFound = true;
          if( sr.addIntersectingTriangle(t2) ) intersectionFound = true; 
        }
       
    if(intersectionFound){
      sr.getNearestTriangleIntersectionPoint();
      sr.intersectionSim3DObject = mesh;
    }
    return intersectionFound;
  } 
  
  
  public boolean intersections_MeshMesh(SimSurfaceMesh thisMesh, SimSurfaceMesh otherMesh){
    
    SimExtents thisExtents = thisMesh.getTransformedExtents();
    SimExtents otherExtents = otherMesh.getTransformedExtents();
    
    
    if( intersections_ExtentsExtents(thisExtents, otherExtents) == false ) return false;
    SimTriangle[] thisTriangles = thisMesh.getTransformedTriangles();
    SimTriangle[] otherTriangles = otherMesh.getTransformedTriangles();
    
    
    for(int thisTriangleIndex = 0; thisTriangleIndex < thisTriangles.length; thisTriangleIndex++){
      for(int otherTriangleIndex = 0; otherTriangleIndex < otherTriangles.length; otherTriangleIndex++){
       
       if( intersections_TriangleTriangle(thisTriangles[thisTriangleIndex], otherTriangles[otherTriangleIndex]) == true)
            return true;
        }
      
    }

    return false;
  }
  
  public boolean intersections_MeshTriangle(SimSurfaceMesh thisMesh, SimTriangle tri){
    
    SimExtents meshExtents = thisMesh.getTransformedExtents();
    SimExtents triExtents = tri.getExtents();
    
    
    if( intersections_ExtentsExtents(meshExtents, triExtents) == false ) return false;
    SimTriangle[] meshTriangles = thisMesh.getTransformedTriangles();
   
    
    
    for(int meshTriangleIndex = 0; meshTriangleIndex < meshTriangles.length; meshTriangleIndex++){
       if( intersections_TriangleTriangle(meshTriangles[meshTriangleIndex], tri) == true)
            return true;
    }

    return false;
  }


public boolean intersections_TriangleRay(SimTriangle triangle, SimRay ray) 
        {

        ray.intersectionPoint = null;
        
        
        PVector dir = ray.direction.copy();
        PVector orig = ray.origin.copy();
        PVector v0 = triangle.p1.copy();
        PVector v1 = triangle.p2.copy();
        PVector v2 = triangle.p3.copy();
        
        
        PVector edge_v0v1 = v1.sub(v0);
        PVector edge_v0v2 = v2.sub(v0);
        PVector pvec = dir.cross(edge_v0v2);
        
        float det = edge_v0v1.dot(pvec);
        
        if( nearZero(det) ){
          
          
          return false;
        }
        
        float invDet = 1.0/det;
        PVector tvec = PVector.sub(orig,v0);
        float u = tvec.dot(pvec) * invDet;
        if( u < 0 || u > 1) {
          return false;
        }
        
        PVector qvec = tvec.cross(edge_v0v1);
        float v = dir.dot(qvec) * invDet;
        if(v < 0 || u + v > 1){
          return false;
        }
        
        float t = edge_v0v2.dot(qvec) * invDet;
        if(t < EPSILON){
          
          
          return false;
        }
        PVector addToOrigin = PVector.mult(dir,t);
        ray.intersectionPoint = PVector.add(orig,addToOrigin);
        ray.nearestIntersectingTriangle = triangle;
        return true;
        
    }


 

boolean intersections_TriangleTriangle(SimTriangle t1, SimTriangle t2) {

  
  
  if(  intersections_ExtentsExtents(t1.getExtents() , t2.getExtents() ) == false ) return false;
  
  
  
  PVector t2SurfaceNormal = t2.surfaceNormal();
  if( t1.surfaceNormal().equals(  t2SurfaceNormal )) return false;
  if( t1.surfaceNormal().equals(  PVector.mult(t2SurfaceNormal, -1) )) return false;
  
  
  
  
  

  PVector E0 = subV(t1.p2,t1.p1);
  PVector E1 = subV(t1.p3,t1.p1);
  PVector E2 = subV(E1,E0);
  PVector N = crossV(E0,E1);


  
  

  PVector F0 = subV(t2.p2,t2.p1);
  PVector F1 = subV(t2.p3,t2.p1);
  PVector F2 = subV(F1,F0);
  PVector M = crossV(F0,F1);


  PVector D = subV(t2.p1,t1.p1);

  

  
  {
    float p0 = 0;
    float p1 = 0;
    float p2 = 0;
    float q0 = N.dot(D);
    float q1 = q0 + N.dot(F0);
    float q2 = q0 + N.dot(F1);

    if (areProjectionsSeparated(p0, p1, p2, q0, q1, q2))  return false;
  }


  
  {
    float p0 = 0;
    float p1 = M.dot(E0);
    float p2 = M.dot(E1);
    float q0 = M.dot(D);
    float q1 = q0;
    float q2 = q0;

    if (areProjectionsSeparated(p0, p1, p2, q0, q1, q2)) return false;
  }


  
  {
    float p0 = 0;
    float p1 = 0;
    float p2 = -(N.dot(F0));
    float q0 = crossV(E0,F0).dot(D);
    float q1 = q0;
    float q2 = q0 + M.dot(E0);

    if (areProjectionsSeparated(p0, p1, p2, q0, q1, q2)) return false;
  }


  
  {
    float p0 = 0;
    float p1 = 0;
    float p2 = -(N.dot(F1));
    float q0 = crossV(E0,F1).dot(D);
    float q1 = q0 - M.dot(E0);
    float q2 = q0;

    if (areProjectionsSeparated(p0, p1, p2, q0, q1, q2)) return false;
  }


  
  {
    float p0 = 0;
    float p1 = 0;
    float p2 = -(N.dot(F2));
    float q0 = crossV(E0,F2).dot(D);
    float q1 = q0 - M.dot(E0);
    float q2 = q1;

    if (areProjectionsSeparated(p0, p1, p2, q0, q1, q2)) return false;
  }


  
  {
    float p0 = 0;
    float p1 = N.dot(F0);
    float p2 = 0;
    float q0 = crossV(E1,F0).dot(D);
    float q1 = q0;
    float q2 = q0 + M.dot(E1);

    if (areProjectionsSeparated(p0, p1, p2, q0, q1, q2)) return false;
  }


  
  {
    float p0 = 0;
    float p1 = N.dot(F1);
    float p2 = 0;
    float q0 = crossV(E1,F1).dot(D);
    float q1 = q0 - M.dot(E1);
    float q2 = q0;

    if (areProjectionsSeparated(p0, p1, p2, q0, q1, q2)) return false;
  }


  
  {
    float p0 = 0;
    float p1 = N.dot(F2);
    float p2 = 0;
    float q0 = crossV(E1,F2).dot(D);
    float q1 = q0 - M.dot(E1);
    float q2 = q1;

    if (areProjectionsSeparated(p0, p1, p2, q0, q1, q2)) return false;
  }


  

  {
    float p0 = 0;
    float p1 = N.dot(F0);
    float p2 = p1;
    float q0 = crossV(E2,F0).dot(D);
    float q1 = q0;
    float q2 = q0 + M.dot(E2);

    if (areProjectionsSeparated(p0, p1, p2, q0, q1, q2))  return false;
  }


  
  {
    float p0 = 0;
    float p1 = N.dot(F1);
    float p2 = p1;
    float q0 = crossV(E2,F1).dot(D);
    float q1 = q0 - M.dot(E2);
    float q2 = q0;

    if (areProjectionsSeparated(p0, p1, p2, q0, q1, q2)) return false;
  }


  
  {
    float p0 = 0;
    float p1 = N.dot(F2);
    float p2 = p1;
    float q0 = crossV(E2,F2).dot(D);
    float q1 = q0 - M.dot(E2);
    float q2 = q1;

    if (areProjectionsSeparated(p0, p1, p2, q0, q1, q2)) return false;
  }


  return true;
} 


boolean areProjectionsSeparated(float p0, float p1, float p2, float q0, float q1, float q2) {
    
    float min_p = min3(p0, p1, p2);
    float max_p = max3(p0, p1, p2);
    float min_q = min3(q0, q1, q2);
    float max_q = max3(q0, q1, q2);

    return ((min_p > max_q) || (max_p < min_q));
  }


  
  
  
  
  
  
  
  
  
  
  
  boolean intersections_ExtentsExtents(SimExtents thisExts, SimExtents otherExts){
    
  
    return  (thisExts.minExtents.x < otherExts.maxExtents.x) && (thisExts.maxExtents.x > otherExts.minExtents.x) &&
            (thisExts.minExtents.y < otherExts.maxExtents.y) && (thisExts.maxExtents.y > otherExts.minExtents.y) &&
            (thisExts.minExtents.z < otherExts.maxExtents.z) && (thisExts.maxExtents.z > otherExts.minExtents.z);
  }
  
  
  
  
  boolean intersections_ExtentsPoint(SimExtents thisExts, PVector p){
    
    if (  isBetweenInc(p.x, thisExts.minExtents.x , thisExts.maxExtents.x)   &&
          isBetweenInc(p.y, thisExts.minExtents.y , thisExts.maxExtents.y)   &&
          isBetweenInc(p.z, thisExts.minExtents.z , thisExts.maxExtents.z)  ) return true;
    return false;
  }
  
  
  


class OrientedBox{
  
  PVector Pos;
  
  
  PVector AxisX, AxisY, AxisZ; 
  
  PVector Half_size;
  
  OrientedBox(){
    
  }
  
  OrientedBox(float w, float h, float d){
    AxisX = vec( 1.f, 0.f, 0.f );
    AxisY = vec( 0.f, 1.f, 0.f );
    AxisZ = vec( 0.f, 0.f, 1.f );
    Pos = vec(0,0,0);
    Half_size = vec(w/2, h/2, d/2);
  }
  
  OrientedBox(SimBox simbox){
   
    Pos = simbox.getTransformedCentre();
    
    PVector[] axes = simbox.getTransformedAxes();
    float w = axes[0].mag();
    float h = axes[1].mag();
    float d = axes[2].mag();
    
    Half_size = new PVector(w/2,h/2,d/2);
    AxisX = axes[0].normalize();
    AxisY = axes[1].normalize();
    AxisZ = axes[2].normalize();
    
  }
  
  
  boolean getSeparatingPlane(PVector RPos, PVector Plane, OrientedBox box1,  OrientedBox box2) {
  
      if(  abs(   dotV(RPos,Plane) ) > 
         ( abs(   dotV( multV(box1.AxisX,box1.Half_size.x) , Plane ) ) +
           abs(   dotV( multV(box1.AxisY,box1.Half_size.y) , Plane ) ) +
           abs(   dotV( multV(box1.AxisZ,box1.Half_size.z) , Plane ) ) +
           abs(   dotV( multV(box2.AxisX,box2.Half_size.x) , Plane ) ) + 
           abs(   dotV( multV(box2.AxisY,box2.Half_size.y) , Plane ) ) +
           abs(   dotV( multV(box2.AxisZ,box2.Half_size.z) , Plane ) ) )      
           ) return true;
      return false;
  }

  boolean getOBOBCollision(OrientedBox otherBox) 
  {
      PVector RPos = subV(otherBox.Pos, this.Pos);
  
      return !( getSeparatingPlane(RPos, this.AxisX, this, otherBox) ||
                getSeparatingPlane(RPos, this.AxisY, this, otherBox) ||
                getSeparatingPlane(RPos, this.AxisZ, this, otherBox) ||
                getSeparatingPlane(RPos, otherBox.AxisX, this, otherBox) ||
                getSeparatingPlane(RPos, otherBox.AxisY, this, otherBox) ||
                getSeparatingPlane(RPos, otherBox.AxisZ, this, otherBox) ||
                getSeparatingPlane(RPos, crossV(this.AxisX,otherBox.AxisX), this, otherBox) ||
                getSeparatingPlane(RPos, crossV(this.AxisX,otherBox.AxisY), this, otherBox) ||
                getSeparatingPlane(RPos, crossV(this.AxisX,otherBox.AxisZ), this, otherBox) ||
                getSeparatingPlane(RPos, crossV(this.AxisY,otherBox.AxisX), this, otherBox) ||
                getSeparatingPlane(RPos, crossV(this.AxisY,otherBox.AxisY), this, otherBox) ||
                getSeparatingPlane(RPos, crossV(this.AxisY,otherBox.AxisZ), this, otherBox) ||
                getSeparatingPlane(RPos, crossV(this.AxisZ,otherBox.AxisX), this, otherBox) ||
                getSeparatingPlane(RPos, crossV(this.AxisZ,otherBox.AxisY), this, otherBox) ||
                getSeparatingPlane(RPos, crossV(this.AxisZ,otherBox.AxisZ), this, otherBox));
  }

}
