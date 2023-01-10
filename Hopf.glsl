#define PI 3.14159265

// This is a visualisation of the Hopf Fibration (https://en.wikipedia.org/wiki/Hopf_fibration).
// For a set of points on the surface of the 2-sphere which lie on a plane parallel to its equator, each ring shown
// is a stereographic projection of the fiber (a great circle on the 3-sphere) mapped to that point.
// The points on the 2-sphere are revolving around the vertical axis whilst travelling up and down between the poles;
// this produces the expansion and rotation of the projected fibers, revealing some of the fibration's structure...

// Find a unit vector orthogonal to vectors v1, v2
vec3 orth(vec3 v1, vec3 v2)
{
    return normalize(cross(v1,v2));
}

// Find the radius and center of a circle given 3 points on its circumference
// https://math.stackexchange.com/questions/1076177/3d-coordinates-of-circle-center-given-three-point-on-the-circle
vec4 p3toCircle(vec3 p1, vec3 p2, vec3 p3)
{
    vec3 cu = p2 - p1;
    vec3 cv = p3 - p1;
    float a = dot(cu, cu);
    float b = dot(cv, cv);
    float c = dot(cu, cv);
    
    float m = 1./(2.*(a*b - c*c));
    float j = m * b * (a-c);
    float k = m * a * (b-c);
    
    vec3 center = p1 + j*cu + k*cv;
    
    return vec4(center, length(center - p1));
}

// Signed distance to a torus
float torusDist (vec3 p, vec2 r)
{
    float d = length(vec2(length(p.xy) - r.x, p.z));
    return d - r.y;
}

// Given a point on S^2 and angle in radians, identify a point which lies on the fiber
// yielded by the inverse Hopf map from S^2 to S^3 at that angle
vec4 iHopf(vec3 p, float th)
{
    float st = sin(th);
    float ct = cos(th);
    vec4 v = vec4((1.+p.z)*ct, p.x*st - p.y*ct, p.x*ct + p.y*st, (1.+p.z)*st);
    return (1./sqrt(2.*(1.+p.z))) * v;
}

// Stereographically project a given point in S^3 to R^3
vec3 s3r3stereo(vec4 p)
{
    return (vec3(p.xyz)/(1.-p.w));
}

// Signed distance from a point to a fiber determined by a pair of orthogonal points on the fiber in S^3
float fiberDist(vec3 p, vec4 q1, vec4 q2)
{
    // Project 3 non-colinear points on the fiber into R^3
    vec3 p1 = s3r3stereo(q1);
    vec3 p2 = s3r3stereo(-q1);
    vec3 p3 = s3r3stereo(q2);
    
    // Find the center and radius of the projected fiber
    vec4 circle = p3toCircle(p1,p2,p3);
    vec3 c = circle.xyz;
    float rad = circle.w;
    
    // Find the transformation from global coords to (orthonormal) ones with xy plane as the projected fiber plane
    vec3 b1 = normalize(p1);
    vec3 b2 = normalize(p3);
    vec3 b3 = orth(b1,b2);
    mat3 A = transpose(mat3(b1,b2,b3));
    
    // Query the SDF of a torus in fiber-aligned coordinates with the projected center and radius
    vec3 po = A*p;
    po += A*c;
    
    return torusDist(po, vec2(rad, 0.09));
}


// Signed distance from a point to the scene
float sceneDist(vec3 p)
{
    p = p.yzx;
    float ct = cos(iTime);
    float st = sin(iTime);
    vec3 p_ = normalize(vec3(ct, st, st-.5));
    vec4 f1 = iHopf(p_, PI*.5);
    vec4 f2 = iHopf(p_, PI);
    float d = fiberDist(p, f1, f2);
    
    for(int i=1; i<8; i++) {
        float a = float(i) * (.25*PI);
        p_ = normalize(vec3( cos(a + iTime), sin(a + iTime), st-.5));
        f1 = iHopf(p_, PI*.5);
        f2 = iHopf(p_, PI);
    
        d = min(d, fiberDist(p, f1, f2));
    }
    
    return d;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from -.5 to .5)
    vec2 uv = (fragCoord-0.5*iResolution.xy)/iResolution.y;

    // Camera settings
    vec3 cameraPos = vec3(uv,-5.);
    vec3 cameraDir = normalize(vec3(uv,1.));

    // Rendering settings
    vec3 rayPos = cameraPos;
    float minD = 1e-3;
    float maxD = 10.;
    int maxIters = 100;
    float stepSize = sceneDist(rayPos);
    
    // Background colour
    vec3 col = vec3(0.);

    for (int i=0; i<maxIters; i++)
    {
        // March the ray to the closest point in the scene
        rayPos += cameraDir * stepSize;

        // Check for collision
        float dist = sceneDist(rayPos);
        if (dist < minD)
        {
            float d = length(cameraPos - rayPos);
            col = vec3(1.-0.1*d);
            break;
        }
        else if (dist > maxD)
        {
            break;
        }

        stepSize = dist;
    }

    // Output to screen
    fragColor = vec4(col,1.0);
}
