+++
date = "2016-03-06"
title = "Managing ENVs In XCode"
tags = [ "Development", "iOS", "Swift" ]
+++

This post is a small one about work flow in XCode. There's no explicit way to have XCode set ENVs for you. When I started working with the IDE, I would simply comment or uncomment certain sections of code based on the ENV I was trying to target.

{{< highlight swift >}}
class MyAppAPI {
    static var debug: Bool = true
    static var baseURL: String {
        get {
            if debug {
                return "http://debug.someAPI.com"
            } else {
                return "http://someAPI.com"
            }
        }
    }
}
{{< /highlight >}}

As your application grows though, this kind of code can pop up in multiple classes. You could deal with it by making a central config class/stuct, but the idea of continually changing a single variable in the code that would drastically change behavior felt like an unsafe thing to do. Also, I would like to know the context of the code I'm looking at without having to navigate back and forth between a config file to see what environment I am operating under. 

XCode Schemes
=============

Xcode has a nice little drop down selector next to the device your targeting. It's called the Scheme Selector:

{{< figure src="/blog/media/scheme-selector.gif">}}

Per the [XCode Docs](https://developer.apple.com/library/ios/featuredarticles/XcodeConcepts/Concept-Schemes.html "Boring Apple Docs"), here's what they have to say about what a scheme selector is used for:

> An Xcode scheme defines a collection of targets to build, a configuration to use when building, and a collection of tests to execute.

Ok, sounds like this little drop down might have something to do with what we want. But, how do we select this configuration? Or, how do we configure the `Configuration` to our liking?

Turns out they're not using the term 'Configuration' colloquially  - XCode has something call 'XCode Configurations'

