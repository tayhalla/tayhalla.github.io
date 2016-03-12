+++
date = "2016-01-25"
title = "Interfaces in Go"
tags = [ "Development", "Go" ]
+++

Go has been a interesting language for me to learn. I love how the language reminds me of writing in C, but it comes with the comfort of having some hardened core libs and memory managemnt baked in. One thing that struck me as odd about it though was the concept of interfaces.

Go's Pointers n' Interfaces
===========================

The first thing I wanted to write in Go was a small app with some networking functionality. Luckily Go has *awesome* resources for getting going. I started with replicating the code from their own [Writing Web Applications](https://golang.org/doc/articles/wiki/ "Awesome Stuff"):

https://golang.org/doc/articles/wiki/#tmp_3
{{< highlight go>}}
// Main is the entry point for the program. 
// Here, the we're calling on the http package to
// listen on port 8080, and send all requests to the function 'handler'
func main() {
    http.HandleFunc("/", handler)
    http.ListenAndServe(":8080", nil)
}

func handler(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "Hi there, I love %s!", r.URL.Path[1:])
}
{{< /highlight >}}

I highlighted the `handler` function declaration to note where I had my first hangup with the language. Without knowing much about Go, this method signature struck me as odd. It looks like Go has the notion of explicit pointers based on the second parameter, `r *http.Request`. But, why would something like a response writer `w http.ResponseWriter`, something that I'm assuming is used to write a message back to the client, follow value semantics instead of reference semantics? If anything, I could see someone building a http lib with it the otherway around. If I send these parameters to another helper function, am I really passing around a copy of the response writer? If I am, maybe the `http.ResponseWriter` has internal member variables that are pointers to socket I'd be writing a reponse to. 

It turns out that the answer lies somewhere in between. Enter Go's `Interface` type. The [`http.ResponseWriter`](https://golang.org/pkg/net/http/ "Cool Link") an instance of an interface. There's no shortage of blogs describing Interfaces, and the respective styles for explaining them differ signifcantly, but here is a rundown that makes sense to me:

A Go Interface is a value type that holds two pointers: one to a value, and the other to a type descripton. That's it. 

But there are multiple interface types in Go, and certainly `http.ResponseWriter` isn't the only one. Very true, and you too can make infinite interface type declarations yourself. So, how do we come up with making the disctintion in method signatures? Isn't Go a staticly typed language? *Yes*, Go is definitely staticly typed, and Interfaces adhere to that strong type system by way of their respective method sets. Interface A is different from interface B because of it's underlying value's methods. *Put differently*, an interface is defined by the method declarations that it's type posesses.

Before we continure, it's worth mentioning here that an inteface does *NOT* make any disctintions based on it's underlying type's properties, or member variables.

When you declare that you accept an interface in Go, such as `http.ResponseWriter` in our `handler` call, you are saying that you don't care what is being passed in, so long as it has the ability to do certain thing via its method set. Swift, Objecitve-C, Java, and many more languages have their notion of this type of protocol based programming model, but what makes Go distinct in this duck typing paradigm is that interfaces are a seperate type, they are NOT merely a abstract declaration used to faciltate polymorphism. 

To make the previous point more clear, let's say you declare the following protocol in swift and want to write a little greeting program:

{{< highlight swift >}}
protocol Greetable {
    func hello() -> String
}

struct ValueSalutation : Greetable {
    func hello() -> String {
        return "What up? I'm a value type"
    }
}

class ReferenceSalutation: Greetable {
    func hello() -> String {
        return "Heyooo~!!, Reference type here"
    }
}

func introdceYourself(stranger: Greetable) {
    print(stranger.hello())
}

introdceYourself(ValueSalutation())
introdceYourself(ReferenceSalutation())
{{< /highlight >}}

In `introdceYourself`, swift doesn't who's coming through as the `stranger` variable, so long as it's type declares its conformance to the Greetable protocol. Both the class and struct have declarations that they conform to the `Greetable` protocol, and the compiler enforces this adherence. Inside `introdceYourself`, you aren't sure whether you're dealing with a value type, or a refernce type. All you know is that stranger possess the ability to say `hello`. 

Now, let's see the same program in go:

{{< highlight go >}}

type Greetable interface {
	hello() string
}

type GoSalutation struct {}

func (s Salutation)hello() string {
	return "Heyyoo from a Go Stuct!!"
}

func introduceYourself(g Greetable) {
	fmt.Println(g.hello())
}

func main() {
	s := GoSalutation{}
	introduceYourself(s)
}
{{< /highlight >}}

The difference here is that inside `introduceYourself`, we are not receiving an instance, or copy of GoSalutation, rather we receive an an interface type `Greetable`. When we pass the instance of `GoSalutation`, it is being automatically boxed up for us into an interface type. It's a compile time safety check that determines whether or not can satisfy `Greetable`, it's *NOT* due to whether `GoSalutation` explictly declares some type of conformance. Also, there's is no question whether we are dealing with a reference type or a value type any longer, we simply know that this the underlying, or `dynamic type`, of the Greetable parameter posesses the ability to say `hello()`. 

I'm not advocating Go's approach to protocol based programming over swift's, or any other languages, I'm just using this example to draw the disctintion, and to illustrate what is really happening when you pass types to methods that accept interfaces.

Back to the Interface
=====================

So, now knowing that an interface is simply a some value type that points to some other types that posses certain method declarations, how does this influence how we understand what is going on with `http.responseWriter`? Let's look at what the `http.responseWriter` interace actually declares:

{{< highlight go >}}
type ResponseWriter interface {
        Header() Header

        Write([]byte) (int, error)

        WriteHeader(int)
}
{{< /highlight >}}

Suprisingly thin - huh? But that's kinda cool. When we decalre that a method accepts a `http.responseWriter` of type interface, all we're saying is that you can call three distinct methods on the underlying dynamic value, and that the underlying type is of no concern to you.

