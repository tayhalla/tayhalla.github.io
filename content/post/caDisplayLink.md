+++
date = "2016-02-25"
title = "CADisplayLink and Maps"
tags = [ "Development", "iOS" ]
+++

Ever been in the position where you need to animate something on screen but the property is not covered by [UIView animateWith...]? Or maybe the thing you're trying to animate is not part of the standard UIKit frameworks, and is instead some higher level UI piece built by a vendor. I ran into this not too long ago with Google Maps iOS SDK. My desire was to animate a polyline across the sceen, but there was no built in animate feature for the SDK. This is how I learned about making your own animations with CADisplayLink. A bit of background first though...

Fun With Google Maps
====================

In the GoogleMaps iOS SDK, you create a polyline by creating a `GMSPath` object with your desired coordinates, providing that to a `GMSPolyline` and feeding the polyline some info such as width, color, etc., then pass that off to the `GMSMapView` you're using to display the map. Once you provide the path object to your mapview, the polyline is drawn on screen. 

Right off the bat, my though was that this polyline was simply another view, or most likely something backed by a `CAShapeLayer`, but the path object and the map didn't provide a reference to any underlying cocoa views or layers. I tried 'fishing' for a reference to the view via `recursiveDescription` and digging through subviews, but quickly realized that the polyline I was seeing was not a separate view, but something rendered directly onto a OpenGL view. GoogleMaps, Apple Maps, and most recently MapBox all provide thier map views as `GLViews`. This pretty much killed the idea of finding a `UIView` or `CALayer` reference and animating it.

GMSPath
=======

Once I gave up trying to animate the view's appearance directly, I took a look back at the underling datasource and wondered what would happen if I changed the `GMSPath` after I passed it to the mapview.

{{< highlight objc >}}
[self.mapView setCamera:[GMSCameraPosition cameraWithLatitude:47.6094426 longitude:-122.3319217 zoom:12.0]];

GMSMutablePath *mutablePath = [[GMSMutablePath alloc] init];
[mutablePath addLatitude:47.626452 longitude:-122.32];
[mutablePath addLatitude:47.626452 longitude:-122.29];
[mutablePath addLatitude:47.6 longitude:-122.29];

GMSPolyline *polyline = [[GMSPolyline alloc] init];
[polyline setPath:mutablePath];
[polyline setStrokeWidth:7.0];
[polyline setStrokeColor:[UIColor redColor]];
[polyline setMap:self.mapView];

dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [mutablePath addLatitude:47.6 longitude:-122.32];
    [mutablePath addLatitude:47.626452 longitude:-122.32];
    [polyline setPath:mutablePath];
});
{{< /highlight >}}

{{< figure src="/media/polyline_complete.gif" class="map-img">}}

Boom!

NSTimer?
========

What I needed was a way to interpolate though my coordinates, and have the callback progressively update the polyline. My first thought was `NSTimer` would be a good candidate, but I was wrong. NSTimer simply wasn't performing its callbacks fast enough, no matter how small I made the intervals. Looking into the documentation reveals why:

> A timer is not a real-time mechanism; it fires only when one of the run loop modes to which the timer has been added is running and able to check if the timer’s firing time has passed. Because of the various input sources a typical run loop manages, the effective resolution of the time interval for a timer is limited to on the order of 50-100 milliseconds.

What I'm looking to do is smoothly animate something, so a mechanism that only fires 10-20 times a second is clearly not my solution. What I need is something that will refresh at least as fast as the window redraws.

CADisplayLink
=============

What is CADisplayLink? It's a callback mechanism that hooks right into the screen's refresh callbacks. From the docs:

> A CADisplayLink object is a timer object that allows your application to synchronize its drawing to the refresh rate of the display. Your application creates a new display link, providing a target object and a selector to be called when the screen is updated

Sounds like just what we need. The API for `CADisplayLink` is pretty similar to NSTimer. You alloc/init an instance, assign is to a runloop, give it a target and selector, and you have a callback that occurs whenever a redraw is about to happen on the screen. 

Here's the code:

{{< highlight objc >}}
- (void)setupTimer
{
    self.displayLink               = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateRoutePolyline)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    self.displayLink.frameInterval = 2.0;
    self.animationBeginTime        = 0;
    self.animationCurrentFrameTime = 0;
}

- (void)updateRoutePolyline
{
    // Setting up our base times for the relative time tracking
    double duration = 0;
    if (self.animationCurrentFrameTime == 0) {
        self.animationBeginTime        = [self.displayLink timestamp];
        self.animationCurrentFrameTime = [self.displayLink timestamp];
    } else {
        double nowTime                 = [self.displayLink timestamp];
        self.animationCurrentFrameTime = nowTime;
        duration                       = nowTime - self.animationBeginTime;
    }
    .
    .
    .
{{< /highlight >}}

And the result? A smooth animation across the screen for my polylines:

{{< figure src="/media/cadisplay_polyline.gif" class="map-img">}}


POP and Other Animation Frameworks
==================================

CADisplayLink is actually the key to any animation framework. An animation on the screen is simply displaying the interpolation of values over the screen. The only thing that makes POP and other animations a bit more complicated is the concept of timing curves - the rate of the change in animateable values over the change in time. With the `[UIView animate...]` functions, you may recognize them as the `UIViewAnimationCurve` enum. They define whether the animation will proceed in a linear fashion, or if it will speed up and/or slow down at certain points in the process. 

For instance though, if you look at POP's root animator class, you will find it [hooking up a CADiaplyLink in the init](https://github.com/facebook/pop/blob/master/pop/POPAnimator.mm#L347), and it's callback is the [core render method in the animation](https://github.com/facebook/pop/blob/master/pop/POPAnimator.mm#L425).

A Note On Interpolation
=======================

In the previous section on animating a polyline, I oversimplified the process a bit. While you can simply interpolate between lat/lng pairs relative to the total distance in polyline, you need to be sure you're hitting all of the original points provided to the polyline. This means that whenever you receive a callback to come up with a new point to put on screen, you need to check to make sure that all of the original control points (ends/beginnings of the lines) were laid out where they needed to be. In order to do that, we need to preprocess the line to figure out each control pairs' position in our longer collection of interpolated points. Here is the code to preprocess the interpolation:

{{< highlight objc >}}
// *** Create the polyline route ***
unsigned int polylineCount = (int)self.locations.count;
if (polylineCount == 0) {
    return;
}

// Get total distance and record segments
CLLocationDistance totalDistance = 0.0;
NSMutableArray *routeLegDistances = [[NSMutableArray alloc] init];

// Calculate the total distance in order to get prorata distance legs
double *distances               = malloc(sizeof(CLLocationDistance) * polylineCount);

// We use these to track the waypoint progress and indexes
int allocCount = polylineCount * 2.0;
self.wayPointIndexTracker       = malloc(sizeof(int) * allocCount);
for (int i = 0; i < allocCount; i++) {
    self.wayPointIndexTracker[i] = INT16_MAX;
}

self.wayPointIndexTrackerBegRef = self.wayPointIndexTracker;
self.waypointMappingCount       = 0;

// Getting the distances between waypoints so that we can
// get relative length spans for each ray
CLLocation *previousLoc;
for (int i = 0; i < polylineCount; i++) {
    CLLocation *location = self.locations[i];
    if (i == 0) {
        previousLoc = location;
        distances[i] = 0.0;
        [routeLegDistances addObject:[NSNumber numberWithInt:0]];
    } else {
        distances[i] = [previousLoc distanceFromLocation:location];
        totalDistance += distances[i];
    }
    previousLoc = location;
}

// Create fake intermediate points
int totalDesiredPoints = 5000;

// Adding a 100 mark buffer. Shouldn't ever go over the limit anyways, but doesn't take much room.
int *waypointRunner                          = self.wayPointIndexTracker;
CLLocationCoordinate2D *finalCoordinateArray = malloc(sizeof(CLLocationCoordinate2D) * (totalDesiredPoints + 500));
CLLocationCoordinate2D *coordinateRunner     = finalCoordinateArray;
CLLocationCoordinate2D previousCoordinate;
unsigned int coordinateCount = 0;
for (int x = 0; x < polylineCount; x++) {
    // Add the first coord
    CLLocation *loc = self.locations[x];
    CLLocationCoordinate2D currentCoord = loc.coordinate;
    if (x > 0) {
        
        // We figure out the relative distance here between the current and the
        // previous. Then use that to approximate how many interpolated points
        // we need.
        double legDistance                  = distances[x];
        double relativeDistance             = legDistance / totalDistance;
        int coordinateInsertCount           = relativeDistance * totalDesiredPoints;
        for (int i = 0; i < coordinateInsertCount; i++) {
            // Calculate the incremental coordinate diff and add to the current coord
            double newCoordinateVariance = (float)i / coordinateInsertCount;
            double addedLatVariance      = (currentCoord.latitude - previousCoordinate.latitude) * newCoordinateVariance;
            double addedLngVariance      = (currentCoord.longitude - previousCoordinate.longitude) * newCoordinateVariance;
            double newLat                = previousCoordinate.latitude + addedLatVariance;
            double newLng                = previousCoordinate.longitude + addedLngVariance;
            *coordinateRunner            = CLLocationCoordinate2DMake(newLat, newLng);

            // If i == 0, we have a waypoint that we must hit
            if (i == 0) {
                *waypointRunner++ = coordinateCount;
            }
            
            coordinateRunner++;
            coordinateCount++;
        }
    }
    previousCoordinate = currentCoord;
}

self.animationCoordinates = finalCoordinateArray;
self.animationCoordinateCount = coordinateCount;

// Don't need these anymore
free(distances);

if (self.animationCoordinateCount > 0) {
    [self drawRoutPolyline];
}
{{< /highlight >}}



