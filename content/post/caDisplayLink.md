+++
date = "2016-02-25"
title = "CADisplayLink"
tags = [ "Development", "iOS" ]
+++

Ever been in the position where you need to animate something on screen but the property is not covered by [UIView animateWith...]? Or maybe the thing you're trying to animate is not part of the standard UIKit frameworks, and is instead some higher level UI piece built by a vendor. I ran into this not too long ago with Google Maps iOS SDK. My desire was to animate a polyline across the sceen, but there was no built in animate feature for the SDK. This is how I learned about making your own animations with CADisplayLink. A bit of background first though...

Fun With Google Maps
====================

In the GoogleMaps iOS SDK, you create a polyline by creating a `GMSPath` object with your desired coordinates, providing that to a `GMSPolyline` and feeding the polyline some info such as width, color, etc., then pass that off to the `GMSMapView` you're using to display the map. Once you provide the path object to your mapview, the polyline is drawn on screen. 

Right off the bat, my though was that this polyline was simply another view, or most likely something backed by a `CAShapeLayer`, but the path object and the map didn't provide a reference to any underlying cocoa views or layers. I tried 'fishing' for a reference to the view via `recursiveDescription` and digging through subviews, but quickly realized that the polyline I was seeing was not a separate view, but something rendered directly onto a OpenGL view. GoogleMaps, Apple Maps, and most recently MapBox all provide thier map views as `GLViews`. This pretty much killed the idea of finding a `UIView` or `CALayer` reference and animating it.

GMSPath
=======

Once I gave up trying to animate the view's appearance directly, I took a look back at the underling datasource and wondered what would happen if I changed it. 

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

Which then produced this!

// Put image here


CADisplayLink
=============
