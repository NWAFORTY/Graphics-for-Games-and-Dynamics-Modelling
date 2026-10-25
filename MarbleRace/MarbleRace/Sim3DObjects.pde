/**
 * Base type for movable scene solids: spheres, boxes, meshes, rays. Tracks scale/rotation/translation,
 * computes world extents, exposes closest-point helpers for collisions. Derived types implement drawing
 * and extent queries; pairwise hit tests delegate to intersections_*(SimIntersections tab).
 */

abstract class Sim3DObject{


  abstract void drawMe();
  
  abstract SimExtents getTransformedExtents();
  
  
  
  String myTag = "unnamed";

  
   
  
  
  
  
  public boolean intersects(Sim3DObject other){
    return intersections_Sim3DObjectSim3DObject(this, other);
    
  }
  
  public boolean intersects(SimRay ray){
    return intersections_Sim3DObjectRay( this,  ray);
  }
  
  public boolean intersects(PVector point){
    return intersections_Sim3DObjectPoint(this,  point);
  }
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  float scale = 1;
  float rotateX, rotateY, rotateZ = 0.0;
  PVector translate = new PVector(0, 0, 0);
  
  
  private float sinRotateX, sinRotateY, sinRotateZ = 0;
  private float cosRotateX=1, cosRotateY=1, cosRotateZ=1;
  
  void preCalculateSinCosRotations(){
    sinRotateX = sin(rotateX); 
    sinRotateY = sin(rotateY);
    sinRotateZ = sin(rotateZ);
    cosRotateX = cos(rotateX);
    cosRotateY = cos(rotateY);
    cosRotateZ = cos(rotateZ);
    
  }
  
  void setIdentityTransform() {
    
    setTransform( 1, 0, 0, 0, vec(0, 0, 0));
  }
  
  
  
  
  
  void setTransform(float scale, float rotateX, float rotateY, float rotateZ, PVector translate) {
    setScale(scale);
    setTranslation(translate);
    setRotation( rotateX,  rotateY,  rotateZ);
  }
  
  
  
  
  
  void setScale(float s){
    if( nearZero(s) ) {
      println("You are scaling to near zero - not allowed");
      return;
    }
    this.scale = s;
    
  }
  
  
  void setRotation(float rotateX, float rotateY, float rotateZ){
    this.rotateX = rotateX;
    this.rotateY = rotateY;
    this.rotateZ = rotateZ;
    preCalculateSinCosRotations();
  }
  
  void setTranslation(PVector t){
    this.translate = t.copy();
  }
  
  void setTranslation(float tX, float tY, float tZ){
    setTranslation( new PVector(tX,tY,tZ) );
  }
  
  
  
  
  
  
  void tweakRotation(float rotateX, float rotateY, float rotateZ){
    this.rotateX += rotateX;
    this.rotateY += rotateY;
    this.rotateZ += rotateZ;
    preCalculateSinCosRotations();
  }
  
  void tweakTranslation(PVector t){
    this.translate.add(t);
  }
  
  void tweakTranslation(float tX, float tY, float tZ){
    tweakTranslation( new PVector(tX,tY,tZ) );
  }

  
  
  
  
  
  
  
  
  
  public PVector transform(PVector pIn) {
    
    PVector p = pIn.copy();
    
    
    PVector scaled = p.mult(this.scale);

    float x = scaled.x;
    float y = scaled.y;
    float z = scaled.z;

    
    
    float y1 = y*cosRotateX  - z*sinRotateX;
    float z1 = y*sinRotateX  + z*cosRotateX ;
    float x1 = x;
    
    float z2 = z1*cosRotateY  - x1*sinRotateY;
    float x2 = z1*sinRotateY +  x1*cosRotateY;
    float y2 = y1;
    
    float x3 = x2*cosRotateZ  - y2*sinRotateZ ;
    float y3 = x2*sinRotateZ  + y2*cosRotateZ ;
    float z3 = z2;

    PVector rotated = new PVector(x3, y3, z3);

    
    
    PVector translated = rotated.add(translate);
    return translated;
  }
  
  
  
  
  
  PVector[] transformVertices(PVector[] vertices) {
    int numVerts = vertices.length;
    PVector[] transformedVerts = new PVector[numVerts];
    for (int n = 0; n < numVerts; n++) {
      transformedVerts[n] = transform(vertices[n]);
    }
    return transformedVerts;
  }


  SimExtents getTransformedExtents(PVector[] vertices) {
    PVector[] trasformedvertices = transformVertices(vertices);
    
    return new SimExtents(trasformedvertices);
  }
  
  float getTransformedRadius(){
    SimExtents extents = getTransformedExtents();
    return extents.getRadius();
  }
  
  PVector getTransformedCentre(){
    SimExtents extents = getTransformedExtents();
    return extents.centrePoint;
  }
  
  
  
  
  
  
  
  public void  drawTransformedVertex(PVector v) {
    PVector transformedVector = transform(v);
    vertex(transformedVector.x, transformedVector.y, transformedVector.z);
  }
  
  
  
  
  String getClassName(){
    return this.getClass().getSimpleName();
  }

  
}


class SimSphere extends Sim3DObject {
  
  
  private float radius = 1;
  
  
  public SimSphere() {
    radius = 1;
  }

  public SimSphere(float rad) {
    radius = rad;
  }

  public PVector getTransformedCentre() {
    return transform( vec(0,0,0) );
  }

  public void setRadius(float r) {
    this.radius = r;
  }

  float getTransformedRadius() {
    float tradius = this.radius;
    tradius *= this.scale;
    return tradius;
  }
  
  SimExtents getTransformedExtents(){
    
    
    
    float r = getTransformedRadius();
    PVector radiusVector = new PVector(r,r,r);
    
    SimExtents extents = new SimExtents();
    
    PVector centre = getTransformedCentre();
    extents.minExtents = PVector.sub( centre, radiusVector);
    extents.maxExtents = PVector.add( centre, radiusVector);
    extents.centrePoint = centre.copy();
    extents.furthestPointFromCentre = new PVector(0,r,0);
    return extents;
  }


  void drawMe() {
    
    float r = getTransformedRadius();
    PVector transCen = getTransformedCentre();
  
    pushMatrix();
    translate(transCen.x, transCen.y, transCen.z);
    sphere(r); 
    popMatrix();
  }
  
  
} 


class SimBox extends Sim3DObject{
  
  
  
  PVector minCorner;
  PVector maxCorner;

  
  int
    T1 = 0, 
    T2 = 1, 
    T3 = 2, 
    T4 = 3, 
    B1 = 4, 
    B2 = 5, 
    B3 = 6, 
    B4 = 7;


  PVector[] vertices;


  public SimBox() {
    setDimensions(1,1,1);
  }


  SimBox(float w, float h, float d){
    setDimensions(w,h,d);
  }
  
  
  boolean isOriented() {
     if ( this.rotateX == 0 &&  this.rotateY == 0 && this.rotateZ == 0) return false;
    return true;
  }
  
  
  OrientedBox getOrientedBox(){
    return new OrientedBox(this);
  }
  

  void setDimensions(float w, float h, float d) {
    float halfW = w/2;
    float halfH = h/2;
    float halfD = d/2;
    
    PVector c1 = new PVector(-halfW, -halfH, -halfD );
    PVector c2 = new PVector(halfW, halfH, halfD );
    setWithExtents(c1,c2);
  }
  
  void setWithExtents(PVector c1, PVector c2) {
    
    
    vertices = new PVector[8];
    
    
    setIdentityTransform();
    float minx = min(c1.x, c2.x);
    float miny = min(c1.y, c2.y);
    float minz = min(c1.z, c2.z);

    float maxx = max(c1.x, c2.x);
    float maxy = max(c1.y, c2.y);
    float maxz = max(c1.z, c2.z);

    minCorner = new PVector(minx, miny, minz);
    maxCorner = new PVector(maxx, maxy, maxz);
    createVertices();
  }

  int getNumFacets() { 
    return 6;
  }

  SimExtents getTransformedExtents() {
      return getTransformedExtents(vertices);
  }
  
  float getTransformedRadius(){
    return getTransformedExtents().getRadius();
    
  }

  private void createVertices() {
    
    float tx = minCorner.x;
    float ty = minCorner.y;
    float tz = minCorner.z;

    float bx = maxCorner.x;
    float by = maxCorner.y;
    float bz = maxCorner.z;
    
    vertices[T1] = new PVector(tx, ty, tz);
    vertices[T2] = new PVector(tx, ty, bz);
    vertices[T3] = new PVector(bx, ty, bz);
    vertices[T4] = new PVector(bx, ty, tz);
    
    vertices[B1] = new PVector(tx, by, tz);
    vertices[B2] = new PVector(tx, by, bz);
    vertices[B3] = new PVector(bx, by, bz);
    vertices[B4] = new PVector(bx, by, tz);
  }

  
  
  
  
  public PVector getTransformedCentre() {
    
    PVector minCornerTrans = transform(minCorner);
    PVector maxCornerTrans = transform(maxCorner);

    return minCornerTrans.lerp(maxCornerTrans, 0.5);
  }


  SimFacet getTransformedFacet(int num) {
    
    
    int v1, v2, v3, v4;

    
    
    v1 = T1;
    v2 = T4;
    v3 = B4;
    v4 = B1;

    
    if (num == 0) {
      v1 = T1;
      v2 = T2;
      v3 = T3;
      v4 = T4;
    }

    
    if (num == 2) {
      v1 = T1;
      v2 = B1;
      v3 = B2;
      v4 = T2;
    }

    
    if (num == 3) {
      v1 = T4;
      v2 = T3;
      v3 = B3;
      v4 = B4;
    }

    
    if (num == 4) {
      v1 = T2;
      v2 = B2;
      v3 = B3;
      v4 = T3;
    }

    
    if (num == 5) {
      v1 = B1;
      v2 = B4;
      v3 = B3;
      v4 = B2;
    }

    PVector p1 = transform(vertices[v1]);
    PVector p2 = transform(vertices[v2]);
    PVector p3 = transform(vertices[v3]);
    PVector p4 = transform(vertices[v4]);

    return new SimFacet(p1, p2, p3, p4);
  }
  
  
  PVector[] getTransformedAxes(){
    
    
    PVector t1 = transform(vertices[T1]);
    PVector t2 = transform(vertices[T2]);
    PVector t4 = transform(vertices[T4]);
    PVector b1 = transform(vertices[B1]);
    
    PVector[] axes = new PVector[3];
    
    axes[0] = subV(t4,t1);
    axes[1] = subV(b1,t1);
    axes[2] = subV(t2,t1);
    
    
    return axes;
  }


  
  public void drawMe() {
    
    beginShape();
    drawTransformedVertex(vertices[T1]);
    drawTransformedVertex(vertices[T2]);
    drawTransformedVertex(vertices[T3]);
    drawTransformedVertex(vertices[T4]);
    endShape(CLOSE);


    
    beginShape();
    drawTransformedVertex(vertices[T1]);
    drawTransformedVertex(vertices[T4]);
    drawTransformedVertex(vertices[B4]);
    drawTransformedVertex(vertices[B1]);
    endShape(CLOSE);


    
    beginShape();
    drawTransformedVertex(vertices[T1]);
    drawTransformedVertex(vertices[B1]);
    drawTransformedVertex(vertices[B2]);
    drawTransformedVertex(vertices[T2]);
    endShape(CLOSE);


    
    beginShape();
    drawTransformedVertex(vertices[T4]);
    drawTransformedVertex(vertices[T3]);
    drawTransformedVertex(vertices[B3]);
    drawTransformedVertex(vertices[B4]);
    endShape(CLOSE);


    
    beginShape();
    drawTransformedVertex(vertices[T2]);
    drawTransformedVertex(vertices[B2]);
    drawTransformedVertex(vertices[B3]);
    drawTransformedVertex(vertices[T3]);
    endShape(CLOSE);

    
    beginShape();
    drawTransformedVertex(vertices[B1]);
    drawTransformedVertex(vertices[B4]);
    drawTransformedVertex(vertices[B3]);
    drawTransformedVertex(vertices[B2]);
    endShape(CLOSE);
  }
} 


class SimModel extends Sim3DObject{
  
  
  
  
  
  
  
  private PShape originalModel;
  private PVector[] rawvertices;
  
  
  private SimSphere boundingSphere = new SimSphere();
  private SimBox boundingBox = new SimBox();

  private String preferredBoundingVolume;
  public int boundingVolumeTransparency = 50;
  public boolean showBoundingVolume = true;

  public SimModel() {
  }
  
  public SimModel(String filename){
    PShape mod = loadShape(filename);
    if(mod == null){
      println("SimModel: cannot load file name ", filename);
      return;
    }
    setWithPShape(mod);
    
  }
  
  public SimModel(PShape shapeIn){
    setWithPShape(shapeIn);
  }

  void setWithPShape(PShape shapeIn) {
    originalModel = shapeIn;
    calculateBoundingGeometry();
    setIdentityTransform();
  }

  void calculateBoundingGeometry() {
    
    
    
    rawvertices = getRawVertices();
    SimExtents extents = new SimExtents(rawvertices);
    
    boundingBox = new SimBox();
    boundingBox.setWithExtents(extents.minExtents, extents.maxExtents);
    
    
    boundingSphere = new SimSphere(extents.getRadius());
   
    preferredBoundingVolume = "box";
  }
  
  SimExtents getTransformedExtents(){
    return getTransformedExtents(rawvertices);
  }

  void setPreferredBoundingVolume(String BOXorSPHERE){
    String s = BOXorSPHERE.toLowerCase();
    if(s.equals("box")) preferredBoundingVolume = "box";
    if(s.equals("sphere")) preferredBoundingVolume = "sphere";
  }
  
  Sim3DObject getTransformedBoundingVolume(){
    
    if(preferredBoundingVolume.equals("box")) {
      return getTransformedBoundingBox();
    } else {  
      return getTransformedBoundingSphere(); 
    }
  }
  
  void showBoundingVolume(boolean show){
    showBoundingVolume = show;
  }


  PVector[] getRawVertices() {
    PShape flatmodel = originalModel.getTessellation(); 

    int total = flatmodel.getVertexCount();
    
    
    
    PVector[] vertices = new PVector[total];
    for (int j = 0; j < total; j++) {
      vertices[j] = flatmodel.getVertex(j);
    }
    return vertices;
  }
  

  SimSphere getTransformedBoundingSphere() {
    boundingSphere.setTransform( this.scale, this.rotateX, this.rotateY, this.rotateZ, this.translate);
    return boundingSphere;
  }

  SimBox getTransformedBoundingBox() {
    boundingBox.setTransform( this.scale, this.rotateX, this.rotateY, this.rotateZ, this.translate);
    return boundingBox;
  }


  void drawMe() {
    
    
    
    originalModel.resetMatrix();
    originalModel.scale(this.scale);
    originalModel.rotateX(this.rotateX);
    originalModel.rotateY(this.rotateY);
    originalModel.rotateZ(this.rotateZ); 
    originalModel.translate(this.translate.x, this.translate.y, this.translate.z);
    shape(originalModel);
    originalModel.resetMatrix();
    
    if(showBoundingVolume) drawBoundingVolume();
  }
  
  void drawBoundingVolume(){
    if(preferredBoundingVolume.equals("sphere")) drawBoundingSphere();
    if(preferredBoundingVolume.equals("box")) drawBoundingBox();
  }

  void drawBoundingSphere() {
    color cc = g.fillColor;
    
    
    pushStyle();
    fill( red(cc),green(cc), blue(cc),boundingVolumeTransparency);
    SimSphere bs = getTransformedBoundingSphere();
    
    bs.drawMe();
    popStyle();
  }

  void drawBoundingBox() {
    SimBox bb = getTransformedBoundingBox();
    color cc = g.fillColor;
    
    
    pushStyle();
    fill( red(cc),green(cc), blue(cc),boundingVolumeTransparency);
    bb.drawMe();
    popStyle();
  }
  
  
} 


class SimSurfaceMesh  extends Sim3DObject{

    int numFacetsX, numFacetsZ;
    
    
    PVector[] meshVertices;

    
    
    
    
    
    
    
    PImage textureMap;
    
    public SimSurfaceMesh(int numInX, int numInZ, float sizeOfFacet)
    {
        
        
        
        
        numFacetsX = numInX;
        numFacetsZ = numInZ;
        
        meshVertices = new PVector[(numFacetsX+1)*(numFacetsZ+1)];
        
        float centreOffsetX = (numFacetsX * sizeOfFacet)/2f;
        float centreOffsetZ = (numFacetsZ * sizeOfFacet)/2f;
        
        
        for(int z = 0; z < numFacetsZ+1; z++)
        {
            for (int x = 0; x < numFacetsX+1; x++)
            {
                float xf = x * sizeOfFacet - centreOffsetX;
                float yf = 0.0f;
                float zf = z * sizeOfFacet - centreOffsetZ;
                setMeshVertex(x,z,  new PVector(xf, yf, zf) );
            }
            
        }

    }
    
    
    void setHeightsFromImage(PImage im, float maxAltitude){
    
      int numInX = getNumVerticesX();
      int numInZ = getNumVerticesZ();
      int imWidth = im.width;
      int imHeight = im.height;
      
      for(int z = 0; z < numInZ; z++)
          {
              for (int x = 0; x < numInX; x++)
              {
                 int imx = (int) map(x,0,numInX,0,imWidth);
                 int imy = (int) map(z,0,numInZ,0,imHeight);
                 color col = im.get(imx,imy);
                 float hght = map(red(col),0,255,0,maxAltitude);
                 setVertexY(x,z,hght );
              }
              
          }
    
    }
    
    
    void setTextureMap(PImage t){
      textureMap = t.copy();
    }
    
    
    
    
    void bakeInTransform(){
      meshVertices = transformVertices(meshVertices);
      setTransform(1.0,0.0,0.0,0.0, vec(0,0,0));
    }
    
    
    
    
    void drawMe(){
      if ( textureMap != null) {
      drawMe_Texture();
      return;
      }
      int numFacets = getNumFacets();
      beginShape(TRIANGLES);
        
        
        
        for (int i = 0; i < numFacets; i++) {
          SimFacet f = getFacet(i);
          SimTriangle t1 = f.tri1;
          SimTriangle t2 = f.tri2;
          
          drawTransformedVertex(t1.p1);
          drawTransformedVertex(t1.p2);
          drawTransformedVertex(t1.p3);
          
          drawTransformedVertex(t2.p1);
          drawTransformedVertex(t2.p2);
          drawTransformedVertex(t2.p3);
        }
        endShape();
    }
    
    void drawMe_Texture() {
      int numFacets = getNumFacets();
      beginShape(TRIANGLES);
      texture(textureMap);
      
      for (int i = 0; i < numFacets; i++) {
       
        SimFacet f = getFacet(i);
        SimTriangle t1 = f.tri1;
        SimTriangle t2 = f.tri2;
   
        drawTransformedVertex_Texture(t1.p1);
        drawTransformedVertex_Texture(t1.p2);
        drawTransformedVertex_Texture(t1.p3);
  
        drawTransformedVertex_Texture(t2.p1);
        drawTransformedVertex_Texture(t2.p2);
        drawTransformedVertex_Texture(t2.p3);
        }
      
      endShape();
  }
  
  
  
  
  
  public void  drawTransformedVertex_Texture(PVector vertex) {
    PVector transformedVector = transform(vertex);
    PVector uv = getTextureUV(vertex);
    vertex(transformedVector.x, transformedVector.y, transformedVector.z, uv.x, uv.y);
  }
  
  SimFacet getTransformedFacet(int index){
      SimFacet facet = getFacet( index);
      PVector[] verts = facet.getVertices();
      PVector[] transformedVerts = new PVector[4];
      for(int n = 0; n < 4; n++) transformedVerts[n] = transform(verts[n]);
      return new SimFacet(transformedVerts[0],transformedVerts[1],transformedVerts[2],transformedVerts[3]);
    }
    
   
    
   
   SimTriangle[] getTransformedTriangles(){
      int numFacets = getNumFacets();
      int numTriangles = numFacets*2;
      
      SimTriangle[] triangles = new SimTriangle[numTriangles];
      int triangleIndex = 0;
      for (int i = 0; i < numFacets; i++) {
       
        SimFacet f = getTransformedFacet(i);
        
        
        f.tri1.cacheExtents();
        f.tri2.cacheExtents();
        
        triangles[triangleIndex] = f.tri1;
        triangleIndex++;
        triangles[triangleIndex] = f.tri2;
        triangleIndex++;

      }
      
      return triangles;
     
   }
    
  
  public PVector[] getTransformedVertices(){
    return transformVertices(meshVertices);
  }
  
  public SimExtents getTransformedExtents(){
    PVector[] tv = getTransformedVertices();
    return new SimExtents(tv);
  }
  
  
  SimTriangle getClosestTransformedTriangle(PVector p){
      SimTriangle closestTriangle = null;
      float closestDistance = 1000000000.0;
      int numFacets = getNumFacets();
      for (int i = 0; i < numFacets; i++) {
       
        SimFacet f = getTransformedFacet(i);
        PVector closestPoint = f.tri1.closestPointOnTriangle(p);
        float dist = closestPoint.dist(p);
        if(dist < closestDistance){
          closestDistance = dist;
          closestTriangle = f.tri1;
        }
        
        closestPoint = f.tri2.closestPointOnTriangle(p);
        dist = closestPoint.dist(p);
        if(dist < closestDistance){
          closestDistance = dist;
          closestTriangle = f.tri2;
        }
        
      }
      
      return closestTriangle;
      
    }
    
  
  PVector getClosestPointOnTransformedSurface(PVector p){
      SimTriangle closestTriangle = getClosestTransformedTriangle(p);
      return closestTriangle.closestPointOnTriangle(p);
    }
    
    
  
  
  
  
  
  PVector getTextureUV(PVector vertex){
    int w = textureMap.width;
    int h = textureMap.height;
    PVector minVertex = getMeshVertex(0, 0);
    PVector maxVertex = getMeshVertex(numFacetsX, numFacetsZ);
    float u = map(vertex.x, minVertex.x, maxVertex.x, 0, w-1);
    float v = map(vertex.z, minVertex.z, maxVertex.z, 0, h-1);
    return new PVector(u,v);
  }
  
  
  
   
   
   
   
  

   
    public void setVertexY(int vertexX, int vertexZ, float y){
      
      if(vertexX < 0 || vertexX > numFacetsX || vertexZ < 0 || vertexZ > numFacetsZ){
        println("SimSurfaceMesh::setVertexY - illegal vertices index ", vertexX, vertexZ);
        return;
      }
      int vertexGridWidth = numFacetsX + 1;
      int index =  vertexZ * vertexGridWidth + vertexX;
      PVector p = meshVertices[index];
      p.y = y;
      meshVertices[index] = p;
    }
    
    public PVector getMeshVertex(int vertexX, int vertexZ){
      int vertexGridWidth = numFacetsX + 1;
      int index =  vertexZ * vertexGridWidth + vertexX;
      return meshVertices[index];
    }
    
    public void setMeshVertex(int vertexX, int vertexZ, PVector v){
      int vertexGridWidth = numFacetsX + 1;
      int index =  vertexZ * vertexGridWidth + vertexX;
      meshVertices[index] = v;
    }
    
    
    

    int getNumFacets(){
      return (numFacetsX)* (numFacetsZ); 
    }
    
    int getNumTriangles(){
        return (numFacetsX)* (numFacetsZ)*2;
    }
    
    private int getNumVerticesX(){ return  numFacetsX+1;}
    private int getNumVerticesZ(){ return  numFacetsZ+1;}

    
    
    
    SimFacet getFacet(int index){
        
        
        
        
        
        int vertextGridWidth = numFacetsX+1;
        int rowNum = (int)(index/numFacetsX);
        int A = index + rowNum;
        int B = A + 1;
        int C = A + vertextGridWidth;
        int D = C + 1;

        
        SimFacet facet = new SimFacet();
        
        facet.tri1.p1 = meshVertices[D];
        facet.tri1.p2 = meshVertices[B];
        facet.tri1.p3 = meshVertices[A];
        
        
        facet.tri2.p1  = meshVertices[D];
        facet.tri2.p2  = meshVertices[A];
        facet.tri2.p3  = meshVertices[C];

        return facet;

      
    }

    SimFacet getFacet(int x, int z)
    {
        int vertexGridWidth = numFacetsX + 1;
        int index =  z * vertexGridWidth + x;
        
        return getFacet(index); 
    }
    
  
  

}
