-- distPointToLineSeg(): shortest distance of a point to a line segment.
function distPointToLineSeg(p , s1, s2)
    local v = s2 - s1
    local w = p - s1

    c1 = w:dot(v)
    if c1 <= 0 then
        return p:dist(s1)
    end

    c2 = v:dot(v)
    if c2 <= c1 then
        return p:dist(s2)
    end

    b = c1 / c2;
    pb = s1 + b * v;
    return p:dist(pb)
end
--===================================================================

-- Use this function to perform your initial setup
function setup()
    debugDraw = PhysicsDebugDraw()
    
    print("Hello Polygon!")
    print("1. Tap in clockwise order to create a polygon.")
    print("2. Drag existing points to move them.")
    print("3. Drag on lines to add new points.")
    
    -- the mesh to draw the polygon with
    polyMesh = mesh()
    -- the current set of vertices for the polygon
    verts = {}
    -- the polygon fill color
    col = color(255, 188, 0, 255)
    
    index = -1
    touchID = -1
    
    -- rigid body for the polygon
    polyBody = nil
    
    timer = 0
end

-- This function gets called once every frame
function draw()
    
    timer = timer + DeltaTime
    -- create a circle every 2 seconds
    if timer > 2 then
        local body = physics.body(CIRCLE, 25)
        body.restitution = 0.5
        body.x = WIDTH/2
        body.y = HEIGHT
        debugDraw:addBody(body)
        timer = 0
    end
    
    -- This sets the background color to black
    background(0, 0, 0)

    -- draw physics objects
    debugDraw:draw()

    -- draw the polygon interia
    fill(col)
    polyMesh:draw()
    
    pushStyle()
    lineCapMode(PROJECT)
    fill(255, 255, 255, 255)
    
    -- draw the polygon outline
    local pv = verts[1]
    for k,v in ipairs(verts) do
        noStroke()
        ellipse(v.x, v.y, 10, 10)
        stroke(col)
        strokeWidth(5)
        line(pv.x, pv.y, v.x, v.y)
        pv = v
    end
    if pv then
        line(pv.x, pv.y, verts[1].x, verts[1].y)
    end
    popStyle()
    
end

function touched(touch)
    local tv = vec2(touch.x, touch.y)
    
    if touch.state == BEGAN and index == -1 then        
        -- find the closest vertex within 50 px of thr touch
        touchID = touch.id
        local minDist = math.huge
        for k,v in ipairs(verts) do
            local dist = v:dist(tv)
            if dist < minDist and dist < 50 then
                minDist = dist
                index = k
            end
        end
       
        -- if no point is found near the touch, insert a new one           
        if index == -1 then
            index = #verts
            if index == 0 then
                index = index + 1
            end
            
            -- if touch is within 50px to a line, insert point on line
            if #verts > 2 then
                local minDist = math.huge
                local pv = verts[index]
                for k,v in ipairs(verts) do
                    local dist = distPointToLineSeg(tv, pv, v)
                    if dist < minDist and dist < 50 then
                        minDist = dist
                        index = k
                    end
                    pv = v
                end
            end
            
            table.insert(verts, index, tv)
        else
            verts[index] = tv
        end
        
    elseif touch.state == MOVING and touch.id == touchID then
        verts[index] = tv 
    elseif touch.state == ENDED and touch.id == touchID then
        index = -1
    end
    
    -- use triangulate to generate triangles from the polygon outline for the mesh
    polyMesh.vertices = triangulate(verts)
    if polyBody then
        polyBody:destroy()
    end
    if #verts > 2 then
        polyBody = physics.body(POLYGON, unpack(verts))
        polyBody.type = STATIC
    end
end

PhysicsDebugDraw = class()

function PhysicsDebugDraw:init()
    self.bodies = {}
    self.joints = {}
    self.touchMap = {}
    self.contacts = {}
end

function PhysicsDebugDraw:addBody(body)
    table.insert(self.bodies,body)
end

function PhysicsDebugDraw:addJoint(joint)
    table.insert(self.joints,joint)
end

function PhysicsDebugDraw:clear()
    -- deactivate all bodies
    
    for i,body in ipairs(self.bodies) do
        body:destroy()
    end
  
    for i,joint in ipairs(self.joints) do
        joint:destroy()
    end      
    
    self.bodies = {}
    self.joints = {}
    self.contacts = {}
    self.touchMap = {}
end

function PhysicsDebugDraw:draw()
    
    pushStyle()
    smooth()
    strokeWidth(5)
    stroke(128,0,128)
    
    local gain = 2.0
    local damp = 0.5
    for k,v in pairs(self.touchMap) do
        local worldAnchor = v.body:getWorldPoint(v.anchor)
        local touchPoint = v.tp
        local diff = touchPoint - worldAnchor
        local vel = v.body:getLinearVelocityFromWorldPoint(worldAnchor)
        v.body:applyForce( (1/1) * diff * gain - vel * damp, worldAnchor)
        
        line(touchPoint.x, touchPoint.y, worldAnchor.x, worldAnchor.y)
    end
    
    stroke(0,255,0,255)
    strokeWidth(5)
    for k,joint in pairs(self.joints) do
        local a = joint.anchorA
        local b = joint.anchorB
        line(a.x,a.y,b.x,b.y)
    end
    
    stroke(255,255,255,255)
    noFill()
    
    
    for i,body in ipairs(self.bodies) do
        pushMatrix()
        translate(body.x, body.y)
        rotate(body.angle)
    
        if body.type == STATIC then
            stroke(255,255,255,255)
        elseif body.type == DYNAMIC then
            stroke(150,255,150,255)
        elseif body.type == KINEMATIC then
            stroke(150,150,255,255)
        end
    
        if body.shapeType == POLYGON then
            strokeWidth(5.0)
            local points = body.points
            for j = 1,#points do
                a = points[j]
                b = points[(j % #points)+1]
                line(a.x, a.y, b.x, b.y)
            end
        elseif body.shapeType == CHAIN or body.shapeType == EDGE then
            strokeWidth(5.0)
            local points = body.points
            for j = 1,#points-1 do
                a = points[j]
                b = points[j+1]
                line(a.x, a.y, b.x, b.y)
            end      
        elseif body.shapeType == CIRCLE then
            strokeWidth(5.0)
            line(0,0,body.radius-3,0)
            strokeWidth(2.5)
            ellipse(0,0,body.radius*2)
        end
        
        popMatrix()
    end 
    
    stroke(255, 0, 0, 255)
    fill(255, 0, 0, 255)

    for k,v in pairs(self.contacts) do
        for m,n in ipairs(v.points) do
            ellipse(n.x, n.y, 10, 10)
        end
    end
    
    popStyle()
end