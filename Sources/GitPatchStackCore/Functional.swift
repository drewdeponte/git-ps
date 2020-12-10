import Foundation

// ForwardApplication - pipe forward operator
//
// This is an operator to apply a function
//
// 2 |> incr
// 2 |> incr |> square

precedencegroup ForwardApplication {
    associativity: left
}

infix operator |>: ForwardApplication

func |> <A, B>(a: A, f: (A) -> B) -> B {
    return f(a)
}

func |> <A>(a: inout A, f: (inout A) -> Void) -> Void {
    f(&a)
}

// ForwardComposition - right arrow operator
//
// This is an operator to compose multiple functions together
//
// incr >>> square
// square >>> incr
// (incr >>> square)(2)
// 2 |> incr >>> square

precedencegroup ForwardComposition {
    associativity: left
    higherThan: ForwardApplication, EffectfulComposition
}

infix operator >>>: ForwardComposition

func >>> <A, B, C>(f: @escaping (A) -> B, g: @escaping (B) -> C) -> ((A) -> C) {
    return { a in
        g(f(a))
    }
}

func >>> <B, C>(f: @escaping () -> B, g: @escaping (B) -> C) -> ((B) -> C) {
    return { b in
        g(f())
    }
}

// EffectfulComposition - fish operator
//
//
// 2
// |> computeAndPrint
// >=> computeAndPrint
// >=> computeAndPrint

precedencegroup EffectfulComposition {
    associativity: left
    higherThan: ForwardApplication
}

infix operator >=>: EffectfulComposition

func >=> <A, B, C>(
    _ f: @escaping (A) -> (B, [String]),
    _ g: @escaping (B) -> (C, [String])
    ) -> ((A) -> (C, [String]   )) {

    return { a in
        let (b, logs) = f(a)
        let (c, moreLogs) = g(b)
        return (c, logs + moreLogs)
    }
}

func >=> <A, B, C>(
    _ f: @escaping (A) -> B?,
    _ g: @escaping (B) -> C?
    ) -> ((A) -> C?) {

    return { a in
        fatalError()
//        let (b, logs) = f(a)
//        let (c, moreLogs) = g(b)
//        return (c, logs + moreLogs)
    }
}

func >=> <A, B, C>(
    _ f: @escaping (A) -> [B],
    _ g: @escaping (B) -> [C]
    ) -> ((A) -> [C]) {

    return { a in
        fatalError()
        //        let (b, logs) = f(a)
        //        let (c, moreLogs) = g(b)
        //        return (c, logs + moreLogs)
    }
}

//func >=> <A, B, C>(
//    _ f: @escaping (A) -> Promise<B>,
//    _ g: @escaping (B) -> Promise<C>
//    ) -> ((A) -> Promise<C>) {
//
//    return { a in
//        fatalError()
//        //        let (b, logs) = f(a)
//        //        let (c, moreLogs) = g(b)
//        //        return (c, logs + moreLogs)
//    }
//}


// SingleTypeComposition - diamond operator

precedencegroup SingleTypeComposition {
    associativity: left
    higherThan: ForwardApplication
}

infix operator <>: SingleTypeComposition

func <> <A>(f: @escaping (A) -> A, g: @escaping (A) -> A) -> (A) -> A {
    return { a in
        f(g(a))
    }
}

func <> <A>(f: @escaping (inout A) -> Void, g: @escaping (inout A) -> Void) -> (inout A) -> Void {
    return { a in
        f(&a)
        g(&a)
    }
}

func <> <A: AnyObject>(f: @escaping (A) -> Void, g: @escaping (A) -> Void) -> (A) -> Void {
    return { a in
        f(a)
        g(a)
    }
}

// Curry

func curry<A, B, C>(_ f: @escaping (A, B) -> C) -> (A) -> (B) -> C {
    return { a in { b in f(a, b) } }
}

// Flip

func flip<A, B, C>(_ f: @escaping (A) -> (B) -> C) -> (B) -> (A) -> C {
    return { b in { a in f(a)(b) }}
}

// Zurry

func zurry<A>(_ f: () -> A) -> A {
    return f()
}

// Map - free form

func map<A, B>(_ f: @escaping (A) -> B) -> ([A]) -> ([B]) {
    return { $0.map(f) }
}

// Filter - free form

func filter<A>(_ p: @escaping (A) -> Bool) -> ([A]) -> [A] {
    return { $0.filter(p) }
}
