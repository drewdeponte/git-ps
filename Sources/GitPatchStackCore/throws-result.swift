import Foundation

func result<A>(_ f: @escaping (A) throws -> ()) -> (A) -> Result<Void, Error> {
    return { a in
        do {
            return Result.success(try f(a))
        } catch {
            return Result.failure(error)
        }
    }
}

func result<A, B>(_ f: @escaping (A) throws -> B) -> (A) -> Result<B, Error> {
    return { a in
        do {
            return Result.success(try f(a))
        } catch {
            return Result.failure(error)
        }
    }
}
